local M = {}

M.new = function(uv, limit)
    local queued = {}
    local active = {}
    local active_count = 0
    local cancelled = false

    local pump
    pump = function()
        while not cancelled and active_count < limit and #queued > 0 do
            local job = table.remove(queued, 1)
            local token = {}
            active[token] = true
            active_count = active_count + 1

            local finished = false
            local function finish(...)
                if finished then
                    return
                end
                finished = true
                if active[token] then
                    active[token] = nil
                    active_count = active_count - 1
                end
                if cancelled then
                    if job.dispose then
                        pcall(job.dispose, ...)
                    end
                else
                    job.callback(...)
                    pump()
                end
            end

            local ok, request = pcall(job.start, finish)
            if active[token] then
                token.request = request
            end
            if not ok then
                finish("filesystem operation raised")
            end
        end
    end

    local queue = {}
    -- dispose receives a late completion after cancellation so callers can
    -- release resources created by operations whose requests could not stop.
    queue.call = function(_, start, callback, dispose)
        if not cancelled then
            queued[#queued + 1] = { start = start, callback = callback, dispose = dispose }
            pump()
        end
    end
    queue.cancel = function()
        if cancelled then
            return
        end
        cancelled = true
        queued = {}
        if type(uv.cancel) == "function" then
            for token in pairs(active) do
                if token.request ~= nil then
                    pcall(uv.cancel, token.request)
                end
            end
        end
        active = {}
        active_count = 0
    end
    return queue
end

return M
