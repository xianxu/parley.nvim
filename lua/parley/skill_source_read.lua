-- Pure authority for a skill's logical completion and bounded final-read lease.
-- Adapters execute permissions; observations alone never authorize retirement.
local M={}
local function copy(value)local out={};for k,v in pairs(value)do out[k]=v end;return out end
local function number(value)return type(value)=='number' and value==value and value>=0 and value<math.huge end
function M.pool(maximum)
    assert(number(maximum) and maximum>=1 and maximum%1==0,'invalid source read capacity')
    return {maximum=maximum,used=0}
end
function M.new()return {phase='idle',logical=false,slot=false}end
function M.transition(pool,previous,event)
    local next_pool,state,permissions=copy(pool),copy(previous),{}
    local function finish()
        if state.logical then return false end
        state.logical=true;permissions.deliver=true
        permissions.cancel=state.slot or nil
        permissions.release_owner=not state.slot or nil
        return true
    end
    if event.type=='admit' then
        if state.logical or state.phase~='idle' then permissions.reason='terminal or already admitted'
        elseif not number(event.now)then permissions.reason='invalid time'
        elseif pool.used>=pool.maximum then permissions.reason='capacity'
        else
            next_pool.used=pool.used+1;state.slot=true;state.phase='active'
            state.deadline=event.now+5000;state.delay=10;state.due=event.now+state.delay
            permissions.launch=true;permissions.delay=state.delay
        end
    elseif event.type=='finish' then finish()
    elseif event.type=='attach' and state.slot then
        permissions.retain=true;permissions.cancel=state.logical or nil
    elseif event.type=='observation' and state.slot then
        permissions.complete=not state.logical or nil
        if event.physical_resolved==true then
            next_pool.used=pool.used-1;state.slot=false;state.phase='resolved';state.due=nil
            permissions.retire=true;permissions.release_owner=state.logical or nil
        end
    elseif event.type=='tick' and state.slot and state.due and number(event.now) and event.now>=state.due then
        if event.now>=state.deadline then
            state.due=nil;permissions.deadline=true;finish()
        else
            permissions.probe=true;state.delay=math.min(state.delay*2,250)
            state.due=math.min(event.now+state.delay,state.deadline);permissions.delay=state.due-event.now
        end
    elseif event.type=='schedule' and state.slot and state.due and number(event.now) then
        permissions.delay=math.max(1,state.due-event.now)
    end
    return next_pool,state,permissions
end
return M
