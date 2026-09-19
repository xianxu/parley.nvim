-- Operation-scoped provider transport. This module owns no document positions.
local M={}
local serial=0
local scope_key=require('parley.tasker').scope_key
local function scalar(v)return type(v)=='string' and #v>0 and #v<=256
    or type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function safe(fn,...)
    if type(fn)~='function'then return true end
    return pcall(fn,...)
end
local function failure_reason(failure)
    if type(failure)=='table'then
        -- A transport that ended badly names how (#261 M3 review BR-45).
        if failure.exit then return 'provider request failed ('..failure.exit..')' end
        return 'provider request failed (HTTP '..tostring(failure.http_status or 'unknown')..')'
    end
    return type(failure)=='string' and failure:sub(1,512) or 'provider request failed'
end
function M.new(opts)
    opts=opts or {}
    local dispatcher=opts.dispatcher or require('parley.dispatcher')
    local tasker=opts.tasker or require('parley.tasker')
    local wire=opts.wire or require('parley.tools.wire')
    local records=setmetatable({},{__mode='k'})
    local function alive(r)
        if not r.active or r.terminal then return false end
        local ok,cancelled=safe(r.ctx.cancelled)
        return ok and cancelled~=true
    end
    local function failed(r,reason)
        if r.failed or r.cancelled then return end;r.failed=true
        safe(r.cb.failed,reason)
    end
    local function resolve(r)
        if r.terminal then return end
        r.terminal=true;r.active=false
        -- Cancellation's resolver and ordinary cb.resolved represent the same
        -- physical completion; deliver exactly one, never both.
        local resolver=r.cancel_resolved or r.cb.resolved
        r.cancel_resolved=nil
        safe(resolver)
        r.ctx=nil;r.input=nil;r.cb=nil
    end
    local function completed(r,qid,failure)
        if r.terminal then return end
        local active=alive(r);r.active=false
        local ok=pcall(function()
            if not active then return end
            local qt=tasker.get_query(qid)
            if not qt then error('missing query result')end
            -- Query data is borrowed only for this call. Tool declarations are
            -- copied for the host so its continuation state cannot mutate admission.
            if failure then
                if opts.on_result then opts.on_result(r.ctx,qt,{},failure)end
                failed(r,failure_reason(failure));return
            end
            local decoder=qt.tool_wire and wire.by_name(qt.tool_wire)
                or wire.resolve(r.input.provider,r.input.model or r.input.payload.model)
            local calls=decoder and decoder.decode_tool_calls_from_stream(qt.raw_response or '') or {}
            assert(type(calls)=='table' and #calls<=32,'tool call limit')
            local declared,seen={},{}
            for i,call in ipairs(calls)do
                assert(scalar(call.id) and type(call.name)=='string' and #call.name>0 and #call.name<=256
                    and type(call.input)=='table' and not seen[call.id],'invalid tool call')
                seen[call.id]=true
                declared[i]={call_id=call.id,arguments={id=call.id,name=call.name,input=call.input}}
            end
            if opts.on_result then opts.on_result(r.ctx,qt,vim.deepcopy(calls))end
            if #calls>0 then assert(r.cb.round(declared)~=false,'tool round refused')
            else assert(r.cb.complete()~=false,'completion refused')end

        end)
        if not ok then failed(r,'provider result processing failed')end
        resolve(r)
    end
    local adapter={}
    function adapter.request(ctx,cb)
        assert(type(ctx)=='table' and scalar(ctx.epoch) and scalar(ctx.generation) and scalar(ctx.operation),'operation identity required')
        assert(type(cb)=='table' and type(cb.output)=='function' and type(cb.complete)=='function'
            and type(cb.failed)=='function' and type(cb.resolved)=='function' and type(cb.round)=='function','runner callbacks required')
        serial=serial+1
        local handle={};local r={ctx=ctx,cb=cb,input=ctx.input,epoch=ctx.epoch,generation=ctx.generation,
            operation=ctx.operation,owner='response-provider:'..serial,active=true}
        records[handle]=r
        if type(r.input)~='table' or type(r.input.provider)~='string' or r.input.provider=='' or type(r.input.payload)~='table'then
            failed(r,'invalid provider input');resolve(r);return handle
        end
        local output=dispatcher.create_output_handler(function(_,bytes)
            if not alive(r)then return false end
            local ok,accepted=safe(r.cb.output,bytes)
            if not ok or accepted~=true then
                r.active=false;tasker.stop_owner(r.owner);return false
            end
            return true
        end)
        local function abort(reason)
            if r.terminal then return end
            failed(r,failure_reason(reason));resolve(r)
        end
        local ok=pcall(dispatcher.query,r.input.buf,r.input.provider,r.input.payload,output,
            function(qid)completed(r,qid)end,nil,
            function(_,event)if alive(r)then safe(opts.on_progress,r.ctx,event)end end,
            abort,function()if alive(r)then safe(opts.on_activity,r.ctx)end end,
            function(qid,err)completed(r,qid,err)end,
            {generation_id=r.owner,logical_generation=scope_key(ctx.epoch,ctx.generation),admission_key=r.owner,attempt_id=r.owner,alive=function()return alive(r)end})
        if not ok then
            r.active=false;failed(r,'provider startup failed')
            if tasker.get_attempt(r.owner)then tasker.stop_owner(r.owner)
            else resolve(r)end
        end
        return handle
    end
    function adapter.cancel_operation(ctx,resolved)
        local r=type(ctx)=='table' and records[ctx.handle]
        if not r or r.epoch~=ctx.epoch or r.generation~=ctx.generation or r.operation~=ctx.operation then return false end
        if r.cancelled then return false end
        r.cancelled=true;r.active=false
        if r.terminal then safe(resolved);return true end
        r.cancel_resolved=resolved
        -- A zero match means no process is running for this request: a pre_query
        -- or a recovery is pending. Nothing would resolve it, so it resolves now;
        -- its late callback finds the owner inactive and aborts (`transport_alive`,
        -- #261 M4 W5). A signal that failed leaves the process to its exit.
        local ok,matched=pcall(tasker.stop_owner,r.owner)
        if ok and matched==0 then resolve(r) end
        return true
    end
    return adapter
end
return M
