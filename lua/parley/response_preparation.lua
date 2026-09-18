-- Finite preparation grants exclude annotation source. The frozen plan chooses
-- payloads; only the coordinator's current grant can choose mutation locations.
local D=require('parley.document')
local Deferred=require('parley.deferred_work')
local M={}
local operations=setmetatable({},{__mode='k'})
local function state(op)return assert(operations[op],'invalid response preparation')end
local function result(s)return {status=s.status,reason=s.reason,gap=s.index,
    removed_bytes=s.removed,accepted_bytes=s.accepted}end

-- Regions are relative to captured question EOL. Source capture/admission is
-- the host's responsibility; these numbers must never be rebased from a fresh
-- post-IO snapshot. The final source LF stays OUTSIDE the output grant, matching
-- response_target's physical-EOL endpoint (including canonical document EOF).
function M.plan(layout,opts)
    opts=opts or {}
    assert(type(layout)=='table' and layout.target and layout.gaps and #layout.gaps>0,'layout required')
    local origin=layout.target.first_byte-1
    assert(origin>=0,'question end required')
    local out={regions={},gaps={},bootstrap_newline=opts.bootstrap_newline==true,at_eof=opts.at_eof==true}
    for i,gap in ipairs(layout.gaps)do
        local first=i==1 and origin or gap.first.byte
        local last=gap.last.byte
        local bytes=gap.text
        if i==#layout.gaps then
            last=last-1
            assert(bytes:sub(-1)=='\n','terminal separator required')
            bytes=bytes:sub(1,-2)
        end
        local offset=i==1 and 1 or 0
        assert(last>=first,'invalid source gap')
        out.regions[i]={first_offset=first-origin,last_offset=last-origin}
        out.gaps[i]={first_byte=first,last_byte=last,source_bytes=last-first,
            bytes=bytes,first_offset=offset,
            retain_prefix=i==1 and (#bytes-(i<#layout.gaps and 1 or 0)) or nil}
    end
    if out.gaps[1].source_bytes==0 then out.bootstrap_newline=true end
    return out
end
local function revoke(s,primary)
    for i,id in ipairs(s.grants)do
        if primary or i>1 then D.transition(s.doc,{kind='revoke',grant=id})end
    end
end
local function retire(s,status,reason,done)
    if s.status~='more'then return false end
    s.status=status;s.reason=reason
    if s.cursor then D.replace_cancel(s.doc,s.cursor);s.cursor=nil end
    if s.off then s.off();s.off=nil end
    if s.work then s.work:close();s.work=nil end
    revoke(s,status~='applied')
    local cb,input,doc,primary=s.callbacks,s.input,s.doc,s.grants[1]
    s.doc=nil;s.callbacks=nil;s.input=nil;s.spec=nil;s.ctx=nil;s.grants=nil
    if status=='applied' and cb.prepared then
        local ok,accepted=pcall(cb.prepared,input)
        if not ok or accepted==false then
            s.status='error';s.reason=ok and 'prepared callback refused' or tostring(accepted)
            D.transition(doc,{kind='revoke',grant=primary})
            if cb.failed then pcall(cb.failed,s.reason)end
        end
    elseif status=='error' and cb.failed then pcall(cb.failed,reason)end
    local resolved=done or cb.resolved
    if resolved then resolved()end
    return true
end
function M.snapshot(op)return result(state(op))end
function M.cancel(op,done)
    local s=state(op)
    if s.status~='more'then if done then done()end;return false end
    return retire(s,'cancelled','cancelled',done)
end
local function intent(s,grant,bytes)
    return {epoch=s.ctx.epoch,generation=s.ctx.generation,entity=s.ctx.entity,grant=grant.id,
        revision=grant.revision,operation=s.ctx.operation,bytes=bytes}
end
local function waiting(s)
    local work=D.repair_step(s.doc)
    if work.status=='detached'then retire(s,'cancelled','detached');return result(s)end
    return result(s)
end
function M.step(op)
    local s=state(op)
    if s.status~='more'then return result(s)end
    if s.ctx.cancelled and s.ctx.cancelled()then M.cancel(op);return result(s)end
    local snapshot=D.snapshot(s.doc)
    if snapshot.epoch~=s.ctx.epoch then retire(s,'cancelled','epoch changed');return result(s)end
    local grant=snapshot.grants[s.grants[s.index]]
    if not grant or grant.status=='revoked'then retire(s,'error','preparation grant revoked');return result(s)end
    if s.bootstrap then
        local applied=D.append(s.doc,intent(s,grant,'\n'))
        s.accepted=s.accepted+(applied.accepted_bytes or 0)
        if (applied.accepted_bytes or 0)>0 then s.bootstrap=false end
        if applied.status=='applied' then return result(s)end
        if applied.status=='more' or applied.status=='read' or applied.status=='suspended' or applied.status=='waiting' then return waiting(s)end
        retire(s,'error',applied.reason or applied.error or applied.status);return result(s)
    end
    local gap=s.spec.gaps[s.index]
    if not s.cursor then
        local request=intent(s,grant,gap.bytes)
        request.first_offset=gap.first_offset;request.retain_prefix=gap.retain_prefix
        local cursor,reason=D.replace_new(s.doc,request)
        if not cursor then
            if reason=='uncertain' or reason=='suspended' or reason=='waiting'then return waiting(s)end
            retire(s,'error',reason);return result(s)
        end
        s.cursor=cursor
    end
    local applied=D.replace_step(s.doc,s.cursor)
    s.removed=s.removed+(applied.removed_bytes or 0);s.accepted=s.accepted+(applied.accepted_bytes or 0)
    if applied.status=='applied'then
        s.cursor=nil;s.index=s.index+1
        if s.index>#s.grants then retire(s,'applied')end
    elseif applied.status=='suspended' or applied.status=='waiting'then return waiting(s)
    elseif applied.status~='more'then retire(s,'error',applied.error or applied.status)end
    return result(s)
end
function M.start(doc,ctx,callbacks,spec,opts)
    opts=opts or {};callbacks=callbacks or {}
    if type(callbacks)~='table' then return nil,'invalid callbacks'end
    for _,name in ipairs({'prepared','failed','resolved'})do
        if callbacks[name]~=nil and type(callbacks[name])~='function'then return nil,'invalid callbacks'end
    end
    if type(ctx)~='table' or type(spec)~='table' or type(spec.gaps)~='table'
        or #spec.gaps==0 or #spec.gaps>16
        or ctx.preparation_grants~=nil and type(ctx.preparation_grants)~='table'
        or ctx.cancelled~=nil and type(ctx.cancelled)~='function' then return nil,'invalid preparation' end
    local grants={ctx.grant}
    for _,id in ipairs(ctx.preparation_grants or {})do grants[#grants+1]=id end
    if #grants~=#spec.gaps then return nil,'preparation grant count'end
    local snapshot=D.snapshot(doc);local seen={};local gaps={}
    if snapshot.epoch~=ctx.epoch then return nil,'epoch changed'end
    for i,id in ipairs(grants)do
        local g=snapshot.grants[id];local gap=spec.gaps[i]
        if seen[id] or not g or g.status=='revoked' or g.generation~=ctx.generation or g.entity~=ctx.entity
            or type(gap.bytes)~='string' or #gap.bytes>1048576 or g.last-g.first~=gap.source_bytes then
            return nil,'preparation source or grant changed'
        end
        seen[id]=true
        gaps[i]={bytes=gap.bytes,first_offset=gap.first_offset,retain_prefix=gap.retain_prefix}
    end
    local op={};local s={doc=doc,ctx={epoch=ctx.epoch,generation=ctx.generation,entity=ctx.entity,
        operation=ctx.operation,cancelled=ctx.cancelled},callbacks=callbacks,input=ctx.input,
        grants=grants,spec={gaps=gaps},bootstrap=spec.bootstrap_newline==true,status='more',index=1,removed=0,accepted=0}
    operations[op]=s
    function op:cancel(done)return M.cancel(self,done)end
    s.work=Deferred.new(function()return M.step(op).status=='more'end)
    s.off=D.subscribe(doc,function(event)
        if s.status=='more' and (event.kind=='reload' or event.kind=='detach')then retire(s,'cancelled',event.kind)end
    end)
    if opts.schedule~=false then s.work:request()end
    return op
end
return M
