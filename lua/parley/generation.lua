-- Pure generation decisions. Opaque states retain scalar immutable blob IDs,
-- never editor coordinates, payload strings, IO handles or callback closures.
local Seq=require('parley.tools.sequence')
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
--- #266: may this generation emit a write-producing effect (an output `write`,
--- `insert_tool` or `finalize`) now? One predicate for all three, so none of
--- them can outrun the other two's preconditions:
---   * the turn — an optimization, not the enforcement point: the coordinator
---     refuses a turnless write with 'waiting' regardless, but gating here stops a
---     queued generation emitting effects that would only park;
---   * the deferred preparation gap — it must land before anything else this
---     generation writes, or a call block or output lands inside the old answer's
---     region ahead of the replacement that clears it.
local function may_write(s)
    return s.turn_status=='held' and s.gap=='none'
end
--- Is one of the three write-producing emissions due? This is what pulls a
--- deferred gap in: the gap is written immediately before the generation's first
--- write, whatever kind that write turns out to be.
local function write_due(s,bytes)
    if #s.queue>0 then return true end
    if s.phase=='executing_tools' or s.phase=='flushing' then
        local round=s.round
        return round~=nil and not round.inserting and bytes==0
            and (Seq.next(round.seq)~=nil or s.phase=='flushing' and Seq.waiting(round.seq)~=nil)
    end
    return s.phase=='finalizing' and bytes==0 and not s.finalized
end
local function writable(s)
    if s.grant_status~='valid' or s.phase=='stopping' or s.phase=='terminal' or s.phase=='paused' then return false end
    return may_write(s)
end
--- Desire for the write turn. Tracked so a release is not emitted by a
--- generation that never asked, and a request is not emitted twice.
local function request_turn(s,effects)
    if s.turn_wanted then return end
    s.turn_wanted=true; emit(s,effects,'request_turn',{})
end
local function release_turn(s,effects)
    if not s.turn_wanted then return end
    s.turn_wanted=false; emit(s,effects,'release_turn',{})
end

local function stop(s,effects,outcome)
    if s.phase=='stopping' then return end
    s.phase='stopping';s.outcome=outcome;s.grant_status='revoked'
    -- Revoke before yielding the turn. The runner executes one effect per step,
    -- and the machine can report `terminal` in this same transition, so an effect
    -- queued ahead of the revoke keeps the region held while the phase already
    -- says it is free — an immediate regenerate is then refused as 'overlap'.
    emit(s,effects,'revoke',{grant=s.grant})
    release_turn(s,effects)
    for _,item in ipairs(s.queue) do
        s.discarded_bytes=s.discarded_bytes+item.bytes
        emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq})
    end
    s.queue={}
    for _,operation in ipairs(s.operation_order) do
        if s.operations[operation] and not s.operations[operation].resolved then emit(s,effects,'cancel_operation',{operation=operation}) end
    end
end
local function operation(s,effects,kind,fields)
    local e=emit(s,effects,kind,fields)
    e.operation=e.id
    s.operations[e.operation]={kind=kind,next_seq=1}
    s.operation_order[#s.operation_order+1]=e.operation
    return e.operation
end
--- Tools run as soon as they are declared (#266): execution is concurrent, only
--- their blocks are serialized. A slot frees when a tool is cleaned up, not when
--- its result is written, so a result held behind an earlier one never blocks
--- the next tool from starting.
local function start_children(s,effects)
    local running=0
    for _,child in ipairs(s.round.children) do if child.started and not child.resolved then running=running+1 end end
    for _,child in ipairs(s.round.children) do
        if running>=4 then break end
        if not child.started and not child.resolved then
            child.started=true;running=running+1
            s.operations[child.operation]={kind='child',next_seq=1}
            s.operation_order[#s.operation_order+1]=child.operation
            emit(s,effects,'start_child',{operation=child.operation,round=s.round.id,
                call_id=child.call_id,arguments_ref=child.arguments_ref,capabilities_ref=s.capabilities_ref})
        end
    end
end
--- The one tool block this round may write next, if any (tools/sequence.lua).
--- Held behind the text staged before the round, behind the turn and the gap
--- (`may_write`), and behind the block already in flight.
local function insert_next(s,effects,bytes)
    local round=s.round
    if round.inserting or bytes>0 or not may_write(s) then return end
    local item=Seq.next(round.seq)
    if not item then return end
    local child=round.children[item.index]
    local result=item.kind=='result'
    round.inserting={id=emit(s,effects,'insert_tool',{round=round.id,index=item.index,kind=item.kind,
        call_id=child.call_id,result_ref=result and not child.cancelled and child.result_ref or nil,
        cancelled=result and child.cancelled or nil}).id,item=item}
end
--- #266 M3 (operator): Stop during a tool round writes the round out rather than
--- dropping the pairs of tools that already ran. Every tool still running is
--- cancelled and none starts; the walk then writes each pair in declared order
--- (`flushing` in pump). The turn is kept: a stopped generation behind another
--- answer keeps its place and writes when the turn arrives.
local function flush(s,effects)
    s.phase='flushing'
    for _,child in ipairs(s.round.children) do
        local op=s.operations[child.operation]
        if child.started and not child.outcome and op and not op.resolved then
            emit(s,effects,'cancel_operation',{operation=child.operation})
        end
    end
end
--- A tool the walk reaches with no outcome is recorded as cancelled by the user:
--- `running` if it had started (it may have partly taken effect), else `queued`.
local function cancel_child(s,child)
    child.outcome='cancelled_by_user';child.cancelled=child.started and 'running' or 'queued'
    if not child.started then child.resolved=true end
    s.round.seq=Seq.outcome(s.round.seq,child.index)
end
local function pump(s,effects)
    if s.phase=='stopping' then
        if outstanding(s)==0 and not s.inflight and not s.finalize_pending
            and not (s.round and s.round.inserting) then
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
        local item=s.queue[1]
        if item and writable(s) then
            table.remove(s.queue,1)
            local e=emit(s,effects,'write',{operation=item.operation,grant=s.grant,blob_ref=item.blob_ref,
                offset=item.offset,bytes=math.min(4096,item.bytes),seq=item.seq})
            s.inflight={id=e.id,item=item,bytes=e.bytes}
        end
    end
    local bytes=staged(s)
    if s.provider_failed and bytes==0 then
        stop(s,effects,'provider_failed')
        pump(s,effects)
        return
    end
    -- After the failure check, not before: a provider that failed with nothing
    -- staged has nothing to write, so its gap must never be (M1 review I3).
    if s.gap=='deferred' and s.turn_status=='held' and s.grant_status=='valid' and s.phase~='paused'
        and write_due(s,bytes) then
        s.gap='writing';emit(s,effects,'write_gap',{grant=s.grant})
    end
    if s.round and s.round.prepared_input_ref and s.phase=='executing_tools'
        and bytes==0 and s.grant_status=='valid' then
        s.input_ref=s.round.prepared_input_ref;s.round=nil;s.phase='requesting'
        for id,op in pairs(s.operations) do if op.resolved then s.operations[id]=nil end end
        s.attempt=operation(s,effects,'request',{input_ref=s.input_ref,capabilities_ref=s.capabilities_ref})
    end
    if s.round and s.phase=='executing_tools' and s.grant_status=='valid' then
        local round=s.round
        start_children(s,effects)
        insert_next(s,effects,bytes)
        -- Every block written and every tool cleaned up — whatever its outcome:
        -- a failed call is written as its error result and the model reads it
        -- (operator, 2026-09-18), so nothing here waits on a known outcome.
        if Seq.complete(round.seq) and not round.inserting and outstanding(s)==0 and not round.join_pending then
            local results={}
            for i,child in ipairs(round.children) do results[i]=child.result_ref end
            round.join_pending=true
            round.preparation=operation(s,effects,'continue_round',{round=round.id,result_refs=results,
                input_seed_ref=s.input_seed_ref,dependencies_ref=s.dependencies_ref})
        end
    end
    if s.phase=='flushing' then
        local round=s.round
        if s.grant_status=='valid' then
            local index=not round.inserting and bytes==0 and may_write(s) and Seq.waiting(round.seq)
            if index then cancel_child(s,round.children[index]) end
            insert_next(s,effects,bytes)
        end
        if Seq.complete(round.seq) and not round.inserting then
            stop(s,effects,'cancelled');pump(s,effects);return
        end
    end
    if phase(s)=='draining' and bytes==0 and not s.provider_failed then advance(s,'finalizing') end
    if s.phase=='finalizing' and bytes==0 and s.grant_status=='valid' then
        if not s.finalize_pending and not s.finalized then
            if may_write(s) then s.finalize_pending=emit(s,effects,'finalize',{grant=s.grant,exchange=s.exchange}).id end
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
        phase='preparing',grant_status='valid',turn_status='held',gap='none',serial=0,operations={},operation_order={},queue={},
        accepted_bytes=0,committed_bytes=0,discarded_bytes=0,limits={staged_bytes=bytes,queued_items=items}})
end
--- O(1) phase, for per-sync callers that need nothing else: M.snapshot builds
--- a fresh table and walks the operations.
function M.phase(handle) return get(handle).phase end
--- The round's tools for presentation (#266 M2): how many are declared, how many
--- have an outcome, and how many are cleaned up — the round continues only once
--- every one is. The transcript shows only blocks that have landed, so this is
--- where a tool still running, or still cleaning up, stays visible.
local function tools(s)
    if not s.round then return nil end
    local finished,settled=0,0
    for _,child in ipairs(s.round.children) do
        if child.outcome then finished=finished+1 end
        if child.resolved then settled=settled+1 end
    end
    return {total=#s.round.children,finished=finished,settled=settled}
end
function M.snapshot(handle)
    local s=get(handle);local bytes,items=staged(s)
    local retained=0;for _ in pairs(s.operations) do retained=retained+1 end
    local supervised={}
    if s.phase=='stopping' or s.phase=='terminal'then
        for _,child in ipairs(s.round and s.round.children or {})do
            if child.supervised then supervised[child.operation]={outcome=child.outcome,result_ref=child.result_ref}end
        end
    end
    return {epoch=s.epoch,generation=s.generation,exchange=s.exchange,grant=s.grant,phase=s.phase,
        grant_status=s.grant_status,input_ref=s.input_ref,input_seed_ref=s.input_seed_ref,
        dependencies_ref=s.dependencies_ref,capabilities_ref=s.capabilities_ref,stale_input=s.stale_input or false,
        staged_bytes=bytes,staged_items=items,accepted_bytes=s.accepted_bytes,committed_bytes=s.committed_bytes,
        discarded_bytes=s.discarded_bytes,outstanding_operations=outstanding(s),retained_operations=retained,outcome=s.outcome,
        round=s.round and s.round.id,attempt=s.attempt,supervised_children=supervised,gap=s.gap,tools=tools(s)}
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
        request_turn(s,effects)
        s.preparation=operation(s,effects,'prepare',{input_seed_ref=s.input_seed_ref,dependencies_ref=s.dependencies_ref})
    elseif kind=='turn' then
        if event.status~='held' and event.status~='waiting' then return reject('turn status') end
        s.turn_status=event.status
    elseif kind=='prepared' then
        if phase(s)~='preparing' or event.preparation~=s.preparation or not s.operations[event.preparation]
            or s.input_ref or not ref(event.input_ref) or (event.gap~=nil and event.gap~=true) then return reject('preparation') end
        s.input_ref=event.input_ref
        -- #266: a preparation may report its input before writing its gap, so the
        -- request starts without waiting on the turn; the gap then lands just
        -- before this generation's first write.
        if event.gap then s.gap='deferred' end
    elseif kind=='gap_result' then
        if s.gap~='writing' or (event.status~='applied' and event.status~='failed') then return reject('gap') end
        s.gap='none'
        if event.status=='failed' then stop(s,effects,'prepare_failed') end
    elseif kind=='prepare_failed' then
        local current=event.preparation==s.preparation or s.round and event.preparation==s.round.preparation
        local owner=s.operations[event.preparation]
        if not current or not owner or owner.resolved or s.phase=='stopping' then return reject('preparation') end
        stop(s,effects,'prepare_failed')
    elseif kind=='output' then
        local owner=s.operations[event.operation]
        if not owner or owner.kind~='request' or owner.complete or owner.resolved
            or s.phase=='stopping' then return reject('operation') end
        if not integer(event.seq) or event.seq~=owner.next_seq or not integer(event.bytes)
            or (event.bytes>0 and not ref(event.blob_ref)) then return reject('output') end
        -- #266: `extend` grows the LAST queued item, which must be this operation's
        -- and carry this blob. A held generation receives one event per SSE
        -- delta; extending keeps it one item bounded by bytes (and keeps the queue
        -- every transition copies short). An item already in flight is not in the
        -- queue, so it can never grow under a write that has been issued.
        local tail=event.extend and s.queue[#s.queue]
        if event.extend and not (tail and tail.operation==event.operation and tail.blob_ref==event.blob_ref) then
            return reject('extend')
        end
        owner.next_seq=owner.next_seq+1
        if event.bytes>0 then
            local bytes,items=staged(s)
            if bytes+event.bytes>s.limits.staged_bytes or not tail and items>=s.limits.queued_items then stop(s,effects,'overflow')
            else
                s.accepted_bytes=s.accepted_bytes+event.bytes
                if tail then tail.bytes=tail.bytes+event.bytes
                else
                    s.queue[#s.queue+1]={operation=event.operation,
                        blob_ref=event.blob_ref,bytes=event.bytes,offset=0,seq=event.seq}
                end
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
        if status=='revoked' or status=='uncertain' then stop(s,effects,status) end
        if s.phase=='stopping' then
            s.discarded_bytes=s.discarded_bytes+item.bytes
            emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq})
        else
            if item.bytes==0 then emit(s,effects,'release_blob',{blob_ref=item.blob_ref,operation=item.operation,seq=item.seq}) end
            if item.bytes>0 then table.insert(s.queue,1,item) end
            if status=='suspended' then s.grant_status='suspended' end
        end
    elseif kind=='grant_suspended' or kind=='grant_resumed' or kind=='grant_revoked' then
        if s.grant_status=='revoked' then return reject('revoked') end
        local status=kind=='grant_suspended' and 'suspended' or 'valid'
        if event.grant~=s.grant then return reject('grant')
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
        attempt.complete=true;s.provider_failed=true;advance(s,staged(s)>0 and 'draining' or 'finalizing')
    elseif kind=='provider_complete' then
        local attempt=s.operations[event.attempt]
        if phase(s)~='requesting' or event.attempt~=s.attempt or not attempt or attempt.complete then return reject('attempt') end
        attempt.complete=true;advance(s,staged(s)>0 and 'draining' or 'finalizing')
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
                round.children[i]={operation=round.id..':child:'..i,index=i,call_id=call.call_id,arguments_ref=call.arguments_ref}
            end
            round.seq=Seq.new(#event.calls)
            s.round=round
        end
    elseif kind=='inserted' then
        local round=s.round
        if not round or not round.inserting or event.insert~=round.inserting.id then return reject('insert') end
        local item=round.inserting.item;round.inserting=nil
        if event.status=='applied' then round.seq=Seq.written(round.seq,item)
        else stop(s,effects,(event.status=='revoked' or event.status=='uncertain') and event.status or 'insert_failed') end
    elseif kind=='child_outcome' then
        local round=s.round;local found
        if round and event.round==round.id then for _,child in ipairs(round.children) do
            if child.operation==event.operation then found=child end
        end end
        if not found or not found.started or found.supervised or (found.outcome and not (found.outcome=='unknown' and event.outcome=='known'))
            or not ref(event.result_ref)
            or (event.outcome~='known' and event.outcome~='unknown' and event.outcome~='rejected' and event.outcome~='cancelled_before_effect') then return reject('child') end
        -- An outcome is final once its result is on its way to the transcript:
        -- the block written and the result the next request carries are one blob.
        local writing=round.inserting and round.inserting.item.kind=='result' and round.inserting.item.index==found.index
        if writing or Seq.final(round.seq,found.index) then return reject('written') end
        found.outcome=event.outcome;found.result_ref=event.result_ref
        if s.operations[event.operation] then s.operations[event.operation].complete=true end
        round.seq=Seq.outcome(round.seq,found.index)
    elseif kind=='round_prepared' then
        if (s.phase~='executing_tools' and s.phase~='paused') or not s.round or event.round~=s.round.id
            or not s.round.join_pending or s.round.prepared_input_ref or not ref(event.input_ref)
            or (event.preparation and event.preparation~=s.round.preparation) then return reject('round') end
        s.round.prepared_input_ref=event.input_ref
    elseif kind=='pause' then
        if s.phase=='stopping' or s.phase=='paused' then return reject('phase') end
        s.resume_phase=s.phase;s.phase='paused';release_turn(s,effects)
    elseif kind=='resume_validated' then
        if s.phase~='paused' or s.grant_status~='valid' or not ref(event.policy_ref) then return reject('resume') end
        s.phase=s.resume_phase;s.resume_phase=nil;request_turn(s,effects)
    elseif kind=='operation_resolved' or kind=='operation_supervised' then
        local supervised=kind=='operation_supervised'
        local op=s.operations[event.operation]
        if not op or op.resolved then return reject('operation') end
        -- Transfer is local retirement only: a separate supervisor retains the
        -- physical operation and unknown effect ledger. It can never join a round.
        if supervised and ((s.phase~='stopping' and s.phase~='flushing') or op.kind~='child')then return reject('supervision')end
        -- A tool resolves on cleanup whatever its outcome (#266 M2): an unknown
        -- one is written as an error result and the round goes on. It still
        -- needs *an* outcome — cleanup alone says nothing about the effect.
        if op.kind=='child' and not supervised then
            for _,child in ipairs(s.round.children) do
                if child.operation==event.operation and not child.outcome then
                    return reject('unresolved child outcome')
                end
            end
        end
        op.resolved=true
        if supervised then op.supervised=true end
        for i,id in ipairs(s.operation_order) do if id==event.operation then table.remove(s.operation_order,i);break end end
        for _,child in ipairs(s.round and s.round.children or {}) do
            if child.operation==event.operation then
                child.resolved=true
                if supervised then
                    child.supervised=true
                    -- Handed off mid-flush with nothing reported: it was cancelled
                    -- while running, and the walk writes it so.
                    if not child.outcome and s.phase=='flushing' then cancel_child(s,child) end
                    child.outcome=child.outcome or 'unknown'
                end
            end
        end
    elseif kind=='finalize_result' then
        if not s.finalize_pending or event.finalize~=s.finalize_pending then return reject('finalize') end
        s.finalize_pending=nil
        if event.status=='applied' then s.finalized=true else stop(s,effects,'finalize_failed') end
    elseif kind=='cancel' then
        if s.phase=='stopping' then return reject('duplicate') end
        if event.reason~=nil and event.reason~='overflow' then return reject('cancel reason') end
        -- The runner's byte check refuses before admission and cancels; the
        -- machine's own check stops. Both are an overflow, not a user's Stop.
        -- A user's Stop during a tool round writes the round out first (#266 M3);
        -- a second Stop, while it does, drops the rest.
        if event.reason==nil and s.phase=='executing_tools' and s.round and not Seq.complete(s.round.seq)
            and s.grant_status~='revoked' then flush(s,effects)
        else stop(s,effects,event.reason=='overflow' and 'overflow' or 'cancelled') end
    else return reject('event') end
    pump(s,effects)
    return wrap(s),{accepted=true,admitted_bytes=s.accepted_bytes-old.accepted_bytes,effects=copy(effects)}
end
return M
