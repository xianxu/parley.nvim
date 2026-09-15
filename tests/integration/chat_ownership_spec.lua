-- Public response ownership through the real dispatcher and managed process seam.
local parley=require('parley')
local Respond=require('parley.chat_respond')
local Process=require('tests.helpers.fake_process')
local root=vim.fn.tempname()..'-ownership'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},default_agent='OwnershipFixture',
    agents={{name='Choose a model',disable=true},{name='OwnershipFixture',provider='openai',
        model={model='fixture'},system_prompt='Fixture',tools={}}}})
local function text(buf)return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')end
local function settle(predicate)assert.is_true(vim.wait(3000,predicate,1),'scheduled response did not settle')end
local function status(p)
    for i,arg in ipairs(p.args)do if arg=='--write-out'then
        p:emit('stderr',p.args[i+1]:match('%%{stderr}(.-)%%{http_code}')..'200\n');return
    end end
end
local function output(p,bytes)
    p:emit('stdout','data: '..vim.json.encode({choices={{delta={content=bytes}}}})..'\n\n')
end
local function finish(p)status(p);p:finish()end

describe('chat ownership containment',function()
    local old_runtime,old_secret,old_run,buffers,sessions,processes
    local sequence=0
    before_each(function()
        buffers,sessions={},{}
        old_runtime=parley.tasker._uv
        local runtime;runtime,processes=Process.new();parley.tasker._uv=runtime
        old_secret,old_run=parley.vault.get_secret,parley.vault.run_with_secret
        parley.vault.get_secret=function()return 'fixture-secret'end
        parley.vault.run_with_secret=function(_,fn)fn()end
        parley.dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
    end)
    after_each(function()
        for _,buf in ipairs(buffers)do Respond.cancel_responses(buf)end
        for _,p in pairs(processes.processes)do finish(p)end
        settle(function()return #parley.tasker._handles==0 end)
        for _,session in ipairs(sessions)do
            settle(function()local s=Respond.response_snapshot(session);return s.status=='terminal' or s.status=='cancelled'end)
        end
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        parley.tasker._uv=old_runtime
        parley.vault.get_secret,parley.vault.run_with_secret=old_secret,old_run
    end)
    local function start(topic)
        sequence=sequence+1
        local file=root..('/2026-09-14.12-00-%02d.001_fixture.md'):format(sequence)
        vim.fn.writefile({'# topic: '..(topic or 'Ownership fixture'),'- file: fixture.md','---','','💬: First question',''},file)
        vim.cmd('edit '..vim.fn.fnameescape(file))
        local buf=vim.api.nvim_get_current_buf();buffers[#buffers+1]=buf
        vim.api.nvim_win_set_cursor(0,{5,0})
        local before=processes.spawn_calls
        local session=assert(Respond.respond({range=0}));sessions[#sessions+1]=session
        settle(function()return processes.spawn_calls==before+1 end)
        local p=processes.processes[4242+before];output(p,'Generated answer')
        settle(function()return text(buf):find('Generated answer',1,true)~=nil end)
        return buf,p,session
    end
    it('preserves a question typed ahead through completion without adding a duplicate prompt',function()
        local buf,p,session=start()
        local tail={'','💬: My next question','still composing'}
        vim.api.nvim_buf_set_lines(buf,-1,-1,false,tail);finish(p)
        settle(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(session).generation.outcome)
        local result=text(buf);assert.truthy(result:find(table.concat(tail,'\n'),1,true),result)
        local _,questions=result:gsub('💬:','');assert.equals(2,questions)
    end)
    it('preserves non-marker human text appended before completion',function()
        local buf,p,session=start()
        vim.api.nvim_buf_set_lines(buf,-1,-1,false,{'','unfinished human text'});finish(p)
        settle(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.truthy(text(buf):find('unfinished human text',1,true))
    end)
    it('cancels a deleted answer owner while another chat continues and waits for physical cleanup',function()
        local first,a,session=start();local second,b,other=start()
        for row,line in ipairs(vim.api.nvim_buf_get_lines(first,0,-1,false))do
            if line:find('🤖:',1,true)then vim.api.nvim_buf_set_lines(first,row-1,row,false,{});break end
        end
        output(a,'late');settle(function()return #processes.signals>0 end)
        assert.equals(a.pid,processes.signals[1].pid)
        assert.equals('stopping',Respond.response_snapshot(session).generation.phase)
        for _,signal in ipairs(processes.signals)do assert.is_not_equal(b.pid,signal.pid)end
        output(b,' survives');settle(function()return text(second):find(' survives',1,true)~=nil end)
        finish(a);finish(b)
        settle(function()return Respond.response_snapshot(session).status=='terminal'
            and Respond.response_snapshot(other).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(other).generation.outcome)
        assert.is_nil(text(first):find('late',1,true))
    end)
    for _,invalidation in ipairs({'answer header','buffer'})do
        it('cancels automatic topic after deleting its '..invalidation..' without a scratch buffer',function()
            local first,answer,session=start('?')
            local existing={};for _,buf in ipairs(vim.api.nvim_list_bufs())do existing[buf]=true end
            finish(answer);settle(function()return processes.spawn_calls==2 end)
            settle(function()return Respond.response_snapshot(session).status=='terminal'end)
            assert.equals('success',Respond.response_snapshot(session).generation.outcome)
            for _,buf in ipairs(vim.api.nvim_list_bufs())do assert.is_true(existing[buf]==true,'topic must not allocate a source buffer')end
            local second,sibling=start()
            if invalidation=='buffer'then vim.api.nvim_buf_delete(first,{force=true})
            else
                for row,line in ipairs(vim.api.nvim_buf_get_lines(first,0,-1,false))do
                    if line:find('🤖:',1,true)then vim.api.nvim_buf_set_lines(first,row-1,row,false,{});break end
                end
            end
            settle(function()return #processes.signals>0 end)
            for _,signal in ipairs(processes.signals)do assert.equals(4243,signal.pid)end
            assert.equals(2,#parley.tasker._handles,'signal is not positive cleanup')
            local topic=processes.processes[4243];output(topic,'late topic');finish(topic)
            settle(function()return #parley.tasker._handles==1 end)
            output(sibling,' survives');settle(function()return text(second):find(' survives',1,true)~=nil end)
            if vim.api.nvim_buf_is_valid(first)then assert.equals('# topic: ?',vim.api.nvim_buf_get_lines(first,0,1,false)[1])end
        end)
    end
end)
