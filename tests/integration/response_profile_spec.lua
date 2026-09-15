local S=require('parley.response_session')
local D=require('parley.document')
local L=require('parley.response_layout')
local P=require('parley.response_preparation')
local Tasker=require('parley.tasker')
local Dispatcher=require('parley.dispatcher')
local Vault=require('parley.vault')
local Pending=require('parley.chat_pending')
local function pump(session)for _=1,300 do S.step(session)end end
local function finish(p)
    for index,arg in ipairs(p.args)do if arg=='--write-out'then
        p:emit('stderr',p.args[index+1]:match('%%{stderr}(.-)%%{http_code}')..'200\n');break
    end end
    p:finish();vim.wait(100,function()return #Tasker._handles==0 end,1)
end
local function declare(p,id)
    p:emit('stdout','data: '..vim.json.encode({choices={{delta={tool_calls={{index=0,id=id,type='function',
        ['function']={name='read_file',arguments='{"path":"file"}'}}}}}}})..'\n\n')
    finish(p)
end
describe('prepared response profile',function()
    local buf,doc,session,processes,old_runtime,old_secret,old_vault,started
    before_each(function()
        started={};session=nil
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: old','text','','💬: next','draft'})
        doc=D.attach(buf,{schedule=false})
        old_runtime,old_secret,old_vault=Tasker._uv,Vault.get_secret,Vault.run_with_secret
        local runtime;runtime,processes=require('tests.helpers.fake_process').new();Tasker._uv=runtime
        Vault.get_secret=function()return 'fixture-secret'end;Vault.run_with_secret=function(_,fn)fn()end
        Dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        Dispatcher.query_dir=vim.fn.tempname()..'-queries';vim.fn.mkdir(Dispatcher.query_dir,'p')
    end)
    after_each(function()
        if session then S.cancel(session);pump(session)end
        for _,events in ipairs(started)do events.outcome('cancelled_before_effect',{});events.resolved()end
        for _,p in pairs(processes.processes)do finish(p)end
        if session then pump(session)end
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
        Tasker._uv,Vault.get_secret,Vault.run_with_secret=old_runtime,old_secret,old_vault
    end)
    local function start(profile)
        local plan=P.plan(L.prepare({lines={'🤖: old','text'},first_row=1,first_byte=#'💬: q'+1,
            header_lines={'🤖: selected'}},{chat_branch_prefix='🌿:',chat_local_prefix='🔒:'}))
        local input={buf=buf,provider='openai',model='fixture',messages={},payload={model='fixture',messages={}},response_profile=profile}
        local producer={start=function(_,_,events)started[#started+1]=events;return events end,
            cancel=function(_,resolved)resolved()end}
        session=assert(S.start(doc,{operation='profile',question={first={row=0,col=0},last={row=0,col=#'💬: q'}},
            output={first={row=0,col=#'💬: q'},last={row=2,col=4}},input={},preparation=plan,schedule=false},
            {buf=buf,agent='Placeholder',max_iterations=9,max_result_bytes=1000,producer=producer,
                prepare_input=function(_,cb)cb.prepared(input);cb.resolved();return {}end,
                build_input=function(previous,messages)
                    previous.messages=messages;previous.payload.messages=messages
                    previous.response_profile={agent='Later',max_iterations=9,max_result_bytes=1000}
                    return previous
                end}))
        pump(session)
        return input
    end
    it('freezes selected limits before the first round and keeps them on continuation',function()
        local original=start({agent='Selected',max_iterations=1,max_result_bytes=8})
        local first=processes.processes[4242];assert.is_not_nil(first)
        original.response_profile.max_iterations=9;original.response_profile.max_result_bytes=1000
        declare(first,'first');pump(session);assert.equals(1,#started)
        started[1].outcome('known',{content='1234567890abcdefghij'});started[1].resolved();pump(session)
        assert.equals(2,processes.spawn_calls)
        local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
        assert.truthy(text:find('12345678\n... [truncated:',1,true))
        assert.is_nil(text:find('1234567890',1,true))
        declare(processes.processes[4243],'second');pump(session)
        assert.equals(1,#started,'continuation must not raise the captured round limit')
        assert.equals('provider_failed',S.snapshot(session).generation.outcome)
    end)
    it('updates pending identity to the selected display name',function()
        start({agent='Selected',max_iterations=1,max_result_bytes=8})
        assert.equals('Selected',Pending.identity(buf).agent)
    end)
    for _,profile in ipairs({{max_iterations=0},{max_iterations=1.5},{max_iterations=false},{max_result_bytes=false},{max_result_bytes=524289},{agent=''}})do
        it('rejects invalid profile '..vim.inspect(profile)..' before replacing source',function()
            local before=vim.api.nvim_buf_get_lines(buf,0,-1,false)
            start(profile)
            assert.equals('terminal',S.snapshot(session).status)
            assert.equals(0,processes.spawn_calls)
            assert.same(before,vim.api.nvim_buf_get_lines(buf,0,-1,false))
        end)
    end
end)
