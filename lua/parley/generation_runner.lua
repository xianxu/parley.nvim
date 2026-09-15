-- IO composition for the pure generation machine. Payloads stay here; effects
-- and late callbacks carry scoped identifiers, never a current buffer/cursor.
local G=require('parley.generation')
local D=require('parley.document')
local Deferred=require('parley.deferred_work')
local M={}
local runners=setmetatable({},{__mode='k'})
local serial,active,staged_total=0,0,0
local function state(r)return assert(runners[r],'invalid generation runner')end
local function copy(value)return type(value)=='table' and vim.deepcopy(value) or value end
local function release(s,ref)
    local blob=s.blobs[ref]
    if blob then
        if blob.staged then s.staged=s.staged-blob.bytes;staged_total=staged_total-blob.bytes end
        s.blobs[ref]=nil
    end
end
local function blob(s,value,staged)
    s.serial=s.serial+1
    local ref=s.prefix..':'..s.serial
    s.blobs[ref]={value=staged and value or copy(value),bytes=staged and #value or 0,staged=staged}
    if staged then s.staged=s.staged+#value;staged_total=staged_total+#value end
    return ref
end
local function enqueue(s,effect)
    s.queue[#s.queue+1]=effect
    if s.schedule then s.work:request() end
end
local function dispatch(s,event)
    event.epoch,event.generation=s.epoch,s.generation
    local result
    s.machine,result=G.transition(s.machine,event)
    for _,effect in ipairs(result.effects) do
        if effect.type=='release_blob' then release(s,effect.blob_ref) else enqueue(s,effect) end
    end
    if result.accepted and s.adapters.changed then
        local current=G.snapshot(s.machine)
        local key=current.phase..':'..tostring(current.stale_input)
        if key~=s.presentation_key then
            s.presentation_key=key
            local ok,err=pcall(s.adapters.changed,current)
            if not ok then s.presentation_failure=tostring(err):sub(1,4096)end
        end
    end
    return result
end
local function sync(s)
    if s.terminal then return end
    local doc=D.snapshot(s.doc)
    if doc.epoch~=s.epoch or not doc.attached then
        s.detached=true;s.written=nil
        dispatch(s,{type='grant_revoked',grant=s.grant})
        return
    end
    for grant,previous in pairs(s.grants) do
        local current=doc.grants[grant]
        local status=current and current.status or 'revoked'
        if status~=previous then
            s.grants[grant]=status
            dispatch(s,{type=status=='valid' and 'grant_resumed' or 'grant_'..status,grant=grant})
        end
    end
    local generation=doc.generations[s.generation]
    if generation and generation.stale then dispatch(s,{type='input_changed',dependencies_ref=s.dependencies_ref}) end
end
local function alive(s,operation)
    sync(s)
    return not s.detached and not s.terminal and s.operations[operation]~=nil
        and G.snapshot(s.machine).phase~='stopping'
end
local function issue(s,reason)
    s.failure=tostring(reason):sub(1,4096)
end
local function stage(s,bytes)
    return type(bytes)=='string' and #bytes<=s.limit-s.staged and #bytes<=16777216-staged_total
end
local function slice(bytes,first,limit)
    local last=math.min(#bytes,first+limit-1);local at,count=first,0
    while true do
        local ending=bytes:find('\n',at,true)
        if not ending or ending>last then break end
        count=count+1
        if count>255 then last=ending-1;break end
        at=ending+1
    end
    return bytes:sub(first,last)
end
local function context(s,effect)
    local grant=effect.grant or s.grant
    local ctx={epoch=s.epoch,generation=s.generation,operation=effect.operation or effect.id,grant=grant,
        entity=s.entity,exchange=s.entity,round=effect.round,call_id=effect.call_id,
        stale_input=G.snapshot(s.machine).stale_input}
    if effect.type=='prepare' then ctx.preparation_grants=copy(s.preparation_grants) end
    local pending,completion,failed,sealed=0,nil,false,false
    local function mutation(kind,bytes,done,options)
        sync(s)
        if sealed or s.detached or s.terminal or G.snapshot(s.machine).phase=='stopping'
            or (not alive(s,effect.operation) and effect.type~='finalize' and effect.type~='reserve_round') then
            return false,'stale operation'
        end
        if type(done)~='function' or not stage(s,bytes) or s.manual_items>=s.queue_limit then
            issue(s,'staging overflow');dispatch(s,{type='cancel'});return false,'staging overflow'
        end
        local ref=blob(s,bytes,true);pending=pending+1;s.manual_items=s.manual_items+1
        enqueue(s,{type=kind,operation=effect.operation or effect.id,grant=grant,
            options=options and {first_offset=options.first_offset,retain_prefix=options.retain_prefix} or {},
            blob_ref=ref,offset=0,bytes=#bytes,accepted=0,done=function(result)
                pending=pending-1;s.manual_items=s.manual_items-1;failed=failed or result.status~='applied'
                local ok,err=pcall(done,result);if not ok then issue(s,err);failed=true end
                if pending==0 and completion then local fn=completion;completion=nil;fn(failed) end
            end})
        return true
    end
    function ctx.append(bytes,done)return mutation('manual_append',bytes,done)end
    function ctx.replace(bytes,done,options)
        if options~=nil and type(options)~='table' then return false,'invalid replacement options' end
        return mutation('manual_replace',bytes,done,options)
    end
    function ctx.cancelled()
        local phase=G.snapshot(s.machine).phase
        return s.detached or s.terminal or phase=='stopping' or phase=='terminal'
    end
    return ctx,function(fn)
        sealed=true
        if pending>0 then completion=fn else fn(failed) end
    end
end
local function callbacks(s,effect,after_writes)
    local operation=effect.operation
    local prepared=false
    local cb={}
    function cb.resolved()
        if not s.operations[operation] then return false end
        local result=dispatch(s,{type='operation_resolved',operation=operation})
        if result.accepted then s.operations[operation]=nil end
        return result.accepted
    end
    function cb.prepared(input)
        if prepared or not alive(s,operation) then return false end
        if effect.type=='prepare' then
            local grants=D.snapshot(s.doc).grants
            for _,gid in ipairs(s.preparation_grants) do
                if grants[gid] and grants[gid].status~='revoked' then return false,'live preparation grant' end
            end
            for _,gid in ipairs(s.preparation_grants) do s.grants[gid]=nil end
        end
        prepared=true
        local ref=blob(s,input,false)
        after_writes(function(failed)
            if failed then release(s,ref);dispatch(s,{type='prepare_failed',preparation=operation});return end
            local result=dispatch(s,{type=effect.type=='continue_round' and 'round_prepared' or 'prepared',
                preparation=operation,round=effect.round,input_ref=ref})
            if not result.accepted then release(s,ref) end
        end)
        return true
    end
    function cb.output(bytes,seq)
        if not alive(s,operation) then return false end
        local op=s.operations[operation]
        if not stage(s,bytes) then issue(s,'staging overflow');dispatch(s,{type='cancel'});return false end
        seq=seq or op.next_seq
        local ref=blob(s,bytes,true)
        local result=dispatch(s,{type='output',operation=operation,seq=seq,blob_ref=ref,bytes=#bytes})
        if not result.accepted or result.admitted_bytes==0 then release(s,ref)
        else op.next_seq=seq+1 end
        return result.accepted
    end
    function cb.complete()
        if not alive(s,operation) then return false end
        return dispatch(s,{type='provider_complete',attempt=operation}).accepted
    end
    function cb.failed(reason)
        if not s.operations[operation] or s.terminal then return false end
        if effect.type=='start_child' then return cb.outcome('unknown',{error=tostring(reason):sub(1,4096)}) end
        issue(s,reason or 'adapter failed')
        return dispatch(s,{type=(effect.type=='prepare' or effect.type=='continue_round') and 'prepare_failed' or 'provider_failed',
            preparation=operation,attempt=operation}).accepted
    end
    function cb.round(calls)
        if not alive(s,operation) then return false end
        local declared={}
        if type(calls)~='table' or #calls>32 then dispatch(s,{type='cancel'});return false end
        for i,call in ipairs(calls) do
            declared[i]={index=i,call_id=call.call_id,arguments_ref=blob(s,call.arguments,false)}
        end
        local accepted=dispatch(s,{type='round_declared',attempt=operation,calls=declared}).accepted
        if not accepted then for _,call in ipairs(declared) do release(s,call.arguments_ref) end end
        return accepted
    end
    function cb.outcome(outcome,result)
        if not s.operations[operation] then return false end
        local ref=blob(s,result,false)
        local accepted=dispatch(s,{type='child_outcome',round=effect.round,operation=operation,
            outcome=outcome,result_ref=ref}).accepted
        if not accepted then release(s,ref) else
            release(s,s.operations[operation].result_ref);s.operations[operation].result_ref=ref
        end
        return accepted
    end
    return cb
end
local function start_operation(s,effect)
    if s.detached or G.snapshot(s.machine).phase=='stopping' then
        -- Never-started effects are positively resolved without spawning IO.
        if effect.type=='start_child' then
            local ref=blob(s,true,false)
            dispatch(s,{type='child_outcome',round=effect.round,operation=effect.operation,
                outcome='cancelled_before_effect',result_ref=ref});release(s,ref)
        end
        dispatch(s,{type='operation_resolved',operation=effect.operation});return
    end
    local ctx,after_writes=context(s,effect)
    local input=s.blobs[effect.input_ref or effect.input_seed_ref]
    ctx.input=input and copy(input.value)
    if effect.type=='continue_round' then
        local previous=s.blobs[s.current_input]
        ctx.previous_input=previous and copy(previous.value)
    end
    if effect.type=='request' then
        for grant in pairs(s.grants) do if grant~=s.grant then s.grants[grant]=nil end end
        if s.current_input~=effect.input_ref then release(s,s.current_input);s.current_input=effect.input_ref end
    end
    ctx.capabilities=copy(s.capabilities)
    if effect.arguments_ref then
        ctx.arguments=copy(s.blobs[effect.arguments_ref].value);release(s,effect.arguments_ref)
    end
    if effect.result_refs then
        ctx.results={};for i,ref in ipairs(effect.result_refs) do
            ctx.results[i]=copy(s.blobs[ref].value);release(s,ref)
        end
    end
    local op={next_seq=1};s.operations[effect.operation]=op
    local cb=callbacks(s,effect,after_writes)
    local adapter=s.adapters[effect.type]
    if not adapter then cb.failed('missing '..effect.type..' adapter');return end
    local ok,handle=pcall(adapter,ctx,cb)
    if not ok then cb.failed(handle)
    elseif s.operations[effect.operation]==op then op.handle=handle end
end
-- Presentation receives copied receipt facts after accounting, never mutation
-- capabilities or payloads. Its failure cannot change an accepted prefix.
local function written(s,effect,result)
    local accepted,removed=result.accepted_bytes or 0,result.removed_bytes or 0
    if not s.written or accepted+removed==0 or s.detached or s.terminal then return end
    local grant=D.snapshot(s.doc).grants[effect.grant]
    local tip=grant and grant.status~='revoked' and D.byte_position(s.doc,grant.last)
    if tip then tip.byte=grant.last end
    s.written_serial=(s.written_serial or 0)+1
    local receipt={id=s.prefix..':written:'..s.written_serial,
        kind=effect.type=='write' and 'output' or effect.type=='manual_append' and 'append' or 'replace',
        status=result.status,accepted_bytes=accepted,removed_bytes=removed,tip=tip}
    local ctx={epoch=s.epoch,generation=s.generation,operation=effect.operation,grant=effect.grant,
        entity=effect.entity or (grant and grant.entity) or s.entity,exchange=s.entity}
    s.notifying=true
    local ok,err=pcall(s.written,ctx,receipt)
    s.notifying=false
    if not ok then s.presentation_failure=tostring(err):sub(1,4096) end
end
local function write(s,effect)
    local value=s.blobs[effect.blob_ref]
    if not value then return false end
    local generation=G.snapshot(s.machine)
    local grant=not s.detached and D.snapshot(s.doc).grants[effect.grant]
    if grant then effect.entity=grant.entity end
    local attempted=slice(value.value,effect.offset+1,math.min(4096,effect.bytes))
    local result
    if not grant or grant.status=='revoked' or generation.phase=='stopping' then
        result={status='stale',accepted_bytes=0}
    elseif grant.status=='suspended' then return true,'waiting'
    else
        result=D.append(s.doc,{epoch=s.epoch,generation=s.generation,operation=effect.operation,entity=grant.entity,
            grant=effect.grant,revision=grant.revision,bytes=attempted})
    end
    if result.status=='more' or result.status=='busy' then return true end
    local status=result.status=='applied' and 'applied' or result.status=='suspended' and 'suspended'
        or result.status=='stale' and 'revoked' or 'uncertain'
    if effect.type=='write' then
        dispatch(s,{type='write_result',write=effect.id,attempted_bytes=#attempted,
            committed_bytes=result.accepted_bytes,status=status})
        written(s,effect,result)
        return false
    end
    effect.offset=effect.offset+result.accepted_bytes;effect.bytes=effect.bytes-result.accepted_bytes
    effect.accepted=effect.accepted+result.accepted_bytes
    written(s,effect,result)
    if effect.bytes>0 and (status=='applied' or status=='suspended') then return true,status=='suspended' and 'waiting' end
    release(s,effect.blob_ref)
    effect.done({status=effect.bytes==0 and 'applied' or status,accepted_bytes=effect.accepted})
    return false
end
local function replace(s,effect)
    local value=s.blobs[effect.blob_ref]
    local grant=not s.detached and D.snapshot(s.doc).grants[effect.grant]
    if grant then effect.entity=grant.entity end
    local phase=G.snapshot(s.machine).phase
    local stopping=s.detached or s.terminal or phase=='stopping' or phase=='terminal'
    local result
    if stopping or not grant or grant.status=='revoked' or not value then
        if effect.cursor then D.replace_cancel(s.doc,effect.cursor) end
        result={status='stale',accepted_bytes=0,removed_bytes=0}
    else
        if not effect.cursor then
            if grant.status=='suspended' then return true,'waiting' end
            local reason
            effect.cursor,reason=D.replace_new(s.doc,{epoch=s.epoch,generation=s.generation,
                operation=effect.operation,grant=effect.grant,entity=grant.entity,revision=grant.revision,
                bytes=value.value,first_offset=effect.options.first_offset,retain_prefix=effect.options.retain_prefix})
            if not effect.cursor then result={status='refused',reason=reason,accepted_bytes=0,removed_bytes=0} end
        end
        if effect.cursor then result=D.replace_step(s.doc,effect.cursor) end
    end
    effect.accepted=effect.accepted+(result.accepted_bytes or 0)
    effect.removed=(effect.removed or 0)+(result.removed_bytes or 0)
    written(s,effect,result)
    if result.status=='more' then return true end
    if result.status=='suspended' then return true,'waiting' end
    if effect.cursor then D.replace_cancel(s.doc,effect.cursor);effect.cursor=nil end
    release(s,effect.blob_ref)
    effect.done({status=result.status,accepted_bytes=effect.accepted,removed_bytes=effect.removed,
        error=result.error,reason=result.reason})
    return false
end
local function execute(s,effect)
    if effect.type=='prepare' or effect.type=='request' or effect.type=='start_child' or effect.type=='continue_round' then
        if effect.type=='continue_round' and G.snapshot(s.machine).phase~='stopping'
            and G.snapshot(s.machine).stale_input and not s.stale_policy then
            dispatch(s,{type='pause'});return true,'waiting'
        end
        if effect.type=='continue_round' then
            local phase=G.snapshot(s.machine).phase
            if phase=='paused' then return true,'waiting' end
            if phase~='stopping' and phase~='terminal' and not effect.reclaimed then
                -- This effect exists only after every declared child has a
                -- known outcome and positively resolved effect ownership.
                for gid in pairs(s.grants) do
                    if gid~=s.grant then
                        s.grants[gid]=nil
                        if not s.detached and D.snapshot(s.doc).grants[gid] then
                            D.transition(s.doc,{kind='revoke',grant=gid})
                        end
                    end
                end
                local parent=not s.detached and D.snapshot(s.doc).grants[s.grant]
                if not parent then dispatch(s,{type='cancel'});return true end
                local reclaimed=D.reclaim_tail(s.doc,{epoch=s.epoch,generation=s.generation,
                    grant=s.grant,entity=parent.entity,revision=parent.revision})
                if not reclaimed.ok then
                    if reclaimed.reason~='unconfirmed identity' then
                        issue(s,reclaimed.reason);dispatch(s,{type='pause'})
                    end
                    return true,'waiting'
                end
                effect.reclaimed=true
            end
        end
        start_operation(s,effect)
    elseif effect.type=='write'  or effect.type=='manual_append' then return write(s,effect)
    elseif effect.type=='manual_replace' then return replace(s,effect)
    elseif effect.type=='revoke' then
        if not s.detached then D.transition(s.doc,{kind='revoke',grant=effect.grant}) end
    elseif effect.type=='cancel_operation' then
        local op=s.operations[effect.operation]
        if op then
            local adapter=s.adapters.cancel_operation
            if not adapter then issue(s,'cancel adapter missing; operation unresolved');return end
            local ok,err=pcall(adapter,{epoch=s.epoch,generation=s.generation,operation=effect.operation,handle=op.handle},function(evidence)
                if s.operations[effect.operation]~=op then return false end
                local kind='operation_resolved'
                if evidence~=nil then
                    -- Only this trusted cancellation adapter can transfer ownership.
                    -- Ordinary producer cb.resolved() always needs positive cleanup.
                    if type(evidence)~='table' or getmetatable(evidence) or evidence.supervised~=true then return false end
                    for key in pairs(evidence)do if key~='supervised'then return false end end
                    kind='operation_supervised'
                end
                local result=dispatch(s,{type=kind,operation=effect.operation})
                if result.accepted then s.operations[effect.operation]=nil end
                return result.accepted
            end)
            if not ok then issue(s,err) end
        end
    elseif effect.type=='cancel_reservation' then
        local reservation=s.reservation
        if not reservation or reservation.round~=effect.round then return false end
        local adapter=s.adapters.cancel_reservation
        if not adapter then issue(s,'reservation cancel adapter missing; reservation unresolved');return false end
        local ok,err=pcall(adapter,{epoch=s.epoch,generation=s.generation,round=effect.round,
            handle=reservation.handle},function()reservation.done(nil,nil,'cancelled')end)
        if not ok then issue(s,err) end
    elseif effect.type=='finalize' then
        if s.detached or G.snapshot(s.machine).phase=='stopping' then
            dispatch(s,{type='finalize_result',finalize=effect.id,status='failed'});return false
        end
        local ctx,after_writes=context(s,effect)
        local done=false
        local function complete(status)
            if done then return end;done=true
            after_writes(function(failed)
                dispatch(s,{type='finalize_result',finalize=effect.id,status=failed and 'failed' or status})
            end)
        end
        local ok,err=pcall(s.adapters.finalize,ctx,complete)
        if not ok then issue(s,err);complete('failed') end
    elseif effect.type=='reserve_round' then
        if s.detached or G.snapshot(s.machine).phase=='stopping' then
            dispatch(s,{type='round_reservation_failed',round=effect.round,status='cancelled'});return false
        end
        local ctx,after_writes=context(s,effect);ctx.children=copy(effect.children)
        for _,child in ipairs(ctx.children) do
            -- Reservation is a borrowed view, not consumption: the unchanged
            -- private blob is retained until this child actually starts.
            child.arguments=copy(s.blobs[child.arguments_ref].value)
        end
        local completed=false
        local reservation={round=effect.round};s.reservation=reservation
        local adapter=s.adapters.reserve_round
        local function done(grants,receipt,status)
            if completed or s.terminal then return end;completed=true
            after_writes(function(failed)
                if s.reservation==reservation then s.reservation=nil end
                if failed or not grants then
                    dispatch(s,{type='round_reservation_failed',round=effect.round,status=status or 'failed'});return
                end
                for _,grant in ipairs(grants) do s.grants[grant]='valid' end
                local ref=blob(s,receipt or true,false)
                dispatch(s,{type='round_reserved',round=effect.round,grants=grants,receipt_ref=ref});release(s,ref)
            end)
        end
        reservation.done=done
        if not adapter then done(nil) else
            local ok,handle=pcall(adapter,ctx,done)
            if not ok then issue(s,handle);done(nil)
            elseif s.reservation==reservation then reservation.handle=handle end
        end
    elseif effect.type=='terminal' then
        if not s.detached then D.transition(s.doc,{kind='finish_generation',generation=s.generation}) end
        s.terminal=true;s.written=nil;s.off();s.work:close();active=active-1
        for ref in pairs(s.blobs) do release(s,ref) end
        local terminal=s.adapters.terminal
        s.queue={};s.pending=nil;s.seed=nil;s.capabilities=nil;s.adapters={}
        s.operations={};s.doc=nil;s.grants={};s.preparation_grants={};s.detached=true;s.off=nil
        if terminal then pcall(terminal,G.snapshot(s.machine)) end
    end
    return false
end
function M.step(r)
    local s=state(r)
    if s.notifying then return {status='busy'} end
    sync(s)
    if s.terminal then return {status='terminal'} end
    local effect=s.pending or table.remove(s.queue,1)
    if not effect then return {status='waiting'} end
    local again,waiting=execute(s,effect)
    s.pending=again and effect or nil
    return {status=waiting or (s.terminal and 'terminal' or 'more')}
end
function M.start(doc,spec,adapters)
    if type(adapters)~='table' or type(adapters.prepare)~='function' or type(adapters.request)~='function'
        or type(adapters.finalize)~='function' then return nil,'prepare/request/finalize adapters required' end
    if type(spec)~='table' or (spec.limits~=nil and type(spec.limits)~='table') then return nil,'invalid specification' end
    if spec.input_stale~=nil and type(spec.input_stale)~='boolean' then return nil,'invalid stale evidence' end
    if active>=16 then return nil,'process generation limit' end
    local limits=spec.limits or {};local limit=limits.staged_bytes or 1048576
    if type(limit)~='number' or limit<1 or limit>1048576 or limit%1~=0 then return nil,'invalid staging limit' end
    local queued=limits.queued_items or 256
    if type(queued)~='number' or queued<1 or queued>256 or queued%1~=0 then return nil,'invalid queue limit' end
    local extras=spec.preparation_regions or {}
    if type(extras)~='table' or #extras>15 then return nil,'preparation region limit' end
    local regions={{entity=spec.entity,first=spec.first,last=spec.last,marker_revision=1,revision=1,confirmed=true}}
    for k,region in pairs(extras) do
        if type(k)~='number' or k%1~=0 or k<1 or k>#extras or type(region)~='table'
            or region.entity~=nil and region.entity~=spec.entity then return nil,'invalid preparation region' end
    end
    for _,region in ipairs(extras) do
        regions[#regions+1]={entity=spec.entity,first=region.first,last=region.last,marker_revision=1,revision=1,confirmed=true}
    end
    local registered=D.transition(doc,{kind='register_generation',input_snapshot={runner=true},dependencies=spec.dependencies or {},input_stale=spec.input_stale})
    if not registered.ok then return nil,registered.reason end
    local generation=registered.generation
    local acquired=D.transition(doc,{kind='acquire',generation=generation,regions=regions})
    if not acquired.ok then D.transition(doc,{kind='finish_generation',generation=generation});return nil,acquired.reason end
    serial=serial+1
    local r={};local s={doc=doc,epoch=D.snapshot(doc).epoch,generation=generation,grant=acquired.grants[1],entity=spec.entity,
        blobs={},staged=0,manual_items=0,queue_limit=queued,serial=0,prefix='runner:'..serial,queue={},operations={},adapters=adapters,limit=limit,
        schedule=spec.schedule~=false,capabilities=copy(spec.capabilities or {}),grants={}}
    s.written=adapters.written;s.adapters={}
    for key,adapter in pairs(adapters) do if key~='written' then s.adapters[key]=adapter end end
    s.preparation_grants={}
    for i,gid in ipairs(acquired.grants) do
        s.grants[gid]='valid'
        if i>1 then s.preparation_grants[#s.preparation_grants+1]=gid end
    end
    runners[r]=s;active=active+1
    s.seed=blob(s,spec.input,false);s.dependencies_ref=blob(s,spec.dependencies or {},false)
    s.machine=G.new({epoch=s.epoch,generation=generation,exchange=s.entity,grant=s.grant,input_seed_ref=s.seed,
        dependencies_ref=s.dependencies_ref,capabilities_ref=blob(s,s.capabilities,false),limits=limits})
    s.work=Deferred.new(function()return M.step(r).status=='more'end)
    s.off=D.subscribe(doc,function()
        sync(s)
        if s.schedule then s.work:request() end
    end)
    sync(s) -- carry pre-admission stale input evidence before any preparation effect
    dispatch(s,{type='start'})
    return r
end
function M.snapshot(r)
    local s=state(r);local out=G.snapshot(s.machine)
    out.retained_blobs=0;for _ in pairs(s.blobs) do out.retained_blobs=out.retained_blobs+1 end
    out.retained_staged_bytes=s.staged;out.failure=s.failure;out.presentation_failure=s.presentation_failure;return out
end
function M.cancel(r,reason)local s=state(r);s.written=nil;if reason then issue(s,reason) end;return dispatch(s,{type='cancel'})end
function M.resume(r,policy_ref)
    local s=state(r);sync(s)
    local result=dispatch(s,{type='resume_validated',policy_ref=policy_ref})
    if result.accepted then s.stale_policy=policy_ref;if s.schedule then s.work:request() end end
    return result
end
-- Explicit public policy: retain the original input and recorded tool results.
-- A captured decision cannot migrate to a later round, generation, or document.
function M.resume_original(r,identity)
    local s=state(r);sync(s)
    local current=G.snapshot(s.machine)
    if type(identity)~='table' or s.detached or current.phase~='paused' or not current.stale_input
        or not s.pending or s.pending.type~='continue_round' then
        return {accepted=false,reason='no stale continuation ready'}
    end
    for _,key in ipairs({'epoch','generation','round','input_ref'})do
        if current[key]~=identity[key] then return {accepted=false,reason='response changed'}end
    end
    for _,status in pairs(s.grants)do
        if status~='valid' then return {accepted=false,reason='output ownership changed'}end
    end
    local target=D.lookup(s.doc,s.entity)
    if not target or target.opaque or not target.metadata or not target.metadata.confirmed then
        return {accepted=false,reason='target unavailable'}
    end
    return M.resume(r,'operator:original-input')
end
function M.drain(r,limit)
    local s=state(r);local result
    for _=1,limit or 1000 do
        local repair=not s.detached and D.repair_step(s.doc) or {status='detached'}
        result=M.step(r)
        if result.status=='terminal' or result.status=='waiting' and (repair.status=='idle' or repair.status=='detached') then return result end
    end
    return result
end
return M
