-- Command-time source capture followed by runner admission in the same callback
-- that proves the target. No asynchronous callback re-enters the current cursor.
local Target=require('parley.response_target')
local Runner=require('parley.generation_runner')
local D=require('parley.document')
local M={}
local states=setmetatable({},{__mode='k'})
local function state(session)return assert(states[session],'invalid response submission')end
local function snapshot(s)
    return {status=s.status,reason=s.reason,generation=s.runner and Runner.snapshot(s.runner) or s.result}
end
local function regions(value,preparation)
    if preparation==nil then return {{first=value.first,last=value.last}}end
    if type(preparation)~='table' or type(preparation.regions)~='table'
        or #preparation.regions<1 or #preparation.regions>16 then return nil end
    local out={}
    for _,region in ipairs(preparation.regions)do
        if type(region)~='table' then return nil end
        local first,last=region.first_offset,region.last_offset
        if type(first)~='number' or type(last)~='number' or first%1~=0 or last%1~=0
            or first<0 or last<first or last>value.last-value.first then return nil end
        out[#out+1]={first=value.first+first,last=value.first+last}
    end
    return out
end
local function reject(adapters,reason)
    local rejected=type(adapters)=='table' and adapters.rejected
    if type(rejected)=='function' then pcall(rejected,reason) end
    return nil,reason
end
local function cancelled(s,reason)
    if s.status~='waiting' then return end
    local adapters=s.adapters
    s.status='cancelled';s.reason=reason;s.doc=nil;s.target=nil;s.spec=nil;s.adapters=nil
    -- Host notification runs after retirement and cannot interrupt target cleanup.
    reject(adapters,reason)
end
function M.start(doc,spec,adapters)
    if type(spec)~='table' or type(adapters)~='table' then return reject(adapters,'invalid submission') end
    for _,name in ipairs({'prepare','request','finalize'})do
        if type(adapters[name])~='function' then return reject(adapters,name..' adapter required') end
    end
    local session={}
    local s={doc=doc,status='waiting',spec=vim.deepcopy(spec),adapters={}}
    for name,fn in pairs(adapters)do s.adapters[name]=fn end
    states[session]=s
    local target,reason=Target.start(doc,s.spec,{
        ready=function(value)
            local spans=regions(value,s.spec.preparation)
            if not spans then cancelled(s,'preparation outside captured output');return end
            local primary=table.remove(spans,1)
            local run_spec={entity=value.entity,first=primary.first,last=primary.last,dependencies=value.dependencies,
                preparation_regions=spans,
                input=s.spec.input,capabilities=s.spec.capabilities,limits=s.spec.limits,
                input_stale=value.input_stale,schedule=s.spec.schedule}
            local hooks=s.adapters
            local terminal=hooks.terminal
            hooks.terminal=function(result)
                s.result=result;s.status='terminal';s.doc=nil;s.target=nil;s.spec=nil;s.adapters=nil
                if terminal then terminal(result) end
            end
            local runner,err=Runner.start(doc,run_spec,hooks)
            if not runner then cancelled(s,err);return end
            s.target=nil;s.spec=nil;s.adapters=nil
            s.runner=runner;s.status='running'
        end,
        cancelled=function(why)cancelled(s,why)end,
    })
    if not target then cancelled(s,reason);states[session]=nil;return nil,reason end
    s.target=target
    return session
end
function M.snapshot(session)return snapshot(state(session))end
function M.step(session)
    local s=state(session)
    if s.status=='waiting' then
        Target.step(s.target)
        return {status=(s.status=='waiting' or s.status=='running') and 'more' or s.status}
    end
    if s.status~='running' then return {status=s.status}end
    local repair=D.repair_step(s.doc)
    local result=Runner.step(s.runner)
    if result.status=='waiting' and repair.status~='idle' and repair.status~='detached' then return {status='more'}end
    return result
end
function M.cancel(session,reason)
    local s=state(session)
    if s.status=='waiting' then return Target.cancel(s.target,reason)end
    if s.status=='running' then return Runner.cancel(s.runner,reason)end
    return false
end
function M.resume(session,policy_ref)
    local s=state(session)
    if s.status~='running' then return {accepted=false,reason='not running'}end
    return Runner.resume(s.runner,policy_ref)
end
return M
