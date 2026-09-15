local parley=require('parley')
local Respond=require('parley.chat_respond')
local Tasker=require('parley.tasker')
local Producer=require('parley.tools.producer')
local Registry=require('parley.tools')
local Vault=require('parley.vault')
local FakeProcess=require('tests.helpers.fake_process')
local function wait(fn)assert.is_true(vim.wait(5000,fn,1),'public async response did not advance')end
local function buffer_text(buf)return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')end
local function is_provider(process)
    for _,arg in ipairs(process.args)do if arg=='--write-out'then return true end end
    return false
end
local function http_ok(process)
    for i,arg in ipairs(process.args)do if arg=='--write-out'then
        local sentinel=process.args[i+1]:match('%%{stderr}(.-)%%{http_code}')
        process:emit('stderr',sentinel..'200\n');return
    end end
    error('provider status marker missing')
end
local function response(process,delta,finish)
    process:emit('stdout','data: '..vim.json.encode({choices={{delta=delta,finish_reason=finish}}})..'\n\n')
    process:emit('stdout','data: [DONE]\n\n');http_ok(process);process:finish()
end
local function tool_round(process,calls)
    local wire={};for i,call in ipairs(calls)do wire[#wire+1]={index=i-1,id=call.id,type='function',
        ['function']={name=call.name,arguments=vim.json.encode(call.input)}}end
    response(process,{tool_calls=wire},'tool_calls')
end

describe('public asynchronous chat tools',function()
    local root,buf,processes,old_secret,old_run,held,sessions,old_tasker_run
    before_each(function()
        root=vim.fn.tempname()..'-chat-async';vim.fn.mkdir(root..'/one','p');vim.fn.mkdir(root..'/two','p')
        root=(vim.uv or vim.loop).fs_realpath(root)
        parley.setup({chat_dir=root,state_dir=root..'/state',providers={openai={endpoint='http://127.0.0.1:9/fixture'}},api_keys={},
            default_agent='AsyncFixture',agents={{name='Choose a model',disable=true},
                {name='AsyncFixture',provider='openai',model={model='fixture'},system_prompt='Fixture',tools={'ls','find','read_file'}}}})
        old_secret,old_run=Vault.get_secret,Vault.run_with_secret
        Vault.get_secret=function()return 'fixture-secret'end;Vault.run_with_secret=function(_,fn)fn()end
        parley.dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        parley.dispatcher.query_dir=root..'/queries';vim.fn.mkdir(parley.dispatcher.query_dir,'p')
        Tasker._reset();Tasker._uv,processes=FakeProcess.new();held={};sessions={};old_tasker_run=Tasker.run
        buf=vim.api.nvim_create_buf(true,false);vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_name(buf,root..'/2026-09-15.12-00-00.001_fixture.md')
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Fixture','- file: fixture.md','---','',
            '💬: first','🤖: old','old one','','💬: second','🤖: old','old two','',
            '💬: third','🤖: old','old three','','💬: next','draft'})
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _,process in pairs(processes.processes)do process:finish()end
        wait(function()
            for _,session in ipairs(sessions)do local status=Respond.response_snapshot(session).status
                if status~='terminal' and status~='cancelled'then return false end
            end
            return true
        end)
        for _,item in ipairs(held)do item.done({certainty='known',effect='not_applied',physical_resolved=true,
            result={content='fixture cleanup',is_error=true},evidence={checked=true}})end
        for _,process in pairs(processes.processes)do process:finish()end
        wait(function()return Producer.stats().records==0 and Tasker.stats().active==0 end)
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        Vault.get_secret,Vault.run_with_secret=old_secret,old_run;Tasker.run=old_tasker_run;Tasker._uv=nil;Tasker._reset()
        vim.fn.delete(root,'rf')
    end)
    local function cursor(question)
        for i,line in ipairs(vim.api.nvim_buf_get_lines(buf,0,-1,false))do if line=='💬: '..question then
            vim.api.nvim_win_set_cursor(0,{i,0});return
        end end
        error('question missing: '..question)
    end
    local function submit(question)
        cursor(question)
        local session=assert(Respond.respond({range=0,root_policy={write_root=root,read_roots={root}}}))
        sessions[#sessions+1]=session;return session
    end
    local function providers()
        local out={};for _,p in pairs(processes.processes)do if is_provider(p)then out[#out+1]=p end end
        table.sort(out,function(a,b)return a.pid<b.pid end);return out
    end
    local function tools()
        local out={};for _,p in pairs(processes.processes)do if not is_provider(p)then out[#out+1]=p end end
        table.sort(out,function(a,b)return a.pid<b.pid end);return out
    end
    local function finish(session,index)
        wait(function()return #providers()>=index end)
        response(providers()[index],{content='Final response'},'stop')
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(session).generation.outcome)
    end
    local function register_held()
        Registry.register({name='held_fixture',description='stateful asynchronous fixture',kind='write',needs_backup=false,
            input_schema={type='object',properties={file_path={type='string'}},required={'file_path'}},
            resources=function(input)return {{path=input.file_path,scope='file',mode='write'}}end,
            execute_async=function(input,context,done)
                local item={path=input.file_path,context=context,done=done,cancelled=false};held[#held+1]=item
                return {cancel=function()item.cancelled=true end,reconcile=function()end}
            end})
        parley.agents.AsyncFixture.tools={'held_fixture'}
    end
    local function known(item,content)
        item.done({certainty='known',effect='applied',physical_resolved=true,result={content=content},evidence={checked=true}})
    end
    it('overlaps disjoint builtin processes and renders out-of-order completion in declaration order',function()
        local session=submit('first');wait(function()return #providers()==1 or Respond.response_snapshot(session).status=='terminal' end)
        assert.equals(1,#providers(),vim.inspect(Respond.response_snapshot(session)))
        tool_round(providers()[1],{{id='one',name='ls',input={path=root..'/one'}},
            {id='two',name='ls',input={path=root..'/two'}}})
        wait(function()return #tools()==2 end)
        local count=vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_text(buf,count-1,5,count-1,5,{' edited while tools run'})
        tools()[2]:emit('stdout','SECOND_TOOL_RESULT\n');tools()[2]:finish()
        vim.wait(30,function()return false end,1);assert.equals(1,#providers())
        tools()[1]:emit('stdout','FIRST_TOOL_RESULT\n');tools()[1]:finish()
        finish(session,2)
        local content=buffer_text(buf)
        assert.is_true(content:find('FIRST_TOOL_RESULT',1,true)<content:find('SECOND_TOOL_RESULT',1,true))
        assert.is_not_nil(content:find('draft edited while tools run',1,true))
    end)
    it('freezes the allowed async function and agent tools before provider completion',function()
        local session=submit('first');wait(function()return #providers()==1 or Respond.response_snapshot(session).status=='terminal' end)
        assert.equals(1,#providers(),vim.inspect(Respond.response_snapshot(session)))
        local original=Registry.get('ls');local changed=vim.deepcopy(original);local replaced=0
        changed.execute_async=function()replaced=replaced+1;error('replacement must not run')end
        Registry.register(changed);parley.agents.AsyncFixture.tools={}
        tool_round(providers()[1],{{id='frozen',name='ls',input={path=root..'/one'}}})
        wait(function()return #tools()==1 end);assert.equals(0,replaced)
        tools()[1]:emit('stdout','CAPTURED_FUNCTION\n');tools()[1]:finish();finish(session,2)
        assert.is_not_nil(buffer_text(buf):find('CAPTURED_FUNCTION',1,true))
    end)
    it('refuses undeclared and synchronous-only tools without calling their handlers',function()
        local executed=0
        Registry.register({name='sync_fixture',description='legacy synchronous fixture',input_schema={type='object'},
            handler=function()executed=executed+1;return {content='must not execute'}end})
        parley.agents.AsyncFixture.tools={'ls','sync_fixture'}
        local rejected=submit('first')
        wait(function()return Respond.response_snapshot(rejected).status=='terminal'end)
        assert.equals('prepare_failed',Respond.response_snapshot(rejected).generation.outcome)
        assert.equals(0,#providers());assert.equals(0,executed)
        parley.agents.AsyncFixture.tools={'ls'}
        local session=submit('first');wait(function()return #providers()==1 end)
        tool_round(providers()[1],{{id='unadvertised',name='not_advertised',input={}}})
        finish(session,2)
        assert.equals(0,executed);assert.equals(0,#tools())
        assert.is_nil(buffer_text(buf):find('must not execute',1,true))
    end)
    it('scopes Stop to one generation and retains unknown conflicts while disjoint work proceeds',function()
        register_held()
        local first=submit('first');wait(function()return #providers()==1 end)
        tool_round(providers()[1],{{id='a',name='held_fixture',input={file_path=root..'/one/a'}}})
        wait(function()return #held==1 end)
        held[1].done({certainty='unknown',effect='unknown',physical_resolved=false,result={content='uncertain'}})
        local second=submit('second');wait(function()return #providers()==2 end)
        tool_round(providers()[2],{{id='b',name='held_fixture',input={file_path=root..'/two/b'}}})
        wait(function()return #held==2 end)
        cursor('first');Respond.cmd_stop()
        wait(function()return Respond.response_snapshot(first).status=='terminal'end)
        assert.is_true(held[1].cancelled);assert.is_false(held[2].cancelled)
        assert.is_true(Producer.stats().records>=2)
        known(held[2],'SIBLING_RESULT');finish(second,3)
        local conflicting=submit('third');wait(function()return #providers()==4 end)
        tool_round(providers()[4],{{id='conflict',name='held_fixture',input={file_path=root..'/one/a'}}})
        vim.wait(30,function()return false end,1);assert.equals(2,#held)
        local disjoint=submit('next');wait(function()return #providers()==5 end)
        tool_round(providers()[5],{{id='disjoint',name='held_fixture',input={file_path=root..'/two/c'}}})
        wait(function()return #held==3 end)
        assert.equals(root..'/two/c',held[3].path)
        known(held[3],'DISJOINT_RESULT');finish(disjoint,6)
        assert.equals('running',Respond.response_snapshot(conflicting).status)
        known(held[1],'LATE_FIRST_RESULT')
        wait(function()return #held==4 end);assert.equals(root..'/one/a',held[4].path)
        known(held[4],'CONFLICT_RESOLVED');finish(conflicting,7)
        assert.is_nil(buffer_text(buf):find('LATE_FIRST_RESULT',1,true))
    end)
    it('hands reloaded parents to supervision and ignores later backend document callbacks',function()
        register_held();vim.cmd('silent write')
        local session=submit('first');wait(function()return #providers()==1 end)
        tool_round(providers()[1],{{id='reload',name='held_fixture',input={file_path=root..'/one/a'}}})
        wait(function()return #held==1 end)
        vim.cmd('silent edit!')
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.is_true(held[1].cancelled);assert.equals(1,Producer.stats().records)
        local before=buffer_text(buf);known(held[1],'LATE_RELOAD_RESULT')
        wait(function()return Producer.stats().records==0 end)
        assert.equals(before,buffer_text(buf));assert.equals(1,#providers())
    end)

    it('keeps native editor callbacks responsive through actual filesystem and process builtins',function()
        vim.fn.writefile({'NATIVE_FILE_BYTES'},root..'/one/input.txt')
        local native_spawns,heartbeat=0,false
        Tasker.run=function(...)
            local args={...};local options=args[8]
            if options and options.kind=='tool'then
                native_spawns=native_spawns+1
                local previous=Tasker._uv;Tasker._uv=nil
                local result={pcall(old_tasker_run,unpack(args))};Tasker._uv=previous
                assert.is_true(result[1]);vim.schedule(function()heartbeat=true end)
                return unpack(result,2)
            end
            return old_tasker_run(...)
        end
        local session=submit('first');wait(function()return #providers()==1 end)
        tool_round(providers()[1],{{id='read',name='read_file',input={file_path=root..'/one/input.txt'}},
            {id='list',name='ls',input={path=root..'/one'}}})
        wait(function()return heartbeat end);assert.equals(1,native_spawns)
        finish(session,2)
        local content=buffer_text(buf)
        assert.is_not_nil(content:find('NATIVE_FILE_BYTES',1,true));assert.is_not_nil(content:find('input.txt',1,true))
    end)

    it('keeps physical ownership when operator reconciliation supplies only effect evidence',function()
        register_held()
        local session=submit('first');wait(function()return #providers()==1 end)
        tool_round(providers()[1],{{id='reconcile',name='held_fixture',input={file_path=root..'/one/a'}}})
        wait(function()return #held==1 end)
        held[1].done({certainty='unknown',effect='unknown',physical_resolved=false,result={content='unknown'}})
        cursor('first');Respond.cmd_stop()
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        local entries=Producer.list();assert.equals(1,#entries)
        assert.is_true(Producer.reconcile(entries[1].id,{certainty='known',effect='partial',physical_resolved=true,
            result={content='operator inspected'},evidence={operator_checked=true}}))
        entries=Producer.list();assert.equals(1,#entries)
        assert.equals('known',entries[1].certainty);assert.is_false(entries[1].physical_resolved)
        known(held[1],'physical completion')
        wait(function()return Producer.stats().records==0 end)
    end)

end)
