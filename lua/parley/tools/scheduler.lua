-- luacheck: no unused args
-- Process-scoped supervision: effect evidence and physical cleanup are separate.
local O=require('parley.tools.operation')
local R=require('parley.tools.resources')
local M={}
local Result=require('parley.tools.result_evidence')
local function result_copy(value)
    return Result.publish({content=value.content,is_error=value.is_error,truncated=value.truncated,
        reconciliation_required=value.reconciliation_required},value.publication_limit)
end
local function plain(value)
    local state,result=O.accept(O.new(),{generation='copy',attempt='1',round='1',call_id='copy',name='copy',capability_ref='copy',input=value})
    if result.status=='accepted'then return O.get(state,result.key).input end
end
function M.new(opts)
    opts=opts or {};local supplied=opts;opts={}
    for k,v in pairs(supplied)do opts[k]=v end
    opts.context={};for k,v in pairs(supplied.context or {})do opts.context[k]=v end
    local limits=opts.limits or {}
    local max_records=limits.max_records or 128
    local max_bytes=limits.max_result_bytes or 65536
    local total_bytes=limits.max_total_result_bytes or 1048576
    local function integer(n)return type(n)=='number' and n>0 and n<math.huge and n%1==0 end
    assert(integer(max_records) and max_records<=128 and integer(max_bytes) and integer(total_bytes) and total_bytes>=max_bytes,'invalid scheduler limits')
    local ledger=O.new({max_records=max_records});local resources=R.new(limits.resources)
    local generations,records,by_key,by_id={},{},{},{}
    local serial,scope_count,retained=0,0,0
    local schedule=opts.schedule or vim.schedule
    local now=opts.clock_ms or function()return (vim.uv or vim.loop).hrtime()/1e6 end
    local timer=opts.timer or function(delay,fn)local t=vim.defer_fn(fn,delay);return function()if t and not t:is_closing()then t:stop();t:close()end end end
    local service={};local pump,start,observe,arm,set_result;local timer_cancel
    local function transition(r,event)local result;ledger,result=O.transition(ledger,r.key,event);return result end
    local function lifecycle(r)return O.lifecycle(ledger,r.key)end
    local function forget(r)
        if not records[r.op]then return end
        local permission;ledger,permission=O.forget(ledger,r.key)
        if permission.status~='forgotten'then return end
        records[r.op]=nil;by_key[r.key]=nil;by_id[r.id]=nil
        retained=retained-r.bytes;r.scope.count=r.scope.count-1
        if r.scope.count==0 then scope_count=scope_count-1 end
        r.callbacks=nil;r.backend=nil;r.definition=nil;r.input=nil;r.result=nil
    end
    local function dispatch(r)
        if r.delivery then return end;r.delivery=true
        schedule(function()
            r.delivery=false
            if not records[r.op] then return end
            if not transition(r,{type='delivery_begin'}).deliver then return end
            if r.needs_normalize then
                r.needs_normalize=false
                local ok,formatted=pcall(opts.normalize,result_copy(r.result))
                if ok then set_result(r,formatted)else
                    transition(r,{type='presentation_failed',error_ref=r.id})
                    set_result(r,{content='Tool result formatting failed',is_error=true})
                end
            end
            local cb=r.callbacks
            if cb and r.version~=(r.delivered or 0)then
                r.delivered=r.version
                if cb.outcome then pcall(cb.outcome,lifecycle(r).known and 'known' or 'unknown',result_copy(r.result))end
            end
            cb=r.callbacks
            if cb and lifecycle(r).physical and not r.resolved then r.resolved=true;if cb.resolved then pcall(cb.resolved)end end
            transition(r,{type='delivery_end'})
            forget(r)
        end)
    end
    set_result=function(r,value)
        local content=type(value)=='table' and type(value.content)=='string' and value.content or 'Tool outcome unavailable'
        local available=math.max(0,math.min(max_bytes,total_bytes-retained+r.bytes))
        local result=Result.cap({content=content,is_error=type(value)~='table' or value.is_error==true,
            truncated=r.result and r.result.truncated or type(value)=='table' and value.truncated==true,
            reconciliation_required=r.result and r.result.reconciliation_required
                or r.evidence and r.evidence.reconciliation_required==true
                or type(value)=='table' and value.reconciliation_required==true},available)
        retained=retained-r.bytes+#result.content;r.bytes=#result.content
        result.publication_limit=available;r.result=result
    end
    local function settle(r)
        if transition(r,{type='release'}).release_claims then
            local permission
            if R.get(resources,r.id).status=='queued'then resources,permission=R.cancel(resources,r.id)
            else
                -- A crashed tool (#266 M3) is released on its process ending.
                resources,permission=R.release(resources,r.id,
                    {effect=lifecycle(r).known and 'known' or 'ended',evidence_ref=r.id})
            end
            assert(permission.status=='released' or permission.status=='cancelled','resource release rejected')
            pump()
        end
        dispatch(r);arm()
    end
    local function polling(r)transition(r,{type='poll',now=now()})end
    observe=function(r,value,operator)
        if not records[r.op] or type(value)~='table'then return end
        if not operator and value.physical_resolved==true then transition(r,{type='physical',evidence_ref=r.id})end
        local known=value.certainty=='known' and (value.effect=='applied' or value.effect=='not_applied' or value.effect=='partial')
        local evidence=plain(value.evidence or {})
        if operator and (not known or not evidence or next(evidence)==nil)then return false end
        if not lifecycle(r).known then
            local status=lifecycle(r).status
            if status=='executing' or status=='outcome_unknown' and known then
                -- Commit certainty before invoking any presentation code.
                local permission=transition(r,{type=status=='executing' and 'outcome' or 'reconcile',effect=known and 'known' or 'unknown',evidence_ref=r.id,result_ref=r.id})
                if permission.status~='accepted'then return false end
                r.effect=known and value.effect or 'unknown';r.evidence=evidence
                set_result(r,value.result);r.version=r.version+1
                r.needs_normalize=opts.normalize~=nil
            end
        end
        if not lifecycle(r).known then resources=R.unknown(resources,r.id)end
        if not lifecycle(r).known or not lifecycle(r).physical then polling(r)end
        if not r.settling then
            r.settling=true
            schedule(function()
                r.settling=false
                if records[r.op] then settle(r)end
            end)
        end
        return true
    end
    start=function(r)
        if r.scope.closed then service:cancel(r.op);return end
        local permission=transition(r,{type='authorize',capability_ref=r.capability_ref})
        if permission.status~='accepted' or not transition(r,{type='start'}).effect_start then
            service:cancel(r.op);return
        end
        local ctx={};for k,v in pairs(opts.context or {})do ctx[k]=v end
        for k,v in pairs(r.scope.context)do ctx[k]=v end
        ctx.config=plain(r.definition.config or {});ctx.operation_id=r.id;ctx.logical_generation=r.scope.logical
        ctx.generation_id=r.scope.id;ctx.document=r.scope.document;ctx.max_bytes=max_bytes
        ctx.authority=r.authority
        local entry=O.get(ledger,r.key);ctx.attempt=entry.attempt;ctx.round=entry.round;ctx.call_id=entry.call_id;ctx.name=entry.name
        local ok,backend=pcall(r.definition.execute_async,plain(entry.input),ctx,function(value)observe(r,value)end)
        r.definition=nil
        if ok then r.backend=backend else observe(r,{certainty='unknown',effect='unknown',result={content='Tool submission uncertain',is_error=true}})end
        if records[r.op] and lifecycle(r).cancelled and not lifecycle(r).physical and r.backend and r.backend.cancel then pcall(r.backend.cancel,r.backend)end
    end
    pump=function()
        local admitted;resources,admitted=R.pump(resources)
        for _,id in ipairs(admitted)do local r=by_id[id];if r then start(r)end end
    end
    arm=function()
        if timer_cancel then timer_cancel();timer_cancel=nil end
        local earliest
        for _,r in pairs(records)do local poll=lifecycle(r).poll;if poll then earliest=math.min(earliest or math.huge,poll.next)end end
        if earliest then timer_cancel=timer(math.max(1,earliest-now()),function()timer_cancel=nil;service:reconcile_step()end)end
    end
    function service:generation(spec)
        if type(spec)~='table' or type(spec.document)~='string' or #spec.document>4096 or type(spec.logical_generation)~='string' or #spec.logical_generation>4096 or scope_count>=max_records then return nil,'invalid_or_capacity'end
        local context=plain(spec.context or {});if not context or type(spec.capabilities)~='table'then return nil,'invalid'end
        local caps={};local count=0
        for name,def in pairs(spec.capabilities)do
            count=count+1
            if count>128 or type(name)~='string' or #name>4096 or type(def)~='table' or type(def.execute_async)~='function'then return nil,'invalid'end
            local config=plain(def.config or {});if not config then return nil,'invalid'end
            caps[name]={execute_async=def.execute_async,config=config}
        end
        serial=serial+1;local gen={};scope_count=scope_count+1
        generations[gen]={id='generation:'..serial,logical=spec.logical_generation,document=spec.document,context=context,caps=caps,count=0}
        return gen
    end
    function service:execute(gen,spec,callbacks)
        local scope=generations[gen];if not scope then return nil,'retired'end
        if type(spec)~='table'then return nil,'invalid'end
        local def=scope.caps[spec.name];if not def then return nil,'authority'end
        local accepted;ledger,accepted=O.accept(ledger,{generation=scope.id,attempt=spec.attempt,round=spec.round,call_id=spec.call_id,name=spec.name,input=spec.input,capability_ref=scope.id..':'..spec.name})
        if accepted.status=='duplicate' or accepted.status=='reuse'then
            local r=by_key[accepted.key]
            if accepted.status=='reuse' and lifecycle(r).physical and not r.delivery then r.callbacks=callbacks or {};r.delivered=0;r.resolved=false;dispatch(r)end
            return r.op,accepted.status
        end
        if accepted.status~='accepted'then return nil,accepted.status end
        serial=serial+1;local op={};local r={op=op,id='operation:'..serial,key=accepted.key,scope=scope,document=scope.document,authority=spec.authority,claims=plain(spec.claims),name=spec.name,definition=def,capability_ref=scope.id..':'..spec.name,callbacks=callbacks or {},bytes=0,version=0}
        local admission;resources,admission=R.admit(resources,{id=r.id,document=scope.document,generation=scope.id,claims=spec.claims})
        if admission.status~='admitted' and admission.status~='queued'then
            transition(r,{type='reject'});transition(r,{type='release'});transition(r,{type='owner_closed'})
            ledger=O.forget(ledger,r.key);return nil,admission.status
        end
        records[op]=r;by_key[r.key]=r;by_id[r.id]=r;scope.count=scope.count+1
        if admission.status=='admitted'then start(r)end
        return op,admission.status
    end
    function service:cancel(op)
        local r=records[op];if not r then return false end
        if lifecycle(r).cancelled then return true end
        local permission=transition(r,{type='cancel'})
        if permission.status~='accepted'then return false end
        if permission.cancelled_before_effect then
            r.effect='not_applied';r.version=r.version+1
            set_result(r,{content='Tool cancelled before execution',is_error=true});settle(r)
        elseif permission.cancel_backend then
            polling(r);if r.backend and r.backend.cancel then pcall(r.backend.cancel,r.backend)end;arm()
        end
        return true
    end
    function service:close_generation(gen)
        local scope=generations[gen];if not scope then return end
        generations[gen]=nil;scope.closed=true;scope.caps=nil;scope.context=nil;scope.document=nil
        if scope.count==0 then scope_count=scope_count-1;return end
        local pending={};for op,r in pairs(records)do if r.scope==scope then pending[#pending+1]=op;r.callbacks=nil;transition(r,{type='owner_closed'}) end end
        for _,op in ipairs(pending)do local r=records[op];service:cancel(op);if r then forget(r)end end
    end
    function service:reconcile(op,value)local r=records[op];if not r then return false end;return observe(r,value,true)==true end
    function service:reconcile_step(time)
        time=time or now()
        for _,r in pairs(records)do
            local permission=transition(r,{type='tick',now=time})
            if permission.diagnostic then
                if opts.diagnostic then pcall(opts.diagnostic,{operation_id=r.id,message='Tool cleanup or effect remains unresolved'})end
            elseif permission.probe then
                if r.backend and r.backend.reconcile then local ok,value=pcall(r.backend.reconcile,r.backend);if ok and type(value)=='table'then observe(r,value)end end
                if r.backend and r.backend.snapshot then local ok,value=pcall(r.backend.snapshot,r.backend);if ok and type(value)=='table'then observe(r,value)end end
            end
        end
        arm()
    end
    function service:snapshot(op)local r=records[op];if not r then return nil end;return {id=r.id,name=r.name,document=r.document,logical_generation=r.scope.logical,claims=plain(r.claims),evidence=plain(r.evidence or {}),effect=r.effect,certainty=lifecycle(r).known and 'known' or 'unknown',physical_resolved=lifecycle(r).physical,result=result_copy(r.result or {})}end
    function service:stats()
        local stats=R.stats(resources);stats.records=O.stats(ledger).records;stats.result_bytes=retained;stats.generations=scope_count;stats.polling=0
        for _,r in pairs(records)do if lifecycle(r).poll then stats.polling=stats.polling+1 end end;return stats
    end
    return service
end
return M
