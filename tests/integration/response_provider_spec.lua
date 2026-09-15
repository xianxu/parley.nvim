local Dispatcher=require('parley.dispatcher')
local Tasker=require('parley.tasker')
local Vault=require('parley.vault')
local Providers=require('parley.providers')
local Process=require('tests.helpers.fake_process')
local ok,Provider=pcall(require,'parley.response_provider')
local function status(process,code)
    for i,arg in ipairs(process.args)do if arg=='--write-out'then
        local sentinel=process.args[i+1]:match('%%{stderr}(.-)%%{http_code}')
        process:emit('stderr',sentinel..code..'\n');return
    end end
    error('missing fixture sentinel')
end
local function callbacks()
    local state={bytes='',events={},resolved=0,failed=0,complete=0}
    local cb={output=function(bytes)state.bytes=state.bytes..bytes;state.events[#state.events+1]='output';return true end,
        complete=function()state.complete=state.complete+1;state.events[#state.events+1]='complete';return true end,
        round=function(calls)state.calls=calls;state.events[#state.events+1]='round';return true end,
        failed=function(reason)state.failed=state.failed+1;state.reason=reason;state.events[#state.events+1]='failed';return true end,
        resolved=function()state.resolved=state.resolved+1;state.events[#state.events+1]='resolved';return true end}
    return cb,state
end
local function context(gen)
    return {epoch=1,generation=gen,operation='request:'..gen,cancelled=function()return false end,
        input={provider='openai',model='fixture',payload={model='fixture',messages={}},buf=72}}
end
describe('production response provider adapter',function()
    local runtime,processes,old_secret,old_vault,old_get
    before_each(function()
        Tasker._reset();runtime,processes=Process.new();Tasker._uv=runtime
        old_secret,old_vault,old_get=Vault.get_secret,Vault.run_with_secret,Providers.get
        Vault.get_secret=function()return 'fixture-secret'end
        Vault.run_with_secret=function(_,fn)fn()end
        Dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        Dispatcher.query_dir=vim.fn.tempname()..'-queries';vim.fn.mkdir(Dispatcher.query_dir,'p')
    end)
    after_each(function()
        Providers.get=old_get
        for _,process in pairs(processes.processes)do status(process,'200');process:finish()end
        vim.wait(100,function()return #Tasker._handles==0 end,1)
        Vault.get_secret,Vault.run_with_secret=old_secret,old_vault;Tasker._reset();Tasker._uv=nil
    end)
    it('provides the request/cancel adapter',function()assert.is_true(ok,tostring(Provider))end)
    if not ok then return end
    it('admits output position-free and separates host result, completion and positive cleanup',function()
        local cb,s=callbacks();local adapter=Provider.new({on_result=function(_,qt)
            assert.equals('\nhello',qt.response);s.events[#s.events+1]='result'
        end})
        adapter.request(context(1),cb)
        local p=processes.processes[4242]
        p:emit('stdout','data: {"choices":[{"delta":{"content":"\\nhello"}}]}\n\n')
        assert.equals('hello',s.bytes);assert.equals(0,s.complete);assert.equals(0,s.resolved)
        status(p,'200');p:exit();assert.equals(0,s.resolved)
        p:emit('stdout',nil);assert.equals(0,s.resolved);p:emit('stderr',nil)
        assert.is_true(vim.wait(100,function()return s.resolved==1 end,1))
        assert.same({'output','result','complete','resolved'},s.events)
    end)
    it('cancels only its own same-buffer operation and waits for process plus pipe cleanup',function()
        local adapter=Provider.new();local a,sa=callbacks();local b,sb=callbacks()
        local ca,cb=context(1),context(2);local ha=adapter.request(ca,a);adapter.request(cb,b)
        local resolved=0
        adapter.cancel_operation({epoch=1,generation=1,operation=ca.operation,handle=ha},function()resolved=resolved+1 end)
        assert.equals(1,#processes.signals);assert.equals(4242,processes.signals[1].pid)
        assert.equals(0,resolved);assert.equals(0,sa.resolved)
        processes.processes[4243]:emit('stdout','data: {"choices":[{"delta":{"content":"other"}}]}\n\n')
        assert.equals('other',sb.bytes)
        local p=processes.processes[4242];status(p,'200');p:finish(0,15)
        assert.is_true(vim.wait(100,function()return resolved==1 end,1))
        assert.equals(0,sa.complete);assert.equals(0,sa.resolved)
    end)
    it('prevents delayed pre-query startup after cancellation without claiming early resolution',function()
        local ready
        Providers.get=function(name)local p=vim.tbl_extend('force',{},old_get(name));p.pre_query=function(fn)ready=fn end;return p end
        local adapter=Provider.new();local cb,s=callbacks();local ctx=context(1)
        local handle=adapter.request(ctx,cb);local resolved=0
        adapter.cancel_operation({epoch=1,generation=1,operation=ctx.operation,handle=handle},function()resolved=resolved+1 end)
        assert.equals(0,processes.spawn_calls);assert.equals(0,resolved)
        ready();assert.equals(0,processes.spawn_calls);assert.equals(1,resolved);assert.equals(0,s.resolved)
        ready();assert.equals(1,resolved);assert.equals(0,s.resolved)
    end)
    it('refuses a cancelled recovery retry and waits for its explicit settlement',function()
        local retry
        Providers.get=function(name)
            local p=vim.tbl_extend('force',{},old_get(name))
            p.recover_query=function(_,again)retry=again;return true end
            return p
        end
        local adapter=Provider.new();local cb,s=callbacks();local ctx=context(1)
        local handle=adapter.request(ctx,cb);local p=processes.processes[4242]
        status(p,'503');p:finish(22)
        assert.is_true(vim.wait(100,function()return retry~=nil end,1))
        local resolved=0
        adapter.cancel_operation({epoch=1,generation=1,operation=ctx.operation,handle=handle},function()resolved=resolved+1 end)
        assert.equals(0,resolved);retry()
        assert.equals(1,resolved);assert.equals(1,processes.spawn_calls);assert.equals(0,s.failed)
        retry();assert.equals(1,resolved)
    end)
    it('checks liveness again after provider formatting immediately before spawn',function()
        local cancelled=false
        Providers.get=function(name)
            local p=vim.tbl_extend('force',{},old_get(name));local format=p.format_headers
            p.format_headers=function(...)cancelled=true;return format(...)end
            return p
        end
        local adapter=Provider.new();local cb,s=callbacks();local ctx=context(1)
        ctx.cancelled=function()return cancelled end
        adapter.request(ctx,cb)
        assert.equals(0,processes.spawn_calls);assert.equals(1,s.resolved)
    end)
    it('releases rejected startup exactly once and contains a throwing host result callback',function()
        local adapter=Provider.new();local cb,s=callbacks();Vault.get_secret=function()return nil end
        adapter.request(context(1),cb);assert.equals(1,s.failed);assert.equals(1,s.resolved);assert.equals(0,processes.spawn_calls)
        Vault.get_secret=function()return 'secret'end
        adapter=Provider.new({on_result=function()error('host failed')end});cb,s=callbacks()
        adapter.request(context(2),cb);local p=processes.processes[4242];status(p,'200');p:finish()
        assert.is_true(vim.wait(100,function()return s.resolved==1 end,1))
        assert.equals(1,s.failed);assert.equals(0,s.complete)
    end)
    it('decodes ordered tool calls through the dispatched wire and reports a round without recursive IO',function()
        local cb,s=callbacks();local observed
        local adapter=Provider.new({on_result=function(_,_,calls)
            observed=vim.deepcopy(calls);if calls and calls[1] then calls[1].input.path='host mutation' end
            s.events[#s.events+1]='result'
        end})
        adapter.request(context(1),cb)
        local p=processes.processes[4242]
        p:emit('stdout','data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call-a","type":"function","function":{"name":"read","arguments":"{\\"path\\":\\"file\\"}"}}]}}]}\n\n')
        status(p,'200');p:finish()
        assert.is_true(vim.wait(100,function()return s.resolved==1 end,1))
        assert.equals(0,s.complete);assert.equals(1,processes.spawn_calls)
        assert.same({{id='call-a',name='read',input={path='file'}}},observed)
        assert.same({{call_id='call-a',arguments={id='call-a',name='read',input={path='file'}}}},s.calls)
        assert.same({'result','round','resolved'},s.events)
    end)
    it('reports terminal failure after streamed output and still resolves physical cleanup',function()
        local cb,s=callbacks();local adapter=Provider.new();adapter.request(context(1),cb)
        local p=processes.processes[4242];p:emit('stdout','data: {"choices":[{"delta":{"content":"partial"}}]}\n\n')
        status(p,'500');p:finish(22)
        assert.is_true(vim.wait(100,function()return s.resolved==1 end,1))
        assert.same({'output','failed','resolved'},s.events)
    end)
end)
