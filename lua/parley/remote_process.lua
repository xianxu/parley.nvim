-- Bounded native process evidence for private runtime cleanup. Missing ps rows
-- never authorize reclaim: only explicit ESRCH, confirmed again, proves death.
local M = {}
local uv = vim.uv or vim.loop

local function now_ms() return uv.hrtime() / 1000000 end
local function unknown(reason) return { kind = 'unknown', reason = reason } end

local native = {}
function native.probe(pid)
    local ok, result, reason = pcall(uv.kill, pid, 0)
    if ok and result then return { kind = 'alive' } end
    if ok and type(reason) == 'string' and reason:match('^ESRCH') then return { kind = 'dead' } end
    return unknown(tostring(reason or result or 'native liveness unavailable'))
end

-- Backend contract: read receives an owned PID list/options snapshot; cancel
-- joins all owned work before invoking on_joined. Completion may arrive late.
function native.read(pids, callback, options)
    local encoded = {}
    for _, pid in ipairs(pids) do encoded[#encoded + 1] = tostring(pid) end
    local env = vim.deepcopy(options.env or {})
    env.LC_ALL = 'C'
    local exited, child, joiners = false, nil, {}
    local operation = {}
    function operation.cancel(on_joined)
        if exited then if on_joined then on_joined() end; return end
        if on_joined then joiners[#joiners + 1] = on_joined end
        if child then pcall(child.kill, child, 9) end
    end
    child = vim.system({ options.ps_binary or 'ps', '-p', table.concat(encoded, ','),
        '-o', 'pid=', '-o', 'lstart=' }, { text = true, env = env,
        timeout = math.max(1, math.ceil(options.remaining_ms)) }, function(result)
        -- vim.system's exit callback follows process reaping and pipe closure.
        exited = true
        callback(result)
        for _, on_joined in ipairs(joiners) do on_joined() end
        joiners = {}
    end)
    return operation
end

local function parse(stdout, selected)
    if type(stdout) ~= 'string' or #stdout > 65536 then return nil end
    local starts = {}
    for line in stdout:gmatch('[^\r\n]+') do
        if line:match('%S') then
            local raw_pid, started = line:match('^%s*(%d+)%s+(.+)%s*$')
            local pid = tonumber(raw_pid)
            started = started and vim.trim(started)
            -- lstart is native opaque identity. Validate its C-locale shape;
            -- retain the exact trimmed spelling rather than parsing a date.
            if not pid or not selected[pid] or starts[pid] or not started
                or not started:match('^%a%a%a%s+%a%a%a%s+%d%d?%s+%d%d:%d%d:%d%d%s+%d%d%d%d$') then
                return nil
            end
            starts[pid] = started
        end
    end
    return starts
end

--- Observe at most 256 distinct positive numeric PIDs asynchronously.
--- callback(rows_by_pid, status) runs once; status.kind is complete, unknown,
--- or canceled. alive.started is the trimmed native lstart identity. The
--- caller compares it to its persisted witness; this module never reclaims.
--- options: deadline_ms (default 1000, absolute over the entire operation),
--- ps_binary/env, or source={probe(pid),read(pids,callback,options)} backend.
--- One probe per distinct PID; only initial ESRCH gets a second safety probe.
--- cancel() joins the owned read and deadline before delivering unknown rows.
function M.observe(pids, callback, options)
    options = options or {}
    local source = options.source or native
    local read_options = { ps_binary = options.ps_binary, env = vim.deepcopy(options.env or {}) }
    local deadline = now_ms() + (tonumber(options.deadline_ms) or 1000)
    local selected, distinct, rows, initial = {}, {}, {}, {}
    local invalid = type(pids) ~= 'table'
    if not invalid then
        for key, pid in pairs(pids) do
            if type(key) ~= 'number' or key < 1 or key % 1 ~= 0
                or type(pid) ~= 'number' or pid <= 0 or pid % 1 ~= 0
                or pid > 2147483647 then
                invalid = true
            elseif not selected[pid] then
                distinct[#distinct + 1], selected[pid] = pid, true
            end
        end
    end
    table.sort(distinct)
    invalid = invalid or #distinct > 256
    local timer, reader, done, stopping = nil, nil, false, false
    local operation = {}
    local function stop_timer()
        if timer and not timer:is_closing() then timer:stop(); timer:close() end
        timer = nil
    end
    local function finish(status, reason)
        if done then return end
        done = true
        stop_timer()
        if status ~= 'complete' then
            for _, pid in ipairs(distinct) do rows[pid] = unknown(reason) end
        end
        local result = { kind = status, reason = reason }
        vim.schedule(function() callback(rows, result) end)
    end
    local function stop(status, reason)
        if done or stopping then return end
        stopping = true
        stop_timer()
        if reader then reader.cancel(function() finish(status, reason) end)
        else finish(status, reason) end
    end
    function operation.cancel() stop('canceled', 'canceled') end
    local function probe(pid)
        local ok, result = pcall(source.probe, pid)
        if not ok or type(result) ~= 'table' then return unknown('liveness unavailable') end
        if result.kind ~= 'alive' and result.kind ~= 'dead' then return unknown(result.reason or 'liveness unknown') end
        return result
    end
    local function complete(result)
        if done or stopping then return end
        if now_ms() >= deadline then stop('unknown', 'deadline'); return end
        if not result or result.code ~= 0 then finish('unknown', 'ps failed'); return end
        local starts = parse(result.stdout, selected)
        if not starts then finish('unknown', 'malformed ps evidence'); return end
        for _, pid in ipairs(distinct) do
            if now_ms() >= deadline then stop('unknown', 'deadline'); return end
            local before = initial[pid]
            if before.kind == 'dead' then
                local after = probe(pid)
                rows[pid] = after.kind == 'dead' and not starts[pid] and {kind='dead'}
                    or unknown('contradictory death evidence')
            elseif before.kind == 'alive' and starts[pid] then
                rows[pid] = {kind='alive',started=starts[pid]}
            else rows[pid] = unknown(before.reason or 'missing ps evidence') end
        end
        if now_ms() >= deadline then stop('unknown', 'deadline'); return end
        finish('complete')
    end
    if invalid then finish('unknown', 'invalid pid batch'); return operation end
    timer = uv.new_timer()
    -- Refresh the loop clock first: the deadline is hrtime (#382, #421).
    require('parley.helper').start_deadline(timer, math.max(1, math.ceil(deadline - now_ms())), vim.schedule_wrap(function()
        stop('unknown', 'deadline')
    end))
    local inspect = {}
    for _, pid in ipairs(distinct) do
        if now_ms() >= deadline then stop('unknown', 'deadline'); return operation end
        initial[pid] = probe(pid)
        if initial[pid].kind ~= 'dead' then inspect[#inspect + 1] = pid end
    end
    if #inspect == 0 then
        vim.schedule(function() complete({code=0,stdout=''}) end)
    else
        read_options.remaining_ms = deadline - now_ms()
        local ok, value = pcall(source.read, inspect, function(result)
            vim.schedule(function() complete(result) end)
        end, read_options)
        if ok and type(value) == 'table' and type(value.cancel) == 'function' then reader = value
        else finish('unknown', 'ps unavailable') end
    end
    return operation
end
return M
