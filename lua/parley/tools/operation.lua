-- Pure effect ledger. The scheduler owns these values; no transport observation
-- can manufacture a known external effect or authorize a second execution.
local M={}
local function integer(n)return type(n)=='number' and n>0 and n<math.huge and n%1==0 end
local function ref(s)return type(s)=='string' and #s>0 and #s<=4096 end
local function copy(t)
    if type(t)~='table'then return t end
    local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function input(value,limits)
    local nodes,bytes,stack=0,0,{}
    local function visit(v,depth)
        nodes=nodes+1;if nodes>limits.max_argument_nodes or depth>32 then error('limit',0)end
        local kind=type(v)
        if kind=='string'then bytes=bytes+#v;if bytes>limits.max_argument_bytes then error('limit',0)end;return v end
        if kind=='boolean'then return v end
        if kind=='number' and v==v and v>-math.huge and v<math.huge then return v end
        if kind~='table' or getmetatable(v) or stack[v]then error('invalid',0)end
        stack[v]=true;local out={}
        for k,item in pairs(v)do
            if type(k)~='string' and not integer(k)then error('key',0)end
            out[visit(k,depth+1)]=visit(item,depth+1)
        end
        stack[v]=nil;return out
    end
    if type(value)~='table'then return nil end
    local ok,result=pcall(visit,value,0);if ok then return result end
end
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function identity(spec)
    local parts={}
    for _,field in ipairs({'generation','attempt','round','call_id'})do
        local value=spec[field];if not ref(value)then return nil end
        parts[#parts+1]=#value..':'..value
    end
    return table.concat(parts)
end
local function changed(s,key,record)
    local records={};for k,v in pairs(s.records)do records[k]=v end;records[key]=record
    return {limits=s.limits,records=records,count=s.count}
end
function M.new(opts)
    opts=opts or {}
    local function configured(key,default)if opts[key]~=nil then return opts[key]end;return default end
    local limits={max_records=configured('max_records',128),
        max_argument_bytes=configured('max_argument_bytes',65536),max_argument_nodes=configured('max_argument_nodes',8192)}
    for _,n in pairs(limits)do assert(integer(n),'invalid operation limit')end
    return {limits=limits,records={},count=0}
end
function M.accept(s,spec)
    if type(spec)~='table'then return s,{status='invalid'}end
    local key=identity(spec)
    if not key or not ref(spec.name) or not ref(spec.capability_ref)then return s,{status='invalid'}end
    local args=input(spec.input,s.limits);if not args then return s,{status='invalid'}end
    local previous=s.records[key]
    if previous then
        if previous.name~=spec.name or previous.capability_ref~=spec.capability_ref or not equal(previous.input,args)then
            return s,{status='conflict',key=key}
        end
        return s,{status=previous.status=='outcome_known' and 'reuse' or 'duplicate',key=key,result_ref=previous.result_ref}
    end
    if s.count>=s.limits.max_records then return s,{status='capacity'}end
    local record={name=spec.name,input=args,capability_ref=spec.capability_ref,status='queued'}
    for _,field in ipairs({'generation','attempt','round','call_id'})do record[field]=spec[field]end
    local next_state=changed(s,key,record);next_state.count=s.count+1
    return next_state,{status='accepted',key=key}
end
function M.transition(s,key,event)
    local previous=s.records[key]
    if not previous then return s,{status='missing'}end
    if type(event)~='table'then return s,{status='invalid'}end
    local record={};for k,v in pairs(previous)do record[k]=v end
    local status,kind=record.status,event.type
    local result={status='accepted',key=key}
    if kind=='authorize' and status=='queued' and not record.owner_closed then
        if event.capability_ref~=record.capability_ref then return s,{status='authority'}end
        record.status='authorized'
    elseif kind=='start' and status=='authorized' and not record.owner_closed then
        record.status='executing';record.started=true;result.effect_start=true
    elseif kind=='cancel' and (status=='queued' or status=='authorized')then
        record.status='cancelled_before_effect';record.physical=true;record.cancel_requested=true
        result.cancelled_before_effect=true
    elseif kind=='cancel' and record.started then
        record.cancel_requested=true;result.cancel_backend=not record.physical
    elseif kind=='reject' and (status=='queued' or status=='authorized')then
        record.status='rejected';record.physical=true
    elseif kind=='outcome' and status=='executing' or kind=='reconcile' and status=='outcome_unknown'then
        if not ref(event.evidence_ref) or event.result_ref~=nil and not ref(event.result_ref) or (event.effect~='known' and event.effect~='partial' and event.effect~='unknown')
            or kind=='reconcile' and event.effect~='known' or event.effect=='known' and not ref(event.result_ref)then
            return s,{status='invalid'}
        end
        record.status=event.effect=='known' and 'outcome_known' or 'outcome_unknown'
        record.effect=event.effect;record.evidence_ref=event.evidence_ref;record.result_ref=event.result_ref
    elseif kind=='physical' and record.started and not record.physical then
        if not ref(event.evidence_ref)then return s,{status='invalid'}end
        record.physical=true
    -- #266 M3 (operator): a crashed tool is a plain failure, so an unknown effect
    -- is released too — but only once its process has physically ended. While it
    -- runs it holds its claims: that is an effect in progress, not a quarantine.
    elseif kind=='release' and not record.released and record.physical
        and (status=='outcome_known' or status=='outcome_unknown' or status=='cancelled_before_effect' or status=='rejected')then
        record.released=true;record.poll=nil;result.release_claims=true
    elseif kind=='owner_closed' and not record.owner_closed then
        record.owner_closed=true
    elseif kind=='delivery_begin' and not record.delivering then
        record.delivering=true;result.deliver=true
    elseif kind=='delivery_end' and record.delivering then
        record.delivering=nil
    elseif kind=='poll' and record.started and not record.released and not record.poll_retired then
        if type(event.now)~='number' or event.now~=event.now or event.now<0 or event.now==math.huge then return s,{status='invalid'}end
        if not record.poll then record.poll={deadline=event.now+5000,next=event.now+50,delay=50}end
    elseif kind=='tick' and record.poll then
        if type(event.now)~='number' or event.now~=event.now or event.now<record.poll.next or event.now==math.huge then return s,{status='invalid'}end
        if event.now>=record.poll.deadline then
            record.poll=nil;record.poll_retired=true;result.diagnostic=true
        else
            local delay=math.min(1000,record.poll.delay*2)
            record.poll={deadline=record.poll.deadline,next=math.min(record.poll.deadline,event.now+delay),delay=delay};result.probe=true
        end
    elseif kind=='presentation_failed' and (status=='outcome_known' or status=='outcome_unknown')then
        if not ref(event.error_ref)then return s,{status='invalid'}end
        record.presentation_error_ref=event.error_ref
    else return s,{status='invalid_transition'}end
    return changed(s,key,record),result
end
function M.forget(s,key)
    local record=s.records[key]
    if not record then return s,{status='missing'}end
    if not record.owner_closed or record.delivering or not record.released or not record.physical then
        return s,{status='unresolved'}
    end
    local next_state=changed(s,key,nil);next_state.count=s.count-1
    return next_state,{status='forgotten'}
end
function M.lifecycle(s,key)
    local r=s.records[key];if not r then return nil end
    return {status=r.status,known=r.status=='outcome_known' or r.status=='cancelled_before_effect' or r.status=='rejected',
        physical=r.physical==true,released=r.released==true,started=r.started==true,cancelled=r.cancel_requested==true,
        owner_closed=r.owner_closed==true,poll=copy(r.poll)}
end
function M.get(s,key)return copy(s.records[key])end
function M.stats(s)return {records=s.count}end
return M
