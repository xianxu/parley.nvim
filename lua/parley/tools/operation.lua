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
    if kind=='authorize' and status=='queued'then
        if event.capability_ref~=record.capability_ref then return s,{status='authority'}end
        record.status='authorized'
    elseif kind=='start' and status=='authorized'then
        record.status='executing';result.effect_start=true
    elseif kind=='cancel' and (status=='queued' or status=='authorized')then
        record.status='cancelled_before_effect'
    elseif kind=='cancel' and (status=='executing' or status=='outcome_unknown')then
        record.cancel_requested=true
    elseif kind=='reject' and (status=='queued' or status=='authorized')then
        record.status='rejected'
    elseif kind=='outcome' and status=='executing' or kind=='reconcile' and status=='outcome_unknown'then
        if not ref(event.evidence_ref) or event.result_ref~=nil and not ref(event.result_ref) or (event.effect~='known' and event.effect~='partial' and event.effect~='unknown')
            or kind=='reconcile' and event.effect~='known' or event.effect=='known' and not ref(event.result_ref)then
            return s,{status='invalid'}
        end
        record.status=event.effect=='known' and 'outcome_known' or 'outcome_unknown'
        record.effect=event.effect;record.evidence_ref=event.evidence_ref;record.result_ref=event.result_ref
    elseif kind=='presentation_failed' and (status=='outcome_known' or status=='outcome_unknown')then
        if not ref(event.error_ref)then return s,{status='invalid'}end
        record.presentation_error_ref=event.error_ref
    else return s,{status='invalid_transition'}end
    return changed(s,key,record),result
end
function M.forget(s,key)
    local record=s.records[key]
    if not record then return s,{status='missing'}end
    if record.status~='outcome_known' and record.status~='cancelled_before_effect' and record.status~='rejected'then
        return s,{status='unresolved'}
    end
    local next_state=changed(s,key,nil);next_state.count=s.count-1
    return next_state,{status='forgotten'}
end
function M.get(s,key)return copy(s.records[key])end
function M.stats(s)return {records=s.count}end
return M
