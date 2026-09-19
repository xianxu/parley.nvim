local T=require('parley.tasker')
local Fake=require('tests.helpers.fake_process')
local function wait(fn)assert.is_true(vim.wait(2000,fn,1))end

describe('bounded process supervision',function()
    local processes,now
    before_each(function()
        T._reset();T._uv,processes=Fake.new();now=0;T._clock=function()return now end
    end)
    -- The reconcile timer; a deadline timer (60000) is armed beside it at spawn.
    local function reconcile_timer()
        for _,timer in ipairs(processes.timers)do if timer.delay~=60000 then return timer end end
    end
    after_each(function()
        for _,p in pairs(processes.processes)do p:finish()end
        vim.wait(100,function()return #T._handles==0 end,1)
        T._reset();T._uv=nil;T._clock=nil
    end)
    -- #261 M3: a generation's processes lead their own group, so a stop can kill
    -- the whole group; a run with no generation stays in Neovim's session, where
    -- a terminal prompt still works.
    it('spawns a scoped run as its own group leader and an unscoped one attached',function()
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='s',generation_id='g',logical_generation='e:1'})
        T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='u',deadline_ms=60000})
        assert.is_true(processes.spawn_options[1].detached)
        assert.is_nil(processes.spawn_options[2].detached)
        assert.is_nil(processes.spawn_options[1].detach, 'luv ignores the misspelled key')
    end)
    it('passes captured cwd and cancels an attempt without its sibling',function()
        local a=T.run(1,'fixture',{},nil,nil,nil,nil,{cwd='/captured',attempt_id='a',generation_id='g',admission_key='a'})
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='b',generation_id='g',admission_key='b'})
        assert.equals('/captured',processes.processes[4242].cwd)
        assert.equals(1,T.stop_attempt(a))
        assert.equals(1,#processes.signals);assert.equals(4242,processes.signals[1].pid)
        assert.is_not_nil(T.get_attempt('b'))
    end)
    it('bounds retained output before concatenation and holds overflow until physical drain',function()
        local result,received
        T.run(1,'fixture',{},function(_,_,out,err,failure)result={out,err,failure}end,
            function(_,bytes)if bytes then received=(received or 0)+#bytes end end,nil,nil,
            {attempt_id='bounded',stdout_limit=8,stderr_limit=4,deadline_ms=60000})
        local p=processes.processes[4242];p:emit('stdout',string.rep('x',100));p:emit('stderr','123456')
        assert.equals(8,received);assert.is_nil(result);assert.is_true(T.stats().retained_bytes<=12)
        p:exit();assert.is_nil(result);p:emit('stdout',nil);assert.is_nil(result);p:emit('stderr',nil)
        wait(function()return result~=nil end)
        assert.equals('xxxxxxxx',result[1]);assert.is_true(#result[2]<=4);assert.is_not_nil(result[3])
        assert.equals(0,T.stats().retained_bytes)
    end)
    it('streams provider output beyond capture limit with zero stdout retention',function()
        local received,result=0,nil
        T.run(1,'fixture',{},function(_,_,out,_,failure)result={out,failure}end,
            function(_,bytes)if bytes then assert.is_true(#bytes<=65536);received=received+#bytes end end,nil,nil,
            {kind='provider',collect_stdout=false,attempt_id='provider',deadline_ms=60000})
        processes.processes[4242]:emit('stdout',string.rep('x',1048577))
        assert.equals(1048577,received);assert.equals(0,T.stats().retained_bytes)
        processes.processes[4242]:finish();wait(function()return result~=nil end)
        assert.equals('',result[1]);assert.is_nil(result[2])
    end)
    it('applies process document and logical-generation admission before spawn',function()
        assert.is_true(T.configure_limits({tool_attempts=3,total_attempts=4,document_generations=2,document_tools=2,generation_tools=1}).ok)
        local function run(id,buf,generation)
            return T.run(buf,'fixture',{},nil,nil,nil,function()end,
                {kind='tool',attempt_id=id,admission_key=id,logical_generation=generation})
        end
        assert.is_not_nil(run('a',1,'g1'));assert.is_nil(run('b',1,'g1'))
        assert.is_not_nil(run('c',1,'g2'));assert.is_nil(run('d',1,'g3'))
        assert.is_not_nil(run('e',2,'g3'));assert.is_nil(run('f',3,'g4'))
        assert.equals(3,processes.spawn_calls)
    end)
    it('uses capped reconciliation backoff then retires timer without fabricating cleanup',function()
        local terminal,unresolved=0,0
        T.run(1,'fixture',{},function()terminal=terminal+1 end,nil,nil,nil,
            {attempt_id='a',deadline_ms=60000,on_unresolved=function()unresolved=unresolved+1 end})
        T.stop_attempt('a');local p=processes.processes[4242];p.probe='missing'
        T.reconcile_step(0);assert.equals(0,T.get_attempt('a').reconcile_probes or 0)
        now=50;T.reconcile_step(now);assert.equals(1,T.get_attempt('a').reconcile_probes)
        T.reconcile_step(now);assert.equals(1,T.get_attempt('a').reconcile_probes)
        now=5000;T.reconcile_step(now);assert.equals(1,unresolved);assert.equals(0,terminal)
        assert.is_true(T.get_attempt('a').unresolved_visible);assert.is_true(reconcile_timer().closing)
        now=6000;T.reconcile_step(now);assert.equals(1,unresolved)
        assert.is_not_nil(T.get_attempt('a'));p:finish();wait(function()return terminal==1 end)
    end)
    it('closes reconciliation timers when exit and both EOFs arrive',function()
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='a',deadline_ms=60000});T.stop_attempt('a')
        processes.processes[4242]:finish();wait(function()return T.get_attempt('a')==nil end)
        for _,timer in ipairs(processes.timers)do assert.is_true(timer.closing)end
    end)
    it('never writes argv credentials to logger output',function()
        local logger=require('parley.logger');local debug=logger.debug;local messages={}
        logger.debug=function(value)messages[#messages+1]=value end
        T.run(1,'fixture',{'--secret','DO_NOT_LOG_CREDENTIAL'},nil,nil,nil,nil,{attempt_id='a',deadline_ms=60000})
        logger.debug=debug
        assert.is_nil(table.concat(messages,'\n'):find('DO_NOT_LOG_CREDENTIAL',1,true))
    end)
    it('freezes collection policy before caller mutates options',function()
        local opts={attempt_id='frozen',collect_stdout=false,deadline_ms=60000};local received=0
        T.run(1,'fixture',{},nil,function(_,data)if data then received=received+#data end end,nil,nil,opts)
        opts.collect_stdout=true
        processes.processes[4242]:emit('stdout',string.rep('x',1048577))
        assert.equals(1048577,received);assert.equals(0,T.stats().retained_bytes)
    end)
    it('bounds aggregate retention and releases capacity only after physical drain',function()
        assert.is_true(T.configure_limits({retained_bytes=10,total_attempts=2}).ok)
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='a',deadline_ms=60000})
        T.run(2,'fixture',{},nil,nil,nil,nil,{attempt_id='b',deadline_ms=60000})
        processes.processes[4242]:emit('stdout','12345678')
        processes.processes[4243]:emit('stdout','abcdef')
        assert.equals(10,T.stats().retained_bytes)
        assert.is_true(T.get_attempt('b').output_overflow)
        assert.is_nil(T.run(3,'fixture',{},nil,nil,nil,function()end,{attempt_id='c',deadline_ms=60000}))
        processes.processes[4243]:finish();wait(function()return T.get_attempt('b')==nil end)
        assert.equals(8,T.stats().retained_bytes)
        assert.is_not_nil(T.run(3,'fixture',{},nil,nil,nil,nil,{attempt_id='c',deadline_ms=60000}))
    end)
    it('keeps the editor responsive while native processes overlap in captured cwd',function()
        T._uv=nil;T._clock=nil
        local results={};local heartbeat=false
        local function launch(id)
            return T.run(nil,'/bin/sh',{'-c','sleep 0.15; pwd'},function(code,_,out,_,failure)
                results[id]={code=code,out=out,failure=failure}
            end,nil,nil,nil,{attempt_id=id,cwd='/tmp',deadline_ms=60000})
        end
        assert.is_not_nil(launch('native-a'));assert.is_not_nil(launch('native-b'))
        assert.equals(2,T.stats().active)
        vim.defer_fn(function()heartbeat=true end,10)
        wait(function()return heartbeat end)
        assert.is_nil(results['native-a']);assert.is_nil(results['native-b'])
        wait(function()return results['native-a'] and results['native-b'] end)
        for _,result in pairs(results)do
            assert.equals(0,result.code);assert.is_nil(result.failure)
            assert.equals((vim.uv or vim.loop).fs_realpath('/tmp'),(vim.uv or vim.loop).fs_realpath(vim.trim(result.out)))
        end
        assert.equals(0,T.stats().active);assert.equals(0,T.stats().timers)
    end)

    it('validates finite caps and counts utility work in the shared process ceiling',function()
        for _,bad in ipairs({0,-1,0/0,math.huge,1.5,33})do
            assert.is_false(T.configure_limits({total_attempts=bad}).ok)
        end
        assert.is_true(T.configure_limits({provider_attempts=1,total_attempts=2}).ok)
        local function run(id,kind)
            return T.run(nil,'fixture',{},nil,nil,nil,function()end,{attempt_id=id,kind=kind,deadline_ms=60000})
        end
        assert.is_not_nil(run('p','provider'));assert.is_nil(run('p2','provider'))
        assert.is_not_nil(run('utility','utility'));assert.is_nil(run('tool','tool'))
        assert.equals(2,processes.spawn_calls)
    end)
    -- #261 M3: a stop kills for certain. Each sequence ends with the record gone
    -- (or held, where stated) and the active count back at its baseline.
    describe('a stop kills for certain',function()
        local scoped={generation_id='g',logical_generation='e:1'}
        local function run(extra,callback)
            return T.run(1,'fixture',{},callback,nil,nil,nil,vim.tbl_extend('force',{attempt_id='a'},scoped,extra or {}))
        end
        local function recorder()
            local calls={}
            return calls,function(...)calls[#calls+1]={n=select('#',...),...}end
        end
        local function signals()
            local out={}
            for _,s in ipairs(processes.signals)do out[#out+1]=(s.group and 'group ' or 'pid ')..s.pid..':'..s.signal end
            table.sort(out) -- records are signalled in no set order
            return out
        end
        before_each(function()T._uv,processes=Fake.new({pipes_follow_holders=true})end)

        it('1: a group that ignores TERM gets SIGKILL at exactly 2 s, and the callback reads a kill',function()
            local calls,callback=recorder()
            run(nil,callback);local p=processes.processes[4242];p.ignores={[15]=true}
            assert.equals(1,T.stop_scope('e:1'))
            now=1999;T.reconcile_step(now);assert.same({'group 4242:15'},signals())
            now=2000;T.reconcile_step(now);assert.same({'group 4242:15','group 4242:9'},signals())
            wait(function()return #calls==1 end)
            assert.is_nil(calls[1][1]);assert.equals('killed: stop',calls[1][5])
            assert.equals(0,T.stats().active)
        end)
        it('2: a group TERM ends the parent and the grandchild holding its pipe',function()
            run();local p=processes.processes[4242];p:fork()
            T.stop_scope('e:1')
            assert.same({'group 4242:15','group 4243:15'},signals())
            wait(function()return T.stats().active==0 end)
        end)
        it('3: a stop after the parent exited still reaches the grandchild',function()
            local calls,callback=recorder()
            run(nil,callback);local p=processes.processes[4242];local g=p:fork()
            p:exit(0,0);now=100
            assert.is_not_nil(T.get_attempt('a'),'the grandchild holds the pipe')
            T.stop_scope('e:1')
            assert.same({'group 4243:15'},signals());assert.is_true(g.exited)
            wait(function()return #calls==1 end)
            assert.is_nil(calls[1][1],'the grandchild was killed: its output may be cut')
            assert.equals('killed: stop',calls[1][5])
        end)
        it('4: a process that exits between TERM and KILL gets no SIGKILL',function()
            run();local p=processes.processes[4242];p.ignores={[15]=true}
            T.stop_scope('e:1')
            now=1000;p:exit(0,0)
            wait(function()return T.stats().active==0 end)
            now=2000;T.reconcile_step(now)
            assert.same({'group 4242:15'},signals())
        end)
        it('5: a process gone before the stop is observed missing, and nothing raises',function()
            T._uv,processes=Fake.new({})
            T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='u',deadline_ms=60000})
            processes.processes[4242].signal_result='missing'
            assert.equals(1,T.stop_attempt('u'))
            assert.equals('missing',T.get_attempt('u').signal_observation)
            -- A scoped group whose members all exited before their EOF.
            T._uv,processes=Fake.new({})
            run();processes.processes[4242]:exit(0,0)
            assert.equals(1,T.stop_scope('e:1'))
            assert.equals('missing',T.get_attempt('a').signal_observation)
        end)
        it('6: stop_scope signals exactly the records of its scope',function()
            run({attempt_id='a',admission_key='a'});run({attempt_id='b',admission_key='b'})
            run({attempt_id='c',admission_key='c',logical_generation='e:2'})
            assert.equals(2,T.stop_scope(T.scope_key('e',1)))
            assert.same({'group 4242:15','group 4243:15'},signals())
            assert.is_not_nil(T.get_attempt('c'))
            assert.equals('e:1',T.scope_key('e',1))
        end)
        it('7: an unscoped run is killed by pid at its deadline, and its callback reads a kill',function()
            T._uv,processes=Fake.new({finish_on_signal=true})
            local calls,callback=recorder()
            T.run(nil,'fixture',{},callback,nil,nil,nil,{attempt_id='u',deadline_ms=60000})
            assert.is_nil(processes.spawn_options[1].detached)
            local deadline=processes.timers[1];assert.equals(60000,deadline.delay)
            deadline:fire()
            wait(function()return #calls==1 end)
            assert.same({'pid 4242:15'},signals())
            assert.is_nil(calls[1][1]);assert.equals('killed: deadline',calls[1][5])
            assert.is_true(deadline.closing,'the deadline timer retires with the record')
        end)
        it('8: an unscoped run without a deadline is refused, and its callback hears why',function()
            local calls,callback=recorder()
            assert.is_nil(T.run(nil,'fixture',{},callback,nil,nil,nil,{attempt_id='u'}))
            assert.equals(0,processes.spawn_calls)
            wait(function()return #calls==1 end)
            assert.equals(5,calls[1].n);assert.is_nil(calls[1][1])
            assert.truthy(calls[1][5]:find('deadline_ms',1,true))
            for _,bad in ipairs({0,-1,1.5,0/0,math.huge,'60'})do
                assert.is_nil(T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='bad',deadline_ms=bad}))
            end
            assert.equals(0,processes.spawn_calls)
        end)
        it('9: a refused spawn with no on_start_error settles its callback once, containing a throw',function()
            T._uv,processes=Fake.new({spawn_error='ENOENT'})
            local calls,callback=recorder()
            assert.is_nil(run(nil,callback))
            wait(function()return #calls==1 end)
            assert.is_nil(calls[1][1]);assert.truthy(calls[1][5]:find('ENOENT',1,true))
            local thrown=false
            assert.is_nil(run({attempt_id='t'},function()thrown=true;error('callback exploded')end))
            wait(function()return thrown end)
            vim.wait(20);assert.equals(1,#calls)
        end)
        it('10: a scoped kill by stop reads as a failure',function()
            local calls,callback=recorder()
            run(nil,callback);T.stop_scope('e:1')
            wait(function()return #calls==1 end)
            assert.is_nil(calls[1][1]);assert.equals('killed: stop',calls[1][5])
        end)
        it('11: a process that ignores KILL is held after 5 s, logged with its pid, and still counted',function()
            local logger=require('parley.logger');local warning=logger.warning;local messages={}
            logger.warning=function(value)messages[#messages+1]=value end
            local unresolved=0
            run({on_unresolved=function()unresolved=unresolved+1 end});local p=processes.processes[4242]
            p.ignores={[15]=true,[9]=true}
            now=10;T.stop_scope('e:1')
            now=2010;T.reconcile_step(now);now=5010;T.reconcile_step(now)
            logger.warning=warning
            assert.same({'group 4242:15','group 4242:9'},signals())
            assert.equals(1,unresolved);assert.equals(1,T.stats().active)
            assert.same({{pid=4242,kind='utility',since=10,scope='e:1'}},T.held())
            assert.truthy(table.concat(messages,'\n'):find('4242',1,true))
        end)
        it('a pipe error with exit 0 still reads as a failure: code is nil whenever io_error is set',function()
            local calls,callback=recorder()
            run(nil,callback);local p=processes.processes[4242]
            p:emit('stdout','cut');p:emit('stdout',nil,'EIO');p:exit(0,0);p:emit('stderr',nil)
            wait(function()return #calls==1 end)
            assert.is_nil(calls[1][1]);assert.equals('stdout: EIO',calls[1][5])
        end)
        -- #261 M3 review BR-43: pid 0 is Neovim's own group, and -0 == 0. The
        -- fake raises if it is ever signalled; tasker must not reach it.
        it('never signals a record whose pid is 0',function()
            T._uv,processes=Fake.new({spawn_pid=0})
            T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='z',deadline_ms=60000})
            assert.equals(0,T.get_attempt('z').pid)
            assert.equals(1,T.stop_attempt('z'))
            assert.equals('missing',T.get_attempt('z').signal_observation)
            assert.same({},processes.signals)
            now=2010;T.reconcile_step(now) -- the escalation would signal it too
            assert.same({},processes.signals)
        end)
        -- #261 M3 review BR-44: a held record is never retired, so the deadline
        -- timer must close as it fires rather than waiting for retire.
        it('keeps no deadline handle on a record the kernel holds',function()
            T._uv,processes=Fake.new({})
            local unresolved=0
            T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='h',deadline_ms=60000,
                on_unresolved=function()unresolved=unresolved+1 end})
            local p=processes.processes[4242];p.ignores={[15]=true,[9]=true}
            local deadline=processes.timers[1];assert.equals(60000,deadline.delay)
            now=10;deadline:fire()
            wait(function()return T.get_attempt('h').stop_cause=='deadline' end)
            now=2010;T.reconcile_step(now);now=5010;T.reconcile_step(now)
            assert.equals(1,unresolved);assert.equals(1,#T.held())
            assert.is_true(deadline.closing,'the fired deadline timer was not closed')
        end)
        it('leave kills every live record: scoped by group, unscoped by pid',function()
            run()
            T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='u',deadline_ms=60000})
            T.leave()
            assert.same({'group 4242:9','pid 4243:9'},signals())
            assert.equals('leave',T.get_attempt('u').stop_cause)
        end)
    end)
    it('drives reconciliation from its owned timer and retires an exit-without-EOF timer',function()
        T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='timer',deadline_ms=60000})
        processes.processes[4242]:exit()
        local timer=reconcile_timer();assert.equals(50,timer.delay)
        now=50;timer:fire()
        wait(function()return (T.get_attempt('timer').reconcile_probes or 0)==1 end)
        assert.equals(100,timer.delay)
        now=5000;timer:fire()
        wait(function()return T.get_attempt('timer').unresolved_visible==true end)
        assert.is_true(timer.closing);assert.equals(1,T.stats().active)
    end)

end)
