--------------------------------------------------------------------------------
-- Generic independent helper functions
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local _H = {}

---@param keys string # string of keystrokes
---@param mode string # string of vim mode ('n', 'i', 'c', etc.), default is 'n'
_H.feedkeys = function(keys, mode)
	mode = mode or "n"
	keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
	vim.api.nvim_feedkeys(keys, mode, true)
end

---@param buffers table # table of buffers
---@param mode table | string # mode(s) to set keymap for
---@param key string # shortcut key
---@param callback function | string # callback or string to set keymap
---@param desc string | nil # optional description for keymap
_H.set_keymap = function(buffers, mode, key, callback, desc)
	logger.debug(
		"registering shortcut:"
			.. " mode: "
			.. vim.inspect(mode)
			.. " key: "
			.. key
			.. " buffers: "
			.. vim.inspect(buffers)
			.. " callback: "
			.. vim.inspect(callback)
	)
	for _, buf in ipairs(buffers) do
		vim.keymap.set(mode, key, callback, {
			noremap = true,
			silent = true,
			nowait = true,
			buffer = buf,
			desc = desc,
		})
	end
end

---@param events string | table # events to listen to
---@param buffers table | nil # buffers to listen to (nil for all buffers)
---@param callback function # callback to call
---@param gid number # augroup id
_H.autocmd = function(events, buffers, callback, gid)
	if buffers then
		for _, buf in ipairs(buffers) do
			vim.api.nvim_create_autocmd(events, {
				group = gid,
				buffer = buf,
				callback = vim.schedule_wrap(callback),
			})
		end
	else
		vim.api.nvim_create_autocmd(events, {
			group = gid,
			callback = vim.schedule_wrap(callback),
		})
	end
end

---@param file_name string # name of the file for which to delete buffers
_H.delete_buffer = function(file_name)
	-- iterate over buffer list and close all buffers with the same name
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) and vim.api.nvim_buf_get_name(b) == file_name then
			vim.api.nvim_buf_delete(b, { force = true })
		end
	end
end

---@param file string | nil # name of the file to delete
_H.delete_file = function(file)
	logger.debug("deleting file: " .. vim.inspect(file))
	if file == nil then
		return
	end
	_H.delete_buffer(file)
	os.remove(file)
end

---@param file_name string # name of the file for which to get buffer
---@return number | nil # buffer number
_H.get_buffer = function(file_name)
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) then
			if _H.ends_with(vim.api.nvim_buf_get_name(b), file_name) then
				return b
			end
		end
	end
	return nil
end

---@return string # returns unique uuid
_H.uuid = function()
	local random = math.random
	local template = "xxxxxxxx_xxxx_4xxx_yxxx_xxxxxxxxxxxx"
	local result = string.gsub(template, "[xy]", function(c)
		local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
		return string.format("%x", v)
	end)
	return result
end

---@param name string # name of the augroup
---@param opts table | nil # options for the augroup
---@return number # returns augroup id
_H.create_augroup = function(name, opts)
	return vim.api.nvim_create_augroup(name .. "_" .. _H.uuid(), opts or { clear = true })
end

---@param buf number # buffer number
---@return number # returns the first line with content of specified buffer
_H.last_content_line = function(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	-- go from end and return number of last nonwhitespace line
	local line = vim.api.nvim_buf_line_count(buf)
	while line > 0 do
		local content = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]
		if content:match("%S") then
			return line
		end
		line = line - 1
	end
	return 0
end

---@param buf number # buffer number
---@return string # returns filetype of specified buffer
_H.get_filetype = function(buf)
	return vim.api.nvim_get_option_value("filetype", { buf = buf })
end

---@param line number # line number
---@param buf number # buffer number
---@param win number | nil # window number
_H.cursor_to_line = function(line, buf, win)
	logger.debug("cursor_to_line called - line: " .. tostring(line) .. 
	            ", buf: " .. tostring(buf) .. 
	            ", win: " .. tostring(win) ..
	            ", current_buf: " .. tostring(vim.api.nvim_get_current_buf()))
	
	-- don't manipulate cursor if user is elsewhere
	if buf ~= vim.api.nvim_get_current_buf() then
		logger.debug("cursor_to_line early return - buffer mismatch")
		return
	end

	-- check if win is valid
	if not win or not vim.api.nvim_win_is_valid(win) then
		logger.debug("cursor_to_line early return - invalid window")
		return
	end

	-- ensure line is within range
	local line_count = vim.api.nvim_buf_line_count(buf)
	if line > line_count then
		logger.debug("cursor_to_line adjusting - line " .. tostring(line) .. 
		            " out of range (max: " .. tostring(line_count) .. ")")
		line = line_count
	end
	
	-- move cursor to the line
	logger.debug("cursor_to_line - setting cursor position to line " .. tostring(line))
	pcall(vim.api.nvim_win_set_cursor, win, { line, 0 })
end

---@param str string # string to check
---@param start string # string to check for
_H.starts_with = function(str, start)
	return str:sub(1, #start) == start
end

---@param str string # string to check
---@param ending string # string to check for
_H.ends_with = function(str, ending)
	return ending == "" or str:sub(-#ending) == ending
end

-- Read file contents into a string if it exists
---@param filepath string # path to the file
---@return string|nil # file contents or nil if file doesn't exist
_H.read_file_content = function(filepath)
    local expanded_path = vim.fn.expand(filepath)
    if vim.fn.filereadable(expanded_path) == 0 then
        logger.warning("File not found: " .. expanded_path)
        return nil
    end
    
    local lines = vim.fn.readfile(expanded_path)
    if not lines or #lines == 0 then
        return ""
    end
    
    return table.concat(lines, "\n")
end

-- Determine if a path is a directory
---@param path string # path to check
---@return boolean # true if path is a directory
_H.is_directory = function(path)
    local expanded_path = vim.fn.expand(path)
    return vim.fn.isdirectory(expanded_path) == 1
end

-- Get a formatted representation of a file with its content
---@param filepath string # path to the file
---@return string # formatted file content with header
_H.format_file_content = function(filepath)
    local content = _H.read_file_content(filepath)
    if not content then
        return "Error: Could not read file " .. filepath
    end
    
    local filetype = vim.filetype.match({ filename = filepath }) or ""
    
    -- Add line numbers to the content
    local lines = vim.split(content, "\n")
    local numbered_lines = {}
    for i, line in ipairs(lines) do
        table.insert(numbered_lines, string.format("%d: %s", i, line))
    end
    local numbered_content = table.concat(numbered_lines, "\n")
    
    return "File: " .. filepath .. "\n```" .. filetype .. "\n" .. numbered_content .. "\n```\n\n"
end

-- Find files in a directory matching a pattern
---@param dirpath string # directory path
---@param pattern string # glob pattern
---@param recursive boolean # whether to search recursively
---@return table # list of matching file paths
_H.find_files = function(dirpath, pattern, recursive)
    local expanded_dir = vim.fn.expand(dirpath)
    if vim.fn.isdirectory(expanded_dir) == 0 then
        logger.warning("Directory not found: " .. expanded_dir)
        return {}
    end
    
    -- Construct glob pattern based on parameters
    local glob_pattern
    if recursive then
        -- Use vim's ** for recursive glob
        if pattern then
            glob_pattern = expanded_dir .. "/**/" .. pattern
        else
            glob_pattern = expanded_dir .. "/**/*"
        end
    else
        -- Non-recursive glob
        if pattern then
            glob_pattern = expanded_dir .. "/" .. pattern
        else
            glob_pattern = expanded_dir .. "/*"
        end
    end
    
    logger.debug("Searching with glob pattern: " .. glob_pattern)
    
    -- Use vim's glob() to find matching files
    local matches = vim.fn.glob(glob_pattern, false, true)
    local files = {}
    
    -- Filter to include only files, not directories
    for _, match in ipairs(matches) do
        if vim.fn.isdirectory(match) == 0 then
            table.insert(files, match)
        end
    end
    
    logger.debug("Found " .. #files .. " matching files")
    return files
end

-- Process a directory pattern (possibly with glob) and return all matching file contents
---@param dirspec string # directory specification (possibly with glob pattern)
---@return string # combined contents of all matching files
_H.process_directory_pattern = function(dirspec)
    local result = {}
    local recursive = false
    local pattern = nil
    local dir = dirspec
    
    -- Check if this is a recursive search pattern with **
    if dirspec:match("**/") then
        recursive = true
        dir = dirspec:gsub("/*%*%*/.*$", "") -- Remove ** and anything after
    end
    
    -- Extract a filename pattern if it exists
    if dirspec:match("/%*%*?/?.*%.%w+$") or dirspec:match("/%*%.%w+$") then
        pattern = dirspec:match(".*/(%*%*?/?.*%.%w+)$") or dirspec:match(".*/(%*%.%w+)$")
        dir = dirspec:gsub("/%*%*?/?.*%.%w+$", ""):gsub("/%*%.%w+$", "")
    end
    
    -- If it ends with a trailing slash, it's a directory without pattern
    if dirspec:match("/$") then
        dir = dirspec:gsub("/$", "")
    end
    
    logger.debug("Processed directory pattern: dir=" .. dir .. 
                ", pattern=" .. (pattern or "nil") .. 
                ", recursive=" .. tostring(recursive))
    
    -- Find all matching files
    local files = _H.find_files(dir, pattern, recursive)
    
    -- Collect content from all files
    if #files > 0 then
        table.insert(result, "Directory listing for " .. dirspec .. " (" .. #files .. " files):\n")
        
        for _, file in ipairs(files) do
            table.insert(result, _H.format_file_content(file))
        end
    else
        table.insert(result, "No files found matching pattern: " .. dirspec)
    end
    
    return table.concat(result, "\n")
end

-- helper function to find the root directory of the current git repository
---@param path string | nil  # optional path to start searching from
---@return string # returns the path of the git root dir or an empty string if not found
_H.find_git_root = function(path)
	logger.debug("finding git root for path: " .. vim.inspect(path))
	local cwd = vim.fn.expand("%:p:h")
	if path then
		cwd = vim.fn.fnamemodify(path, ":p:h")
	end

	for _ = 0, 1000 do
		local files = vim.fn.readdir(cwd)
		if vim.tbl_contains(files, ".git") then
			logger.debug("found git root: " .. cwd)
			return cwd
		end
		local parent = vim.fn.fnamemodify(cwd, ":h")
		if parent == cwd then
			break
		end
		cwd = parent
	end
	logger.debug("git root not found")
	return ""
end

---@param buf number # buffer number
_H.undojoin = function(buf)
	if not buf or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local status, result = pcall(vim.cmd.undojoin)
	if not status then
		if result:match("E790") then
			return
		end
		logger.error("Error running undojoin: " .. vim.inspect(result))
	end
end

---@param tbl table # the table to be stored
---@param file_path string # the file path where the table will be stored as json
_H.table_to_file = function(tbl, file_path)
	local json = vim.json.encode(tbl)

	local file = io.open(file_path, "w")
	if not file then
		logger.warning("Failed to open file for writing: " .. file_path)
		return
	end
	file:write(json)
	file:close()
end

---@param file_path string # the file path from where to read the json into a table
---@return table | nil # the table read from the file, or nil if an error occurred
_H.file_to_table = function(file_path)
	local file, err = io.open(file_path, "r")
	if not file then
		logger.warning("Failed to open file for reading: " .. file_path .. "\nError: " .. err)
		return nil
	end
	local content = file:read("*a")
	file:close()

	if content == nil or content == "" then
		logger.warning("Failed to read any content from file: " .. file_path)
		return nil
	end

	local tbl = vim.json.decode(content)
	return tbl
end

---@param date_str string # Date string in format YYYY-MM-DD
---@return number # Week number (Sunday-based)
_H.get_week_number_sunday_based = function(date_str)
    -- Ensure we have a valid date string
    if not date_str or type(date_str) ~= "string" then
        logger.error("Invalid date input: " .. tostring(date_str))
        return 1 -- Return week 1 as fallback
    end
    
    -- Parse "YYYY-MM-DD" into year, month, day
    local year, month, day = date_str:match("(%d+)%-(%d+)%-(%d+)")
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    
    if not year or not month or not day then
        logger.error("Invalid date format '" .. date_str .. "'. Expected 'YYYY-MM-DD'")
        
        -- Try to recover with current date as fallback
        local current = os.date("*t")
        year, month, day = current.year, current.month, current.day
    end
    
    -- Validate date components
    month = math.min(math.max(month, 1), 12) -- Ensure month is between 1-12
    day = math.min(math.max(day, 1), 31)     -- Ensure day is between 1-31
    
    -- Convert to time with safety checks
    -- Make sure values are valid to prevent errors
    year = tonumber(year) or os.date("*t").year
    month = tonumber(month) or 1
    day = tonumber(day) or 1
    
    -- Clamp values to valid ranges
    month = math.min(math.max(1, month), 12)
    
    -- Make sure day is valid for the given month
    local month_days = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    -- Adjust for leap year
    if month == 2 and (year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)) then
        month_days[2] = 29
    end
    day = math.min(math.max(1, day), month_days[month])
    
    -- Get timestamps
    local time = os.time({year=year, month=month, day=day})
    if not time then
        logger.error("Invalid date: " .. year .. "-" .. month .. "-" .. day)
        return 1 -- Default to week 1 on error
    end
    
    local jan1 = os.time({year=year, month=1, day=1})
    if not jan1 then
        logger.error("Invalid January 1st date: " .. year .. "-1-1")
        return 1 -- Default to week 1 on error
    end
    
    local jan1_wday = tonumber(os.date("%w", jan1)) or 0  -- 0=Sunday, add fallback
    
    -- Sunday on or before Jan 1
    local week1_start = jan1 - jan1_wday * 24 * 60 * 60
    local days_since = math.floor((time - week1_start) / (24 * 60 * 60))
    local week_number = math.floor(days_since / 7) + 1
    
    -- Ensure week number is positive and reasonable
    week_number = math.max(1, math.min(53, week_number))
    
    return week_number
end

---@param dir string # directory to prepare
---@param name string | nil # name of the directory
---@return string # returns resolved directory path
_H.prepare_dir = function(dir, name)
	local odir = dir
	dir = dir:gsub("/$", "")
	name = name and name .. " " or ""
	if vim.fn.isdirectory(dir) == 0 then
		logger.debug("creating " .. name .. "directory: " .. dir)
		vim.fn.mkdir(dir, "p")
	end

	dir = vim.fn.resolve(dir)

	logger.debug("resolved " .. name .. "directory:\n" .. odir .. " -> " .. dir)
	return dir
end

---@param cmd_name string # name of the command
---@param cmd_func function # function to be executed when the command is called
---@param completion function | table | nil # optional function returning table for completion
---@param desc string | nil # description of the command
_H.create_user_command = function(cmd_name, cmd_func, completion, desc)
	logger.debug("creating user command: " .. cmd_name)
	vim.api.nvim_create_user_command(cmd_name, cmd_func, {
		nargs = "*",
		range = true,
		desc = desc or "Parley.nvim command",
		complete = function(arg_lead, cmd_line, cursor_pos)
			logger.debug(
				"completing user command: "
					.. cmd_name
					.. "\narg_lead: "
					.. arg_lead
					.. "\ncmd_line: "
					.. cmd_line
					.. "\ncursor_pos: "
					.. cursor_pos
			)
			if not completion then
				return {}
			end
			if type(completion) == "function" then
				return completion(arg_lead, cmd_line, cursor_pos) or {}
			end
			if type(completion) == "table" then
				return completion
			end
			return {}
		end,
	})
end

return _H
