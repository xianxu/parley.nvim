-- Document proof and generation effects for the pure batch reducer. The host
-- starts the same captured single-response path and reports positive terminal IO.
local D=require('parley.document')
local B=require('parley.batch')
local M={}
local private=setmetatable({},{__mode='k'})
local serial=0
local pump,queue
local function get(job)return assert(private[job],'invalid response batch')end
local function transition(s,event)
    local view=B.snapshot(s.state);event.epoch=view.epoch;event.batch=view.batch
    local next_state,result=B.transition(s.state,event);s.state=next_state
    return result
end
local function capture(s,entity,kind)
    local result=D.capture_revision(s.doc,entity,kind)
    if result.status~='ready' then return nil,result.status end
    s.serial=s.serial+1
    local revision=tostring(s.serial)
    s.tokens[revision]=result.token
    return revision
end
local function evidence(s,adopt)
    local view=B.snapshot(s.state)
    local proof={epoch=tostring(D.snapshot(s.doc).epoch),questions={},contexts={}}
    local function check(entity,revision,kind)
        local result=D.validate_revision(s.doc,s.tokens[revision])
        if result.status=='conflict' and adopt then
            local fresh,why=capture(s,entity,kind)
            if fresh then return {status='valid',revision=fresh} end
            return {status=why}
        end
        return {status=result.status,revision=revision}
    end
    for i=view.completed+1,#view.selection do
        local item=view.selection[i];proof.questions[item.entity]=check(item.entity,item.revision,'question')
    end
    for entity,revision in pairs(view.contexts)do proof.contexts[entity]=check(entity,revision,'context')end
    return proof
end
local function prune(s)
    local view=B.snapshot(s.state);local keep={}
    for i=view.completed+1,#view.selection do keep[view.selection[i].revision]=true end
    for _,revision in pairs(view.contexts)do keep[revision]=true end
    for revision in pairs(s.tokens)do if not keep[revision]then s.tokens[revision]=nil end end
end
local function changed(s)
    if s.opts.changed then s.opts.changed(B.snapshot(s.state))end
end
local function finish(s)
    local pending=s.finished
    if not pending then return true end
    local revision
    if pending.outcome=='success' then
        local why;revision,why=capture(s,pending.entity,'context')
        if not revision and (why=='opaque' or why=='budget')then return false end
        if not revision then pending.outcome='context unavailable' end
    end
    s.finished=nil;s.operation=nil
    transition(s,{type='finished',leg=pending.leg,outcome=pending.outcome,context_revision=revision})
    prune(s);changed(s)
    return true
end
local function run(s,effect)
    local active={leg=effect.leg,entity=effect.entity};s.operation=active
    local function done(result)
        if s.disposed or s.operation~=active or active.finished then return end
        active.finished=true
        s.finished={leg=active.leg,entity=active.entity,outcome=type(result)=='table' and result.outcome or 'unknown'}
        queue(s)
    end
    local ok,handle,reason=pcall(s.opts.start,effect.entity,done)
    -- A throw may follow an external effect. Keep ownership unresolved unless
    -- the callback positively reported completion; never retry through a throw.
    if not ok then
        active.unknown=true;transition(s,{type='cancel'});changed(s);return
    end
    active.handle=handle
    if not handle and not active.finished then done({outcome=reason or 'start refused'})end
    if active.cancel_requested and handle and handle.cancel then handle:cancel()end
end
pump=function(s)
    if s.disposed then return end
    s.queued=false
    if not finish(s)then return end
    local view=B.snapshot(s.state)
    if view.phase=='completed' then
        if s.unsubscribe then s.unsubscribe();s.unsubscribe=nil end
        s.tokens={};s.opts.start=nil;return
    end
    if view.phase~='ready' then return end
    local result=transition(s,{type='start',evidence=evidence(s,false)})
    for _,effect in ipairs(result.effects)do if effect.type=='start_generation' then run(s,effect)end end
    if result.accepted then changed(s)end
end
queue=function(s)
    if s.disposed or s.queued then return end
    s.queued=true;s.opts.schedule(function()pump(s)end)
end
function M.start(doc,opts)
    assert(type(opts)=='table' and type(opts.start)=='function','batch generation starter required')
    serial=serial+1
    local s={doc=doc,opts={start=opts.start,changed=opts.changed,schedule=opts.schedule or vim.schedule},tokens={},serial=0}
    local spec={epoch=tostring(D.snapshot(doc).epoch),batch='batch:'..serial,selection={},contexts={}}
    for _,entity in ipairs(opts.selection or {})do
        local revision,why=capture(s,entity,'question');if not revision then return nil,why end
        spec.selection[#spec.selection+1]={entity=entity,revision=revision}
    end
    for _,entity in ipairs(opts.contexts or {})do
        local revision,why=capture(s,entity,'context');if not revision then return nil,why end
        spec.contexts[#spec.contexts+1]={entity=entity,revision=revision}
    end
    s.state=B.new(spec)
    local job={};private[job]=s
    s.unsubscribe=D.subscribe(doc,function(event)
        if event.kind=='detach' or event.kind=='reload' then M.cancel(job)end
        queue(s)
    end)
    queue(s);return job
end
function M.snapshot(job)return B.snapshot(get(job).state)end
function M.cancel(job)
    local s=get(job);if s.disposed then return {accepted=false,effects={}}end
    local result=transition(s,{type='cancel'})
    for _,effect in ipairs(result.effects)do
        local op=s.operation
        if effect.type=='cancel_generation' and op and op.leg==effect.leg then
            op.cancel_requested=true
            if op.handle and op.handle.cancel then op.handle:cancel()end
        end
    end
    changed(s);return result
end
function M.resume(job,opts)
    local s=get(job);if s.disposed then return {accepted=false,effects={},reason='disposed'}end
    local adopt=opts and opts.accept_changes==true
    local result=transition(s,{type='resume',evidence=evidence(s,adopt),accept_changes=adopt})
    prune(s);if result.accepted then changed(s);queue(s)end
    return result
end
function M.dispose(job)
    local s=get(job);if s.disposed then return end
    M.cancel(job);s.disposed=true
    if s.unsubscribe then s.unsubscribe();s.unsubscribe=nil end
    s.tokens={};s.opts={};s.operation=nil;s.finished=nil;s.doc=nil
end
return M
