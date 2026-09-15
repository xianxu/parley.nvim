-- Resolve a command-time selection before the generation runner admits IO.
-- Source guards follow native edits; structural repair supplies identity only.
local D=require('parley.document')
local Deferred=require('parley.deferred_work')
local M={}
local states=setmetatable({},{__mode='k'})
local pending=setmetatable({},{__mode='k'})
local function state(target)return assert(states[target],'invalid response target')end
local function scalar(value)return value==nil or type(value)=='string' and #value<=256
    or type(value)=='number' and value>=0 and value<math.huge and value%1==0 end
local function same_position(a,b)return type(a)=='table' and type(b)=='table' and a.row==b.row and a.col==b.col end
local function snapshot(s)return {status=s.status,reason=s.reason,input_stale=s.input_stale}end
local function retire(s,status,reason,result)
    if s.status~='waiting' then return snapshot(s) end
    s.status=status;s.reason=reason
    local callbacks=s.callbacks;s.callbacks=nil
    if s.off then s.off();s.off=nil end
    if s.work then s.work:close();s.work=nil end
    D.cancel_user(s.doc,s.guard);s.guard=nil
    local group=pending[s.doc]
    if group then group[s.key]=nil;if not next(group)then pending[s.doc]=nil end end
    s.doc=nil;s.key=nil
    if status=='ready' and callbacks.ready then callbacks.ready(result)
    elseif status=='cancelled' and callbacks.cancelled then callbacks.cancelled(reason)end
    return snapshot(s)
end
function M.snapshot(target)return snapshot(state(target))end
function M.cancel(target,reason)
    local s=state(target);if s.status~='waiting'then return false end
    retire(s,'cancelled',reason or 'cancelled');return true
end
local function readiness(s,resolved)
    local question,output=resolved.regions[1],resolved.regions[2]
    local marker=D.query(s.doc,question.first.row,question.first.row+1)[1]
    if not marker or marker.opaque or not marker.metadata or not marker.metadata.confirmed then return nil end
    local semantic=marker.metadata.semantic
    if not semantic or not semantic.exchange_start or marker.metadata.token.kind~='user' then return false,'question changed' end
    local exchange=D.exchange(s.doc,question.first.row,{budget_nodes=4096,budget_entries=8192,cursor=s.cursor})
    s.cursor=exchange.cursor
    if exchange.status=='opaque' or exchange.status=='budget' or exchange.status=='stale' then return nil end
    if exchange.status~='ready' or exchange.first~=question.first.row then return false,'exchange changed' end
    local qend=D.query(s.doc,question.last.row,question.last.row+1)[1]
    local last=D.query(s.doc,output.last.row,output.last.row+1)[1]
    if not qend or qend.opaque or not qend.metadata or not qend.metadata.confirmed
        or not last or last.opaque or not last.metadata or not last.metadata.confirmed then return nil end
    if not qend.metadata.semantic or qend.metadata.semantic.role~='question'
        or question.last.byte~=qend.end_byte-1 or output.first.byte~=question.last.byte
        or output.last.row>=exchange.last or output.last.byte~=last.end_byte-1 then return false,'range changed' end
    local dependencies={{first=s.input_prefix and 0 or question.first.byte,last=question.last.byte}}
    for i=3,#resolved.regions do local r=resolved.regions[i];dependencies[#dependencies+1]={first=r.first.byte,last=r.last.byte}end
    return {entity=marker.handle,first=output.first.byte,last=output.last.byte,question_row=question.first.row,
        regions=resolved.regions,dependencies=dependencies,input_ref=s.input_ref,dependencies_ref=s.dependencies_ref,
        input_stale=s.input_stale}
end
function M.step(target)
    local s=state(target);if s.status~='waiting' then return snapshot(s)end
    local resolved=D.resolve_user(s.doc,s.guard)
    if not resolved then return retire(s,'cancelled','source changed')end
    local result=D.repair_step(s.doc)
    if result.status=='detached' then return retire(s,'cancelled','detached')end
    if s.status~='waiting' then return snapshot(s)end
    resolved=D.resolve_user(s.doc,s.guard)
    if not resolved then return retire(s,'cancelled','source changed')end
    local ready,reason=readiness(s,resolved)
    if ready==false then return retire(s,'cancelled',reason)end
    if ready then
        -- No yield between the final native proof check and runner acquisition
        -- in the host's ready callback. A target is not itself a write grant.
        if not D.resolve_user(s.doc,s.guard)then return retire(s,'cancelled','source changed')end
        return retire(s,'ready',nil,ready)
    end
    return snapshot(s)
end
function M.start(doc,spec,callbacks)
    callbacks=callbacks or {}
    if type(spec)~='table' or type(spec.question)~='table' or type(spec.output)~='table'
        or type(spec.question.first)~='table' or type(spec.output.last)~='table'
        or not same_position(spec.question.last,spec.output.first) or spec.question.first.col~=0
        or spec.input_prefix~=nil and type(spec.input_prefix)~='boolean'
        or not scalar(spec.input_ref) or not scalar(spec.dependencies_ref) then return nil,'invalid target'end
    if type(callbacks)~='table' or callbacks.ready~=nil and type(callbacks.ready)~='function'
        or callbacks.cancelled~=nil and type(callbacks.cancelled)~='function' then return nil,'invalid callbacks'end
    local group=pending[doc] or {};local count=0
    for _ in pairs(group)do count=count+1 end
    if count>=4 then return nil,'target limit'end
    local regions={spec.question,spec.output};for _,r in ipairs(spec.guards or {})do regions[#regions+1]=r end
    local guard,reason=D.capture_user(doc,{operation=spec.operation,regions=regions})
    if not guard then return nil,reason end
    local target={};local key={}
    local scheduling=spec.schedule~=false
    local s={doc=doc,key=key,guard=guard,status='waiting',input_stale=false,
        callbacks={ready=callbacks.ready,cancelled=callbacks.cancelled},
        input_ref=spec.input_ref,dependencies_ref=spec.dependencies_ref,input_prefix=spec.input_prefix}
    states[target]=s;group[key]=true;pending[doc]=group
    s.work=Deferred.new(function()return M.step(target).status=='waiting'end)
    s.off=D.subscribe(doc,function(event)
        if s.status~='waiting'then return end
        if event.kind=='reload' or event.kind=='detach' then retire(s,'cancelled',event.kind);return end
        if event.kind=='edit' then
            s.input_stale=true;s.cursor=nil
            if not D.resolve_user(doc,guard)then retire(s,'cancelled','source changed');return end
        end
        if scheduling and s.work then s.work:request()end
    end)
    if scheduling then s.work:request()end
    return target
end
return M
