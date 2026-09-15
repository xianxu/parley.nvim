-- Pure authority for filesystem request, effect, cancellation and retirement.
-- Handles, byte strings and path identities remain in the IO adapter.
local M={}
function M.new(limit)
    assert(type(limit)=='number' and limit>0 and limit%1==0,'invalid request limit')
    return {limit=limit,steps=0,serial=0,cancelled=false,stopped=false,terminal=false,
        mutated=false,applied=false,uncertain=false}
end
function M.view(s,facts)
    facts=facts or {}
    local physical=s.pending==nil and not facts.handles and not facts.native_handles
    local unknown=not physical or facts.temporary or facts.artifacts or s.uncertain
    return {certainty=unknown and 'unknown' or 'known',physical_resolved=physical,
        effect=s.applied and 'applied' or s.mutated and 'partial' or s.uncertain and 'unknown' or 'not_applied',
        cancelled=s.cancelled,steps=s.steps}
end
function M.transition(s,e)
    local denied={execute=false,consume=false,proceed=false,publish=false,reconcile=false,reason='unavailable'}
    if type(e)~='table' or s.terminal then return s,denied end
    local n={};for k,v in pairs(s)do n[k]=v end
    if e.type=='request'then
        if e.cleanup and e.mutation then return s,denied end
        if s.pending or not e.cleanup and (s.cancelled or s.stopped)then return s,denied end
        if not e.cleanup and s.steps>=s.limit then denied.reason='capacity';return s,denied end
        n.serial=s.serial+1;n.pending=n.serial;n.steps=s.steps+1
        if e.mutation then n.uncertain=true end
        return n,{execute=true,id=n.pending}
    elseif e.type=='completed'then
        if not s.pending or e.id~=s.pending then return s,denied end
        n.pending=nil;return n,{consume=true}
    elseif e.type=='cancel'then
        n.cancelled=true;return n,{accepted=true}
    elseif e.type=='stop'then
        n.stopped=true;return n,{cleanup=s.pending==nil}
    elseif e.type=='proceed'then
        if s.stopped or s.cancelled then
            n.stopped=true;return n,{proceed=false,cleanup=s.pending==nil,cancelled=s.cancelled}
        end
        return s,{proceed=true}
    elseif e.type=='effect'then
        if e.mutated then n.mutated=true end
        if e.applied then n.applied=true end
        if e.complete_if_mutated and s.mutated then n.applied=true end
        if e.uncertain~=nil then n.uncertain=e.uncertain end
        return n,{accepted=true}
    elseif e.type=='cleanup'then
        if s.pending then return s,denied end
        if (e.remaining or 0)>0 then return s,{action='close'}end
        if e.facts.temporary and not e.facts.handles then return s,{action='remove_temporary'}end
        return s,{action='publish'}
    elseif e.type=='reconcile'then
        return s,{reconcile=s.pending==nil}
    elseif e.type=='publish'then
        local outcome=M.view(s,e.facts)
        n.terminal=outcome.certainty=='known'
        return n,{publish=true,outcome=outcome}
    end
    return s,denied
end
return M
