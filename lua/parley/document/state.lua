-- Bounded authority only. The coordinator supplies live sequence identity proofs;
-- this module neither owns document text nor treats coordinates as identity.
local M = {}
local states = setmetatable({}, {__mode='k'})
local serial = 0
local function id() serial=serial+1; return serial end
local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
local function scalar(v) return (type(v)=='string' and #v<=256) or (type(v)=='number' and integer(v)) end
local function copy(value, limit)
    local fields, bytes, active = 0, 0, {}
    local function visit(v, depth)
        fields=fields+1; assert(fields<=(limit or 65536) and depth<=16, 'snapshot limit')
        if type(v)=='string' then bytes=bytes+#v; assert(bytes<=(limit and 65536 or 1048576),'snapshot bytes limit') end
        if type(v)~='table' then
            assert(v==nil or type(v)=='boolean' or type(v)=='string' or
                (type(v)=='number' and v==v and math.abs(v)<math.huge), 'invalid snapshot value')
            return v
        end
        assert(not active[v] and getmetatable(v)==nil,'invalid snapshot table')
        active[v]=true; local out={}
        for k,x in pairs(v) do assert(scalar(k),'invalid snapshot key'); out[visit(k,depth+1)]=visit(x,depth+1) end
        active[v]=nil; return out
    end
    return visit(value,0)
end
local function state(doc) local s=states[doc]; assert(s, 'unknown document'); return s end
local function range(p) return type(p)=='table' and integer(p.first) and integer(p.last) and p.first<=p.last end
local function proof(p)
    return range(p) and scalar(p.entity) and scalar(p.marker_revision) and integer(p.revision) and p.confirmed==true
end
local function overlaps(a,b)
    if a.last<b.first or b.last<a.first then return false end
    if a.last==b.first and (a.open_last or b.open_first) then return false end
    if b.last==a.first and (b.open_last or a.open_first) then return false end
    return true
end
local function contains(a,b)
    return a.first<=b.first and b.last<=a.last and
        not (a.open_first and a.first==b.first) and not (a.open_last and a.last==b.last)
end
local function writable(grant, wanted)
    for _,slot in ipairs(grant.slots) do if contains(slot,wanted) then return true end end
    return false
end
local function effect(result,kind,object,reason)
    local e={kind=kind,reason=reason}; e[kind=='stale' and 'generation' or 'grant']=object
    result.effects[#result.effects+1]=e
end
local function revoke(s,g,result,reason)
    if g.status=='revoked' then return end
    g.status='revoked'; g.reason=reason; effect(result,'revoked',g.id,reason)
    for _,child in pairs(s.grants) do if child.parent==g.id then revoke(s,child,result,reason) end end
end
local function suspend(g,result,reason)
    if g.status=='valid' then g.status='suspended'; g.reason=reason; effect(result,'suspended',g.id,reason) end
end
local function reject(reason) return {ok=false,reason=reason,effects={}} end
local function identity(g,p)
    return type(p)=='table' and p.entity==g.entity and p.marker_revision==g.marker_revision and
        p.revision==g.revision and p.first==g.first and p.last==g.last
end

function M.new(opts)
    opts=opts or {}; assert(opts.epoch==nil or scalar(opts.epoch),'invalid epoch')
    local limit=opts.max_dependencies or 256
    assert(integer(limit) and limit<=256,'invalid dependency limit')
    local doc={}; states[doc]={epoch=opts.epoch or id(),attached=true,generations={},grants={},max_dependencies=limit}
    return doc
end

function M.snapshot(doc) return copy(state(doc)) end

function M.resolve(doc,request,current)
    local s=state(doc)
    if type(request)~='table' or not s.attached or request.epoch~=s.epoch then return reject('epoch') end
    local g=s.grants[request.grant]
    if not g or g.generation~=request.generation or g.entity~=request.entity or not s.generations[g.generation] then
        return reject('ownership')
    end
    if g.status~='valid' then return reject(g.status) end
    if request.revision~=g.revision then return reject('revision') end
    local result={ok=true,effects={}}
    if not identity(g,current) then revoke(s,g,result,'identity'); result.ok=false; result.reason='identity'; return result end
    if current.confirmed~=true then suspend(g,result,'uncertain'); result.ok=false; result.reason='uncertain'; return result end
    if request.first~=nil or request.last~=nil then
        if not range(request) or not writable(g,request) then return reject('outside grant') end
    elseif #g.slots~=1 or not contains(g.slots[1],g) then return reject('patch range required') end
    result.epoch=s.epoch; result.grant=g.id; result.generation=g.generation; result.entity=g.entity
    result.first=g.first; result.last=g.last; result.revision=g.revision; result.slots=copy(g.slots)
    return result
end

local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function exclude(slots,child)
    local out={}
    for _,slot in ipairs(slots) do
        if not overlaps(slot,child) then out[#out+1]=slot
        else
            if slot.first<child.first then out[#out+1]={first=slot.first,last=child.first,
                open_first=slot.open_first,open_last=true} end
            if child.last<slot.last then out[#out+1]={first=child.last,last=slot.last,
                open_first=true,open_last=slot.open_last} end
        end
    end
    return out
end
local function move(p,edit)
    local delta=edit.new_bytes-(edit.last-edit.first)
    local function endpoint(x,right)
        if x<edit.first then return x end
        if x>edit.last then return x+delta end
        return edit.first+(right and edit.new_bytes or 0)
    end
    p.first=endpoint(p.first,p.open_first); p.last=endpoint(p.last,not p.open_last)
end

function M.transition(doc,event)
    local s=state(doc)
    if type(event)~='table' then return reject('invalid event') end
    if not s.attached then return reject('detached') end
    if event.epoch~=nil and event.epoch~=s.epoch then return reject('epoch') end
    local kind=event.kind; local result={ok=true,effects={}}
    if kind=='register_generation' then
        if count(s.generations)>=4 then return reject('generation limit') end
        local deps=event.dependencies or {}
        if type(deps)~='table' or #deps>s.max_dependencies then return reject('dependency limit') end
        for k,p in pairs(deps) do if not integer(k) or k<1 or k>#deps or not range(p) then return reject('invalid dependency') end end
        local valid,input=pcall(copy,event.input_snapshot,4096)
        if not valid then return reject('invalid input snapshot') end
        local captured={}; for i,p in ipairs(deps) do captured[i]={first=p.first,last=p.last} end
        local gid=id(); s.generations[gid]={id=gid,input_snapshot=input,dependencies=captured,stale=false}
        result.generation=gid
    elseif kind=='acquire' then
        if not s.generations[event.generation] then return reject('generation') end
        local regions=event.regions
        local live=0; for _,g in pairs(s.grants) do if g.status~='revoked' then live=live+1 end end
        if type(regions)~='table' or #regions==0 or #regions+live>16 then return reject('grant limit') end
        for k,p in pairs(regions) do
            if not integer(k) or k<1 or k>#regions or not proof(p) then return reject('invalid region') end
        end
        local parent=event.parent and s.grants[event.parent]
        if event.parent and (not parent or parent.status~='valid' or parent.generation~=event.generation) then return reject('parent') end
        for i,p in ipairs(regions) do
            if parent and not writable(parent,p) then return reject('outside parent') end
            for j=1,i-1 do if overlaps(p,regions[j]) then return reject('overlap') end end
            for _,g in pairs(s.grants) do
                if g.status~='revoked' and g~=parent then
                    for _,slot in ipairs(g.slots) do if overlaps(p,slot) then return reject('overlap') end end
                end
            end
        end
        local slots=parent and parent.slots
        if slots then
            for _,p in ipairs(regions) do slots=exclude(slots,p) end
            if #slots>17 then return reject('parent slot limit') end
        end
        -- Revoked IDs are never reused; missing authority fails closed without a
        -- growing tombstone registry. Keep their effects in the caller's event log.
        for gid,g in pairs(s.grants) do if g.status=='revoked' then s.grants[gid]=nil end end
        result.grants={}
        for _,p in ipairs(regions) do
            local gid=id(); s.grants[gid]={id=gid,generation=event.generation,entity=p.entity,
                marker_revision=p.marker_revision,revision=p.revision,first=p.first,last=p.last,
                slots={{first=p.first,last=p.last}},status='valid',parent=event.parent}
            result.grants[#result.grants+1]=gid
        end
        if parent then parent.slots=slots end
    elseif kind=='observed_edit' then
        if not range(event) or not integer(event.new_bytes) or (event.revision~=nil and not integer(event.revision)) then
            return reject('invalid edit')
        end
        local owner=s.grants[event.owner_grant]
        if owner and (owner.status~='valid' or not writable(owner,event)) then owner=nil end
        for _,g in pairs(s.grants) do
            if g.status~='revoked' then
                for _,slot in ipairs(g.slots) do
                    if overlaps(slot,event) and g~=owner then revoke(s,g,result,'output edit'); break end
                end
            end
        end
        for _,g in pairs(s.grants) do
            local first,last=g.first,g.last
            move(g,event); for _,slot in ipairs(g.slots) do move(slot,event) end
            -- Plans contain absolute byte coordinates. A disjoint edit moving
            -- this grant invalidates old plans without revoking the writer.
            if g.status~='revoked' and (g==owner or first~=g.first or last~=g.last) then
                g.revision=math.max(g.revision+1,g==owner and event.revision or 0)
            end
        end
        for _,gen in pairs(s.generations) do
            for _,dep in ipairs(gen.dependencies) do
                if overlaps(dep,event) and not gen.stale then gen.stale=true; effect(result,'stale',gen.id,'input edit') end
                move(dep,event)
            end
        end
    elseif kind=='uncertain' then
        if not range(event) then return reject('invalid uncertainty') end
        for _,g in pairs(s.grants) do if overlaps(g,event) then suspend(g,result,'structural uncertainty') end end
    elseif kind=='reconcile' then
        if type(event.proofs)~='table' then return reject('invalid proofs') end
        for gid,g in pairs(s.grants) do
            local p=event.proofs[gid]
            if p and g.status~='revoked' then
                if not identity(g,p) then revoke(s,g,result,'identity')
                elseif p.confirmed==true then
                    if g.status=='suspended' then effect(result,'resumed',g.id,'confirmed identity') end
                    g.status='valid'; g.reason=nil
                else suspend(g,result,'structural uncertainty') end
            end
        end
    elseif kind=='revoke' then
        local g=s.grants[event.grant]; if not g then return reject('grant') end
        revoke(s,g,result,'explicit revoke')
    elseif kind=='finish_generation' then
        if not s.generations[event.generation] then return reject('generation') end
        for gid,g in pairs(s.grants) do
            if g.generation==event.generation then revoke(s,g,result,'generation finished'); s.grants[gid]=nil end
        end
        s.generations[event.generation]=nil
    elseif kind=='reload' or kind=='detach' then
        if event.next_epoch~=nil and (not scalar(event.next_epoch) or event.next_epoch==s.epoch) then return reject('invalid epoch') end
        for _,g in pairs(s.grants) do revoke(s,g,result,kind) end
        s.grants={}; s.generations={}; s.epoch=event.next_epoch or id(); s.attached=kind~='detach'; result.epoch=s.epoch
    else return reject('unknown event') end
    return result
end

return M
