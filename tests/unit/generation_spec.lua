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
        assert.equals('finalizing',G.snapshot(s).phase);assert.is_nil(effect(r,'finalize'))
        s,r=send(s,{type='write_result',write=write.id,committed_bytes=5,status='applied'})
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

    it('reserves ordered round slots before child dispatch and joins recorded outcomes',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={
            {index=1,call_id='c2',arguments_ref='args2'},{index=2,call_id='c1',arguments_ref='args1'}}})
        local reserved=effect(r,'reserve_round')
        assert.is_nil(effect(r,'start_child'))
        assert.equals('c2',reserved.children[1].call_id);assert.equals('c1',reserved.children[2].call_id)
        local one,two=reserved.children[1].operation,reserved.children[2].operation
        s,r=send(s,{type='round_reserved',round=reserved.round,grants={'g1','g2'},receipt_ref='reservation'})
        assert.equals(one,effect(r,'start_child').operation)
        s=send(s,{type='child_outcome',round=reserved.round,operation=two,outcome='known',result_ref='result2'})
        s=send(s,{type='operation_resolved',operation=two})
        s=send(s,{type='child_outcome',round=reserved.round,operation=one,outcome='known',result_ref='result1'})
        s,r=send(s,{type='operation_resolved',operation=one})
        assert.is_nil(effect(r,'continue_round')) -- original provider still owned
        s,r=send(s,{type='operation_resolved',operation=a})
        local join=effect(r,'continue_round');assert.is_table(join)
        assert.same({'result1','result2'},join.result_refs)
        assert.equals('executing_tools',G.snapshot(s).phase)
        s,r=send(s,{type='round_prepared',round=reserved.round,input_ref='next-input'})
        assert.equals('next-input',effect(r,'request').input_ref)
    end)

    it('keeps unknown child work owned and prevents paused continuation',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='c',arguments_ref='args'}}})
        local round=effect(r,'reserve_round');local child=round.children[1].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'child-grant'},receipt_ref='r'})
        s=send(s,{type='child_outcome',round=round.round,operation=child,outcome='unknown',result_ref='uncertain'})
        s=send(s,{type='pause',reason='human child edit'})
        s=send(s,{type='operation_resolved',operation=a})
        s,r=send(s,{type='cancel'})
        assert.equals('stopping',G.snapshot(s).phase)
        assert.equals(child,effect(r,'cancel_operation').operation)
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

    it('revokes one child slot without cancelling its sibling or granting unknown-result resolution',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='a',arguments_ref='a'},
            {index=2,call_id='b',arguments_ref='b'}}})
        local round=effect(r,'reserve_round');local one,two=round.children[1].operation,round.children[2].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'g1','g2'},receipt_ref='r'})
        s,r=send(s,{type='grant_revoked',grant='g1'})
        assert.equals('paused',G.snapshot(s).phase);assert.equals('valid',G.snapshot(s).grant_status)
        assert.equals(one,effect(r,'cancel_operation').operation)
        for _,e in ipairs(r.effects) do assert.is_false(e.type=='cancel_operation' and e.operation==two) end
        s,r=output(s,two,1,3);assert.equals('g2',effect(r,'write').grant)
        s=send(s,{type='child_outcome',round=round.round,operation=one,outcome='unknown',result_ref='unknown'})
        local prior=s;s,r=send(s,{type='operation_resolved',operation=one})
        assert.equals(prior,s);assert.is_false(r.accepted)
        s,r=send(s,{type='child_outcome',round=round.round,operation=one,outcome='known',result_ref='resolved'})
        assert.is_true(r.accepted)
        s,r=send(s,{type='operation_resolved',operation=one});assert.is_true(r.accepted)
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

    it('admits four child effects only after reservation and drains queued children fairly',function()
        local s,a=requesting();local calls={}
        for i=1,5 do calls[i]={index=i,call_id='call'..i,arguments_ref='args'..i} end
        local r;s,r=send(s,{type='round_declared',attempt=a,calls=calls})
        local round=effect(r,'reserve_round')
        s,r=send(s,{type='round_reserved',round=round.round,grants={'1','2','3','4','5'},receipt_ref='r'})
        local started=0;for _,e in ipairs(r.effects) do if e.type=='start_child' then started=started+1 end end
        assert.equals(4,started)
        local first=round.children[1].operation
        s=send(s,{type='child_outcome',round=round.round,operation=first,outcome='known',result_ref='r1'})
        s,r=send(s,{type='operation_resolved',operation=first})
        assert.equals(round.children[5].operation,effect(r,'start_child').operation)
    end)

    it('allows cancelled reservation acknowledgements and provider failure to resolve without orphaned work',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='c',arguments_ref='a'}}})
        local round=effect(r,'reserve_round').round
        s,r=send(s,{type='cancel'});assert.equals(round,effect(r,'cancel_reservation').round)
        s,r=send(s,{type='cancel'});assert.is_nil(effect(r,'cancel_reservation'))
        s=send(s,{type='operation_resolved',operation=a})
        assert.equals('stopping',G.snapshot(s).phase)
        s,r=send(s,{type='round_reservation_failed',round=round,status='cancelled'})
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

    it('cancels a queued child before effect admission without cancelling running siblings',function()
        local s,a=requesting();local calls={}
        for i=1,5 do calls[i]={index=i,call_id='c'..i,arguments_ref='a'..i} end
        local r;s,r=send(s,{type='round_declared',attempt=a,calls=calls})
        local round=effect(r,'reserve_round')
        s=send(s,{type='round_reserved',round=round.round,grants={'g1','g2','g3','g4','g5'},receipt_ref='r'})
        s,r=send(s,{type='cancel_child',round=round.round,operation=round.children[5].operation})
        assert.is_true(r.accepted);assert.is_nil(effect(r,'cancel_operation'))
        assert.equals('paused',G.snapshot(s).phase)
        s=send(s,{type='child_outcome',round=round.round,operation=round.children[1].operation,outcome='known',result_ref='r1'})
        s=send(s,{type='operation_resolved',operation=round.children[1].operation})
        s,r=send(s,{type='resume_validated',policy_ref='explicit'})
        assert.is_nil(effect(r,'start_child'))
        assert.equals(4,G.snapshot(s).outstanding_operations) -- provider and three running siblings
    end)

    it('refuses excess round fanout before reserving or launching any child effect',function()
        local s,a=requesting();local calls={}
        for i=1,33 do calls[i]={index=i,call_id='c'..i,arguments_ref='a'} end
        local r;s,r=send(s,{type='round_declared',attempt=a,calls=calls})
        assert.equals('stopping',G.snapshot(s).phase)
        assert.is_nil(effect(r,'reserve_round'));assert.is_nil(effect(r,'start_child'))
    end)

    it('owns asynchronous continuation preparation and holds its result through suspension',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='c',arguments_ref='a'}}})
        local round=effect(r,'reserve_round');local child=round.children[1].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'child'},receipt_ref='r'})
        s=send(s,{type='child_outcome',round=round.round,operation=child,outcome='known',result_ref='result'})
        s=send(s,{type='operation_resolved',operation=child})
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
        s,r=send(s,{type='round_prepared',round=round.round,input_ref='fixed-round'})
        assert.is_true(r.accepted);assert.is_nil(effect(r,'request'))
        s,r=send(s,{type='grant_resumed',grant='grant'})
        assert.equals('fixed-round',effect(r,'request').input_ref)
    end)

    it('bounds continuation admission while earlier preparation handles remain unresolved',function()
        local s,r=send(G.new(spec()),{type='start'});local prep=effect(r,'prepare').operation
        s,r=send(s,{type='prepared',preparation=prep,input_ref='input'});local a=effect(r,'request').operation
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='c',arguments_ref='a'}}})
        local round=effect(r,'reserve_round');local child=round.children[1].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'child'},receipt_ref='r'})
        s=send(s,{type='child_outcome',round=round.round,operation=child,outcome='known',result_ref='r'})
        s=send(s,{type='operation_resolved',operation=child})
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
            local r;s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='c',arguments_ref='args'}}})
            local round=effect(r,'reserve_round');local child=round.children[1].operation
            assert.is_nil(identities[child]);identities[child]=true
            s=send(s,{type='round_reserved',round=round.round,grants={'slot'..index},receipt_ref='r'})
            s=send(s,{type='child_outcome',round=round.round,operation=child,outcome='known',result_ref='r'..index})
            s=send(s,{type='operation_resolved',operation=child})
            s,r=send(s,{type='operation_resolved',operation=a})
            local prep=effect(r,'continue_round').operation
            assert.is_number(G.snapshot(s).retained_operations)
            assert.is_true(G.snapshot(s).retained_operations<=4)
            s=send(s,{type='operation_resolved',operation=prep})
            s,r=send(s,{type='round_prepared',round=round.round,input_ref='input'..index})
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
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={{index=1,call_id='a',arguments_ref='args'}}})
        local round=effect(r,'reserve_round');local child=round.children[1].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'child'},receipt_ref='receipt'})
        local unchanged,rejected=send(s,{type='operation_supervised',operation=child})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s=send(s,{type='operation_resolved',operation=a});s=send(s,{type='cancel'})
        unchanged,rejected=send(s,{type='operation_resolved',operation=child,supervised=true})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s,r=send(s,{type='operation_supervised',operation=child})
        assert.is_true(r.accepted);assert.equals('terminal',G.snapshot(s).phase)
        local saved=G.snapshot(s).supervised_children[child]
        assert.equals('unknown',saved.outcome);assert.equals(0,G.snapshot(s).outstanding_operations)
        assert.is_nil(effect(r,'continue_round'))
    end)
    it('keeps transferred unknown evidence frozen while sibling cleanup is pending',function()
        local s,a=requesting();local r
        s,r=send(s,{type='round_declared',attempt=a,calls={
            {index=1,call_id='a',arguments_ref='a'},{index=2,call_id='b',arguments_ref='b'}}})
        local round=effect(r,'reserve_round');local first=round.children[1].operation
        s=send(s,{type='round_reserved',round=round.round,grants={'one','two'},receipt_ref='receipt'})
        s=send(s,{type='child_outcome',round=round.round,operation=first,outcome='unknown',result_ref='uncertain'})
        s=send(s,{type='cancel'})
        local unchanged,rejected=send(s,{type='operation_supervised',operation=a})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        s=send(s,{type='operation_resolved',operation=a})
        s,r=send(s,{type='operation_supervised',operation=first});assert.is_true(r.accepted)
        assert.equals('stopping',G.snapshot(s).phase)
        unchanged,rejected=send(s,{type='child_outcome',round=round.round,operation=first,outcome='known',result_ref='late'})
        assert.equals(s,unchanged);assert.is_false(rejected.accepted)
        assert.equals('uncertain',G.snapshot(s).supervised_children[first].result_ref)
        s=send(s,{type='operation_supervised',operation=round.children[2].operation})
        assert.equals('terminal',G.snapshot(s).phase)
    end)

end)
