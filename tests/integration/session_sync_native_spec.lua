-- Real input order matters: the operator's global auto-save is installed before
-- the session buffer, so TextChanged can save before session-sync sees it (#324).
local arrival = require("tests.helpers.arrival")
local Embedded = require("tests.helpers.embedded_nvim")
describe("session-sync native edits", function()
    local child, root, file, sent_file
    local function exec(code, ...)
        return child:exec(code, ...)
    end
    local function exists() return vim.uv.fs_stat(file .. ".lock") ~= nil end
    local function keys(value)
        child:input(value)
    end
    local function wait_for(code)
        assert.is_true(vim.wait(arrival.MS, function() return exec(code) end), code)
    end
    -- A visible path may still be empty or partially written by the child.
    -- Every positive file assertion waits for its complete expected payload.
    local function payload(path, expected)
        local observed
        local ready = vim.wait(arrival.MS, function()
            local ok, lines = pcall(vim.fn.readfile, path, "b")
            if not ok or lines[#lines] ~= "" then return false end
            table.remove(lines) -- the terminating newline proves the last line arrived.
            observed = lines
            if not expected(lines) then return false end
            observed = lines
            return true
        end)
        assert.is_true(ready, "expected complete payload missing: " .. path .. " observed=" .. vim.inspect(observed))
        return observed
    end
    local function locked()
        payload(file .. ".lock", function(lines) return lines[1] == "holder: operator" end)
    end
    local function notified(kind)
        return payload(sent_file, function(lines)
            return #lines == 1 and lines[1]:find("ops:0|" .. kind .. ":", 1, true) == 1
        end)
    end
    local function open(autosave, undo, slow_watch, registered)
        exec([[
            local path, autosave, undo, slow_watch, registered = ...
            _G.path, _G.auto_save, _G.pre_save_lock = path, autosave, nil
            vim.api.nvim_create_autocmd("TextChanged", { pattern = "*.md", callback = function()
                _G.pre_save_lock = vim.fn.filereadable(path .. ".lock")
            end })
            -- Same callback/order as the operator's core/options.lua. The switch
            -- lets undo tests observe the unmodified state without auto-saving it.
            vim.api.nvim_create_autocmd({"InsertLeave", "TextChanged"}, {
                pattern = "*.md", callback = function()
                    if auto_save and vim.bo.modified and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
                        vim.cmd("silent! write")
                    end
                end,
            })
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            if undo then
                vim.api.nvim_buf_set_lines(0, 7, 8, false, {"saved version"})
                vim.cmd("silent write")
            end
            -- Seed dot in another buffer without changing the session file.
            local session = vim.api.nvim_get_current_buf()
            local scratch = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_set_current_buf(scratch)
            vim.api.nvim_buf_set_lines(0, 0, -1, false, {"seed"})
            vim.cmd("normal! x")
            vim.api.nvim_set_current_buf(session)
            vim.api.nvim_buf_delete(scratch, {force=true})
            vim.fn.setreg('a', 'pasted')
            local ss = require("parley.session_sync")
            ss.POLL_MS = slow_watch and 60000 or 20
            if registered then
                ss.attach(session, { ID = "doc-1", File = path, Owner = "ops:0", RegisteredOwner = "ops:0", RegisteredAt = "now" })
            else
                require("parley").setup_markdown_keymaps(session)
            end
            vim.api.nvim_win_set_cursor(0, {8,0})
        ]], file, autosave, undo, slow_watch, registered)
    end
    local function agent_reload(checktime)
        local lines = vim.fn.readfile(file)
        lines[8] = "agent reply"
        vim.fn.writefile(lines, file)
        if checktime then exec("vim.cmd('checktime')") end
        wait_for([[return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == "agent reply"]])
        assert.is_false(exec("return vim.bo.modified"))
        assert.is_false(exists())
        exec("vim.api.nvim_win_set_cursor(0,{8,0}); _G.pre_save_lock=nil")
    end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        file, sent_file = root .. "/status.md", root .. "/sent"
        vim.fn.writefile({"---", "type: session-sync", "owner: ops:0", "operator: test", "---", "", "## Operator instructions", "first bullet", "second bullet", "third bullet"}, file)
        require("tests.helpers.fake_couch").write(root, sent_file, root .. "/argv")
        child = Embedded.start({ ui = { 100, 30 } })
        exec([[
            local root = ...
            -- Capture notifications without builtin vim.notify's hit-enter UI;
            -- foreign-write warnings are asserted through the fake owner's log.
            _G.notifications = {}
            vim.notify = function(message) notifications[#notifications+1] = message end
            vim.env.PATH = root .. "/bin:" .. vim.env.PATH
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.FAKE_COUCH_STATUS = nil
            vim.env.FAKE_COUCH_LOG_DELAY = "0.1"
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
        ]], root)
    end)
    after_each(function()
        child:stop()
        vim.fn.delete(root, "rf")
    end)

    for _, kind in ipairs({"registered session", "registered side doc"}) do
        it(kind .. " locks on actual insert entry and releases unchanged escape (#404)", function()
            if kind == "registered side doc" then
                local original = file
                file = root .. "/session.side/discussion.md"
                vim.fn.mkdir(root .. "/session.side", "p")
                vim.fn.writefile(vim.fn.readfile(original), file)
                local lines = vim.fn.readfile(file)
                lines[2] = "type: prose"
                vim.fn.writefile(lines, file)
            end
            open(true, false, true, true)
            keys("i")
            wait_for("return vim.fn.mode() == 'i'")
            assert.is_true(exists(), "insert turn was not protected")
            locked()
            assert.is_false(exec("return vim.bo.modified"))
            assert.is_true(exec("return vim.wo.winbar:find('yours',1,true) ~= nil"))
            keys("<Esc>")
            wait_for("return vim.fn.mode() == 'n'")
            assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "unchanged escape kept lock")
            assert.is_nil(vim.uv.fs_stat(sent_file), "unchanged exit sent a submission")
        end)
    end

    -- Hold a real fake-backed discovery reply, not a fabricated registration.
    -- The release runs inside native InsertEnter while queued input is waiting.
    local function pending_lookup(delay, absent)
        open(false, false, true, true)
        exec([[
            local root, delay, absent = ...
            require("parley.session_sync").detach(0)
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "scope-410", "tag-410"
            vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
            local identity = {ID="doc-1", File=path, Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="now"}
            vim.fn.writefile({vim.json.encode({paths=absent and {} or {[path]=identity},moves={}})},vim.env.FAKE_COUCH_REGISTRY)
            local couch = require("parley.couch")
            _G.pending_original_run = _G.pending_original_run or couch.run
            _G.pending_original_acquire = _G.pending_original_acquire or couch.operator_lock
            local run, acquire = pending_original_run, pending_original_acquire
            _G.lookup_launches, _G.acquire_calls, _G.acquire_acknowledged = 0, 0, nil
            _G.before_first_char, _G.release_lookup, _G.lookup_action = nil, nil, nil
            couch.run = function(argv, callback, options)
                if argv[2]=="--session-sync" and argv[3]=="lookup" then
                    lookup_launches = lookup_launches + 1
                    return run(argv, function(result)
                        _G.release_lookup = function() callback(result) end
                    end, options)
                end
                return run(argv, callback, options)
            end
            couch.operator_lock = function(verb, ...)
                if verb=="acquire" then
                    acquire_calls=acquire_calls+1
                    local args={...}
                    _G.acquire_remaining=args[3] and args[3]-vim.uv.hrtime()/1e6
                end
                local result = acquire(verb, ...)
                if verb=="acquire" then _G.acquire_acknowledged=result.kind=="confirmed" end
                return result
            end
            vim.api.nvim_create_autocmd("InsertCharPre",{buffer=0,callback=function()
                _G.first_char_confirmed=acquire_acknowledged==true
                _G.before_first_char=vim.api.nvim_buf_get_lines(0,7,8,false)[1]
                _G.entry_elapsed=(vim.uv.hrtime()-entry_started)/1e6
            end})
            vim.api.nvim_create_autocmd("InsertEnter",{buffer=0,callback=function()
                _G.entry_started=vim.uv.hrtime()
                if delay then vim.defer_fn(function()
                    if _G.lookup_action then lookup_action() else release_lookup() end
                end,delay) end
            end})
            require("parley.agentic_document").attach(vim.api.nvim_get_current_buf())
        ]], root, delay, absent)
        wait_for("return type(release_lookup)=='function'")
    end

    for _, kind in ipairs({"parent", "side"}) do
        it("pending lookup protects queued first input in " .. kind .. " (#410)", function()
            if kind=="side" then
                local lines=vim.fn.readfile(file);lines[2]="type: prose";vim.fn.writefile(lines,file)
            end
            pending_lookup(50)
            local fresh=vim.fn.readfile(file);fresh[8]="fresh pending lookup"
            exec("vim.env.FAKE_COUCH_OPERATOR_ACQUIRE_WRITE=...",table.concat(fresh,"\n").."\n")
            keys("iX")
            wait_for("return _G.before_first_char ~= nil")
            assert.is_true(exec("return first_char_confirmed"),"queued input preceded pending lookup acquisition")
            assert.equals("fresh pending lookup",exec("return before_first_char"))
            assert.equals("Xfresh pending lookup",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            assert.equals(1,exec("return lookup_launches"))
            assert.equals(1,exec("return acquire_calls"))
            keys("<Esc>")
        end)
    end

    it("pending lookup exhausts one budget then reconciles late edits (#410)",function()
        pending_lookup(nil)
        keys("iX")
        wait_for("return _G.before_first_char ~= nil")
        assert.is_true(exec("return entry_elapsed>=450"),"pending lookup admitted input before budget expired")
        assert.is_true(exec("return entry_elapsed<1500"),"pending input exceeded 500 ms plus scheduling allowance")
        assert.is_true(exec("return require('parley.agentic_document').identity(vim.api.nvim_get_current_buf())==nil"))
        assert.equals(0,exec("return acquire_calls"))
        exec("vim.cmd('silent write');release_lookup()")
        wait_for("return require('parley.agentic_document').identity(vim.api.nvim_get_current_buf()) ~= nil")
        assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        keys("<Esc>")
        wait_for("return vim.fn.mode()=='n'")
        assert.is_true(exists(),"late attachment lost autosaved outstanding edit baseline")
    end)

    it("nested late attachment consumes only the original residual budget (#410)",function()
        pending_lookup(300)
        exec("vim.env.FAKE_COUCH_OPERATOR_DELAY='2'")
        keys("iX")
        wait_for("return _G.before_first_char ~= nil")
        local evidence=exec("return {elapsed=entry_elapsed,remaining=acquire_remaining,calls=acquire_calls}")
        assert.equals(1,evidence.calls)
        assert.is_true(evidence.remaining<=210,vim.inspect(evidence))
        assert.is_true(evidence.elapsed>=450,vim.inspect(evidence))
        assert.is_true(evidence.elapsed<500+arrival.MS,vim.inspect(evidence))
        assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        assert.is_true(exec([[return vim.wo.winbar:find("not locked: Couch unreachable",1,true)~=nil]]))
        keys("<Esc>")
    end)

    for _, fault in ipairs({"held","invalid"}) do
        it("pending lookup keeps "..fault.." acquisition refusal before input (#410)",function()
            pending_lookup(50)
            exec([[
                if ...=="held" then
                    vim.env.FAKE_COUCH_OPERATOR_CODE="operator-lock";vim.env.FAKE_COUCH_OPERATOR_EXIT="3"
                else vim.env.FAKE_COUCH_OPERATOR_ACK="{}" end
            ]],fault)
            keys("iX")
            wait_for("return not vim.bo.modifiable")
            assert.equals(1,exec("return acquire_calls"))
            assert.equals("first bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            keys("<Esc>")
        end)
    end

    it("absent pending lookup admits a plain file without a new input lookup (#410)",function()
        pending_lookup(50,true)
        keys("iX")
        wait_for("return _G.before_first_char ~= nil")
        assert.equals(0,exec("return acquire_calls"))
        assert.equals(1,exec("return lookup_launches"))
        assert.is_true(exec("return require('parley.agentic_document').identity(vim.api.nvim_get_current_buf())==nil"))
        keys("<Esc>iY")
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]:find('Y',1,true)~=nil")
        assert.equals(1,exec("return lookup_launches"),"plain entry launched another synchronous discovery")
        keys("<Esc>")
    end)

    for _, change in ipairs({"detach","rename"}) do
        it("stale pending lookup cannot gate after "..change.." (#410)",function()
            pending_lookup(50)
            exec([[
                local change=...
                _G.lookup_action=function()
                    if change=="detach" then require("parley.agentic_document").detach(vim.api.nvim_get_current_buf())
                    else vim.api.nvim_buf_set_name(0,path..".renamed.md") end
                    release_lookup()
                end
            ]],change)
            keys("iX")
            wait_for("return _G.before_first_char ~= nil")
            assert.equals(0,exec("return acquire_calls"))
            assert.is_true(exec("return require('parley.agentic_document').identity(vim.api.nvim_get_current_buf())==nil"))
            assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            keys("<Esc>")
        end)
    end

    local pending_read_counts={}
    for _, count in ipairs({4,8}) do
        it("bounds discovery, acquisition and full reads for "..count.." pending entries (#410)",function()
            local lines=vim.fn.readfile(file)
            exec([[
                _G.full_reads=0
                local get_lines=vim.api.nvim_buf_get_lines
                vim.api.nvim_buf_get_lines=function(buf,start,stop,strict)
                    if start==0 and stop==-1 then full_reads=full_reads+1 end
                    return get_lines(buf,start,stop,strict)
                end
            ]])
            local lookups,acquires=0,0
            for index=1,count do
                file=root.."/entry-"..index..".md"
                vim.fn.writefile(lines,file)
                pending_lookup(5)
                keys("i")
                wait_for("return vim.fn.mode()=='i' and acquire_calls==1")
                lookups=lookups+exec("return lookup_launches")
                acquires=acquires+exec("return acquire_calls")
                keys("<Esc>")
                wait_for("return vim.fn.mode()=='n'")
                assert.is_true(vim.wait(arrival.MS,function() return not exists() end))
                exec("require('parley.agentic_document').detach(vim.api.nvim_get_current_buf())")
            end
            assert.equals(count,lookups,"input launched extra discovery")
            assert.equals(count,acquires,"attachment acquired more than once per input scope")
            local reads=exec("return full_reads")
            assert.is_true(reads>=2*count and reads<=50*count,"unexpected full-buffer work: "..reads)
            pending_read_counts[count]=reads
            if count==8 then
                assert.is_true(reads<=2*pending_read_counts[4]+4,"full-buffer work grew faster than entry count: "..reads)
            end
        end)
    end

    it("insert intent stays locked after typing back to the baseline until escape (#404)", function()
        open(true, false, true, true)
        keys("ix<C-h>")
        wait_for("return vim.fn.mode() == 'i' and vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
        exec("vim.schedule(function() _G.insert_settled=true end)")
        wait_for("return _G.insert_settled == true")
        assert.is_true(exists(), "insert turn was not protected")
        locked()
        keys("<Esc>")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
    end)

    it("auto-saved changes survive escape and insert re-entry until submit (#404)", function()
        open(true, false, true, true)
        keys("iX<Esc>")
        wait_for("return vim.fn.mode() == 'n' and not vim.bo.modified")
        assert.is_true(exists(), "insert turn was not protected")
        locked()
        keys("i<Esc>")
        exec("vim.schedule(function() _G.insert_settled=true end)")
        wait_for("return _G.insert_settled == true")
        assert.is_true(exists(), "insert turn was not protected")
        locked()
        exec("require('parley.session_sync').submit(0)")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
        notified("submitted")
    end)

    it("late registration during insert takes the turn before any keystroke (#404)", function()
        open(false, false, true, true)
        exec("require('parley.session_sync').detach(0)")
        keys("i")
        wait_for("return vim.fn.mode() == 'i'")
        assert.is_false(exists())
        exec("require('parley.session_sync').attach(0,{ID='doc-1',File=path,Owner='ops:0'})")
        assert.is_true(exists(), "insert turn was not protected")
        locked()
        keys("<Esc>")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
    end)

    for _, replacement in ipairs({false, true}) do
        it("unchanged escape preserves " .. (replacement and "replacement" or "pre-existing") .. " lock (#404)", function()
            local foreign = {"holder: operator", "time: 2000-01-01T00:00:00Z", "foreign: true"}
            if not replacement then vim.fn.writefile(foreign, file .. '.lock') end
            open(false, false, true, true)
            keys("i")
            wait_for("return vim.fn.mode() == 'i'")
            if replacement then vim.fn.writefile(foreign, file .. '.lock') end
            keys("<Esc>")
            wait_for("return vim.fn.mode() == 'n'")
            assert.same(foreign, vim.fn.readfile(file .. '.lock'))
        end)
    end

    for _, kind in ipairs({"parent", "side"}) do
        it("confirmed insert reloads before queued first edit in " .. kind .. " (#408)", function()
            if kind == "side" then
                local lines=vim.fn.readfile(file); lines[2]="type: prose"
                vim.fn.writefile(lines,file)
            end
            open(false,false,true,true)
            local fresh=vim.fn.readfile(file);fresh[8]="fresh before acknowledgment"
            exec([[
                vim.env.FAKE_COUCH_OPERATOR_ACQUIRE_WRITE=...
                vim.env.FAKE_COUCH_OPERATOR_DELAY="0.1"
                _G.first_edit=nil
                local couch=require("parley.couch"); local acquire=couch.operator_lock
                couch.operator_lock=function(verb,...)
                    local result=acquire(verb,...)
                    if verb=="acquire" then _G.acquire_acknowledged=result.kind=="confirmed" end
                    return result
                end
                vim.api.nvim_create_autocmd("InsertCharPre",{buffer=0,callback=function()
                    _G.first_char_confirmed=acquire_acknowledged==true
                    _G.before_first_char=vim.api.nvim_buf_get_lines(0,7,8,false)[1]
                end})
                vim.api.nvim_buf_attach(0,false,{on_reload=function() end, on_lines=function(_,buf)
                    first_edit=first_edit or vim.api.nvim_buf_get_lines(buf,7,8,false)[1]
                end})
            ]],table.concat(fresh,"\n").."\n")
            keys("iX")
            wait_for("return _G.first_edit ~= nil")
            assert.is_true(exec("return first_char_confirmed"),"first character preceded acquisition acknowledgment")
            assert.equals("fresh before acknowledgment",exec("return before_first_char"))
            assert.equals("Xfresh before acknowledgment",exec("return first_edit"))
            assert.equals("Xfresh before acknowledgment",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            local text=table.concat(vim.fn.readfile(file..".lock"),"\n")
            assert.truthy(text:find("document: doc-1",1,true))
            assert.truthy(text:match("turn: [0-9a-f]+"))
            assert.is_nil(vim.uv.fs_stat(file..".clobbered"))
            assert.is_nil(vim.uv.fs_stat(sent_file))
            keys("<Esc>")
        end)
    end

    for _, fault in ipairs({
        {name="held", code="operator-lock", exit="3"},
        {name="uncertain", code="operator-lock-uncertain", exit="1"},
        {name="malformed", ack="{}"},
    }) do
        it("blocks queued insert edits for "..fault.name.." acknowledgment (#408)",function()
            open(false,false,true,true)
            exec([[
                local fault=...
                vim.env.FAKE_COUCH_OPERATOR_CODE=fault.code
                vim.env.FAKE_COUCH_OPERATOR_EXIT=fault.exit
                vim.env.FAKE_COUCH_OPERATOR_ACK=fault.ack
            ]],fault)
            keys("iX")
            wait_for("return vim.fn.mode() == 'i'")
            assert.is_false(exec("return vim.bo.modifiable"))
            assert.equals("first bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            assert.is_true(exec([[return table.concat(notifications,"\n"):find("not applied",1,true)~=nil]]))
            keys("<Esc>")
        end)
    end

    for _, timeout in ipairs({false,true}) do
        it("allows queued edits with an unconfirmed warning on "..(timeout and "500 ms timeout" or "store unavailable").." (#408)",function()
            open(true,false,true,true)
            exec([[
                local timeout=...
                require("parley.session_sync").set_submission_feedback(0,"previous submit accepted",false)
                if timeout then vim.env.FAKE_COUCH_OPERATOR_DELAY="2"
                else vim.env.FAKE_COUCH_OPERATOR_CODE="session-sync-unavailable";vim.env.FAKE_COUCH_OPERATOR_EXIT="7" end
            ]],timeout)
            local started=vim.uv.hrtime()
            keys("iX")
            wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'Xfirst bullet'")
            local elapsed=(vim.uv.hrtime()-started)/1e6
            if timeout then
                assert.is_true(elapsed>=450,"timeout returned before its 500 ms budget")
                assert.is_true(elapsed<500+arrival.MS,"timeout exceeded bounded arrival allowance")
            end
            assert.is_true(exec("return vim.bo.modifiable"))
            assert.is_true(exec([[return vim.wo.winbar:find("not locked: Couch unreachable; edits may conflict",1,true)~=nil]]))
            keys("<Esc>")
            exec("vim.cmd('silent write')")
            local foreign=vim.fn.readfile(file);foreign[8]="agent competing copy";vim.fn.writefile(foreign,file)
            exec("vim.cmd('checktime')")
            wait_for([[return vim.fn.filereadable(vim.api.nvim_buf_get_name(0)..'.clobbered')==1]])
            assert.equals("agent competing copy",vim.fn.readfile(file..".clobbered")[8])
            assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        end)
    end

    it("unavailable admission warning outranks a previous submit before typing (#408)",function()
        open(false,false,true,true)
        exec([[
            require("parley.session_sync").set_submission_feedback(0,"previous submit accepted",false)
            vim.env.FAKE_COUCH_OPERATOR_CODE="session-sync-unavailable"
            vim.env.FAKE_COUCH_OPERATOR_EXIT="7"
        ]])
        keys("i");wait_for("return vim.fn.mode()=='i'")
        assert.is_true(exec([[return vim.wo.winbar:find("not locked: Couch unreachable; edits may conflict",1,true)~=nil]]))
        keys("<Esc>")
    end)

    for _, intervening_refusal in ipairs({false,true}) do
        it("preserves saved unconfirmed edits through "..(intervening_refusal and "a refused then confirmed retry" or "a confirmed retry without refusal").." (#408 BR-1)",function()
            open(false,false,true,true)
            exec([[
                _G.retry_insert_entries=0
                vim.api.nvim_create_autocmd("InsertEnter",{buffer=0,callback=function() retry_insert_entries=retry_insert_entries+1 end})
                vim.env.FAKE_COUCH_OPERATOR_CODE="session-sync-unavailable"
                vim.env.FAKE_COUCH_OPERATOR_EXIT="7"
            ]])
            keys("iX")
            wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='Xfirst bullet'")
            keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
            exec("vim.cmd('silent write')")
            assert.equals("Xfirst bullet",vim.fn.readfile(file)[8])
            assert.is_false(exists(),"unavailable acquire unexpectedly published a lock")
            if intervening_refusal then
                exec([[
                    vim.env.FAKE_COUCH_OPERATOR_CODE="operator-lock"
                    vim.env.FAKE_COUCH_OPERATOR_EXIT="3"
                ]])
                keys("i");wait_for("return vim.fn.mode()=='i'")
                assert.is_false(exec("return vim.bo.modifiable"))
                assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"),"refused retry applied queued input")
                assert.is_true(exec([[return table.concat(notifications,"\n"):find("not applied",1,true)~=nil]]))
                keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
            end
            exec([[
                vim.env.FAKE_COUCH_OPERATOR_CODE=nil
                vim.env.FAKE_COUCH_OPERATOR_EXIT=nil
            ]])
            keys("i")
            exec("vim.schedule(function() _G.retry_entry_settled=true end)")
            wait_for("return _G.retry_entry_settled==true")
            local final_entry=exec("return {mode=vim.fn.mode(),entries=retry_insert_entries,error=vim.v.errmsg,modifiable=vim.bo.modifiable}")
            assert.equals("i",final_entry.mode,"confirmed retry did not enter insert: "..vim.inspect(final_entry))
            assert.is_true(final_entry.modifiable)
            locked()
            assert.equals("Xfirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
            exec("vim.schedule(function() _G.retry_exit_settled=true end)")
            wait_for("return _G.retry_exit_settled==true")
            assert.is_true(exists(),"confirmed unchanged exit retired the earlier outstanding edit")
            assert.equals("Xfirst bullet",vim.fn.readfile(file)[8])
            assert.is_nil(vim.uv.fs_stat(sent_file),"retry submitted an outstanding edit")
        end)
    end

    it("an older release reply cannot retire a newly admitted turn (#408 retry)",function()
        open(false,false,true,true)
        keys("i");wait_for("return vim.fn.mode()=='i'")
        locked()
        exec([[
            local couch=require('parley.couch')
            local command=couch.operator_lock
            couch.operator_lock=function(verb,...)
                local result=command(verb,...)
                if verb=='release' and result.kind=='confirmed' and not _G.reentered_release then
                    _G.reentered_release=true
                    assert(require('parley.session_sync').retry(0))
                    _G.reentered_release_done=true
                end
                return result
            end
        ]])
        keys("<Esc>")
        wait_for("return vim.fn.mode()=='n' and reentered_release_done==true")
        locked()
        assert.is_nil(vim.uv.fs_stat(sent_file),"stale release submitted a newer turn")
    end)

    local function refuse_insert_entry()
        exec([[
            vim.env.FAKE_COUCH_OPERATOR_CODE="operator-lock"
            vim.env.FAKE_COUCH_OPERATOR_EXIT="3"
        ]])
        keys("I");wait_for("return vim.fn.mode()=='i'")
        assert.is_false(exec("return vim.bo.modifiable"))
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
    end
    local function settle_retry_input(value)
        keys(value)
        exec("_G.retry_input_settled=false;vim.schedule(function() _G.retry_input_settled=true end)")
        wait_for("return _G.retry_input_settled==true")
    end

    for _, entry in ipairs({"i","a","o","I","A","O"}) do
        it("retries refused admission with native "..entry.." entry (#408 retry)",function()
            open(false,false,true,true)
            refuse_insert_entry()
            exec("vim.env.FAKE_COUCH_OPERATOR_CODE=nil;vim.env.FAKE_COUCH_OPERATOR_EXIT=nil")
            settle_retry_input(entry)
            assert.equals("i",exec("return vim.fn.mode()"),"retry did not enter insert via "..entry)
            assert.is_true(exec("return vim.bo.modifiable"))
            locked()
            local native={i={8,0,10},a={8,1,10},o={9,0,11},I={8,0,10},A={8,12,10},O={8,0,11}}
            local position=exec("local at=vim.api.nvim_win_get_cursor(0);return {at[1],at[2],vim.api.nvim_buf_line_count(0)}")
            assert.same(native[entry],position,"retry changed the native entry action")
            assert.is_nil(vim.uv.fs_stat(sent_file),"retry submitted the document")
            keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        end)
    end

    it("refused retry freshens before its queued first edit (#408 retry)",function()
        open(false,false,true,true)
        refuse_insert_entry()
        local fresh=vim.fn.readfile(file);fresh[8]="fresh before retry acknowledgment"
        exec([[
            vim.env.FAKE_COUCH_OPERATOR_CODE=nil
            vim.env.FAKE_COUCH_OPERATOR_EXIT=nil
            vim.env.FAKE_COUCH_OPERATOR_ACQUIRE_WRITE=...
            vim.env.FAKE_COUCH_OPERATOR_DELAY="0.1"
            _G.retry_first_edit=nil
            local couch=require("parley.couch");local acquire=couch.operator_lock
            couch.operator_lock=function(verb,...)
                local result=acquire(verb,...)
                if verb=="acquire" then _G.retry_acquire_confirmed=result.kind=="confirmed" end
                return result
            end
            vim.api.nvim_create_autocmd("InsertCharPre",{buffer=0,callback=function()
                local proof=couch.operator_proof(table.concat(vim.fn.readfile(path..".lock"),"\n").."\n")
                _G.retry_first_char_protected=retry_acquire_confirmed==true and proof and proof.ID=="doc-1" and type(proof.Turn)=="string"
                _G.retry_before_first_char=vim.api.nvim_buf_get_lines(0,7,8,false)[1]
            end})
            vim.api.nvim_buf_attach(0,false,{on_reload=function() end,on_lines=function(_,buf)
                retry_first_edit=retry_first_edit or vim.api.nvim_buf_get_lines(buf,7,8,false)[1]
            end})
        ]],table.concat(fresh,"\n").."\n")
        keys("iX")
        wait_for("return _G.retry_first_edit~=nil")
        assert.is_true(exec("return retry_first_char_protected"),"retry applied first character before confirmed protection")
        assert.equals("fresh before retry acknowledgment",exec("return retry_before_first_char"))
        assert.equals("Xfresh before retry acknowledgment",exec("return retry_first_edit"))
        assert.equals("Xfresh before retry acknowledgment",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        locked()
        assert.is_nil(vim.uv.fs_stat(file..".clobbered"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
    end)

    it("repeated refusal keeps native retry entry blocked and available (#408 retry)",function()
        open(false,false,true,true)
        refuse_insert_entry()
        for _,entry in ipairs({"i","a"}) do
            settle_retry_input(entry)
            assert.equals("n",exec("return vim.fn.mode()"),"refused retry entered insert")
            assert.is_false(exec("return vim.bo.modifiable"))
            assert.equals("first bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
            assert.equals(1,exec("return vim.fn.maparg(...,'n',false,true).buffer",entry),"refusal lost retry entry mapping")
        end
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("unavailable retry admits native input with a visible warning (#408 retry)",function()
        open(false,false,true,true)
        refuse_insert_entry()
        exec([[
            vim.env.FAKE_COUCH_OPERATOR_CODE="session-sync-unavailable"
            vim.env.FAKE_COUCH_OPERATOR_EXIT="7"
        ]])
        settle_retry_input("i")
        assert.equals("i",exec("return vim.fn.mode()"))
        assert.is_true(exec("return vim.bo.modifiable"))
        keys("X");wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='Xfirst bullet'")
        assert.is_true(exec([[return vim.wo.winbar:find("not locked: Couch unreachable; edits may conflict",1,true)~=nil]]))
        assert.equals(0,exec("return vim.tbl_count(vim.fn.maparg('i','n',false,true))"),"editable admission kept refusal mapping")
        keys("<Esc>")
    end)

    it("retry restores displaced buffer mappings and uncovers global mappings (#408 retry)",function()
        open(false,false,true,true)
        exec([[
            vim.keymap.set('n','i',function() _G.local_i=true end,{buffer=0,desc='original local insert'})
            vim.keymap.set('n','a',function() _G.global_a=true end,{desc='original global append'})
        ]])
        refuse_insert_entry()
        assert.equals(1,exec("return vim.fn.maparg('a','n',false,true).buffer"),"refusal did not cover global entry mapping")
        assert.is_false(exec("return vim.fn.maparg('i','n',false,true).desc=='original local insert'"))
        exec("vim.env.FAKE_COUCH_OPERATOR_CODE=nil;vim.env.FAKE_COUCH_OPERATOR_EXIT=nil")
        settle_retry_input("O")
        assert.equals("i",exec("return vim.fn.mode()"))
        assert.equals("original local insert",exec("return vim.fn.maparg('i','n',false,true).desc"))
        assert.equals(1,exec("return vim.fn.maparg('i','n',false,true).buffer"))
        assert.equals("original global append",exec("return vim.fn.maparg('a','n',false,true).desc"))
        assert.equals(0,exec("return vim.fn.maparg('a','n',false,true).buffer"))
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        keys("i");wait_for("return _G.local_i==true")
        keys("a");wait_for("return _G.global_a==true")
    end)

    it("explicit retry acquires without entering insert or submitting (#408 retry)",function()
        open(false,false,true,true)
        refuse_insert_entry()
        exec([[
            vim.env.FAKE_COUCH_OPERATOR_CODE=nil
            vim.env.FAKE_COUCH_OPERATOR_EXIT=nil
            vim.cmd('ParleySessionRetry')
        ]])
        assert.equals("n",exec("return vim.fn.mode()"))
        assert.is_true(exec("return vim.bo.modifiable"))
        locked()
        assert.equals("first bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("detach removes refusal mappings and restores displaced mappings (#408 retry)",function()
        open(false,false,true,true)
        exec([[
            vim.keymap.set('n','i',function() _G.detached_i=true end,{buffer=0,desc='detached original insert'})
            vim.keymap.set('n','a',function() _G.detached_a=true end,{desc='detached global append'})
        ]])
        refuse_insert_entry()
        exec("require('parley.session_sync').detach(0)")
        assert.is_true(exec("return vim.bo.modifiable"))
        assert.equals("detached original insert",exec("return vim.fn.maparg('i','n',false,true).desc"))
        assert.equals(1,exec("return vim.fn.maparg('i','n',false,true).buffer"))
        assert.equals("detached global append",exec("return vim.fn.maparg('a','n',false,true).desc"))
        assert.equals(0,exec("return vim.fn.maparg('a','n',false,true).buffer"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("clean foreign reload after unavailable unchanged entry does not become operator work (#408 retry)",function()
        open(false,false,false,true)
        exec([[
            vim.env.FAKE_COUCH_OPERATOR_CODE="session-sync-unavailable"
            vim.env.FAKE_COUCH_OPERATOR_EXIT="7"
        ]])
        keys("i");wait_for("return vim.fn.mode()=='i'")
        assert.is_false(exec("return vim.bo.modified"))
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        assert.is_false(exists())
        exec("vim.env.FAKE_COUCH_OPERATOR_CODE=nil;vim.env.FAKE_COUCH_OPERATOR_EXIT=nil")
        local foreign=vim.fn.readfile(file);foreign[8]="foreign clean update";vim.fn.writefile(foreign,file)
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='foreign clean update'")
        assert.is_false(exec("return vim.bo.modified"),"watch reload made a dirty buffer")
        assert.is_nil(vim.uv.fs_stat(file..".clobbered"))
        keys("i");wait_for("return vim.fn.mode()=='i'")
        locked()
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        exec("vim.schedule(function() _G.clean_reload_exit_settled=true end)")
        wait_for("return _G.clean_reload_exit_settled==true")
        assert.is_false(exists(),"clean foreign reload was retained as outstanding operator work")
        assert.equals("foreign clean update",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("lost acquire acknowledgment retries the same turn without advancing baseline (#408)",function()
        open(true,false,true,true)
        exec('vim.env.FAKE_COUCH_OPERATOR_DELAY="2"')
        keys("iX")
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='Xfirst bullet'")
        local original=vim.fn.readfile(file..".lock","b")
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        exec("vim.env.FAKE_COUCH_OPERATOR_DELAY=nil")
        keys("i");wait_for("return vim.fn.mode()=='i'")
        assert.same(original,vim.fn.readfile(file..".lock","b"),"retry changed token or acquisition time")
        assert.is_false(exec([[return vim.wo.winbar:find("not locked",1,true)~=nil]]))
        keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
        assert.is_true(exists(),"reacquisition advanced the saved edit baseline")
        keys("u")
        assert.is_true(vim.wait(arrival.MS,function() return not exists() end))
    end)

    for _, pairs in ipairs({4,8}) do
        it("bounds operator calls and full reads across "..pairs.." confirmed turns (#408)",function()
            open(false,false,true,true)
            local trace=root.."/operator-trace"
            exec([[
                vim.env.FAKE_COUCH_OPERATOR_TRACE=...
                _G.full_reads=0
                _G.original_get_lines=vim.api.nvim_buf_get_lines
                local target=vim.api.nvim_get_current_buf()
                vim.api.nvim_buf_get_lines=function(buf,start,stop,strict)
                    if (buf==target or buf==0 and vim.api.nvim_get_current_buf()==target) and start==0 and stop==-1 then full_reads=full_reads+1 end
                    return original_get_lines(buf,start,stop,strict)
                end
            ]],trace)
            for _=1,pairs do
                keys("i");wait_for("return vim.fn.mode()=='i'")
                assert.is_true(exists())
                keys("<Esc>");wait_for("return vim.fn.mode()=='n'")
                assert.is_true(vim.wait(arrival.MS,function() return not exists() end))
            end
            local reads=exec("vim.api.nvim_buf_get_lines=original_get_lines; return full_reads")
            assert.equals(2*pairs,#vim.fn.readfile(trace),"one acquire/release pair per turn")
            assert.is_true(reads>=2*pairs and reads<=8*pairs,"unexpected full-buffer work: "..reads)
        end)
    end

    it("submit refuses replacement legacy protection on a registered turn (#408)",function()
        open(false,false,true,true)
        keys("iX")
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='Xfirst bullet'")
        keys("<Esc>")
        wait_for("return vim.fn.mode()=='n'")
        local foreign={"holder: operator","time: foreign"}
        vim.fn.writefile(foreign,file..".lock")
        local accepted=exec([[
            local ss=require("parley.session_sync")
            return ss.send_registered(0,ss.identity(0),function() end)
        ]])
        assert.is_false(accepted)
        assert.same(foreign,vim.fn.readfile(file..".lock"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("submit preserves unreadable registered protection with no owned witness (#408)",function()
        open(false,false,true,true)
        local foreign={"holder: operator","time: foreign"}
        vim.fn.writefile(foreign,file..".lock")
        assert.is_true(vim.uv.fs_chmod(file..".lock",0))
        local accepted=exec([[
            local input=io.open(path..".lock","rb")
            if input then input:close(); error("fixture sidecar remains readable") end
            local ss=require("parley.session_sync")
            return ss.send_registered(0,ss.identity(0),function() end)
        ]])
        vim.uv.fs_chmod(file..".lock",384)
        assert.is_false(accepted)
        assert.same(foreign,vim.fn.readfile(file..".lock"))
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("observed registered edits acquire a producer turn before insert (#408)",function()
        open(false,false,true,true)
        exec([[
            local ss=require("parley.session_sync")
            local baseline=vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false)))
            assert(ss.acquire_observed(0,{outstanding=true,baseline=baseline}))
        ]])
        assert.truthy(table.concat(vim.fn.readfile(file..".lock"),"\n"):match("turn: [0-9a-f]+"))
        keys("iX")
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='Xfirst bullet'")
        assert.is_true(exec("return vim.bo.modifiable"))
        keys("<Esc>")
    end)

    it("normal-mode edit and insert share one confirmed operator turn (#408)",function()
        open(false,false,true,true)
        keys("x")
        wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]=='irst bullet'")
        keys("iX")
        wait_for("return vim.fn.mode()=='i'")
        exec("vim.schedule(function() _G.normal_insert_settled=true end)")
        wait_for("return normal_insert_settled==true")
        assert.is_true(exec("return vim.bo.modifiable"))
        assert.equals("Xirst bullet",exec("return vim.api.nvim_buf_get_lines(0,7,8,false)[1]"))
        assert.truthy(table.concat(vim.fn.readfile(file..".lock"),"\n"):match("turn: [0-9a-f]+"))
        keys("<Esc>")
    end)

    it("plain unregistered Markdown never locks on insert (#404)", function()
        local lines = vim.fn.readfile(file)
        lines[2] = "type: prose"
        vim.fn.writefile(lines, file)
        open(false, false, true, false)
        keys("i")
        wait_for("return vim.fn.mode() == 'i'")
        assert.is_false(exists())
        keys("<Esc>")
        wait_for("return vim.fn.mode() == 'n'")
        assert.is_false(exists())
    end)

    it("escape reconciles a foreign write outside the input autocmd before release (#404)", function()
        open(false, false, true, true)
        keys("i")
        wait_for("return vim.fn.mode() == 'i'")
        locked()
        local foreign = vim.fn.readfile(file)
        foreign[8] = "foreign before escape"
        vim.fn.writefile(foreign, file)
        keys("<Esc>")
        wait_for("return vim.fn.mode() == 'n'")
        notified("session-sync violation")
        assert.equals("foreign before escape", vim.fn.readfile(file .. '.clobbered')[8])
        assert.equals("first bullet", vim.fn.readfile(file)[8])
    end)

    for _, side in ipairs({false, true}) do
        for _, autosave in ipairs({false, true}) do
            for _, late in ipairs({false, true}) do
                for _, changed in ipairs({false, true}) do
                    it(("Ctrl-C releases %s %s late=%s autosave=%s (#404 BR-1)"):format(
                        side and "side doc" or "parent", changed and "after full undo" or "unchanged",
                        tostring(late), tostring(autosave)), function()
                        if side then
                            local original = file
                            file = root .. "/session.side/note.md"
                            vim.fn.mkdir(root .. "/session.side", "p")
                            local lines = vim.fn.readfile(original)
                            lines[2] = "type: prose"
                            vim.fn.writefile(lines, file)
                        end
                        open(autosave, false, true, true)
                        if late then exec("require('parley.session_sync').detach(0)") end
                        keys("i")
                        wait_for("return vim.fn.mode() == 'i'")
                        if late then exec("require('parley.session_sync').attach(0,{ID='doc-1',File=path,Owner='ops:0'})") end
                        assert.is_true(exists())
                        keys(changed and "X<C-c>" or "<C-c>")
                        wait_for("return vim.fn.mode() == 'n'")
                        if changed then
                            assert.is_true(exists(), "changed exit lost protection")
                            keys("u")
                            wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
                        end
                        exec("vim.schedule(function() _G.ctrl_c_settled=true end)")
                        wait_for("return _G.ctrl_c_settled == true")
                        assert.is_false(exists(), "actual mode departure stranded insert intent")
                        assert.is_nil(vim.uv.fs_stat(sent_file))
                    end)
                end
            end
        end
    end

    it("automatic move finalization preserves live unchanged insert intent (#404)", function()
        open(false, false, true, true)
        keys("i")
        wait_for("return vim.fn.mode() == 'i'")
        assert.is_true(exists())
        local destination = root .. '/renamed.md'
        exec([[
            local destination = ...
            local ss=require('parley.session_sync')
            local identity=ss.identity(0)
            local token=assert(ss.begin_move(0))
            assert(ss.install_move_lock(0,token,destination))
            vim.api.nvim_buf_set_name(0,destination)
            vim.cmd('silent write')
            assert(vim.fn.mode()=='i', 'probe must preserve actual insert mode')
            local ok,intent=ss.move_finalization_snapshot(0,token)
            assert(ok,intent)
            assert(intent.new_lock_after==intent.new_lock_before, 'finalization dropped live insert intent')
            intent.stage='protection'
            assert(ss.prepare_move_finalization(0,token,intent))
            identity.File=destination
            assert(ss.retire_move(0,token,identity))
        ]],destination)
        file=destination
        assert.is_true(exists())
        keys('<Esc>')
        assert.is_true(vim.wait(arrival.MS,function() return not exists() end))
    end)

    local function feedback(message, is_error)
        return exec([[
            local message, is_error = ...
            local ss = require("parley.session_sync")
            return type(ss.set_submission_feedback) == "function" and ss.set_submission_feedback(0, message, is_error)
        ]], message, is_error or false)
    end

    local function make_plain()
        vim.fn.writefile({"---", "type: prose", "owner: business", "operator: test", "---", "", "## Operator instructions", "first bullet", "second bullet", "third bullet"}, file)
    end
    it("keeps submitted feedback through own save and actual owed refresh until the next edit before autosave", function()
        make_plain(); open(true, false, false, true)
        assert.is_true(feedback("submitted to ops:0 · 14:23"))
        exec([[
            vim.cmd("silent write")
            vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
            local couch = require("parley.couch")
            local run = couch.run
            couch.run = function(argv, callback, options)
                return run(argv, function(result)
                    callback(result)
                    if argv[2] == "--session-sync" and argv[3] == "status" then _G.feedback_status_refreshed = true end
                end, options)
            end
            vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = {
                Owed = { { ID = "owed", At = "2026-10-14T12:00:00Z" } }, LastWrite = "2026-10-14T11:00:00Z",
            } })
            require("parley.session_sync").PING_CHECK_MS = 0
        ]])
        wait_for("return _G.feedback_status_refreshed == true")
        assert.is_true(exec("return vim.wo.winbar:find('submitted to ops:0 · 14:23', 1, true) ~= nil"))
        exec([[
            require("parley.session_sync").PING_CHECK_MS = 60000
            local command = vim.cmd
            vim.cmd = setmetatable({}, { __call = function(_, value)
                if value == "silent! write" then
                    _G.feedback_at_auto_save = vim.wo.winbar:find("submitted to", 1, true) ~= nil
                end
                return command(value)
            end, __index = command })
        ]])
        keys("x"); locked()
        wait_for("return _G.feedback_at_auto_save ~= nil and not vim.bo.modified")
        assert.is_false(exec("return _G.feedback_at_auto_save"))
        assert.is_false(exec("return vim.wo.winbar:find('submitted to', 1, true) ~= nil"))
        payload(file, function(lines) return lines[8] == "irst bullet" end)
    end)

    it("clears submission feedback when a foreign write is observed and reloaded", function()
        make_plain(); open(false, false, false, true)
        assert.is_true(feedback("submitted to ops:0 · 14:23"))
        agent_reload(true)
        assert.is_false(exec("return vim.wo.winbar:find('submitted to', 1, true) ~= nil"))
        assert.equals("StatusLine:ParleySessionSyncFree", exec("return vim.wo.winhighlight"))
    end)

    it("renders bounded single-line literal error feedback and lets the next submission replace it", function()
        make_plain(); open(false, false, true, true)
        local message = "submit failed: bad%{1+1}\nnext\r\n" .. string.rep("x", 400)
        assert.is_true(feedback(message, true))
        local observed = exec([[
            local message = ...
            local view = require("parley.session_sync").feedback_view(message, true)
            vim.cmd("silent write")
            vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = 0 })
            return { view = view, rendered = vim.api.nvim_eval_statusline(vim.wo.winbar,
                { winid = 0, use_winbar = true, maxwidth = 1000 }).str, highlight = vim.wo.winhighlight,
                bounded = vim.fn.strchars(view.label) <= 160 }
        ]], message)
        assert.equals("DiagnosticError", observed.view.hl)
        assert.equals("StatusLine:ParleySessionSyncFree", observed.highlight)
        assert.is_true(observed.bounded)
        assert.is_nil(observed.view.label:find("[\r\n]"))
        assert.is_truthy(observed.rendered:find("bad%{1+1}", 1, true))
        assert.is_true(feedback("submitted to other:2 · 15:10"))
        assert.is_true(exec("return vim.wo.winbar:find('submitted to other:2 · 15:10', 1, true) ~= nil"))
        assert.is_false(exec("return vim.wo.winbar:find('submit failed:', 1, true) ~= nil"))
        assert.equals("StatusLine:ParleySessionSyncFree", exec("return vim.wo.winhighlight"))
    end)

    it("does not attach or change the band when feedback is requested for an unattached buffer", function()
        local before = exec("return vim.wo.winbar")
        assert.equals("function", exec("return type(require('parley.session_sync').set_submission_feedback)"))
        assert.is_false(feedback("submit failed: offline", true))
        assert.equals(before, exec("return vim.wo.winbar"))
        assert.is_true(exec("return require('parley.session_sync').identity(0) == nil"))
    end)

    for _, case in ipairs({
        { name = "dd", input = "dd" }, { name = "x", input = "x" },
        { name = "p", input = '"ap' }, { name = "u", input = "u", undo = true },
        { name = "dot", input = "." },
    }) do
        it("registered plain " .. case.name .. " locks before existing auto-save", function()
            make_plain()
            open(true, case.undo, false, true)
            keys(case.input)
            locked()
            wait_for("return _G.pre_save_lock ~= nil and not vim.bo.modified")
            assert.equals(1, exec("return _G.pre_save_lock"))
            assert.equals("ops:0", exec("return require('parley.session_sync').identity(0).Owner"))
        end)
    end
    it("registered identity survives header edits and undo releases then redo retakes", function()
        make_plain()
        open(true, false, false, true)
        keys("ggdd")
        locked()
        wait_for("return not vim.bo.modified")
        assert.equals("ops:0", exec("return require('parley.session_sync').identity(0).Owner"))
        keys("u")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
        keys("<C-r>")
        locked()
    end)
    it("observed auto-saved edits acquire with the pre-edit baseline", function()
        make_plain()
        exec([[
            local path = ...
            vim.cmd("edit " .. vim.fn.fnameescape(path))
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            _G.before_hash = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
            local st = vim.uv.fs_stat(path)
            _G.before_loaded = st.mtime.sec .. "." .. st.mtime.nsec
            vim.cmd("normal! Gdd")
            vim.cmd("silent write")
            ss.attach(vim.api.nvim_get_current_buf(), { ID="doc-1", File=path, Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="now" },
                { baseline=before_hash, loaded=before_loaded, outstanding=true })
        ]], file)
        assert.is_false(exec("return vim.bo.modified"))
        locked()
        keys("u")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "observed baseline must survive auto-save")
    end)
    it("prepares without unlock and registered send saves before releasing and routes confirmed owner", function()
        make_plain()
        open(false, false, false, true)
        keys("dd")
        locked()
        assert.is_true(exec("return require('parley.session_sync').prepare_submit(vim.api.nvim_get_current_buf())"))
        assert.is_true(exists())
        assert.is_false(exec("return vim.bo.modified"))
        exec([[
            local ss = require("parley.session_sync")
            ss.send_registered(vim.api.nvim_get_current_buf(), ss.identity(0), function(obj) _G.sent_code = obj.code end)
        ]])
        notified("submitted")
        wait_for("return _G.sent_code == 0")
        assert.is_false(exists())
        assert.equals("second bullet", vim.fn.readfile(file)[8])
    end)
    it("completes a refused registered send callback without releasing the turn", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        assert.is_true(exec([[
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            identity.ID = "stale-id"
            local result
            local ok = ss.send_registered(0, identity, function(value) result = value end)
            return ok == false and result ~= nil and result.code ~= 0 and result.stderr ~= ""
        ]]))
        assert.is_true(exists())
        assert.is_nil(vim.uv.fs_stat(sent_file))
    end)

    it("detaches without unlocking and preserves user option overrides", function()
        make_plain()
        open(false, false, false, true)
        keys("dd")
        locked()
        exec([[
            vim.bo.autoread = true
            vim.wo.winbar = "operator band"
            require("parley.session_sync").detach(vim.api.nvim_get_current_buf())
        ]])
        assert.is_true(exists())
        assert.is_true(exec("return vim.bo.autoread"))
        assert.equals("operator band", exec("return vim.wo.winbar"))
        assert.is_true(exec("return require('parley.session_sync').identity(0) == nil"))
    end)
    it("moves protection exclusively and keeps acquisition baseline through metadata handoff", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local next_file = root .. "/renamed.md"
        exec([[
            local new = ...
            local ss = require("parley.session_sync")
            _G.move_token = assert(ss.begin_move(vim.api.nvim_get_current_buf()))
            assert(ss.install_move_lock(vim.api.nvim_get_current_buf(), move_token, new))
            vim.cmd("saveas " .. vim.fn.fnameescape(new))
        ]], next_file)
        assert.is_not_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_not_nil(vim.uv.fs_stat(next_file .. ".lock"))
        exec([[
            local new = ...
            local ss = require("parley.session_sync")
            assert(ss.finish_move(vim.api.nvim_get_current_buf(), move_token,
                {ID="doc-1", File=new, Owner="ops:0", RegisteredOwner="ops:0", RegisteredAt="now"}))
        ]], next_file)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        file = next_file
        keys("u")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "move must preserve acquisition baseline")
    end)

    local function rewritten_move(held)
        make_plain()
        open(false, false, true, true)
        return exec([[
            local destination, held = ...
            local ss = require("parley.session_sync")
            local function hash() return vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false))) end
            _G.sync_original = vim.api.nvim_buf_get_lines(0,0,-1,false)
            if held then vim.api.nvim_buf_set_lines(0,7,8,false,{"unsent operator edit"}) end
            local before = hash()
            assert(ss.acquire_observed(0, {baseline=held and vim.fn.sha256(vim.json.encode(sync_original)) or before,
                outstanding=true}))
            _G.sync_token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, sync_token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            _G.sync_before = before
            local lines = vim.fn.readfile(destination)
            lines[7] = "## Mechanically rewritten parent"
            vim.fn.writefile(lines, destination)
            ss.with_buffer_read(0, function() vim.cmd("silent edit") end)
            return {before=before, after=hash(), baseline=sync_token.baseline}
        ]], root .. "/synchronized.md", held)
    end

    it("restored move protection resumes insert without a new acquire (#408)",function()
        rewritten_move(false)
        local destination=root.."/synchronized.md"
        local trace=root.."/restore-trace"
        exec([[
            local trace=...
            local ss=require("parley.session_sync")
            local ok,proof=ss.synchronize_move(0,sync_token,sync_before);assert(ok,proof)
            _G.restore_proof,_G.restore_identity=proof,ss.identity(0)
            ss.detach(0)
            vim.env.FAKE_COUCH_OPERATOR_TRACE=trace
        ]],trace)
        keys("i");wait_for("return vim.fn.mode()=='i'")
        exec([[
            local destination=...
            local ss=require("parley.session_sync")
            local token=assert(ss.restore_move(0,restore_identity,destination,restore_proof))
            assert(vim.bo.modifiable,"recovery attempted to acquire the already-witnessed turn")
            local ok,intent=ss.move_finalization_snapshot(0,token);assert(ok,intent)
            assert(intent.new_lock_after==intent.new_lock_before,"restoration lost live insert intent")
            intent.stage="protection";assert(ss.prepare_move_finalization(0,token,intent))
            restore_identity.File=destination
            assert(ss.retire_move(0,token,restore_identity))
        ]],destination)
        assert.is_nil(vim.uv.fs_stat(trace),"restore must use its validated journal proof")
        file=destination
        keys("<Esc>")
        assert.is_true(vim.wait(arrival.MS,function() return not exists() end))
        assert.equals(1,#vim.fn.readfile(trace),"only the eventual owned release contacts Couch")
    end)

    it("synchronizes a mechanical move rewrite and releases only its transformed baseline", function()
        local proof = rewritten_move(false)
        local destination = root .. "/synchronized.md"
        local protection = exec([[
            local ss = require("parley.session_sync")
            assert(type(ss.synchronize_move) == "function", "missing move synchronization API")
            local ok, protection = ss.synchronize_move(0, sync_token, sync_before)
            assert(ok, protection)
            assert(sync_token.baseline == protection.baseline)
            return protection
        ]])
        assert.equals(proof.after, protection.baseline)
        assert.equals(protection.old_lock, protection.new_lock)
        assert.is_not_nil(vim.uv.fs_stat(file .. ".lock"), "synchronization must keep migration protection")
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0); identity.File = destination
            assert(ss.finish_move(0, sync_token, identity))
            assert(ss.release_if_baseline(0))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
        file = destination
        keys("x")
        locked() -- native read must not detach the next edit observer.
    end)

    it("preserves an outstanding operator baseline through mechanical move synchronization", function()
        local proof = rewritten_move(true)
        local destination = root .. "/synchronized.md"
        local baseline = exec([[
            local ss = require("parley.session_sync")
            assert(type(ss.synchronize_move) == "function", "missing move synchronization API")
            local ok, protection = ss.synchronize_move(0, sync_token, sync_before)
            assert(ok, protection)
            local identity = ss.identity(0); identity.File = ...
            assert(ss.finish_move(0, sync_token, identity))
            assert(not ss.release_if_baseline(0))
            return protection.baseline
        ]], destination)
        assert.equals(proof.baseline, baseline)
        file = destination
        assert.is_true(exists())
        exec("vim.api.nvim_buf_set_lines(0,0,-1,false,sync_original)")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "original acquisition baseline must still release")
    end)

    it("refuses stale synchronization token, path, protection and modified buffers without changing baseline", function()
        local proof = rewritten_move(false)
        local destination = root .. "/synchronized.md"
        local baseline = exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            assert(type(ss.synchronize_move) == "function", "missing move synchronization API")
            local function refused(token, before)
                local ok, message = ss.synchronize_move(0, token, before)
                assert(ok == false and type(message) == "string")
                assert(sync_token.baseline == sync_before, "refusal changed acquisition proof")
            end
            refused({}, sync_before)
            refused(sync_token, false)
            vim.api.nvim_buf_set_name(0, destination .. ".wrong")
            refused(sync_token, sync_before)
            vim.api.nvim_buf_set_name(0, destination)
            vim.fn.writefile({"foreign protection"}, destination .. ".lock")
            refused(sync_token, sync_before)
            local lock = assert(io.open(destination .. ".lock", "wb")); assert(lock:write(sync_token.lock)); lock:close()
            vim.bo.modified = true
            refused(sync_token, sync_before)
            vim.bo.modified = false
            local ok, protection = ss.synchronize_move(0, sync_token, sync_before)
            assert(ok, protection)
            return protection.baseline
        ]], destination)
        assert.equals(proof.after, baseline)
    end)

    for _, known_baseline in ipairs({false, true}) do
        it("synchronizes restored protection with known baseline=" .. tostring(known_baseline), function()
            local proof = rewritten_move(false)
            local destination = root .. "/synchronized.md"
            local absent = exec([[
                local destination, known_baseline, after = ...
                local ss = require("parley.session_sync")
                local identity = ss.identity(0)
                local protection = {old_lock=sync_token.lock,new_lock=sync_token.lock,
                    baseline=known_baseline and after or nil}
                ss.detach(0)
                local restored = assert(ss.restore_move(0, identity, destination, protection))
                assert(type(ss.synchronize_move) == "function", "missing move synchronization API")
                local ok, next_protection = ss.synchronize_move(0, restored, after)
                assert(ok, next_protection)
                identity.File = destination
                assert(ss.finish_move(0, restored, identity))
                assert(ss.release_if_baseline(0) == known_baseline)
                return next_protection.baseline == nil
            ]], destination, known_baseline, proof.after)
            assert.equals(not known_baseline, absent)
            assert.equals(not known_baseline, vim.uv.fs_stat(destination .. ".lock") ~= nil)
        end)
    end

    it("journals finalization intent before cleanup and resumes only after retirement", function()
        rewritten_move(false)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local synced, protection = ss.synchronize_move(0, sync_token, sync_before); assert(synced, protection)
            assert(type(ss.move_finalization_snapshot) == "function", "missing replayable finalization API")
            local ok, intent = ss.move_finalization_snapshot(0, sync_token); assert(ok, intent)
            assert(intent.new_lock_after == false)
            intent.stage = "protection"
            assert(ss.prepare_move_finalization(0, sync_token, intent))
            assert(ss.prepare_move_finalization(0, sync_token, intent), "cleanup replay must be idempotent")
            local stream=assert(io.open(destination .. ".lock","wb"));assert(stream:write(sync_token.lock));stream:close()
            intent.stage="retire"
            assert(not ss.prepare_move_finalization(0,sync_token,intent), "retire must require exact after-state")
            assert(vim.fn.filereadable(destination .. ".lock")==1, "retire refusal cannot remove captured before-state")
            intent.stage="protection"
            assert(ss.prepare_move_finalization(0,sync_token,intent))
            assert(vim.fn.filereadable(destination .. ".lock") == 0)
            assert(not ss.begin_move(0), "engine must stay suspended before journal retirement")
            assert(not ss.release_if_baseline(0))
            local identity=ss.identity(0);identity.File=destination
            assert(ss.retire_move(0,sync_token,identity))
        ]], destination)
        file = destination
        keys("x"); locked()
    end)

    it("replays persisted finalization after both cleanup effects and editor death", function()
        rewritten_move(false)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local synced, protection = ss.synchronize_move(0,sync_token,sync_before); assert(synced,protection)
            assert(type(ss.move_finalization_snapshot) == "function", "missing replayable finalization API")
            local ok, intent=ss.move_finalization_snapshot(0,sync_token);assert(ok,intent)
            local identity=ss.identity(0)
            intent.stage="protection"
            assert(ss.prepare_move_finalization(0,sync_token,intent))
            ss.detach(0)
            assert(not ss.restore_move(0,identity,destination,protection), "absence without intent must refuse")
            intent.stage="handoff"
            assert(not ss.restore_move(0,identity,destination,protection,intent), "handoff has not authorized cleanup")
            intent.stage="protection"
            local restored=assert(ss.restore_move(0,identity,destination,protection,intent))
            assert(ss.prepare_move_finalization(0,restored,intent))
            identity.File=destination
            assert(ss.retire_move(0,restored,identity))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    for _, point in ipairs({"before-cleanup", "after-old", "after-new"}) do
        for _, entry in ipairs({"before-restore", "after-restore", "outside-insert"}) do
            it("retained release journal respects current intent at " .. point .. "/" .. entry .. " (#404)", function()
                rewritten_move(false)
                local destination = root .. "/synchronized.md"
                exec([[
                    local destination, point = ...
                    local ss = require("parley.session_sync")
                    local synced, protection = ss.synchronize_move(0,sync_token,sync_before); assert(synced,protection)
                    local ok,intent = ss.move_finalization_snapshot(0,sync_token); assert(ok,intent)
                    assert(intent.new_lock_after == false, "fixture must authorize release outside insert")
                    intent.stage = point == "after-new" and "retire" or "protection"
                    _G.replay = { identity=ss.identity(0), protection=protection, intent=intent }
                    if point ~= "before-cleanup" then assert(os.remove(replay.identity.File .. ".lock")) end
                    if point == "after-new" then assert(os.remove(destination .. ".lock")) end
                    ss.detach(0)
                ]], destination, point)
                if entry == "before-restore" then
                    keys("i"); wait_for("return vim.fn.mode() == 'i'")
                end
                exec([[
                    local destination, entry = ...
                    local ss = require("parley.session_sync")
                    local function bytes(path)
                        local f = io.open(path,"rb"); if not f then return false end
                        local value=f:read("*a"); f:close(); return value
                    end
                    replay.before_old=bytes(replay.identity.File .. ".lock")
                    replay.before_new=bytes(destination .. ".lock")
                    local token,reason=ss.restore_move(0,replay.identity,destination,replay.protection,replay.intent)
                    replay.token=token
                    if entry == "before-restore" then
                        assert(not token, "release recovery admitted fresh insert intent")
                        assert(reason:find("leave insert mode and reopen",1,true),reason)
                        assert(bytes(replay.identity.File .. ".lock")==replay.before_old,"refusal changed OLD")
                        assert(bytes(destination .. ".lock")==replay.before_new,"refusal changed NEW")
                    else assert(token,reason) end
                ]], destination, entry)
                if entry == "after-restore" then
                    keys("i"); wait_for("return vim.fn.mode() == 'i'")
                    exec([[
                        local destination=...
                        local ss=require("parley.session_sync")
                        local ok,reason=ss.prepare_move_finalization(0,replay.token,replay.intent)
                        assert(not ok,"persisted permission overrode live insert intent")
                        assert(reason:find("leave insert mode and reopen",1,true),reason)
                        local function bytes(path)
                            local f=io.open(path,"rb"); if not f then return false end
                            local value=f:read("*a");f:close();return value
                        end
                        assert(bytes(replay.identity.File .. ".lock")==replay.before_old,"refusal changed OLD")
                        assert(bytes(destination .. ".lock")==replay.before_new,"refusal changed NEW")
                    ]],destination)
                end
                if entry ~= "outside-insert" then
                    keys("<Esc>"); wait_for("return vim.fn.mode() == 'n'")
                end
                exec([[
                    local destination=...
                    local ss=require("parley.session_sync")
                    local token=replay.token or assert(ss.restore_move(0,replay.identity,destination,replay.protection,replay.intent))
                    assert(ss.prepare_move_finalization(0,token,replay.intent))
                    assert(ss.prepare_move_finalization(0,token,replay.intent),"cleanup replay did not converge")
                    replay.identity.File=destination
                    assert(ss.retire_move(0,token,replay.identity))
                ]],destination)
                assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
                assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
            end)
        end
    end

    it("replays partial OLD cleanup and preserves foreign NEW protection", function()
        rewritten_move(false)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            assert(ss.synchronize_move(0,sync_token,sync_before))
            assert(type(ss.move_finalization_snapshot) == "function", "missing replayable finalization API")
            local ok,intent=ss.move_finalization_snapshot(0,sync_token);assert(ok,intent);intent.stage="protection"
            vim.env.FAKE_COUCH_OPERATOR_CODE="operator-lock-uncertain"
            vim.env.FAKE_COUCH_OPERATOR_EXIT="1"
            vim.env.FAKE_COUCH_OPERATOR_OPS="operator-release"
            local called,finished,reason=pcall(ss.prepare_move_finalization,0,sync_token,intent)
            vim.env.FAKE_COUCH_OPERATOR_CODE=nil
            vim.env.FAKE_COUCH_OPERATOR_EXIT=nil
            vim.env.FAKE_COUCH_OPERATOR_OPS=nil
            assert(called and finished==false and reason, "NEW failure must remain replayable")
            assert(vim.fn.filereadable(sync_token.old_path .. ".lock")==0)
            vim.fn.writefile({"foreign lock"},destination .. ".lock")
            assert(not ss.prepare_move_finalization(0,sync_token,intent))
            assert(vim.fn.readfile(destination .. ".lock")[1]=="foreign lock")
            local stream=assert(io.open(destination .. ".lock","wb"));assert(stream:write(sync_token.lock));stream:close()
            assert(ss.prepare_move_finalization(0,sync_token,intent))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    it("admits finalization for a legacy complete handoff with OLD already removed", function()
        rewritten_move(false)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination=...
            local ss=require("parley.session_sync")
            local ok,protection=ss.synchronize_move(0,sync_token,sync_before);assert(ok,protection)
            local identity=ss.identity(0)
            assert(os.remove(sync_token.old_path .. ".lock"))
            ss.detach(0)
            local restored=assert(ss.restore_move(0,identity,destination,protection))
            local captured,intent=ss.move_finalization_snapshot(0,restored);assert(captured,intent)
            assert(intent.old_lock_before==protection.old_lock)
            intent.stage="handoff"
            ss.detach(0)
            restored=assert(ss.restore_move(0,identity,destination,protection,intent))
            intent.stage="protection"
            assert(ss.prepare_move_finalization(0,restored,intent))
            identity.File=destination
            assert(ss.retire_move(0,restored,identity))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    it("refuses a non-file NEW lock without treating it as completed cleanup", function()
        rewritten_move(false)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination=...
            local ss=require("parley.session_sync")
            assert(ss.synchronize_move(0,sync_token,sync_before))
            local captured,intent=ss.move_finalization_snapshot(0,sync_token);assert(captured,intent)
            intent.stage="protection"
            assert(os.remove(destination .. ".lock"))
            vim.fn.mkdir(destination .. ".lock")
            local finished,reason=ss.prepare_move_finalization(0,sync_token,intent)
            assert(finished==false and type(reason)=="string", "unknown protection is not absence")
            assert(vim.fn.filereadable(sync_token.old_path .. ".lock")==1, "refusal must preserve OLD too")
            assert(vim.fn.isdirectory(destination .. ".lock")==1)
        ]], destination)
    end)

    it("retains outstanding operator protection through replayable finalization", function()
        rewritten_move(true)
        local destination = root .. "/synchronized.md"
        exec([[
            local destination = ...
            local ss=require("parley.session_sync")
            assert(ss.synchronize_move(0,sync_token,sync_before))
            assert(type(ss.move_finalization_snapshot) == "function", "missing replayable finalization API")
            local ok,intent=ss.move_finalization_snapshot(0,sync_token);assert(ok,intent)
            assert(intent.new_lock_after==intent.new_lock_before and type(intent.new_lock_after)=="string")
            intent.stage="protection"
            assert(ss.prepare_move_finalization(0,sync_token,intent))
            local identity=ss.identity(0);identity.File=destination
            assert(ss.retire_move(0,sync_token,identity))
            assert(not ss.release_if_baseline(0))
        ]], destination)
        assert.is_not_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    it("aborts a no-effect move when the buffer name aliases its canonical registry path", function()
        make_plain()
        local alias = root .. "/alias.md"
        assert(vim.uv.fs_symlink(file, alias))
        assert.is_true(exec([[
            local alias, canonical = ...
            vim.cmd("edit " .. vim.fn.fnameescape(alias))
            assert(vim.api.nvim_buf_get_name(0) == alias, "test requires a preserved lexical alias")
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            ss.attach(0, {ID="doc-1",File=canonical,Owner="ops:0",RegisteredOwner="ops:0",RegisteredAt="now"})
            local token = assert(ss.begin_move(0))
            return ss.abort_move(0, token)
        ]], alias, file))
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(alias .. ".lock"))
    end)

    it("releases synthetic move protection only at the unchanged acquisition baseline", function()
        make_plain()
        open(false, false, true, true)
        local destination = root .. "/synthetic.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local baseline = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false)))
            assert(ss.acquire_observed(0, { baseline=baseline, outstanding=true }))
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            local identity = ss.identity(0)
            identity.File = destination
            assert(ss.finish_move(0, token, identity))
            assert(ss.release_if_baseline(0))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(destination .. ".lock"))
    end)

    it("retains synthetic move protection after a programmatic edit during migration", function()
        make_plain()
        open(false, false, true, true)
        local destination = root .. "/during.md"
        assert.is_false(exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local baseline = vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(0,0,-1,false)))
            assert(ss.acquire_observed(0, { baseline=baseline, outstanding=true }))
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            -- A forced plugin edit must retain the pre-move acquisition baseline.
            vim.api.nvim_buf_set_lines(0,7,8,false,{"programmatic edit"})
            assert(vim.fn.filereadable(destination .. ".lock") == 1)
            vim.cmd("silent write")
            local identity = ss.identity(0)
            identity.File = destination
            assert(ss.finish_move(0, token, identity))
            return ss.release_if_baseline(0)
        ]], destination))
        assert.is_not_nil(vim.uv.fs_stat(destination .. ".lock"))
        assert.equals("programmatic edit", vim.fn.readfile(destination)[8])
    end)

    it("restores journaled move protection after editor process death", function()
        make_plain()
        open(false, false, true, true)
        local baseline = vim.fn.readfile(file)
        keys("dd")
        locked()
        local destination = root .. "/restored.md"
        local proof = exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            local protection = { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline }
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            return { identity=identity, protection=protection }
        ]], destination)
        child:stop()
        child = Embedded.start({ ui = { 100, 30 } })
        exec([[
            local root, destination, proof = ...
            vim.env.PATH = root .. "/bin:" .. vim.env.PATH
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.FAKE_COUCH_STATUS = nil
            vim.env.FAKE_COUCH_ACTORS = '{"Actors":[]}'
            vim.notify = function() end
            vim.cmd("edit " .. vim.fn.fnameescape(destination))
            local ss = require("parley.session_sync")
            ss.POLL_MS = 60000
            _G.restored_token = assert(ss.restore_move(0, proof.identity, destination, proof.protection))
            _G.original_identity = proof.identity
        ]], root, destination, proof)
        assert.is_not_nil(vim.uv.fs_stat(file .. ".lock"))
        exec([[
            local destination = ...
            local identity = vim.deepcopy(original_identity)
            identity.File = destination
            assert(require("parley.session_sync").finish_move(0, restored_token, identity))
        ]], destination)
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
        file = destination
        exec("vim.api.nvim_buf_set_lines(0,0,-1,false,...)", baseline)
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "restored acquisition baseline was lost")
    end)

    it("restore refuses a different destination lock without changing either lock", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local destination = root .. "/occupied.md"
        vim.fn.writefile({ "holder: operator", "time: another editor" }, destination .. ".lock")
        local old_lock = vim.fn.readfile(file .. ".lock")
        assert.is_true(exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            ss.detach(0)
            local restored = ss.restore_move(0, identity, destination,
                { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline })
            return restored == nil
        ]], destination))
        assert.same(old_lock, vim.fn.readfile(file .. ".lock"))
        assert.same({ "holder: operator", "time: another editor" }, vim.fn.readfile(destination .. ".lock"))
    end)

    it("restore permits completed OLD lock cleanup only with matching NEW proof", function()
        make_plain()
        open(false, false, true, true)
        keys("dd")
        locked()
        local destination = root .. "/handoff.md"
        exec([[
            local destination = ...
            local ss = require("parley.session_sync")
            local identity = ss.identity(0)
            local token = assert(ss.begin_move(0))
            assert(ss.install_move_lock(0, token, destination))
            vim.cmd("saveas " .. vim.fn.fnameescape(destination))
            vim.fn.delete(identity.File .. ".lock")
            ss.detach(0)
            local restored = assert(ss.restore_move(0, identity, destination,
                { old_lock=token.lock, new_lock=token.lock, baseline=token.baseline }))
            identity.File = destination
            assert(ss.finish_move(0, restored, identity))
        ]], destination)
        assert.is_not_nil(vim.uv.fs_stat(destination .. ".lock"))
        assert.is_nil(vim.uv.fs_stat(file .. ".lock"))
    end)

    for _, reloaded in ipairs({"open", "watch", "checktime"}) do
        for _, case in ipairs({
            {name="dd", input="dd"}, {name="x", input="x"},
            {name="p", input='"ap'}, {name="u", input="u", undo=true},
            {name="dot", input="."}, {name="insert", input="iX"},
        }) do
            it(case.name .. " locks before the existing auto-save" .. " after " .. reloaded, function()
                open(true, case.undo)
                if reloaded ~= "open" then agent_reload(reloaded == "checktime") end
                keys(case.input)
                locked()
                if case.name == "insert" then
                    -- Let TextChangedI run before InsertLeave's auto-save.
                    wait_for("return vim.bo.modified")
                    keys("<Esc>")
                end
                wait_for("return _G.pre_save_lock ~= nil")
                assert.equals(1, exec("return _G.pre_save_lock"), "lock must precede auto-save")
                wait_for("return not vim.bo.modified")
                assert.is_true(exists(), "auto-save must retain the operator turn")
            end)
        end
    end

    for _, input in ipairs({"ggdd", "ggx", 'gg"ap'}) do
        it("keeps attached session identity through header edit " .. input, function()
            open(false)
            keys(input)
            locked()
            assert.is_true(exec("return require('parley.session_sync').is_session_sync(0)"))
        end)
    end

    for _, autosave in ipairs({false, true}) do
        for _, reloaded in ipairs({"open", "watch", "checktime"}) do
            it("undo releases acquisition baseline, redo retakes: " .. reloaded .. " autosave=" .. tostring(autosave), function()
                open(autosave)
                if reloaded ~= "open" then agent_reload(reloaded == "checktime") end
                local baseline = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                keys("u")
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == " .. string.format("%q", baseline[8]))
                assert.is_true(vim.wait(arrival.MS, function() return not exists() end), "baseline undo kept the lock")
                payload(file, function(lines) return vim.deep_equal(baseline, lines) end)
                assert.same({}, exec("return notifications"))
                assert.is_nil(vim.uv.fs_stat(sent_file), "undo must not notify owner")
                keys("<C-r>"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                assert.is_true(exists())
                keys("u")
                assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
                agent_reload() -- next agent write succeeds and reaches the editor.
            end)
        end

        it("partial undo retains turn, full undo releases: autosave=" .. tostring(autosave), function()
            open(autosave)
            keys("dd"); locked()
            keys("x"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'econd bullet'")
            keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'second bullet'")
            exec("vim.schedule(function() _G.reconciled=true end)")
            wait_for("return _G.reconciled == true")
            assert.is_true(exists())
            keys("u")
            assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
            agent_reload()
        end)
    end

    it("submit then agent reload then first body dd still locks before auto-save", function()
        open(true)
        keys("dd"); locked()
        exec("require('parley.session_sync').submit(vim.api.nvim_get_current_buf())")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
        notified("submitted")
        agent_reload()
        keys("dd"); locked()
        wait_for("return _G.pre_save_lock ~= nil")
        assert.equals(1, exec("return _G.pre_save_lock"))
    end)

    for _, autosave in ipairs({false, true}) do
        for _, change in ipairs({"overwrite", "delete", "unkeepable overwrite"}) do
            it("clean undo preserves pending foreign " .. change .. " before release autosave=" .. tostring(autosave), function()
                open(autosave, false, true) -- release callback must handle it before the watcher.
                local original = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                local foreign = vim.fn.readfile(file)
                exec([[
                    local change = ...
                    if change == "delete" then
                        vim.fn.delete(path)
                    else
                        local foreign = vim.fn.readfile(path)
                        foreign[8] = "foreign agent text"
                        vim.fn.writefile(foreign, path)
                        if change == "unkeepable overwrite" then
                            vim.fn.mkdir(path .. ".clobbered")
                        end
                    end
                    vim.cmd("normal! u")
                ]], change)
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
                if change == "overwrite" then
                    foreign[8] = "foreign agent text"
                    payload(file .. ".clobbered", function(lines) return vim.deep_equal(foreign, lines) end)
                    payload(file, function(lines) return vim.deep_equal(original, lines) end)
                elseif change == "delete" then
                    payload(file, function(lines) return vim.deep_equal(original, lines) end)
                else
                    notified("session-sync violation")
                    assert.equals("foreign agent text", vim.fn.readfile(file)[8])
                end
                locked()
                notified("session-sync violation")
            end)
        end

        for _, undecided in ipairs({"ignored", "errored"}) do
            it("clean undo keeps undecided foreign writes locked when checktime is " .. undecided .. " autosave=" .. tostring(autosave), function()
                open(autosave, false, true)
                local original = vim.fn.readfile(file)
                keys("dd"); locked()
                if autosave then wait_for("return not vim.bo.modified") end
                local foreign = vim.fn.readfile(file)
                exec([[
                    local undecided = ...
                    local lines = vim.fn.readfile(path)
                    lines[8] = "unclassified foreign text"
                    vim.fn.writefile(lines, path)
                    _G.real_cmd = vim.cmd
                    if undecided == "ignored" then
                        vim.o.eventignore = "FileChangedShell"
                    else
                        vim.cmd = setmetatable({}, {__call=function(_, command)
                            if command:match("^checktime") then error("checktime unavailable") end
                            return real_cmd(command)
                        end, __index=real_cmd})
                    end
                    vim.cmd("normal! u")
                ]], undecided)
                wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
                exec("vim.schedule(function() _G.reconciled=true end)")
                wait_for("return _G.reconciled == true")
                assert.is_true(exists(), "an undecided disk change must retain protection")
                assert.is_false(vim.fn.filereadable(file .. ".clobbered") == 1)
                assert.equals("unclassified foreign text", vim.fn.readfile(file)[8])
                exec("vim.cmd=real_cmd; vim.o.eventignore=''")
                if autosave then
                    -- With a failed auto-save, checktime need not repeat its
                    -- disk-change event. The contract here is to keep an
                    -- undecided write protected, without fabricating a retry.
                    locked()
                    foreign[8] = "unclassified foreign text"
                    payload(file, function(lines) return vim.deep_equal(foreign, lines) end)
                    return
                end
                exec("vim.cmd('checktime')")
                foreign[8] = "unclassified foreign text"
                payload(file .. ".clobbered", function(lines) return vim.deep_equal(foreign, lines) end)
                payload(file, function(lines) return vim.deep_equal(original, lines) end)
                locked()
            end)
        end

    end

    it("a pre-existing lock has no acquisition baseline and stays held after undo", function()
        vim.fn.writefile({"holder: operator", "time: 2026-10-14T00:00:00Z"}, file .. ".lock")
        open(true)
        keys("dd"); wait_for("return not vim.bo.modified")
        keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
        exec("vim.schedule(function() _G.reconciled=true end)")
        wait_for("return _G.reconciled == true")
        locked()
    end)

    it("failed baseline save keeps the lock until a later successful reconciliation", function()
        open(false)
        keys("dd"); locked()
        exec([[
            vim.cmd("silent write")
            _G.real_cmd = vim.cmd
            vim.cmd = setmetatable({}, {__call=function(_, command)
                if command == "silent write" then error("write unavailable") end
                return real_cmd(command)
            end, __index=real_cmd})
        ]])
        keys("u"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'first bullet'")
        exec("vim.schedule(function() _G.reconciled=true end)")
        wait_for("return _G.reconciled == true")
        locked()
        payload(file, function(lines) return lines[8] == "second bullet" end)
        exec("vim.cmd=real_cmd")
        keys("x"); wait_for("return vim.api.nvim_buf_get_lines(0,7,8,false)[1] == 'irst bullet'")
        keys("u")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
        payload(file, function(lines) return lines[8] == "first bullet" end)
    end)

    it("explicit save retains changed turn, undo to acquisition baseline releases", function()
        open(false)
        keys("dd"); locked()
        exec("vim.cmd('silent write')")
        assert.is_false(exec("return vim.bo.modified"))
        vim.wait(100)
        assert.is_true(exists())
        keys("u")
        assert.is_true(vim.wait(arrival.MS, function() return not exists() end))
        payload(file, function(lines) return lines[8] == "first bullet" end)
    end)
end)
