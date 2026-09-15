-- One timer per work owner. A new timer turn separates every bounded slice.
local M={}
function M.new(step)
    assert(type(step)=='function','work callback required')
    local epoch,timer,running,requested,closed=0,nil,false,false,false
    local work={}
    local function stop_timer()
        local previous=timer;timer=nil
        if previous and not previous:is_closing() then previous:stop();previous:close() end
    end
    function work:request()
        if closed then return end
        if running then requested=true;return end
        if timer then return end
        local captured=epoch
        timer=vim.defer_fn(function()
            if closed or captured~=epoch then return end
            timer=nil;running=true;requested=false
            local success,again=pcall(step)
            running=false
            if not success then self:cancel();error(again,0) end
            if not closed and captured==epoch and (again==true or requested) then self:request() end
        end,1)
    end
    function work.cancel(_)
        epoch=epoch+1;requested=false;stop_timer()
    end
    function work:close()
        self:cancel();closed=true;step=nil
    end
    return work
end
return M
