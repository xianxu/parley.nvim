-- Hold real subprocess completions after durable publication. Cancellation is
-- deliberately followed by late delivery, so editor incarnation guards matter.
describe("agentic document buffer lifetime", function()
    local root, file, buf, saved, document, couch, ss, controls, group
    local function await(predicate)
        assert.is_true(vim.wait(10000, predicate, 10), "buffer lifecycle did not settle")
    end
    local function drain()
        local done = false
        vim.schedule(function() done = true end)
        await(function() return done end)
    end
    local function hold(predicate)
        local previous, control = couch.run, {}
        controls[#controls + 1] = control
        couch.run = function(argv, callback, options)
            if not control.captured and predicate(argv) then
                control.captured = true
                return previous(argv, function(result)
                    control.result = result
                    control.release = function()
                        control.release = nil
                        callback(result)
                    end
                end, options)
            end
            return previous(argv, callback, options)
        end
        return control
    end
    local function hold_registry(verb)
        return hold(function(argv) return argv[2] == "--session-sync" and argv[3] == verb end)
    end
    local function plain()
        await(function() local s = document.status(buf); return s and s.phase == "plain" end)
    end
    local function registered()
        await(function()
            local s = document.status(buf)
            return s and s.phase == "registered" and not s.operation
        end)
    end
    local function submit()
        assert.is_true(document.submit(buf))
    end
    local function send_count()
        return vim.fn.filereadable(root .. "/sent") == 1 and #vim.fn.readfile(root .. "/sent") or 0
    end
    local function admitted()
        plain(); submit(); registered()
        await(function() return send_count() == 1 end)
        return vim.deepcopy(document.identity(buf))
    end
    local function unload()
        vim.api.nvim_buf_call(buf, function() vim.cmd("silent bdelete") end)
        assert.is_false(vim.api.nvim_buf_is_loaded(buf))
    end
    local function reopen(path)
        vim.cmd("edit " .. vim.fn.fnameescape(path or file))
        buf = vim.api.nvim_get_current_buf()
        require("parley").setup_markdown_keymaps(buf)
    end
    local function complete_during_read(control)
        vim.api.nvim_create_autocmd("BufUnload", { group = group, buffer = buf, once = true, callback = function()
            assert.truthy(control.release)
            control.release()
            drain() -- completion runs inside the synchronous native read epoch
        end })
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        file = root .. "/ordinary.md"
        vim.fn.writefile({ "# Question", "original", "tail" }, file)
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        couch, ss, document = require("parley.couch"), require("parley.session_sync"), require("parley.agentic_document")
        saved = { env = {}, run = couch.run, state_dir = require("parley").config.state_dir, poll = ss.POLL_MS }
        for _, key in ipairs({ "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "COUCH_ISOLATED_ROOT",
            "FAKE_COUCH_REGISTRY", "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_ACTORS", "FAKE_COUCH_STATUS", "FAKE_COUCH_SLEEP", "FAKE_COUCH_EXIT" }) do
            saved.env[key] = vim.env[key] or false
        end
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG, vim.env.COUCH_ISOLATED_ROOT = "lifetime", "pane", root
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = root .. "/registry.json", nil
        vim.env.FAKE_COUCH_STATUS, vim.env.FAKE_COUCH_SLEEP, vim.env.FAKE_COUCH_EXIT = nil, nil, "0"
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "ops:0", Scope = "lifetime", Tag = "pane" } },
        } })
        require("parley").config.state_dir, ss.POLL_MS = root .. "/state", 20
        controls = {}
        group = vim.api.nvim_create_augroup("ParleyLifetimeSpec", { clear = true })
        reopen()
    end)
    after_each(function()
        vim.api.nvim_del_augroup_by_id(group)
        for _, owned in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(owned) and vim.api.nvim_buf_get_name(owned):sub(1, #root + 1) == root .. "/" then
                document.detach(owned)
                vim.api.nvim_buf_delete(owned, { force = true })
            end
        end
        require("parley.document_registry").shutdown()
        for _, control in ipairs(controls) do if control.release then control.release() end end
        drain()
        couch.run, ss.POLL_MS = saved.run, saved.poll
        require("parley").config.state_dir = saved.state_dir
        for key, value in pairs(saved.env) do vim.env[key] = value or nil end
        vim.fn.delete(root, "rf")
    end)

    it("retires an unloaded lookup and freshly queries on reopen without a stuck operation", function()
        plain()
        local held = hold_registry("lookup")
        document.recheck(buf)
        await(function() return held.release ~= nil end)
        unload(); held.release(); drain()
        assert.is_nil(document.status(buf), "true unload must retire the controller")
        local fresh = hold_registry("lookup")
        reopen()
        await(function() return fresh.release ~= nil end)
        fresh.release(); plain()
        submit(); registered()
        await(function() return send_count() == 1 end)
    end)

    it("reconfirms a registration published before unload without automatically sending", function()
        plain()
        local held = hold_registry("register")
        submit(); await(function() return held.release ~= nil end)
        local published = vim.json.decode(held.result.stdout).Registration
        unload(); held.release(); drain()
        assert.is_nil(document.status(buf))
        assert.equals(0, send_count())
        local fresh = hold_registry("lookup")
        reopen(); await(function() return fresh.release ~= nil end)
        fresh.release(); registered()
        assert.equals(published.ID, document.identity(buf).ID)
        assert.equals(0, send_count(), "confirmation alone cannot resume a stale submit")
        submit(); registered()
        await(function() return send_count() == 1 end)
    end)

    it("releases an unloaded move lease and forward-recovers the published exact tuple", function()
        local identity = admitted()
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "unsent edit" })
        local held, new = hold_registry("rename"), root .. "/renamed.md"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return held.release ~= nil end)
        assert.is_not.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
        unload()
        local namespace = table.concat({ root, vim.env.COUCH_STORE_DIR or "account-singleton", "lifetime" }, "\n")
        local lease, err = require("parley.document_lease").acquire(namespace, identity.ID, { root = root .. "/state" })
        assert.truthy(lease, vim.inspect(err)); lease.release()
        held.release(); drain()
        reopen(new); registered()
        assert.equals(identity.ID, document.identity(buf).ID)
        assert.equals(new, document.identity(buf).File)
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
        assert.equals(1, vim.fn.filereadable(new .. ".lock"))
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        assert.equals(1, send_count())
    end)

    it("ignores an issued send completion after unload without releasing a new turn", function()
        admitted()
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "first edit" })
        local held = hold(function(argv) return argv[2] == "--send-to" end)
        submit(); await(function() return held.release ~= nil end)
        assert.equals(2, send_count(), "fake has already accepted the issued send")
        unload(); reopen(); registered()
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "new incarnation edit" })
        local lock = table.concat(vim.fn.readfile(file .. ".lock"), "\n")
        local before = vim.wo.winbar
        held.release(); drain()
        assert.equals(lock, table.concat(vim.fn.readfile(file .. ".lock"), "\n"))
        assert.equals(before, vim.wo.winbar)
        assert.equals(2, send_count())
        assert.is_nil(document.status(buf).operation)
    end)

    it("preserves a lookup completion during the session engine's managed agent reload", function()
        local identity = admitted()
        local held = hold_registry("lookup")
        document.recheck(buf); await(function() return held.release ~= nil end)
        complete_during_read(held)
        vim.fn.writefile({ "# Question", "agent reply", "tail" }, file)
        await(function() return vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "agent reply" end)
        registered()
        assert.equals(identity.ID, document.identity(buf).ID)
        assert.is_true(ss.is_session_sync(buf))
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "operator after reload" })
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
        vim.cmd("silent write")
        assert.equals(1, vim.fn.filereadable(file .. ".lock"), "saving must preserve the acquisition baseline")
        submit(); registered(); await(function() return send_count() == 2 end)
    end)

    it("keeps the owned native acknowledgement attached and preserves its submit receipt", function()
        local identity = admitted()
        local unloads = 0
        vim.api.nvim_create_autocmd("BufUnload", { group = group, buffer = buf, callback = function() unloads = unloads + 1 end })
        local handled, new, err = document.move_path(file, root .. "/owned.md")
        assert.is_true(handled); assert.equals(root .. "/owned.md", new, tostring(err))
        assert.is_true(unloads > 0, "owned acknowledgement must exercise the native read boundary")
        registered()
        assert.equals(identity.ID, document.identity(buf).ID)
        assert.is_true(ss.is_session_sync(buf))
        submit(); drain()
        assert.equals(1, send_count(), "owned reload must preserve a successful receipt")
        assert.truthy(vim.wo.winbar:find("nothing to submit", 1, true))
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "edit after owned reload" })
        assert.equals(1, vim.fn.filereadable(new .. ".lock"))
    end)
end)
