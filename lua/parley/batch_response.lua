-- Document proof and generation effects for the pure batch reducer. The host
-- starts the same captured single-response path and reports positive terminal IO.
local D=require('parley.document')
local B=require('parley.batch')
local M={}
local private=setmetatable({},{__mode='k'})
local serial=0
local pump,queue,retire
local function turn_budget()return {queries=0,nodes=0,entries=0}end
local function get(job)return assert(private[job],'invalid response batch')end
local function transition(s,event)
    local view=B.snapshot(s.state);event.epoch=view.epoch;event.batch=view.batch
    local next_state,result=B.transition(s.state,event);s.state=next_state
    return result
end
local function remember(s,record)
    s.serial=s.serial+1
    local revision=tostring(s.serial)
    s.tokens[revision]=record
    return revision
end
local function query(s,method,value,kind)
    local turn=s.turn;local opts
    if turn then
        if turn.queries>=8 or turn.nodes>=8192 or turn.entries>=16384 then return {status='yield'}end
        opts={budget_nodes=math.min(4096,8192-turn.nodes),budget_entries=math.min(8192,16384-turn.entries)}
        turn.queries=turn.queries+1
    end
    local result
    if method=='capture' then result=D.capture_revision(s.doc,value,kind,opts)
    else result=D.validate_revision(s.doc,value,opts)end
    if turn then
        turn.nodes=turn.nodes+(result.work and result.work.nodes_visited or 0)
        turn.entries=turn.entries+(result.work and result.work.entries_visited or 0)
        if result.status=='budget' and (opts.budget_nodes<4096 or opts.budget_entries<8192)then
            return {status='yield'}
        end
    end
    return result
end
local function capture(s,entity,kind)
    local result=query(s,'capture',entity,kind)
    if result.status~='ready' then return nil,result.status end
    return remember(s,{token=result.token})
end
local function validate(s,revision)
    local record=s.tokens[revision]
    if record and record.status then return {status=record.status} end
    return query(s,'validate',record and record.token)
end
local function prune(s)
    local view=B.snapshot(s.state);local keep={}
    for i=view.completed+1,#view.selection do keep[view.selection[i].revision]=true end
    for _,revision in pairs(view.contexts)do keep[revision]=true end
    for revision in pairs(s.tokens)do if not keep[revision]then s.tokens[revision]=nil end end
end
local function changed(s,validation_result)
    if s.opts.changed then pcall(s.opts.changed,B.snapshot(s.state),validation_result)end
end
local function begin_validation(s,mode,adopt,restarts)
    local view=B.snapshot(s.state)
    local pass={mode=mode,adopt=adopt,edits=s.edits,restarts=restarts or 0,index=1,items={},
        proof={epoch=tostring(D.snapshot(s.doc).epoch),questions={},contexts={}}}
    for i=view.completed+1,#view.selection do
        local item=view.selection[i]
        pass.items[#pass.items+1]={entity=item.entity,revision=item.revision,kind='question',group='questions'}
    end
    for entity,revision in pairs(view.contexts)do
        pass.items[#pass.items+1]={entity=entity,revision=revision,kind='context',group='contexts'}
    end
    s.validation=pass;return pass
end
local function validation_slice(s)
    local pass=s.validation
    if pass.edits~=s.edits then return 'stale' end
    while pass.index<=#pass.items do
        local item=pass.items[pass.index];local result
        if not item.adopting then
            result=validate(s,item.revision)
            if result.status=='conflict' and pass.adopt then item.adopting=true end
        end
        if item.adopting then
            local revision,why=capture(s,item.entity,item.kind)
            result=revision and {status='valid',revision=revision} or {status=why}
        end
        if s.disposed or pass.edits~=s.edits then return 'stale' end
        if result.status=='yield' then return 'yield' end
        if result.status=='opaque' or result.status=='budget' then return 'wait' end
        pass.proof[item.group][item.entity]={status=result.status,revision=result.revision or item.revision}
        pass.index=pass.index+1
    end
    return 'ready'
end
local function advance_validation(s)
    local pass=s.validation;local status=validation_slice(s)
    if s.disposed then return end
    if status=='stale' then
        s.validation=nil;prune(s)
        if pass.restarts==0 then
            begin_validation(s,pass.mode,pass.adopt,1);queue(s)
            return {accepted=true,pending=true,effects={}}
        end
        transition(s,{type='cancel'})
        if pass.mode~='resume'then changed(s)end
        return {accepted=false,effects={},reason='validation interrupted by edits'}
    end
    if status=='yield' or status=='wait' then
        if status=='yield'then queue(s)end
        return {accepted=true,pending=true,effects={},reason=status=='wait' and 'revision unavailable' or nil}
    end
    s.validation=nil
    local result=transition(s,{type=pass.mode,evidence=pass.proof,accept_changes=pass.adopt})
    if pass.mode=='resume' then
        if result.accepted then s.ready_proof={edits=pass.edits,proof=pass.proof};queue(s)end
        prune(s)
    end
    return result
end
local function finish(s)
    local pending=s.finished
    if not pending then return true end
    local revision=pending.context_revision
    local context_status
    if pending.outcome=='success' then
        if not revision then
            if pending.edits~=s.edits then revision=remember(s,{status='conflict'})
            else
                local why;revision,why=capture(s,pending.entity,'context')
                if why=='yield'then queue(s);return false end
                if not revision and (why=='opaque' or why=='budget')then return false end
                if not revision then revision=remember(s,{status=why or 'obsolete'})end
            end
            pending.context_revision=revision
        end
        local checked=validate(s,revision)
        if checked.status=='yield'then queue(s);return false end
        if checked.status=='opaque' or checked.status=='budget'then return false end
        context_status=checked.status=='valid' and 'valid' or 'conflict'
    end
    s.finished=nil;s.operation=nil
    transition(s,{type='finished',leg=pending.leg,outcome=pending.outcome,context_revision=revision,context_status=context_status})
    prune(s);changed(s)
    return true
end
local function run(s,effect)
    local active={leg=effect.leg,entity=effect.entity};s.operation=active
    local function done(result)
        if s.disposed or s.operation~=active or active.finished then return end
        active.finished=true
        local pending={leg=active.leg,entity=active.entity,edits=s.edits,
            outcome=type(result)=='table' and result.outcome or 'unknown'}
        if type(pending.outcome)~='string' or #pending.outcome==0 or #pending.outcome>256 then pending.outcome='unknown'end
        if pending.outcome=='success' then pending.context_revision=capture(s,active.entity,'context')end
        s.finished=pending
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
    if active.cancel_requested and handle and handle.cancel then pcall(handle.cancel,handle)end
end
local function pump_once(s)
    if not finish(s)then return end
    local view=B.snapshot(s.state)
    if view.phase=='completed' then
        retire(s,'completed');return
    end
    if view.phase~='ready' and not s.validation then return end
    local result
    local validating_resume=s.validation and s.validation.mode=='resume'
    if s.ready_proof and s.ready_proof.edits==s.edits and view.phase=='ready' then
        result=transition(s,{type='start',evidence=s.ready_proof.proof});s.ready_proof=nil
    else
        s.ready_proof=nil
        if not s.validation then begin_validation(s,'start',false)end
        result=advance_validation(s)
    end
    if not result or result.pending or s.disposed then return end
    for _,effect in ipairs(result.effects)do if effect.type=='start_generation' then run(s,effect)end end
    if result.accepted or validating_resume then changed(s,validating_resume and result or nil)end
end
pump=function(s)
    if s.disposed then return end
    s.queued=false
    local previous=s.turn;s.turn=previous or turn_budget()
    pump_once(s);s.turn=previous
end
queue=function(s)
    if s.disposed or s.queued then return end
    s.queued=true;s.opts.schedule(function()pump(s)end)
end
function M.start(doc,opts)
    assert(type(opts)=='table' and type(opts.start)=='function','batch generation starter required')
    serial=serial+1
    local s={doc=doc,opts={start=opts.start,changed=opts.changed,retired=opts.retired,
        schedule=opts.schedule or vim.schedule},tokens={},serial=0,edits=0}
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
        if event.kind=='detach' or event.kind=='reload' then retire(s,event.kind);return end
        if event.kind=='edit' then s.edits=s.edits+1 end
        queue(s)
    end)
    queue(s);return job
end
function M.snapshot(job)return B.snapshot(get(job).state)end
function M.cancel(job)
    local s=get(job);if s.disposed then return {accepted=false,effects={}}end
    local result=transition(s,{type='cancel'})
    s.validation=nil;s.ready_proof=nil;prune(s)
    for _,effect in ipairs(result.effects)do
        local op=s.operation
        if effect.type=='cancel_generation' and op and op.leg==effect.leg then
            op.cancel_requested=true
            if op.handle and op.handle.cancel then pcall(op.handle.cancel,op.handle)end
        end
    end
    changed(s);return result
end
function M.resume(job,opts)
    -- accepted+pending acknowledges staged validation only. The reducer stays
    -- paused until every proof is current; callers must observe later state.
    -- Small, available passes retain the immediate accepted/rejected contract.
    local s=get(job);if s.disposed then return {accepted=false,effects={},reason='disposed'}end
    local adopt=opts and opts.accept_changes==true
    local view=B.snapshot(s.state)
    if view.phase~='paused' or view.active or view.unknown then return transition(s,{type='resume'})end
    if s.validation then return {accepted=false,effects={},reason='validation pending'}end
    local pass=begin_validation(s,'resume',adopt)
    local previous=s.turn;s.turn=previous or turn_budget()
    local result=advance_validation(s);s.turn=previous
    if result and result.pending and result.reason=='revision unavailable' and #pass.items<=8 then
        s.validation=nil;prune(s)
        return {accepted=false,effects={},reason=result.reason}
    end
    if result and result.accepted and not result.pending then changed(s)end
    return result
end
retire=function(s,reason)
    if s.disposed then return end
    local result=transition(s,{type='cancel'})
    local operation,callback=s.operation,s.opts.retired
    s.disposed=true
    if s.unsubscribe then s.unsubscribe();s.unsubscribe=nil end
    s.tokens={};s.opts={};s.operation=nil;s.finished=nil;s.doc=nil;s.validation=nil;s.ready_proof=nil
    -- Retire local ownership before callbacks. Session still owns physical IO;
    -- its late terminal notification cannot advance this retired batch.
    for _,effect in ipairs(result.effects)do
        if effect.type=='cancel_generation' and operation and operation.leg==effect.leg then
            operation.cancel_requested=true
            if operation.handle and operation.handle.cancel then pcall(operation.handle.cancel,operation.handle)end
        end
    end
    if callback then pcall(callback,reason)end
end
function M.dispose(job)retire(get(job),'disposed')end
return M
