describe("agentic markdown admission", function()
    local root, file, buf, saved, document
    local function await(predicate) assert.is_true(vim.wait(3000, predicate, 10)) end
    local function submit()
        local mapping = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg("<M-CR>", "n", false, true) end)
        assert.equals(1, mapping.buffer)
        mapping.callback()
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        file = root .. "/ordinary.md"
        vim.fn.writefile({ "---", "owner: business-team", "---", "# Question", "original", "tail" }, file)
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, scope = vim.env.COUCH_THREAD_SCOPE, tag = vim.env.COUCH_THREAD_TAG,
            registry = vim.env.FAKE_COUCH_REGISTRY, actors = vim.env.FAKE_COUCH_ACTORS,
            mode = vim.env.FAKE_COUCH_REGISTRY_MODE, state_dir = require("parley").config.state_dir,
            input = vim.ui.input, own_slot = require("parley.couch").own_slot }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "scope-test", "tag-test"
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "ops:0", Scope = "scope-test", Tag = "tag-test" } },
        } })
        require("parley").config.state_dir = root .. "/state"
        vim.ui.input = function() error("agentic submit must not ask for process-instruction") end
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        document = require("parley.agentic_document")
        require("parley").setup_markdown_keymaps(buf)
    end)
    after_each(function()
        for _, owned in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(owned) and vim.api.nvim_buf_get_name(owned):sub(1, #root + 1) == root .. "/" then
                if document then document.detach(owned) end
                vim.api.nvim_buf_delete(owned, { force = true })
            end
        end
        require("parley.document_registry").shutdown()
        vim.env.PATH, vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = saved.path, saved.scope, saved.tag
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_ACTORS = saved.registry, saved.actors
        vim.env.FAKE_COUCH_REGISTRY_MODE = saved.mode
        require("parley").config.state_dir, vim.ui.input = saved.state_dir, saved.input
        require("parley.couch").own_slot = saved.own_slot
        vim.fn.delete(root, "rf")
    end)
    it("opens plain, then saves registers and submits without changing frontmatter", function()
        await(function() return document.status(buf).phase == "plain" end)
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "edited question" })
        submit()
        await(function() return vim.fn.filereadable(root .. "/sent.last") == 1 end)
        assert.equals("submitted: " .. file, table.concat(vim.fn.readfile(root .. "/sent.last"), "\n"))
        assert.same({ "---", "owner: business-team", "---", "# Question", "edited question", "tail" }, vim.fn.readfile(file))
        assert.equals("ops:0", document.identity(buf).Owner)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "next edit" })
        await(function() return vim.fn.filereadable(file .. ".lock") == 1 end)
    end)
    it("leaves unknown editable then recovers outstanding auto-saved edits into a turn", function()
        await(function() return document.status(buf).phase == "plain" end)
        -- A separate actor registers while this editor cannot query it.
        local registry = require("parley.document_registry")
        local registered
        registry.request("register", { file, "ops:0" }, {}, function(r) registered = r end)
        await(function() return registered ~= nil end)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        document.recheck(buf)
        await(function() return document.status(buf).phase == "unknown" end)
        assert.is_true(vim.bo[buf].modifiable)
        assert.truthy(vim.wo.winbar:find("Couch unavailable: agentic state unknown", 1, true))
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "operator ahead" }); vim.cmd("silent write")
        assert.is_false(vim.bo[buf].modified)
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        document.recheck(buf)
        await(function() return document.identity(buf) ~= nil end)
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
    end)
    it("uses the known namespace cache on an offline reopen", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.identity(buf) ~= nil and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        document.detach(buf); vim.api.nvim_buf_delete(buf, { force = true })
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        require("parley").setup_markdown_keymaps(buf)
        assert.equals("ops:0", document.identity(buf).Owner)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "offline edit" })
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
    end)
    it("treats corrupt cached entries as unknown rather than blocking editing", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.identity(buf) ~= nil and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        local cache_file = vim.fn.glob(root .. "/state/document-cache/*/known.json")
        vim.fn.writefile({ '{"version":1,"entries":[1]}' }, cache_file)
        document.detach(buf); vim.api.nvim_buf_delete(buf, { force = true })
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        local ok, err = pcall(require("parley").setup_markdown_keymaps, buf)
        assert.is_true(ok, tostring(err))
        await(function() return document.status(buf).phase == "unknown" end)
        assert.is_true(vim.bo[buf].modifiable)
    end)
    it("transfers registered native saveas identity with its side folder and backlinks", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.identity(buf) ~= nil and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        local side = root .. "/ordinary.side"
        vim.fn.mkdir(side, "p")
        vim.fn.writefile({ "---", "parent: ../ordinary.md", "---", "[up](../ordinary.md#question)", "unrelated" }, side .. "/child.md")
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "held edit" })
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
        local id = document.identity(buf).ID
        local new = root .. "/renamed.md"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.identity(buf).File == new end)
        assert.equals(id, document.identity(buf).ID)
        assert.equals(1, vim.fn.filereadable(file)) -- saveas retains old copy.
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        assert.equals(1, vim.fn.filereadable(new .. ".lock"))
        assert.same({ "---", "parent: ../renamed.md", "---", "[up](../renamed.md#question)", "unrelated" }, vim.fn.readfile(root .. "/renamed.side/child.md"))
    end)
    it("recovers an uncertain published native move before admitting the reopened path", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.identity(buf) ~= nil and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "held edit" })
        local new = root .. "/recovered.md"
        vim.env.FAKE_COUCH_REGISTRY_MODE = "uncertain"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.status(buf).phase == "pending" end)
        document.detach(buf); vim.api.nvim_buf_delete(buf, { force = true })
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.cmd("edit " .. vim.fn.fnameescape(new)); buf = vim.api.nvim_get_current_buf()
        require("parley").setup_markdown_keymaps(buf)
        await(function() return vim.fn.filereadable(file .. ".lock") == 0 end)
        assert.equals(new, document.identity(buf).File)
        assert.equals(1, vim.fn.filereadable(new .. ".lock"))
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)
    it("does not send an edited in-flight registration and confirms it without automatic resend", function()
        await(function() return document.status(buf).phase == "plain" end)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "delay"
        submit()
        await(function()
            local op = document.status(buf).operation
            return op and op.witness.operation == "register"
        end)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "typed during registration" })
        await(function() return document.status(buf).phase == "pending" end)
        assert.equals(0, vim.fn.filereadable(root .. "/sent.last"))
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        submit()
        await(function() return document.status(buf).phase == "registered" end)
        assert.equals(0, vim.fn.filereadable(root .. "/sent.last"))
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
    end)
    it("confirms a newly saved couch-owner override before routing a registered submit", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.status(buf).phase == "registered" and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        vim.fn.delete(root .. "/sent.last")
        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "couch-owner: ops:9" })
        submit()
        await(function() return document.status(buf).phase == "registered" and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        local sent = vim.fn.readfile(root .. "/sent")
        assert.equals("ops:9|submitted: " .. file, sent[#sent])
        assert.equals("ops:9", document.identity(buf).Owner)
    end)
    it("retires confirmed absent registration after preserving its existing operator lock", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.identity(buf) ~= nil and vim.fn.filereadable(root .. "/sent.last") == 1 end)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "unsent edit" })
        local forgot = vim.system({ "couch", "--session-sync", "forget", file, "--json" }, { text = true }):wait(2000)
        assert.equals(0, forgot.code)
        document.recheck(buf)
        await(function() return document.status(buf).phase == "plain" end)
        assert.is_nil(document.identity(buf))
        assert.is_true(vim.bo[buf].modified)
        assert.equals(1, vim.fn.filereadable(file .. ".lock"))
    end)
    it("releases a synthetic free-turn migration lock after a successful unedited saveas", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.status(buf).phase == "registered" end)
        local new = root .. "/free-move.md"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.identity(buf).File == new end)
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        assert.equals(0, vim.fn.filereadable(new .. ".lock"))
    end)
    it("refuses an occupied target without overwriting it and permits no-effect return to OLD", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.status(buf).phase == "registered" end)
        local target = root .. "/occupied.md"
        vim.fn.writefile({ "other document" }, target)
        local registered
        require("parley.document_registry").request("register", { target, "ops:9" }, {}, function(r) registered = r end)
        await(function() return registered ~= nil end)
        assert.equals("registered", registered.kind)
        local ok = pcall(vim.cmd, "saveas! " .. vim.fn.fnameescape(target))
        assert.is_false(ok)
        assert.same({ "other document" }, vim.fn.readfile(target))
        ok = pcall(vim.cmd, "file " .. vim.fn.fnameescape(file))
        assert.is_true(ok)
        assert.equals(file, document.identity(buf).File)
        assert.equals("", vim.fn.glob(root .. "/state/document-moves/*/*.json"))
    end)
    it("admits and moves a .markdown document through the existing Markdown classifier", function()
        document.detach(buf); vim.api.nvim_buf_delete(buf, { force = true })
        file = root .. "/long-form.markdown"
        vim.fn.writefile({ "# Markdown", "question" }, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        require("parley").setup_markdown_keymaps(buf)
        assert.is_not_nil(document.status(buf))
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await(function() return document.status(buf).phase == "registered" end)
        local side = root .. "/long-form.side"
        vim.fn.mkdir(side, "p")
        vim.fn.writefile({ "[parent](../long-form.markdown)" }, side .. "/child.markdown")
        local new = root .. "/renamed.markdown"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.identity(buf).File == new end)
        assert.same({ "[parent](../renamed.markdown)" }, vim.fn.readfile(root .. "/renamed.side/child.markdown"))
    end)
    it("discards an own-actor result captured before the pane thread changed", function()
        await(function() return document.status(buf).phase == "plain" end)
        local couch = require("parley.couch")
        local original, observed = couch.own_slot, false
        couch.own_slot = function(callback)
            original(function(...)
                observed = true
                callback(...)
            end)
        end
        submit()
        vim.env.COUCH_THREAD_TAG = "replacement-tag"
        await(function() return observed end)
        couch.own_slot = original
        assert.equals("plain", document.status(buf).phase)
        assert.is_nil(document.status(buf).operation)
        assert.equals(0, vim.fn.filereadable(root .. "/sent.last"))
        assert.equals(0, vim.fn.filereadable(root .. "/registry.json"))
    end)
end)
