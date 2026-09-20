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
--- Grow a staged blob (#266). Parts are joined only when the blob is read, so a
--- long run of held deltas costs one concatenation rather than one per delta.
local function append(s,ref,bytes)
    local b=s.blobs[ref]
    b.parts=b.parts or {};b.parts[#b.parts+1]=bytes
    b.bytes=b.bytes+#bytes;s.staged=s.staged+#bytes;staged_total=staged_total+#bytes
end
local function contents(b)
    if b.parts then b.value=b.value..table.concat(b.parts);b.parts=nil end
    return b.value
end
local function enqueue(s,effect)
    s.queue[#s.queue+1]=effect
    if s.schedule then s.work:request() end
end
--- Presentation receives the machine snapshot plus, while this generation waits
--- for the write turn, `blocked`: which generation holds it, its exchange, and
--- what it is doing (#266). A held generation must never read as a frozen editor.
local function blocked_key(b)
    return b and ':'..tostring(b.generation)..':'..tostring(b.entity)..':'..tostring(b.phase)..':'..tostring(b.line) or ''
end
local function present(s)
    if not s.adapters.changed then return end
    local current=G.snapshot(s.machine)
    local b=s.blocked;current.blocked=b and copy(b)
    local t=current.tools
    local key=current.phase..':'..tostring(current.stale_input)..blocked_key(b)
        ..(t and ':'..t.finished..'/'..t.settled..'/'..t.total or '')
    if key~=s.presentation_key then
        s.presentation_key=key
        local ok,err=pcall(s.adapters.changed,current)
        if not ok then s.presentation_failure=tostring(err):sub(1,4096)end
    end
end
--- The scope kill (#261 M4): once, when the machine first reaches `stopping` or
--- `terminal` (a successful generation never stops). It ends every process the
--- generation started — the ones an adapter could not cancel included — so
--- nothing it spawned outlives it. O(1) phase check: this runs on every dispatch.
local issue -- defined below; kill_scope and fault both record through it
local function kill_scope(s)
    if s.scope_killed then return end
    s.scope_killed=true
    local stopping=s.adapters.stopping
    if stopping then
        local ok,err=pcall(stopping,{epoch=s.epoch,generation=s.generation})
        if not ok then issue(s,err,true) end
    end
end
local function scope_kill(s)
    if s.scope_killed then return end
    local phase=G.phase(s.machine)
    if phase=='stopping' or phase=='terminal' then kill_scope(s) end
end
local function dispatch(s,event)
    event.epoch,event.generation=s.epoch,s.generation
    local result
    s.machine,result=G.transition(s.machine,event)
    if result.accepted then scope_kill(s) end
    for _,effect in ipairs(result.effects) do
        if effect.type=='release_blob' then release(s,effect.blob_ref) else enqueue(s,effect) end
    end
    if result.accepted then present(s) end
    return result
end
--- The turn holder this generation is waiting behind, or nil. Only a generation
--- that wants the turn is blocked: a paused one gave it up, a stopping one is done.
local function blocker(s,doc)
    -- Constant-time checks first: this runs on every sync — every step, every
    -- provider delta, every document notification — the holder's included.
    if s.turn_status~='waiting' or doc.turn==nil then return nil end
    local phase=G.phase(s.machine)
    if phase=='paused' or phase=='stopping' or phase=='terminal' then return nil end
    -- The one place a holder's exchange becomes a line number; presentation and
    -- the overflow report both read `line` rather than re-deriving it.
    local function located(entity,holder_phase)
        local marker=entity and D.lookup(s.doc,entity)
        return {generation=doc.turn,entity=entity,phase=holder_phase,
            line=marker and not marker.opaque and marker.start_row+1 or nil}
    end
    for _,other in pairs(runners) do
        if other.generation==doc.turn and other.doc==s.doc and not other.terminal then
            return located(other.entity,G.phase(other.machine))
        end
    end
    -- Not a runner (an automatic topic writes through the coordinator directly).
    for _,grant in pairs(doc.grants) do
        if grant.generation==doc.turn and grant.status~='revoked' then return located(grant.entity) end
    end
    return {generation=doc.turn}
end
-- Why a generation lost its grant, for the words its ending gets (#261 M5):
-- the first cause wins. An edit to its output, a reload, or a detach, which is
-- both the chat closing and `:e!` (Neovim detaches the buffer to re-read it);
-- the host, which knows the buffer, tells those two apart.
local EDIT_REASONS={['output edit']=true,identity=true}
local function sync(s)
    if s.terminal then return end
    local doc=D.snapshot(s.doc)
    if doc.epoch~=s.epoch or not doc.attached then
        s.cause=s.cause or (not doc.attached and 'detach' or 'reload')
        s.detached=true;s.written=nil
        dispatch(s,{type='grant_revoked',grant=s.grant})
        return
    end
    for grant,previous in pairs(s.grants) do
        local current=doc.grants[grant]
        local status=current and current.status or 'revoked'
        if status~=previous then
            if status=='revoked' and current and EDIT_REASONS[current.reason] then s.cause=s.cause or 'edit' end
            s.grants[grant]=status
            dispatch(s,{type=status=='valid' and 'grant_resumed' or 'grant_'..status,grant=grant})
        end
    end
    local turn=doc.turn==s.generation and 'held' or 'waiting'
    if turn~=s.turn_status then s.turn_status=turn; dispatch(s,{type='turn',status=turn}) end
    local generation=doc.generations[s.generation]
    if generation and generation.stale then dispatch(s,{type='input_changed',dependencies_ref=s.dependencies_ref}) end
    -- Recomputed on every sync, and sync runs on every document notification —
    -- which includes each of the holder's writes, so its phase stays current.
    -- Present only when the blocker changed; dispatch presents machine changes.
    local blocked=blocker(s,doc)
    if blocked_key(blocked)~=blocked_key(s.blocked) then s.blocked=blocked;present(s) end
end
local function alive(s,operation)
    sync(s)
    return not s.detached and not s.terminal and s.operations[operation]~=nil
        and G.snapshot(s.machine).phase~='stopping'
end
-- A producer token and a free-text diagnosis are different things, and sharing
-- one field made an unworded token print raw in the user's words (#261 M5 review
-- round 3, BR-66). Typed here, at the producer: a token is keyed by
-- parley.refusal; a diagnosis (a Lua error, a provider's text) travels beside it
-- and is shown as detail.
function issue(s,reason,diagnosis)
    -- `failure` holds a token; anything the vocabulary cannot resolve is the
    -- diagnosis beside it, whatever the caller meant. This keeps the snapshot's
    -- own field honest for its readers. It is not the only gate: parley.refusal
    -- gates again where the value is READ, because a host can supply a reason
    -- that never passed through here (#261 close: BR-92).
    local Refusal=require('parley.refusal')
    if not diagnosis and not Refusal.is_token(reason) then diagnosis=true end
    -- Provider prose keeps every line (the last often carries the action); a Lua
    -- error keeps its first, and drops the traceback.
    if diagnosis then s.diagnosis=Refusal.prose(reason) else s.failure=tostring(reason):sub(1,4096) end
end
--- Why staged bytes overflowed. A generation held behind the write turn names the
--- answer it waited for (#266): without that, an overflow while queued reads as
--- a runaway response. The budget itself is unchanged — 1 MiB per generation,
--- 16 MiB process-wide — and 16 runners x 1 MiB is exactly the process cap, so
--- the per-generation limit always binds first.
-- An overflow records which answer the generation was held behind, as data; the
-- host words it (chat_presentation.overflow_message).
local function note_overflow(s)
    issue(s,'staging overflow');s.waited_for_line=s.blocked and s.blocked.line
end
local function overflowed(s)
    note_overflow(s);dispatch(s,{type='cancel',reason='overflow'})
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
-- Effects that write but are not operations: nothing resolves them, so the
-- liveness check below must not look for one. A set, not a comparison, so a
-- renamed effect cannot silently drop out of it.
local unscoped={finalize=true,insert_tool=true}
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
            or (not alive(s,effect.operation) and not unscoped[effect.type]) then
            return false,'stale operation'
        end
        if type(done)~='function' or not stage(s,bytes) or s.manual_items>=s.queue_limit then
            overflowed(s);return false,'staging overflow'
        end
        local ref=blob(s,bytes,true);pending=pending+1;s.manual_items=s.manual_items+1
        enqueue(s,{type=kind,operation=effect.operation or effect.id,grant=grant,
            options=options and {first_offset=options.first_offset,retain_prefix=options.retain_prefix} or {},
            blob_ref=ref,offset=0,bytes=#bytes,accepted=0,done=function(result)
                pending=pending-1;s.manual_items=s.manual_items-1;failed=failed or result.status~='applied'
                local ok,err=pcall(done,result);if not ok then issue(s,err,true);failed=true end
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
    --- `gap` (prepare only, optional): a writer for bytes the preparation has not
    --- written yet. Reporting input without them lets the request start at once;
    --- the machine calls the writer back through `write_gap` immediately before
    --- this generation's first write (#266).
    function cb.prepared(input,gap)
        if prepared or not alive(s,operation) then return false end
        if gap~=nil and (effect.type~='prepare' or type(gap)~='function') then return false,'invalid gap writer' end
        if effect.type=='prepare' then
            -- Without a deferred gap, preparation must have retired its extra
            -- grants already. With one, they stay live until the gap lands.
            local grants=D.snapshot(s.doc).grants
            for _,gid in ipairs(gap and {} or s.preparation_grants) do
                if grants[gid] and grants[gid].status~='revoked' then return false,'live preparation grant' end
            end
            for _,gid in ipairs(s.preparation_grants) do s.grants[gid]=nil end
        end
        prepared=true
        local ref=blob(s,input,false)
        after_writes(function(failed)
            if failed then release(s,ref);dispatch(s,{type='prepare_failed',preparation=operation});return end
            s.gap_writer=gap
            local result=dispatch(s,{type=effect.type=='continue_round' and 'round_prepared' or 'prepared',
                preparation=operation,round=effect.round,input_ref=ref,gap=gap and true or nil})
            if not result.accepted then release(s,ref);s.gap_writer=nil end
        end)
        return true
    end
    function cb.output(bytes,seq)
        if not alive(s,operation) then return false end
        local op=s.operations[operation]
        if not stage(s,bytes) then overflowed(s);return false end
        seq=seq or op.next_seq
        -- Grow the item this operation queued last, if the machine still holds it
        -- queued (#266): output arrives one delta at a time, and a generation held
        -- behind the turn would otherwise queue one item per delta.
        -- The machine's own budget can refuse too (its item cap spans operations);
        -- that is the same overflow and gets the same reason.
        local function refused(result)
            if result.accepted and result.admitted_bytes==0 and #bytes>0
                and G.snapshot(s.machine).outcome=='overflow' and not s.failure then note_overflow(s) end
        end
        if op.tail and s.blobs[op.tail] and #bytes>0 then
            local result=dispatch(s,{type='output',operation=operation,seq=seq,blob_ref=op.tail,bytes=#bytes,extend=true})
            if result.accepted then
                if result.admitted_bytes>0 then append(s,op.tail,bytes) else refused(result) end
                op.next_seq=seq+1
                return true
            end
        end
        local ref=blob(s,bytes,true)
        local result=dispatch(s,{type='output',operation=operation,seq=seq,blob_ref=ref,bytes=#bytes})
        if not result.accepted or result.admitted_bytes==0 then release(s,ref);refused(result)
        else op.next_seq=seq+1;op.tail=ref end
        return result.accepted
    end
    function cb.complete()
        if not alive(s,operation) then return false end
        return dispatch(s,{type='provider_complete',attempt=operation}).accepted
    end
    function cb.failed(reason,diagnosis)
        if not s.operations[operation] or s.terminal then return false end
        if effect.type=='start_child' then return cb.outcome('unknown',{error=tostring(reason):sub(1,4096)}) end
        -- A failure reported after the generation is already stopping is an echo of
        -- the stop (the transport aborts because we refused its bytes), not a
        -- cause: keep the reason that stopped it.
        if G.snapshot(s.machine).phase~='stopping' then issue(s,reason or 'adapter failed',diagnosis) end
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
    local phase=G.phase(s.machine)
    -- A tool queued before a Stop must not start while its round is written out
    -- (#266 M3): flushing only writes.
    if s.detached or phase=='stopping' or (phase=='flushing' and effect.type=='start_child') then
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
    local op={next_seq=1,kind=effect.type};s.operations[effect.operation]=op
    local cb=callbacks(s,effect,after_writes)
    local adapter=s.adapters[effect.type]
    if not adapter then cb.failed('missing adapter: '..effect.type);return end
    local ok,handle=pcall(adapter,ctx,cb)
    if not ok then
        op.start_threw=true
        -- A Lua error, not a token: it travels as the diagnosis beside the
        -- outcome's words (#261 M5 review round 3, BR-66).
        cb.failed(handle,true)
        -- A tool whose start threw: its outcome is `unknown` (recorded above) and
        -- it resolves now so the round goes on (#261 M4 W1). A throw is not proof
        -- nothing started — a process spawned before the throw is in the
        -- generation's scope and runs until the scope kill at its terminal.
        if effect.type=='start_child' then cb.resolved() end
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
    local attempted=slice(contents(value),effect.offset+1,math.min(4096,effect.bytes))
    local result
    if not grant or grant.status=='revoked' or generation.phase=='stopping' then
        result={status='stale',accepted_bytes=0}
    elseif grant.status=='suspended' then return true,'waiting'
    else
        result=D.append(s.doc,{epoch=s.epoch,generation=s.generation,operation=effect.operation,entity=grant.entity,
            grant=effect.grant,revision=grant.revision,bytes=attempted})
    end
    if result.status=='more' or result.status=='busy' then return true end
    if result.status=='waiting' then return true,'waiting' end
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
                bytes=contents(value),first_offset=effect.options.first_offset,retain_prefix=effect.options.retain_prefix})
            if not effect.cursor then result={status='refused',reason=reason,accepted_bytes=0,removed_bytes=0} end
        end
        if effect.cursor then result=D.replace_step(s.doc,effect.cursor) end
    end
    effect.accepted=effect.accepted+(result.accepted_bytes or 0)
    effect.removed=(effect.removed or 0)+(result.removed_bytes or 0)
    written(s,effect,result)
    if result.status=='more' then return true end
    if result.status=='suspended' or result.status=='waiting' then return true,'waiting' end
    if effect.cursor then D.replace_cancel(s.doc,effect.cursor);effect.cursor=nil end
    release(s,effect.blob_ref)
    effect.done({status=result.status,accepted_bytes=effect.accepted,removed_bytes=effect.removed,
        error=result.error,reason=result.reason})
    return false
end
--- The terminal cleanup, once: the machine's own terminal, or a fault.
local function finish(s,outcome)
    if s.terminal then return end
    if not s.detached then D.transition(s.doc,{kind='finish_generation',generation=s.generation}) end
    s.terminal=true;s.written=nil;s.off();s.work:close();active=active-1
    for ref in pairs(s.blobs) do release(s,ref) end
    local terminal=s.adapters.terminal
    s.queue={};s.pending=nil;s.seed=nil;s.capabilities=nil;s.adapters={};s.gap_writer=nil
    s.operations={};s.doc=nil;s.grants={};s.preparation_grants={};s.detached=true;s.off=nil
    -- The failure reason travels with the terminal snapshot, so a host can say
    -- why a response stopped (an overflow names the answer it waited for).
    local final=G.snapshot(s.machine);final.failure=s.failure;final.waited_for_line=s.waited_for_line
    final.diagnosis=s.diagnosis
    final.cause=s.cause
    -- A fault ends the generation outside the machine: `snapshot` reports what
    -- the host was handed, so there is one authority for "terminal".
    if outcome then final.outcome=outcome;final.phase='terminal';s.final_outcome=outcome end
    if terminal then pcall(terminal,final) end
end
--- The runner's own step threw (#261 M4). Nothing can be trusted to call back
--- now, so the generation ends here with outcome `fault`: its processes are
--- killed through the scope first, then it is cleaned up like any terminal.
--- The one way a generation reaches terminal with operations outstanding.
local function fault(s,err)
    if s.terminal then return end
    issue(s,err,true)
    kill_scope(s)
    finish(s,'fault')
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
                -- This effect exists only after every declared tool's blocks are
                -- written and its effect ownership positively resolved.
                local answer=not s.detached and D.snapshot(s.doc).grants[s.grant]
                if not answer then dispatch(s,{type='cancel'});return true end
                local reclaimed=D.reclaim_tail(s.doc,{epoch=s.epoch,generation=s.generation,
                    grant=s.grant,entity=answer.entity,revision=answer.revision})
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
    elseif effect.type=='write_gap' then
        local writer,settled=s.gap_writer,false
        s.gap_writer=nil
        local function done(status)
            if settled or s.terminal then return false end;settled=true
            return dispatch(s,{type='gap_result',status=status=='applied' and 'applied' or 'failed'}).accepted
        end
        if s.detached or not writer or G.snapshot(s.machine).phase=='stopping' then done('failed');return false end
        local ok,err=pcall(writer,done)
        if not ok then issue(s,err,true);done('failed') end
    elseif effect.type=='request_turn' or effect.type=='release_turn' then
        if not s.detached then D.transition(s.doc,{kind=effect.type,generation=s.generation,epoch=s.epoch}) end
    elseif effect.type=='revoke' then
        if not s.detached then D.transition(s.doc,{kind='revoke',grant=effect.grant}) end
    elseif effect.type=='cancel_operation' then
        local op=s.operations[effect.operation]
        if op and op.start_threw then
            -- Its start threw, so no adapter holds it and none can cancel it.
            -- Whatever it spawned dies with the scope kill; the runner confirms it
            -- here (#261 M4 W1, W9, W11). A tool is handed to supervision, the only
            -- resolution the machine accepts for a tool without an outcome.
            local child=op.kind=='start_child'
            local result=dispatch(s,{type=child and 'operation_supervised' or 'operation_resolved',operation=effect.operation})
            if result.accepted then s.operations[effect.operation]=nil end
        elseif op then
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
            if not ok then issue(s,err,true) end
        end
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
        if not ok then issue(s,err,true);complete('failed') end
    elseif effect.type=='insert_tool' then
        -- One tool block (#266 M2): the machine chose which and when; the adapter
        -- renders and appends it. Always answered, so a stopping machine is never
        -- left waiting on a block it issued. A result is the same blob the next
        -- request carries, so the transcript and the continuation cannot differ.
        local settled=false
        local function settle(status)
            if settled or s.terminal then return end;settled=true
            dispatch(s,{type='inserted',insert=effect.id,status=status})
        end
        if s.detached or G.phase(s.machine)=='stopping' or not s.adapters.insert_tool then
            settle(s.detached and 'revoked' or 'failed');return false
        end
        local ctx,after_writes=context(s,effect)
        ctx.index=effect.index;ctx.kind=effect.kind
        -- #266 M3: a result the Stop walk recorded as cancelled has no blob.
        ctx.failure=effect.cancelled and 'cancelled_'..effect.cancelled or nil
        local result=effect.result_ref and s.blobs[effect.result_ref]
        ctx.result=result and copy(result.value)
        local function complete(status)
            after_writes(function(failed)
                settle(status=='applied' and (failed and 'failed' or 'applied') or tostring(status))
            end)
        end
        local ok,err=pcall(s.adapters.insert_tool,ctx,complete)
        if not ok then issue(s,err,true);settle('failed') end
    elseif effect.type=='terminal' then
        finish(s)
    end
    return false
end
-- Control effects change authority, not text: they are never parked, so they
-- must never wait behind a parked effect either. A stale-input continue_round
-- pauses and then parks at the head of the FIFO until resumed; the release_turn
-- that pause emits would otherwise queue behind it for good (#266 M1 review C1).
-- They keep FIFO order among themselves, so stop()'s revoke still precedes its
-- release_turn.
local control={revoke=true,request_turn=true,release_turn=true}
local function next_control(s)
    for i,effect in ipairs(s.queue) do
        if control[effect.type] then return table.remove(s.queue,i) end
    end
end
function M.step(r)
    local s=state(r)
    if s.notifying then return {status='busy'} end
    sync(s)
    if s.terminal then return {status='terminal'} end
    local effect=next_control(s)
    if effect then execute(s,effect);return {status=s.terminal and 'terminal' or 'more'} end
    effect=s.pending or table.remove(s.queue,1)
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
    runners[r]=s
    -- Everything below can throw, and the generation is already registered with
    -- grants held. A throw releases all of it and reports the reason; `active`
    -- counts the runner only once it has started (#261 M4 W14).
    local started,reason=pcall(function()
        s.seed=blob(s,spec.input,false);s.dependencies_ref=blob(s,spec.dependencies or {},false)
        s.machine=G.new({epoch=s.epoch,generation=generation,exchange=s.entity,grant=s.grant,input_seed_ref=s.seed,
            dependencies_ref=s.dependencies_ref,capabilities_ref=blob(s,s.capabilities,false),limits=limits})
        s.work=Deferred.new(function()return M.step(r).status=='more'end,function(err)fault(s,err)end)
        s.off=D.subscribe(doc,function()
            sync(s)
            if s.schedule then s.work:request() end
        end)
        sync(s) -- carry pre-admission stale input evidence before any preparation effect
        dispatch(s,{type='start'})
    end)
    if not started then
        if s.off then pcall(s.off) end
        if s.work then s.work:close() end
        for ref in pairs(s.blobs) do release(s,ref) end
        D.transition(doc,{kind='finish_generation',generation=generation})
        runners[r]=nil
        return nil,tostring(reason):sub(1,4096)
    end
    active=active+1
    return r
end
--- The runners not yet terminal (#261 M4): a generation that stops must reach
--- terminal, so this returns to its baseline once every stopped one has.
function M.stats()
    return {active=active}
end
function M.snapshot(r)
    local s=state(r);local out=G.snapshot(s.machine)
    if s.final_outcome then out.phase='terminal';out.outcome=s.final_outcome end
    out.retained_blobs=0;for _ in pairs(s.blobs) do out.retained_blobs=out.retained_blobs+1 end
    out.retained_staged_bytes=s.staged;out.failure=s.failure;out.diagnosis=s.diagnosis
    out.waited_for_line=s.waited_for_line
    out.presentation_failure=s.presentation_failure;return out
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
