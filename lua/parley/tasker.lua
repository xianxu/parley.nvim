local logger = require("parley.logger")
local attempt = require("parley.attempt")
local uv = vim.uv or vim.loop

local M = {}
M._handles = {} -- Compatibility snapshots, never lifecycle authority.
M._queries = {} -- Mutable provider payloads; lifecycle metadata stays private.
M._uv = nil
M._debug = {
    is_busy_calls = 0,
    warnings_suppressed = 0,
    last_warning_time = 0,
    warning_interval = 1,
}
M._cache_metrics = { creation = 0, read = 0, input = 0 }

local records, admissions, queries = {}, {}, {}
local sequence = 0

local function snapshot()
    M._handles = {}
    for _, record in pairs(records) do
        table.insert(M._handles, vim.deepcopy(record.state))
    end
    table.sort(M._handles, function(a, b) return a.order < b.order end)
end

-- Test isolation must be explicit; replacing a public snapshot cannot retire work.
function M._reset()
    records, admissions, queries = {}, {}, {}
    M._handles, M._queries = {}, {}
end

function M.get_attempt(id)
    return records[id] and vim.deepcopy(records[id].state) or nil
end

function M.once(fn)
    local called = false
    return function(...)
        if not called then
            called = true
            fn(...)
        end
    end
end

function M.cleanup_old_queries(count, age)
    if vim.tbl_count(M._queries) <= count then return end
    for id, query in pairs(queries) do
        if query.terminal and os.time() - query.timestamp > age then
            queries[id], M._queries[id] = nil, nil
        end
    end
end

function M.set_query(id, payload)
    sequence = sequence + 1
    M._queries[id] = payload
    payload.timestamp = os.time()
    queries[id] = {
        timestamp = payload.timestamp,
        order = sequence,
        buf = payload.buf,
        terminal = false,
    }
    M.cleanup_old_queries(10, 60)
    vim.schedule(function() vim.cmd("doautocmd User ParleyQueryStarted") end)
end

-- Only unlaunched preparation can be rejected by callers. Attempts own completion.
function M.reject_query(id)
    for _, record in pairs(records) do
        if record.state.query_id == id then return false end
    end
    if not queries[id] then return false end
    queries[id].terminal = true
    return true
end

function M.get_query(id)
    return M._queries[id]
end

function M.get_active_query_by_buf(buf)
    local best, order = nil, -1
    for id, query in pairs(queries) do
        if buf ~= nil and query.buf == buf and not query.terminal and query.order > order then
            best, order = M._queries[id], query.order
        end
    end
    return best
end

local function retire(record)
    local state = record.state
    if admissions[state.admission_key] == state.attempt_id then
        admissions[state.admission_key] = nil
    end
    records[state.attempt_id] = nil
    if queries[state.query_id] then queries[state.query_id].terminal = true end
    snapshot()
end

local function event(record, observation)
    record.state = attempt.transition(record.state, observation)
end

function M.is_busy(buf, skip_warning)
    M._debug.is_busy_calls = M._debug.is_busy_calls + 1
    if buf == nil then return false end
    for _, record in pairs(records) do
        if record.state.buf == buf and attempt.is_unresolved(record.state) then
            if not skip_warning then
                local now = os.time()
                if now - M._debug.last_warning_time >= M._debug.warning_interval then
                    logger.warning("Another Parley process [" .. tostring(record.state.pid)
                        .. "] is already running for buffer " .. buf)
                    M._debug.last_warning_time = now
                else
                    M._debug.warnings_suppressed = M._debug.warnings_suppressed + 1
                end
            end
            return true
        end
    end
    return false
end

-- Explicit unresolved retention: a probe is diagnostic, never exit/drain evidence.
-- There are no polling timers. A caller may request another reconciliation pass.
function M.cleanup_stale_handles()
    for _, record in pairs(records) do
        local state = record.state
        if not state.exited and state.pid then
            local ok, result, detail, code = pcall(record.runtime.kill, state.pid, 0)
            local observation = "unknown"
            if ok and result == 0 then
                observation = "alive"
            elseif ok and (code == "ESRCH" or tostring(detail):find("ESRCH", 1, true)) then
                observation = "missing"
            end
            event(record, { type = "observation", observation = observation })
        end
    end
    snapshot()
end

local function stop_matching(matches, signal)
    local count, failed = 0, false
    signal = signal or 15
    for _, record in pairs(records) do
        local state = record.state
        if matches(state) and attempt.is_unresolved(state) then
            count = count + 1
            if not state.exited and state.accepted_signal ~= signal then
                event(record, { type = "stop_requested" })
                local ok, result, detail, code = pcall(record.runtime.kill, state.pid, signal)
                local observation = "unknown"
                if ok and result == 0 then
                    observation = "accepted"
                else
                    failed = true
                    if ok and (code == "ESRCH" or tostring(detail):find("ESRCH", 1, true)) then
                        observation = "missing"
                    end
                end
                event(record, { type = "signal_observation", observation = observation, signal = signal })
            end
        end
    end
    snapshot()
    return count, failed
end

function M.stop(signal)
    return stop_matching(function() return true end, signal)
end

local function scoped_stop(matches, signal)
    local count, failed = stop_matching(matches, signal)
    if failed then error("task transport stop failed", 0) end
    return count
end

function M.stop_buf(buf, signal)
    return scoped_stop(function(state) return state.buf == buf end, signal)
end

function M.stop_owner(owner, signal)
    if owner == nil then return 0 end
    return scoped_stop(function(state) return state.generation_id == owner end, signal)
end

-- Set cache metrics
---@param metrics table # table with creation and read fields
M.set_cache_metrics = function(metrics)
    if metrics then
        -- Handle nil values explicitly - this allows clearing values
        M._cache_metrics.creation = metrics.creation
        M._cache_metrics.read = metrics.read
        M._cache_metrics.input = metrics.input

        -- Format log message with proper handling for nil values
        local input_str = metrics.input ~= nil and tostring(metrics.input) or "nil"
        local creation_str = metrics.creation ~= nil and tostring(metrics.creation) or "nil"
        local read_str = metrics.read ~= nil and tostring(metrics.read) or "nil"

        logger.debug("Cache metrics updated: input=" .. input_str ..
                    ", creation=" .. creation_str ..
                    ", read=" .. read_str)
    end
end

-- Get cache metrics
---@return table # table with creation, read and input fields
M.get_cache_metrics = function()
    return {
        creation = M._cache_metrics.creation,
        read = M._cache_metrics.read,
        input = M._cache_metrics.input
    }
end


---@param buf number | nil # buffer number
---@param cmd string # command to execute
---@param args table # arguments for command
---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data, io_error)
---@param out_reader function | nil # stdout reader function(err, data)
---@param err_reader function | nil # stderr reader function(err, data)
---@param on_start_error function | nil # scheduled launch rejection callback(message)
M.run = function(buf, cmd, args, callback, out_reader, err_reader, on_start_error, opts)
    logger.debug("run command: " .. cmd .. " " .. table.concat(args, " "), true)
    local run_uv = M._uv or uv

    opts = opts or {}
    sequence = sequence + 1
    local id = opts.attempt_id or ("attempt:" .. sequence)
    local key = opts.admission_key or (buf and ("legacy:" .. buf) or id)
    local record = {
        runtime = run_uv,
        state = attempt.new({
            attempt_id = id,
            generation_id = opts.generation_id,
            query_id = opts.query_id,
            admission_key = key,
            buf = buf,
            order = sequence,
        }),
    }
    local function reject(message)
        event(record, { type = "spawn_failed" })
        if records[id] == record then
            retire(record)
        else
            M.reject_query(opts.query_id)
        end
        if on_start_error then vim.schedule(function() on_start_error(message) end) end
    end
    if records[id] or admissions[key] then
        reject("task start rejected: owner is busy")
        return nil
    end
    records[id], admissions[key] = record, id
    snapshot()

    local handle, pid
    local stdout, stderr
    local pipes_ok, pipes_error = pcall(function()
        stdout = assert(run_uv.new_pipe(false))
        stderr = assert(run_uv.new_pipe(false))
    end)
    if not pipes_ok then
        if stdout then pcall(function() stdout:close() end) end
        if stderr then pcall(function() stderr:close() end) end
        reject("task start failed: " .. tostring(pipes_error))
        return nil
    end
    local stdout_data = ""
    local stderr_data = ""
    local io_error

    local function call_safely(label, fn, ...)
        if not fn then return end
        local call_args = { ... }
        local arg_count = select("#", ...)
        local ok = xpcall(function()
            fn(unpack(call_args, 1, arg_count))
        end, function() return nil end)
        if not ok then
            logger.error(label .. " callback failed")
        end
    end

    local finish = M.once(function()
        vim.schedule(function()
            event(record, { type = "delivered" })
            retire(record)
            call_safely("task terminal", callback,
                record.state.code, record.state.signal, stdout_data, stderr_data, io_error)
            local ok, message = pcall(vim.cmd, "doautocmd User ParleyQueryFinished")
            if not ok then logger.error("ParleyQueryFinished failed: " .. tostring(message)) end
        end)
    end)

    local function maybe_finish()
        if attempt.can_deliver_terminal(record.state) then
            finish()
        end
    end

    local function close_pipe(pipe)
        pcall(function() pipe:read_stop() end)
        if not pipe:is_closing() then
            pipe:close()
        end
    end

    local function on_exit(code, signal)
        event(record, { type = "exit", code = code, signal = signal })
        if handle and not handle:is_closing() then
            handle:close()
        end
        maybe_finish()
    end

    local spawn_error
    local spawn_ok
    spawn_ok, handle, pid = pcall(run_uv.spawn, cmd, {
        args = args,
        stdio = { nil, stdout, stderr },
        hide = true,
        detach = true,
    }, on_exit)
    if not spawn_ok or not handle then
        spawn_error = spawn_ok and pid or handle
        close_pipe(stdout)
        close_pipe(stderr)
        reject("task start failed: " .. tostring(spawn_error))
        return
    end

    logger.debug(cmd .. " command started with pid: " .. pid, true)

    record.handle = handle
    event(record, { type = "spawned", pid = pid })
    if record.state.exited and not handle:is_closing() then handle:close() end
    snapshot()

    local function stdout_callback(err, data)
        if record.state.stdout_eof then return end
        if err then
            logger.error("Error reading stdout: " .. vim.inspect(err))
            io_error = io_error or ("stdout: " .. tostring(err))
        end
        if data then
            stdout_data = stdout_data .. data
        end
        call_safely("stdout reader", out_reader, err, data)
        if err then
            call_safely("stdout reader EOF", out_reader, nil, nil)
        end
        if err or data == nil then
            event(record, { type = "stdout_eof" })
            close_pipe(stdout)
            maybe_finish()
        end
    end

    local function stderr_callback(err, data)
        if record.state.stderr_eof then return end
        if err then
            logger.error("Error reading stderr: " .. vim.inspect(err))
            io_error = io_error or ("stderr: " .. tostring(err))
        end
        if data then
            stderr_data = stderr_data .. data
        end
        call_safely("stderr reader", err_reader, err, data)
        if err then
            call_safely("stderr reader EOF", err_reader, nil, nil)
        end
        if err or data == nil then
            event(record, { type = "stderr_eof" })
            close_pipe(stderr)
            maybe_finish()
        end
    end

    local function start_read(stream, pipe, reader, reject_read)
        local ok, result, detail = pcall(run_uv.read_start, pipe, reader)
        local failed = not ok or result == false
            or (type(result) == "number" and result ~= 0)
            or (result == nil and detail ~= nil)
        if failed then
            local reason = ok and (detail or result) or result
            reject_read(stream .. " read_start failed: " .. tostring(reason))
        end
    end

    start_read("stdout", stdout, stdout_callback, function(message)
        stdout_callback(message, nil)
    end)
    start_read("stderr", stderr, stderr_callback, function(message)
        stderr_callback(message, nil)
    end)
    return id
end

-- grep_directory function removed as it's not used anywhere in the codebase

return M
