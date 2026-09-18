local loaded,G=pcall(require,'parley.generation')
local function spec(limits)
    return {epoch='e',generation='g',exchange='x',grant='grant',input_seed_ref='seed',
        dependencies_ref='deps',capabilities_ref='caps',limits=limits}
end
local function effect(result,kind)
    for _,e in ipairs(result.effects) do if e.type==kind then return e end end
end
local function send(state,event)
    event.epoch=event.epoch or 'e';event.generation=event.generation or 'g'
    return G.transition(state,event)
end
local function requesting(limits)
    local s,r=send(G.new(spec(limits)),{type='start'})
    local prep=effect(r,'prepare').operation
    s,r=send(s,{type='prepared',preparation=prep,input_ref='input'})
    local attempt=effect(r,'request').operation
    s=send(s,{type='operation_resolved',operation=prep})
    return s,attempt
end
local function output(s,a,seq,bytes)
    return send(s,{type='output',operation=a,seq=seq,blob_ref='blob'..seq,bytes=bytes})
end
local function effects(result,kind)
    local out={};for _,e in ipairs(result.effects) do if e.type==kind then out[#out+1]=e end end;return out
end
-- #266 M2: declare a round of `n` calls; returns the state, the result and the
-- child operations by call index (children start as soon as they are declared).
local function declare(s,a,n)
    local calls={};for i=1,n do calls[i]={index=i,call_id='c'..i,arguments_ref='args'..i} end
    local r;s,r=send(s,{type='round_declared',attempt=a,calls=calls})
    local children={}
    for _,e in ipairs(effects(r,'start_child')) do children[tonumber(e.call_id:sub(2))]=e.operation end
    return s,r,children,effect(r,'start_child') and effect(r,'start_child').round
end
-- Acknowledge the one in-flight tool block as written; returns the next one.
local function insert(s,r,status)
    local e=assert(effect(r,'insert_tool'),'no tool block in flight')
    local after;s,after=send(s,{type='inserted',insert=e.id,status=status or 'applied'})
    return s,after,e
end

describe('pure generation lifecycle',function()
    it('provides the reducer',function() assert.is_true(loaded,tostring(G)) end)
    if not loaded then return end

    it('owns preparation before effects and rejects late preparation after cancellation',function()
        local s=G.new(spec())
        local started,r=send(s,{type='start'})
        local prep=effect(r,'prepare').operation
        assert.equals('preparing',G.snapshot(s).phase)
        local stopped,cancel=send(started,{type='cancel'})
        assert.equals('stopping',G.snapshot(stopped).phase)
        assert.is_table(effect(cancel,'revoke'))
        assert.equals(prep,effect(cancel,'cancel_operation').operation)
        local late,result=send(stopped,{type='prepared',preparation=prep,input_ref='late'})
        assert.is_false(result.accepted);assert.same({},result.effects)
        assert.equals(stopped,late)
        local terminal,done=send(late,{type='operation_resolved',operation=prep})
        assert.equals('terminal',G.snapshot(terminal).phase)
        assert.is_table(effect(done,'terminal'))
        local duplicate,again=send(terminal,{type='operation_resolved',operation=prep})
        assert.equals(terminal,duplicate);assert.same({},again.effects)
    end)

    it('keeps state and emitted descriptors private and freezes input references',function()
        local s,a=requesting()
        local before=G.snapshot(s)
        before.phase='terminal';before.input_ref='other'
        local next,r=output(s,a,1,10)
        effect(r,'write').bytes=999
        assert.equals(0,G.snapshot(s).accepted_bytes)
        assert.equals(10,G.snapshot(next).staged_bytes)
        next=send(next,{type='input_changed',dependencies_ref='deps'})
        assert.is_true(G.snapshot(next).stale_input)
        assert.equals('input',G.snapshot(next).input_ref)
        local unchanged,bad=send(next,{type='input_changed',dependencies_ref='unrelated'})
        assert.equals(next,unchanged);assert.is_false(bad.accepted)
        assert.equals('requesting',G.snapshot(s).phase)
    end)

    it('accounts admitted output through partial receipts, suspension and retry offsets',function()
        local s,a=requesting()
        local r;s,r=output(s,a,1,10)
        local write=effect(r,'write')
        assert.equals(10,G.snapshot(s).staged_bytes)
        s=send(s,{type='grant_suspended',grant='grant'})
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=4,status='suspended'})
        local v=G.snapshot(s)
        assert.equals(10,v.accepted_bytes);assert.equals(4,v.committed_bytes);assert.equals(6,v.staged_bytes)
        assert.is_nil(effect(r,'write'))
        s,r=send(s,{type='grant_resumed',grant='grant'})
        write=effect(r,'write');assert.equals(4,write.offset);assert.equals(6,write.bytes)
        s=send(s,{type='write_result',write=write.id,committed_bytes=6,status='applied'})
        assert.equals(0,G.snapshot(s).staged_bytes)
        local same,again=send(s,{type='write_result',write=write.id,committed_bytes=6,status='applied'})
        assert.equals(s,same);assert.same({},again.effects)
    end)

    it('retains inflight bytes across revocation and records late committed receipts without replay',function()
        local s,a=requesting();local r;s,r=output(s,a,1,10)
        local write=effect(r,'write')
        s=output(s,a,2,7)
        s=send(s,{type='grant_revoked',grant='grant'})
        assert.equals(10,G.snapshot(s).staged_bytes)
        assert.equals(7,G.snapshot(s).discarded_bytes)
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=3,status='revoked'})
        assert.is_nil(effect(r,'write'))
        assert.equals(3,G.snapshot(s).committed_bytes)
        assert.equals(14,G.snapshot(s).discarded_bytes)
        assert.equals(0,G.snapshot(s).staged_bytes)
        local same,resume=send(s,{type='grant_resumed',grant='grant'})
        assert.equals(s,same);assert.is_false(resume.accepted)
        s=send(s,{type='operation_resolved',operation=a})
        assert.equals('terminal',G.snapshot(s).phase)
    end)

    it('caps aggregate queued plus inflight bytes and items, ignoring empty output',function()
        local s,a=requesting({staged_bytes=12,queued_items=2})
        local r;s,r=output(s,a,1,8)
        s=output(s,a,2,4)
        s=output(s,a,3,0)
        assert.equals(2,G.snapshot(s).staged_items)
        s,r=output(s,a,4,1)
        assert.equals('stopping',G.snapshot(s).phase)
        assert.equals('overflow',G.snapshot(s).outcome)
        assert.is_table(effect(r,'revoke'))
        assert.equals(12,G.snapshot(s).accepted_bytes)
        local t,b=requesting({staged_bytes=100,queued_items=2})
        t=send(t,{type='grant_suspended',grant='grant'})
        t=output(t,b,1,1);t=output(t,b,2,1);t=output(t,b,3,1)
        assert.equals('stopping',G.snapshot(t).phase)
        assert.equals(2,G.snapshot(t).discarded_bytes)
        local u,c=requesting()
        u=output(u,c,1,1048576);u=output(u,c,2,1)
        assert.equals('overflow',G.snapshot(u).outcome)
    end)

    it('flushes staged output before finalization and waits for transport resolution',function()
        local s,a=requesting();local r;s,r=output(s,a,1,5)
        local write=effect(r,'write')
        s,r=send(s,{type='provider_complete',attempt=a})
        -- #266 M1: this window now has a name. Complete-but-unwritten is `draining`,
        -- not `finalizing` with a non-empty queue — which is what let one bytes==0
        -- test stand for both "my writes landed" and "I may proceed".
        assert.equals('draining',G.snapshot(s).phase);assert.is_nil(effect(r,'finalize'))
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=5,status='applied'})
        assert.equals('finalizing',G.snapshot(s).phase)
        local final=effect(r,'finalize');assert.is_table(final)
        s=send(s,{type='finalize_result',finalize=final.id,status='applied'})
        assert.equals('finalizing',G.snapshot(s).phase)
        s,r=send(s,{type='operation_resolved',operation=a})
        assert.equals('terminal',G.snapshot(s).phase);assert.equals('success',effect(r,'terminal').outcome)
    end)

    it('does not issue requests while suspended and never substitutes preparation snapshots',function()
        local s,r=send(G.new(spec()),{type='start'});local prep=effect(r,'prepare').operation
        s=send(s,{type='grant_suspended',grant='grant'})
        s,r=send(s,{type='prepared',preparation=prep,input_ref='fixed'})
        assert.is_nil(effect(r,'request'))
        s,r=send(s,{type='grant_resumed',grant='grant'})
        assert.equals('fixed',effect(r,'request').input_ref)
    end)

    it('rejects wrong identities, out-of-order output and impossible receipts without effects',function()
        local s,a=requesting();local before=s
        local r;s,r=send(s,{type='output',operation=a,seq=1,blob_ref='b',bytes=1,epoch='wrong'})
        assert.equals(before,s);assert.is_false(r.accepted)
        s,r=output(s,a,2,1);assert.equals(before,s);assert.same({},r.effects)
        s,r=output(s,a,1,3);local write=effect(r,'write');before=s
        s,r=output(s,a,1,3);assert.equals(before,s)
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=4,status='applied'})
        assert.equals(before,s);assert.is_false(r.accepted)
        s,r=send(s,{type='invented'});assert.equals(before,s);assert.same({},r.effects)
    end)

    -- #266 M2: tools run as soon as they are declared; their blocks land one at a
    -- time in declared order — call 1, result 1, call 2, result 2 — whatever
    -- order the outcomes arrive in.
    it('starts every declared tool at once and writes their blocks in declared order',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,2)
        assert.equals(2,#effects(r,'start_child'),'execution never waits on a write')
        local e=effect(r,'insert_tool')
        assert.same({'call',1,'c1'},{e.kind,e.index,e.call_id})
        s=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='result2'})
        s=send(s,{type='operation_resolved',operation=children[2]})
        s,r=insert(s,r)
        assert.is_nil(effect(r,'insert_tool'),'result 2 arrived first but waits behind result 1')
        s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='result1'})
        local written={}
        while effect(r,'insert_tool') do
            local item;s,r,item=insert(s,r)
            written[#written+1]=item.kind..item.index..(item.result_ref and ':'..item.result_ref or '')
        end
        assert.same({'result1:result1','call2','result2:result2'},written)
        s,r=send(s,{type='operation_resolved',operation=children[1]})
        assert.is_nil(effect(r,'continue_round')) -- original provider still owned
        s,r=send(s,{type='operation_resolved',operation=a})
        local join=effect(r,'continue_round');assert.is_table(join)
        assert.same({'result1','result2'},join.result_refs)
        assert.equals('executing_tools',G.snapshot(s).phase)
        s,r=send(s,{type='round_prepared',round=round,input_ref='next-input'})
        assert.equals('next-input',effect(r,'request').input_ref)
    end)

    it('holds tool blocks while another generation holds the turn, but still runs the tools',function()
        local s,a=requesting()
        s=send(s,{type='turn',status='waiting'})
        local r;s,r=declare(s,a,2)
        assert.equals(2,#effects(r,'start_child'),'tools run without the turn')
        assert.is_nil(effect(r,'insert_tool'),'but write nothing without it')
        s,r=send(s,{type='turn',status='held'})
        assert.equals('call',effect(r,'insert_tool').kind)
    end)

    it('holds tool blocks behind the text staged before them',function()
        local s,a=requesting()
        local r;s,r=output(s,a,1,5)
        local text=effect(r,'write')
        s,r=declare(s,a,1)
        assert.is_not_nil(effect(r,'start_child'))
        assert.is_nil(effect(r,'insert_tool'),'a call block must not land ahead of the text before it')
        s,r=send(s,{type='write_result',write=text.id,committed_bytes=5,status='applied'})
        assert.equals('call',effect(r,'insert_tool').kind)
    end)

    it('stops when a tool block cannot be written',function()
        for status,outcome in pairs({revoked='revoked',uncertain='uncertain',failed='insert_failed'}) do
            local s,a=requesting()
            local r;s,r=declare(s,a,1)
            s=insert(s,r,status)
            assert.equals('stopping',G.snapshot(s).phase,status)
            assert.equals(outcome,G.snapshot(s).outcome,status)
        end
    end)

    it('reports a round\'s tools for presentation, cleanup counted apart from outcome',function()
        local s,a=requesting()
        local _,children,round;s,_,children,round=declare(s,a,2)
        assert.same({total=2,finished=0,settled=0},G.snapshot(s).tools)
        s=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='r1'})
        assert.same({total=2,finished=1,settled=0},G.snapshot(s).tools,'an outcome is not cleanup')
        s=send(s,{type='operation_resolved',operation=children[1]})
        assert.same({total=2,finished=1,settled=1},G.snapshot(s).tools)
    end)

    it('refuses output from a tool, which has no place of its own to write',function()
        local s,a=requesting()
        local _,children;s,_,children=declare(s,a,1)
        local unchanged,refused=output(s,children[1],1,3)
        assert.equals(s,unchanged);assert.is_false(refused.accepted)
    end)

    it('keeps a tool with an unknown outcome owned until its cleanup is positively resolved',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,1)
        s=insert(s,r)
        s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome='unknown',result_ref='uncertain'})
        s=insert(s,r)
        s,r=send(s,{type='operation_resolved',operation=a})
        assert.is_nil(effect(r,'continue_round'),'written, but the tool has not been cleaned up')
        s,r=send(s,{type='cancel'})
        assert.equals('stopping',G.snapshot(s).phase)
        assert.equals(children[1],effect(r,'cancel_operation').operation)
        assert.is_nil(effect(r,'terminal'))
    end)

    it('conserves independent byte accounting under seeded suspension and receipt histories',function()
        local seed=31
        local function random(n) seed=(seed*48271)%2147483647;return seed%n+1 end
        for _=1,25 do
            local s,a=requesting({staged_bytes=1024,queued_items=64})
            local accepted,committed=0,0
            local seq=0
            for _=1,40 do
                local count=random(20);seq=seq+1;accepted=accepted+count
                local r;s,r=output(s,a,seq,count)
                local write=effect(r,'write')
                assert.is_table(write)
                local first=random(count)-1
                s=send(s,{type='grant_suspended',grant='grant'})
                s=send(s,{type='write_result',write=write.id,committed_bytes=first,status='suspended'})
                committed=committed+first
                assert.equals(accepted-committed,G.snapshot(s).staged_bytes)
                s,r=send(s,{type='grant_resumed',grant='grant'});write=effect(r,'write')
                s=send(s,{type='write_result',write=write.id,committed_bytes=count-first,status='applied'})
                committed=committed+count-first
                assert.equals(accepted,G.snapshot(s).accepted_bytes)
                assert.equals(committed,G.snapshot(s).committed_bytes)
                assert.equals(0,G.snapshot(s).staged_bytes)
            end
        end
    end)
    it('accepts every completion, receipt and transport-resolution ordering without early terminal',function()
        local permutations={{1,2,3},{1,3,2},{2,1,3},{2,3,1},{3,1,2},{3,2,1}}
        for _,order in ipairs(permutations) do
            local s,a=requesting();local r;s,r=output(s,a,1,5)
            local write=effect(r,'write').id
            local events={{type='provider_complete',attempt=a},
                {type='write_result',write=write,committed_bytes=5,status='applied'},
                {type='operation_resolved',operation=a}}
            local completed,received,resolved,finalized=false,false,false,false
            for _,index in ipairs(order) do
                s,r=send(s,events[index]);assert.is_true(r.accepted)
                completed=completed or index==1;received=received or index==2;resolved=resolved or index==3
                local final=effect(r,'finalize')
                if final then
                    assert.is_true(completed and received)
                    s=send(s,{type='finalize_result',finalize=final.id,status='applied'});finalized=true
                end
                assert.equals(completed and received and resolved and finalized,G.snapshot(s).phase=='terminal')
            end
            assert.equals('terminal',G.snapshot(s).phase)
        end
    end)

    it('keeps preparation readiness independent from preparation handle cleanup order',function()
        local s,r=send(G.new(spec()),{type='start'});local prep=effect(r,'prepare').operation
        s=send(s,{type='operation_resolved',operation=prep})
        s,r=send(s,{type='prepared',preparation=prep,input_ref='fixed'})
        assert.is_true(r.accepted);assert.is_table(effect(r,'request'))
    end)

    -- #266 M2 (operator, 2026-09-18): a failed call is written as its error
    -- result and the round goes on, so the model can try another way. Nothing
    -- pauses, and the calls behind it are not held.
    for _,failure in ipairs({'unknown','rejected','cancelled_before_effect'}) do
        it('writes a '..failure..' outcome as its result and continues without pausing',function()
            local s,a=requesting()
            local r,children,round;s,r,children,round=declare(s,a,2)
            s=insert(s,r)
            s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome=failure,result_ref='failed1'})
            assert.is_nil(effect(r,'release_turn'),'a failed call keeps the turn')
            assert.equals('executing_tools',G.snapshot(s).phase)
            local e=effect(r,'insert_tool');assert.same({'result',1,'failed1'},{e.kind,e.index,e.result_ref})
            s,r=insert(s,r)
            assert.equals('call',effect(r,'insert_tool').kind,'the calls behind it are not held')
            s=insert(s,r)
            s,r=send(s,{type='operation_resolved',operation=children[1]})
            assert.is_true(r.accepted,'a failed call resolves on cleanup, whatever its outcome')
            s,r=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='result2'})
            s=insert(s,r)
            s=send(s,{type='operation_resolved',operation=children[2]})
            s,r=send(s,{type='operation_resolved',operation=a})
            assert.same({'failed1','result2'},effect(r,'continue_round').result_refs)
        end)
    end

    it('lets an unknown outcome be confirmed only until its result is on its way',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,2)
        local call1=effect(r,'insert_tool')
        s=send(s,{type='child_outcome',round=round,operation=children[2],outcome='unknown',result_ref='u2'})
        s,r=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='k2'})
        assert.is_true(r.accepted,'confirmed before its slot is reached')
        s=send(s,{type='inserted',insert=call1.id,status='applied'})
        s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome='unknown',result_ref='u1'})
        assert.equals('u1',effect(r,'insert_tool').result_ref)
        local held,refused=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='k1'})
        assert.is_false(refused.accepted,'its result is already on its way to the transcript')
        assert.equals(s,held)
        s,r=insert(s,r) -- result 1, as unknown
        held,refused=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='k1'})
        assert.is_false(refused.accepted,'an outcome is final once written')
        s,r=insert(s,r) -- call 2
        assert.equals('k2',effect(r,'insert_tool').result_ref,'the confirmation came in time, so it is what lands')
        held,refused=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='late'})
        assert.is_false(refused.accepted,'only unknown may be confirmed, and only once')
    end)

    it('bounds writes to the editor slice while retaining aggregate staging credit',function()
        local s,a=requesting();local r;s,r=output(s,a,1,10000)
        local committed=0
        while committed<10000 do
            local write=effect(r,'write');assert.is_true(write.bytes<=4096)
            assert.equals(committed,write.offset)
            assert.equals(10000-committed,G.snapshot(s).staged_bytes)
            committed=committed+write.bytes
            s,r=send(s,{type='write_result',write=write.id,committed_bytes=write.bytes,status='applied'})
        end
        assert.equals(10000,G.snapshot(s).committed_bytes)
        assert.equals(0,G.snapshot(s).staged_bytes)
    end)

    it('releases each admitted blob exactly once after writes or cancellation',function()
        local s,a=requesting();local r;s,r=output(s,a,1,8);local write=effect(r,'write')
        s=output(s,a,2,3)
        s,r=send(s,{type='cancel'})
        assert.equals('blob2',effect(r,'release_blob').blob_ref)
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=2,status='revoked'})
        assert.equals('blob1',effect(r,'release_blob').blob_ref)
        local _,again=send(s,{type='write_result',write=write.id,committed_bytes=2,status='revoked'})
        assert.is_nil(effect(again,'release_blob'))
    end)

    it('runs at most four tools at once and starts the next as one is cleaned up',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,5)
        assert.equals(4,#effects(r,'start_child'))
        s=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='r1'})
        s,r=send(s,{type='operation_resolved',operation=children[1]})
        assert.equals('c5',effect(r,'start_child').call_id,'cleanup, not writing, frees a slot')
    end)

    it('waits for an in-flight tool block before terminal and resolves provider failure without orphaned work',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,1)
        local block=effect(r,'insert_tool')
        -- A hard stop (revocation): a user's Stop would write the round out (M3).
        s=send(s,{type='grant_revoked',grant='grant'})
        s=send(s,{type='operation_resolved',operation=a})
        s=send(s,{type='child_outcome',round=round,operation=children[1],outcome='cancelled_before_effect',result_ref='x'})
        s=send(s,{type='operation_resolved',operation=children[1]})
        assert.equals('stopping',G.snapshot(s).phase,'the block in flight is still owned')
        s,r=send(s,{type='inserted',insert=block.id,status='failed'})
        assert.equals('terminal',G.snapshot(s).phase);assert.is_table(effect(r,'terminal'))
        local t,b=requesting();t=send(t,{type='provider_failed',attempt=b})
        assert.equals('stopping',G.snapshot(t).phase)
        t=send(t,{type='operation_resolved',operation=b})
        assert.equals('terminal',G.snapshot(t).phase)
    end)

    it('uses scalar document identities and validates configured hard ceilings',function()
        local input=spec();input.epoch=1;input.generation=2;input.exchange=3;input.grant=4
        local s,r=G.transition(G.new(input),{type='start',epoch=1,generation=2})
        assert.is_true(r.accepted);assert.equals(1,G.snapshot(s).epoch)
        for _,limits in ipairs({{staged_bytes=1048577},{queued_items=257},{queued_items=0},{staged_bytes=math.huge}}) do
            assert.has_error(function() G.new(spec(limits)) end)
        end
    end)

    it('preserves terminal eligibility through all cancellation and receipt orderings',function()
        for _,order in ipairs({{1,2,3},{1,3,2},{2,1,3},{2,3,1},{3,1,2},{3,2,1}}) do
            local s,a=requesting();local r;s,r=output(s,a,1,9)
            local write=effect(r,'write').id
            local events={{type='cancel'},{type='write_result',write=write,committed_bytes=9,status='applied'},
                {type='operation_resolved',operation=a}}
            local cancelled,received,resolved=false,false,false
            local seen={}
            for _,index in ipairs(order) do
                s,r=send(s,events[index]);assert.is_true(r.accepted)
                for _,e in ipairs(r.effects) do assert.is_nil(seen[e.id]);seen[e.id]=true end
                cancelled=cancelled or index==1;received=received or index==2;resolved=resolved or index==3
                assert.equals(cancelled and received and resolved,G.snapshot(s).phase=='terminal')
                local v=G.snapshot(s)
                assert.equals(v.accepted_bytes,v.committed_bytes+v.discarded_bytes+v.staged_bytes)
            end
        end
    end)

    it('refuses excess round fanout before launching or writing anything',function()
        local s,a=requesting();local calls={}
        for i=1,33 do calls[i]={index=i,call_id='c'..i,arguments_ref='a'} end
        local r;s,r=send(s,{type='round_declared',attempt=a,calls=calls})
        assert.equals('stopping',G.snapshot(s).phase)
        assert.is_nil(effect(r,'insert_tool'));assert.is_nil(effect(r,'start_child'))
    end)

    it('owns asynchronous continuation preparation and holds its result through suspension',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,1)
        s=insert(s,r)
        s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='result'})
        s=insert(s,r)
        s=send(s,{type='operation_resolved',operation=children[1]})
        s,r=send(s,{type='operation_resolved',operation=a})
        local preparation=effect(r,'continue_round').operation
        assert.is_string(preparation)
        local failed,failure=send(s,{type='prepare_failed',preparation=preparation})
        assert.is_true(failure.accepted)
        assert.equals('stopping',G.snapshot(failed).phase)
        failed=send(failed,{type='operation_resolved',operation=preparation})
        assert.equals('terminal',G.snapshot(failed).phase)
        local cancelled,cancel=send(s,{type='cancel'})
        assert.equals('stopping',G.snapshot(cancelled).phase)
        assert.equals(preparation,effect(cancel,'cancel_operation').operation)
        cancelled=send(cancelled,{type='operation_resolved',operation=preparation})
        assert.equals('terminal',G.snapshot(cancelled).phase)
        s=send(s,{type='grant_suspended',grant='grant'})
        s,r=send(s,{type='round_prepared',round=round,input_ref='fixed-round'})
        assert.is_true(r.accepted);assert.is_nil(effect(r,'request'))
        s,r=send(s,{type='grant_resumed',grant='grant'})
        assert.equals('fixed-round',effect(r,'request').input_ref)
    end)

    it('bounds continuation admission while earlier preparation handles remain unresolved',function()
        local s,r=send(G.new(spec()),{type='start'});local prep=effect(r,'prepare').operation
        s,r=send(s,{type='prepared',preparation=prep,input_ref='input'});local a=effect(r,'request').operation
        local children,round;s,r,children,round=declare(s,a,1)
        s=insert(s,r)
        s,r=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='r'})
        s=insert(s,r)
        s=send(s,{type='operation_resolved',operation=children[1]})
        s,r=send(s,{type='operation_resolved',operation=a});assert.is_nil(effect(r,'continue_round'))
        s,r=send(s,{type='operation_resolved',operation=prep});assert.is_table(effect(r,'continue_round'))
    end)

    it('records readiness and provider completion while paused without admitting continuation',function()
        local s,r=send(G.new(spec()),{type='start'});local prep=effect(r,'prepare').operation
        s=send(s,{type='pause'})
        s,r=send(s,{type='prepared',preparation=prep,input_ref='fixed'})
        assert.is_true(r.accepted);assert.is_nil(effect(r,'request'))
        s,r=send(s,{type='resume_validated',policy_ref='resume'})
        local a=effect(r,'request').operation
        s=send(s,{type='pause'})
        s,r=send(s,{type='provider_complete',attempt=a})
        assert.is_true(r.accepted);assert.is_nil(effect(r,'finalize'))
        s,r=send(s,{type='resume_validated',policy_ref='resume2'})
        assert.is_table(effect(r,'finalize'))
    end)

    it('accounts a smaller applied editor slice without inventing grant suspension',function()
        local s,a=requesting();local r;s,r=output(s,a,1,4096)
        local write=effect(r,'write')
        s,r=send(s,{type='write_result',write=write.id,attempted_bytes=255,committed_bytes=255,status='applied'})
        assert.is_true(r.accepted)
        assert.equals('valid',G.snapshot(s).grant_status)
        assert.equals(3841,G.snapshot(s).staged_bytes)
        local next_write=effect(r,'write');assert.equals(255,next_write.offset);assert.equals(3841,next_write.bytes)
        local prior=s
        s,r=send(s,{type='write_result',write=next_write.id,attempted_bytes=10,committed_bytes=11,status='suspended'})
        assert.equals(prior,s);assert.is_false(r.accepted)
    end)

    it('bounds retained operation records across one hundred completed tool rounds',function()
        local s,a=requesting()
        local identities={}
        for index=1,100 do
            local r,children,round;s,r,children,round=declare(s,a,1)
            local child=children[1]
            assert.is_nil(identities[child]);identities[child]=true
            s=insert(s,r)
            s,r=send(s,{type='child_outcome',round=round,operation=child,outcome='known',result_ref='r'..index})
            s=insert(s,r)
            s=send(s,{type='operation_resolved',operation=child})
            s,r=send(s,{type='operation_resolved',operation=a})
            local prep=effect(r,'continue_round').operation
            assert.is_number(G.snapshot(s).retained_operations)
            assert.is_true(G.snapshot(s).retained_operations<=4)
            s=send(s,{type='operation_resolved',operation=prep})
            s,r=send(s,{type='round_prepared',round=round,input_ref='input'..index})
            a=effect(r,'request').operation
            assert.equals(1,G.snapshot(s).retained_operations)
            local same,duplicate=send(s,{type='operation_resolved',operation=child})
            assert.equals(s,same);assert.is_false(duplicate.accepted);assert.same({},duplicate.effects)
        end
    end)

    it('drains admitted bytes after provider failure while rejecting late output',function()
        local s,a=requesting();local r;s,r=output(s,a,1,10)
        local first=effect(r,'write')
        s=output(s,a,2,7)
        s,r=send(s,{type='provider_failed',attempt=a})
        assert.is_nil(effect(r,'revoke'))
        assert.equals(17,G.snapshot(s).staged_bytes)
        local unchanged,rejected=output(s,a,3,5)
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s=send(s,{type='operation_resolved',operation=a})
        s,r=send(s,{type='write_result',write=first.id,committed_bytes=10,status='applied'})
        local second=effect(r,'write');assert.is_table(second)
        s,r=send(s,{type='write_result',write=second.id,committed_bytes=7,status='applied'})
        assert.equals('terminal',G.snapshot(s).phase)
        assert.equals('provider_failed',G.snapshot(s).outcome)
        assert.equals(17,G.snapshot(s).committed_bytes)
        assert.equals(0,G.snapshot(s).discarded_bytes)
        assert.is_nil(effect(r,'finalize'))
    end)
    it('lets human revocation stop a failed provider drain without replay',function()
        local s,a=requesting();local r;s,r=output(s,a,1,10)
        local write=effect(r,'write')
        s=output(s,a,2,7)
        s=send(s,{type='provider_failed',attempt=a})
        s=send(s,{type='grant_revoked',grant='grant'})
        s=send(s,{type='write_result',write=write.id,committed_bytes=0,status='revoked'})
        s=send(s,{type='operation_resolved',operation=a})
        assert.equals('terminal',G.snapshot(s).phase)
        assert.equals(17,G.snapshot(s).discarded_bytes)
        assert.equals(0,G.snapshot(s).committed_bytes)
    end)

    it('transfers child supervision only while stopping without inventing a known outcome',function()
        local s,a=requesting()
        local r,children;s,r,children=declare(s,a,1)
        local child=children[1]
        s=insert(s,r)
        local unchanged,rejected=send(s,{type='operation_supervised',operation=child})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s=send(s,{type='operation_resolved',operation=a});s=send(s,{type='grant_revoked',grant='grant'})
        unchanged,rejected=send(s,{type='operation_resolved',operation=child,supervised=true})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s,r=send(s,{type='operation_supervised',operation=child})
        assert.is_true(r.accepted);assert.equals('terminal',G.snapshot(s).phase)
        local saved=G.snapshot(s).supervised_children[child]
        assert.equals('unknown',saved.outcome);assert.equals(0,G.snapshot(s).outstanding_operations)
        assert.is_nil(effect(r,'continue_round'))
    end)
    it('keeps transferred unknown evidence frozen while sibling cleanup is pending',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,2)
        local first=children[1]
        s=insert(s,r)
        s,r=send(s,{type='child_outcome',round=round,operation=first,outcome='unknown',result_ref='uncertain'})
        s,r=insert(s,r) -- result 1, written as unknown
        s=insert(s,r) -- call 2
        s=send(s,{type='grant_revoked',grant='grant'})
        local unchanged,rejected=send(s,{type='operation_supervised',operation=a})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s=send(s,{type='operation_resolved',operation=a})
        s,r=send(s,{type='operation_supervised',operation=first});assert.is_true(r.accepted)
        assert.equals('stopping',G.snapshot(s).phase)
        unchanged,rejected=send(s,{type='child_outcome',round=round,operation=first,outcome='known',result_ref='late'})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        assert.equals('uncertain',G.snapshot(s).supervised_children[first].result_ref)
        s=send(s,{type='operation_supervised',operation=children[2]})
        assert.equals('terminal',G.snapshot(s).phase)
    end)

    -- #266 M3 (operator): Stop during a tool round writes the round out. Every
    -- running tool is cancelled, none starts, and each pair lands in order — a
    -- tool with an outcome by the time the walk reaches it is written as is, one
    -- without is recorded as cancelled by the user. Then the generation stops.
    local function blocks(s,r)
        local out={}
        while effect(r,'insert_tool') do
            local e;s,r,e=insert(s,r)
            out[#out+1]=e.kind..e.index..(e.result_ref and ':'..e.result_ref or '')..(e.cancelled and ':cancelled_'..e.cancelled or '')
        end
        return s,r,out
    end
    it('writes a stopped tool round out instead of dropping it',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,2)
        s,r=insert(s,r) -- call 1
        s=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='r2'})
        s,r=send(s,{type='cancel'})
        assert.equals('flushing',G.snapshot(s).phase)
        assert.is_nil(effect(r,'revoke'),'the answer keeps its grant to write the round');assert.is_nil(effect(r,'release_turn'))
        local cancelled={};for _,e in ipairs(effects(r,'cancel_operation')) do cancelled[e.operation]=true end
        assert.is_true(cancelled[children[1]],'a running tool is cancelled')
        local written;s,r,written=blocks(s,r)
        assert.same({'result1:cancelled_running','call2','result2:r2'},written)
        assert.equals('stopping',G.snapshot(s).phase);assert.equals('cancelled',G.snapshot(s).outcome)
        assert.is_not_nil(effect(r,'revoke'));assert.is_not_nil(effect(r,'release_turn'))
        for _,child in ipairs({children[1],children[2]}) do s,r=send(s,{type='operation_resolved',operation=child}) end
        s,r=send(s,{type='operation_resolved',operation=a})
        assert.equals('terminal',G.snapshot(s).phase)
    end)
    it('writes a tool that never started as cancelled before it ran, and starts none',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,5)
        s,r=insert(s,r)
        s,r=send(s,{type='cancel'})
        local first=effect(r,'insert_tool')
        local _,freed=send(s,{type='operation_resolved',operation=children[1]})
        assert.is_nil(effect(freed,'start_child'),'a freed slot starts nothing while flushing')
        s=send(s,{type='operation_resolved',operation=children[1]})
        s,r=send(s,{type='inserted',insert=first.id,status='applied'})
        local written;s,r,written=blocks(s,r)
        assert.equals('call5',written[#written-1]);assert.equals('result5:cancelled_queued',written[#written])
    end)
    it('writes an outcome that arrives during the flush as it is',function()
        local s,a=requesting()
        local r,children,round;s,r,children,round=declare(s,a,2)
        s,r=insert(s,r)
        s,r=send(s,{type='cancel'})
        local first=effect(r,'insert_tool');assert.equals(true,first.cancelled=='running')
        s=send(s,{type='child_outcome',round=round,operation=children[2],outcome='known',result_ref='late'})
        s,r=send(s,{type='inserted',insert=first.id,status='applied'})
        local written;s,r,written=blocks(s,r)
        assert.same({'call2','result2:late'},written)
        local _,refused=send(s,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='too-late'})
        assert.is_false(refused.accepted,'a cancelled call\'s later outcome changes nothing')
    end)
    it('keeps its place behind another answer and writes the round when the turn arrives',function()
        local s,a=requesting()
        local r;s,r=declare(s,a,1)
        s,r=insert(s,r)
        s=send(s,{type='turn',status='waiting'})
        s,r=send(s,{type='cancel'})
        assert.equals('flushing',G.snapshot(s).phase)
        assert.is_nil(effect(r,'release_turn'),'it keeps its place in line');assert.is_nil(effect(r,'insert_tool'))
        s,r=send(s,{type='turn',status='held'})
        local written;s,r,written=blocks(s,r)
        assert.same({'result1:cancelled_running'},written)
        assert.equals('stopping',G.snapshot(s).phase)
    end)
    it('drops the rest on a second Stop, and stops on revocation or overflow',function()
        for _,ev in ipairs({{type='cancel'},{type='grant_revoked',grant='grant'},{type='cancel',reason='overflow'}}) do
            local s,a=requesting()
            local r;s,r=declare(s,a,2)
            s=insert(s,r);s=send(s,{type='cancel'})
            assert.equals('flushing',G.snapshot(s).phase)
            s,r=send(s,ev)
            assert.equals('stopping',G.snapshot(s).phase,ev.type..(ev.reason or ''))
            assert.is_not_nil(effect(r,'revoke'))
        end
    end)
    it('stops at once when Stop lands outside a tool round or after the round is written',function()
        local s=requesting();s=send(s,{type='cancel'})
        assert.equals('stopping',G.snapshot(s).phase,'streaming text: unchanged')
        local t,a=requesting()
        local r,children,round;t,r,children,round=declare(t,a,1)
        t,r=insert(t,r)
        t,r=send(t,{type='child_outcome',round=round,operation=children[1],outcome='known',result_ref='r1'})
        t=insert(t,r)
        t=send(t,{type='cancel'})
        assert.equals('stopping',G.snapshot(t).phase,'every block written: nothing to flush')
        local o,b=requesting();local r2;o,r2=declare(o,b,1);o=insert(o,r2)
        o=send(o,{type='cancel',reason='overflow'})
        assert.equals('stopping',G.snapshot(o).phase,'an overflow is not a Stop')
    end)
    it('accepts supervision while flushing and writes that tool as cancelled while running',function()
        local s,a=requesting()
        local r,children;s,r,children=declare(s,a,1)
        local call1=effect(r,'insert_tool')
        s=send(s,{type='cancel'})
        s,r=send(s,{type='operation_supervised',operation=children[1]})
        assert.is_true(r.accepted,'a cancelled tool may be handed to its supervisor while flushing')
        s,r=send(s,{type='inserted',insert=call1.id,status='applied'})
        local written;s,r,written=blocks(s,r)
        assert.same({'result1:cancelled_running'},written)
    end)

    -- #266 M1: the write turn and the draining phase.
    it('holds output while another generation holds the write turn',function()
        local s,a=requesting()
        local r
        s,r=send(s,{type='turn',status='waiting'})
        s,r=output(s,a,1,4)
        assert.is_nil(effect(r,'write'),'must not write without the turn')
        s,r=send(s,{type='turn',status='held'})
        assert.is_not_nil(effect(r,'write'),'writes as soon as the turn arrives')
    end)

    it('requests the turn on start and releases it when it pauses',function()
        local s,r=send(G.new(spec()),{type='start'})
        assert.is_not_nil(effect(r,'request_turn'),'start must request the turn')
        s,r=send(s,{type='pause'})
        assert.is_not_nil(effect(r,'release_turn'),'a pause must not hold the turn')
    end)

    -- The runner executes one effect per step and the machine may already report
    -- `terminal`; a release queued ahead of the revoke left the region held while
    -- the phase said it was free, so an immediate regenerate was refused 'overlap'
    -- (batch_lifecycle_spec's single retry cases).
    it('revokes its grant before yielding the turn when it stops',function()
        local s,a=requesting()
        s=send(s,{type='operation_resolved',operation=a})
        local _,r=send(s,{type='cancel'})
        local order={}
        for i,e in ipairs(r.effects) do order[e.type]=order[e.type] or i end
        assert.is_not_nil(order.revoke);assert.is_not_nil(order.release_turn)
        assert.is_true(order.revoke<order.release_turn,'revoke must precede release_turn')
    end)

    -- #266 (operator decision, 2026-09-17): a transient suspension keeps the turn.
    -- Suspension is routine — any edit the structure cannot classify at once —
    -- and releasing would queue the holder behind the next generation for that
    -- generation's whole lifetime, splitting one answer's history around another.
    it('holds the turn through a grant suspension and resumes without re-requesting',function()
        local s,a=requesting()
        local r
        s,r=send(s,{type='grant_suspended',grant='grant'})
        assert.is_nil(effect(r,'release_turn'),'a suspension must not yield the turn')
        s,r=output(s,a,1,4)
        assert.is_nil(effect(r,'write'),'nothing is written while suspended')
        s,r=send(s,{type='grant_resumed',grant='grant'})
        assert.is_nil(effect(r,'request_turn'),'it never gave the turn up')
        assert.is_not_nil(effect(r,'write'),'writing resumes on the proof')
    end)

    it('re-requests the turn when a paused generation resumes',function()
        local s=send(G.new(spec()),{type='start'})
        local r
        s,r=send(s,{type='pause'})
        s,r=send(s,{type='resume_validated',policy_ref='operator:test'})
        assert.is_not_nil(effect(r,'request_turn'),'resume must re-request the turn')
    end)

    -- The state the Spec names: complete but not yet written. Without it, the
    -- bytes==0 gates cannot tell a held generation from a streaming one.
    it('enters draining when the provider completes with output still staged',function()
        local s,a=requesting()
        s=send(s,{type='turn',status='waiting'})
        s=output(s,a,1,4)
        s=send(s,{type='provider_complete',attempt=a})
        assert.equals('draining',G.snapshot(s).phase)
        assert.is_true(G.snapshot(s).staged_bytes>0)
    end)

    it('leaves draining for finalizing once the staged output lands',function()
        local s,a=requesting()
        s=send(s,{type='turn',status='waiting'})
        s=output(s,a,1,4)
        s=send(s,{type='provider_complete',attempt=a})
        assert.equals('draining',G.snapshot(s).phase)
        local r
        s,r=send(s,{type='turn',status='held'})
        local w=effect(r,'write')
        s,r=send(s,{type='write_result',write=w.id,attempted_bytes=4,committed_bytes=4,status='applied'})
        assert.equals('finalizing',G.snapshot(s).phase)
    end)

    it('goes straight to finalizing when nothing is staged',function()
        local s,a=requesting()
        s=send(s,{type='provider_complete',attempt=a})
        assert.equals('finalizing',G.snapshot(s).phase)
    end)

    -- Cancellation, revocation and staleness must be expressible from draining —
    -- that is why it is a phase and not a boolean.
    it('expresses cancellation and revocation from draining',function()
        for _,ev in ipairs({{type='cancel'},{type='grant_revoked',grant='grant'}}) do
            local s,a=requesting()
            s=send(s,{type='turn',status='waiting'})
            s=output(s,a,1,4)
            s=send(s,{type='provider_complete',attempt=a})
            assert.equals('draining',G.snapshot(s).phase)
            s=send(s,ev)
            assert.equals('stopping',G.snapshot(s).phase,ev.type..' must be expressible from draining')
        end
    end)

    -- #266 Task 1.7: a held generation receives one output event per SSE delta.
    -- Consecutive output of one operation extends the last queued item, so what
    -- is held is bounded by bytes, not chunk count — and the queue each transition
    -- copies stays one item long.
    it('extends the last queued item of the same operation instead of queueing another',function()
        local s,a=requesting()
        local r
        s=send(s,{type='turn',status='waiting'})
        s,r=output(s,a,1,4)
        for seq=2,300 do
            s,r=send(s,{type='output',operation=a,seq=seq,blob_ref='blob1',bytes=4,extend=true})
            assert.is_true(r.accepted,'extension '..seq)
        end
        assert.equals(1,G.snapshot(s).staged_items);assert.equals(1200,G.snapshot(s).staged_bytes)
        s,r=send(s,{type='turn',status='held'})
        local w=effect(r,'write');assert.equals('blob1',w.blob_ref);assert.equals(1200,w.bytes)
    end)
    it('refuses to extend an item that is being written or belongs to something else',function()
        local s,a=requesting()
        local r
        s,r=output(s,a,1,4)
        assert.is_not_nil(effect(r,'write'),'the only item is now in flight')
        local _,refused=send(s,{type='output',operation=a,seq=2,blob_ref='blob1',bytes=4,extend=true})
        assert.is_false(refused.accepted,'an in-flight item cannot grow')
        s=send(s,{type='turn',status='waiting'})
        s=output(s,a,2,4)
        _,refused=send(s,{type='output',operation=a,seq=3,blob_ref='other',bytes=4,extend=true})
        assert.is_false(refused.accepted,'only the queued blob may grow')
    end)
    it('bounds a held answer by its bytes',function()
        -- queued_items=1: only extension can admit the second delta at all, so
        -- the overflow below can only come from the byte budget.
        local s,a=requesting({staged_bytes=16,queued_items=1})
        s=send(s,{type='turn',status='waiting'})
        s=output(s,a,1,8)
        s=send(s,{type='output',operation=a,seq=2,blob_ref='blob1',bytes=8,extend=true})
        assert.equals('requesting',G.snapshot(s).phase,'within budget')
        s=send(s,{type='output',operation=a,seq=3,blob_ref='blob1',bytes=1,extend=true})
        assert.equals('overflow',G.snapshot(s).outcome,'one byte past the budget')
    end)

    -- Both overflow sites — the runner's byte check before admission and the
    -- machine's own — must end the same way, so a caller can tell an overflow
    -- from a user's Stop.
    it('records a cancellation for overflow as an overflow',function()
        local s=requesting()
        s=send(s,{type='cancel',reason='overflow'})
        assert.equals('overflow',G.snapshot(s).outcome)
        local t=requesting()
        t=send(t,{type='cancel'})
        assert.equals('cancelled',G.snapshot(t).outcome)
    end)

    -- #266: the preparation gap is deferred to the generation's first write, so
    -- the provider request never waits on the turn (the Spec's option (b)) and a
    -- response cancelled before its first byte leaves the transcript untouched.
    local function deferred(limits)
        local s,r=send(G.new(spec(limits)),{type='start'})
        local prep=effect(r,'prepare').operation
        s,r=send(s,{type='prepared',preparation=prep,input_ref='input',gap=true})
        return s,effect(r,'request'),prep,r
    end
    local function all(results,kind)
        for _,r in ipairs(results) do if effect(r,kind) then return true end end
        return false
    end

    it('starts the request as soon as input is prepared, before the gap is written',function()
        local s,request,_,r=deferred()
        assert.is_not_nil(request,'the request must not wait for the gap')
        assert.equals('requesting',G.snapshot(s).phase)
        assert.equals('deferred',G.snapshot(s).gap)
        assert.is_nil(effect(r,'write_gap'),'nothing to write yet')
    end)

    it('writes the gap immediately before the first output, and the output only after it lands',function()
        local s,request=deferred()
        local r
        s,r=output(s,request.operation,1,4)
        assert.is_not_nil(effect(r,'write_gap'),'first output must bring the gap')
        assert.is_nil(effect(r,'write'),'output must not outrun its gap')
        assert.equals('writing',G.snapshot(s).gap)
        s,r=output(s,request.operation,2,4)
        assert.is_nil(effect(r,'write_gap'),'the gap is written exactly once')
        assert.is_nil(effect(r,'write'),'still not before the gap lands')
        s,r=send(s,{type='gap_result',status='applied'})
        assert.equals('none',G.snapshot(s).gap)
        assert.is_not_nil(effect(r,'write'),'output follows the gap')
    end)

    it('holds the gap while another generation holds the turn',function()
        local s,request=deferred()
        local r
        s=send(s,{type='turn',status='waiting'})
        s,r=output(s,request.operation,1,4)
        assert.is_nil(effect(r,'write_gap'),'no gap without the turn')
        s,r=send(s,{type='turn',status='held'})
        assert.is_not_nil(effect(r,'write_gap'),'the gap lands once the turn arrives')
        assert.is_nil(effect(r,'write'))
    end)

    it('never writes the gap when cancelled before any output',function()
        local s,request,prep=deferred()
        local results={}
        local r
        s,r=send(s,{type='cancel'});results[#results+1]=r
        s,r=send(s,{type='operation_resolved',operation=request.operation});results[#results+1]=r
        s,r=send(s,{type='operation_resolved',operation=prep});results[#results+1]=r
        assert.equals('terminal',G.snapshot(s).phase)
        assert.is_false(all(results,'write_gap'),'a response with nothing to say must not touch the transcript')
    end)

    -- M1 review I3: a provider that fails before its first byte has nothing to
    -- write, so the transcript — including a regenerated answer — stays as it was.
    it('never writes the gap when the provider fails before any output',function()
        local s,request=deferred()
        local r
        s,r=send(s,{type='provider_failed',attempt=request.operation})
        assert.is_nil(effect(r,'write_gap'),'a failure with nothing staged must not write the gap')
        assert.equals('stopping',G.snapshot(s).phase)
        assert.equals('provider_failed',G.snapshot(s).outcome)
    end)

    it('writes the gap before a tool round writes its first block, but starts its tools at once',function()
        local s,request=deferred()
        local r
        s,r=send(s,{type='round_declared',attempt=request.operation,
            calls={{index=1,call_id='c1',arguments_ref='args1'}}})
        assert.is_not_nil(effect(r,'start_child'),'tools do not wait for the gap')
        assert.is_not_nil(effect(r,'write_gap'))
        assert.is_nil(effect(r,'insert_tool'),'call blocks must not outrun the gap')
        s,r=send(s,{type='gap_result',status='applied'})
        assert.is_not_nil(effect(r,'insert_tool'))
    end)

    it('writes the gap before finalizing an answer that produced no output',function()
        local s,request=deferred()
        local r
        s,r=send(s,{type='provider_complete',attempt=request.operation})
        assert.equals('finalizing',G.snapshot(s).phase)
        assert.is_not_nil(effect(r,'write_gap'))
        assert.is_nil(effect(r,'finalize'),'finalize must not outrun the gap')
        s,r=send(s,{type='gap_result',status='applied'})
        assert.is_not_nil(effect(r,'finalize'))
    end)

    it('stops when the gap cannot be written',function()
        local s,request=deferred()
        s=output(s,request.operation,1,4)
        s=send(s,{type='gap_result',status='failed'})
        assert.equals('stopping',G.snapshot(s).phase)
        assert.equals('prepare_failed',G.snapshot(s).outcome)
    end)

    it('rejects a gap result that was never asked for',function()
        local s=deferred()
        local _,r=send(s,{type='gap_result',status='applied'})
        assert.is_false(r.accepted)
        local plain=requesting()
        _,r=send(plain,{type='gap_result',status='applied'})
        assert.is_false(r.accepted)
    end)
end)
