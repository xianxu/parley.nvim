-- Pure generation decisions. Opaque states retain scalar immutable blob IDs,
-- never editor coordinates, payload strings, IO handles or callback closures.
local M={}
local private=setmetatable({},{__mode='k'})
local function integer(n) return type(n)=='number' and n>=0 and n<=9007199254740991 and n%1==0 end
local function ref(v) return type(v)=='string' and #v>0 and #v<=256 end
local function identity(v) return ref(v) or integer(v) end
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
local function wrap(s) local handle={};private[handle]=s;return handle end
local function get(s) return assert(private[s],'invalid generation state') end
local function outstanding(s)
    local n=0;for _,op in pairs(s.operations) do if not op.resolved then n=n+1 end end;return n
end
local function emit(s,effects,kind,fields)
    s.serial=s.serial+1
    local e=fields or {};e.type=kind;e.id=s.generation..':'..s.serial
    e.epoch=s.epoch;e.generation=s.generation
    effects[#effects+1]=e;return e
end
local function staged(s)
    local bytes=s.inflight and s.inflight.item.bytes or 0
    for _,item in ipairs(s.queue) do bytes=bytes+item.bytes end
    return bytes,#s.queue+(s.inflight and 1 or 0)
end
local function phase(s) return s.phase=='paused' and s.resume_phase or s.phase end
local function advance(s,value)
    if s.phase=='paused' then s.resume_phase=value else s.phase=value end
end
local function writable(s,grant)
    if s.grant_status=='revoked' or s.phase=='stopping' or s.phase=='terminal' then return false end
    if grant==s.grant then return s.grant_status=='valid' and s.phase~='paused' end
    for _,child in ipairs(s.round and s.round.children or {}) do
        if child.grant==grant then return child.grant_status=='valid' end
    end
    return false
end
local function stop(s,effects,outcome)
    if s.phase=='stopping' then return end
    s.phase='stopping';s.outcome=outcome;s.grant_status='revoked'
    emit(s,effects,'revoke',{grant=s.grant})
    for _,item in ipairs(s.queue) do
        s.discarded_bytes=s.discarded_bytes+item.bytes
        emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq})
    end
    s.queue={}
    for _,operation in ipairs(s.operation_order) do
        if s.operations[operation] and not s.operations[operation].resolved then emit(s,effects,'cancel_operation',{operation=operation}) end
    end
end
local function child_by_grant(s,grant)
    for _,child in ipairs(s.round and s.round.children or {}) do if child.grant==grant then return child end end
end
local function revoke_child(s,effects,child)
    child.grant_status='revoked'
    if not child.started then child.resolved=true;child.outcome='cancelled_before_effect' end
    if s.phase~='paused' and s.phase~='stopping' then s.resume_phase=s.phase;s.phase='paused' end
    emit(s,effects,'revoke',{grant=child.grant})
    local op=s.operations[child.operation]
    if op and not op.resolved then emit(s,effects,'cancel_operation',{operation=child.operation}) end
    local kept={}
    for _,item in ipairs(s.queue) do
        if item.grant==child.grant then
            s.discarded_bytes=s.discarded_bytes+item.bytes
            emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq})
        else kept[#kept+1]=item end
    end
    s.queue=kept
end
local function operation(s,effects,kind,fields)
    local e=emit(s,effects,kind,fields)
    e.operation=e.id
    s.operations[e.operation]={kind=kind,next_seq=1}
    s.operation_order[#s.operation_order+1]=e.operation
    return e.operation
end
local function start_children(s,effects)
    local running=0
    for _,child in ipairs(s.round.children) do if child.started and not child.resolved then running=running+1 end end
    for _,child in ipairs(s.round.children) do
        if running>=4 then break end
        if not child.started and not child.resolved and child.grant_status=='valid' then
            child.started=true;running=running+1
            s.operations[child.operation]={kind='child',next_seq=1,grant=child.grant}
            s.operation_order[#s.operation_order+1]=child.operation
            emit(s,effects,'start_child',{operation=child.operation,round=s.round.id,grant=child.grant,
                call_id=child.call_id,arguments_ref=child.arguments_ref,capabilities_ref=s.capabilities_ref})
        end
    end
end
local function pump(s,effects)
    if s.phase=='stopping' then
        if outstanding(s)==0 and not s.inflight and not s.finalize_pending
            and not (s.round and s.round.reservation_pending) then
            s.phase='terminal';emit(s,effects,'terminal',{outcome=s.outcome,
                committed_bytes=s.committed_bytes,discarded_bytes=s.discarded_bytes})
        end
        return
    end
    if s.phase=='preparing' and s.input_ref and s.grant_status=='valid' then
        s.phase='requesting'
        s.attempt=operation(s,effects,'request',{input_ref=s.input_ref,capabilities_ref=s.capabilities_ref})
    end
    if not s.inflight then
        for i,item in ipairs(s.queue) do
            if writable(s,item.grant) then
                table.remove(s.queue,i)
                local e=emit(s,effects,'write',{operation=item.operation,grant=item.grant,blob_ref=item.blob_ref,
                    offset=item.offset,bytes=math.min(4096,item.bytes),seq=item.seq})
                s.inflight={id=e.id,item=item,bytes=e.bytes};break
            end
        end
    end
    local bytes=staged(s)
    if s.provider_failed and bytes==0 then
        stop(s,effects,'provider_failed')
        pump(s,effects)
        return
    end
    if s.round and s.round.prepared_input_ref and s.phase=='executing_tools'
        and bytes==0 and s.grant_status=='valid' then
        s.input_ref=s.round.prepared_input_ref;s.round=nil;s.phase='requesting'
        for id,op in pairs(s.operations) do if op.resolved then s.operations[id]=nil end end
        s.attempt=operation(s,effects,'request',{input_ref=s.input_ref,capabilities_ref=s.capabilities_ref})
    end
    if s.round and s.phase=='executing_tools' and bytes==0 and s.grant_status=='valid' then
        local round=s.round
        if not round.reserved and not round.reservation_pending then
            round.reservation_pending=true
            emit(s,effects,'reserve_round',{round=round.id,children=copy(round.children),grant=s.grant})
        elseif round.reserved then
            start_children(s,effects)
            local complete=outstanding(s)==0
            local results={}
            for i,child in ipairs(round.children) do
                if not child.resolved or child.outcome~='known' then complete=false end
                results[i]=child.result_ref
            end
            if complete and not round.join_pending then
                round.join_pending=true
                round.preparation=operation(s,effects,'continue_round',{round=round.id,result_refs=results,
                    input_seed_ref=s.input_seed_ref,dependencies_ref=s.dependencies_ref})
            end
        end
    end
    if s.phase=='finalizing' and bytes==0 and s.grant_status=='valid' then
        if not s.finalize_pending and not s.finalized then
            s.finalize_pending=emit(s,effects,'finalize',{grant=s.grant,exchange=s.exchange}).id
        elseif s.finalized and outstanding(s)==0 then
            s.phase='terminal';s.outcome='success'
            emit(s,effects,'terminal',{outcome='success',committed_bytes=s.committed_bytes,discarded_bytes=s.discarded_bytes})
        end
    end
end
function M.new(spec)
    for _,key in ipairs({'epoch','generation','exchange','grant'}) do assert(identity(spec[key]),'invalid '..key) end
    for _,key in ipairs({'input_seed_ref','dependencies_ref','capabilities_ref'}) do assert(ref(spec[key]),'invalid '..key) end
    local limits=spec.limits or {}
    local bytes,items=limits.staged_bytes or 1048576,limits.queued_items or 256
    assert(integer(bytes) and bytes>0 and bytes<=1048576,'invalid staged byte limit')
    assert(integer(items) and items>0 and items<=256,'invalid staged item limit')
    return wrap({epoch=spec.epoch,generation=spec.generation,exchange=spec.exchange,grant=spec.grant,
        input_seed_ref=spec.input_seed_ref,dependencies_ref=spec.dependencies_ref,capabilities_ref=spec.capabilities_ref,
        phase='preparing',grant_status='valid',serial=0,operations={},operation_order={},queue={},
        accepted_bytes=0,committed_bytes=0,discarded_bytes=0,limits={staged_bytes=bytes,queued_items=items}})
end
function M.snapshot(handle)
    local s=get(handle);local bytes,items=staged(s)
    local retained=0;for _ in pairs(s.operations) do retained=retained+1 end
    return {epoch=s.epoch,generation=s.generation,exchange=s.exchange,grant=s.grant,phase=s.phase,
        grant_status=s.grant_status,input_ref=s.input_ref,input_seed_ref=s.input_seed_ref,
        dependencies_ref=s.dependencies_ref,capabilities_ref=s.capabilities_ref,stale_input=s.stale_input or false,
        staged_bytes=bytes,staged_items=items,accepted_bytes=s.accepted_bytes,committed_bytes=s.committed_bytes,
        discarded_bytes=s.discarded_bytes,outstanding_operations=outstanding(s),retained_operations=retained,outcome=s.outcome,
        round=s.round and s.round.id,attempt=s.attempt}
end
function M.transition(handle,event)
    local old=get(handle)
    local function reject(reason) return handle,{accepted=false,reason=reason,effects={}} end
    if type(event)~='table' or event.epoch~=old.epoch or event.generation~=old.generation then return reject('identity') end
    if old.phase=='terminal' then return reject('terminal') end
    local s,effects=copy(old),{}
    local kind=event.type
    if kind=='start' then
        if s.started or s.phase~='preparing' then return reject('duplicate') end
        s.started=true
        s.preparation=operation(s,effects,'prepare',{input_seed_ref=s.input_seed_ref,dependencies_ref=s.dependencies_ref})
    elseif kind=='prepared' then
        if phase(s)~='preparing' or event.preparation~=s.preparation or not s.operations[event.preparation]
            or s.input_ref or not ref(event.input_ref) then return reject('preparation') end
        s.input_ref=event.input_ref
    elseif kind=='prepare_failed' then
        local current=event.preparation==s.preparation or s.round and event.preparation==s.round.preparation
        local owner=s.operations[event.preparation]
        if not current or not owner or owner.resolved or s.phase=='stopping' then return reject('preparation') end
        stop(s,effects,'prepare_failed')
    elseif kind=='output' then
        local owner=s.operations[event.operation]
        if not owner or (owner.kind~='request' and owner.kind~='child') or owner.complete or owner.resolved
            or s.phase=='stopping' then return reject('operation') end
        if not integer(event.seq) or event.seq~=owner.next_seq or not integer(event.bytes)
            or (event.bytes>0 and not ref(event.blob_ref)) then return reject('output') end
        owner.next_seq=owner.next_seq+1
        if event.bytes>0 then
            local bytes,items=staged(s)
            if bytes+event.bytes>s.limits.staged_bytes or items>=s.limits.queued_items then stop(s,effects,'overflow')
            else
                s.accepted_bytes=s.accepted_bytes+event.bytes
                s.queue[#s.queue+1]={operation=event.operation,grant=owner.grant or s.grant,
                    blob_ref=event.blob_ref,bytes=event.bytes,offset=0,seq=event.seq}
            end
        end
    elseif kind=='write_result' then
        local pending=s.inflight
        local status=event.status
        local attempted=event.attempted_bytes or (pending and pending.bytes)
        if not pending or event.write~=pending.id or not integer(event.committed_bytes)
            or not integer(attempted) or attempted<1 or attempted>pending.bytes
            or event.committed_bytes>attempted or (status~='applied' and status~='suspended'
                and status~='revoked' and status~='uncertain')
            or (status=='applied' and event.committed_bytes~=attempted) then return reject('receipt') end
        local item=pending.item;s.inflight=nil
        s.committed_bytes=s.committed_bytes+event.committed_bytes
        item.bytes=item.bytes-event.committed_bytes;item.offset=item.offset+event.committed_bytes
        local child=child_by_grant(s,item.grant)
        if status=='revoked' or status=='uncertain' then
            if child then
                if child.grant_status~='revoked' then revoke_child(s,effects,child) end
            else stop(s,effects,status) end
        end
        if s.phase=='stopping' or (child and child.grant_status=='revoked') then
            s.discarded_bytes=s.discarded_bytes+item.bytes
            emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq})
        else
            if item.bytes==0 then emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq}) end
            if item.bytes>0 then table.insert(s.queue,1,item) end
            if status=='suspended' then
                if item.grant==s.grant then s.grant_status='suspended'
                elseif child then child.grant_status='suspended' end
            end
        end
    elseif kind=='grant_suspended' or kind=='grant_resumed' or kind=='grant_revoked' then
        if s.grant_status=='revoked' then return reject('revoked') end
        local status=kind=='grant_suspended' and 'suspended' or 'valid'
        if event.grant~=s.grant then
            local child=child_by_grant(s,event.grant)
            if not child or child.grant_status=='revoked' then return reject('grant') end
            if kind=='grant_revoked' then revoke_child(s,effects,child)
            elseif child.grant_status==status then return reject('duplicate')
            else child.grant_status=status end
        elseif kind=='grant_revoked' then stop(s,effects,'revoked')
        elseif s.grant_status==status then return reject('duplicate')
        else s.grant_status=status end
    elseif kind=='input_changed' then
        if event.dependencies_ref~=s.dependencies_ref or s.stale_input then return reject('dependency') end
        s.stale_input=true
    elseif kind=='provider_failed' then
        local attempt=s.operations[event.attempt]
        if phase(s)~='requesting' or event.attempt~=s.attempt or not attempt or attempt.complete then return reject('attempt') end
        -- Transport failure ends admission, not already admitted output. Drain
        -- valid writes before failure retirement; human revocation still wins.
        attempt.complete=true;s.provider_failed=true;advance(s,'finalizing')
    elseif kind=='provider_complete' then
        local attempt=s.operations[event.attempt]
        if phase(s)~='requesting' or event.attempt~=s.attempt or not attempt or attempt.complete then return reject('attempt') end
        attempt.complete=true;advance(s,'finalizing')
    elseif kind=='round_declared' then
        local attempt=s.operations[event.attempt]
        if phase(s)~='requesting' or event.attempt~=s.attempt or not attempt or attempt.complete then return reject('attempt') end
        if type(event.calls)~='table' or #event.calls<1 or #event.calls>32 then stop(s,effects,'round_capacity')
        else
            local seen={}
            for i,call in ipairs(event.calls) do
                if call.index~=i or not ref(call.call_id) or not ref(call.arguments_ref) or seen[call.call_id] then
                    return reject('call declaration')
                end
                seen[call.call_id]=true
            end
            attempt.complete=true;advance(s,'executing_tools')
            s.serial=s.serial+1;local round={id=s.generation..':round:'..s.serial,children={}}
            for i,call in ipairs(event.calls) do
                local id=round.id..':child:'..i
                round.children[i]={operation=id,index=i,call_id=call.call_id,arguments_ref=call.arguments_ref,
                    call_block=id..':call',result_slot=id..':result'}
            end
            s.round=round
        end
    elseif kind=='round_reservation_failed' then
        local round=s.round
        if not round or event.round~=round.id or not round.reservation_pending then return reject('reservation') end
        if event.status~='cancelled' and event.status~='suspended' and event.status~='failed' then return reject('reservation status') end
        round.reservation_pending=false
        if s.phase~='stopping' then
            if event.status=='suspended' then s.grant_status='suspended'
            else stop(s,effects,'reservation_failed') end
        end
    elseif kind=='round_reserved' then
        local round=s.round
        if not round or event.round~=round.id or not round.reservation_pending or not ref(event.receipt_ref)
            or type(event.grants)~='table' or #event.grants~=#round.children then return reject('reservation') end
        local seen={}
        for _,grant in ipairs(event.grants) do
            if not identity(grant) or grant==s.grant or seen[grant] then return reject('child grant') end;seen[grant]=true
        end
        round.reservation_pending=false;round.reserved=true
        for i,child in ipairs(round.children) do child.grant=event.grants[i];child.grant_status='valid' end
        if s.phase=='stopping' then emit(s,effects,'revoke',{grant=s.grant}) end
    elseif kind=='cancel_child' then
        local child
        if s.round and event.round==s.round.id then
            for _,candidate in ipairs(s.round.children) do if candidate.operation==event.operation then child=candidate end end
        end
        if not child or not child.grant or child.grant_status=='revoked' or s.phase=='stopping' then return reject('child') end
        revoke_child(s,effects,child)
    elseif kind=='child_outcome' then
        local round=s.round;local found
        if round and event.round==round.id then for _,child in ipairs(round.children) do
            if child.operation==event.operation then found=child end
        end end
        if not found or not found.started or (found.outcome and not (found.outcome=='unknown' and event.outcome=='known'))
            or not ref(event.result_ref)
            or (event.outcome~='known' and event.outcome~='unknown' and event.outcome~='rejected' and event.outcome~='cancelled_before_effect') then return reject('child') end
        found.outcome=event.outcome;found.result_ref=event.result_ref
        if s.operations[event.operation] then s.operations[event.operation].complete=true end
        if event.outcome~='known' and s.phase~='stopping' and s.phase~='paused' then s.resume_phase=s.phase;s.phase='paused' end
    elseif kind=='round_prepared' then
        if (s.phase~='executing_tools' and s.phase~='paused') or not s.round or event.round~=s.round.id
            or not s.round.join_pending or s.round.prepared_input_ref or not ref(event.input_ref)
            or (event.preparation and event.preparation~=s.round.preparation) then return reject('round') end
        s.round.prepared_input_ref=event.input_ref
    elseif kind=='pause' then
        if s.phase=='stopping' or s.phase=='paused' then return reject('phase') end
        s.resume_phase=s.phase;s.phase='paused'
    elseif kind=='resume_validated' then
        if s.phase~='paused' or s.grant_status~='valid' or not ref(event.policy_ref) then return reject('resume') end
        s.phase=s.resume_phase;s.resume_phase=nil
    elseif kind=='operation_resolved' then
        local op=s.operations[event.operation]
        if not op or op.resolved then return reject('operation') end
        if op.kind=='child' then
            for _,child in ipairs(s.round.children) do
                if child.operation==event.operation and (not child.outcome or child.outcome=='unknown') then
                    return reject('unresolved child outcome')
                end
            end
        end
        op.resolved=true
        for i,id in ipairs(s.operation_order) do if id==event.operation then table.remove(s.operation_order,i);break end end
        for _,child in ipairs(s.round and s.round.children or {}) do
            if child.operation==event.operation then child.resolved=true end
        end
    elseif kind=='finalize_result' then
        if not s.finalize_pending or event.finalize~=s.finalize_pending then return reject('finalize') end
        s.finalize_pending=nil
        if event.status=='applied' then s.finalized=true else stop(s,effects,'finalize_failed') end
    elseif kind=='cancel' then
        if s.phase=='stopping' then return reject('duplicate') end
        stop(s,effects,'cancelled')
    else return reject('event') end
    pump(s,effects)
    return wrap(s),{accepted=true,admitted_bytes=s.accepted_bytes-old.accepted_bytes,effects=copy(effects)}
end
return M
