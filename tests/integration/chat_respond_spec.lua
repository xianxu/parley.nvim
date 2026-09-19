-- Integration tests for M.chat_respond in lua/parley/init.lua
--
-- These tests exercise the full chat_respond flow including the completion callback,
-- which requires mocking the dispatcher and tasker.

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chat-respond-" .. os.time()

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    -- These transport fixtures own a configured model; onboarding is tested separately.
    default_agent = "FixtureAnthropic",
    agents = {
        { name = "Choose a model", disable = true },
        { name = "FixtureAnthropic", provider = "anthropic",
          model = { model = "claude-sonnet-5" }, system_prompt = "You are a helpful assistant.",
          tools = { "@all" } },
    },
    providers = {},
    api_keys = {},
})

-- Create the chat directory
vim.fn.mkdir(tmp_dir, "p")

-- Helper to create valid chat filenames (must have timestamp format for not_chat validation)
local function make_chat_filename()
    return tmp_dir .. "/2026-03-01-test-" .. os.time() .. "-" .. math.random(100000) .. ".md"
end

local function mk_read_file_sse_response(toolu_id, path)
    local events = {
        { type = "message_start", message = { id = "msg_test", model = "claude-sonnet-4-6" } },
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = toolu_id, name = "read_file", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = '{"path":"' .. path .. '"}' } },
        { type = "content_block_stop", index = 0 },
        { type = "message_delta", delta = { stop_reason = "tool_use" } },
        { type = "message_stop" },
    }
    local lines = {}
    for _, ev in ipairs(events) do
        table.insert(lines, "event: " .. (ev.type or "unknown"))
        table.insert(lines, "data: " .. vim.json.encode(ev))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

local function buffer_contains(buf, needle)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    return text:find(needle, 1, true) ~= nil
end

local function find_line_number(buf, text)
    for index, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        if line == text then return index end
    end
    return nil
end

local Respond=require('parley.chat_respond')
local function wait_for(predicate)
    assert.is_true(vim.wait(5000,predicate,1),'response did not settle')
end
-- Native buffers with a stateful transport fixture: physical terminal callbacks
-- are explicit, and each response exposes its actual session lifetime.
describe('chat_respond: scoped session integration',function()
    local old_query,old_stop,old_agent,buf,calls,files
    before_each(function()
        calls,files={},{};old_agent=parley._state.agent
        old_query,old_stop=parley.dispatcher.query,parley.tasker.stop_owner
        parley.dispatcher.query=function(b,provider,payload,output,complete,_,_,abort,model,failure,opts)
            local id='session-fixture:'..#calls
            local call={id=id,buf=b,provider=provider,model=model,payload=payload,output=output,
                complete=complete,abort=abort,failure=failure,opts=opts,running=true}
            calls[#calls+1]=call
            parley.tasker.set_query(id,{buf=b,response='',raw_response='',
                tool_wire=provider=='openai' and 'openai' or 'anthropic'})
            return id
        end
        parley.tasker.stop_owner=function(owner)
            for _,call in ipairs(calls)do
                if call.running and call.opts.generation_id==owner then
                    call.running=false;vim.schedule(function()call.abort('cancelled')end)
                end
            end
        end
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,make_chat_filename())
        vim.api.nvim_set_current_buf(buf)
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _,call in ipairs(calls)do call.abort('fixture cleanup')end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        parley.dispatcher.query,parley.tasker.stop_owner=old_query,old_stop
        for _,path in ipairs(files)do vim.fn.delete(path)end
        parley._state.agent=old_agent;parley.agents.OpenAiFamilyTest=nil
    end)
    local function open(body)
        local lines={'# topic: Existing topic','- file: fixture.md','---',''}
        for _,line in ipairs(body)do lines[#lines+1]=line end
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
        vim.api.nvim_win_set_cursor(0,{5,0})
    end
    local function submit()
        local session=Respond.respond({range=0});assert.is_not_nil(session)
        wait_for(function()return #calls>0 end)
        return session
    end
    local function output(call,bytes)
        local query=parley.tasker.get_query(call.id);query.response=query.response..bytes
        call.output(call.id,bytes)
    end
    local function complete(session,call)
        call.running=false;call.complete(call.id)
        wait_for(function()return Respond.response_snapshot(session).status=='terminal'end)
        return Respond.response_snapshot(session).generation
    end
    it('cleans recovery only after the chat deletion is confirmed',function()
        open({'💬: question',''})
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf,0,-1,false),path)
        local Recovery=require('parley.chat_recovery')
        local old_deleted,old_delete=Recovery.deleted,parley.helpers.delete_file
        local calls_deleted=0
        Recovery.deleted=function(captured)
            calls_deleted=calls_deleted+1;assert.equals(path,captured)
            assert.equals(0,vim.fn.filereadable(path));return {ok=true}
        end
        parley.helpers.delete_file=function()return nil,'injected deletion refusal'end
        local failed=parley.delete_chat_file(path)
        parley.helpers.delete_file=old_delete
        assert.is_nil(failed);assert.equals(0,calls_deleted)
        local ok=parley.delete_chat_file(path)
        Recovery.deleted=old_deleted
        assert.is_true(ok);assert.equals(1,calls_deleted)
    end)
    -- #261: the reported blocker. Regenerate, edit the answer while it streams
    -- (the edit revokes the generation), then regenerate again. Before #261 the
    -- retained on-disk snapshot said "original" while the buffer held the
    -- partial answer; once the in-process retry cache was invalidated (a second
    -- edit, a reload, a reopen) every retry was refused.
    local function row_containing(needle)
        for index,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false))do
            if line:find(needle,1,true) then return index end
        end
    end
    local function regenerate_then_revoke()
        open({'💬: question','','🤖: original','valuable answer',''})
        local first=submit()
        output(calls[1],'partial new text')
        wait_for(function()return buffer_contains(buf,'partial new text')end)
        -- Where the text lands relative to the answer header is the layout's
        -- business; the edit only has to fall inside the granted output.
        local row=assert(row_containing('partial new text'))
        vim.api.nvim_buf_set_text(buf,row-1,0,row-1,0,{'edited '})
        wait_for(function()return Respond.response_snapshot(first).status=='terminal'end)
        assert.equals('revoked',Respond.response_snapshot(first).generation.outcome)
        return row
    end
    local function submit_again()
        vim.api.nvim_win_set_cursor(0,{5,0})
        Respond.respond({range=0})
        wait_for(function()return #calls==2 end)
    end
    -- Characterization: passes before #261 through the in-process retry cache.
    -- Kept because deleting that cache must not break the immediate retry.
    it('regenerates immediately after a revoked regeneration',function()
        regenerate_then_revoke(); submit_again()
    end)
    it('regenerates after a revoked regeneration and a further edit (#261)',function()
        local row=regenerate_then_revoke()
        vim.api.nvim_buf_set_text(buf,row-1,0,row-1,0,{'again '})
        submit_again()
    end)
    it('regenerates after a revoked regeneration and a reload (#261)',function()
        regenerate_then_revoke()
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.cmd('silent write!');vim.cmd('edit!')
        submit_again()
    end)
    it('regenerates after a revoked regeneration, closing and reopening the chat (#261)',function()
        regenerate_then_revoke()
        local path=vim.api.nvim_buf_get_name(buf);files[#files+1]=path
        vim.cmd('silent write!')
        vim.api.nvim_buf_delete(buf,{force=true})
        vim.cmd('edit '..vim.fn.fnameescape(path));buf=vim.api.nvim_get_current_buf()
        submit_again()
    end)
    it('regenerates regardless of a legacy answer-recovery directory (#261)',function()
        local legacy=parley.config.state_dir..'/answer-recovery'
        vim.fn.mkdir(legacy,'p');vim.uv.fs_chmod(legacy,tonumber('755',8))
        vim.fn.writefile({'not json'},legacy..'/0.1.json')
        local ok,err=pcall(function()
            open({'💬: question','','🤖: original','valuable answer',''})
            submit()
        end)
        vim.fn.delete(legacy,'rf')
        assert(ok,err)
    end)
    it('supports explicit edit adoption through the registered resume command',function()
        open({'💬: first','','🤖: old first','','💬: second',''})
        vim.api.nvim_win_set_cursor(0,{9,0})
        local batch=assert(Respond.respond_all())
        wait_for(function()return #calls==1 end)
        local second=assert(find_line_number(buf,'💬: second'))
        vim.api.nvim_buf_set_text(buf,second-1,6,second-1,6,{'edited '})
        output(calls[1],'new first');calls[1].complete(calls[1].id)
        wait_for(function()return Respond.batch_snapshot(batch).phase=='paused'end)
        assert.equals(1,Respond.batch_snapshot(batch).completed)
        vim.cmd('ParleyChatResumeBatch!')
        wait_for(function()return #calls==2 end)
        assert.truthy(vim.json.encode(calls[2].payload):find('edited second',1,true))
    end)
    it('runs a captured batch while the operator edits another chat',function()
        open({'💬: first','','🤖: old first','','💬: second',''})
        vim.api.nvim_win_set_cursor(0,{9,0})
        local free=parley.config.chat_free_cursor
        local batch=Respond.respond_all();assert.is_not_nil(batch)
        wait_for(function()return #calls==1 end)
        local other=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(other)
        vim.api.nvim_buf_set_lines(other,0,-1,false,{'operator work'})
        local second=assert(find_line_number(buf,'💬: second'))
        vim.api.nvim_buf_set_lines(buf,second-1,second-1,false,{'💬: unselected insertion','','🤖: unselected answer',''})
        output(calls[1],'new first');calls[1].complete(calls[1].id)
        wait_for(function()return #calls==2 end)
        assert.equals(buf,calls[2].buf)
        assert.is_nil(vim.json.encode(calls[2].payload):find('unselected insertion',1,true))
        output(calls[2],'new second');calls[2].complete(calls[2].id)
        wait_for(function()return Respond.batch_snapshot(batch).phase=='completed'end)
        assert.equals(free,parley.config.chat_free_cursor)
        assert.same({'operator work'},vim.api.nvim_buf_get_lines(other,0,-1,false))
        assert.equals(other,vim.api.nvim_get_current_buf())
        vim.api.nvim_set_current_buf(buf);vim.api.nvim_buf_delete(other,{force=true})
    end)
    it('completes once with a new prompt and retains existing headers',function()
        open({'💬: question',''})
        local session=submit();output(calls[1],'answer')
        assert.equals('success',complete(session,calls[1]).outcome)
        calls[1].complete(calls[1].id)
        local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
        assert.truthy(text:find('# topic: Existing topic',1,true))
        assert.truthy(text:find('answer',1,true))
        local _,count=text:gsub('💬:','');assert.equals(2,count)
    end)
    for _,divider in ipairs({false,true})do
    it('preserves raw annotations and footnotes with footer divider '..tostring(divider),function()
        local body={'💬: question','','🤖: old','old answer','🌿: child.md: branch','🔒: private',''}
        if divider then body[#body+1]='---';body[#body+1]=''end
        body[#body+1]='[^1]: source';open(body)
        local session=submit();output(calls[1],'fresh answer')
        assert.equals('success',complete(session,calls[1]).outcome)
        assert.is_false(buffer_contains(buf,'old answer'))
        for _,value in ipairs({'🌿: child.md: branch','🔒: private','[^1]: source','fresh answer'})do
            assert.is_true(buffer_contains(buf,value),value)
        end
        local note=assert(find_line_number(buf,'🔒: private'))
        local footer=assert(find_line_number(buf,'[^1]: source'))
        local prompt=assert(find_line_number(buf,'💬:'))
        assert.is_true(prompt>note and prompt<footer)
    end)
    end
    it('replaces a middle answer without duplicating the human next question',function()
        open({'💬: question','🤖: old','old answer','','💬: human','draft'})
        local session=submit();output(calls[1],'replacement')
        assert.equals('success',complete(session,calls[1]).outcome)
        local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
        assert.is_nil(text:find('old answer',1,true))
        assert.truthy(text:find('💬: human\ndraft',1,true))
        local _,count=text:gsub('💬:','');assert.equals(2,count)
    end)
    it('leaves the cursor with the human next draft while background text arrives',function()
        open({'💬: question','🤖: old','old answer','','💬: human','draft'})
        local session=submit()
        vim.api.nvim_win_set_cursor(0,{assert(find_line_number(buf,'draft')),3})
        output(calls[1],'background answer')
        complete(session,calls[1])
        -- #266: the answer header now lands with the first output, above the
        -- draft, so the draft's row moves; the cursor must move with it.
        assert.same({assert(find_line_number(buf,'draft')),3},vim.api.nvim_win_get_cursor(0))
    end)
    it('drains admitted partial output before provider failure without a success prompt',function()
        open({'💬: question',''})
        local session=submit();output(calls[1],'partial one');output(calls[1],' partial two')
        calls[1].running=false;calls[1].failure(calls[1].id,'fixture transport failure')
        wait_for(function()return Respond.response_snapshot(session).status=='terminal'end)
        local result=Respond.response_snapshot(session).generation
        assert.equals('provider_failed',result.outcome)
        assert.is_true(buffer_contains(buf,'partial one partial two'))
        local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
        local _,count=text:gsub('💬:','');assert.equals(1,count)
    end)
    it('does not revive revoked writes after undo restores a deleted question',function()
        open({'💬: question',''})
        local session=submit();output(calls[1],'before deletion')
        wait_for(function()return buffer_contains(buf,'before deletion')end)
        vim.api.nvim_buf_set_lines(buf,4,5,false,{'replacement'})
        vim.cmd('undo')
        output(calls[1],' forbidden late bytes')
        calls[1].running=false;calls[1].complete(calls[1].id)
        wait_for(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.is_false(buffer_contains(buf,'forbidden late bytes'))
        assert.is_not.equals('success',Respond.response_snapshot(session).generation.outcome)
    end)
    it('creates folds for streamed thinking and an adjacent summary through the shared document',function()
        open({'💬: question',''})
        require('parley.tool_folds').setup(buf)
        local session=submit();output(calls[1],'🧠: first\nsecond\n\nanswer\n📝: summary')
        complete(session,calls[1])
        local thinking=assert(find_line_number(buf,'🧠: first'))
        local summary=assert(find_line_number(buf,'📝: summary'))
        wait_for(function()return vim.fn.foldlevel(thinking)>0 and vim.fn.foldlevel(summary)>0 end)
        vim.cmd('normal! zM')
        assert.equals(thinking,vim.fn.foldclosed(thinking))
        assert.equals(thinking+1,vim.fn.foldclosedend(thinking))
        assert.equals(summary,vim.fn.foldclosed(summary))
    end)
    for _,provider in ipairs({'anthropic','openai'})do
    it('reserves tool results and continues with frozen messages for '..provider,function()
        open({'💬: read the fixture',''})
        local path=tmp_dir..'/tool-fixture.txt';files[#files+1]=path
        vim.fn.writefile({'fixture tool content'},path)
        if provider=='openai'then
            parley.agents.OpenAiFamilyTest={name='OpenAiFamilyTest',provider='openai',
                model={model='fixture-openai'},system_prompt='Fixture',tools={'@all'}}
            parley._state.agent='OpenAiFamilyTest'
        end
        local session=submit();local first=calls[1]
        local qt=parley.tasker.get_query(first.id)
        qt.raw_response=mk_read_file_sse_response('tool-fixture',path)
        if provider=='openai'then
            qt.raw_response='data: '..vim.json.encode({choices={{delta={tool_calls={{index=0,id='tool-fixture',
                type='function',['function']={name='read_file',arguments=vim.json.encode({path=path})}}}}}}})..'\n\ndata: [DONE]\n'
        end
        first.running=false;first.complete(first.id)
        wait_for(function()return #calls==2 or Respond.response_snapshot(session).status=='terminal'end)
        assert.equals(2,#calls,vim.inspect(Respond.response_snapshot(session)))
        assert.equals(provider,calls[2].provider)
        assert.is_true(buffer_contains(buf,'fixture tool content'))
        local payload=vim.inspect(calls[2].payload)
        assert.truthy(payload:find(provider=='openai' and 'tool_call_id' or 'tool_result',1,true))
        assert.truthy(payload:find('fixture tool content',1,true))
        output(calls[2],'finished');assert.equals('success',complete(session,calls[2]).outcome)
    end)
    end
    it('refuses files outside the chat directory and malformed headers before provider IO',function()
        vim.api.nvim_buf_set_name(buf,vim.fn.tempname()..'.md')
        open({'💬: question'})
        assert.is_nil(Respond.respond({range=0}));assert.equals(0,#calls)
        vim.api.nvim_buf_set_name(buf,make_chat_filename())
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Missing separator','💬: question'})
        assert.is_nil(Respond.respond({range=0}));assert.equals(0,#calls)
    end)
end)

describe("chat_respond_all", function()
    local test_file
    local original_query
    local original_defer_fn
    local original_fetch_content
    local google_drive

    before_each(function()
        test_file = make_chat_filename()
        original_query = parley.dispatcher.query
        original_defer_fn = vim.defer_fn
        google_drive = require("parley.oauth")
        original_fetch_content = google_drive.fetch_content
    end)

    after_each(function()
        if original_query then
            parley.dispatcher.query = original_query
        end
        if original_defer_fn then
            vim.defer_fn = original_defer_fn
        end
        if original_fetch_content then
            google_drive.fetch_content = original_fetch_content
        end
        if test_file and vim.fn.filereadable(test_file) == 1 then
            vim.fn.delete(test_file)
        end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buftype") == "" then
                pcall(vim.api.nvim_buf_delete, buf, {force = true})
            end
        end
    end)

    it("calls dispatcher once per exchange sequentially", function()
        local chat_content = [[
# topic: Test
- file: test.md
---

💬: First question

🤖: First answer

💬: Second question
]]

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()

        -- Position cursor on second question (line 10)
        vim.api.nvim_win_set_cursor(0, {10, 0})

        local call_count = 0
        local all_completed = false

        -- Mock vim.defer_fn to execute immediately
        vim.defer_fn = function(fn, delay)
            vim.schedule(fn)
        end

        parley.dispatcher.query = function(buf, provider, payload, handler, completion_callback)
            call_count = call_count + 1
            local mock_qid = "qid_" .. call_count
            parley.tasker.set_query(mock_qid, {
                response = "Response " .. call_count,
                buf = buf
            })

            vim.schedule(function()
                completion_callback(mock_qid)
                if call_count == 2 then
                    all_completed = true
                end
            end)
        end

        parley.chat_respond_all()

        -- Wait for both callbacks to complete
        vim.wait(500, function() return all_completed end, 10)

        -- Should have called dispatcher twice (once for each question)
        assert.equals(2, call_count, "Dispatcher should be called once per exchange")
    end)

    it("reuses remote content fetched in earlier batch steps instead of refetching it later", function()
        local chat_content = [[
# topic: Test
- file: test.md
---

💬: First question @@https://example.com/one.txt@@

🤖: First answer

💬: Second question
]]

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)

        -- Position cursor on second question.
        vim.api.nvim_win_set_cursor(0, {10, 0})

        local fetch_calls = {}
        local call_count = 0
        local all_completed = false

        vim.defer_fn = function(fn, delay)
            vim.schedule(fn)
        end

        google_drive.fetch_content = function(url, config, callback)
            table.insert(fetch_calls, url)
            callback('File: Remote URL - "one.txt"' .. "\n```text\n1: fetched once\n```\n\n", nil)
        end

        parley.dispatcher.query = function(buf, provider, payload, handler, completion_callback)
            call_count = call_count + 1
            local mock_qid = "qid_remote_" .. call_count
            parley.tasker.set_query(mock_qid, {
                response = "Response " .. call_count,
                buf = buf
            })

            vim.schedule(function()
                completion_callback(mock_qid)
                if call_count == 2 then
                    all_completed = true
                end
            end)
        end

        parley.chat_respond_all()
        vim.wait(500, function() return all_completed end, 10)

        assert.equals(2, call_count, "Dispatcher should still run once per exchange")
        assert.same({ "https://example.com/one.txt" }, fetch_calls)
    end)

    it("returns early without calling dispatcher for non-chat file", function()
        local non_chat_file = (os.getenv("TMPDIR") or "/tmp") .. "/claude/not-a-chat-all.md"
        vim.fn.writefile({"# Not a chat"}, non_chat_file)
        vim.cmd("edit " .. non_chat_file)

        local dispatcher_called = false
        parley.dispatcher.query = function(...)
            dispatcher_called = true
        end

        parley.chat_respond_all()

        assert.is_false(dispatcher_called, "Dispatcher should not be called for non-chat file")

        vim.fn.delete(non_chat_file)
    end)
end)

describe("chat_respond: drill-in pre-processing", function()
    local test_file
    local original_query

    local function line_number(buf, text)
        for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line == text then return row end
        end
    end

    local function closed_fold_text(buf, row)
        local last = vim.fn.foldclosedend(row)
        if last < row then return nil end
        return table.concat(vim.api.nvim_buf_get_lines(buf, row - 1, last, false), "\n")
    end

    before_each(function()
        test_file = make_chat_filename()
        original_query = parley.dispatcher.query
        -- Stub dispatcher so chat_respond's network call is a no-op (we only
        -- assert on buffer state, not on the API path).
        parley.dispatcher.query = function() end
    end)

    after_each(function()
        if original_query then
            parley.dispatcher.query = original_query
        end
        if test_file and vim.fn.filereadable(test_file) == 1 then
            vim.fn.delete(test_file)
        end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buftype") == "" then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end)

    it("preserves summary and user folds during end submission without rewriting the chat", function()
        local chat_content = table.concat({
            "# topic: Folded end drill-in", "- file: test.md", "---", "",
            "💬: first question 🤖<term>[explain this]", "", "🤖: [A]", "answer body", "📝: summary", "",
            "💬: follow up", "",
        }, "\n")
        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.wo.foldmethod = "manual"
        vim.wo.foldenable = true
        vim.wo.foldminlines = 0
        vim.wo.foldcolumn = "1"
        vim.wo.number = false
        vim.wo.signcolumn = "no"
        local summary_row = assert(line_number(buf, "📝: summary"))
        local user_start = assert(line_number(buf, "🤖: [A]"))
        vim.cmd(string.format("%d,%dfold", summary_row, summary_row))
        vim.cmd(string.format("%d,%dfold", user_start, user_start + 1))
        vim.cmd("normal! zM")
        vim.cmd("redraw!")
        local screen_row = vim.fn.screenpos(0, summary_row, 1).row
        local marker_before = vim.fn.screenstring(screen_row, 1)
        local summary_before = closed_fold_text(buf, summary_row)
        local user_before = closed_fold_text(buf, user_start)
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })

        local buffer_edit = require("parley.buffer_edit")
        local original_replace_all = buffer_edit.replace_all_lines
        buffer_edit.replace_all_lines = function() error("whole-buffer rewrite") end
        local ok, err = pcall(function() parley.chat_respond({ range = 0 }) end)
        buffer_edit.replace_all_lines = original_replace_all

        assert.is_true(ok, err)
        assert.equals(summary_row, vim.fn.foldclosed(summary_row))
        assert.equals(summary_before, closed_fold_text(buf, summary_row))
        assert.equals(user_before, closed_fold_text(buf, user_start))
        local transformed_question_row = assert(line_number(buf, "💬: first question [term]"))
        assert.equals(-1, vim.fn.foldclosed(transformed_question_row))
        vim.cmd("redraw!")
        local marker_after = vim.fn.screenstring(vim.fn.screenpos(0, summary_row, 1).row, 1)
        assert.is_not.equals("", marker_before)
        assert.equals(marker_before, marker_after)
    end)

    it("normalizes multiple trailing blank lines during end submission", function()
        vim.fn.writefile({
            "# topic: Trailing blank drill-in", "- file: test.md", "---", "",
            "💬: first", "", "🤖: [A]", "answer 🤖<term>[expand]", "",
            "💬: continue", "", "", "",
        }, test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })

        local ok, err = pcall(function() parley.chat_respond({ range = 0 }) end)

        assert.is_true(ok, err)
        local joined = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        assert.truthy(joined:find("answer [term]\n\n💬: continue\n\n> [term]\n\nexpand", 1, true), joined)
        assert.is_nil(joined:find("\n\n\n> %[term%]"), joined)
    end)

    it("gathers a submission marker on the final physical line", function()
        vim.fn.writefile({
            "# topic: Final-line drill-in", "- file: test.md", "---", "",
            "💬: explain 🤖<term>[expand]",
        }, test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })

        local ok, err = pcall(function() parley.chat_respond({ range = 0 }) end)

        assert.is_true(ok, err)
        local joined = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        assert.truthy(joined:find("💬: explain [term]\n\n💬:\n> [term]\n\nexpand", 1, true), joined)
        assert.is_nil(joined:find("🤖<", 1, true), joined)
    end)

    it("shifts a later user fold with its text during branch submission", function()
        local chat_content = table.concat({
            "# topic: Folded branch drill-in", "- file: test.md", "---", "",
            "💬: first", "", "🤖: [A]", "answer 🤖<term>[explain]", "📝: first summary", "",
            "💬: later", "", "🤖: [A]", "later answer one", "later answer two", "",
        }, "\n")
        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.wo.foldmethod = "manual"
        vim.wo.foldenable = true
        vim.wo.foldminlines = 0
        vim.wo.foldcolumn = "1"
        local summary_row = assert(line_number(buf, "📝: first summary"))
        local later_start = assert(line_number(buf, "later answer one"))
        vim.cmd(string.format("%d,%dfold", summary_row, summary_row))
        vim.cmd(string.format("%d,%dfold", later_start, later_start + 1))
        vim.cmd("normal! zM")
        local summary_before = closed_fold_text(buf, summary_row)
        local later_before = closed_fold_text(buf, later_start)
        local count_before = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(0, { 8, 0 })

        local buffer_edit = require("parley.buffer_edit")
        local original_replace_all = buffer_edit.replace_all_lines
        buffer_edit.replace_all_lines = function() error("whole-buffer rewrite") end
        local ok, err = pcall(function() parley.chat_respond({ range = 0 }) end)
        buffer_edit.replace_all_lines = original_replace_all

        assert.is_true(ok, err)
        local delta = vim.api.nvim_buf_line_count(buf) - count_before
        assert.equals(summary_before, closed_fold_text(buf, summary_row))
        assert.equals(later_start + delta, vim.fn.foldclosed(later_start + delta))
        assert.equals(later_before, closed_fold_text(buf, later_start + delta))
        assert.equals(-1, vim.fn.foldclosed(line_number(buf, "💬: first")))
    end)

    it("gathers ready drill-in markers and appends them to the next user turn", function()
        local chat_content = table.concat({
            "# topic: Drill-in test",
            "- file: test.md",
            "---",
            "",
            "💬: tell me about 🤖<RedShift>[what is this?]",
            "",
            "🤖: it's a data warehouse.",
            "",
            "💬: ",
        }, "\n")

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()

        -- Cursor at end of buffer (next-turn slot — not on a past question)
        local last_line = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(0, { last_line, 0 })

        local ok, err = pcall(function() parley.chat_respond({ range = 0 }) end)
        assert.is_true(ok, "chat_respond should not error: " .. tostring(err))

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local joined = table.concat(lines, "\n")

        -- Marker stripped; quoted term remains inline, enclosed in [] so the
        -- reader can see the referenced span (#127 mark_reference_span).
        assert.is_nil(joined:find("🤖<", 1, true), "drill-in marker should be stripped from buffer")
        assert.truthy(joined:find("tell me about [RedShift]", 1, true),
            "stripped term should remain inline, bracketed; got:\n" .. joined)
        -- Quote block appended at the end
        assert.truthy(joined:find("> [RedShift]\n\nwhat is this?", 1, true),
            "quote block should be appended (bracketed + blank line, #141); got:\n" .. joined)
    end)

    it("does not add a quote block when there are no drill-in markers", function()
        local chat_content = table.concat({
            "# topic: No drill-in",
            "- file: test.md",
            "---",
            "",
            "💬: plain question",
        }, "\n")

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        local last_line = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_win_set_cursor(0, { last_line, 0 })

        pcall(function() parley.chat_respond({ range = 0 }) end)
        local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

        -- No drill-in artifacts should appear (no `> ` blockquote lines added).
        assert.is_nil(after:find("\n> ", 1, true),
            "no quote block should be added when there were no drill-ins; got:\n" .. after)
        -- Original question should still be present unchanged.
        assert.truthy(after:find("💬: plain question", 1, true),
            "original question should be preserved; got:\n" .. after)
    end)

    it("gathers a drill-in from the current exchange preface and preserves the following preface", function()
        local lines = { "# topic: Branch prefaces", "- file: test.md", "---", "",
            "@@🤖<Term>[what is this?]@@", "💬: Explain this topic", "", "🤖:",
            "Original answer", "", "@@later topic@@", "💬: Later question" }
        vim.fn.writefile(lines, test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        parley.chat_respond({ range = 0 })
        local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        assert.is_nil(after:find("🤖<Term>", 1, true))
        assert.is_truthy(after:find("@@[Term]@@\n💬: Explain this topic", 1, true))
        assert.is_truthy(after:find("Original answer", 1, true))
        assert.is_truthy(after:find("> [Term]\n\nwhat is this?", 1, true))
        assert.is_truthy(after:find("@@later topic@@\n💬: Later question", 1, true))
    end)

    it("branches a new turn after the cursor exchange when it contains drill-ins", function()
        -- Cursor on a past exchange that has a drill-in marker → don't resubmit;
        -- instead strip the marker and insert a new user turn (with quote+question
        -- block) right after that exchange's answer. Subsequent exchanges below
        -- stay in place but are no longer in the API context for this turn. The
        -- LLM response targets the inserted new turn, NOT the original exchange.
        local chat_content = table.concat({
            "# topic: Branch",
            "- file: test.md",
            "---",
            "",
            "💬: explain 🤖<Term>[what is this?]",
            "",
            "🤖: prior answer about Term.",
            "",
            "💬: a later unrelated question",
        }, "\n")

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()

        -- Capture the messages payload the dispatcher receives so we can prove
        -- the new turn (not the original Q) is the last user message — i.e.,
        -- the API call is for the new turn and end_index didn't leak the stale
        -- later exchange into the context.
        local captured_messages = nil
        parley.dispatcher.query = function(_buf, _provider, payload)
            captured_messages = payload and payload.messages
        end

        -- Cursor on the FIRST exchange's question line (which has a drill-in)
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        pcall(function() parley.chat_respond({ range = 0 }) end)
        local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

        -- Marker stripped; quoted term remains inline, enclosed in [] (#127)
        assert.is_nil(after:find("🤖<Term>", 1, true),
            "drill-in marker should be stripped after branch; got:\n" .. after)
        assert.truthy(after:find("explain [Term]", 1, true),
            "stripped term should remain inline, bracketed; got:\n" .. after)
        -- Original answer preserved (we did NOT resubmit / overwrite it)
        assert.truthy(after:find("prior answer about Term.", 1, true),
            "original answer should be preserved; got:\n" .. after)
        -- A new user turn with the quote+question block was inserted between
        -- the original answer and the later unrelated question.
        local quote_pos = after:find("> [Term]\n\nwhat is this?", 1, true)
        local later_q_pos = after:find("a later unrelated question", 1, true)
        assert.truthy(quote_pos, "quote block should be present; got:\n" .. after)
        assert.truthy(later_q_pos, "later question should be preserved")
        assert.is_true(quote_pos < later_q_pos,
            "quote block must appear before the later unrelated question; got:\n" .. after)

        -- Dispatcher payload: the LAST user message must be the inserted new
        -- turn (containing "what is this?"), proving target_idx and end_index
        -- both point at the new turn rather than the original Q or the stale
        -- later exchange.
        wait_for(function()return captured_messages~=nil end)
        assert.is_not_nil(captured_messages, "dispatcher should have been invoked")
        local last_user_msg = nil
        for i = #captured_messages, 1, -1 do
            if captured_messages[i].role == "user" then
                last_user_msg = captured_messages[i]
                break
            end
        end
        assert.is_not_nil(last_user_msg, "expected a user message in payload")
        local last_content
        if type(last_user_msg.content) == "string" then
            last_content = last_user_msg.content
        else
            last_content = vim.inspect(last_user_msg.content)
        end
        assert.truthy(last_content:find("what is this?", 1, true),
            "last user message should be the new drill-in turn; got: " .. last_content)
        assert.is_nil(last_content:find("a later unrelated question", 1, true),
            "stale later exchange should NOT be part of the API call context")
    end)

    it("does true resubmit when cursor exchange has an answer but no drill-ins", function()
        -- Sanity check that the branch path doesn't break the existing
        -- resubmit path when there's nothing to drill in.
        local chat_content = table.concat({
            "# topic: Plain resubmit",
            "- file: test.md",
            "---",
            "",
            "💬: plain question",
            "",
            "🤖: prior answer.",
        }, "\n")

        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        local before = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
        pcall(function() parley.chat_respond({ range = 0 }) end)
        local after = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

        -- No drill-in artifacts inserted
        assert.is_nil(after:find("\n> ", 1, true),
            "no quote block should appear when cursor exchange has no drill-ins; got:\n" .. after)
        -- Original question preserved
        assert.truthy(after:find("💬: plain question", 1, true))
    end)
end)
