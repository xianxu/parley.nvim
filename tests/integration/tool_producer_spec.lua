local Producer=require('parley.tools.producer')
local Scheduler=require('parley.tools.scheduler')
describe('supervised tool producer adapter',function()
    local root,queue,service,producer,done,starts,cancelled,definition
    local function flush()while #queue>0 do table.remove(queue,1)()end end
    local function ctx()return {epoch=1,generation=2,round=1,attempt=1}end
    local function call(id)return {id=id or 'a',name='fixture',input={}}end
    local function outcome(physical)return {certainty='known',effect='applied',physical_resolved=physical,
        result={content='confirmed'},evidence={checked=true}}end
    before_each(function()
        root=vim.fn.tempname()..'-producer';vim.fn.mkdir(root,'p')
        queue={};starts=0;cancelled=0;done={}
        service=Scheduler.new({schedule=function(fn)queue[#queue+1]=fn end,timer=function()return function()end end})
        definition={name='fixture',description='fixture',input_schema={},kind='write',resources=function()return {}end,
            execute_async=function(_,_,cb)starts=starts+1;done[#done+1]=cb;return {cancel=function()cancelled=cancelled+1 end}end}
        producer=assert(Producer.new({allowed_tools={'fixture'},registry={get=function()return definition end},
            root_policy={write_root=root,read_roots={root}},buf=55,scheduler=service}))
    end)
    after_each(function()
        producer.close()
        for _,cb in ipairs(done)do cb(outcome(true))end
        flush();vim.fn.delete(root,'rf')
    end)
    it('captures definitions once and normalizes only after effect evidence is recorded',function()
        definition.execute_async=function()error('mutated registry')end
        local results,resolved={},0
        producer.start(call(),ctx(),{outcome=function(kind,result)
            assert.equals('known',kind);assert.equals(1,service:stats().records)
            results[#results+1]=result
        end,resolved=function()resolved=resolved+1 end})
        assert.equals(1,starts);done[1](outcome(false));flush()
        assert.equals('a',results[1].id);assert.equals('confirmed',results[1].content);assert.equals(0,resolved)
        done[1](outcome(true));flush();assert.equals(1,#results);assert.equals(1,resolved)
    end)
    it('rejects uncaptured tools and changed generation identity before effects',function()
        local failures,resolved=0,0
        local events={outcome=function(kind,result)assert.equals('known',kind);assert.is_true(result.is_error);failures=failures+1 end,
            resolved=function()resolved=resolved+1 end}
        local bad=call();bad.name='other';producer.start(bad,ctx(),events)
        producer.start(call(),ctx(),{})
        local changed=ctx();changed.epoch=2;producer.start(call('b'),changed,events)
        assert.equals(1,starts);assert.equals(2,failures);assert.equals(2,resolved)
    end)
    it('hands cancellation to supervision without claiming physical closure',function()
        local callbacks=0;local h=producer.start(call(),ctx(),{outcome=function()callbacks=callbacks+1 end,resolved=function()callbacks=callbacks+1 end})
        local handoff;producer.cancel(h,function(value)handoff=value end)
        assert.same({supervised=true},handoff);assert.equals(1,cancelled)
        assert.equals(1,service:stats().records)
        done[1](outcome(true));flush();assert.equals(0,callbacks)
        producer.close();assert.equals(0,service:stats().records)
    end)
    it('cancels one child without suppressing its sibling callbacks',function()
        local results={}
        local a=producer.start(call('a'),ctx(),{outcome=function()error('cancelled child callback')end})
        producer.start(call('b'),ctx(),{outcome=function(_,r)results[#results+1]=r.id end})
        producer.cancel(a,function(value)assert.is_true(value.supervised)end)
        done[2](outcome(true));flush();assert.same({'b'},results)
        done[1](outcome(true));flush();assert.same({'b'},results)
    end)
    -- #266 M3: only a tool whose process still runs keeps its claims past close;
    -- one that ended (even with an unknown outcome) is a plain failure and holds
    -- nothing.
    -- #266 M3 review BR-15: a tool the scheduler had not started is settled by
    -- its own "cancelled before execution" outcome, not handed to the supervisor,
    -- which would erase the evidence that it never ran.
    it('settles a cancelled tool that never started by its own outcome',function()
        local same={name='fixture',description='fixture',input_schema={},kind='write',
            resources=function()return {{path=root..'/same',scope='file',mode='write'}}end,
            execute_async=function(_,_,cb)starts=starts+1;done[#done+1]=cb;return {cancel=function()end}end}
        local p=assert(Producer.new({allowed_tools={'fixture'},registry={get=function()return same end},
            root_policy={write_root=root,read_roots={root}},buf=56,scheduler=service}))
        p.start(call('first'),ctx(),{})
        local kind,result,resolved,supervised
        local second=p.start(call('second'),ctx(),{outcome=function(k,r)kind,result=k,r end,resolved=function()resolved=true end})
        assert.equals(1,starts,'the second waits behind the first')
        p.cancel(second,function(evidence)supervised=evidence and evidence.supervised end)
        flush()
        assert.equals(1,starts,'it never ran');assert.is_nil(supervised,'not handed to the supervisor')
        assert.equals('known',kind);assert.is_true(result.is_error)
        assert.truthy(result.content:find('before execution',1,true),result.content)
        assert.is_true(resolved)
        p.close()
    end)
    it('severs closed generation callbacks while a still-running unknown keeps its claims',function()
        local callbacks=0
        producer.start(call(),ctx(),{outcome=function()callbacks=callbacks+1 end})
        done[1]({certainty='unknown',effect='unknown',physical_resolved=false,result={content='uncertain'}});flush()
        assert.equals(1,callbacks);producer.close();assert.equals(1,service:stats().records)
        done[1](outcome(true));flush();assert.equals(1,callbacks);assert.equals(0,service:stats().records)
    end)
    it('retires a crashed tool at close once its process has ended',function()
        producer.start(call(),ctx(),{outcome=function()end})
        done[1]({certainty='unknown',effect='unknown',physical_resolved=true,result={content='crashed'}});flush()
        producer.close();assert.equals(0,service:stats().records)
    end)
    it('delivers later known evidence after physical completion of an unknown outcome',function()
        local kinds,resolved={},0
        producer.start(call(),ctx(),{outcome=function(kind)kinds[#kinds+1]=kind end,resolved=function()resolved=resolved+1 end})
        done[1]({certainty='unknown',effect='unknown',physical_resolved=true,result={content='uncertain'}});flush()
        done[1](outcome(true));flush()
        assert.same({'unknown','known'},kinds);assert.equals(1,resolved)
    end)
    it('supports an empty deny-only profile without current root or editor authority',function()
        local p=assert(Producer.new({allowed_tools={}}));local result,resolved
        p.start(call(),ctx(),{outcome=function(_,value)result=value end,resolved=function()resolved=true end})
        assert.is_true(result.is_error);assert.is_true(resolved);p.close()
    end)
    it('survives synchronous completion followed by reentrant close',function()
        local immediate=Scheduler.new({schedule=function(fn)fn()end,timer=function()return function()end end})
        local def=vim.deepcopy(definition);def.execute_async=function(_,_,cb)cb(outcome(true));return {}end
        local p=assert(Producer.new({allowed_tools={'fixture'},registry={get=function()return def end},
            root_policy={write_root=root,read_roots={root}},buf=56,scheduler=immediate}))
        local count=0
        p.start(call(),ctx(),{outcome=function()count=count+1;p.close()end})
        assert.equals(1,count);assert.equals(0,immediate:stats().records)
    end)
    it('keeps global operator identities stable across idle reconfiguration and retains active quarantine',function()
        local function new()
            return assert(Producer.new({allowed_tools={'fixture'},registry={get=function()return definition end},
                root_policy={write_root=root,read_roots={root}},buf=55}))
        end
        local p=new();p.start(call(),ctx(),{})
        local list=Producer.list();assert.equals(1,#list)
        local id=list[1].id
        assert.equals('fixture',list[1].name);assert.equals('1:2',list[1].logical_generation)
        done[#done]({certainty='unknown',effect='unknown',physical_resolved=true,result={content='unknown'}})
        assert.is_true(vim.wait(1000,function()return Producer.list()[1].certainty=='unknown'end,1))
        p.close()
        assert.is_false(Producer.configure({max_records=127}).ok)
        assert.equals(id,Producer.list()[1].id)
        done[#done](outcome(true))
        assert.is_true(vim.wait(1000,function()return Producer.stats().records==0 end,1))
        assert.is_true(Producer.configure({max_records=127}).ok)
        p=new();p.start(call(),ctx(),{})
        assert.is_not.equals(id,Producer.list()[1].id)
        assert.is_false(Producer.reconcile(id,outcome(true)))
        done[#done](outcome(true));p.close()
        assert.is_true(vim.wait(1000,function()return Producer.stats().records==0 end,1))
        assert.is_true(Producer.configure(Producer.defaults()).ok)
    end)
    it('never transfers supervision for an unknown cancellation handle',function()
        local called=false
        assert.is_false(producer.cancel({},function()called=true end));assert.is_false(called)
    end)
    it('validates finite defaults and refuses unsafe configuration',function()
        local defaults=Producer.defaults()
        assert.equals(524288,defaults.max_result_bytes);assert.equals(16777216,defaults.max_total_result_bytes)
        assert.is_false(Producer.configure({max_records=129}).ok)
        assert.is_false(Producer.configure({max_file_bytes=math.huge}).ok)
        assert.is_true(Producer.configure(defaults).ok)
    end)
end)
