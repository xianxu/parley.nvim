-- #290: the stream writer folds what it writes in the same turn it lands — a
-- tool block written whole, and a streamed `📝:` summary row — and #264's
-- reconcile, the authority, then finds nothing to change. Driven through
-- chat_respond with the stateful transport fixture and a real window.
local tmp_dir=(os.getenv('TMPDIR') or '/tmp')..'/claude/parley-test-writer-folds-'..os.time()
local parley=require('parley')
parley.setup({
    chat_dir=tmp_dir,state_dir=tmp_dir..'/state',default_agent='FixtureAnthropic',
    agents={
        {name='Choose a model',disable=true},
        {name='FixtureAnthropic',provider='anthropic',model={model='claude-sonnet-5'},
            system_prompt='You are a helpful assistant.',tools={'@all'}},
    },
    providers={},api_keys={},
})
vim.fn.mkdir(tmp_dir,'p')
local Respond=require('parley.chat_respond')
local F=require('parley.tool_folds')
local Fixture=require('tests.helpers.respond_fixture')
local policy=require('parley.fold_projection')
local parser=require('parley.chat_parser')

local function sse(id,path)
    local events={
        {type='message_start',message={id='msg_test',model='claude-sonnet-5'}},
        {type='content_block_start',index=0,content_block={type='tool_use',id=id,name='read_file',input={}}},
        {type='content_block_delta',index=0,delta={type='input_json_delta',partial_json='{"path":"'..path..'"}'}},
        {type='content_block_stop',index=0},
        {type='message_delta',delta={stop_reason='tool_use'}},
        {type='message_stop'},
    }
    local lines={}
    for _,ev in ipairs(events) do
        lines[#lines+1]='event: '..ev.type;lines[#lines+1]='data: '..vim.json.encode(ev);lines[#lines+1]=''
    end
    return table.concat(lines,'\n')
end
local function wait_for(predicate)assert.is_true(vim.wait(5000,predicate,1),'did not settle')end
local function row_of(buf,prefix)
    for index,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false)) do
        if line:sub(1,#prefix)==prefix then return index end
    end
end

describe('writer folds (#290)',function()
    local buf,calls,restore,events,files
    before_each(function()
        files={}
        calls,restore=Fixture.install(parley)
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,tmp_dir..'/2026-03-01-writer-folds-'..math.random(1000000)..'.md')
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Folds','- file: fixture.md','---','','💬: question',''})
        vim.api.nvim_win_set_cursor(0,{5,0})
        F.setup(buf)
        events={}
        -- A `written` event is emitted inside the write's own turn, before any
        -- scheduled repair step can run: probe the window's folds right there.
        F._observer=function(event)
            if event.phase=='written' then
                event.closed={}
                for i,range in ipairs(event.ranges) do
                    event.closed[i]={vim.fn.foldclosed(range[1]+1)-1,vim.fn.foldclosedend(range[1]+1)-1}
                end
                event.lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
            end
            events[#events+1]=event
        end
    end)
    after_each(function()
        F._observer=nil
        Respond.cancel_responses(buf);restore()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
        for _,path in ipairs(files) do vim.fn.delete(path) end
    end)
    local function submit()
        local session=assert(Respond.respond({range=0}))
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
        wait_for(function()return F.flush(buf)=='idle' end)
    end
    local function written()
        local list={};for _,e in ipairs(events) do if e.phase=='written' then list[#list+1]=e end end
        return list
    end
    local function reconciled(from)
        local removed,created,count=0,0,0
        for i=from or 1,#events do
            local e=events[i]
            if e.phase=='reconcile' then removed=removed+e.removed;created=created+e.created;count=count+1 end
        end
        return removed,created,count
    end
    -- The settled oracle: the parser's foldable sections, row by row.
    local function oracle()
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local expected={}
        for _,exchange in ipairs(parser.parse_chat(lines,0,{}).exchanges) do
            for _,section in ipairs(exchange.answer and exchange.answer.semantic_sections or {}) do
                if policy.is_foldable(section.kind) then
                    for row=section.line_start,section.line_end do expected[row]=true end
                end
            end
        end
        for row=1,#lines do
            assert.equals(expected[row] and 1 or 0,vim.fn.foldlevel(row),'row '..row..' '..lines[row])
        end
    end

    it('folds a tool call and a result over 4 KiB closed as they are written, with no reconcile work',function()
        local path=tmp_dir..'/writer-folds-tool.txt';files[#files+1]=path
        local content={};for i=1,300 do content[i]=('line %03d '):format(i)..string.rep('w',40) end
        vim.fn.writefile(content,path)
        local session=submit();local first=calls[1]
        parley.tasker.get_query(first.id).raw_response=sse('tool-fold',path)
        first.running=false;first.complete(first.id)
        wait_for(function()return #calls==2 end)
        local blocks=written()
        assert.equals(2,#blocks,'one written fold per block')
        for i,marker in ipairs({'🔧:','📎:'}) do
            local range=blocks[i].ranges[1]
            assert.equals(marker,blocks[i].lines[range[1]+1]:sub(1,#marker))
            assert.truthy(blocks[i].lines[range[2]+1]:match('^`+$'),'ends on the closing fence')
            assert.same({range[1],range[2]},blocks[i].closed[1],marker..' closed in its write turn')
        end
        -- The result block landed whole: its closing fence was already there.
        assert.truthy(blocks[2].lines[blocks[2].ranges[1][2]+1]:match('^`+$'))
        assert.equals(303,blocks[2].ranges[1][2]-blocks[2].ranges[1][1]+1,'marker, two fences and 300 body rows')
        output(calls[2],'finished');complete(session,calls[2])
        local removed,created,count=reconciled()
        assert.is_true(count>0,'the reconcile ran')
        assert.equals(0,removed);assert.equals(0,created)
        oracle()
        for _,marker in ipairs({'🔧:','📎:'}) do
            local row=row_of(buf,marker);assert.equals(row,vim.fn.foldclosed(row))
        end
    end)

    it('folds a summary from the write that completes its split prefix and keeps it closed',function()
        local session=submit()
        output(calls[1],'answer\n📝');wait_for(function()return row_of(buf,'📝')~=nil end)
        local row=row_of(buf,'📝')
        assert.equals(0,#written(),'an incomplete prefix is not a summary yet')
        assert.equals(0,vim.fn.foldlevel(row))
        output(calls[1],': the gist');wait_for(function()return #written()==1 end)
        assert.same({{row-1,row-1}},written()[1].ranges)
        assert.same({{row-1,row-1}},written()[1].closed,'closed in the write turn')
        output(calls[1],' and more of it');wait_for(function()return row_of(buf,'📝: the gist and more')~=nil end)
        assert.equals(row,vim.fn.foldclosed(row),'stays closed while the line streams')
        -- The streaming edit deleted the fold; the writer restored it in that turn.
        assert.equals(2,#written())
        local mark=#events+1
        complete(session,calls[1])
        local removed=reconciled(mark)
        assert.equals(0,removed)
        oracle()
        assert.equals(row,vim.fn.foldclosed(row))
    end)

    -- The parser folds only a summary's marker row (the line after it is
    -- ordinary answer text), so the writer's one-row fold is already exact.
    it('folds only the marker row of a summary followed by more text',function()
        local session=submit()
        output(calls[1],'answer\n📝: first\nsecond line after the summary')
        wait_for(function()return #written()==1 end)
        local row=row_of(buf,'📝: first')
        assert.same({{row-1,row-1}},written()[1].closed)
        local mark=#events+1
        complete(session,calls[1])
        local removed,created=reconciled(mark)
        assert.equals(0,removed);assert.equals(0,created)
        oracle()
        assert.equals(row,vim.fn.foldclosed(row))
        assert.equals(row,vim.fn.foldclosedend(row))
    end)

    -- The writer cannot see fences; the settled parse decides. Today the parser
    -- also folds a `📝:` row inside a code fence, so the two agree.
    it('agrees with the parse on a summary marker inside a code fence',function()
        local session=submit()
        output(calls[1],'answer\n```\n📝: quoted\n```\ndone')
        wait_for(function()return #written()==1 end)
        local row=row_of(buf,'📝: quoted')
        assert.same({{row-1,row-1}},written()[1].closed,'folded in the write turn')
        complete(session,calls[1])
        oracle()
    end)
end)
