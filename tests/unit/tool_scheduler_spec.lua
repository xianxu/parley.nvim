local S=require('parley.tools.scheduler')
describe('captured tool scheduler',function()
    local service,gen,done,starts,queue,clock
    local function flush()while #queue>0 do table.remove(queue,1)()end end
    local function spec(id,path)return {attempt='1',round='1',call_id=id or 'a',name='tool',input={x=1},claims={{path=path or '/a',scope='file',mode='write'}}}end
    local function outcome(certainty,physical,effect)return {certainty=certainty,physical_resolved=physical,effect=effect or 'applied',evidence={checked=true},result={content='result'}}end
    before_each(function()
        done={};starts=0;queue={};clock=0
        service=S.new({schedule=function(fn)queue[#queue+1]=fn end,clock_ms=function()return clock end,timer=function()return function()end end})
        gen=assert(service:generation({document='doc',logical_generation='g',capabilities={tool={execute_async=function(_,_,cb)starts=starts+1;done[starts]=cb;return {cancel=function()end,reconcile=function()end}end}}}))
    end)
    it('captures authority and reuses known partial outcomes without replay',function()
        local result;local op=assert(service:execute(gen,spec(),{outcome=function(_,r)result=r end}))
        done[1](outcome('known',true,'partial'));flush();assert.equals('result',result.content)
        service:execute(gen,spec(),{outcome=function(_,r)result=r end});flush();assert.equals(1,starts)
        local changed=spec();changed.input.x=2;local refused,why=service:execute(gen,changed,{})
        assert.is_nil(refused);assert.equals('conflict',why);assert.equals('partial',service:snapshot(op).effect)
    end)
    it('keeps unknown claims across close until known evidence and physical completion',function()
        local op=service:execute(gen,spec(),{});done[1](outcome('unknown',false,'unknown'));flush()
        service:close_generation(gen);assert.is_nil(service:execute(gen,spec('retired'),{}))
        local g=service:generation({document='other',logical_generation='h',capabilities={tool={execute_async=function(_,_,cb)starts=starts+1;done[starts]=cb end}}})
        service:execute(g,spec('b'),{});assert.equals(1,starts)
        assert.is_true(service:reconcile(op,outcome('known',true))) -- operator cannot fabricate physical completion
        flush();assert.equals(1,starts)
        done[1](outcome('known',true));flush();assert.equals(2,starts)
        assert.equals(1,service:stats().records)
    end)
    it('cancels queued work immediately but waits on running cancellation',function()
        local resolved=0;local a=service:execute(gen,spec(),{resolved=function()resolved=resolved+1 end})
        local b=service:execute(gen,spec('b'),{resolved=function()resolved=resolved+1 end})
        service:cancel(b);flush();assert.equals(1,resolved);assert.equals(1,starts)
        service:cancel(a);flush();assert.equals(1,resolved)
        done[1](outcome('known',true,'not_applied'));flush();assert.equals(2,resolved)
        service:close_generation(gen);assert.equals(0,service:stats().records)
    end)
    it('records effects before a formatter fails and bounds retained output',function()
        local observed
        service=S.new({schedule=function(fn)queue[#queue+1]=fn end,limits={max_result_bytes=32},normalize=function()error('format')end})
        gen=service:generation({document='d',logical_generation='g',capabilities={tool={execute_async=function(_,_,cb)cb(outcome('known',true))end}}})
        local op=service:execute(gen,spec(),{outcome=function(_,r)observed=r end});flush()
        assert.equals('applied',service:snapshot(op).effect);assert.is_true(observed.is_error)
        assert.is_true(service:stats().result_bytes<=32)
    end)
    it('retires probe timers after five seconds without releasing unknown effects',function()
        local op=service:execute(gen,spec(),{});done[1](outcome('unknown',true,'unknown'));flush()
        clock=6000;service:reconcile_step();assert.equals(1,service:stats().unknown)
        assert.equals(0,service:stats().polling);assert.is_not_nil(service:snapshot(op))
    end)
    it('captures definitions and rejects unsafe configuration before effects',function()
        local config={value='original'};local seen
        local def={config=config,execute_async=function(_,ctx,cb)seen=ctx.config.value;cb(outcome('known',true))end}
        local g=service:generation({document='d',logical_generation='captured',capabilities={tool=def}})
        config.value='changed';def.execute_async=function()error('replaced')end
        service:execute(g,spec(),{});flush();assert.equals('original',seen)
        assert.is_nil(service:generation({document='d',logical_generation='bad',capabilities={tool={execute_async=function()end,config={fn=function()end}}}}))
    end)
    it('does not start queued tools inside a native callback',function()
        local inside=false;local escaped=false;local callback
        local g=service:generation({document='d',logical_generation='native',capabilities={tool={execute_async=function(_,_,cb)if inside then escaped=true end;callback=cb end}}})
        service:execute(g,spec(),{});service:execute(g,spec('b'),{})
        inside=true;callback(outcome('known',true));inside=false
        assert.is_false(escaped);flush();assert.is_false(escaped)
    end)
    it('closes reentrantly without starting queued work or double pruning',function()
        service:execute(gen,spec(),{outcome=function()service:close_generation(gen)end})
        service:execute(gen,spec('b'),{});done[1](outcome('known',true));service:close_generation(gen);flush()
        assert.equals(1,starts);assert.equals(0,service:stats().records);assert.equals(0,service:stats().generations);assert.equals(0,service:stats().running)
    end)
    it('bounds large results across active known records and admission',function()
        for i=1,128 do local op=service:execute(gen,spec(tostring(i),'/p'..i),{});assert.is_not_nil(op)
            done[#done]( {certainty='known',effect='applied',physical_resolved=true,evidence={},result={content=string.rep('x',100000)}} );flush()
        end
        local op,why=service:execute(gen,spec('full'),{});assert.is_nil(op);assert.equals('capacity',why)
        assert.is_true(service:stats().result_bytes<=1048576)
        service:close_generation(gen);flush();assert.equals(0,service:stats().result_bytes)
    end)

    it('keeps results bounded and visible at the exact content limit',function()
        local result
        service:execute(gen,spec(),{outcome=function(_,value)result=value end})
        done[1]({certainty='known',effect='applied',physical_resolved=true,result={content=string.rep('x',70000)}});flush()
        assert.equals(65536,#result.content);assert.is_true(result.truncated)
        assert.has_error(function()S.new({limits={max_result_bytes=math.huge,max_total_result_bytes=math.huge}})end)
    end)
    it('handles submission throws followed by late evidence without replay',function()
        local callback;local resolved=0
        local g=service:generation({document='d',logical_generation='throw',capabilities={tool={execute_async=function(_,_,cb)callback=cb;error('after submission')end}}})
        local op=service:execute(g,spec(),{resolved=function()resolved=resolved+1 end});flush()
        assert.equals('unknown',service:snapshot(op).certainty);assert.equals(0,resolved)
        callback(outcome('known',true));flush();assert.equals(1,resolved)
        callback(outcome('unknown',false,'unknown'));flush()
        assert.equals('known',service:snapshot(op).certainty);assert.equals(1,resolved)
    end)
    it('matches independent single execution accounting across cancellation histories',function()
        local seed=27
        for round=1,40 do
            local callbacks={};local count={}
            local g=service:generation({document='d'..round,logical_generation='g'..round,capabilities={tool={execute_async=function(_,ctx,cb)count[ctx.call_id]=(count[ctx.call_id] or 0)+1;callbacks[ctx.call_id]=cb;return {cancel=function()end}end}}})
            local ops={}
            for n=1,6 do ops[n]=service:execute(g,spec(tostring(n),'/history/'..n),{})end
            for _=1,20 do
                seed=(seed*48271)%2147483647;local n=seed%6+1
                if seed%3==0 then service:cancel(ops[n])
                elseif callbacks[tostring(n)]then callbacks[tostring(n)](outcome('known',true))
                else service:execute(g,spec(tostring(n),'/history/'..n),{})end
                flush();for _,number in pairs(count)do assert.equals(1,number)end
            end
            service:close_generation(g)
            for _,cb in pairs(callbacks)do cb(outcome('known',true))end;flush()
            assert.equals(0,service:stats().records);assert.equals(0,service:stats().running)
        end
    end)

    it('allows formatter closure without retaining results after retirement',function()
        local g
        service=S.new({schedule=function(fn)queue[#queue+1]=fn end,normalize=function()service:close_generation(g);return {content='a longer formatted result'} end})
        g=service:generation({document='d',logical_generation='format-close',capabilities={tool={execute_async=function(_,_,cb)cb(outcome('known',true))end}}})
        service:execute(g,spec(),{});flush()
        assert.equals(0,service:stats().records);assert.equals(0,service:stats().result_bytes)
    end)

end)
