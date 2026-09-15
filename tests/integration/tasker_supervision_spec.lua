local T=require('parley.tasker')
local Fake=require('tests.helpers.fake_process')
local function wait(fn)assert.is_true(vim.wait(2000,fn,1))end

describe('bounded process supervision',function()
    local processes,now
    before_each(function()
        T._reset();T._uv,processes=Fake.new();now=0;T._clock=function()return now end
    end)
    after_each(function()
        for _,p in pairs(processes.processes)do p:finish()end
        vim.wait(100,function()return #T._handles==0 end,1)
        T._reset();T._uv=nil;T._clock=nil
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
            {attempt_id='bounded',stdout_limit=8,stderr_limit=4})
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
            {kind='provider',collect_stdout=false,attempt_id='provider'})
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
            {attempt_id='a',on_unresolved=function()unresolved=unresolved+1 end})
        T.stop_attempt('a');local p=processes.processes[4242];p.probe='missing'
        T.reconcile_step(0);assert.equals(0,T.get_attempt('a').reconcile_probes or 0)
        now=50;T.reconcile_step(now);assert.equals(1,T.get_attempt('a').reconcile_probes)
        T.reconcile_step(now);assert.equals(1,T.get_attempt('a').reconcile_probes)
        now=5000;T.reconcile_step(now);assert.equals(1,unresolved);assert.equals(0,terminal)
        assert.is_true(T.get_attempt('a').unresolved_visible);assert.is_true(processes.timers[1].closing)
        now=6000;T.reconcile_step(now);assert.equals(1,unresolved)
        assert.is_not_nil(T.get_attempt('a'));p:finish();wait(function()return terminal==1 end)
    end)
    it('closes reconciliation timers when exit and both EOFs arrive',function()
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='a'});T.stop_attempt('a')
        processes.processes[4242]:finish();wait(function()return T.get_attempt('a')==nil end)
        assert.is_true(processes.timers[1].closing)
    end)
    it('never writes argv credentials to logger output',function()
        local logger=require('parley.logger');local debug=logger.debug;local messages={}
        logger.debug=function(value)messages[#messages+1]=value end
        T.run(1,'fixture',{'--secret','DO_NOT_LOG_CREDENTIAL'},nil,nil,nil,nil,{attempt_id='a'})
        logger.debug=debug
        assert.is_nil(table.concat(messages,'\n'):find('DO_NOT_LOG_CREDENTIAL',1,true))
    end)
    it('freezes collection policy before caller mutates options',function()
        local opts={attempt_id='frozen',collect_stdout=false};local received=0
        T.run(1,'fixture',{},nil,function(_,data)if data then received=received+#data end end,nil,nil,opts)
        opts.collect_stdout=true
        processes.processes[4242]:emit('stdout',string.rep('x',1048577))
        assert.equals(1048577,received);assert.equals(0,T.stats().retained_bytes)
    end)
    it('bounds aggregate retention and releases capacity only after physical drain',function()
        assert.is_true(T.configure_limits({retained_bytes=10,total_attempts=2}).ok)
        T.run(1,'fixture',{},nil,nil,nil,nil,{attempt_id='a'})
        T.run(2,'fixture',{},nil,nil,nil,nil,{attempt_id='b'})
        processes.processes[4242]:emit('stdout','12345678')
        processes.processes[4243]:emit('stdout','abcdef')
        assert.equals(10,T.stats().retained_bytes)
        assert.is_true(T.get_attempt('b').output_overflow)
        assert.is_nil(T.run(3,'fixture',{},nil,nil,nil,function()end,{attempt_id='c'}))
        processes.processes[4243]:finish();wait(function()return T.get_attempt('b')==nil end)
        assert.equals(8,T.stats().retained_bytes)
        assert.is_not_nil(T.run(3,'fixture',{},nil,nil,nil,nil,{attempt_id='c'}))
    end)
    it('keeps the editor responsive while native processes overlap in captured cwd',function()
        T._uv=nil;T._clock=nil
        local results={};local heartbeat=false
        local function launch(id)
            return T.run(nil,'/bin/sh',{'-c','sleep 0.15; pwd'},function(code,_,out,_,failure)
                results[id]={code=code,out=out,failure=failure}
            end,nil,nil,nil,{attempt_id=id,cwd='/tmp'})
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
            return T.run(nil,'fixture',{},nil,nil,nil,function()end,{attempt_id=id,kind=kind})
        end
        assert.is_not_nil(run('p','provider'));assert.is_nil(run('p2','provider'))
        assert.is_not_nil(run('utility','utility'));assert.is_nil(run('tool','tool'))
        assert.equals(2,processes.spawn_calls)
    end)
    it('drives reconciliation from its owned timer and retires an exit-without-EOF timer',function()
        T.run(nil,'fixture',{},nil,nil,nil,nil,{attempt_id='timer'})
        processes.processes[4242]:exit()
        local timer=processes.timers[1];assert.equals(50,timer.delay)
        now=50;timer:fire()
        wait(function()return (T.get_attempt('timer').reconcile_probes or 0)==1 end)
        assert.equals(100,timer.delay)
        now=5000;timer:fire()
        wait(function()return T.get_attempt('timer').unresolved_visible==true end)
        assert.is_true(timer.closing);assert.equals(1,T.stats().active)
    end)

end)
