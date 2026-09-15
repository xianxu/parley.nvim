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
local function cancelled(s,reason)
    s.status='cancelled';s.reason=reason;s.doc=nil;s.target=nil;s.spec=nil;s.adapters=nil
end
function M.start(doc,spec,adapters)
    if type(spec)~='table' or type(adapters)~='table' then return nil,'invalid submission' end
    for _,name in ipairs({'prepare','request','finalize'})do
        if type(adapters[name])~='function' then return nil,name..' adapter required' end
    end
    local session={}
    local s={doc=doc,status='waiting',spec=vim.deepcopy(spec),adapters={}}
    for name,fn in pairs(adapters)do s.adapters[name]=fn end
    states[session]=s
    local target,reason=Target.start(doc,s.spec,{
        ready=function(value)
            local run_spec={entity=value.entity,first=value.first,last=value.last,dependencies=value.dependencies,
                input=s.spec.input,capabilities=s.spec.capabilities,limits=s.spec.limits,
                input_stale=value.input_stale,schedule=s.spec.schedule}
            local hooks=s.adapters
            local terminal=hooks.terminal
            hooks.terminal=function(result)
                s.result=result;s.status='terminal';s.doc=nil;s.target=nil;s.spec=nil;s.adapters=nil
                if terminal then terminal(result) end
            end
            local runner,err=Runner.start(doc,run_spec,hooks)
            s.target=nil;s.spec=nil;s.adapters=nil
            if not runner then cancelled(s,err);return end
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
