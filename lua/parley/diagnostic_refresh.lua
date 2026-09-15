-- Scheduled diagnostics derived from the shared document candidate projection.

local M = {}

function M._new(deps)
    local refresh = {}

    function refresh.refresh(buf)
        if not deps.is_valid(buf) then
            return
        end
        deps.timezone.refresh_buffer(buf)
        deps.footnotes.refresh_footnote_diagnostics(buf)
    end

    function refresh.clear(buf)
        if not deps.is_valid(buf) then
            return
        end
        deps.timezone.clear(buf)
        deps.footnotes.clear_footnote_diagnostics(buf)
    end

    return refresh
end

local Document=require('parley.document')
local Reader=require('parley.line_reader')
local timezone=require('parley.timezone_diagnostics')
local footnotes=require('parley.skill_render')
local define=require('parley.define')
local buffers={}
local schedule
local function tick(job)
    if job.materializing then return end
    job.work=job.work+1
    if job.work>=4096 then coroutine.yield({status='more'});job.work=0 end
end
local function source(job,span)
    local cached,base='',-1
    local function read(col)
        return coroutine.yield({status='read',handle=span.handle,col=col})
    end
    return {length=span.bytes-1,tick=function()tick(job)end,
        on_match=function()job.matches=job.matches+1 end,byte=function(pos)
        tick(job)
        if pos<1 or pos>=span.bytes then return '' end
        local col=pos-1
        if col<base or col>=base+#cached then
            base=math.floor(col/4096)*4096;cached=read(base).bytes
        end
        return cached:sub(col-base+1,col-base+1)
    end}
end
local function candidates(s,definitions,visit)
    local row,cursor=0,nil
    while row<Document.size(s.doc).rows do
        local found=Document.diagnostic_candidates(s.doc,row,Document.size(s.doc).rows,
            {definitions=definitions,cursor=cursor,budget_nodes=2048,budget_entries=4096})
        if found.status=='found' then row=found.span.end_row;cursor=nil;visit(found.span)
        elseif found.status=='not_found' then return
        elseif found.status=='stale' then error('stale diagnostic index')
        else
            cursor=found.status=='budget' and found.cursor or nil
            coroutine.yield({status=found.status=='opaque' and 'opaque' or 'more'})
        end
        coroutine.yield({status='more'})
    end
end
local function start(s)
    local job={work=0,matches=0,timezone={},footnotes={},definitions={}}
    job.thread=coroutine.create(function()
        local first_definition
        candidates(s,true,function(span)
            first_definition=first_definition or span.start_row
            local definition=define.read_diagnostic_definition(source(job,span))
            if definition then job.definitions[#job.definitions+1]=definition;job.matches=job.matches+1 end
        end)
        candidates(s,false,function(span)
            local token=span.metadata.token
            if token.diagnostic_utc_candidate then
                local col,carry=0,''
                repeat
                    local input=coroutine.yield({status='read',handle=span.handle,col=col})
                    local records
                    records,carry=timezone.scan_chunk(input.bytes,col,carry,
                        {to_local=s.opts.to_local or function(value)return os.date('*t',value)end,
                            on_match=function()job.matches=job.matches+1 end})
                    job.work=job.work+#input.bytes
                    for _,record in ipairs(records) do record.handle=span.handle;job.timezone[#job.timezone+1]=record end
                    col=col+#input.bytes
                    if job.work>=4096 then coroutine.yield({status='more'});job.work=0 end
                    if input.eol then break end
                until false
            end
            if token.diagnostic_reference_candidate and first_definition and span.start_row<first_definition then
                define.read_diagnostic_references(source(job,span),job.definitions,function(record)
                    record.handle=span.handle;job.footnotes[#job.footnotes+1]=record
                end)
            end
        end)
        -- Bounded membership/coordinate validation precedes output materialization.
        for _,records in ipairs({job.timezone,job.footnotes}) do
            for _,record in ipairs(records) do
                tick(job)
                local live=Document.lookup(s.doc,record.handle)
                if not live then error('detached diagnostic source') end
                record.lnum=live.start_row
                coroutine.yield({status='more'})
            end
        end
        return {status='publish'}
    end)
    s.job=job
end
local function publish(s)
    local job=s.job;job.materializing=true
    local records={}
    for _,record in ipairs(job.footnotes) do
        local value=define.materialize_diagnostic(record)
        value.lnum=record.lnum;value.end_lnum=record.lnum
        records[#records+1]=value
    end
    local utc=timezone.publish(s.buf,job.timezone)
    local foot=footnotes.publish_footnotes(s.buf,records)
    local work={native_diagnostic_entries=utc.entries+foot.entries,
        diagnostic_message_bytes=utc.message_bytes+foot.message_bytes,native_diagnostic_sets=2}
    local event={operation='diagnostic_publication'};for key,value in pairs(work) do event[key]=value end
    Reader.record_work(s.buf,event)
    s.job=nil;s.dirty=false
    return {status='idle',work=work}
end
function M.step(buf)
    local s=buffers[buf]
    if not s or s.dead then return {status='detached'} end
    if s.failure then return {status='error',reason=s.failure} end
    if not s.dirty then return {status='idle'} end
    if not s.job then start(s) end
    local job=s.job
    if job.pending and job.pending.status=='publish' then return publish(s) end
    local input
    if job.pending and job.pending.status=='read' then
        local request=job.pending
        local live=Document.lookup(s.doc,request.handle)
        if not live then s.job=nil;return {status='more'} end
        input=(s.opts.reader or Reader.for_buffer(buf)):chunk({row=live.start_row,col=request.col,max_bytes=4096})
    end
    local success,result=coroutine.resume(job.thread,input)
    if not success then
        s.job=nil;s.failure=tostring(result)
        return {status='error',reason=s.failure}
    end
    job.pending=result
    result.work={diagnostic_bytes_processed=job.work,diagnostic_matches_processed=job.matches}
    Reader.record_work(buf,{operation='diagnostic_parse',diagnostic_bytes_processed=job.work,
        diagnostic_matches_processed=job.matches})
    job.work=0;job.matches=0
    return result
end
schedule=function(s)
    if s.dead or s.scheduled or s.opts.schedule==false then return end
    s.scheduled=true
    vim.schedule(function()
        s.scheduled=false
        if s.dead or buffers[s.buf]~=s then return end
        local result=M.step(s.buf)
        if result.status~='idle' and result.status~='opaque' and result.status~='detached' and result.status~='error' then schedule(s) end
    end)
end
function M.refresh(buf,opts)
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
    local s=buffers[buf]
    if not s then
        local doc=Document.get(buf) or Document.attach(buf,{patterns=require('parley.document.lexical').patterns(require('parley.config'))})
        if not doc then return end
        s={buf=buf,doc=doc,opts=opts or {},dirty=true};buffers[buf]=s
        s.unsubscribe=Document.subscribe(doc,function(event)
            if event.kind=='detach' then M.clear(buf)
            elseif event.kind=='reload' or event.kind=='edit' and event.diagnostic_changed~=false then
                s.job=nil;s.failure=nil;s.dirty=true;schedule(s)
            elseif event.kind=='repair' and s.dirty then schedule(s) end
        end)
    elseif opts then
        for key,value in pairs(opts) do s.opts[key]=value end
        if opts.to_local then s.dirty=true;s.job=nil;s.failure=nil end
    end
    schedule(s)
    return s
end
function M.drain(buf,limit)
    local result
    for _=1,limit or 10000 do
        local s=buffers[buf];if not s then return {status='detached'} end
        Document.repair_step(s.doc)
        result=M.step(buf)
        if result.status=='idle' or result.status=='detached' or result.status=='error' then return result end
    end
    return result
end
function M.clear(buf)
    local s=buffers[buf]
    if s then s.dead=true;s.job=nil;s.unsubscribe();buffers[buf]=nil end
    if vim.api.nvim_buf_is_valid(buf) then timezone.clear(buf);footnotes.clear_footnote_diagnostics(buf) end
end
return M
