local O=require('parley.tools.operation')
local function spec(overrides)
    local value={generation='g',attempt='a',round='r',call_id='c',name='write_file',
        input={path='/file',content='before'},capability_ref='cap'}
    for k,v in pairs(overrides or {})do value[k]=v end
    return value
end
local function accept(options,overrides)
    local s,result=O.accept(O.new(options),spec(overrides));assert.equals('accepted',result.status)
    return s,result.key
end
local function event(s,key,kind,extra)
    local e={type=kind};for k,v in pairs(extra or {})do e[k]=v end
    return O.transition(s,key,e)
end
local function executing()
    local s,key=accept();s=event(s,key,'authorize',{capability_ref='cap'});s=event(s,key,'start')
    return s,key
end

describe('tool operation effect ledger',function()
    it('records immutable arguments before authorizing an effect',function()
        local initial=O.new();local input=spec()
        local s,result=O.accept(initial,input);input.input.content='mutated'
        assert.equals('queued',O.get(s,result.key).status);assert.equals('before',O.get(s,result.key).input.content)
        local unchanged,rejected=event(s,result.key,'start');assert.equals('invalid_transition',rejected.status)
        assert.same(s,unchanged);assert.equals(0,O.stats(initial).records)
        local bad,why=event(s,result.key,'authorize',{capability_ref='other'})
        assert.equals('authority',why.status);assert.same(s,bad)
        s=event(s,result.key,'authorize',{capability_ref='cap'});s=event(s,result.key,'start')
        local again,duplicate=event(s,result.key,'start');assert.equals('invalid_transition',duplicate.status)
        assert.same(s,again);assert.equals('executing',O.get(s,result.key).status)
    end)
    it('scopes duplicates and refuses changed arguments or authority',function()
        local s,key=accept();local same,result=O.accept(s,spec())
        assert.equals('duplicate',result.status);assert.equals(key,result.key);assert.same(s,same)
        for _,change in ipairs({{name='read_file'},{input={path='/other'}},{capability_ref='new'}})do
            local next_state,conflict=O.accept(s,spec(change));assert.equals('conflict',conflict.status);assert.same(s,next_state)
        end
        for _,field in ipairs({'generation','attempt','round','call_id'})do
            local next_state,added=O.accept(s,spec({[field]='different'}));assert.equals('accepted',added.status)
            assert.are_not.equals(key,added.key);assert.equals(2,O.stats(next_state).records)
        end
    end)
    it('reuses known results even when result presentation failed',function()
        local s,key=executing();s=event(s,key,'outcome',{effect='known',evidence_ref='written',result_ref='result'})
        s=event(s,key,'presentation_failed',{error_ref='serializer'})
        local _,reuse=O.accept(s,spec());assert.equals('reuse',reuse.status);assert.equals('result',reuse.result_ref)
        local record=O.get(s,key);assert.equals('outcome_known',record.status);assert.equals('written',record.evidence_ref)
        record.input.content='outside';assert.equals('before',O.get(s,key).input.content)
    end)
    it('never replays partial or unknown effects and requires explicit effect reconciliation',function()
        for _,effect in ipairs({'partial','unknown'})do
            local s,key=executing();s=event(s,key,'outcome',{effect=effect,evidence_ref='partial-write'})
            local _,duplicate=O.accept(s,spec());assert.equals('duplicate',duplicate.status)
            for _,e in ipairs({{type='start'},{type='resolved'},{type='reconcile',resolved=true},
                {type='reconcile',effect='known',result_ref='r'}})do
                local unchanged,result=O.transition(s,key,e);assert.are_not.equals('accepted',result.status);assert.same(s,unchanged)
            end
            s=event(s,key,'reconcile',{effect='known',evidence_ref='verified-bytes',result_ref='reconciled'})
            local _,reuse=O.accept(s,spec());assert.equals('reuse',reuse.status);assert.equals('reconciled',reuse.result_ref)
        end
    end)
    it('refuses unbounded outcome references without changing effect evidence',function()
        local s,key=executing()
        for _,value in ipairs({{},function()end,string.rep('x',4097)})do
            local same,result=event(s,key,'outcome',{effect='unknown',evidence_ref='observed',result_ref=value})
            assert.equals('invalid',result.status);assert.same(s,same)
        end
    end)
    it('cancels only unstarted work and preserves running effect uncertainty',function()
        local s,key=accept();s=event(s,key,'cancel');assert.equals('cancelled_before_effect',O.get(s,key).status)
        local _,duplicate=O.accept(s,spec());assert.equals('duplicate',duplicate.status)
        s,key=executing();s=event(s,key,'cancel');assert.equals('executing',O.get(s,key).status)
        assert.is_true(O.get(s,key).cancel_requested)
    end)
    it('rejects unsafe and oversized inputs atomically',function()
        assert.has_error(function()O.new({max_argument_nodes=false})end)
        assert.has_error(function()O.new({max_records=math.huge})end)
        local cycle={};cycle.self=cycle
        local invalid={cycle,setmetatable({},{__index={}}),{fn=function()end},{n=0/0},{n=math.huge},{x=string.rep('x',100)}}
        for _,input in ipairs(invalid)do
            local initial=O.new({max_argument_bytes=32})
            local unchanged,result=O.accept(initial,spec({input=input}))
            assert.equals('invalid',result.status);assert.same(initial,unchanged)
        end
        local initial=O.new({max_argument_nodes=2});local unchanged,result=O.accept(initial,spec())
        assert.equals('invalid',result.status);assert.same(initial,unchanged)
        local s=accept({max_records=1});local same,full=O.accept(s,spec({call_id='other'}))
        assert.equals('capacity',full.status);assert.same(s,same)
        local _,duplicate=O.accept(s,spec());assert.equals('duplicate',duplicate.status)
    end)
    it('forgets only terminal effect records and leaves no tombstones',function()
        local s,key=executing();local unchanged,result=O.forget(s,key)
        assert.equals('unresolved',result.status);assert.same(s,unchanged)
        s=event(s,key,'outcome',{effect='unknown',evidence_ref='e'})
        unchanged,result=O.forget(s,key);assert.equals('unresolved',result.status);assert.same(s,unchanged)
        s=event(s,key,'reconcile',{effect='known',evidence_ref='e2',result_ref='r'})
        s,result=O.forget(s,key);assert.equals('forgotten',result.status);assert.equals(0,O.stats(s).records)
        assert.is_nil(O.get(s,key))
    end)
    it('matches an independent single-effect oracle across generated event histories',function()
        local seed=1701
        local function random(n)seed=(seed*48271)%2147483647;return seed%n+1 end
        for _=1,80 do
            local s,key=accept();local authorized,started,terminal=false,false,false;local starts=0
            for _=1,30 do
                local kind=({'authorize','start','outcome','cancel','resolved'})[random(5)]
                local e={type=kind,capability_ref='cap',effect='known',evidence_ref='e',result_ref='r'}
                local should_start=kind=='start' and authorized and not started and not terminal
                local next_state,result=O.transition(s,key,e)
                assert.equals(should_start,result.effect_start==true)
                if kind=='authorize' and not authorized and not started and not terminal then authorized=true
                elseif kind=='start' and authorized and not started and not terminal then started=true;starts=starts+1
                elseif kind=='outcome' and started and not terminal then terminal=true
                elseif kind=='cancel' and not started then terminal=true end
                if result.effect_start then assert.is_true(started);assert.equals(1,starts)end
                s=next_state
                assert.is_true(starts<=1)
                local _,duplicate=O.accept(s,spec());assert.are_not.equals('accepted',duplicate.status)
            end
        end
    end)
end)
