-- One response lifetime composes source admission, finite preparation, transport,
-- tools, and presentation. Handles carry their adapter kind; cancellation never
-- guesses ownership from the buffer or treats an unacknowledged effect as done.
local Submission=require('parley.response_submission')
local Preparation=require('parley.response_preparation')
local Provider=require('parley.response_provider')
local Tools=require('parley.response_tools')
local Pending=require('parley.chat_pending')
local D=require('parley.document')
local M={}
local states=setmetatable({},{__mode='k'})
local function state(session)return assert(states[session],'invalid response session')end
local function safe(fn,...)if type(fn)=='function'then return pcall(fn,...)end;return true end
function M.start(doc,spec,opts)
    opts=opts or {}
    if type(spec)~='table' or type(spec.preparation)~='table' or type(opts.prepare_input)~='function'
        or type(opts.build_input)~='function'then return nil,'preparation and payload builders required'end
    local frozen=vim.deepcopy(spec)
    local plan=frozen.preparation
    local s={doc=doc,opts=vim.tbl_extend('force',{},opts),preparations={},active=true}
    opts=s.opts
    local session={};states[session]=s
    local tools=Tools.new(doc,{producer=opts.producer,registry=opts.registry,root_policy=opts.root_policy,
        max_iterations=opts.max_iterations,max_result_bytes=opts.max_result_bytes,
        build_input=opts.build_input,schedule=frozen.schedule})
    s.tools=tools
    local function finish(result,rejected)
        if not s.active then return end;s.active=false
        if s.pending then s.pending:complete();s.pending=nil end
        tools.close()
        local callback=rejected and opts.rejected or opts.terminal
        s.preparations={};s.doc=nil;s.tools=nil;s.opts=nil
        opts=nil;doc=nil;plan=nil;frozen=nil;tools=nil
        safe(callback,result)
    end
    local function presentation(ctx)
        if s.pending or opts.pending==false or not opts.buf then return end
        local cancelled=ctx.cancelled
        local success,pending=pcall(Pending.start,{buf=opts.buf,agent=opts.agent or 'assistant',
            generation=ctx.generation,entity=ctx.entity,alive=function()return s.active and not cancelled()end,
            resolve_tip=function()
                if not s.doc then return nil end
                local grant=D.snapshot(s.doc).grants[ctx.grant]
                return grant and grant.status~='revoked' and D.byte_position(s.doc,grant.last) or nil
            end})
        if success then s.pending=pending end
    end
    local provider=Provider.new({dispatcher=opts.dispatcher,tasker=opts.tasker,wire=opts.wire,
        on_result=function(ctx,qt,calls,failure)
            tools.on_result(ctx,qt,calls,failure)
            if opts.on_result then opts.on_result(ctx,qt,calls,failure)end
        end,
        on_activity=function()if s.pending then s.pending:activity()end end,
        on_progress=function(_,event)if s.pending then s.pending:progress(event)end end})
    local function prepare(ctx,cb)
        presentation(ctx)
        local r={kind='prepare',ctx=ctx,cb=cb,io_done=false,local_done=false}
        s.preparations[r]=true
        local function resolve()
            if r.retired or not r.io_done or not r.local_done then return end
            r.retired=true;s.preparations[r]=nil
            local done=r.cancel_done or cb.resolved
            r.ctx=nil;r.cb=nil;r.handle=nil;r.op=nil;r.input=nil;r.cancel_done=nil
            cb=nil
            done()
        end
        r.resolve=resolve
        local function failed(reason)
            if r.retired or r.failed then return end;r.failed=true
            if not r.cancelled then cb.failed(reason)end
            r.local_done=true;resolve()
        end
        local callbacks={}
        function callbacks.prepared(input)
            if r.retired or r.cancelled or r.input or ctx.cancelled()then return false end
            if type(input)~='table'then failed('invalid prepared input');return false end
            r.input=vim.deepcopy(input)
            local prepared_ctx=vim.tbl_extend('force',{},ctx,{input=r.input})
            local op,reason=Preparation.start(doc,prepared_ctx,{
                prepared=function(value)
                    if r.cancelled or ctx.cancelled()then return false end
                    return cb.prepared(value)
                end,
                failed=failed,
                resolved=function()r.local_done=true;resolve()end,
            },plan,{schedule=frozen.schedule})
            if not op then failed(reason);return false end
            r.op=op
            return true
        end
        function callbacks.failed(reason)failed(reason)end
        function callbacks.resolved()
            if r.retired then return end
            r.io_done=true
            if r.cancelled or not r.input then
                if not r.cancelled and not r.failed then failed('preparation resolved without input')end
                r.local_done=true
            end
            resolve()
        end
        local success,handle=pcall(opts.prepare_input,ctx,callbacks)
        if success then if not r.retired then r.handle=handle end
        else
            -- A throw after starting IO provides no positive completion evidence.
            failed('input preparation failed')
        end
        return r
    end
    local function wrap(kind,fn)
        return function(ctx,cb)return {kind=kind,handle=fn(ctx,cb)}end
    end
    local hooks={prepare=prepare,request=wrap('provider',function(ctx,cb)
            safe(opts.requesting,ctx)
            return provider.request(ctx,cb)
        end),
        reserve_round=tools.reserve_round,cancel_reservation=tools.cancel_reservation,
        start_child=wrap('tool',tools.start_child),continue_round=wrap('continuation',tools.continue_round),
        finalize=function(ctx,done)
            if opts.finalize then return opts.finalize(ctx,done)end
            done('applied')
        end,
        written=function(ctx,receipt)
            if s.pending and receipt.kind=='output' and receipt.tip then s.pending:written(receipt.tip.row,receipt.tip.col)end
            safe(opts.written,ctx,receipt)
        end,
        terminal=function(result)finish(result,false)end,rejected=function(reason)finish(reason,true)end}
    function hooks.cancel_operation(ctx,done)
        local handle=ctx.handle
        if type(handle)~='table'then return false end
        if handle.kind=='prepare'then
            local r=handle
            if r.retired then done();return true end
            if r.cancelled then return false end
            r.cancelled=true;r.cancel_done=done
            if r.op then Preparation.cancel(r.op,function()r.local_done=true;r.resolve()end)
            else r.local_done=true end
            if r.io_done then r.resolve()
            elseif opts.cancel_prepare then
                local inner=vim.tbl_extend('force',{},ctx,{handle=r.handle})
                opts.cancel_prepare(inner,function()r.io_done=true;r.resolve()end)
            elseif type(r.handle)=='table' and type(r.handle.cancel)=='function'then
                r.handle:cancel(function()r.io_done=true;r.resolve()end)
            end
            return true
        end
        local inner=vim.tbl_extend('force',{},ctx,{handle=handle.handle})
        if handle.kind=='provider'then return provider.cancel_operation(inner,done)end
        if handle.kind=='tool'then return tools.cancel_operation(inner,done)end
        if handle.kind=='continuation'then done();return true end -- synchronous builder
        return false
    end
    local submission,reason=Submission.start(doc,frozen,hooks)
    if not submission then finish(reason,true);states[session]=nil;return nil,reason end
    s.submission=submission
    return session
end
function M.snapshot(session)return Submission.snapshot(state(session).submission)end
function M.step(session)
    local s=state(session)
    if s.active then
        for r in pairs(s.preparations)do if r.op and not r.local_done then Preparation.step(r.op)end end
        if s.tools then s.tools.step()end
    end
    return Submission.step(s.submission)
end
function M.cancel(session,reason)return Submission.cancel(state(session).submission,reason)end
function M.resume(session,policy)return Submission.resume(state(session).submission,policy)end
return M
