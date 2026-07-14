--------------------------------------------------------------------------------
-- Task managmenet module
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local uv = vim.uv or vim.loop

local M = {}
M._handles = {}
M._uv = nil -- injectable transport seam for deterministic drain-order tests
M._queries = {} -- table of latest queries
M._debug = {
    is_busy_calls = 0,
    warnings_suppressed = 0,
    last_warning_time = 0,
    warning_interval = 1 -- seconds between warnings
}
M._cache_metrics = {
    creation = 0,   -- tokens created in cache
    read = 0,       -- tokens read from cache
    input = 0       -- total input tokens
}

---@param fn function # function to wrap so it only gets called once
M.once = function(fn)
	local once = false
	return function(...)
		if once then
			return
		end
		once = true
		fn(...)
	end
end

---@param N number # number of queries to keep
---@param age number # age of queries to keep in seconds
M.cleanup_old_queries = function(N, age)
	local current_time = os.time()

	local query_count = 0
	for _ in pairs(M._queries) do
		query_count = query_count + 1
	end

	if query_count <= N then
		return
	end

	for qid, query_data in pairs(M._queries) do
		if current_time - query_data.timestamp > age then
			M._queries[qid] = nil
		end
	end
end

---@param qid string # query id
---@return table | nil # query data
M.get_query = function(qid)
	if not M._queries[qid] then
		logger.error("query with ID " .. tostring(qid) .. " not found.")
		return nil
	end
	return M._queries[qid]
end

---@param buf number | nil # buffer number
---@return table | nil # newest query for this buffer
M.get_active_query_by_buf = function(buf)
	if buf == nil then
		return nil
	end

	local active_query = nil
	for _, query_data in pairs(M._queries) do
		if query_data.buf == buf then
			if not active_query or (query_data.timestamp or 0) > (active_query.timestamp or 0) then
				active_query = query_data
			end
		end
	end

	return active_query
end

---@param qid string # query id
---@param payload table # query payload
M.set_query = function(qid, payload)
	M._queries[qid] = payload
	M._queries[qid].timestamp = os.time()
	M.cleanup_old_queries(10, 60)

	-- Trigger event for lualine update
	vim.schedule(function()
		vim.cmd("doautocmd User ParleyQueryStarted")
	end)
end

-- add a process handle and its corresponding pid to the _handles table
---@param handle userdata | nil # the Lua uv handle
---@param pid number | string # the process id
---@param buf number | nil # buffer number
M.add_handle = function(handle, pid, buf)
    -- Check if this PID is already in the handles table
    for _, h in ipairs(M._handles) do
        if h.pid == pid then
            logger.debug("Process " .. pid .. " is already in handles table, not adding duplicate")
            return
        end
    end
	table.insert(M._handles, { handle = handle, pid = pid, buf = buf })
	logger.debug("Added handle for PID " .. pid .. ", total handles: " .. #M._handles)
end

-- remove a process handle from the _handles table using its pid
---@param pid number | string # the process id to find the corresponding handle
M.remove_handle = function(pid)
	for i, h in ipairs(M._handles) do
		if h.pid == pid then
			table.remove(M._handles, i)
			logger.debug("Removed handle for PID " .. pid .. ", remaining handles: " .. (#M._handles))
			return
		end
	end
	logger.debug("Attempted to remove nonexistent handle for PID " .. pid)
end

--- check if there is some pid running for the given buffer
---@param buf number | nil # buffer number
---@return boolean
M.is_busy = function(buf, skip_warning)
	-- Increment debug counter
	M._debug.is_busy_calls = M._debug.is_busy_calls + 1

	if buf == nil then
		return false
	end

	-- Initialize variables to track the first active process we find
	local active_pid = nil

	-- Count active processes for this buffer
	local active_count = 0

	for _, h in ipairs(M._handles) do
		if h.buf == buf then
			-- Check if the process is still active by sending signal 0 (doesn't kill the process, just checks existence)
			local is_active = false

			-- Use pcall since kill might throw an error if process doesn't exist
			pcall(function()
				if type(h.pid) == "number" and h.pid > 0 then
					is_active = uv.kill(h.pid, 0) == 0
				end
			end)

			if is_active then
				active_count = active_count + 1
				if active_pid == nil then
					active_pid = h.pid -- Store the first active PID we find
				end
			else
				-- Process no longer exists, remove it from handles
				logger.debug("Removing stale process handle: " .. h.pid)
				M.remove_handle(h.pid)
			end
		end
	end

	-- After processing all handles, report the result once
	if active_pid ~= nil then
		-- Only log warnings if not explicitly suppressed (for UI calls)
		if not skip_warning then
			-- Limit warning frequency to prevent log spam
			local current_time = os.time()
			if (current_time - M._debug.last_warning_time) >= M._debug.warning_interval then
				-- Only log warning if enough time has passed since the last one
				logger.warning("Another Parley process [" .. active_pid .. "] is already running for buffer " .. buf ..
							" (found " .. active_count .. " active process(es))")
				M._debug.last_warning_time = current_time
			else
				-- Count suppressed warnings
				M._debug.warnings_suppressed = M._debug.warnings_suppressed + 1
			end
		end
		return true
	end

	return false
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

-- report_debug_stats function removed - only used internally

-- Clean up stale process handles that are no longer running
M.cleanup_stale_handles = function()
	local i = 1
	local active_count = 0
	local removed_count = 0

	while i <= #M._handles do
		local h = M._handles[i]

		-- Check if process still exists
		local process_exists = false
		pcall(function()
			if type(h.pid) == "number" and h.pid > 0 then
				process_exists = uv.kill(h.pid, 0) == 0
			end
		end)

		if not process_exists then
			-- Process no longer exists, remove from handles
			logger.debug("Cleanup: Removing stale process handle [" .. h.pid .. "]")
			table.remove(M._handles, i)
			removed_count = removed_count + 1
		else
			active_count = active_count + 1
			i = i + 1
		end
	end

	logger.debug("Cleanup completed: " .. active_count .. " active processes, " ..
				 removed_count .. " stale processes removed")

end

local function stop_matching(matches, signal)
	local kept = {}
	local stopped = 0
	local signal_failed = false
	local runtime = M._uv or uv
	for _, h in ipairs(M._handles) do
		if matches(h) then
			stopped = stopped + 1
			if h.handle ~= nil and not h.handle:is_closing() then
				local ok, result = pcall(function()
					if type(h.pid) == "number" and h.pid > 0 then
						return runtime.kill(h.pid, signal or 15)
					end
					return 0
				end)
				if not ok or result == nil or result == false then signal_failed = true end
			end
		else
			table.insert(kept, h)
		end
	end
	M._handles = kept
	if stopped > 0 then
		vim.schedule(function()
			vim.cmd("doautocmd User ParleyQueryFinished")
		end)
	end
	return stopped, signal_failed
end

-- Stop receiving responses for all processes and clean the handles.
---@param signal number | nil # signal to send to the process
M.stop = function(signal)
	return stop_matching(function() return true end, signal)
end

-- Stop only processes owned by one buffer, preserving unrelated work.
---@param buf number # buffer number
---@param signal number | nil # signal to send to the process
---@return number # matching handle records retired
M.stop_buf = function(buf, signal)
	local stopped, signal_failed = stop_matching(function(handle) return handle.buf == buf end, signal)
	if signal_failed then
		error("task transport stop failed", 0)
	end
	return stopped
end

---@param buf number | nil # buffer number
---@param cmd string # command to execute
---@param args table # arguments for command
---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data, io_error)
---@param out_reader function | nil # stdout reader function(err, data)
---@param err_reader function | nil # stderr reader function(err, data)
---@param on_start_error function | nil # scheduled launch rejection callback(message)
M.run = function(buf, cmd, args, callback, out_reader, err_reader, on_start_error)
	logger.debug("run command: " .. cmd .. " " .. table.concat(args, " "), true)
	local run_uv = M._uv or uv

	-- Run cleanup routine to remove stale processes
	M.cleanup_stale_handles()

	if M.is_busy(buf, false) then
		if on_start_error then
			vim.schedule(function()
				on_start_error("task start rejected: buffer is busy")
			end)
		end
		return
	end

	local handle, pid
	local stdout = run_uv.new_pipe(false)
	local stderr = run_uv.new_pipe(false)
	local stdout_data = ""
	local stderr_data = ""
	local exit_code
	local exit_signal
	local process_done = false
	local stdout_done = false
	local stderr_done = false
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
			call_safely("task terminal", callback,
				exit_code, exit_signal, stdout_data, stderr_data, io_error)
			M.remove_handle(pid)
			local ok, message = pcall(vim.cmd, "doautocmd User ParleyQueryFinished")
			if not ok then logger.error("ParleyQueryFinished failed: " .. tostring(message)) end
		end)
	end)

	local function maybe_finish()
		if process_done and stdout_done and stderr_done then
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
		exit_code = code
		exit_signal = signal
		process_done = true
		if handle and not handle:is_closing() then
			handle:close()
		end
		maybe_finish()
	end

	local spawn_error
	handle, pid = run_uv.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
		hide = true,
		detach = true,
	}, on_exit)
	if not handle then
		spawn_error = pid
		close_pipe(stdout)
		close_pipe(stderr)
		if on_start_error then
			local report_start_error = M.once(on_start_error)
			vim.schedule(function()
				report_start_error("task start failed: " .. tostring(spawn_error))
			end)
		end
		return
	end

	logger.debug(cmd .. " command started with pid: " .. pid, true)

	M.add_handle(handle, pid, buf)

	local function stdout_callback(err, data)
		if stdout_done then return end
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
			stdout_done = true
			close_pipe(stdout)
			maybe_finish()
		end
	end

	local function stderr_callback(err, data)
		if stderr_done then return end
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
			stderr_done = true
			close_pipe(stderr)
			maybe_finish()
		end
	end

	local function start_read(stream, pipe, reader, reject)
		local ok, result, detail = pcall(run_uv.read_start, pipe, reader)
		local failed = not ok or result == false
			or (type(result) == "number" and result ~= 0)
			or (result == nil and detail ~= nil)
		if failed then
			local reason = ok and (detail or result) or result
			reject(stream .. " read_start failed: " .. tostring(reason))
		end
	end

	start_read("stdout", stdout, stdout_callback, function(message)
		stdout_callback(message, nil)
	end)
	start_read("stderr", stderr, stderr_callback, function(message)
		stderr_callback(message, nil)
	end)
end

-- grep_directory function removed as it's not used anywhere in the codebase

return M
