-- One timer per work owner. A new timer turn separates every bounded slice.
-- A step that throws cancels the work; with `on_error` the owner is told, so it
-- can settle what it holds, instead of the error escaping a timer callback
-- where nothing can (#261 M4).
local M={}
function M.new(step,on_error)
    assert(type(step)=='function','work callback required')
    assert(on_error==nil or type(on_error)=='function','error callback must be a function')
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
            if not success then
                self:cancel()
                if on_error then on_error(again) else error(again,0) end
                return
            end
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
