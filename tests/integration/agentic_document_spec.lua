describe("agentic markdown admission", function()
    local root, file, buf, saved, document
    local function sent_payload()
        local stream = io.open(root .. "/sent.last", "rb")
        if not stream then return nil end
        local bytes = stream:read("*a")
        stream:close()
        return bytes
    end
    -- An end-to-end admission can include lookup, actor resolution, register,
    -- send and scheduled completions. Each production request keeps its own
    -- deadline; the test budget also permits suite-wide process contention.
    local function await(predicate)
        local ready, reason = vim.wait(10000, predicate, 10)
        assert.is_true(ready, vim.inspect({
            wait_reason = reason, path = file,
            lifecycle = document and buf and document.status(buf),
            sent_payload = sent_payload(),
            modified = buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified,
        }))
    end
    local function await_submitted()
        await(function()
            local status = document.status(buf)
            return status and status.phase == "registered" and not status.operation
                and document.identity(buf) ~= nil and sent_payload() == "submitted: " .. file
        end)
    end
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
            input = vim.ui.input, own_slot = require("parley.couch").own_slot,
            couch_run = require("parley.couch").run, ping_check = require("parley.session_sync").PING_CHECK_MS,
            exit = vim.env.FAKE_COUCH_EXIT, sleep = vim.env.FAKE_COUCH_SLEEP,
            log_delay = vim.env.FAKE_COUCH_LOG_DELAY, status = vim.env.FAKE_COUCH_STATUS }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "scope-test", "tag-test"
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP = "0", nil
        vim.env.FAKE_COUCH_LOG_DELAY, vim.env.FAKE_COUCH_STATUS = nil, nil
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
        vim.env.FAKE_COUCH_EXIT, vim.env.FAKE_COUCH_SLEEP = saved.exit, saved.sleep
        vim.env.FAKE_COUCH_LOG_DELAY, vim.env.FAKE_COUCH_STATUS = saved.log_delay, saved.status
        require("parley").config.state_dir, vim.ui.input = saved.state_dir, saved.input
        require("parley.couch").own_slot = saved.own_slot
        require("parley.couch").run = saved.couch_run
        require("parley.session_sync").PING_CHECK_MS = saved.ping_check
        vim.fn.delete(root, "rf")
    end)
    it("opens plain, then saves registers and submits without changing frontmatter", function()
        await(function() return document.status(buf).phase == "plain" end)
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "edited question" })
        submit()
        await_submitted()
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
        submit(); await_submitted()
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
        submit(); await_submitted()
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
        submit(); await_submitted()
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
        submit(); await_submitted()
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
        submit(); await_submitted()
        vim.fn.delete(root .. "/sent.last")
        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "couch-owner: ops:9" })
        submit()
        await_submitted()
        local sent = vim.fn.readfile(root .. "/sent")
        assert.equals("ops:9|submitted: " .. file, sent[#sent])
        assert.equals("ops:9", document.identity(buf).Owner)
    end)
    it("retires confirmed absent registration after preserving its existing operator lock", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
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
        submit(); await_submitted()
        local new = root .. "/free-move.md"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.identity(buf).File == new end)
        assert.equals(0, vim.fn.filereadable(file .. ".lock"))
        assert.equals(0, vim.fn.filereadable(new .. ".lock"))
    end)
    it("refuses an occupied target without overwriting it and permits no-effect return to OLD", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
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
        submit(); await_submitted()
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

    local function feedback_bar()
        return vim.wo[vim.fn.bufwinid(buf)].winbar
    end
    local function success_feedback()
        return feedback_bar():find("submitted to ops:0 · %d%d:%d%d") ~= nil
    end
    local function error_feedback()
        local text=feedback_bar():lower()
        return text:find("failed",1,true) ~= nil or text:find("error",1,true) ~= nil
    end

    it("retains submitted owner and time through refresh and save until an operator or agent edit", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit()
        await_submitted()
        assert.is_true(success_feedback(),feedback_bar())
        local submitted_bar=feedback_bar()
        local probe_finished=false
        local couch=require("parley.couch")
        local production_run=couch.run
        -- Observe completion while preserving the real subprocess and reply.
        -- Changed owed knowledge forces the ordinary probe refresh path.
        couch.run=function(argv,callback,options)
            return production_run(argv,function(result)
                callback(result)
                if argv[2] == "--session-sync" and argv[3] == "status" then probe_finished=true end
            end,options)
        end
        require("parley.session_sync").PING_CHECK_MS=0
        vim.env.FAKE_COUCH_STATUS=vim.json.encode({Code="ok",Status={Owed={
            {ID="feedback-probe",Kind="delivery",At=os.date("!%Y-%m-%dT%H:%M:%SZ",os.time()-60)},
        }}})
        await(function() return probe_finished end)
        assert.equals(submitted_bar,feedback_bar(),"completed owed probe must retain submission feedback")
        vim.cmd("silent write")
        vim.api.nvim_exec_autocmds("BufWinEnter",{buffer=buf})
        await(function() local status=document.status(buf); return status.phase == "registered" and not status.operation end)
        assert.equals(submitted_bar,feedback_bar(),"refresh, lookup and plain write must retain submission feedback")
        vim.api.nvim_buf_set_lines(buf,4,5,false,{"next operator edit"})
        assert.is_false(success_feedback(),"operator edit must clear prior submission feedback")
        submit()
        await_submitted()
        assert.is_true(success_feedback(),feedback_bar())
        local answer=vim.fn.readfile(file)
        answer[5]="agent reply after submission"
        vim.fn.writefile(answer,file)
        vim.cmd("checktime")
        await(function() return vim.api.nvim_buf_get_lines(buf,4,5,false)[1] == answer[5] end)
        assert.is_false(success_feedback(),"observed agent write must clear submission feedback")
    end)

    it("shows registration failure in the winbar before a turn engine is attached", function()
        await(function() return document.status(buf).phase == "plain" end)
        assert.is_nil(require("parley.session_sync").identity(buf))
        vim.env.FAKE_COUCH_REGISTRY_MODE="unsupported"
        submit()
        await(function() return document.status(buf).phase == "pending" end)
        assert.is_true(error_feedback(),feedback_bar())
        assert.is_false(success_feedback())
        assert.is_true(vim.bo[buf].modifiable)
        assert.is_nil(require("parley.session_sync").identity(buf))
        assert.is_nil(sent_payload())
    end)

    it("shows failed owner confirmation while retaining the attached operator turn", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit()
        await_submitted()
        vim.api.nvim_buf_set_lines(buf,4,5,false,{"unsent owner-confirmation edit"})
        local old_payload=sent_payload()
        local old_deliveries=vim.fn.readfile(root .. "/sent")
        vim.env.FAKE_COUCH_REGISTRY_MODE="unsupported"
        submit()
        await(function() local status=document.status(buf); return status.phase == "registered" and not status.operation end)
        assert.is_true(error_feedback(),feedback_bar())
        assert.is_false(success_feedback())
        assert.equals(1,vim.fn.filereadable(file .. ".lock"))
        assert.equals(old_payload,sent_payload())
        assert.same(old_deliveries,vim.fn.readfile(root .. "/sent"),"failed lookup must not send again")
    end)

    it("shows unresolved pane owner in the winbar without attaching or sending", function()
        await(function() return document.status(buf).phase == "plain" end)
        vim.env.FAKE_COUCH_ACTORS=vim.json.encode({Code="ok",Actors={}})
        submit()
        await(error_feedback)
        assert.is_false(success_feedback())
        assert.is_nil(document.identity(buf))
        assert.is_nil(require("parley.session_sync").identity(buf))
        assert.is_nil(sent_payload())
        assert.is_true(vim.bo[buf].modifiable)
    end)

    it("shows send failure in the winbar while retaining registration", function()
        await(function() return document.status(buf).phase == "plain" end)
        vim.env.FAKE_COUCH_EXIT="1"
        submit()
        await(function()
            local status=document.status(buf)
            return status.phase == "registered" and not status.operation and sent_payload() == "submitted: " .. file
        end)
        assert.is_true(error_feedback(),feedback_bar())
        assert.is_false(success_feedback())
        assert.is_not_nil(document.identity(buf))
        vim.api.nvim_exec_autocmds("BufWinEnter",{buffer=buf})
        await(function() local status=document.status(buf); return status.phase == "registered" and not status.operation end)
        assert.is_true(error_feedback(),"ordinary refresh must not silently clear send failure")
    end)

    local function deliveries()
        return vim.fn.filereadable(root .. "/sent") == 1 and vim.fn.readfile(root .. "/sent") or {}
    end
    local function settled()
        local status = document.status(buf)
        return status and status.phase == "registered" and not status.operation
    end
    local function unchanged_feedback()
        return feedback_bar():find("nothing to submit: no changes since %d%d:%d%d") ~= nil
    end

    it("skips unchanged content, explicitly resends on a second press, and sends changed content", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
        assert.equals(1, #deliveries())
        submit(); await(settled)
        assert.is_true(unchanged_feedback(), feedback_bar())
        assert.equals(1, #deliveries(), "unchanged press must not deliver")
        submit(); await(settled)
        assert.truthy(feedback_bar():find("resent to ops:0 · %d%d:%d%d"), feedback_bar())
        assert.equals(2, #deliveries())
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "changed after receipt" })
        vim.cmd("silent write") -- immediate auto-save does not advance the receipt
        submit(); await(settled)
        assert.is_true(success_feedback(), feedback_bar())
        assert.equals(3, #deliveries())
        for _, line in ipairs(deliveries()) do assert.equals("ops:0|submitted: " .. file, line) end
    end)

    it("does not remember a failed delivery as successfully submitted content", function()
        await(function() return document.status(buf).phase == "plain" end)
        vim.env.FAKE_COUCH_EXIT = "1"
        submit(); await(settled)
        assert.is_true(error_feedback(), feedback_bar())
        vim.env.FAKE_COUCH_EXIT = "0"
        submit(); await(settled)
        assert.is_true(success_feedback(), feedback_bar())
        assert.equals(2, #deliveries())
        submit(); await(settled)
        assert.is_true(unchanged_feedback(), feedback_bar())
        assert.equals(2, #deliveries())
    end)

    it("coalesces busy owner-confirmation presses without a delayed resend", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
        local couch = require("parley.couch")
        local production_run, finish = couch.run, nil
        couch.run = function(argv, callback, options)
            return production_run(argv, function(result)
                if argv[2] == "--session-sync" and argv[3] == "lookup" then
                    finish = function() callback(result) end
                else callback(result) end
            end, options)
        end
        submit()
        await(function() return finish ~= nil end)
        submit(); submit()
        finish()
        await(settled)
        assert.is_true(unchanged_feedback(), feedback_bar())
        assert.equals(1, #deliveries())
        assert.is_nil(document.status(buf).operation)
    end)

    it("ignores a busy background lookup press even when a resend confirmation was armed", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
        submit(); await(settled)
        assert.is_true(unchanged_feedback(), feedback_bar())
        local couch = require("parley.couch")
        local production_run, finish = couch.run, nil
        couch.run = function(argv, callback, options)
            return production_run(argv, function(result)
                if argv[2] == "--session-sync" and argv[3] == "lookup" then
                    finish = function() callback(result) end
                else callback(result) end
            end, options)
        end
        document.recheck(buf)
        await(function() return finish ~= nil end)
        submit()
        finish()
        await(settled) -- registry replies are scheduled; a queued second lookup remains held by this fake
        assert.is_nil(document.status(buf).operation, "busy press must not schedule a second lookup or resend")
        assert.equals(1, #deliveries())
        assert.is_true(unchanged_feedback(), feedback_bar())
    end)

    it("records the issued hash but suppresses success feedback after a later edit", function()
        await(function() return document.status(buf).phase == "plain" end)
        local couch = require("parley.couch")
        local production_run, finish = couch.run, nil
        couch.run = function(argv, callback, options)
            return production_run(argv, function(result)
                if argv[1] == "couch" and argv[2] == "--send-to" then
                    finish = function() callback(result) end
                else callback(result) end
            end, options)
        end
        submit()
        await(function() return finish ~= nil end)
        vim.api.nvim_buf_set_lines(buf, 4, 5, false, { "new unsent edit while delivery pending" })
        finish(); await(settled)
        assert.is_false(success_feedback(), feedback_bar())
        assert.equals(1, vim.fn.filereadable(file .. ".lock"), "late delivery must not release a newer edit turn")
        couch.run = production_run
        submit(); await(settled)
        assert.is_true(success_feedback(), feedback_bar())
        assert.equals(2, #deliveries(), "the later edit still needs its own delivery")
    end)

    it("suppresses a delayed success receipt after an agent write reloads the buffer", function()
        await(function() return document.status(buf).phase == "plain" end)
        local couch = require("parley.couch")
        local production_run, finish = couch.run, nil
        couch.run = function(argv, callback, options)
            return production_run(argv, function(result)
                if argv[1] == "couch" and argv[2] == "--send-to" then
                    finish = function() callback(result) end
                else callback(result) end
            end, options)
        end
        submit()
        await(function() return finish ~= nil end)
        local answer = vim.fn.readfile(file)
        answer[5] = "agent wrote before delivery callback"
        vim.fn.writefile(answer, file)
        vim.cmd("checktime")
        await(function() return vim.api.nvim_buf_get_lines(buf, 4, 5, false)[1] == answer[5] end)
        finish(); await(settled)
        assert.is_false(success_feedback(), feedback_bar())
        couch.run = production_run
        submit(); await(settled)
        assert.is_true(success_feedback(), feedback_bar())
        assert.equals(2, #deliveries())
    end)

    it("preserves successful content receipts across confirmed native saveas", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
        local new = root .. "/receipt-renamed.md"
        vim.cmd("saveas " .. vim.fn.fnameescape(new))
        await(function() return document.identity(buf).File == new and settled() end)
        submit(); await(settled)
        assert.is_true(unchanged_feedback(), feedback_bar())
        assert.equals(1, #deliveries())
        submit(); await(settled)
        assert.equals("ops:0|submitted: " .. new, deliveries()[2])
    end)

    it("forgets the in-memory submit receipt on detach and reopen", function()
        await(function() return document.status(buf).phase == "plain" end)
        submit(); await_submitted()
        document.detach(buf); vim.api.nvim_buf_delete(buf, { force = true })
        vim.cmd("edit " .. vim.fn.fnameescape(file)); buf = vim.api.nvim_get_current_buf()
        require("parley").setup_markdown_keymaps(buf)
        await(settled)
        submit(); await(settled)
        assert.is_true(success_feedback(), feedback_bar())
        assert.equals(2, #deliveries())
    end)

end)
