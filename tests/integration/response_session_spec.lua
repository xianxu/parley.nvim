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
    -- #261 M4: when the generation stops, every process in its scope is stopped
    -- as a group — one no adapter knows about included (a content fetch, say).
    it('kills its generation scope when it stops, reaching a process no adapter tracks',function()
        local s=start(doc,spec(0),{buf=buf,agent='fixture',build_input=function(previous)return previous end,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end},sessions)
        pump(s);assert.equals(1,processes.spawn_calls)
        local generation=Session.snapshot(s).generation
        Tasker.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='stray',
            logical_generation=Tasker.scope_key(generation.epoch,generation.generation)})
        local stray=processes.processes[4243]
        Session.cancel(s);pump(s)
        local signalled=false
        for _,sig in ipairs(processes.signals)do if sig.pid==stray.pid and sig.group then signalled=true end end
        assert.is_true(signalled,'the stray process in the scope was not signalled')
    end)
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
    -- #266: preparation reports its input without writing, so the request starts
    -- at once; the gap is written immediately before the first write.
    local function lone_opts()
        return {buf=buf,agent='fixture',build_input=function(previous)return previous end,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end}
    end
    local function lines()return vim.api.nvim_buf_get_lines(buf,0,-1,false)end
    -- The pending status lines: presentation only, never transcript.
    local function notes()
        local ns=vim.api.nvim_create_namespace('parley_chat_pending')
        local out={}
        for _,mark in ipairs(vim.api.nvim_buf_get_extmarks(buf,ns,0,-1,{details=true}))do
            local virt=mark[4].virt_lines;if virt then out[#out+1]=virt[1][1][1] end
        end
        return table.concat(out,'\n')
    end
    it('starts the request before the gap and lands the gap once, immediately before the first output',function()
        local before=lines()
        local s=start(doc,spec(0),lone_opts(),sessions);pump(s)
        assert.equals(1,processes.spawn_calls,'the request must not wait for the gap')
        assert.same(before,lines(),'the old answer stays until something replaces it')
        local p=processes.processes[4242]
        p:emit('stdout','data: {"choices":[{"delta":{"content":"fresh"}}]}\n\n');status(p);p:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        assert.equals('success',Session.snapshot(s).generation.outcome)
        local text=table.concat(lines(),'\n')
        local _,headers=text:gsub('🤖: fixture','')
        assert.equals(1,headers,'the gap lands exactly once')
        assert.truthy(text:find('🤖: fixture%s+fresh'),'the gap sits immediately before the output: '..text)
        local _,olds=text:gsub('🤖: old','')
        assert.equals(1,olds,'the replaced answer is gone; only the other exchange keeps its old answer')
    end)
    it('leaves the transcript untouched when cancelled before any output',function()
        local before=lines()
        local s=start(doc,spec(0),lone_opts(),sessions);pump(s)
        assert.equals(1,processes.spawn_calls)
        Session.cancel(s);pump(s)
        local p=processes.processes[4242];status(p);p:exit();p:emit('stdout',nil);p:emit('stderr',nil)
        vim.wait(200,function()return #Tasker._handles==0 end,1);pump(s)
        assert.equals('terminal',Session.snapshot(s).status)
        assert.same(before,lines(),'a response with nothing to say must not touch the transcript')
    end)
    it('holds a second answer, gap included, until the first answer finishes',function()
        local a=start(doc,spec(0),lone_opts(),sessions);local b=start(doc,spec(3),lone_opts(),sessions)
        pump(a);pump(b)
        assert.equals(2,processes.spawn_calls,'both requests run concurrently')
        local pa,pb=processes.processes[4242],processes.processes[4243]
        pa:emit('stdout','data: {"choices":[{"delta":{"content":"alpha"}}]}\n\n')
        pb:emit('stdout','data: {"choices":[{"delta":{"content":"beta"}}]}\n\n');status(pb);pb:finish()
        vim.wait(100,function()return #Tasker._handles==1 end,1);pump(b);pump(a);pump(b)
        local held=lines()
        assert.truthy(table.concat(held,'\n'):find('alpha',1,true),'the holder writes')
        assert.is_nil(table.concat(held,'\n'):find('beta',1,true),'the second answer is held')
        assert.same({'💬: q','🤖: old','text'},{held[#held-4],held[#held-3],held[#held-2]},
            'its gap is held too: the old second answer is still in place')
        status(pa);pa:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(a);pump(b)
        assert.equals('success',Session.snapshot(a).generation.outcome)
        assert.equals('success',Session.snapshot(b).generation.outcome)
        local text=table.concat(lines(),'\n')
        assert.truthy(text:find('alpha',1,true));assert.truthy(text:find('🤖: fixture%s+beta'),text)
    end)
    -- M1 review I2: the gap writer must settle on every path. A writer that
    -- returns without reporting leaves the machine's gap 'writing' forever, and
    -- then nothing — output, round or finalize — may ever write.
    it('settles the gap when preparation cannot start at write time',function()
        local original=Preparation.start
        Preparation.start=function()return nil,'forced preparation failure'end
        local before=lines()
        local s=start(doc,spec(0),lone_opts(),sessions);pump(s)
        local p=processes.processes[4242]
        p:emit('stdout','data: {"choices":[{"delta":{"content":"fresh"}}]}\n\n')
        pump(s);Preparation.start=original
        status(p);p:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        local generation=Session.snapshot(s).generation
        assert.equals('terminal',generation.phase)
        assert.equals('prepare_failed',generation.outcome)
        assert.are_not.equal('writing',generation.gap,'the gap must be settled, not left writing')
        assert.equals('forced preparation failure',generation.failure)
        assert.same(before,lines(),'a gap that never landed leaves the transcript as it was')
    end)
    it('tells a held answer what it waits for, without touching the transcript',function()
        local a=start(doc,spec(0),lone_opts(),sessions);local b=start(doc,spec(3),lone_opts(),sessions)
        pump(a);pump(b)
        local before=lines()
        assert.is_true(vim.wait(500,function()return notes():find('Waiting for the answer to line 1',1,true)~=nil end,5),notes())
        assert.truthy(notes():find('(streaming)',1,true),notes())
        assert.same(before,lines(),'the note is presentation, never transcript')
        -- M1 review: the held answer's own provider detail shares the one status
        -- slot; while it is held, the note must win or it is never shown again.
        processes.processes[4243]:emit('stdout','data: {"choices":[{"delta":{"reasoning_content":"thinking"}}]}\n\n')
        vim.wait(100,function()return false end,5)
        assert.truthy(notes():find('Waiting for',1,true),'provider detail must not bury the note: '..notes())
        local pa=processes.processes[4242]
        pa:emit('stdout','data: {"choices":[{"delta":{"content":"alpha"}}]}\n\n');status(pa);pa:finish()
        vim.wait(100,function()return #Tasker._handles==1 end,1);pump(a);pump(b)
        assert.equals('success',Session.snapshot(a).generation.outcome)
        assert.is_true(vim.wait(500,function()return not notes():find('Waiting for',1,true)end,5),
            'the note must clear once the turn arrives: '..notes())
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

    -- #266 M2 Task 3.4: the transcript now shows only the blocks that have
    -- landed — call a until a's result arrives — so the tools still running are
    -- reported where concurrency belongs: on the pending extmark.
    it('shows every tool in flight while only the first call block is written',function()
        local events={}
        local producer={start=function(call,_,cb)events[call.id]=cb;return {}end,
            cancel=function(_,done)done()end}
        local s=start(doc,spec(0),{buf=buf,agent='fixture',producer=producer,
            prepare_input=function(_,cb)cb.prepared(input(buf));cb.resolved();return {}end,
            build_input=function(previous,messages)previous.messages=messages;previous.payload.messages=messages;return previous end},sessions)
        pump(s)
        local function text()return table.concat(lines(),'\n')end
        local p=processes.processes[4242]
        p:emit('stdout','data: '..vim.json.encode({choices={{delta={tool_calls={
            {index=0,id='call-a',type='function',['function']={name='read_file',arguments='{"path":"a"}'}},
            {index=1,id='call-b',type='function',['function']={name='read_file',arguments='{"path":"b"}'}}}}}}})..'\n\n')
        status(p);p:finish();vim.wait(100,function()return #Tasker._handles==0 end,1);pump(s)
        assert.is_not_nil(events['call-a']);assert.is_not_nil(events['call-b'])
        assert.truthy(text():find('id=call-a',1,true));assert.is_nil(text():find('id=call-b',1,true))
        assert.is_true(vim.wait(500,function()return notes():find('0 of 2',1,true)~=nil end,5),notes())
        events['call-b'].outcome('known',{content='b done'});events['call-b'].resolved();pump(s)
        assert.is_nil(text():find('id=call-b',1,true),'b is held behind a')
        assert.is_true(vim.wait(500,function()return notes():find('1 of 2',1,true)~=nil end,5),notes())
        events['call-a'].outcome('known',{content='a done'});events['call-a'].resolved();pump(s)
        assert.truthy(text():find('b done',1,true))
        assert.is_true(vim.wait(500,function()return not notes():find('of 2',1,true)end,5),
            'the note clears once the round continues: '..notes())
    end)

    -- #266 M3 (operator): Stop during a tool round writes the round out; a
    -- stopped answer behind another keeps its place, says so, and writes its
    -- pairs when the turn arrives.
    it('writes a stopped answer\'s tool round when its turn arrives, saying so meanwhile',function()
        local events={}
        -- As the real producer does for a started tool: cancellation hands it to
        -- its supervisor (tools/producer.lua cancel), which is what lets a tool
        -- that never reported an outcome retire.
        local producer={start=function(call,_,cb)events[call.id]=cb;return {}end,cancel=function(_,done)done({supervised=true})end}
        local function tool_opts()
            local o=lone_opts();o.producer=producer
            o.build_input=function(previous,messages)previous.messages=messages;previous.payload.messages=messages;return previous end
            return o
        end
        local a=start(doc,spec(0),lone_opts(),sessions);local b=start(doc,spec(3),tool_opts(),sessions)
        pump(a);pump(b)
        local pb=processes.processes[4243]
        pb:emit('stdout','data: '..vim.json.encode({choices={{delta={tool_calls={
            {index=0,id='call-b',type='function',['function']={name='read_file',arguments='{"path":"b"}'}}}}}}})..'\n\n')
        status(pb);pb:finish();vim.wait(100,function()return #Tasker._handles==1 end,1);pump(b);pump(a);pump(b)
        assert.is_not_nil(events['call-b'],'b\'s tool runs while a streams')
        Session.cancel(b,'operator stopped response');pump(b)
        assert.equals('flushing',Session.snapshot(b).generation.phase)
        assert.is_true(vim.wait(500,function()return notes():find('Stopped; writing its tool results after the answer to line 1',1,true)~=nil end,5),notes())
        assert.is_nil(table.concat(lines(),'\n'):find('id=call-b',1,true),'nothing written before the turn arrives')
        local pa=processes.processes[4242]
        pa:emit('stdout','data: {"choices":[{"delta":{"content":"alpha"}}]}\n\n');status(pa);pa:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(a);pump(b)
        local text=table.concat(lines(),'\n')
        assert.truthy(text:find('id=call-b error=true',1,true),text)
        assert.truthy(text:find('Cancelled by the user while running',1,true),text)
        assert.equals('terminal',Session.snapshot(b).generation.phase)
        assert.equals('cancelled',Session.snapshot(b).generation.outcome)
    end)

    -- #266 close review (stall-visibility, 4th): a wait note is state, not an
    -- event. A held answer gets the turn and writes its text and first call
    -- block while both its tools still run; each write clears the status line,
    -- so the tools note must be shown again after it.
    it('keeps the tools note on screen after a held answer\'s writes land',function()
        local events={}
        local producer={start=function(call,_,cb)events[call.id]=cb;return {}end,cancel=function(_,done)done({supervised=true})end}
        local o=lone_opts();o.producer=producer
        o.build_input=function(previous,messages)previous.messages=messages;previous.payload.messages=messages;return previous end
        local a=start(doc,spec(0),lone_opts(),sessions);local b=start(doc,spec(3),o,sessions)
        pump(a);pump(b)
        local pb=processes.processes[4243]
        pb:emit('stdout','data: {"choices":[{"delta":{"content":"beta"}}]}\n\n')
        pb:emit('stdout','data: '..vim.json.encode({choices={{delta={tool_calls={
            {index=0,id='call-a',type='function',['function']={name='read_file',arguments='{"path":"a"}'}},
            {index=1,id='call-b',type='function',['function']={name='read_file',arguments='{"path":"b"}'}}}}}}})..'\n\n')
        status(pb);pb:finish();vim.wait(100,function()return #Tasker._handles==1 end,1);pump(b);pump(a);pump(b)
        assert.is_not_nil(events['call-a']);assert.is_not_nil(events['call-b'])
        assert.is_true(vim.wait(500,function()return notes():find('Waiting for the answer to line 1',1,true)~=nil end,5),notes())
        local pa=processes.processes[4242]
        pa:emit('stdout','data: {"choices":[{"delta":{"content":"alpha"}}]}\n\n');status(pa);pa:finish()
        vim.wait(100,function()return #Tasker._handles==0 end,1);pump(a);pump(b)
        local text=table.concat(lines(),'\n')
        assert.truthy(text:find('beta',1,true),text)
        assert.truthy(text:find('id=call-a',1,true),text)
        assert.is_true(vim.wait(500,function()return notes():find('0 of 2',1,true)~=nil end,5),
            'the tools note must survive the writes: ['..notes()..']')
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
