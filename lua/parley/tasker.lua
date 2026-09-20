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
-- Scopes already stopped (#261 M4 review): a generation's key is never live
-- again, so a helper chain resuming after the scope kill (a keychain read, a
-- login) cannot spawn into it. Bounded: the oldest key is forgotten first.
local stopped_scopes, stopped_order, STOPPED_LIMIT = {}, {}, 1024
local sequence = 0

-- How long a process outside any generation may run (#261 M3): nobody stops
-- it, so it names its own end. Past it, TERM, then KILL 2 s later.
M.deadline = {
    prompt = 600000, -- a human may be answering: keychain dialog, pinentry, biometrics
    http = 120000, -- one request and its response
    convert = 60000, -- pandoc or textutil on one document
    stream = 900000, -- an LLM stream with no owner: long reasoning output
}

local DEFAULT_LIMITS={provider_attempts=16,tool_attempts=16,total_attempts=32,
    document_generations=4,document_tools=8,generation_tools=4,retained_bytes=16*1024*1024}
local limits=vim.deepcopy(DEFAULT_LIMITS)
local retained_bytes=0
local schedule_reconcile,close_reconcile
local function clock()return M._clock and M._clock() or uv.hrtime()/1000000 end
local function integer(value,maximum)return type(value)=='number' and value>=1 and value<=maximum and value%1==0 end
-- Limits may be lowered for a profile, but cannot exceed the shared hard bounds.
-- Utility processes consume the total ceiling rather than an uncounted allowance.
function M.configure_limits(value)
    if type(value)~='table'then return {ok=false,reason='invalid process limits'}end
    local next_limits=vim.deepcopy(limits)
    for name,limit in pairs(value)do
        if not DEFAULT_LIMITS[name] or not integer(limit,DEFAULT_LIMITS[name])then return {ok=false,reason='invalid process limit: '..tostring(name)}end
        next_limits[name]=limit
    end
    limits=next_limits;return {ok=true}
end
function M.stats()
    local out={active=0,providers=0,tools=0,retained_bytes=retained_bytes,timers=0}
    for _,record in pairs(records)do
        out.active=out.active+1
        if record.state.kind=='provider'then out.providers=out.providers+1 end
        if record.state.kind=='tool'then out.tools=out.tools+1 end
        if record.timer then out.timers=out.timers+1 end
    end
    return out
end
local function capacity(candidate)
    local total,providers,tools,document_tools,generation_tools=0,0,0,0,0
    local generations={}
    for _,record in pairs(records)do
        local state=record.state;total=total+1
        if state.kind=='provider'then providers=providers+1 end
        if state.kind=='tool'then tools=tools+1 end
        if candidate.buf~=nil and state.buf==candidate.buf then
            generations[state.logical_generation]=true
            if state.kind=='tool'then document_tools=document_tools+1
                if state.logical_generation==candidate.logical_generation then generation_tools=generation_tools+1 end
            end
        end
    end
    if total>=limits.total_attempts or candidate.kind=='provider' and providers>=limits.provider_attempts
        or candidate.kind=='tool' and tools>=limits.tool_attempts then return false end
    if candidate.buf~=nil then
        if not generations[candidate.logical_generation] and vim.tbl_count(generations)>=limits.document_generations then return false end
        if candidate.kind=='tool' and (document_tools>=limits.document_tools or generation_tools>=limits.generation_tools)then return false end
    end
    return true
end
local function collection()return {pieces={},chunks={},piece_bytes=0,bytes=0}end
local function collect(buffer,data)
    local offset=1
    while offset<=#data do
        local last=math.min(#data,offset+65536-buffer.piece_bytes-1)
        buffer.pieces[#buffer.pieces+1]=data:sub(offset,last)
        buffer.piece_bytes=buffer.piece_bytes+last-offset+1;offset=last+1
        if buffer.piece_bytes==65536 or #buffer.pieces==128 then
            buffer.chunks[#buffer.chunks+1]=table.concat(buffer.pieces)
            buffer.pieces={};buffer.piece_bytes=0
        end
    end
    buffer.bytes=buffer.bytes+#data
end
local function collected(buffer)
    if #buffer.pieces>0 then buffer.chunks[#buffer.chunks+1]=table.concat(buffer.pieces)end
    return table.concat(buffer.chunks)
end

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

local function snapshot()
    M._handles = {}
    for _, record in pairs(records) do
        table.insert(M._handles, vim.deepcopy(record.state))
    end
    table.sort(M._handles, function(a, b) return a.order < b.order end)
end

-- Test isolation must be explicit; replacing a public snapshot cannot retire work.
function M._reset()
    for _,record in pairs(records)do if close_reconcile then close_reconcile(record)end end
    limits=vim.deepcopy(DEFAULT_LIMITS);retained_bytes=0
    records, admissions, queries = {}, {}, {}
    stopped_scopes, stopped_order = {}, {}
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

local function close_timer(timer)
    if timer then pcall(function()timer:stop()end);pcall(function()if not timer:is_closing()then timer:close()end end)end
end

local function retire(record)
    close_reconcile(record)
    close_timer(record.deadline);record.deadline=nil
    retained_bytes=math.max(0,retained_bytes-(record.retained or 0));record.retained=0
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

-- Where a signal goes (#261 M3): a scoped run's whole group, so a grandchild
-- holding the pipe dies with it; an unscoped run's pid, only while it has not
-- exited, since a reaped pid can be reused. A group id is not reused while any
-- member lives.
local function target(state)
    -- kill(0) and kill(-0) signal Neovim's own group: never a record's target.
    if not state.pid or state.pid <= 0 then return nil end
    if state.group then return -state.pid end
    if not state.exited then return state.pid end
end

-- Sends `signal` (0 probes) and returns the observation. ESRCH is `missing`, an
-- answer rather than a failure; only a throw or another errno is `unknown`.
local function send(record, signal)
    local to = target(record.state)
    if not to then return "missing" end
    local ok, result, detail, code = pcall(record.runtime.kill, to, signal)
    if ok and result == 0 then return signal == 0 and "alive" or "accepted" end
    if ok and (code == "ESRCH" or tostring(detail):find("ESRCH", 1, true)) then return "missing" end
    return "unknown"
end

close_reconcile=function(record)
    local timer=record.timer;record.timer=nil
    close_timer(timer)
end
schedule_reconcile=function(record)
    if not record.state.reconcile_due or not attempt.is_unresolved(record.state)then close_reconcile(record);return end
    if not record.timer then
        if not record.runtime.new_timer then return end
        local ok,timer=pcall(record.runtime.new_timer)
        if not ok or not timer then record.state.timer_error=true;return end
        record.timer=timer
    end
    local delay=math.max(1,math.ceil(record.state.reconcile_due-clock()))
    local ok=pcall(function()record.timer:start(delay,0,function()
        vim.schedule(function()if records[record.state.attempt_id]==record then M.reconcile_step()end end)
    end)end)
    if not ok then record.state.timer_error=true;close_reconcile(record)end
end
-- Reconciliation probes liveness, and sends SIGKILL once a stop's grace has run
-- out (#261 M3). After five seconds the timer retires, while the unresolved
-- attempt and its admission slot remain until positive drain.
function M.reconcile_step(now)
    now=now or clock()
    for _,record in pairs(records)do
        if attempt.is_unresolved(record.state)then
            local effects;record.state,effects=attempt.transition(record.state,{type='reconcile_tick',now=now})
            if effects.escalate then
                event(record,{type='signal_observation',observation=send(record,9),signal=9})
            end
            if effects.probe and target(record.state)then
                event(record,{type='observation',observation=send(record,0)})
            end
            if effects.unresolved then
                close_reconcile(record)
                logger.warning('Parley process ['..tostring(record.state.pid)
                    ..'] remains unresolved after cancellation/exit; resource ownership retained')
                if record.on_unresolved then pcall(record.on_unresolved,vim.deepcopy(record.state))end
            else schedule_reconcile(record)end
        else close_reconcile(record)end
    end
    snapshot();return M.stats()
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
-- Manual probes do not bypass the finite cancellation reconciliation schedule.
function M.cleanup_stale_handles()
    for _, record in pairs(records) do
        local state = record.state
        if target(state) then event(record, { type = "observation", observation = send(record, 0) }) end
    end
    snapshot()
end

-- Stops every unresolved record that matches: the signal now, SIGKILL at +2 s
-- while it stays unresolved (attempt.lua). A repeated stop inside one window
-- sends nothing new unless the signal differs. `failed` means a signal could not
-- be delivered for a reason other than the process being gone.
local function stop_matching(matches, signal, cause)
    local count, failed = 0, false
    signal = signal or 15
    for _, record in pairs(records) do
        if matches(record.state) and attempt.is_unresolved(record.state) then
            count = count + 1
            local accepted = record.state.accepted_signal
            local effects
            record.state, effects = attempt.transition(record.state, { type = "stop_requested", now = clock(), cause = cause })
            if effects.opened or accepted ~= signal then
                local observation = send(record, signal)
                if observation == "unknown" then failed = true end
                event(record, { type = "signal_observation", observation = observation, signal = signal })
            end
            schedule_reconcile(record)
        end
    end
    snapshot()
    return count, failed
end

function M.stop(signal)
    return stop_matching(function() return true end, signal)
end

-- The one spelling of a generation's process scope (#261 M3).
function M.scope_key(epoch, generation)
    return tostring(epoch) .. ":" .. tostring(generation)
end

-- Whether run options place a process in a generation's scope; an unscoped
-- run must name its deadline.
function M.is_scoped(opts)
    return opts ~= nil and (opts.logical_generation or opts.generation_id) ~= nil
end

-- How a run ended, in words for a message or a log: its io_error when there
-- is one (a kill Parley caused, a pipe error, an overflow, a refusal), else its
-- exit code — never a nil code (#261 M3 review BR-38).
function M.exit_reason(code, signal, io_error)
    if io_error then return tostring(io_error) end
    if signal and signal ~= 0 then return ("exit %s, signal %s"):format(tostring(code), tostring(signal)) end
    return "exit " .. tostring(code)
end

-- Records still held after their stop window: a process the kernel keeps.
function M.held()
    local out = {}
    for _, record in pairs(records) do
        local state = record.state
        if state.unresolved_visible then
            out[#out + 1] = { pid = state.pid, kind = state.kind, since = state.reconcile_started,
                scope = state.group and state.logical_generation or nil }
        end
    end
    table.sort(out, function(a, b) return (a.pid or 0) < (b.pid or 0) end)
    return out
end

-- Leaving Neovim: SIGKILL to everything still live.
function M.leave()
    return stop_matching(function() return true end, 9, "leave")
end

local function scoped_stop(matches, signal)
    local count, failed = stop_matching(matches, signal)
    if failed then error("task transport stop failed", 0) end
    return count
end

function M.stop_buf(buf, signal)
    return scoped_stop(function(state) return state.buf == buf end, signal)
end

function M.stop_scope(key, signal)
    if key == nil then return 0 end
    if not stopped_scopes[key] then
        stopped_scopes[key] = true; stopped_order[#stopped_order + 1] = key
        if #stopped_order > STOPPED_LIMIT then stopped_scopes[table.remove(stopped_order, 1)] = nil end
    end
    return scoped_stop(function(state) return state.group and state.logical_generation == key end, signal)
end

function M.stop_owner(owner, signal)
    if owner == nil then return 0 end
    return scoped_stop(function(state) return state.generation_id == owner end, signal)
end

function M.stop_attempt(id,signal)
    return scoped_stop(function(state)return state.attempt_id==id end,signal)
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
---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data, io_error);
--- code is nil whenever io_error is set, and a refusal delivers (nil, nil, nil, nil, reason)
---@param out_reader function | nil # stdout reader function(err, data)
---@param err_reader function | nil # stderr reader function(err, data)
---@param on_start_error function | nil # scheduled launch rejection callback(message)
---@param opts table | nil # Captured cwd/kind/owner, bounded collection policy, and unresolved callback.
-- Provider readers use collect_stdout=false: bounded delivery chunks do not cap the
-- total answer. Tool/utility output is retained within per-stream and shared caps.
-- An overflow requests cancellation; only exit plus both EOFs releases ownership.
M.run = function(buf, cmd, args, callback, out_reader, err_reader, on_start_error, opts)
    logger.debug("starting owned task process", true)
    local run_uv = M._uv or uv

    opts = vim.tbl_extend("force", {}, opts or {})
    sequence = sequence + 1
    local id = opts.attempt_id or ("attempt:" .. sequence)
    local key = opts.admission_key or (buf and ("legacy:" .. buf) or id)
    -- A generation's process leads its own group (#261 M3), so a stop reaches
    -- every process it started. Anything else stays in Neovim's session, where
    -- a secret command can still prompt on the terminal.
    local group = M.is_scoped(opts)
    local record = {
        runtime = run_uv,
        retained=0,on_unresolved=opts.on_unresolved,
        state = attempt.new({
            attempt_id = id,
            generation_id = opts.generation_id,
            logical_generation = opts.logical_generation or opts.generation_id or id,
            kind = opts.kind or 'utility',
            stdout_bytes=0,stderr_bytes=0,
            query_id = opts.query_id,
            admission_key = key,
            buf = buf,
            order = sequence,
            group = group,
        }),
    }
    local function reject(message)
        event(record, { type = "spawn_failed" })
        if records[id] == record then
            retire(record)
        else
            M.reject_query(opts.query_id)
        end
        -- Every run settles (#261 M3): without a start-error handler, the exit
        -- callback hears the refusal.
        if on_start_error then vim.schedule(function() on_start_error(message) end)
        else vim.schedule(function() call_safely("task refusal", callback, nil, nil, nil, nil, message) end) end
    end
    if records[id] or admissions[key] then
        reject("task start rejected: owner is busy")
        return nil
    end
    local stdout_limit,stderr_limit=opts.stdout_limit or 1048576,opts.stderr_limit or 65536
    if not integer(stdout_limit,16*1024*1024) or not integer(stderr_limit,1048576)
        or opts.collect_stdout~=nil and type(opts.collect_stdout)~='boolean'
        or opts.cwd~=nil and (type(opts.cwd)~='string' or opts.cwd=='')
        or record.state.kind~='provider' and record.state.kind~='tool' and record.state.kind~='utility'
        or opts.deadline_ms~=nil and not integer(opts.deadline_ms,3600000) then
        reject('task start rejected: invalid process options');return nil
    end
    if group and stopped_scopes[record.state.logical_generation] then
        reject('task start rejected: its generation has already stopped');return nil
    end
    -- Nobody stops an unscoped run, so it names its own end (#261 M3).
    if not group and opts.deadline_ms==nil then
        reject('task start rejected: a process outside a generation needs deadline_ms');return nil
    end
    if not capacity(record.state)then reject('task start rejected: process admission capacity');return nil end
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
    local stdout_buffer,stderr_buffer=collection(),collection()
    local io_error

    local finish = M.once(function()
        vim.schedule(function()
            local stdout_data,stderr_data=collected(stdout_buffer),collected(stderr_buffer)
            stdout_buffer,stderr_buffer=nil,nil
            event(record, { type = "delivered" })
            retire(record)
            -- `code` is the exit code only of a process that ended on its own with
            -- its output read whole; otherwise nil, and `io_error` says why — a
            -- kill Parley caused, a pipe error, an overflow (#261 M3). So a
            -- caller testing `code == 0` never takes cut output for success.
            local killed = attempt.kill_cause(record.state)
            local failure = io_error or (killed and "killed: " .. killed)
            call_safely("task terminal", callback, not failure and record.state.code or nil, record.state.signal,
                stdout_data, stderr_data, failure)
            local ok, message = pcall(vim.cmd, "doautocmd User ParleyQueryFinished")
            if not ok then logger.error("ParleyQueryFinished failed: " .. tostring(message)) end
        end)
    end)

    local function maybe_finish()
        if attempt.can_deliver_terminal(record.state) then
            close_reconcile(record)
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
        if attempt.is_unresolved(record.state)then
            event(record,{type='reconcile_requested',now=clock()});schedule_reconcile(record)
        end
        maybe_finish()
    end

    local spawn_error
    local spawn_ok
    spawn_ok, handle, pid = pcall(run_uv.spawn, cmd, {
        args = args,
        cwd = opts.cwd,
        stdio = { nil, stdout, stderr },
        hide = true,
        detached = group or nil,
    }, on_exit)
    if not spawn_ok or not handle then
        spawn_error = spawn_ok and pid or handle
        close_pipe(stdout)
        close_pipe(stderr)
        reject("task start failed: " .. tostring(spawn_error))
        return
    end

    logger.debug("owned task process started with pid: " .. pid, true)

    record.handle = handle
    event(record, { type = "spawned", pid = pid })
    if record.state.exited and not handle:is_closing() then handle:close() end
    if opts.deadline_ms and attempt.is_unresolved(record.state) then
        local ok,timer=pcall(record.runtime.new_timer)
        if ok and timer and pcall(function()timer:start(opts.deadline_ms,0,function()
            vim.schedule(function()
                -- One-shot: closed as it fires, so a record then held forever
                -- keeps no handle; retire closes one that never fired.
                if record.deadline==timer then close_timer(timer);record.deadline=nil end
                if records[id]==record then stop_matching(function(state)return state.attempt_id==id end,15,'deadline')end
            end)
        end)end)then record.deadline=timer
        elseif ok and timer then close_timer(timer)end
    end
    snapshot()

    local function deliver(stream,buffer,limit,reader,err,data,collecting)
        if not data or data == '' then call_safely(stream..' reader',reader,err,data);return end
        local amount=#data
        if collecting then amount=math.min(amount,limit-buffer.bytes,limits.retained_bytes-retained_bytes)end
        amount=math.max(0,amount)
        if collecting and amount>0 then
            collect(buffer,data:sub(1,amount));record.retained=record.retained+amount;retained_bytes=retained_bytes+amount
            record.state[stream..'_bytes']=buffer.bytes
        end
        for first=1,amount,65536 do call_safely(stream..' reader',reader,err,data:sub(first,math.min(first+65535,amount)))end
        if amount<#data then
            io_error=io_error or (stream..' retention limit exceeded')
            record.state.output_overflow=true
            pcall(M.stop_attempt,id)
        end
    end

    local function stdout_callback(err, data)
        if record.state.stdout_eof then return end
        if err then
            logger.error("Error reading stdout: " .. vim.inspect(err))
            io_error = io_error or ("stdout: " .. tostring(err))
        end
        deliver('stdout',stdout_buffer,stdout_limit,out_reader,err,data,opts.collect_stdout~=false)
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
        deliver('stderr',stderr_buffer,stderr_limit,err_reader,err,data,true)
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
