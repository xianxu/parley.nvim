-- One response lifetime composes source admission, finite preparation, transport,
-- tools, and presentation. Handles carry their adapter kind; cancellation never
-- guesses ownership from the buffer or treats an unacknowledged effect as done.
local Submission=require('parley.response_submission')
local Preparation=require('parley.response_preparation')
local Provider=require('parley.response_provider')
local Tools=require('parley.response_tools')
local Pending=require('parley.chat_pending')
local Presentation=require('parley.chat_presentation')
local D=require('parley.document')
local M={}
local states=setmetatable({},{__mode='k'})
local function state(session)return assert(states[session],'invalid response session')end
local function safe(fn,...)if type(fn)=='function'then return pcall(fn,...)end;return true end
local function preparation_override(original,override)
    if override==nil then return original end
    if type(override)~='table' or type(override.gaps)~='table' or #override.gaps~=#original.gaps then return nil end
    local candidate=vim.deepcopy(override)
    local geometry=vim.deepcopy(original)
    for index,gap in ipairs(candidate.gaps)do
        if type(gap)~='table' or type(gap.bytes)~='string' then return nil end
        gap.bytes=original.gaps[index].bytes
        gap.retain_prefix=original.gaps[index].retain_prefix
    end
    if not vim.deep_equal(candidate,geometry)then return nil end
    -- Only output bytes and the amount retained by the existing primary grant
    -- may change; every source boundary remains the command-time geometry.
    return vim.deepcopy(override)
end

function M.start(doc,spec,opts)
    opts=opts or {}
    if type(spec)~='table' or type(spec.preparation)~='table' or type(opts.prepare_input)~='function'
        or type(opts.build_input)~='function'then return nil,'preparation and payload builders required'end
    local frozen=vim.deepcopy(spec)
    local plan=frozen.preparation
    local s={doc=doc,opts=vim.tbl_extend('force',{},opts),preparations={},active=true}
    opts=s.opts
    for _,name in ipairs({"root_policy","allowed_tools","chat_roots"})do
        opts[name]=vim.deepcopy(opts[name])
    end
    local session={};states[session]=s
    local tools
    local function finish(result,rejected)
        if not s.active then return end;s.active=false
        if s.pending then s.pending:complete();s.pending=nil end
        if tools then tools.close()end
        local callback=rejected and opts.rejected or opts.terminal
        s.preparations={};s.doc=nil;s.tools=nil;s.opts=nil
        opts=nil;doc=nil;plan=nil;frozen=nil;tools=nil
        safe(callback,result)
    end
    -- #266: a wait note is state, not an event. The status line it lives on is
    -- cleared by every output write and recreated after a pause, so the current
    -- note is shown again on both — or an answer that got the turn runs its
    -- tools with nothing on screen while the others say they wait on it.
    local function show_note()
        if s.pending and s.note then s.pending:progress({message=s.note})end
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
        if success then s.pending=pending;show_note()end
    end
    local function capture_profile(input,ctx)
        local profile=input.response_profile
        if profile~=nil and type(profile)~='table'then return false,'invalid response profile'end
        profile=profile or {}
        if profile.allowed_tools~=nil and type(profile.allowed_tools)~='table'then return false,'invalid tool capabilities'end
        if profile.agent~=nil and (type(profile.agent)~='string' or #profile.agent==0 or #profile.agent>256)then
            return false,'invalid response display name'
        end
        for _,name in ipairs({'max_iterations','max_result_bytes'})do
            if profile[name]~=nil and type(profile[name])~='number'then return false,'invalid response tool limit'end
        end
        local function limit(name)
            if profile[name]~=nil then return profile[name]end
            return opts[name]
        end
        -- Construction validates the same limits as every other Tools caller.
        -- It runs once, before preparation writes or provider admission, after
        -- an explicit onboarding choice has become the frozen request profile.
        local ok,adapter=pcall(Tools.new,doc,{producer=opts.producer,registry=opts.registry,
            root_policy=opts.root_policy,allowed_tools=profile.allowed_tools or opts.allowed_tools or {},
            buf=opts.buf,chat_roots=opts.chat_roots,help_root=opts.help_root,page_limit=opts.page_limit,
            max_iterations=limit('max_iterations'),
            max_result_bytes=limit('max_result_bytes'),build_input=opts.build_input})
        if not ok then return false,tostring(adapter)end
        tools=adapter;s.tools=adapter
        if profile.agent and profile.agent~=opts.agent then
            if s.pending then s.pending:cancel();s.pending=nil end
            opts.agent=profile.agent;presentation(ctx)
        end
        return true
    end
    local provider=Provider.new({dispatcher=opts.dispatcher,tasker=opts.tasker,wire=opts.wire,
        on_result=function(ctx,qt,calls,failure)
            tools.on_result(ctx,qt,calls,failure)
            if opts.on_result then opts.on_result(ctx,qt,calls,failure)end
        end,
        on_activity=function()if s.pending then s.pending:activity()end end,
        -- While held behind the turn, the waiting note owns the one status slot:
        -- provider detail would bury it and it would not be re-asserted (#266).
        on_progress=function(_,event)if s.pending and not s.note then s.pending:progress(event)end end})
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
        function callbacks.prepared(input,override)
            if r.retired or r.cancelled or r.input or ctx.cancelled()then return false end
            if type(input)~='table'then failed('invalid prepared input');return false end
            local replacement=preparation_override(plan,override)
            if not replacement then failed('preparation override changed captured geometry');return false end
            local profiled,profile_error=capture_profile(input,ctx)
            if not profiled then failed(profile_error);return false end
            r.input=vim.deepcopy(input)
            local prepared_ctx=vim.tbl_extend('force',{},ctx,{input=r.input})
            -- #266: the input goes to the runner now, so the provider request
            -- starts without waiting on the write turn. The gap is handed over as
            -- a writer the machine calls immediately before this generation's
            -- first write — never, if it is cancelled first. This operation stays
            -- unresolved until Preparation retires, so cancellation reaches the
            -- writer through the ordinary cancel_operation path.
            -- The writer settles `done` on every path (M1 review I2): an unsettled
            -- gap stays 'writing' and nothing may ever write again. `done` is
            -- idempotent, so the settle in `resolved` is a no-op after 'applied'
            -- and covers a Preparation that retires 'cancelled' without reporting.
            -- `failed` runs first so its reason is recorded before the stop.
            local function write_gap(done)
                if r.retired or r.cancelled or ctx.cancelled()then return done('cancelled')end
                local op,reason=Preparation.start(doc,prepared_ctx,{
                    prepared=function()return done('applied')end,
                    failed=function(why)failed(why);done('failed')end,
                    resolved=function()done('cancelled');r.local_done=true;resolve()end,
                },replacement,{schedule=frozen.schedule})
                if not op then failed(reason);done('failed');return end
                r.op=op
            end
            local ok,accepted=pcall(cb.prepared,r.input,write_gap)
            if not ok or accepted==false then failed(ok and 'prepared callback refused' or tostring(accepted));return false end
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
    local function tool_adapter(name)
        return function(...)
            assert(tools,'tool profile not prepared')
            return tools[name](...)
        end
    end
    local hooks={prepare=prepare,request=wrap('provider',function(ctx,cb)
            presentation(ctx)
            return provider.request(ctx,cb)
        end),
        insert_tool=tool_adapter('insert_tool'),
        start_child=wrap('tool',tool_adapter('start_child')),continue_round=wrap('continuation',tool_adapter('continue_round')),
        finalize=function(ctx,done)
            if opts.finalize then return opts.finalize(ctx,done)end
            done('applied')
        end,
        written=function(ctx,receipt)
            if s.pending and receipt.kind=='output' and receipt.tip then
                s.pending:written(receipt.tip.row,receipt.tip.col);show_note()
            end
            safe(opts.written,ctx,receipt)
        end,
        changed=function(value)
            if not s.active then return end
            if value.phase=='paused' and s.pending then s.pending:cancel();s.pending=nil end
            -- #266: a generation held behind the write turn names what it waits
            -- for; one running tools says how far they are, since their blocks
            -- land one at a time. Presentation only: an extmark, never transcript.
            local note
            if value.phase=='flushing' then note=Presentation.flushing_message(value.blocked and value.blocked.line)
            elseif value.blocked then note=Presentation.waiting_message(value.blocked.line,value.blocked.phase)
            elseif value.tools and value.phase=='executing_tools' then
                note=Presentation.tools_message(value.tools)
            end
            -- Recorded even with no status line up (after a pause), so the next
            -- one shows the current note rather than a stale comparison.
            if note~=s.note then
                s.note=note
                if s.pending then s.pending:progress({message=note or 'Working...'})end
            end
            safe(opts.changed,value)
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
    end
    return Submission.step(s.submission)
end
function M.cancel(session,reason)return Submission.cancel(state(session).submission,reason)end
function M.resume(session,policy)return Submission.resume(state(session).submission,policy)end
function M.resume_original(session,identity)return Submission.resume_original(state(session).submission,identity)end
return M
