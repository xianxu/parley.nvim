-- Recovery publication fences preparation. Successful replacement evidence is
-- captured before completion releases generation grants; failed/cancelled output
-- remains inspection/explicit-target recovery, never newly blessed human text.
local D=require('parley.document')
local Store=require('parley.answer_recovery')
local Reader=require('parley.line_reader')
local M={}
local states=setmetatable({},{__mode='k'})
local LIMIT=16*1024*1024
local function state(job)return assert(states[job],'invalid response recovery')end
local function fail(reason)return {ok=false,reason=tostring(reason or 'recovery conflict')}end
local function live(s)
    return s.doc and vim.api.nvim_buf_is_valid(s.buf) and D.get(s.buf)==s.doc
        and D.snapshot(s.doc).epoch==s.epoch
end
local function drop_guard(s,name)
    local token=s[name];s[name]=nil
    if token and s.doc then D.cancel_user(s.doc,token)end
end
local function owner(s,ctx)
    if not live(s) or type(ctx)~='table' or ctx.epoch~=s.epoch
        or s.entity and ctx.entity~=s.entity or ctx.cancelled and ctx.cancelled()then return false end
    local grant=D.snapshot(s.doc).grants[ctx.grant]
    return grant and grant.status=='valid' and grant.entity==ctx.entity and grant.generation==ctx.generation
end
local function contained(s,token,entity)
    local resolved=D.resolve_user(s.doc,token);if not resolved then return nil,'source changed'end
    local region=resolved.regions[1]
    local exchange=D.exchange(s.doc,region.first.row)
    if exchange.status~='ready' or exchange.identity~=entity or region.last.row>exchange.last
        or region.last.row==exchange.last and region.last.col~=0 then return nil,'exchange changed'end
    return resolved
end
local function read(s,token)
    if not live(s)then return nil,'document changed'end
    local proof,err=D.resolve_user(s.doc,token);if not proof then return nil,err end
    local region=proof.regions[1];local first,last=region.first,region.last
    if last.byte-first.byte>LIMIT then return nil,'recovery region limit'end
    local row,col,bytes=first.row,first.col,{}
    local reader=s.reader or Reader.for_buffer(s.buf)
    while row<last.row or row==last.row and col<last.col do
        local length=row==last.row and math.min(4096,last.col-col) or 4096
        local ok,part=pcall(reader.chunk,reader,{row=row,col=col,max_bytes=length})
        if not ok then return nil,part end
        local current=live(s) and D.resolve_user(s.doc,token)
        if not current or not vim.deep_equal(current.regions,proof.regions)then return nil,'source changed during read'end
        bytes[#bytes+1]=part.bytes;col=col+#part.bytes
        if part.eol and row<last.row then bytes[#bytes+1]='\n';row=row+1;col=0
        elseif #part.bytes==0 then return nil,'incomplete recovery read'end
    end
    return table.concat(bytes),proof
end
function M.capture(doc,spec)
    if type(spec)~='table' or not spec.store or not spec.buf or not spec.region
        or not spec.association or not spec.key or D.get(spec.buf)~=doc then return nil,'invalid recovery capture'end
    local token,err=D.capture_user(doc,{operation='answer-recovery-source',regions={spec.region}})
    if not token then return nil,err end
    local job={};local s={status='captured',doc=doc,buf=spec.buf,epoch=D.snapshot(doc).epoch,original=token,
        store=spec.store,key=spec.key,association=vim.deepcopy(spec.association),
        annotations=vim.deepcopy(spec.annotations),reader=spec.reader,on_release=spec.on_release}
    states[job]=s
    s.off=D.subscribe(doc,function(event)
        if event.kind=='detach' or event.kind=='reload'then M.release(job)end
    end)
    return job
end
function M.publish(job,ctx)
    local s=state(job)
    if not s.original or not owner(s,ctx)then return fail('original ownership changed')end
    if not contained(s,s.original,ctx.entity)then return fail('original exchange changed')end
    local bytes,why=read(s,s.original);if not bytes then return fail(why)end
    local result=Store.publish(s.store,{key=s.key,bytes=bytes,annotations=s.annotations,
        association=s.association,replacement={bytes=bytes}})
    if result.ok then s.id=result.id end
    if not result.ok then return result end
    if not owner(s,ctx) or not D.resolve_user(s.doc,s.original)then return fail('source changed during recovery publication')end
    s.entity=ctx.entity;s.generation=ctx.generation
    drop_guard(s,'original');s.annotations=nil;s.reader=nil;s.status='published'
    return result
end
-- Call after the completion edit, but before its done callback releases the
-- current grant. Never infer this region from EOF: host excludes new prompts and
-- trailing footnotes using the current captured exchange identity.
function M.settle(job,ctx,region)
    local s=state(job)
    if not s.id or not owner(s,ctx) or ctx.generation~=s.generation then return fail('replacement ownership changed')end
    local doc=s.doc
    local token,err=D.capture_user(doc,{operation='answer-recovery-settlement',regions={region}})
    if not token then return fail(err)end
    local valid=contained(s,token,s.entity)
    local bytes,why
    if valid then bytes,why=read(s,token)end
    if not bytes then D.cancel_user(doc,token);return fail(why or 'replacement exchange changed')end
    local evidence={bytes=bytes,revision=tostring(vim.api.nvim_buf_get_changedtick(s.buf))}
    local result=Store.update(s.store,s.id,evidence)
    if not result.ok or not owner(s,ctx) or not D.resolve_user(s.doc,token)then
        D.cancel_user(doc,token);return result.ok and fail('replacement changed during publication') or result
    end
    drop_guard(s,'settled');s.settled=token;s.evidence=evidence;s.status='settled'
    return result
end
local function apply(s,token,bytes)
    local doc=s.doc
    local result=D.apply_user(doc,token,{patches={{region=1,text=bytes}}})
    D.cancel_user(doc,token)
    return {ok=result.status=='applied',reason=result.reason or result.error or result.status,receipt=result}
end
function M.restore(job)
    local s=state(job)
    if not live(s) or not s.id or not s.settled then return fail('fresh target selection required')end
    return Store.restore(s.store,s.id,{validate=function()
        local bytes,why=read(s,s.settled)
        if not bytes or bytes~=s.evidence.bytes then return nil,why or 'replacement changed'end
        return s.settled
    end,apply=function(token,bytes)
        s.settled=nil
        local result=apply(s,token,bytes);s.status=result.ok and 'restored' or 'conflict';return result
    end})
end
-- Explicit selection follows inspection/preview. expected_bytes are the exact
-- current answer bytes approved by the operator, not an unconditional overwrite
-- flag. The guard is captured BEFORE recovery-file IO and checked again at apply.
function M.restore_target(store,id,doc,opts)
    if type(opts)~='table' or type(opts.expected_bytes)~='string' or D.get(opts.buf)~=doc then return fail('explicit target evidence required')end
    local token,err=D.capture_user(doc,{operation='answer-recovery-explicit-restore',regions={opts.region}})
    if not token then return fail(err)end
    local s={doc=doc,buf=opts.buf,epoch=D.snapshot(doc).epoch,reader=opts.reader}
    local result=Store.restore(store,id,{validate=function()
        local bytes,why=read(s,token)
        if not bytes or bytes~=opts.expected_bytes then return nil,why or 'selected target changed'end
        return token
    end,apply=function(proof,bytes)return apply(s,proof,bytes)end})
    D.cancel_user(doc,token);return result
end
-- Host calls from confirmed BufWritePost. read(path, association) MUST return
-- this answer's actual saved-file bytes, derived from the saved document with
-- unique association evidence. A current-buffer string or confirmed=true flag
-- is not save evidence. A callback may yield/reenter; revalidate afterward.
function M.saved(job,opts)
    local s=state(job)
    if not live(s) or not s.id or not s.settled or type(opts)~='table' or type(opts.read)~='function'then
        return fail('confirmed save read-back required')
    end
    local ok,saved,why=pcall(opts.read,s.association.path,vim.deepcopy(s.association))
    if not ok or type(saved)~='string' then return fail(why or saved)end
    local current,err=read(s,s.settled)
    if not current or saved~=s.evidence.bytes or current~=saved then return fail(err or 'saved replacement does not match')end
    local result=Store.cleanup(s.store,s.id,{kind='saved',replacement=s.evidence})
    if result.ok then drop_guard(s,'settled');s.evidence=nil;s.status='cleaned' end
    return result
end
function M.inspect(job)local s=state(job);return s.id and Store.inspect(s.store,s.id) or nil end
function M.list(store)return Store.list(store)end
function M.snapshot(job)
    local s=state(job)
    return {status=s.status,id=s.id,entity=s.entity,epoch=s.epoch,generation=s.generation}
end
-- Each settled job uses one of the Document's existing 64 User slots. The host
-- may release oldest settled jobs before new admission; this drops only runtime
-- association/ABA proof, retaining durable inspection and explicit-target restore.
function M.release(job)
    local s=state(job)
    drop_guard(s,'original');drop_guard(s,'settled')
    if s.off then s.off();s.off=nil end
    s.doc=nil;s.reader=nil;s.annotations=nil;s.evidence=nil;s.association=nil;s.key=nil;s.status='released'
    -- Keep only the store needed by the documented inspect(job) after release
    -- contract; no source bytes, association payload or document authority.
    local released=s.on_release;s.on_release=nil;if released then released(job)end
end
return M
