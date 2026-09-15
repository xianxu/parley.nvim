-- Integration test for lua/parley/skill_invoke.lua — the thin P2 driver.
--
-- Reuses the chat_respond_spec fake pattern: monkeypatch parley.dispatcher.query
-- (the LLM dispatcher), inject a tool-use raw_response into tasker, fire on_exit;
-- vim.wait for the (vim.scheduled) on_done. The propose_edits call applies through
-- the real asynchronous producer and checked filesystem onto the artifact file.

local skill_invoke = require("parley.skill_invoke")
local parley = require("parley")
local tasker = require("parley.tasker")
local assembly = require("parley.skill_assembly")

local remove_fixture_dir = require("tests.helpers.fixture_directory").remove

-- SSE builder (same shape as tests/unit/anthropic_tool_decode_spec.lua).
local function sse(events)
    local out = {}
    for _, ev in ipairs(events) do
        table.insert(out, "event: " .. (ev.type or "unknown"))
        table.insert(out, "data: " .. vim.json.encode(ev))
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

-- A raw_response decoding to one propose_edits tool call with the given edits.
local function propose_edits_sse(edits)
    return sse({
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = "t1", name = "propose_edits", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = vim.json.encode({ edits = edits }) } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    })
end

local function read_file_sse(path)
    return sse({
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = "t_read", name = "read_file", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = vim.json.encode({ file_path = path }) } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    })
end

local function manifest(over)
    return vim.tbl_extend("force", {
        name = "t", description = "d", scope = "global", activation = { manual = true },
        source = function() return "SYSTEM BODY" end,
        tools = {}, elevated = { "propose_edits" }, force_tool = "propose_edits",
    }, over or {})
end

describe("skill_invoke.invoke", function()
    local tmpdir, path, buf
    local orig_query, orig_resolve
    local captured_payload, done_result

    before_each(function()
        require("parley.tools").register_builtins() -- propose_edits must be registered
        tmpdir = vim.fn.tempname() .. "-si"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/doc.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].autoread=true

        captured_payload, done_result = nil, nil

        -- isolate from real agent resolution (tested separately in M2)
        orig_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end

        orig_query = parley.dispatcher.query
        parley.dispatcher.query = function(_buf, _provider, payload, _handler, on_exit)
            captured_payload = payload
            tasker.set_query("qid_test", {
                raw_response = propose_edits_sse({
                    { old_string = "alpha", new_string = "ALPHA", explain = "uppercase" },
                }),
            })
            vim.schedule(function()
                on_exit("qid_test")
            end)
        end
    end)

    after_each(function()
        parley.dispatcher.query = orig_query
        assembly.resolve_agent = orig_resolve
        pcall(function() require("parley.progress").stop() end)
        remove_fixture_dir(tmpdir)
    end)

    for _,denied in ipairs({'admit','finish','observation'})do
        it('obeys pure model rejection of '..denied,function()
            local Model=require('parley.skill_source_read');local transition=Model.transition
            local FS=require('parley.tools.filesystem');local native_new=FS.new
            local read_calls,observed,callback=0,nil,nil
            FS.new=function(options)
                FS.new=native_new
                local fs=native_new(options);local authorize=fs.authorized
                fs.authorized=function(self,token)
                    local protected=authorize(self,token);local read=protected.read
                    protected.read=function(reader,file,done)
                        read_calls=read_calls+1;callback=done
                        return read(reader,file,function(value)observed=value;done(value)end)
                    end
                    return protected
                end
                return fs
            end
            local rejected=false
            Model.transition=function(pool,state,event)
                if event.type==denied then rejected=true;return pool,state,{}end
                return transition(pool,state,event)
            end
            skill_invoke.invoke(buf,manifest(),{},{on_done=function(r)done_result=r end})
            FS.new=native_new
            local reached=vim.wait(5000,function()return rejected end,1)
            Model.transition=transition
            assert.is_true(reached)
            if denied=='admit' then
                assert.equals(0,read_calls)
                assert.is_false(done_result.ok)
            elseif denied=='finish' then
                assert.is_nil(done_result)
                assert.is_true(skill_invoke.is_in_flight(buf))
                skill_invoke.cancel(buf)
                assert.is_false(skill_invoke.is_in_flight(buf))
            else
                assert.is_nil(done_result)
                assert.same({'alpha beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
                assert.is_true(skill_invoke.is_in_flight(buf))
                assert.is_true(observed.physical_resolved)
                callback(observed)
                assert.is_true(done_result.ok)
                assert.is_false(skill_invoke.is_in_flight(buf))
            end
        end)
    end

    for _,autoread in ipairs({false,true})do
        for _,mode in ipairs({'success','human','aba','cancel','ancestor','reload','detach'})do
            it('retains one source completion owner '..tostring(autoread)..' '..mode,function()
                vim.bo[buf].autoread=autoread
                local FS=require('parley.tools.filesystem');local native_new=FS.new
                local held,read_started
                FS.new=function(options)
                    FS.new=native_new
                    local fs=native_new(options);local authorize=fs.authorized
                    fs.authorized=function(self,token)
                        local protected=authorize(self,token);local read=protected.read
                        protected.read=function(reader,file,done)
                            read_started=true
                            local handle
                            held=function()handle=read(reader,file,done);return handle end
                            return {cancel=function()if handle then handle:cancel()end end,
                                reconcile=function()if handle then return handle:reconcile()end end,
                                snapshot=function()return handle and handle:snapshot() or {physical_resolved=false}end}
                        end
                        return protected
                    end
                    return fs
                end
                skill_invoke.invoke(buf,manifest(),{},{on_terminal=function(r)done_result=r end})
                FS.new=native_new
                assert.is_true(vim.wait(5000,function()return read_started or done_result~=nil end,1))
                assert.is_nil(done_result)
                assert.same({'ALPHA beta'},vim.fn.readfile(path))
                assert.same({'alpha beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
                if mode=='human' or mode=='aba' then
                    vim.api.nvim_buf_set_lines(buf,0,-1,false,{'human'})
                    if mode=='aba' then vim.api.nvim_buf_set_lines(buf,0,-1,false,{'alpha beta'}) end
                elseif mode=='cancel' then skill_invoke.cancel(buf)
                elseif mode=='reload' then vim.cmd('edit! '..vim.fn.fnameescape(path))
                elseif mode=='detach' then vim.api.nvim_buf_delete(buf,{force=true})
                elseif mode=='ancestor' then
                    assert(vim.uv.fs_rename(tmpdir,tmpdir..'-old'))
                    vim.fn.mkdir(tmpdir,'p');vim.fn.writefile({'redirected'},path)
                end
                held()
                assert.is_true(vim.wait(5000,function()return done_result~=nil end,1))
                if mode=='success' then
                    assert.is_true(done_result.ok)
                    assert.same({'ALPHA beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
                else
                    assert.is_false(done_result.ok)
                    if mode~='detach' then
                        assert.same({mode=='human' and 'human' or mode=='reload' and 'ALPHA beta' or 'alpha beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
                    end
                end
                if mode=='ancestor' then remove_fixture_dir(tmpdir..'-old')end
            end)
        end
    end

    it('bounds unresolved final reads and keeps cancelled slots until positive drain',function()
        local FS=require('parley.tools.filesystem');local native_new=FS.new
        local records,buffers={},{}
        for i=1,17 do
            local file=tmpdir..'/bounded-'..i..'.md';vim.fn.writefile({'alpha beta'},file)
            vim.cmd('edit! '..vim.fn.fnameescape(file))
            local b=vim.api.nvim_get_current_buf();buffers[#buffers+1]=b
            local record={};records[i]=record
            FS.new=function()
                FS.new=native_new
                return {authorized=function()return {read=function(_,_,done)
                    record.done=done
                    return {cancel=function()record.cancelled=true end,
                        reconcile=function()return false end,
                        snapshot=function()return {physical_resolved=false}end}
                end}end}
            end
            skill_invoke.invoke(b,manifest(),{},{on_terminal=function(value)record.terminal=value end})
            FS.new=native_new
            assert.is_true(vim.wait(5000,function()return record.done~=nil or record.terminal~=nil end,1))
            if i<=16 then
                assert.is_nil(record.terminal)
                skill_invoke.cancel(b)
                assert.is_true(record.cancelled)
                assert.is_true(skill_invoke.is_in_flight(b))
            else
                assert.equals('source read capacity',record.terminal.reason)
                assert.is_true(record.terminal.reconciliation_required)
            end
        end
        for i,record in ipairs(records)do
            if record.done then
                record.done({certainty='unknown',physical_resolved=false})
                assert.is_true(skill_invoke.is_in_flight(buffers[i]))
                record.done({certainty='known',physical_resolved=true})
                record.done({certainty='known',physical_resolved=true})
                assert.is_false(skill_invoke.is_in_flight(buffers[i]))
            end
            vim.api.nvim_buf_delete(buffers[i],{force=true})
        end
    end)

    it('retires reconciliation polling after its diagnostic without releasing the read',function()
        local FS=require('parley.tools.filesystem');local native_new=FS.new
        local done,polls,diagnostics=nil,0,0
        FS.new=function()
            FS.new=native_new
            return {authorized=function()return {read=function(_,_,callback)
                done=callback
                return {cancel=function()end,reconcile=function()polls=polls+1;return true end,
                    snapshot=function()return {physical_resolved=false}end}
            end}end}
        end
        skill_invoke.invoke(buf,manifest(),{},{on_terminal=function(r)done_result=r end})
        FS.new=native_new
        assert.is_true(vim.wait(5000,function()return done~=nil end,1))
        skill_invoke.cancel(buf)
        local clock=vim.uv.hrtime;local warning=parley.logger.warning
        local now=clock()+6000000000
        vim.uv.hrtime=function()return now end
        parley.logger.warning=function(message)
            if message:find('source read cleanup unresolved',1,true)then diagnostics=diagnostics+1 end
        end
        local observed=vim.wait(1000,function()return diagnostics==1 end,1)
        vim.uv.hrtime=clock;parley.logger.warning=warning
        assert.is_true(observed)
        local count=polls;vim.wait(30,function()return false end,1)
        assert.equals(count,polls)
        assert.is_true(skill_invoke.is_in_flight(buf))
        done({certainty='known',physical_resolved=true})
        assert.is_false(skill_invoke.is_in_flight(buf))
    end)

    it('finishes missing-callback reads logically at the deadline while retaining cleanup ownership',function()
        local FS=require('parley.tools.filesystem');local native_new=FS.new
        local done,cancelled,deliveries=nil,false,0
        FS.new=function()
            FS.new=native_new
            return {authorized=function()return {read=function(_,_,callback)
                done=callback
                return {cancel=function()cancelled=true end,reconcile=function()return false end,
                    snapshot=function()return {physical_resolved=false}end}
            end}end}
        end
        local progress=require('parley.progress');local stop=progress.stop;local stopped=0
        progress.stop=function(...)stopped=stopped+1;return stop(...)end
        local weak=setmetatable({},{__mode='v'})
        local callback
        do
            local ui={};weak[1]=ui
            callback=function(r)assert(ui);deliveries=deliveries+1;done_result=r end
        end
        skill_invoke.invoke(buf,manifest(),{},{on_done=callback})
        callback=nil
        FS.new=native_new
        assert.is_true(vim.wait(5000,function()return done~=nil end,1))
        local D=require('parley.document');local doc=D.get(buf)
        assert.is_true(D.user_guard_stats(doc).live>0)
        local clock=vim.uv.hrtime;local now=clock()+6000000000
        vim.uv.hrtime=function()return now end
        local observed=vim.wait(1000,function()return done_result~=nil end,1)
        vim.uv.hrtime=clock;progress.stop=stop
        assert.is_true(observed)
        assert.equals(1,deliveries);assert.is_true(stopped>0)
        assert.is_false(done_result.ok);assert.is_true(done_result.reconciliation_required)
        assert.equals('unknown',done_result.certainty)
        assert.equals(0,D.user_guard_stats(doc).live)
        collectgarbage('collect');collectgarbage('collect')
        assert.is_nil(weak[1],'physical cleanup must not retain UI callback captures')
        assert.is_true(cancelled);assert.is_true(skill_invoke.is_in_flight(buf))
        done({certainty='known',physical_resolved=true,data='late'})
        done({certainty='known',physical_resolved=true,data='late'})
        assert.equals(1,deliveries);assert.is_false(skill_invoke.is_in_flight(buf))
        assert.same({'alpha beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
    end)

    it('keeps the source untouched for no_reload even with autoread enabled',function()
        skill_invoke.invoke(buf,manifest(),{},{no_reload=true,on_done=function(r)done_result=r end})
        assert.is_true(vim.wait(5000,function()return done_result~=nil end,1))
        assert.is_true(done_result.ok)
        assert.same({'alpha beta'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same({'ALPHA beta'},vim.fn.readfile(path))
    end)

    it("preserves truncation evidence in the skill result delivered to its caller", function()
        local large = tmpdir .. "/large.txt"
        vim.fn.writefile({ string.rep("x", 600000) }, large, "b")
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_large_read", { raw_response = read_file_sse(large) })
            vim.schedule(function() on_exit("qid_large_read") end)
        end
        skill_invoke.invoke(buf, manifest({ tools = { "read_file" }, elevated = {}, force_tool = "read_file" }), {}, {
            no_reload = true, on_done = function(result) done_result = result end,
        })
        assert.is_true(vim.wait(5000, function() return done_result ~= nil end, 1))
        assert.is_true(done_result.ok)
        local result = done_result.results[1]
        assert.is_true(result.truncated)
        assert.truthy(result.content:find("[Tool result incomplete]", 1, true))
        assert.is_true(#result.content <= 524288)
    end)

    it("drives one exchange: payload + force_tool, applies propose_edits, reloads, on_done", function()
        skill_invoke.invoke(buf, manifest(), {}, {
            manual = true,
            on_done = function(r) done_result = r end,
        })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result, "on_done never ran")
        assert.is_true(done_result.ok)
        -- payload: force_tool → tool_choice; the system body is messages[1]
        assert.are.same({ type = "tool", name = "propose_edits" }, captured_payload.tool_choice)
        -- large-document headroom: max_tokens bumped well past the 4096 default
        assert.is_true((captured_payload.max_tokens or 0) >= 100000)
        -- propose_edits applied to the artifact FILE via the real execute_call path
        assert.are.equal("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
        -- the artifact BUFFER was reloaded to match
        assert.are.equal("ALPHA beta", table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
        -- a numbered backup was made (M3 Task 1)
        assert.are.equal(1, vim.fn.filereadable(path .. ".parley-backup.1"))
        -- #133 M3: on_done payload carries the journal-feeding fields
        assert.are.equal("alpha beta", done_result.original)
        assert.are.equal("ALPHA beta", done_result.new_content)
        assert.is_true(#done_result.decorations >= 1)
        assert.are.equal("edit", done_result.decorations[1].kind)
        assert.are.equal("uppercase", done_result.decorations[1].explain)
    end)

    it("preserves unsaved human text when a disk-editing skill completes", function()
        skill_invoke.invoke(buf, manifest(), {}, {
            on_done = function(r) done_result = r end,
        })
        vim.api.nvim_buf_set_text(buf, 0, 10, 0, 10, { " human" })
        assert.is_true(vim.wait(2000, function() return done_result ~= nil end))
        assert.equals("alpha beta human", table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
        assert.equals("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
        assert.is_false(done_result.ok)
        assert.is_true(done_result.reconciliation_required)
        assert.equals(vim.fn.resolve(path), vim.fn.resolve(done_result.external_path))
    end)

    it("coerces a stringified edits array and applies it (model quirk, #133)", function()
        -- Some models emit the propose_edits `edits` arg as a JSON STRING, not an
        -- array. The driver must coerce it (so it applies) and not crash the renderer.
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            local edits_str = vim.json.encode({ { old_string = "alpha", new_string = "ALPHA", explain = "up" } })
            tasker.set_query("qid_str", {
                raw_response = sse({
                    { type = "content_block_start", index = 0,
                      content_block = { type = "tool_use", id = "t1", name = "propose_edits", input = {} } },
                    { type = "content_block_delta", index = 0,
                      delta = { type = "input_json_delta", partial_json = vim.json.encode({ edits = edits_str }) } },
                    { type = "content_block_stop", index = 0 },
                    { type = "message_stop" },
                }),
            })
            vim.schedule(function() on_exit("qid_str") end)
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_not_nil(done_result, "on_done never ran (renderer likely crashed)")
        assert.is_true(done_result.ok)
        assert.are.equal("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
    end)

    it("surfaces a failed edit: on_done ok=false, applied=0, file untouched", function()
        -- non-unique old_string → compute_edits fails → propose_edits is_error
        vim.fn.writefile({ "ab ab" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_err", {
                raw_response = propose_edits_sse({
                    { old_string = "ab", new_string = "X", explain = "non-unique" },
                }),
            })
            vim.schedule(function() on_exit("qid_err") end)
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_not_nil(done_result)
        assert.is_false(done_result.ok)
        assert.are.equal(0, done_result.applied)
        assert.are.equal("ab ab", table.concat(vim.fn.readfile(path), "\n")) -- untouched
    end)

    it("is_in_flight true during a query; cancel clears it + supersedes the exchange (#133)", function()
        local held_exit
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            held_exit = on_exit -- hold it open; don't complete the query
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        assert.is_true(skill_invoke.is_in_flight(buf))
        skill_invoke.cancel(buf)
        assert.is_false(skill_invoke.is_in_flight(buf))
        -- The now-superseded query completes late → its on_exit must no-op.
        tasker.set_query("qid_stale", { raw_response = "" })
        held_exit("qid_stale")
        vim.wait(200, function() return done_result ~= nil end)
        assert.is_nil(done_result, "a cancelled query's late on_exit must not run on_done")
    end)

    it("shows the progress bar during the query and stops it on completion (#133 M7)", function()
        local progress = require("parley.progress")
        local held_exit
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            held_exit = on_exit
            tasker.set_query("qid_p", {
                raw_response = propose_edits_sse({
                    { old_string = "alpha", new_string = "ALPHA", explain = "up" },
                }),
            })
        end
        progress.stop()
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        assert.is_true(progress.is_active(), "bar shows while the query runs")
        held_exit("qid_p")
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_false(progress.is_active(), "bar stops when the query completes")
    end)

    it("aborts (on_done ok=false) when no agent resolves", function()
        assembly.resolve_agent = function() return nil end
        local query_called = false
        parley.dispatcher.query = function() query_called = true end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(500, function() return done_result ~= nil end)
        assert.is_not_nil(done_result)
        assert.is_false(done_result.ok)
        assert.is_false(query_called, "must not query without an agent")
    end)

    it("aborts gracefully (on_done ok=false) when source() throws", function()
        -- a fallible source (e.g. voice_apply with a missing style file) must route
        -- through on_done, not throw a raw Lua error past the caller.
        local query_called = false
        parley.dispatcher.query = function() query_called = true end
        local m = manifest({ source = function() error("style file not found") end })
        skill_invoke.invoke(buf, m, {}, { on_done = function(r) done_result = r end })
        vim.wait(500, function() return done_result ~= nil end)
        assert.is_not_nil(done_result, "on_done must run even when source throws")
        assert.is_false(done_result.ok)
        assert.is_truthy((done_result.msg or ""):find("source", 1, true))
        assert.is_false(query_called, "must not query when source failed")
    end)

    it("widens relative reads from ordinary nested repo Markdown", function()
        local repo = tmpdir .. "/repo"
        local nested = repo .. "/data/nested"
        vim.fn.mkdir(nested, "p")
        vim.fn.writefile({ "repo root file" }, repo .. "/README.md")
        path = nested .. "/doc.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()

        parley.config.repo_root = repo

        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_read", {
                -- #192: reads resolve from the write root (nested) only; the
                -- repo root is permission, not a fallback base — traverse to it.
                raw_response = read_file_sse("../../README.md"),
            })
            vim.schedule(function() on_exit("qid_read") end)
        end

        skill_invoke.invoke(buf, manifest({
            tools = { "read_file" },
            elevated = {},
            force_tool = "read_file",
        }), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result)
        assert.is_true(done_result.ok)
        assert.equals("repo root file", done_result.results[1].content:match("repo root file"))
    end)

    it("executes relative tool paths from a super-repo sibling chat neighborhood", function()
        local current_repo = tmpdir .. "/current"
        local sibling_repo = tmpdir .. "/sibling"
        local current_chat = current_repo .. "/workshop/parley"
        local sibling_chat = sibling_repo .. "/workshop/parley"
        vim.fn.mkdir(current_chat, "p")
        vim.fn.mkdir(sibling_chat, "p")
        vim.fn.writefile({ "sibling repo root file" }, sibling_repo .. "/README.md")
        path = sibling_chat .. "/2026-06-29.topic.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()

        parley.config.repo_root = current_repo
        parley.config.repo_chat_dir = "workshop/parley"
        parley.config.chat_roots = {
            { dir = current_chat, label = "repo" },
            { dir = sibling_chat, label = "sibling" },
        }

        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_sibling_read", {
                raw_response = read_file_sse("README.md"),
            })
            vim.schedule(function() on_exit("qid_sibling_read") end)
        end

        skill_invoke.invoke(buf, manifest({
            tools = { "read_file" },
            elevated = {},
            force_tool = "read_file",
        }), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result)
        assert.is_true(done_result.ok)
        assert.equals("sibling repo root file", done_result.results[1].content:match("sibling repo root file"))
    end)
    it("keeps asynchronous skill tools supervised while human buffer edits continue", function()
        local registry=require('parley.tools')
        local done,legacy= nil,0
        registry.register({name='skill_async_fixture',description='async fixture',
            input_schema={type='object',properties={}},
            handler=function()legacy=legacy+1;return {content='legacy'}end,
            resources=function()return {}end,
            execute_async=function(_,_,callback)done=callback;return {cancel=function()end}end})
        parley.dispatcher.query=function(_,_,_,_,exit)
            tasker.set_query('async_skill',{raw_response=sse({
                {type='content_block_start',index=0,content_block={type='tool_use',id='async',name='skill_async_fixture',input={}}},
                {type='content_block_stop',index=0}})})
            exit('async_skill')
        end
        skill_invoke.invoke(buf,manifest({tools={'skill_async_fixture'},elevated={},force_tool=nil}),{},
            {no_reload=true,on_done=function(result)done_result=result end})
        assert.is_true(vim.wait(2000,function()return done~=nil end,1))
        assert.equals(0,legacy);assert.is_nil(done_result)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'human continued editing'})
        done({certainty='known',effect='not_applied',physical_resolved=true,result={content='async',is_error=false}})
        assert.is_true(vim.wait(2000,function()return done_result~=nil end,1))
        assert.is_true(done_result.ok)
        assert.same({'human continued editing'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
    end)

end)

describe("skill_invoke terminal ownership (#182)", function()
    local parley = require("parley")
    local skill_invoke = require("parley.skill_invoke")
    local assembly = require("parley.skill_assembly")
    local tasker = require("parley.tasker")
    local tmpdir, path, buf, original_query, original_resolve

    local function terminal_manifest(overrides)
        return vim.tbl_extend("force", {
            name = "terminal-test",
            description = "d",
            scope = "global",
            activation = { manual = true },
            source = function() return "SYSTEM" end,
            tools = {},
        }, overrides or {})
    end

    before_each(function()
        tmpdir = vim.fn.tempname() .. "-skill-terminal"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/doc.md"
        vim.fn.writefile({ "alpha" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        original_query = parley.dispatcher.query
        original_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end
        require("parley.progress").stop()
    end)

    after_each(function()
        parley.dispatcher.query = original_query
        assembly.resolve_agent = original_resolve
        pcall(skill_invoke.cancel, buf)
        pcall(function() require("parley.progress").stop() end)
        pcall(vim.cmd, "enew!")
        remove_fixture_dir(tmpdir)
    end)

    it("suppresses detached progress only when explicitly requested", function()
        local held_exit
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
            held_exit = on_exit
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
        assert.is_false(require("parley.progress").is_active())
        skill_invoke.cancel(buf)

        skill_invoke.invoke(buf, terminal_manifest(), {}, {})
        assert.is_true(require("parley.progress").is_active())
        skill_invoke.cancel(buf)
        tasker.set_query("late", { raw_response = "" })
        held_exit("late")
    end)

    it("owns each async terminal once and orders terminal before done", function()
        local terminals = {
            {
                name = "success",
                fire = function(c) tasker.set_query("q", { raw_response = "" }); c.on_exit("q") end,
            },
            { name = "pre-query abort", fire = function(c) c.on_abort("abort") end },
            { name = "transport error", fire = function(c) c.on_error("q", { code = 7 }) end },
        }
        for _, case in ipairs(terminals) do
            local callbacks, events = {}, {}
            parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, on_abort, _activity, on_error)
                callbacks = { on_exit = on_exit, on_abort = on_abort, on_error = on_error }
            end
            skill_invoke.invoke(buf, terminal_manifest(), {}, {
                detached_progress = false,
                on_terminal = function() table.insert(events, "terminal") end,
                on_done = function() table.insert(events, "done") end,
            })
            case.fire(callbacks)
            assert.is_true(vim.wait(1000, function() return #events == 2 end, 10), case.name)
            callbacks.on_abort("late")
            callbacks.on_error("q", { code = 8 })
            assert.are.same({ "terminal", "done" }, events, case.name)
            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
        end
    end)

    it("cancel delivers terminal cleanup once, skips done, and ignores late callbacks", function()
        local held_exit, held_error, events = nil, nil, {}
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, _abort, _activity, on_error)
            held_exit, held_error = on_exit, on_error
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function() table.insert(events, "terminal") end,
            on_done = function() table.insert(events, "done") end,
        })
        skill_invoke.cancel(buf)
        skill_invoke.cancel(buf)
        tasker.set_query("late", { raw_response = "" })
        held_exit("late")
        held_error("late", { code = 7 })
        vim.wait(100, function() return false end)
        assert.are.same({ "terminal" }, events)
    end)

    it("finishes invalid scheduled completion without reading or delivering done", function()
        local held_exit, events = nil, {}
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
            held_exit = on_exit
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function(result) table.insert(events, result.msg) end,
            on_done = function() table.insert(events, "done") end,
        })
        vim.api.nvim_buf_delete(buf, { force = true })
        tasker.set_query("deleted", { raw_response = "" })
        held_exit("deleted")
        assert.is_true(vim.wait(1000, function() return #events > 0 end, 10))
        assert.are.same({ "buffer invalid" }, events)
    end)

    it("delivers synchronous terminal failures once before done", function()
        local cases = {
            {
                name = "no file",
                setup = function()
                    vim.cmd("enew!")
                    buf = vim.api.nvim_get_current_buf()
                end,
                manifest = terminal_manifest(),
                message = "buffer has no file",
            },
            {
                name = "source failure",
                setup = function() end,
                manifest = terminal_manifest({ source = function() error("boom") end }),
                message = "source failed",
            },
            {
                name = "no agent",
                setup = function() assembly.resolve_agent = function() return nil end end,
                manifest = terminal_manifest(),
                message = "no agent",
            },
        }
        for _, case in ipairs(cases) do
            if case.name ~= "no file" then
                vim.cmd("edit! " .. vim.fn.fnameescape(path))
                buf = vim.api.nvim_get_current_buf()
            end
            case.setup()
            local events = {}
            skill_invoke.invoke(buf, case.manifest, {}, {
                detached_progress = false,
                on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
                on_done = function() table.insert(events, "done") end,
            })
            assert.are.equal(2, #events, case.name)
            assert.is_truthy(events[1]:find(case.message, 1, true), case.name)
            assert.are.equal("done", events[2], case.name)
            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
        end
    end)

    it("rejects a second invocation through its own ordered terminal", function()
        parley.dispatcher.query = function() end
        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
        local events = {}
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
            on_done = function() table.insert(events, "done") end,
        })
        assert.are.same({ "terminal:already running", "done" }, events)
        assert.is_true(skill_invoke.is_in_flight(buf), "the first invocation must remain owned")
        skill_invoke.cancel(buf)
    end)

    it("finishes a malformed scheduled completion and contains terminal callback failure", function()
        parley.dispatcher.query = function(_b, _p, _payload, _handler, on_exit)
            tasker.set_query("malformed", {
                raw_response = sse({
                    { type = "content_block_start", index = 0,
                      content_block = { type = "tool_use", id = "bad", input = {} } },
                    { type = "content_block_stop", index = 0 },
                    { type = "message_stop" },
                }),
            })
            vim.schedule(function() on_exit("malformed") end)
        end
        local done, terminal_calls = nil, 0
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            on_terminal = function()
                terminal_calls = terminal_calls + 1
                error("caller failure must be contained")
            end,
            on_done = function(result) done = result end,
        })
        assert.is_true(vim.wait(1000, function() return done ~= nil end, 10),
            "malformed completion leaked its terminal")
        assert.are.equal(1, terminal_calls)
        assert.is_false(done.ok)
        assert.are.equal("completion failed", done.msg)
        assert.is_false(skill_invoke.is_in_flight(buf))
        assert.is_false(require("parley.progress").is_active())
    end)
end)
