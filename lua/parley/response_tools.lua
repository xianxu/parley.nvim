-- Tool rounds compose typed document grants and frozen provider messages. They
-- never rebuild a transcript from the live buffer or recursively submit a chat.
local D=require('parley.document')
local Deferred=require('parley.deferred_work')
local Serialize=require('parley.tools.serialize')
local Dispatch=require('parley.tools.dispatcher')
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
local function release_ticket(s,r)
    if r.ticket then
        D.release_capacity(s.doc,{epoch=r.ctx.epoch,generation=r.ctx.generation,
            operation=r.ticket_operation,ticket=r.ticket});r.ticket=nil
    end
end
local function retire_reservation(s,r,grants,receipt,cancelled)
    if r.retired then return end;r.retired=true
    if r.work then r.work:close();r.work=nil end
    if r.off then r.off();r.off=nil end
    release_ticket(s,r)
    if s.reservation==r then s.reservation=nil end
    local done=r.done;r.done=nil;r.payload=nil;r.slots=nil;r.ctx=nil
    if not cancelled then done(grants,receipt)end
end
local function reserve_step(s,r)
    if r.retired or r.appending then return false end
    local grant=parent(s.doc,r.ctx)
    if not grant or r.ctx.cancelled()then retire_reservation(s,r);return false end
    D.repair_step(s.doc)
    grant=parent(s.doc,r.ctx)
    if not grant then retire_reservation(s,r);return false end
    if grant.status~='valid'then return true end
    -- The complete payload was appended through this parent's exact receipts.
    -- Parent revocation catches internal edits; unrelated movement rebases its
    -- current endpoint. No saved absolute slot coordinate crosses a yield.
    local base=grant.last-r.bytes
    local regions,markers={},{}
    for i,slot in ipairs(r.slots)do
        local first,last=base+slot.first,base+slot.last
        local p=D.byte_position(s.doc,first)
        if not p or p.col~=0 then retire_reservation(s,r);return false end
        local row=D.query(s.doc,p.row,p.row+1)[1]
        if not row or not row.metadata or not row.metadata.confirmed then return true end
        if not row.metadata.token or row.metadata.token.kind~='text' then retire_reservation(s,r);return false end
        regions[i]={entity=r.ctx.entity,first=first,last=last,revision=1,marker_revision=1,confirmed=true}
        markers[i]=row.handle
    end
    local acquired=D.transition(s.doc,{kind='acquire',generation=r.ctx.generation,parent=r.ctx.grant,
        capacity=r.ticket,operation=r.ticket_operation,regions=regions})
    if not acquired.ok then
        if acquired.reason=='unconfirmed identity' or acquired.reason=='parent'then return true end
        retire_reservation(s,r);return false
    end
    r.ticket=nil
    retire_reservation(s,r,acquired.grants,{markers=markers,round=r.round})
    return false
end
local function maybe_resolve(s,r)
    if r.retired or not r.producer_done or r.writing then return end
    if not r.supervised and (not r.outcome or r.outcome=='unknown')then return end
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
        result={id=r.call.id,name=r.call.name,content=Dispatch.truncate(value.content,s.result_limit),is_error=value.is_error==true}
    else result={id=r.call.id,name=r.call.name,content=type(value)=='table' and tostring(value.content or '') or '',is_error=true}end
    r.outcome=outcome
    -- Reserve publication before invoking outcome observers: they may report
    -- physical cleanup or cancel reentrantly. Neither can retire this record
    -- while a known result still needs its publication decision.
    r.writing=outcome=='known' and not r.cancelled
    r.cb.outcome(outcome,result)
    if r.cancelled or outcome~='known' then
        r.writing=false;maybe_resolve(s,r);return true
    end
    local text=Serialize.render_result(result)
    local admitted=r.ctx.replace(text,function()
        r.writing=false;maybe_resolve(s,r)
    end)
    if not admitted then r.writing=false;maybe_resolve(s,r)end
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
    function adapter.reserve_round(ctx,done)
        local handle={}
        assert(not s.closed and not s.reservation and s.pending,'missing frozen tool response')
        local pending=s.pending
        assert(pending.epoch==ctx.epoch and pending.generation==ctx.generation,'tool response identity')
        assert(#ctx.children==#pending.calls and #ctx.children>0 and #ctx.children<=15,'tool child capacity')
        local calls,blocks,slots={}, {},{}
        local length=0
        local function append(text)blocks[#blocks+1]=text;length=length+#text end
        for i,child in ipairs(ctx.children)do
            local c=call(child.arguments,child.call_id)
            assert(vim.deep_equal(c,pending.calls[i]),'tool call source changed')
            calls[i]=c
            local rendered=Serialize.render_call(c)
            assert(#rendered<=65536,'tool argument limit')
            append('\n\n'..rendered)
        end
        for i in ipairs(calls)do
            append('\n\n')
            local first=length
            -- Reservation text is inert: result Markdown is evidence and may
            -- only be published after a producer reports a known outcome.
            append('(Tool result pending)')
            slots[i]={first=first,last=length}
        end
        append('\n\n');assert(length<=1048576,'tool round output limit')
        local operation='tool-reservation:'..tostring(ctx.round)
        local reserved=D.reserve_capacity(doc,{epoch=ctx.epoch,generation=ctx.generation,operation=operation,count=#calls})
        if not reserved.ok then done(nil);return handle end
        local r={ctx=ctx,done=done,slots=slots,bytes=length,payload=table.concat(blocks),ticket=reserved.ticket,
            ticket_operation=operation,round=ctx.round,appending=true,epoch=ctx.epoch,generation=ctx.generation}
        s.records[handle]=r;s.reservation=r;s.pending=nil;s.iterations=s.iterations+1
        s.rounds[ctx.round]={calls=calls,text=pending.text,attempt=pending.attempt}
        r.work=Deferred.new(function()return reserve_step(s,r)end)
        r.off=D.subscribe(doc,function(event)
            if not r.retired and (event.kind=='reload' or event.kind=='detach')then retire_reservation(s,r)end
        end)
        local admitted=ctx.append(r.payload,function(result)
            if r.retired then return end
            r.appending=false;r.payload=nil
            if result.status~='applied' or result.accepted_bytes~=r.bytes then retire_reservation(s,r);return end
            if opts.schedule~=false then r.work:request()end
        end)
        if not admitted then retire_reservation(s,r)end
        return handle
    end
    function adapter.cancel_reservation(ctx,resolved)
        local r=s.records[ctx.handle]
        if not r or r.epoch~=ctx.epoch or r.generation~=ctx.generation or r.round~=ctx.round then return false end
        retire_reservation(s,r,nil,nil,true);resolved();return true
    end
    function adapter.start_child(ctx,cb)
        local c=call(ctx.arguments,ctx.call_id)
        local grant=parent(doc,ctx)
        if not grant then cb.outcome('cancelled_before_effect',{id=c.id,name=c.name,content='',is_error=true});cb.resolved();return {}end
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
            local r=ctx.results[i]
            assert(type(r)=='table' and r.id==c.id and r.name==c.name and type(r.content)=='string','tool result identity')
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
    function adapter.step()if s.reservation then return reserve_step(s,s.reservation)end;return false end
    function adapter.close()
        s.closed=true;s.pending=nil;s.rounds={}
        if s.producer.close then s.producer.close()end
        if s.reservation then retire_reservation(s,s.reservation)end
        return next(s.active)==nil
    end
    return adapter
end
return M
