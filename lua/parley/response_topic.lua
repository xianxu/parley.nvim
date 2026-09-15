-- Automatic topic generation owns only the captured '?' suffix. Origin markers
-- remain guarded independently of the answer generation's normal completion.
local D=require('parley.document')
local Provider=require('parley.response_provider')
local Deferred=require('parley.deferred_work')
local Reader=require('parley.line_reader')
local M={}
local states=setmetatable({},{__mode='k'})
local serial=0
local function state(job)return assert(states[job],'invalid topic job')end
function M.input(messages,provider,model,prompt,dispatcher)
    local cleaned={}
    for _,message in ipairs(messages)do
        if message.role~='system'then
            local content=message.content
            if type(content)=='table'then
                local parts={}
                for _,block in ipairs(content)do
                    if block.type=='text' and type(block.text)=='string'then parts[#parts+1]=block.text end
                end
                content=table.concat(parts,' ')
            elseif type(content)~='string'then content=''end
            content=content:match('^%s*(.-)%s*$')
            if content~=''then cleaned[#cleaned+1]={role=message.role,content=content}end
        end
    end
    cleaned[#cleaned+1]={role='user',content=prompt}
    dispatcher=dispatcher or require('parley.dispatcher')
    return {provider=provider,model=vim.deepcopy(model),payload=dispatcher.prepare_payload(cleaned,model,provider)}
end
local function retire(s,status,reason)
    if s.finished then return end;s.finished=true;s.status=status;s.reason=reason
    if s.off then s.off();s.off=nil end
    if s.work then s.work:close();s.work=nil end
    if s.header then D.cancel_user(s.doc,s.header)end
    if s.parents then D.cancel_user(s.doc,s.parents)end
    if s.generation then D.transition(s.doc,{kind='finish_generation',generation=s.generation})end
    local terminal=s.terminal
    s.doc=nil;s.header=nil;s.parents=nil;s.input=nil;s.parts=nil;s.provider=nil;s.handle=nil;s.terminal=nil;s.reader=nil
    if terminal then pcall(terminal,{status=status,reason=reason})end
end
local function stop(s,reason,failed)
    if s.finished or s.stopping then return false end
    s.stopping=true;s.reason=reason;s.failed=failed==true;s.status='stopping'
    if not s.started or s.resolved then retire(s,s.failed and 'failed' or 'cancelled',reason)
    elseif s.handle then
        s.provider.cancel_operation({epoch=s.epoch,generation=s.generation,operation=s.operation,handle=s.handle},function()
            s.resolved=true;retire(s,s.failed and 'failed' or 'cancelled',s.reason)
        end)
    end
    return true
end
local function captured(s)
    if s.finished then return nil end
    if not D.resolve_user(s.doc,s.parents)then return nil end
    return s.header and D.resolve_user(s.doc,s.header)
end
local function request(s)
    s.started=true;s.status='requesting'
    local callbacks={}
    function callbacks.output(bytes)
        if s.stopping or s.finished then return false end
        if s.line_complete then return true end
        local prefix=bytes:sub(1,4097-s.bytes)
        local newline=prefix:find('\n',1,true)
        if newline then prefix=prefix:sub(1,newline-1);s.line_complete=true end
        if s.bytes+#prefix>4096 then stop(s,'topic too long',true);return false end
        s.bytes=s.bytes+#prefix
        if #prefix>0 then s.parts[#s.parts+1]=prefix end
        return true
    end
    function callbacks.complete()if s.stopping or s.finished then return false end;s.complete=true;return true end
    function callbacks.round()stop(s,'unexpected topic tool call',true);return false end
    function callbacks.failed(reason)stop(s,reason,true)end
    function callbacks.resolved()
        if s.finished then return end;s.resolved=true
        if s.stopping then retire(s,s.failed and 'failed' or 'cancelled',s.reason)
        elseif s.work and s.schedule then s.work:request()end
    end
    local handle=s.provider.request({epoch=s.epoch,generation=s.generation,operation=s.operation,input=s.input,
        cancelled=function()return s.finished or s.stopping end},callbacks)
    if s.finished then return end
    s.handle=handle
    if s.stopping then
        s.provider.cancel_operation({epoch=s.epoch,generation=s.generation,operation=s.operation,handle=handle},function()
            s.resolved=true;retire(s,s.failed and 'failed' or 'cancelled',s.reason)
        end)
    end
end
function M.start(doc,spec,opts)
    opts=opts or {}
    if type(spec)~='table' or type(spec.header)~='table' or type(spec.parents)~='table'
        or #spec.parents<1 or #spec.parents>4 or type(spec.input)~='table'then return nil,'invalid topic source'end
    if opts.buf and D.get(opts.buf)~=doc then return nil,'topic buffer mismatch'end
    local frozen=vim.deepcopy(spec)
    local header,reason=D.capture_user(doc,{operation='automatic-topic',regions={frozen.header}})
    if not header then return nil,reason end
    local parents;parents,reason=D.capture_user(doc,{operation='topic-origin',regions=frozen.parents})
    if not parents then D.cancel_user(doc,header);return nil,reason end
    serial=serial+1
    local job={};local s={doc=doc,header=header,parents=parents,input=frozen.input,operation='topic:'..serial,
        status='acquiring',parts={},bytes=0,schedule=frozen.schedule~=false,terminal=opts.terminal}
    states[job]=s
    if opts.buf then s.reader=Reader.for_buffer(opts.buf)end
    s.provider=Provider.new({dispatcher=opts.dispatcher,tasker=opts.tasker,wire=opts.wire})
    s.work=Deferred.new(function()return M.step(job).status=='more'end)
    s.off=D.subscribe(doc,function(event)
        if s.finished or s.writing then return end
        if event.kind=='reload' or event.kind=='detach' or not captured(s)then stop(s,'source changed')end
        if s.schedule and s.work then s.work:request()end
    end)
    if s.schedule then s.work:request()end
    return job
end
function M.snapshot(job)
    local s=state(job);return {status=s.status,reason=s.reason,generation=s.generation,accepted_bytes=s.bytes,resolved=s.resolved==true}
end
function M.step(job)
    local s=state(job)
    if s.finished or s.stopping then return M.snapshot(job)end
    local source=captured(s)
    if not source then stop(s,'source changed');return M.snapshot(job)end
    local repair=D.repair_step(s.doc)
    if repair.status=='detached'then stop(s,'detached');return M.snapshot(job)end
    if not s.started then
        local span=source.regions[1]
        if span.first.row~=span.last.row or span.last.byte-span.first.byte~=1 then
            stop(s,'topic source must be one question mark',true);return M.snapshot(job)
        end
        if s.reader and not s.source_checked then
            local bytes=s.reader:text(span.first.row,span.first.col,span.last.row,span.last.col,{})[1]
            -- An instrumented reader can invoke native edits. Resolve captured
            -- provenance again before deriving the fresh acquisition proof.
            source=captured(s)
            if not source then stop(s,'source changed');return M.snapshot(job)end
            if bytes~='?'then stop(s,'topic source is not a question mark',true);return M.snapshot(job)end
            s.source_checked=true;span=source.regions[1]
        end
        local row=D.query(s.doc,span.first.row,span.first.row+1)[1]
        if not row or row.opaque or not row.handle then return {status='more'}end
        if not s.generation then
            local registered=D.transition(s.doc,{kind='register_generation'})
            if not registered.ok then stop(s,registered.reason,true);return M.snapshot(job)end
            s.generation=registered.generation;s.epoch=D.snapshot(s.doc).epoch
        end
        local acquired=D.transition(s.doc,{kind='acquire',generation=s.generation,regions={{entity=row.handle,
            marker_revision=1,revision=1,confirmed=true,first=span.first.byte,last=span.last.byte}}})
        if not acquired.ok then
            if acquired.reason=='unconfirmed entity' and repair.status~='idle'then return {status='more'}end
            stop(s,acquired.reason,true);return M.snapshot(job)
        end
        s.grant=acquired.grants[1];s.entity=row.handle
        if not captured(s)then stop(s,'source changed');return M.snapshot(job)end
        request(s)
    end
    if not s.finished and not s.stopping and s.complete and s.resolved then
        local topic=table.concat(s.parts):match('^%s*(.-)%s*$'):gsub('%.$','')
        if topic==''then stop(s,'empty topic',true);return M.snapshot(job)end
        local current=captured(s)
        local grant=D.snapshot(s.doc).grants[s.grant]
        if not current or not grant or grant.status=='revoked'then stop(s,'source changed');return M.snapshot(job)end
        if grant.status~='valid'then return {status='more'}end
        local span=current.regions[1]
        s.writing=true
        local applied=D.apply(s.doc,{epoch=s.epoch,generation=s.generation,grant=s.grant,entity=s.entity,
            revision=grant.revision,operation=s.operation,patches={{start=span.first,finish=span.last,expected_old='?',text=topic}}})
        s.writing=false
        retire(s,applied.status=='applied' and 'applied' or 'failed',applied.reason or applied.error)
    end
    return M.snapshot(job)
end
function M.cancel(job,reason)return stop(state(job),reason or 'cancelled')end
return M
