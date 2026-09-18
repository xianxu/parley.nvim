-- Tool rounds compose typed document grants and frozen provider messages. They
-- never rebuild a transcript from the live buffer or recursively submit a chat.
-- The generation machine decides which tool block is written when (#266 M2);
-- this adapter runs the tools and renders the blocks it is asked for.
local D=require('parley.document')
local Serialize=require('parley.tools.serialize')
local M={}
local function copy(value)return type(value)=='table' and vim.deepcopy(value) or value end
local function valid_name(value)return type(value)=='string' and #value>0 and #value<=256 and not value:find('%s')end
local function call(value,id)
    assert(type(value)=='table' and valid_name(value.name) and valid_name(id),'invalid tool identity')
    assert(type(value.input)=='table','invalid tool input')
    return {id=id,name=value.name,input=copy(value.input)}
end
local function parent(doc,ctx)
    local snapshot=D.snapshot(doc)
    local grant=snapshot.grants[ctx.grant]
    if snapshot.epoch~=ctx.epoch or not snapshot.attached or not grant or grant.status=='revoked'
        or grant.entity~=ctx.entity or grant.generation~=ctx.generation then return nil end
    return grant
end
-- A failed call is written as an error result the model reads, so it can try
-- another way (#266 M2, operator decision): the round never pauses on one.
-- Each names what is and is not known about the effect.
local failures={
    unknown='The tool call failed and its outcome is unknown: it may or may not have taken effect.',
    rejected='The tool call was rejected before it ran.',
    cancelled_before_effect='The tool call was cancelled before it ran.',
}
local function failure(outcome,value)
    local detail=type(value)=='table' and (value.content or value.error) or nil
    detail=detail~=nil and tostring(detail) or ''
    return failures[outcome]..(detail~='' and '\n\n'..detail or '')
end
-- The result call `c`'s block and its continuation both carry. A failure the
-- runner reports for a tool that never got a producer (its adapter threw)
-- arrives without identity; it is an unknown outcome like any other. One
-- function for both readers, so the transcript and the wire cannot differ.
local function settled(c,r)
    if type(r)=='table' and r.id~=nil then
        assert(r.id==c.id and r.name==c.name and type(r.content)=='string','tool result identity')
        return r
    end
    return {id=c.id,name=c.name,content=failure('unknown',r),is_error=true}
end
local function maybe_resolve(s,r)
    if r.retired or not r.producer_done then return end
    if not r.supervised and not r.outcome then return end
    r.retired=true;s.active[r]=nil
    local resolved=r.cancel_resolved or r.cb.resolved
    r.cb=nil;r.ctx=nil;r.call=nil;r.producer_handle=nil;r.cancel_resolved=nil
    resolved(r.supervised and {supervised=true} or nil)
end
local function tool_outcome(s,r,outcome,value)
    if r.retired or r.outcome and not (r.outcome=='unknown' and outcome=='known') then return false end
    assert(outcome=='known' or outcome=='unknown' or outcome=='rejected' or outcome=='cancelled_before_effect','invalid tool outcome')
    local result
    if outcome=='known'then
        assert(type(value)=='table' and type(value.content)=='string','invalid tool result')
        result=require('parley.tools.result_evidence').publish(value,s.result_limit)
        result.id=r.call.id;result.name=r.call.name;result.is_error=value.is_error==true
    else result=require('parley.tools.result_evidence').publish({id=r.call.id,name=r.call.name,
        content=failure(outcome,value),is_error=true},s.result_limit)end
    -- The machine writes the result when its turn in the round comes. Observers
    -- may report cleanup reentrantly; `maybe_resolve` waits for the outcome to be
    -- recorded here first. A confirmation the machine refuses — its unknown
    -- result is already written — leaves the recorded outcome standing.
    local accepted=r.cb.outcome(outcome,result)
    if r.outcome and not accepted then return false end
    r.outcome=outcome
    maybe_resolve(s,r)
    return true
end

function M.new(doc,opts)
    opts=opts or {}
    assert(type(opts.build_input)=='function','tool continuation payload builder required')
    local max_iterations=opts.max_iterations or require('parley.defaults').max_tool_iterations or 5
    assert(type(max_iterations)=='number' and max_iterations>=1 and max_iterations%1==0,'invalid tool iteration limit')
    local result_limit=opts.max_result_bytes or 102400
    assert(type(result_limit)=='number' and result_limit>=1 and result_limit<=524288 and result_limit%1==0,'invalid tool result limit')
    local s={doc=doc,rounds={},iterations=0,active={},records=setmetatable({},{__mode='k'}),
        result_limit=result_limit,producer=opts.producer}
    -- The round a declared call belongs to, frozen from the provider's response
    -- the first time the machine names it — by starting a tool or asking for a
    -- block, whichever comes first. Nothing is written by freezing.
    local function round_of(ctx)
        local round=s.rounds[ctx.round]
        if round then return round end
        local pending=s.pending
        assert(not s.closed and pending,'missing frozen tool response')
        assert(pending.epoch==ctx.epoch and pending.generation==ctx.generation,'tool response identity')
        round={calls=pending.calls,text=pending.text,attempt=pending.attempt}
        s.rounds[ctx.round]=round;s.pending=nil;s.iterations=s.iterations+1
        return round
    end
    local function declared(round,c)
        for _,known in ipairs(round.calls)do
            if known.id==c.id then assert(vim.deep_equal(c,known),'tool call source changed');return known end
        end
        error('tool call source changed')
    end
    if not s.producer then
        local reason
        s.producer,reason=require('parley.tools.producer').new({registry=opts.registry,
            allowed_tools=opts.allowed_tools or {},root_policy=opts.root_policy,state_dir=opts.state_dir,
            buf=opts.buf,chat_roots=opts.chat_roots,help_root=opts.help_root,
            page_limit=opts.page_limit,max_result_bytes=result_limit})
        assert(s.producer,reason)
    end
    assert(type(s.producer.start)=='function' and type(s.producer.cancel)=='function','tool producer lifecycle required')
    local adapter={}
    function adapter.on_result(ctx,qt,calls,failure)
        if failure or #calls==0 then s.pending=nil;return end
        assert(not s.closed and s.iterations<max_iterations,'tool iteration limit')
        local text=qt.response or ''
        assert(type(text)=='string' and #text<=1048576,'tool response text limit')
        local frozen={text=text,calls={},generation=ctx.generation,epoch=ctx.epoch,attempt=ctx.operation}
        local bytes=#text
        for i,c in ipairs(calls)do
            frozen.calls[i]=call(c,c.id)
            bytes=bytes+#vim.json.encode(frozen.calls[i])
            assert(bytes<=1048576,'tool round input limit')
        end
        s.pending=frozen
    end
    --- One block of a round, appended at the answer's tail: call `ctx.index`'s
    --- block, or its result (`ctx.result`, the blob the machine recorded). The
    --- round is laid out as the text, a blank line, then every block followed by
    --- a blank line, so the next request's text starts on its own paragraph.
    function adapter.insert_tool(ctx,done)
        local round=round_of(ctx)
        local c=round.calls[ctx.index]
        assert(c and c.id==ctx.call_id,'tool call source changed')
        local block
        if ctx.kind=='call'then
            block=Serialize.render_call(c);assert(#block<=65536,'tool argument limit')
        else block=Serialize.render_result(settled(c,ctx.result))end
        local text=(ctx.kind=='call' and ctx.index==1 and '\n\n' or '')..block..'\n\n'
        local admitted=ctx.append(text,function(result)done(result.status)end)
        if not admitted then done('failed')end
    end
    function adapter.start_child(ctx,cb)
        local c=call(ctx.arguments,ctx.call_id)
        declared(round_of(ctx),c)
        local grant=parent(doc,ctx)
        if not grant then
            cb.outcome('cancelled_before_effect',{id=c.id,name=c.name,content=failure('cancelled_before_effect'),is_error=true})
            cb.resolved();return {}
        end
        local handle={};local r={ctx=ctx,cb=cb,call=c,epoch=ctx.epoch,generation=ctx.generation,
            operation=ctx.operation,grant=ctx.grant}
        s.records[handle]=r;s.active[r]=true
        local events={outcome=function(outcome,value)return tool_outcome(s,r,outcome,value)end,
            resolved=function()r.producer_done=true;maybe_resolve(s,r)end}
        local ok,value=pcall(s.producer.start,copy(c),{root_policy=copy(opts.root_policy),
            cwd=opts.root_policy and opts.root_policy.write_root,max_bytes=s.result_limit,page_limit=opts.page_limit,
            epoch=ctx.epoch,generation=ctx.generation,round=ctx.round,
            attempt=s.rounds[ctx.round] and s.rounds[ctx.round].attempt,buf=opts.buf},events)
        if not ok then
            if not r.outcome then tool_outcome(s,r,'unknown',{content=tostring(value)})end
            -- A throwing producer may already own an effect. No fabricated
            -- positive resolution: its lifecycle callback must settle it.
        elseif not r.retired then r.producer_handle=value end
        return handle
    end
    function adapter.cancel_operation(ctx,resolved)
        local r=s.records[ctx.handle]
        if not r or r.epoch~=ctx.epoch or r.generation~=ctx.generation or r.operation~=ctx.operation then return false end
        if r.retired then resolved(r.supervised and {supervised=true} or nil);return true end
        if r.cancelled then return false end
        r.cancelled=true;r.cancel_resolved=resolved
        s.producer.cancel(r.producer_handle,function(evidence)
            if type(evidence)=='table' and evidence.supervised==true then r.supervised=true end
            r.producer_done=true;maybe_resolve(s,r)
        end)
        return true
    end
    function adapter.continue_round(ctx,cb)
        local round=s.rounds[ctx.round]
        assert(round and type(ctx.previous_input)=='table' and type(ctx.previous_input.messages)=='table','missing frozen round input')
        assert(#ctx.results==#round.calls,'tool result count')
        local messages=copy(ctx.previous_input.messages)
        local assistant,results={},{}
        if round.text~=''then assistant[#assistant+1]={type='text',text=round.text}end
        for i,c in ipairs(round.calls)do
            local r=settled(c,ctx.results[i])
            assistant[#assistant+1]={type='tool_use',id=c.id,name=c.name,input=copy(c.input)}
            results[i]={type='tool_result',tool_use_id=c.id,content=r.content,is_error=r.is_error==true}
        end
        messages[#messages+1]={role='assistant',content=assistant}
        messages[#messages+1]={role='user',content=results}
        local input=opts.build_input(copy(ctx.previous_input),messages,ctx)
        assert(type(input)=='table','invalid continuation payload')
        s.rounds[ctx.round]=nil
        cb.prepared(input);cb.resolved();return {}
    end
    function adapter.close()
        s.closed=true;s.pending=nil;s.rounds={}
        if s.producer.close then s.producer.close()end
        return next(s.active)==nil
    end
    return adapter
end
return M
