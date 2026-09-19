-- Native response presentation across real dispatcher/tasker lifecycle events.
-- The stateful process seam drives pipes and exit separately; no network is used.
local parley=require('parley')
local Respond=require('parley.chat_respond')
local Process=require('tests.helpers.fake_process')
local Pending=require('parley.chat_pending')
local root=vim.fn.tempname()..'-progress-process';vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',web_search=false,default_agent='ProcessFixture',
    providers={openai={endpoint='http://127.0.0.1:9/fixture'}},api_keys={openai='fixture-secret'},
    agents={{name='Choose a model',disable=true},{name='ProcessFixture',provider='openai',
        model={model='fixture-model'},system_prompt='Answer briefly.',tools={}}}})
local function text(buf)
    return vim.api.nvim_buf_is_valid(buf) and table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n') or ''
end
local function marks(buf)
    local ns=vim.api.nvim_get_namespaces().parley_chat_pending
    return ns and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_extmarks(buf,ns,0,-1,{details=true}) or {}
end
local function wait(predicate)assert.is_true(vim.wait(3000,predicate,1),'response lifecycle did not settle')end
local function status(p,code)
    for i,arg in ipairs(p.args)do if arg=='--write-out'then
        p:emit('stderr',p.args[i+1]:match('%%{stderr}(.-)%%{http_code}')..tostring(code or 200)..'\n');return
    end end
end
local function output(p,bytes)
    p:emit('stdout','data: '..vim.json.encode({choices={{delta={content=bytes}}}})..'\n\n')
end

describe('chat progress managed process lifecycle',function()
    local buf,session,processes,old_runtime,old_notify,old_start,old_secret,old_run,old_vault_run,notices,activity_count
    before_each(function()
        old_runtime,old_notify=parley.tasker._uv,vim.notify
        old_start,old_secret,old_run,old_vault_run=Pending.start,parley.vault.get_secret,parley.tasker.run,parley.vault.run_with_secret
        local runtime;runtime,processes=Process.new();parley.tasker._uv=runtime
        parley.vault.get_secret=function()return 'fixture-secret'end
        parley.vault.run_with_secret=function(_,fn)fn()end
        activity_count=0;notices={}
        Pending.start=function(opts)
            local presentation=old_start(opts);local activity=presentation.activity
            presentation.activity=function(self,...)activity_count=activity_count+1;return activity(self,...)end
            return presentation
        end
        vim.notify=function(message,level)
            notices[#notices+1]={message=tostring(message),level=level,buffer_text=buf and text(buf) or '',
                pending_count=buf and #marks(buf) or 0}
        end
        local path=root..'/2026-09-15-process-'..math.random(100000)..'.md'
        vim.fn.writefile({'# topic: Fixture','- file: fixture.md','---','','💬: test process',
            '🤖: old','old answer','','💬: next','draft'},path)
        vim.cmd('edit '..vim.fn.fnameescape(path));buf=vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0,{5,0})
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _,p in pairs(processes.processes)do status(p);p:finish()end
        wait(function()return #parley.tasker._handles==0 end)
        if session then wait(function()local value=Respond.response_snapshot(session);return value.status=='terminal' or value.status=='cancelled'end)end
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        session=nil;parley.tasker._uv=old_runtime;vim.notify=old_notify
        Pending.start,parley.vault.get_secret,parley.tasker.run,parley.vault.run_with_secret=old_start,old_secret,old_run,old_vault_run
    end)
    local function start()
        session=assert(Respond.respond({range=0}))
        wait(function()return processes.spawn_calls==1 end)
        return processes.processes[4242]
    end
    it('shows pending decoration then writes admitted text without a minimum-visible delay',function()
        local p=start()
        wait(function()return #marks(buf)==1 end)
        assert.is_nil(text(buf):find('partial answer',1,true))
        output(p,'partial answer')
        wait(function()return text(buf):find('partial answer',1,true)~=nil end)
        assert.equals(0,#marks(buf),'committed text immediately releases pending decoration')
        p:emit('stdout','data: [DONE]\n\n')
        status(p);p:exit()
        assert.is_not_equal('terminal',Respond.response_snapshot(session).status,'exit without pipe EOF is unresolved')
        p:emit('stdout',nil);p:emit('stderr',nil)
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        assert.equals('success',Respond.response_snapshot(session).generation.outcome)
        assert.equals(2,activity_count)
    end)
    for _,case in ipairs({{name='broken',http=200,exit=18,expected='exit'},
        {name='unauthorized',http=401,exit=22,expected='HTTP 401'},
        {name='http500',http=500,exit=22,expected='HTTP 500'}})do
        it('commits admitted partial output before the '..case.name..' failure notification',function()
            local p=start()
            if case.name~='unauthorized'then output(p,'partial answer')end
            status(p,case.http);p:finish(case.exit)
            wait(function()return Respond.response_snapshot(session).status=='terminal'end)
            assert.equals('provider_failed',Respond.response_snapshot(session).generation.outcome)
            local notice
            for _,candidate in ipairs(notices)do if candidate.message:find('provider request failed',1,true)then notice=candidate;break end end
            assert.is_not_nil(notice,vim.inspect(notices))
            assert.truthy(notice.message:find(case.expected,1,true),notice.message)
            assert.equals(0,notice.pending_count)
            if case.name~='unauthorized'then
                assert.truthy(notice.buffer_text:find('partial answer',1,true),'notification precedes admitted buffer output')
            end
            assert.is_nil(text(buf):find('__PARLEY_HTTP_',1,true));assert.equals(0,#marks(buf))
        end)
    end
    local function prestart(message)
        session=assert(Respond.respond({range=0}))
        wait(function()return Respond.response_snapshot(session).status=='terminal'end)
        local count=0
        for _,notice in ipairs(notices)do if notice.level>=vim.log.levels.WARN and notice.message:find(message,1,true)then count=count+1 end end
        assert.equals(1,count,vim.inspect(notices));assert.equals(0,#marks(buf))
        assert.is_not_equal('success',Respond.response_snapshot(session).generation.outcome)
    end
    it('cleans the admitted session when its provider secret is missing',function()
        parley.vault.get_secret=function()return nil end
        prestart('bearer token is missing');assert.equals(0,processes.spawn_calls)
    end)
    it('cleans the admitted session when its exact transport admission key is occupied',function()
        parley.tasker.run=function(b,command,args,callback,stdout,stderr,reject,opts)
            parley.tasker.run=old_run
            old_run(b,'fixture-blocker',{},nil,nil,nil,nil,{admission_key=opts.admission_key,generation_id='existing-owner'})
            return old_run(b,command,args,callback,stdout,stderr,reject,opts)
        end
        -- The user meets the words for `owner is busy`, not the token (#261 M5).
        prestart('this request is still running');assert.equals(1,processes.spawn_calls)
    end)
    it('cleans the admitted session when process spawn is rejected',function()
        local runtime;runtime,processes=Process.new({spawn_error='fixture spawn rejection'});parley.tasker._uv=runtime
        prestart('fixture spawn rejection')
    end)
end)
