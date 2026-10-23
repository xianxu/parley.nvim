local arrival = require("tests.helpers.arrival")

describe("editorial submit preparation through the native observer", function()
    local root, path, buf, document, saved, edits, notices
    local env_keys = { "PATH", "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "FAKE_COUCH_REGISTRY",
        "FAKE_COUCH_ACTORS", "FAKE_COUCH_REGISTRY_MODE", "FAKE_COUCH_STATUS", "FAKE_COUCH_EXIT",
        "FAKE_COUCH_SLEEP", "FAKE_COUCH_QUERY_SLEEP", "FAKE_COUCH_REGISTRY_DELAY", "FAKE_COUCH_REGISTRY_DELAY_OPS" }
    local original = { "# Question", "original", "tail" }
    local filled = { "---", "collaboration-mode: discussion", "presentation-mode: highlight",
        "processing-mode: free-form", "---", "", "# Question", "original", "tail" }
    local function lines() return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
    local function bar() return vim.wo[vim.fn.bufwinid(buf)].winbar end
    local function sends()
        return vim.fn.filereadable(root .. "/sent") == 1 and vim.fn.readfile(root .. "/sent") or {}
    end
    local function await(predicate)
        local ready, reason = vim.wait(arrival.MS, predicate, 10)
        assert.is_true(ready, vim.inspect({ reason = reason, status = document.status(buf),
            lines = lines(), feedback = bar(), notices = notices, sends = sends() }))
    end
    local function press()
        local mapping = vim.fn.maparg("<M-CR>", "n", false, true)
        assert.equals(1, mapping.buffer)
        mapping.callback()
        await(function()
            return document.status(buf).operation ~= nil or bar():find("not confirmed", 1, true)
                or bar():find("submitted to", 1, true) or bar():find("nothing to submit", 1, true)
                or bar():find("submit cancelled", 1, true)
        end)
    end
    local function delivered()
        await(function()
            local status = document.status(buf)
            return status.registration and not status.operation and bar():find("submitted to ops:0", 1, true)
        end)
    end
    local function no_send()
        assert.same({}, sends())
        assert.is_nil(document.identity(buf))
        assert.is_nil(document.status(buf).operation)
    end
    local function replace_file(content)
        document.detach(buf)
        vim.fn.writefile(content, path)
        vim.cmd("edit!")
        require("parley").setup_markdown_keymaps(buf)
        await(function() return document.status(buf).phase == "plain" end)
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        path = root .. "/document.md"
        saved = { env = {}, state_dir = require("parley").config.state_dir,
            edit = require("parley.buffer_edit").edit_user_lines, notify = vim.notify,
            run = require("parley.couch").run }
        for _, key in ipairs(env_keys) do saved.env[key] = vim.env[key]; vim.env[key] = nil end
        vim.env.PATH = root .. "/bin:" .. saved.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "editorial-test", "editorial-test"
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "ops:0", Scope = "editorial-test", Tag = "editorial-test" } },
        } })
        vim.env.FAKE_COUCH_EXIT = "0"
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        -- Observe actual disk bytes and persisted registration in the fake's
        -- executable send seam. No product transport function is replaced.
        assert((vim.uv or vim.loop).fs_rename(root .. "/bin/couch", root .. "/bin/couch-delegate"))
        vim.fn.writefile({ "#!/bin/sh", 'if [ "$1" = "--send-to" ]; then',
            '  subject=${4#submitted: }',
            '  cp "$subject" ' .. vim.fn.shellescape(root .. "/sent-bytes"),
            '  cp "$FAKE_COUCH_REGISTRY" ' .. vim.fn.shellescape(root .. "/sent-registry"),
            'fi', 'exec ' .. vim.fn.shellescape(root .. "/bin/couch-delegate") .. ' "$@"',
        }, root .. "/bin/couch")
        assert((vim.uv or vim.loop).fs_chmod(root .. "/bin/couch", 493))
        require("parley").config.state_dir = root .. "/state"
        notices = {}
        vim.notify = function(message) notices[#notices + 1] = tostring(message) end
        edits = {}
        local production_edit = saved.edit
        require("parley.buffer_edit").edit_user_lines = function(command, target, first, last, insertion, opts)
            edits[#edits + 1] = { command = command, first = first, last = last, lines = vim.deepcopy(insertion) }
            return production_edit(command, target, first, last, insertion, opts)
        end
        vim.fn.writefile(original, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path)); buf = vim.api.nvim_get_current_buf()
        document = require("parley.agentic_document")
        require("parley").setup_markdown_keymaps(buf)
        await(function() return document.status(buf).phase == "plain" end)
    end)
    after_each(function()
        require("parley.buffer_edit").edit_user_lines = saved.edit
        require("parley.couch").run = saved.run
        if buf and vim.api.nvim_buf_is_valid(buf) then
            document.detach(buf)
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        require("parley.document_registry").shutdown()
        require("parley").config.state_dir, vim.notify = saved.state_dir, saved.notify
        for _, key in ipairs(env_keys) do vim.env[key] = saved.env[key] end
        vim.fn.delete(root, "rf")
    end)

    it("fills through one authorized edit, observes it, and saves before registering and sending", function()
        press()
        assert.same(filled, lines())
        delivered()
        assert.equals(1, #edits)
        assert.equals(0, edits[1].first)
        assert.equals(0, edits[1].last)
        assert.same(filled, vim.fn.readfile(path))
        assert.same(filled, vim.fn.readfile(root .. "/sent-bytes"))
        local registry = vim.json.decode(table.concat(vim.fn.readfile(root .. "/sent-registry"), "\n"))
        assert.equals(document.identity(buf).ID, registry.paths[path].ID)
        assert.equals("ops:0", registry.paths[path].Owner)
        assert.same({ "ops:0|submitted: " .. path }, sends())
        vim.cmd("undo")
        assert.same(original, lines(), "the additions must be a single undoable edit")
        assert.is_true(vim.bo[buf].modified)
    end)

    it("retains existing scalar bytes and body when adding missing settings", function()
        local before = { "---", "owner: business-team", "presentation: direct", "future:", "  nested: untouched",
            "---", "# Question", "original", "tail" }
        replace_file(before)
        press()
        local expected = { "---", "owner: business-team", "presentation: direct", "future:", "  nested: untouched",
            "collaboration-mode: discussion", "presentation-mode: direct", "processing-mode: free-form",
            "---", "# Question", "original", "tail" }
        assert.same(expected, lines())
        delivered()
        assert.same(expected, vim.fn.readfile(root .. "/sent-bytes"))
        assert.equals(1, #edits)
    end)

    it("does not edit a complete header or repeat the preparation on the next press", function()
        replace_file(filled)
        local tick = vim.api.nvim_buf_get_changedtick(buf)
        press()
        assert.is_not.equals("prepare", document.status(buf).operation and document.status(buf).operation.witness.operation)
        delivered()
        assert.equals(tick, vim.api.nvim_buf_get_changedtick(buf))
        press()
        await(function() return bar():find("nothing to submit", 1, true) ~= nil end)
        assert.same(filled, lines())
        assert.same({}, edits)
        assert.equals(1, #sends())
    end)

    it("refuses invalid settings before any byte changes, save, registration or send", function()
        local invalid = { "---", "processing-mode: no-such-mode", "---", "body" }
        replace_file(invalid)
        press()
        assert.is_nil(document.status(buf).operation)
        assert.truthy(bar():find("processing-mode", 1, true), bar())
        assert.same(invalid, lines())
        assert.same(invalid, vim.fn.readfile(path))
        assert.same({}, edits)
        no_send()
    end)

    it("refuses a protected edit without saving or sending", function()
        vim.bo[buf].modifiable = false
        press()
        assert.is_nil(document.status(buf).operation)
        assert.truthy(bar():find("not confirmed", 1, true), bar())
        assert.same(original, lines())
        assert.same(original, vim.fn.readfile(path))
        no_send()
        vim.bo[buf].modifiable = true
    end)

    it("cancels on a real second edit reentrant after the authorized insertion", function()
        local production_edit = require("parley.buffer_edit").edit_user_lines
        local stages = {}
        require("parley.buffer_edit").edit_user_lines = function(...)
            local ok, err = production_edit(...)
            local status = document.status(buf)
            stages[#stages + 1] = status.operation and status.operation.preparation.stage
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "unrelated reentrant edit" })
            return ok, err
        end
        press()
        assert.same({ "observed-edit" }, stages, "the actual expected edit must first be observed")
        no_send()
        assert.equals("unrelated reentrant edit", lines()[#lines()])
        assert.same(original, vim.fn.readfile(path))
        assert.is_true(vim.bo[buf].modified)
        assert.truthy(bar():find("changed", 1, true), bar())
    end)

    it("never acknowledges native reload as the expected preparation edit", function()
        local production_edit = require("parley.buffer_edit").edit_user_lines
        require("parley.buffer_edit").edit_user_lines = function(...)
            vim.cmd("edit!")
            return production_edit(...)
        end
        press()
        -- Native reload can replace the controller and start a fresh admission
        -- lookup; let that read settle, while permitting no mutation or send.
        await(function() return document.status(buf).operation == nil end)
        no_send()
        assert.same(original, vim.fn.readfile(path))
    end)

    it("leaves the undoable unsaved fill after an ordinary write failure", function()
        local group = vim.api.nvim_create_augroup("EditorialSubmitWriteRefusal", { clear = true })
        vim.api.nvim_create_autocmd("BufWritePre", { group = group, buffer = buf,
            callback = function() error("fixture disk write refused") end })
        local ok, err = pcall(function()
            press()
            assert.same(filled, lines())
            assert.is_nil(document.status(buf).operation)
            assert.truthy(bar():find("save failed", 1, true), bar())
            assert.truthy(table.concat(notices, "\n"):find("fixture disk write refused", 1, true), vim.inspect(notices))
            no_send()
            assert.same(original, vim.fn.readfile(path))
            assert.is_true(vim.bo[buf].modified)
            vim.cmd("undo"); assert.same(original, lines())
        end)
        vim.api.nvim_del_augroup_by_id(group)
        assert.is_true(ok, tostring(err))
    end)

    it("joins a busy press during the actual preparation and delayed registry reply", function()
        local production_edit = require("parley.buffer_edit").edit_user_lines
        local stages = {}
        require("parley.buffer_edit").edit_user_lines = function(...)
            stages[#stages + 1] = document.status(buf).operation.preparation.stage
            document.submit(buf)
            return production_edit(...)
        end
        local held
        local couch = require("parley.couch")
        couch.run = function(argv, callback, options)
            return saved.run(argv, function(result)
                if argv[2] == "--session-sync" and argv[3] == "register" then
                    held = function() callback(result) end
                else callback(result) end
            end, options)
        end
        press()
        assert.same({ "awaiting-edit" }, stages)
        await(function() return held ~= nil end)
        document.submit(buf)
        assert.same(filled, lines())
        assert.equals(1, #edits)
        assert.same({}, sends())
        held()
        delivered()
        assert.equals(1, #sends())
    end)
end)
