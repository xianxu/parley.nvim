local parley=require('parley')
local Respond=require('parley.chat_respond')
local Ready=require('parley.llm_readiness')
local root=vim.fn.tempname()..'-onboarding-capture';vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},default_agent='Choose a model',
 agents={{name='Choose a model',placeholder=true,provider='cliproxyapi',model={model='choose-a-model'},system_prompt='Placeholder',tools={}},
 {name='SelectedFixture',provider='openai',model={model='selected-model'},system_prompt='Selected prompt',tools={},max_tool_iterations=1,tool_result_max_bytes=8},
 {name='OtherFixture',provider='openai',model={model='other-model'},system_prompt='Other prompt',tools={}}}})
local function wait(predicate)assert.is_true(vim.wait(3000,predicate,1),'onboarding response did not settle')end
local function text(buf)return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')end
describe('captured response onboarding',function()
    local buf,other,session,ready,calls,old_defer,old_query,old_stop
    before_each(function()
        calls={};ready=nil;session=nil
        old_defer,old_query,old_stop=Ready.defer,parley.dispatcher.query,parley.tasker.stop_owner
        parley._state.agent='Choose a model'
        parley.agents.SelectedFixture.tools={}
        Ready.defer=function(_,action)ready=action;return true end
        parley.dispatcher.query=function(b,provider,payload,output,complete,_,_,abort,_,_,opts)
            local id='onboarding:'..(#calls+1)
            calls[#calls+1]={buf=b,id=id,provider=provider,payload=vim.deepcopy(payload),output=output,complete=complete,abort=abort,opts=opts}
            parley.tasker.set_query(id,{buf=b,response='',raw_response='',tool_wire='openai'})
        end
        parley.tasker.stop_owner=function(owner)
            for _,call in ipairs(calls)do if call.opts.generation_id==owner then call.abort('cancelled')end end
        end
        buf=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_name(buf,root..string.format('/2026-09-15.12-%02d-%02d.%03d_fixture.md',
            math.floor(buf/60000)%60,math.floor(buf/1000)%60,buf%1000))
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Fixture','- file: fixture.md','---','','💬: first',
            '🤖: old','old answer','','💬: next','draft'})
        vim.api.nvim_win_set_cursor(0,{5,0})
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        if ready then ready()end
        for _,call in ipairs(calls)do call.abort('cleanup')end
        if session then wait(function()local value=Respond.response_snapshot(session);return value.status=='terminal' or value.status=='cancelled'end)end
        Ready.defer,parley.dispatcher.query,parley.tasker.stop_owner=old_defer,old_query,old_stop
        for _,b in ipairs({buf,other})do if b and vim.api.nvim_buf_is_valid(b)then vim.api.nvim_buf_delete(b,{force=true})end end
        other=nil
    end)
    it('uses the explicitly selected model and shell while preserving the captured question across focus and draft edits',function()
        session=assert(Respond.respond({range=0}));wait(function()return ready~=nil end)
        vim.api.nvim_buf_set_text(buf,9,5,9,5,{' edited'})
        other=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(other)
        vim.api.nvim_buf_set_lines(other,0,-1,false,{'other buffer'})
        parley._state.agent='SelectedFixture';ready();wait(function()return #calls==1 end)
        assert.equals('openai',calls[1].provider);assert.equals('selected-model',calls[1].payload.model)
        assert.truthy(text(buf):find('🤖:[SelectedFixture]',1,true));assert.truthy(text(buf):find('draft edited',1,true))
        assert.equals(other,vim.api.nvim_get_current_buf())
        calls[1].output(calls[1].id,'selected answer');calls[1].complete(calls[1].id)
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(session).generation.outcome)
    end)
    it('never recaptures a deleted origin when onboarding finishes',function()
        session=assert(Respond.respond({range=0}));wait(function()return ready~=nil end)
        vim.api.nvim_buf_set_lines(buf,4,7,false,{})
        parley._state.agent='SelectedFixture';ready()
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals(0,#calls);assert.truthy(text(buf):find('💬: next',1,true))
    end)
    it('keeps a configured request frozen when ordinary selection changes during readiness',function()
        parley._state.agent='SelectedFixture'
        session=assert(Respond.respond({range=0}));wait(function()return ready~=nil end)
        parley._state.agent='OtherFixture';ready();wait(function()return #calls==1 end)
        assert.equals('selected-model',calls[1].payload.model)
        assert.truthy(text(buf):find('🤖:[SelectedFixture]',1,true))
    end)
    it('enforces the selected agent tool limits through a public continuation',function()
        local executed=0
        require('parley.tools').register({name='profile_read',description='Fixture',
            input_schema={type='object',properties={}},resources=function()return {}end,
            execute_async=function(_,_,done)
                executed=executed+1
                done({certainty='known',effect='not_applied',physical_resolved=true,
                    result={content='1234567890abcdefghij',is_error=false}})
                return {cancel=function()end}
            end})
        parley.agents.SelectedFixture.tools={'profile_read'}
        session=assert(Respond.respond({range=0}));wait(function()return ready~=nil end)
        parley._state.agent='SelectedFixture';ready();wait(function()return #calls==1 end)
        assert.equals('SelectedFixture',require('parley.chat_pending').identity(buf).agent)
        local function round(call,id)
            local query=parley.tasker.get_query(call.id)
            query.raw_response='data: '..vim.json.encode({choices={{delta={tool_calls={{index=0,id=id,type='function',
                ['function']={name='profile_read',arguments='{}'}}}}}}})..'\n\n'
            call.complete(call.id)
        end
        round(calls[1],'first');wait(function()return #calls==2 end)
        local result
        for _,message in ipairs(calls[2].payload.messages)do
            if message.role=='tool' and message.tool_call_id=='first' then result=message.content end
        end
        assert.equals(1,executed)
        -- The eight-byte body cap cannot hold a meaningful omission notice.
        -- Fixed metadata remains visible; no source bytes escape this tiny cap.
        assert.equals('[Tool result incomplete]\n',result)
        round(calls[2],'second');wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals(1,executed)
        assert.equals('provider_failed',Respond.response_snapshot(session).generation.outcome)
    end)
    for _,field in ipairs({'regions','source_bytes','first_offset'})do
        it('rejects a preparation override changing '..field..' before mutating source',function()
            local D=require('parley.document');local S=require('parley.response_session')
            local P=require('parley.response_preparation');local L=require('parley.response_layout')
            local plan=P.plan(L.prepare({lines={'🤖: old','old answer'},first_row=5,
                first_byte=vim.api.nvim_buf_get_offset(buf,5),header_lines={'🤖: selected'}},
                {chat_branch_prefix='🌿:',chat_local_prefix='🔒:'}))
            local changed=vim.deepcopy(plan)
            if field=='regions'then changed.regions[1].last_offset=changed.regions[1].last_offset+1
            else changed.gaps[1][field]=changed.gaps[1][field]+1 end
            local before=text(buf)
            local doc=D.get(buf) or D.attach(buf,{schedule=false})
            local value={operation='override',question={first={row=4,col=0},last={row=4,col=#'💬: first'}},
                output={first={row=4,col=#'💬: first'},last={row=6,col=#'old answer'}},input={},preparation=plan,schedule=false}
            local owned=assert(S.start(doc,value,{buf=buf,pending=false,build_input=function(previous)return previous end,
                prepare_input=function(_,cb)
                    assert.is_false(cb.prepared({provider='openai',payload={model='fixture'}},changed))
                    cb.resolved();return {}
                end}))
            for _=1,1000 do S.step(owned)end
            assert.equals('terminal',S.snapshot(owned).status)
            assert.equals(before,text(buf));assert.equals(0,#calls)
        end)
    end

end)

describe('utility topic transport cleanup',function()
    local buf,processes,old_runtime,old_secret,old_vault,old_notify
    before_each(function()
        local runtime;runtime,processes=require('tests.helpers.fake_process').new()
        old_runtime,old_secret,old_vault,old_notify=parley.tasker._uv,parley.vault.get_secret,parley.vault.run_with_secret,vim.notify
        parley.tasker._uv=runtime
        parley.vault.get_secret=function()return 'fixture-secret'end
        parley.vault.run_with_secret=function(_,fn)fn()end
        parley.dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        vim.notify=function()end
        buf=vim.api.nvim_create_buf(false,true);vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: ?'})
    end)
    after_each(function()
        for _,p in pairs(processes.processes)do p:finish()end
        wait(function()return #parley.tasker._handles==0 end)
        vim.api.nvim_buf_delete(buf,{force=true})
        parley.tasker._uv,parley.vault.get_secret,parley.vault.run_with_secret,vim.notify=old_runtime,old_secret,old_vault,old_notify
    end)
    for _,case in ipairs({{http=500,exit=22},{http=200,exit=18}})do
        it('retires its spinner and callback after started transport failure '..case.exit,function()
            local count,reason,marks_at_callback=0,nil,nil
            Respond.generate_topic({{role='user',content='topic please'}},'openai',{model='fixture'},function(topic,why)
                count=count+1;assert.is_nil(topic);reason=why
                local ns=vim.api.nvim_get_namespaces().parley_topic_pending
                marks_at_callback=#vim.api.nvim_buf_get_extmarks(buf,ns,0,-1,{})
            end,{buf=buf,find_line=function()return 0 end})
            local p=processes.processes[4242];assert.is_not_nil(p)
            p:emit('stdout','data: '..vim.json.encode({choices={{delta={content='partial topic'}}}})..'\n\n')
            for index,arg in ipairs(p.args)do if arg=='--write-out'then
                p:emit('stderr',p.args[index+1]:match('%%{stderr}(.-)%%{http_code}')..case.http..'\n');break
            end end
            p:exit(case.exit);assert.equals(0,count)
            p:emit('stdout',nil);p:emit('stderr',nil)
            wait(function()return #parley.tasker._handles==0 end)
            assert.equals(1,count);assert.is_not_nil(reason);assert.equals(0,marks_at_callback)
            p:finish(case.exit);assert.equals(1,count)
        end)
    end
end)
