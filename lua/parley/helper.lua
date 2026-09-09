--------------------------------------------------------------------------------
-- Generic independent helper functions
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local _H = {}
local LAST_CONTENT_LINE_CHUNK_SIZE = 256

-- Pop a non-blocking as-you-type completion menu (no auto-insert, no auto-select),
-- restoring the user's `completeopt` afterward. The shared idiom behind parley's
-- typeahead completers (spell suggestions, vision YAML). `start` is the 1-indexed
-- byte column where the replaced span begins; `items` is anything |complete()|
-- accepts (a list of strings or `{word=...}` dicts).
---@param start number # 1-indexed start column of the replaced span
---@param items table # completion items (strings or dicts)
_H.complete_noselect = function(start, items)
	local saved = vim.o.completeopt
	vim.o.completeopt = "menuone,noinsert,noselect"
	-- pcall-guard the restore: complete() errors (e.g. called outside Insert mode)
	-- must not leave the user's global completeopt clobbered.
	pcall(vim.fn.complete, start, items)
	vim.o.completeopt = saved
end

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
--- Flatten a writefile() line list so no element contains a newline.
---
--- `vim.fn.writefile` encodes a `\n` INSIDE a list element as a NUL byte rather
--- than rejecting it, so a caller that passes a multi-line string silently
--- writes a corrupt file. Worse, `readfile` turns that NUL back into `\n`, so a
--- Lua round-trip test cannot see the damage — it is visible only outside Vim,
--- as `^@`. Every writefile caller that can be handed composed text should run
--- its lines through here (#214 M3).
--- @param lines string[]
--- @return string[]
_H.flatten_lines = function(lines)
    local out = {}
    for _, line in ipairs(lines) do
        if type(line) == "string" and line:find("\n", 1, true) then
            for _, part in ipairs(vim.split(line, "\n", { plain = true })) do
                out[#out + 1] = part
            end
        else
            out[#out + 1] = line
        end
    end
    return out
end

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

	if not vim.api.nvim_buf_is_valid(buf) then
		return 0
	end

	_H._last_content_line_cache = _H._last_content_line_cache or {}
	local changedtick = vim.api.nvim_buf_get_changedtick(buf)
	local cached = _H._last_content_line_cache[buf]
	if cached and cached.changedtick == changedtick then
		return cached.line
	end

	-- Scan from the end in chunks to reduce nvim API calls on large buffers.
	local line_count = vim.api.nvim_buf_line_count(buf)
	local end_line = line_count
	local found_line = 0
	while end_line > 0 do
		local start_line = math.max(0, end_line - LAST_CONTENT_LINE_CHUNK_SIZE)
		local lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
		for i = #lines, 1, -1 do
			if lines[i]:match("%S") then
				found_line = start_line + i
				break
			end
		end
		if found_line > 0 then
			break
		end
		end_line = start_line
	end

	_H._last_content_line_cache[buf] = {
		changedtick = changedtick,
		line = found_line,
	}
	return found_line
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

-- Expand a path that came out of a TRANSCRIPT.
--
-- `vim.fn.expand()` runs shell commands: expanding "`touch /tmp/x`" executes
-- it. Chat buffers hold model output, so every path lifted out of one — an
-- @@reference, a 🌿: link, an inline [🌿:…](file) — is attacker-influenced
-- text arriving at a command-execution sink. Verified end-to-end: a chat line
-- `@@`touch /tmp/PWNED`@@` created the file when <M-o> was pressed on it.
--
-- Refusal, not escaping: expand() has two executing constructs (`cmd` and
-- `=expr`) and no reliable quoting for either, while no legitimate parley
-- reference needs a backtick in a path. Callers treat nil as "this path is not
-- usable" and take whatever their existing not-found branch is.
--
-- Config-derived paths (chat_dir, root.dir, src_root) are operator-controlled
-- and keep using vim.fn.expand directly — the distinction is provenance, not
-- syntax.
---@param path string|nil
---@return string|nil # expanded path, or nil if expanding it would execute
_H.expand_path = function(path)
    if type(path) ~= "string" or path:find("`", 1, true) then
        return nil
    end
    return vim.fn.expand(path)
end

-- Read file contents into a string if it exists
---@param filepath string # path to the file
---@return string|nil # file contents or nil if file doesn't exist
_H.read_file_content = function(filepath)
    local expanded_path = _H.expand_path(filepath)
    if not expanded_path then
        logger.warning("Refusing to expand a path containing a backtick: " .. tostring(filepath))
        return nil
    end
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
    local expanded_path = _H.expand_path(path)
    return expanded_path ~= nil and vim.fn.isdirectory(expanded_path) == 1
end

-- Check if a path is a remote URL (e.g., Google Docs)
---@param path string # path to check
---@return boolean # true if path is a URL
_H.is_remote_url = function(path)
    return path:match("^https?://") ~= nil
end

-- Get a formatted representation of a file with its content
---@param filepath string # path to the file
---@return string # formatted file content with header
_H.format_file_content = function(filepath)
    local content = _H.read_file_content(filepath)
    if not content then
        return "File: " .. filepath .. "\n[Error: Could not read file]\n\n"
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
    local expanded_dir = _H.expand_path(dirpath)
    if not expanded_dir then
        logger.warning("Refusing to expand a path containing a backtick: " .. tostring(dirpath))
        return {}
    end
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
-- The directory part of a glob-ish reference. PURE.
--   "a/b/**/*.md" -> "a/b"   "a/b/**/*" -> "a/b"
--   "a/b/*.md"    -> "a/b"   "a/b/"     -> "a/b"
--   "a/b/c.md"    -> unchanged (not a glob)
--
-- #225: this derivation had two near-copies — one here and one in the
-- @@-reference chain in init.lua — differing in which shapes they stripped, so
-- neither was wrong but the pair could drift. One function, one test.
---@param spec string
---@return string
_H.glob_base = function(spec)
    local base = spec
        :gsub("/%*%*/.*$", "")   -- /** and everything after it
        :gsub("/%*%*?/?.*$", "") -- a remaining /* or /** segment
        :gsub("/%*%.%w+$", "")   -- /*.ext
        :gsub("/$", "")          -- trailing slash
    return base
end

_H.process_directory_pattern = function(dirspec)
    local result = {}
    -- ** are literal characters here, not Lua pattern magic, hence the % escapes.
    local recursive = dirspec:match("%*%*/") ~= nil
    local pattern = nil
    if dirspec:match("/%*%*?/?.*%.%w+$") or dirspec:match("/%*%.%w+$") then
        pattern = dirspec:match(".*/(%*%*?/?.*%.%w+)$") or dirspec:match(".*/(%*%.%w+)$")
    end
    local dir = _H.glob_base(dirspec)

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
	-- :undojoin operates on the current buffer's undo state. If `buf` is
	-- not the current buffer (e.g. a scheduled callback fired while focus
	-- was elsewhere), the marker would land on the wrong buffer and the
	-- next change in `buf` would not be merged. nvim_buf_call temporarily
	-- sets the current buffer to `buf` for the duration of the callback.
	vim.api.nvim_buf_call(buf, function()
		local status, result = pcall(vim.cmd.undojoin)
		if not status then
			if result:match("E790") then
				return
			end
			logger.error("Error running undojoin: " .. vim.inspect(result))
		end
	end)
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

---@param tbl table # table to encode as JSON
---@param file_path string # destination replaced only after a complete write
---@param adapter table|nil # optional IO adapter for deterministic failure tests
---@return boolean ok
---@return string|nil err
_H.table_to_file_atomic = function(tbl, file_path, adapter)
	adapter = adapter or {}
	local encode = adapter.encode or vim.json.encode
	local open = adapter.open or io.open
	local rename = adapter.rename or os.rename
	local remove = adapter.remove or os.remove
	local temp_path = adapter.temp_path or function(path)
		local uv = vim.uv or vim.loop
		local nonce = uv and uv.hrtime and uv.hrtime() or os.time()
		return string.format("%s.tmp-%s-%06x", path, tostring(nonce), math.random(0, 0xFFFFFF))
	end

	local function failure(stage, detail)
		local message = tostring(detail or "unknown error")
		return false, (stage .. " failed: " .. message):sub(1, 240)
	end
	local function cleanup(path)
		pcall(remove, path)
	end

	local encoded_ok, json = pcall(encode, tbl)
	if not encoded_ok then
		return failure("encode", json)
	end

	local tmp = temp_path(file_path)
	local open_ok, file, open_err = pcall(open, tmp, "w")
	if not open_ok or not file then
		cleanup(tmp)
		return failure("open", open_ok and open_err or file)
	end

	local write_ok, write_result, write_err = pcall(function() return file:write(json) end)
	if not write_ok or not write_result then
		pcall(function() file:close() end)
		cleanup(tmp)
		return failure("write", write_ok and write_err or write_result)
	end

	local close_ok, close_result, close_err = pcall(function() return file:close() end)
	if not close_ok or not close_result then
		cleanup(tmp)
		return failure("close", close_ok and close_err or close_result)
	end

	local rename_ok, rename_result, rename_err = pcall(rename, tmp, file_path)
	if not rename_ok or not rename_result then
		cleanup(tmp)
		return failure("rename", rename_ok and rename_err or rename_result)
	end

	return true
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

_H.get_week_number_sunday_based = function(date_str)
  local function is_leap(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
  end

  -- parse "YYYY-MM-DD"
  local y, m, d = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  local year, month, day = tonumber(y), tonumber(m), tonumber(d)

  -- days in each month, adjust February for leap years
  local days_in_month = {31,28,31,30,31,30,31,31,30,31,30,31}
  if is_leap(year) then days_in_month[2] = 29 end

  -- compute zero-based day-of-year
  local day_index = day - 1
  for i = 1, month - 1 do
    day_index = day_index + days_in_month[i]
  end

  -- weekday of Jan 1 (0=Sunday…6=Saturday)
  local jan1_wday = os.date("*t", os.time{ year=year, month=1, day=1 }).wday - 1

  -- week number = floor((day_index + offset) / 7) + 1
  return math.floor((day_index + jan1_wday) / 7) + 1
end

---@param dir string # directory to prepare
---@param name string | nil # name of the directory
---@return string # returns resolved directory path
_H.prepare_dir = function(dir, name)
	local odir = dir
	dir = _H.expand_path(dir)
	if not dir then
		logger.warning("Refusing to create a directory whose path contains a backtick: " .. tostring(odir))
		return odir
	end
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
