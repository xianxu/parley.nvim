--------------------------------------------------------------------------------
-- Task managmenet module
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local uv = vim.uv or vim.loop

local M = {}
M._handles = {}
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

-- stop receiving gpt responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.stop = function(signal)
	if #M._handles == 0 then
		return
	end

	for _, h in ipairs(M._handles) do
		if h.handle ~= nil and not h.handle:is_closing() then
			pcall(function()
				if type(h.pid) == "number" and h.pid > 0 then
					uv.kill(h.pid, signal or 15)
				end
			end)
		end
	end

	M._handles = {}
	
	-- Trigger event for lualine update when stopping queries
	vim.schedule(function()
		vim.cmd("doautocmd User ParleyQueryFinished")
	end)
end

---@param buf number | nil # buffer number
---@param cmd string # command to execute
---@param args table # arguments for command
---@param callback function | nil # exit callback function(code, signal, stdout_data, stderr_data)
---@param out_reader function | nil # stdout reader function(err, data)
---@param err_reader function | nil # stderr reader function(err, data)
M.run = function(buf, cmd, args, callback, out_reader, err_reader)
	logger.debug("run command: " .. cmd .. " " .. table.concat(args, " "), true)

	local handle, pid
	local stdout = uv.new_pipe(false)
	local stderr = uv.new_pipe(false)
	local stdout_data = ""
	local stderr_data = ""

	-- Run cleanup routine to remove stale processes
	M.cleanup_stale_handles()
	
	if M.is_busy(buf, false) then
		return
	end

	local on_exit = M.once(vim.schedule_wrap(function(code, signal)
		stdout:read_stop()
		stderr:read_stop()
		stdout:close()
		stderr:close()
		if handle and not handle:is_closing() then
			handle:close()
		end
		if callback then
			callback(code, signal, stdout_data, stderr_data)
		end
		M.remove_handle(pid)
		
		-- Trigger event for lualine update
		vim.cmd("doautocmd User ParleyQueryFinished")
	end))

	handle, pid = uv.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
		hide = true,
		detach = true,
	}, on_exit)

	logger.debug(cmd .. " command started with pid: " .. pid, true)

	M.add_handle(handle, pid, buf)

	uv.read_start(stdout, function(err, data)
		if err then
			logger.error("Error reading stdout: " .. vim.inspect(err))
		end
		if data then
			stdout_data = stdout_data .. data
		end
		if out_reader then
			out_reader(err, data)
		end
	end)

	uv.read_start(stderr, function(err, data)
		if err then
			logger.error("Error reading stderr: " .. vim.inspect(err))
		end
		if data then
			stderr_data = stderr_data .. data
		end
		if err_reader then
			err_reader(err, data)
		end
	end)
end

-- grep_directory function removed as it's not used anywhere in the codebase

return M