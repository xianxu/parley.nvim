-- Generation adapters hand cancelled operations to one process-scoped owner.
-- No document objects or current editor selection enter this module.
local Dispatch=require('parley.tools.dispatcher')
local Result=require('parley.tools.result_evidence')
local Scheduler=require('parley.tools.scheduler')
local Tasker=require('parley.tasker')
local M={}
local DEFAULTS={max_records=128,max_result_bytes=524288,max_total_result_bytes=16777216,max_file_bytes=1048576,
    resources={running=16,queued=128,per_document=8,per_generation=4,queued_per_generation=32,max_claims=32},
    process={provider_attempts=16,tool_attempts=16,total_attempts=32,document_generations=4,
        document_tools=8,generation_tools=4,retained_bytes=16777216}}
local configured=vim.deepcopy(DEFAULTS)
local singleton,clients=nil,0
local operations={}
local public_serial=0
local public_ids=setmetatable({},{__mode='k'})
local function invoke(fn,...)if fn then pcall(fn,...)end end
local function prune()
    for id,op in pairs(operations)do if not singleton or not singleton:snapshot(op)then operations[id]=nil end end
end
function M.defaults()return vim.deepcopy(DEFAULTS)end
function M.configure(value)
    if type(value)~='table'then return {ok=false,reason='invalid tool limits'}end
    local candidate=vim.deepcopy(configured)
    local function merge(target,input,maximum)
        for key,v in pairs(input)do
            if maximum[key]==nil then return false end
            if type(maximum[key])=='table'then
                if type(v)~='table' or not merge(target[key],v,maximum[key])then return false end
            elseif type(v)~='number' or v<1 or v>maximum[key] or v%1~=0 then return false
            else target[key]=v end
        end
        return true
    end
    if not merge(candidate,value,DEFAULTS) or candidate.max_total_result_bytes<candidate.max_result_bytes then
        return {ok=false,reason='invalid tool limits'}
    end
    if vim.deep_equal(candidate,configured)then return {ok=true}end
    if clients>0 or singleton and (singleton:stats().records>0 or singleton:stats().generations>0)
        or Tasker.stats().active>0 then return {ok=false,reason='tool service is active'}end
    local applied=Tasker.configure_limits(candidate.process);if not applied.ok then return applied end
    configured=candidate;singleton=nil;operations={};return {ok=true}
end
local function shared()
    if not singleton then
        local applied=Tasker.configure_limits(configured.process);assert(applied.ok,applied.reason)
        singleton=Scheduler.new({limits=configured,
            context={filesystem=require('parley.tools.filesystem').new({max_bytes=configured.max_file_bytes}),tasker=Tasker},
            diagnostic=function(value)
                local id=value.operation_id
                for public,op in pairs(operations)do
                    local snapshot=singleton:snapshot(op)
                    if snapshot and snapshot.id==id then id=public;break end
                end
                vim.notify('Parley tool '..tostring(id)..' remains unresolved',vim.log.levels.WARN)
            end})
    end
    return singleton
end
function M.stats()
    prune();return singleton and singleton:stats() or {records=0,generations=0,result_bytes=0,polling=0}
end
function M.list()
    prune();local result={}
    for id,op in pairs(operations)do local snapshot=singleton:snapshot(op)
        result[#result+1]={id=id,name=snapshot.name,document=snapshot.document,logical_generation=snapshot.logical_generation,
            claims=snapshot.claims,evidence=snapshot.evidence,effect=snapshot.effect,certainty=snapshot.certainty,physical_resolved=snapshot.physical_resolved}
    end
    table.sort(result,function(a,b)return a.id<b.id end);return result
end
function M.reconcile(id,evidence)
    prune();local op=operations[id];if not op then return false end
    return singleton:reconcile(op,evidence)
end
local function scalar(value)
    if type(value)=='string' and #value>0 and #value<=4096 then return value end
    if type(value)=='number' and value>=0 and value<math.huge and value%1==0 then return tostring(value)end
end
function M.new(opts)
    if type(opts)~='table' or opts.allowed_tools~=nil and type(opts.allowed_tools)~='table'then return nil,'captured tool options required'end
    local registry=opts.registry or require('parley.tools')
    local ok,definitions=pcall(function()
        if registry.select then return registry.select(vim.deepcopy(opts.allowed_tools or {}))end
        local defs={};for _,name in ipairs(opts.allowed_tools or {})do defs[#defs+1]=assert(registry.get(name),'unknown tool')end;return defs
    end)
    if not ok then return nil,tostring(definitions)end
    local maximum=opts.max_result_bytes or configured.max_result_bytes
    if type(maximum)~='number' or maximum<1 or maximum>configured.max_result_bytes or maximum%1~=0 then return nil,'invalid result limit'end
    if next(definitions)==nil then
        local refused=setmetatable({},{__mode='k'})
        return {start=function(call,_,events)
            events=events or {};local h={};refused[h]=true
            invoke(events.outcome,'known',Result.publish({id=type(call)=='table' and call.id or '',name=type(call)=='table' and call.name or '',
                content='Tool is not in captured capabilities',is_error=true},maximum));invoke(events.resolved);return h
        end,cancel=function(h,done)if not refused[h]then return false end;invoke(done);return true end,close=function()end}
    end
    if not scalar(opts.buf)then return nil,'captured buffer required'end
    local profile,err=Dispatch.capture(definitions,{root_policy=opts.root_policy,buf=opts.buf,
        chat_roots=opts.chat_roots,help_root=opts.help_root,page_limit=opts.page_limit,max_bytes=maximum,
        max_file_bytes=configured.max_file_bytes,deferred_refresh_buf=opts.deferred_refresh_buf})
    if not profile then return nil,err end
    local service=opts.scheduler;local injected=service~=nil
    local buf=scalar(opts.buf);local generation,identity,closed
    local records=setmetatable({},{__mode='k'});local producer={}
    if not injected then clients=clients+1 end
    local function refuse(call,events,reason)
        invoke(events.outcome,'known',Result.publish({id=type(call)=='table' and call.id or '',name=type(call)=='table' and call.name or '',
            content=tostring(reason),is_error=true},maximum))
        invoke(events.resolved);local h={};records[h]={refused=true};return h
    end
    function producer.start(call,ctx,events)
        events=events or {};ctx=ctx or {}
        local epoch,logical,round,attempt=scalar(ctx.epoch),scalar(ctx.generation),scalar(ctx.round),scalar(ctx.attempt)
        if closed or not epoch or not logical or not round or not attempt then return refuse(call,events,'tool generation is unavailable')end
        local current=buf..':'..epoch..':'..logical
        if identity and identity~=current then return refuse(call,events,'tool generation changed')end
        local prepared,why=Dispatch.prepare(profile,call);if not prepared then return refuse(call,events,why)end
        service=service or shared()
        if not generation then
            generation,why=service:generation({document=buf..':'..epoch,logical_generation=Tasker.scope_key(epoch,logical),
                context=Dispatch.context(profile),capabilities=Dispatch.capabilities(profile)})
            if not generation then return refuse(call,events,why)end
            identity=current
        end
        local call_id,call_name=call.id,call.name
        local handle={};local r={events=events,token=prepared.token};records[handle]=r
        local pending,resolved
        local function deliver(kind,result)
            if not r.op then pending={kind,result};return end
            if not r.events or r.finished then return end
            if kind=='known' then
                if not r.normalized then
                    local snapshot=service:snapshot(r.op)
                    local formatted,value=pcall(Dispatch.normalize,r.token,result,snapshot and snapshot.evidence)
                    r.normalized=formatted and value or Result.publish({id=call_id,name=call_name,
                        content='Tool result formatting failed',is_error=true},maximum)
                    r.token=nil
                end
                result=vim.deepcopy(r.normalized)
            end
            invoke(r.events.outcome,kind,result)
            if kind=='known' and r.physical then r.events=nil;r.normalized=nil;r.finished=true end
        end
        local function complete()
            if not r.op then resolved=true;return end
            if r.physical then return end;r.physical=true
            local callbacks=r.events
            if r.normalized then r.events=nil;r.token=nil;r.normalized=nil;r.finished=true end
            if callbacks then invoke(callbacks.resolved)end
        end
        local op,status=service:execute(generation,{attempt=attempt,round=round,call_id=call.id,name=call.name,
            input=prepared.input,claims=prepared.claims,authority=prepared.authority},{outcome=deliver,resolved=complete})
        if not op then records[handle]=nil;return refuse(call,events,status)end
        r.op=op
        if not injected then
            prune()
            if not public_ids[op]then public_serial=public_serial+1;public_ids[op]='tool-operation:'..public_serial end
            operations[public_ids[op]]=op
        end
        if closed or not r.events then service:cancel(op)
        else
            if pending then deliver(unpack(pending))end
            if resolved then complete()end
        end
        return handle
    end
    function producer.cancel(handle,done)
        local r=records[handle]
        if not r then return false end
        if r.refused then invoke(done);return true end
        if not r.op then r.events=nil;r.token=nil;return false end
        service:cancel(r.op)
        -- #266 M3 review BR-15: a tool the scheduler had not started is settled by
        -- its own outcome ("cancelled before execution") and cleanup, delivered as
        -- usual. Handing it to the supervisor would erase the evidence that it
        -- never ran, and the transcript would say it was cancelled while running.
        local snapshot=service:snapshot(r.op)
        if snapshot and snapshot.physical_resolved then return true end
        r.events=nil;r.token=nil
        invoke(done,{supervised=true});return true
    end
    function producer.close()
        if closed then return end;closed=true
        for _,r in pairs(records)do r.events=nil;r.token=nil end
        records=setmetatable({},{__mode='k'});profile=nil
        if generation then service:close_generation(generation);generation=nil end
        if not injected then clients=clients-1;prune()end
    end
    return producer
end
return M
