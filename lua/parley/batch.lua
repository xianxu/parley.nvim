-- Pure fixed-membership batch decisions. Revision references name private
-- Document proofs held by the host; this module never reads a buffer or runs IO.
local M={}
local private=setmetatable({},{__mode='k'})
local function ref(v) return type(v)=='string' and #v>0 and #v<=256 end
local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
end
local function wrap(s)local h={};private[h]=s;return h end
local function get(h)return assert(private[h],'invalid batch state')end
function M.new(spec)
    assert(type(spec)=='table' and ref(spec.epoch) and ref(spec.batch),'invalid batch scope')
    assert(type(spec.selection)=='table','invalid batch selection')
    local s={epoch=spec.epoch,batch=spec.batch,selection={},contexts={},completed=0,serial=0,phase='ready'}
    local seen={}
    for _,item in ipairs(spec.selection)do
        assert(type(item)=='table' and ref(item.entity) and ref(item.revision) and not seen[item.entity],
            'invalid batch member')
        seen[item.entity]=true;s.selection[#s.selection+1]={entity=item.entity,revision=item.revision}
    end
    for _,item in ipairs(spec.contexts or {})do
        assert(type(item)=='table' and ref(item.entity) and ref(item.revision) and not s.contexts[item.entity],
            'invalid batch context')
        s.contexts[item.entity]=item.revision
    end
    if #s.selection==0 then s.phase='completed' end
    return wrap(s)
end
function M.snapshot(h)return copy(get(h))end
local function validate(s,proof,adopt)
    if type(proof)~='table' or proof.epoch~=s.epoch then return {status='obsolete',reason='document changed'} end
    local deferred,conflict
    local function check(entity,revision,kind,items)
        local item=type(items)=='table' and items[entity]
        if type(item)~='table' then return {status='missing',reason=kind..' missing'} end
        if item.status=='opaque' or item.status=='budget' then deferred=true;return end
        if item.status=='obsolete' then return {status='obsolete',reason=kind..' obsolete'} end
        if item.status~='valid' or not ref(item.revision) then
            return {status='conflict',reason=kind..' changed'}
        end
        if not adopt and item.revision~=revision then conflict=conflict or {status='conflict',reason=kind..' changed'} end
    end
    for i=s.completed+1,#s.selection do
        local item=s.selection[i];local err=check(item.entity,item.revision,'question',proof.questions)
        if err then return err end
    end
    for entity,revision in pairs(s.contexts)do
        local err=check(entity,revision,'context',proof.contexts);if err then return err end
    end
    if conflict then return conflict end
    if deferred then return {status='deferred',reason='revision unavailable'} end
    return {status='ready'}
end
function M.validate_next(h,proof)return validate(get(h),proof,false)end
function M.transition(h,event)
    local original=get(h)
    local function reject(reason)return h,{accepted=false,effects={},reason=reason}end
    if type(event)~='table' or event.epoch~=original.epoch or event.batch~=original.batch then
        return reject('wrong scope')
    end
    local s=copy(original);local effects={}
    if event.type=='start' then
        if s.phase~='ready' then return reject('not ready') end
        local checked=validate(s,event.evidence,false)
        if checked.status=='deferred' then return reject(checked.reason) end
        if checked.status~='ready' then s.phase='paused';s.reason=checked.reason
        else
            s.serial=s.serial+1
            s.active={leg=s.batch..':'..s.serial,entity=s.selection[s.completed+1].entity}
            s.phase='running';s.reason=nil
            effects[1]={type='start_generation',epoch=s.epoch,batch=s.batch,leg=s.active.leg,entity=s.active.entity}
        end
    elseif event.type=='cancel' then
        if s.phase=='completed' or s.phase=='paused' then return reject('not cancellable') end
        -- Why it was cancelled belongs to the batch, not to a flag beside it: a
        -- host reads it off the snapshot and words the pause (#261 M5 review).
        if event.cause~=nil and event.cause~='user' and event.cause~='lifecycle' and event.cause~='fault' then
            return reject('invalid cancel cause')
        end
        s.phase='paused';s.reason='cancelled';s.cause=event.cause
        if s.active then effects[1]={type='cancel_generation',epoch=s.epoch,batch=s.batch,leg=s.active.leg} end
    elseif event.type=='finished' then
        if not s.active or event.leg~=s.active.leg then return reject('stale leg') end
        if not ref(event.outcome) then return reject('missing outcome') end
        if event.outcome=='success' and not ref(event.context_revision) then return reject('missing context revision') end
        if event.context_status~=nil and event.context_status~='valid' and event.context_status~='conflict' then
            return reject('invalid context status')
        end
        local paused=s.phase=='paused'
        if event.outcome=='success' then
            s.contexts[s.active.entity]=event.context_revision;s.completed=s.completed+1
            s.phase=s.completed==#s.selection and 'completed' or (paused and 'paused' or 'ready')
            if not paused then s.reason=nil end
            if event.context_status=='conflict' then s.phase='paused';s.reason='context changed' end
        else
            s.phase='paused';s.reason=event.outcome
            if event.outcome=='unknown' then s.unknown=true end
        end
        s.active=nil
    elseif event.type=='resume' then
        if s.phase~='paused' then return reject('not paused') end
        if s.active then return reject('leg unresolved') end
        if s.unknown then return reject('unknown effect') end
        local checked=validate(s,event.evidence,event.accept_changes==true)
        if checked.status~='ready' then return reject(checked.reason) end
        if event.accept_changes==true then
            for i=s.completed+1,#s.selection do
                local item=s.selection[i];item.revision=event.evidence.questions[item.entity].revision
            end
            for entity in pairs(s.contexts)do s.contexts[entity]=event.evidence.contexts[entity].revision end
        end
        s.phase=s.completed==#s.selection and 'completed' or 'ready';s.reason=nil;s.cause=nil
    else return reject('unknown event') end
    return wrap(s),{accepted=true,effects=effects}
end
return M
