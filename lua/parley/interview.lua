-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- Interview mode: timestamp insertion, highlighting, and timer management

local M = {}

-- Module-local references set via M.setup()
-- _parley holds the full parley module so we always read the current M._state
-- (refresh_state() replaces the entire M._state table, so we can't cache a direct reference)
local _parley = nil
local _logger = nil

-- Track match IDs per buffer for interview timestamp highlighting
local _interview_match_ids = {}

-- Helper: safely stop and close a vim.loop timer
local function stop_and_close_timer(timer)
	if not timer then
		return
	end

	local ok, is_closing = pcall(function()
		return timer:is_closing()
	end)
	if ok and is_closing then
		return
	end

	pcall(function()
		timer:stop()
	end)

	ok, is_closing = pcall(function()
		return timer:is_closing()
	end)
	if ok and is_closing then
		return
	end

	pcall(function()
		timer:close()
	end)
end

--- Store shared references from init.lua.
--- Must be called once during parley setup.
---@param parley table  the main parley module (M from init.lua)
---@param logger table  M.logger from init.lua
M.setup = function(parley, logger)
	_parley = parley
	_logger = logger
end

--- Format elapsed interview time as ":MMmin" string.
---@return string  e.g. ":07min" or "" if not started
M.format_timestamp = function()
	if not _parley._state.interview_start_time then
		return ""
	end
	local elapsed = os.time() - _parley._state.interview_start_time
	local minutes = math.floor(elapsed / 60)
	if minutes < 10 then
		return string.format(":0%dmin", minutes)
	else
		return string.format(":%dmin", minutes)
	end
end

--- Install a global insert-mode <CR> mapping that inserts timestamps in interview mode.
M.setup_keymap = function()
	_logger.info("Setting up interview keymap")
	vim.keymap.set("i", "<CR>", function()
		print("DEBUG: interview_mode=" .. tostring(_parley._state.interview_mode)) -- Debug print
		-- Apply timestamp when interview mode is active (no folder restriction)
		if _parley._state.interview_mode then
			local timestamp = M.format_timestamp()
			_logger.debug("Inserting timestamp: " .. timestamp)
			-- Insert extra newline, then timestamp
			return "<CR><CR>" .. timestamp .. " "
		else
			-- Regular Enter behavior
			return "<CR>"
		end
	end, {
		expr = true,
		desc = "Insert timestamp on new line in interview mode",
	})
	print("DEBUG: Keymap set up complete") -- Debug print
end

--- Remove the global insert-mode <CR> mapping installed by setup_keymap().
M.remove_keymap = function()
	_logger.info("Removing interview keymap")
	pcall(function()
		vim.keymap.del("i", "<CR>")
	end)
end

--- Add (or refresh) syntax highlighting for interview timestamp lines in a buffer.
---@param buf integer  buffer number
M.highlight_timestamps = function(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local match_id_key = "parley_interview_timestamps_" .. buf

	-- Clear existing match for this buffer if it exists
	if _interview_match_ids[match_id_key] then
		pcall(vim.fn.matchdelete, _interview_match_ids[match_id_key])
		_interview_match_ids[match_id_key] = nil
	end

	-- Add highlighting for the entire timestamp line with very low priority (-1)
	-- to ensure all search highlights (incsearch, Search, CurSearch) can take precedence
	local match_id = vim.fn.matchadd("InterviewTimestamp", "^\\s*:\\d\\+min.*$", -1)
	_interview_match_ids[match_id_key] = match_id

	-- Add highlighting for {thought} blocks — interviewer's private thoughts
	local thought_key = "parley_interview_thoughts_" .. buf
	if _interview_match_ids[thought_key] then
		pcall(vim.fn.matchdelete, _interview_match_ids[thought_key])
		_interview_match_ids[thought_key] = nil
	end
	local thought_id = vim.fn.matchadd("InterviewThought", "{[^}]\\+}", -1)
	_interview_match_ids[thought_key] = thought_id
end

--- Clear the cached match ID entry for a buffer (call on BufDelete/BufUnload).
---@param buf integer  buffer number
M.clear_match_cache = function(buf)
	local match_id_key = "parley_interview_timestamps_" .. buf
	if _interview_match_ids[match_id_key] then
		_interview_match_ids[match_id_key] = nil
	end
	local thought_key = "parley_interview_thoughts_" .. buf
	if _interview_match_ids[thought_key] then
		_interview_match_ids[thought_key] = nil
	end
end

--- Start a repeating 15-second timer that refreshes lualine while interview mode is active.
M.start_timer = function()
	-- Stop any existing timer first
	M.stop_timer()

	-- Create a timer that updates the statusline every 15 seconds
	_parley._state.interview_timer = vim.loop.new_timer()
	_parley._state.interview_timer:start(
		15000,
		15000,
		vim.schedule_wrap(function()
			if _parley._state.interview_mode then
				-- Refresh lualine to update the timer display
				pcall(function()
					require("lualine").refresh()
				end)
			else
				-- Stop timer if interview mode is no longer active
				M.stop_timer()
			end
		end)
	)

	_logger.debug("Interview timer started")
end

--- Stop the repeating statusline-refresh timer.
M.stop_timer = function()
	if _parley._state.interview_timer then
		stop_and_close_timer(_parley._state.interview_timer)
		_parley._state.interview_timer = nil
		_logger.debug("Interview timer stopped")
	end
end

--- Enter interview mode, handling timestamp insertion and timer lifecycle.
--- If cursor is on a timestamp line, resumes from that time offset.
--- No-op if already in interview mode.
M.enter = function()
	if _parley._state.interview_mode then
		vim.notify("Interview mode is already active", vim.log.levels.INFO)
		return
	end

	-- Check if cursor is on an interview timestamp line to resume from that offset
	local cursor_line = vim.api.nvim_get_current_line()
	local timestamp_match = cursor_line:match("^%s*:(%d+)min")

	if timestamp_match then
		local minutes = tonumber(timestamp_match)
		if minutes then
			_parley._state.interview_start_time = os.time() - (minutes * 60)
			_parley._state.interview_mode = true
			_logger.info(string.format("Interview mode enabled with timer set to %d minutes", minutes))
			vim.notify(string.format("Interview timer set to %d minutes", minutes), vim.log.levels.INFO)

			M.setup_keymap()
			M.start_timer()

			pcall(function()
				require("lualine").refresh()
			end)
			return
		end
	end

	-- Normal enter: start fresh
	_parley._state.interview_mode = true
	_parley._state.interview_start_time = os.time()
	_logger.info("Interview mode enabled")
	vim.notify("Interview mode enabled", vim.log.levels.INFO)

	-- Insert :00min marker at current cursor position
	local mode = vim.fn.mode()
	if mode == "i" then
		vim.api.nvim_put({ ":00min " }, "c", true, true)
	else
		vim.cmd("startinsert")
		vim.schedule(function()
			vim.api.nvim_put({ ":00min " }, "c", true, true)
		end)
	end

	M.setup_keymap()
	M.start_timer()

	pcall(function()
		require("lualine").refresh()
	end)
end

--- Exit interview mode. No-op if not in interview mode.
M.exit = function()
	if not _parley._state.interview_mode then
		vim.notify("Interview mode is not active", vim.log.levels.INFO)
		return
	end

	_parley._state.interview_mode = false
	_parley._state.interview_start_time = nil
	_logger.info("Interview mode disabled")
	vim.notify("Interview mode disabled", vim.log.levels.INFO)
	M.remove_keymap()
	M.stop_timer()

	pcall(function()
		require("lualine").refresh()
	end)
end

--- Toggle interview mode on/off (enters if off, exits if on).
M.toggle = function()
	if _parley._state.interview_mode then
		M.exit()
	else
		M.enter()
	end
end

return M
