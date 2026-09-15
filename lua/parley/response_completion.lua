-- Finish against current indexed structure. Only the short new prompt is written;
-- human suffixes, annotations, whitespace and footnotes retain their exact bytes.
local D=require('parley.document')
local Deferred=require('parley.deferred_work')
local M={}
local states=setmetatable({},{__mode='k'})
local function state(op)return assert(states[op],'invalid response completion')end
local function snapshot(s)return {status=s.status,reason=s.reason,accepted_bytes=s.accepted}end
local function retire(s,status,reason)
    if s.status~='more'then return false end
    local doc,grant,done,cursor=s.doc,s.extra,s.done,s.cursor
    s.status=status;s.reason=reason;s.doc=nil;s.ctx=nil;s.done=nil;s.extra=nil;s.cursor=nil
    if s.off then s.off();s.off=nil end
    if s.work then s.work:close();s.work=nil end
    if cursor then D.replace_cancel(doc,cursor)end
    if grant then D.transition(doc,{kind='revoke',grant=grant})end
    if done then pcall(done,(status=='applied' or status=='skipped') and 'applied' or 'failed')end
    return true
end
function M.snapshot(op)return snapshot(state(op))end
function M.cancel(op,resolved)
    local changed=retire(state(op),'cancelled','cancelled')
    if resolved then resolved()end
    return changed
end
local function repair(s)
    if D.repair_step(s.doc).status=='detached'then retire(s,'cancelled','detached')end
    return snapshot(s)
end
function M.step(op)
    local s=state(op)
    if s.status~='more'then return snapshot(s)end
    local ctx=s.ctx
    if ctx.cancelled and ctx.cancelled()then M.cancel(op);return snapshot(s)end
    local current=D.snapshot(s.doc)
    local grant=current.grants[ctx.grant]
    if current.epoch~=ctx.epoch or not grant or grant.status=='revoked'
        or grant.generation~=ctx.generation or grant.entity~=ctx.entity then
        retire(s,'cancelled','target revoked');return snapshot(s)
    end
    local tip=D.byte_position(s.doc,grant.last)
    if not tip then return repair(s)end
    local target=D.completion(s.doc,ctx.entity,tip.row)
    if target.status=='opaque' or target.status=='budget'then return repair(s)end
    if target.status=='skipped'then retire(s,'skipped');return snapshot(s)end
    if target.status~='ready'then retire(s,'cancelled',target.status);return snapshot(s)end
    if s.extra then
        local extra=current.grants[s.extra]
        if not extra or extra.status=='revoked' or extra.last~=target.point then
            local old=s.extra;s.extra=nil;D.transition(s.doc,{kind='revoke',grant=old})
        else grant=extra end
    end
    local interior=target.point>=grant.first and target.point<grant.last
    if target.point~=grant.last and not interior then
        local acquired=D.transition(s.doc,{kind='acquire',generation=ctx.generation,regions={{entity=ctx.entity,
            first=target.point,last=target.point,revision=1,marker_revision=1,confirmed=true}}})
        if not acquired.ok then retire(s,'cancelled',acquired.reason);return snapshot(s)end
        s.extra=acquired.grants[1];grant=D.snapshot(s.doc).grants[s.extra]
    end
    -- Zero-source finite replacement retains no inserted bytes. Its private
    -- receipt prevents reconciliation from treating our new question as damage.
    if not s.cursor then
        local cursor,reason=D.insert_released_new(s.doc,{epoch=ctx.epoch,generation=ctx.generation,entity=ctx.entity,
            grant=grant.id,revision=grant.revision,operation=ctx.operation,bytes=s.bytes,point=target.point})
        if not cursor then
            if reason=='uncertain' or reason=='suspended'then return repair(s)end
            retire(s,'cancelled',reason);return snapshot(s)
        end
        s.cursor=cursor
    end
    local applied=D.replace_step(s.doc,s.cursor)
    s.accepted=s.accepted+(applied.accepted_bytes or 0)
    if s.status~='more'then return snapshot(s)end
    if applied.status=='applied'then s.cursor=nil;retire(s,'applied')
    elseif applied.status=='suspended'then return repair(s)
    elseif applied.status~='more'then retire(s,'cancelled',applied.error or applied.status)end
    return snapshot(s)
end
function M.start(doc,ctx,done,opts)
    opts=opts or {}
    if type(ctx)~='table' or type(done)~='function' or type(opts.user_prefix)~='string'
        or #opts.user_prefix==0 or #opts.user_prefix>1024 or opts.user_prefix:find('[\r\n]')then
        return nil,'invalid completion'
    end
    local op={}
    local s={doc=doc,ctx={epoch=ctx.epoch,generation=ctx.generation,grant=ctx.grant,entity=ctx.entity,
        operation=ctx.operation,cancelled=ctx.cancelled},done=done,status='more',accepted=0,
        bytes='\n\n'..opts.user_prefix..'\n'}
    states[op]=s
    function op:cancel(resolved)return M.cancel(self,resolved)end
    s.work=Deferred.new(function()return M.step(op).status=='more'end)
    s.off=D.subscribe(doc,function(event)
        if event.kind=='reload' or event.kind=='detach'then retire(s,'cancelled',event.kind)end
    end)
    if opts.schedule~=false then s.work:request()end
    return op
end
return M
