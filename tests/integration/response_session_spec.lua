local ok,Session=pcall(require,'parley.response_session')
local D=require('parley.document')
local Layout=require('parley.response_layout')
local Preparation=require('parley.response_preparation')
local Dispatcher=require('parley.dispatcher')
local Tasker=require('parley.tasker')
local Vault=require('parley.vault')
local Process=require('tests.helpers.fake_process')
local function status(p)
    for i,arg in ipairs(p.args)do if arg=='--write-out'then
        p:emit('stderr',p.args[i+1]:match('%%{stderr}(.-)%%{http_code}')..'200\n');return
    end end
end
local function input(buf)return {buf=buf,provider='openai',model='fixture',messages={},payload={model='fixture',messages={}}}end
local function spec(row)
    local body={'🤖: old','text'}
    local plan=Preparation.plan(Layout.prepare({lines=body,first_row=row+1,first_byte=1,
        header_lines={'🤖: fixture'}},{chat_branch_prefix='🌿:',chat_local_prefix='🔒:'}))
    return {operation='respond',question={first={row=row,col=0},last={row=row,col=#'💬: q'}},
        output={first={row=row,col=#'💬: q'},last={row=row+2,col=4}},preparation=plan,input={},schedule=false}
end
local function pump(s)for _=1,150 do Session.step(s)end end
describe('production response session composition',function()
    local buf,doc,processes,old_secret,old_run,sessions
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: old','text','💬: q','🤖: old','text','💬: next','draft'})
        doc=D.attach(buf,{schedule=false});sessions={}
        local runtime;runtime,processes=Process.new();Tasker._reset();Tasker._uv=runtime
        old_secret,old_run=Vault.get_secret,Vault.run_with_secret
        Vault.get_secret=function()return 'fixture-secret'end;Vault.run_with_secret=function(_,fn)fn()end
        Dispatcher.providers.openai={endpoint='http://127.0.0.1:9/fixture'}
        Dispatcher.query_dir=vim.fn.tempname()..'-queries';vim.fn.mkdir(Dispatcher.query_dir,'p')
    end)
    after_each(function()
        for _,p in pairs(processes.processes)do status(p);p:finish()end
        vim.wait(100,function()return #Tasker._handles==0 end,1)
        if ok then for _,s in ipairs(sessions)do Session.cancel(s);pump(s)end end
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
        Vault.get_secret,Vault.run_with_secret=old_secret,old_run;Tasker._reset();Tasker._uv=nil
    end)
    it('provides one production session facade',function()assert.is_true(ok,tostring(Session))end)
    if not ok then return end
    local function start(doc,value,opts,sessions)
        local s=assert(Session.start(doc,value,opts));sessions[#sessions+1]=s;return s
    end
    it('composes disjoint native writers and preserves the next human draft',function()
        local function opts()return {buf=buf,agent='fixture',build_input=function(previous)return previous end,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end}end
        local a=start(doc,spec(0),opts(),sessions);local b=start(doc,spec(3),opts(),sessions)
        pump(a);pump(b);assert.equals(2,processes.spawn_calls)
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        vim.api.nvim_buf_set_text(buf,#lines-1,5,#lines-1,5,{' human'})
        for pid,p in pairs(processes.processes)do
            p:emit('stdout','data: {"choices":[{"delta":{"content":"answer'..pid..'"}}]}\n\n')
            status(p);p:finish()
        end
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(a);pump(b)
        assert.equals('success',Session.snapshot(a).generation.outcome)
        assert.equals('success',Session.snapshot(b).generation.outcome)
        local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
        assert.truthy(text:find('answer4242',1,true));assert.truthy(text:find('answer4243',1,true))
        assert.truthy(text:find('draft human',1,true))
    end)
    it('waits for positive preparation cleanup and ignores late prepared input after cancel',function()
        local callbacks,cancel_done
        local s=start(doc,spec(0),{buf=buf,agent='fixture',build_input=function(previous)return previous end,
            prepare_input=function(ctx,cb)
                assert.equals('valid',D.snapshot(doc).grants[ctx.grant].status);callbacks=cb;return {token=true}
            end,cancel_prepare=function(ctx,done)assert.is_true(ctx.handle.token);cancel_done=done end},sessions)
        pump(s);Session.cancel(s);pump(s)
        assert.equals('stopping',Session.snapshot(s).generation.phase)
        callbacks.prepared(input(buf));pump(s);assert.equals(0,processes.spawn_calls)
        cancel_done();pump(s);assert.equals('terminal',Session.snapshot(s).status)
        callbacks.resolved();pump(s);assert.equals(0,processes.spawn_calls)
    end)
    it('routes provider cancellation to one process and waits for its pipe cleanup',function()
        local function opts()return {buf=buf,agent='fixture',build_input=function(previous)return previous end,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end}end
        local a=start(doc,spec(0),opts(),sessions);local b=start(doc,spec(3),opts(),sessions)
        pump(a);pump(b);Session.cancel(a);pump(a)
        assert.equals(1,#processes.signals);assert.equals(4242,processes.signals[1].pid)
        assert.equals('stopping',Session.snapshot(a).generation.phase)
        local first=processes.processes[4242];status(first);first:exit()
        pump(a);assert.equals('stopping',Session.snapshot(a).generation.phase)
        first:emit('stdout',nil);first:emit('stderr',nil)
        vim.wait(100,function()return #Tasker._handles==1 end,1);pump(a)
        assert.equals('terminal',Session.snapshot(a).status)
        local second=processes.processes[4243]
        second:emit('stdout','data: {"choices":[{"delta":{"content":"sibling"}}]}\n\n')
        status(second);second:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(b)
        assert.equals('success',Session.snapshot(b).generation.outcome)
    end)
    it('composes a tool round and rebuilds the provider from frozen ordered results',function()
        local events,continued
        local producer={start=function(_,_,cb)events=cb;return {}end,
            cancel=function(_,done)done()end}
        local s=start(doc,spec(0),{buf=buf,agent='fixture',producer=producer,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end,
            build_input=function(previous,messages)
                continued=vim.deepcopy(messages);previous.messages=messages;previous.payload.messages=messages;return previous
            end},sessions)
        pump(s)
        local p=processes.processes[4242]
        p:emit('stdout','data: '..vim.json.encode({choices={{delta={tool_calls={{index=0,id='call-a',type='function',
            ['function']={name='read_file',arguments='{"path":"file"}'}}}}}}})..'\n\n')
        status(p);p:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        assert.is_not_nil(events)
        events.outcome('known',{content='tool content'});events.resolved();pump(s)
        assert.equals(2,processes.spawn_calls)
        assert.equals('tool content',continued[#continued].content[1].content)
        local last=processes.processes[4243];status(last);last:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        assert.equals('success',Session.snapshot(s).generation.outcome)
    end)

    it('releases host payloads before terminal notification even when IO retains callbacks',function()
        local callbacks,observed
        local retained=setmetatable({},{__mode='v'})
        local opts={buf=buf,agent='fixture',build_input=function(previous)return previous end}
        opts.host_payload={large=string.rep('x',10000)};retained[1]=opts.host_payload
        opts.prepare_input=function(_,cb)callbacks=cb;cb.prepared(input(buf));cb.resolved();return {}end
        opts.terminal=function()
            collectgarbage('collect');collectgarbage('collect');observed=retained[1]
        end
        local s=start(doc,spec(0),opts,sessions);opts=nil;pump(s)
        local p=processes.processes[4242];status(p);p:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        assert.equals('terminal',Session.snapshot(s).status)
        assert.is_nil(observed)
        assert.is_false(callbacks.prepared(input(buf)))
    end)

end)
