-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- A streamlined LLM chat interface for Neovim with highlighting and navigation

--------------------------------------------------------------------------------
-- This is the main module
--------------------------------------------------------------------------------
local config = require("parley.config")

local M = {
	_Name = "Parley", -- plugin name
	_state = {
		interview_mode = false, -- interview mode state
		interview_start_time = nil, -- interview start timestamp
		interview_timer = nil, -- timer handle for statusline updates
	}, -- table of state variables
	agents = {}, -- table of agents
	system_prompts = {}, -- table of system prompts
	cmd = {}, -- default command functions
	config = {}, -- config variables
	hooks = {}, -- user defined command functions
	defaults = require("parley.defaults"), -- some useful defaults
chat_parser = require("parley.chat_parser"), -- chat file parser
	dispatcher = require("parley.dispatcher"), -- handle communication with LLM providers
	helpers = require("parley.helper"), -- helper functions
	logger = require("parley.logger"), -- logger module
	outline = require("parley.outline"), -- outline navigation module
	render = require("parley.render"), -- render module
	tasker = require("parley.tasker"), -- tasker module
	vault = require("parley.vault"), -- handles secrets
	lualine = require("parley.lualine"), -- lualine integration
	agent_picker = require("parley.agent_picker"), -- agent selection UI
	system_prompt_picker = require("parley.system_prompt_picker"), -- system prompt selection UI
	chat_dir_picker = require("parley.chat_dir_picker"), -- chat root management UI
	float_picker = require("parley.float_picker"), -- shared floating window picker
}

--------------------------------------------------------------------------------
-- Module helper functions and variables
--------------------------------------------------------------------------------

local agent_completion = function()
	return M._agents
end

local function dir_completion(arg_lead)
	return vim.fn.getcompletion(arg_lead or "", "dir")
end

local function chat_dir_completion(arg_lead)
	local lead = (arg_lead or ""):lower()
	local matches = {}
	for _, dir in ipairs(M.get_chat_dirs()) do
		if lead == "" or dir:lower():find(lead, 1, true) == 1 then
			table.insert(matches, dir)
		end
	end
	return matches
end

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

local function find_chat_header_end(lines)
	return M.chat_parser.find_header_end(lines)
end

local function parse_chat_headers(lines)
	local header_end = find_chat_header_end(lines)
	if not header_end then
		return nil, nil
	end
	local cfg = M.config or {}
	local parse_config = {
		chat_user_prefix = cfg.chat_user_prefix or "💬:",
		chat_local_prefix = cfg.chat_local_prefix or "🔒:",
		chat_assistant_prefix = cfg.chat_assistant_prefix or { "🤖:" },
		chat_memory = cfg.chat_memory or {
			enable = true,
			summary_prefix = "📝:",
			reasoning_prefix = "🧠:",
		},
	}
	local parsed = M.chat_parser.parse_chat(lines, header_end, parse_config)
	return parsed.headers, header_end
end

local function path_within_dir(path, dir)
	local resolved_path = vim.fn.resolve(vim.fn.expand(path)):gsub("/+$", "")
	local resolved_dir = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
	return resolved_path == resolved_dir or M.helpers.starts_with(resolved_path, resolved_dir .. "/")
end

local function resolve_dir_key(dir)
	return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
end

local function default_chat_root_label(dir, is_primary)
	if is_primary then
		return "main"
	end

	local base = vim.fn.fnamemodify(resolve_dir_key(dir), ":t")
	if base == nil or base == "" then
		return "extra"
	end
	return base
end

local function normalize_chat_roots(chat_dir, chat_dirs, chat_roots)
	local roots = {}
	local seen = {}

	local function add_root(rootish, is_primary)
		local dir = nil
		local label = nil
		if type(rootish) == "string" then
			dir = rootish
		elseif type(rootish) == "table" then
			dir = rootish.dir or rootish.path
			label = rootish.label
		end

		if type(dir) ~= "string" or dir == "" then
			return
		end

		local prepared = M.helpers.prepare_dir(dir, "chat")
		local resolved = resolve_dir_key(prepared)
		local existing = seen[resolved]
		if existing then
			if (roots[existing].label == nil or roots[existing].label == "" or roots[existing].label == default_chat_root_label(roots[existing].dir, roots[existing].is_primary))
				and type(label) == "string" and label ~= "" then
				roots[existing].label = label
			end
			return
		end

		local root = {
			dir = prepared,
			label = (type(label) == "string" and label ~= "") and label or default_chat_root_label(prepared, is_primary),
			is_primary = is_primary,
			role = is_primary and "primary" or "extra",
		}
		table.insert(roots, root)
		seen[resolved] = #roots
	end

	if type(chat_roots) == "table" and #chat_roots > 0 then
		for index, root in ipairs(chat_roots) do
			add_root(root, index == 1)
		end
	else
		add_root(chat_dir, true)

		if type(chat_dirs) == "string" then
			add_root(chat_dirs, false)
		elseif type(chat_dirs) == "table" then
			for _, dir in ipairs(chat_dirs) do
				add_root(dir, false)
			end
		end
	end

	if #roots > 0 then
		roots[1].is_primary = true
		roots[1].role = "primary"
		if roots[1].label == nil or roots[1].label == "" then
			roots[1].label = default_chat_root_label(roots[1].dir, true)
		end
		for index = 2, #roots do
			roots[index].is_primary = false
			roots[index].role = "extra"
			if roots[index].label == nil or roots[index].label == "" then
				roots[index].label = default_chat_root_label(roots[index].dir, false)
			end
		end
	end

	return roots
end

M.get_chat_roots = function()
	if type(M.config.chat_roots) == "table" and #M.config.chat_roots > 0 then
		return M.config.chat_roots
	end
	local roots = normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, nil)
	M.config.chat_roots = roots
	return roots
end

M.get_chat_dirs = function()
	local roots = M.get_chat_roots()
	if #roots > 0 then
		return vim.tbl_map(function(root)
			return root.dir
		end, roots)
	end
	if type(M.config.chat_dir) == "string" and M.config.chat_dir ~= "" then
		return { M.config.chat_dir }
	end
	return {}
end

local function find_chat_root_record(file_name)
	local resolved_file = resolve_dir_key(file_name)
	for _, root in ipairs(M.get_chat_roots()) do
		if path_within_dir(resolved_file, root.dir) then
			return root, resolved_file
		end
	end
	return nil, resolved_file
end

local function find_chat_root(file_name)
	local root, resolved_file = find_chat_root_record(file_name)
	return root and root.dir or nil, resolved_file
end

local function apply_chat_roots(chat_roots)
	if type(chat_roots) ~= "table" or #chat_roots == 0 then
		return nil, "at least one chat directory is required"
	end

	local primary = nil
	local additional = {}
	for index, root in ipairs(chat_roots) do
		if index == 1 then
			primary = root
		else
			table.insert(additional, root)
		end
	end

	local normalized = normalize_chat_roots(primary, additional, nil)
	if #normalized == 0 then
		return nil, "at least one chat directory is required"
	end

	M.config.chat_roots = normalized
	M.config.chat_dir = normalized[1].dir
	M.config.chat_dirs = vim.tbl_map(function(root)
		return root.dir
	end, normalized)
	return normalized
end

local function apply_chat_dirs(chat_dirs)
	if type(chat_dirs) ~= "table" or #chat_dirs == 0 then
		return nil, "at least one chat directory is required"
	end

	local primary = chat_dirs[1]
	local additional = {}
	for i = 2, #chat_dirs do
		table.insert(additional, chat_dirs[i])
	end

	return apply_chat_roots(normalize_chat_roots(primary, additional, nil))
end

M.set_chat_dirs = function(chat_dirs, persist)
	local normalized, err = apply_chat_dirs(chat_dirs)
	if not normalized then
		return nil, err
	end

	if persist ~= false then
		M.refresh_state({
			chat_dirs = vim.deepcopy(M.get_chat_dirs()),
			chat_roots = vim.deepcopy(M.get_chat_roots()),
		})
	end

	return M.get_chat_dirs()
end

M.set_chat_roots = function(chat_roots, persist)
	local normalized, err = apply_chat_roots(chat_roots)
	if not normalized then
		return nil, err
	end

	if persist ~= false then
		M.refresh_state({
			chat_dirs = vim.deepcopy(M.get_chat_dirs()),
			chat_roots = vim.deepcopy(M.get_chat_roots()),
		})
	end

	return M.get_chat_roots()
end

M.add_chat_dir = function(chat_dir, persist, label)
	local roots = vim.deepcopy(M.get_chat_roots())
	table.insert(roots, {
		dir = chat_dir,
		label = label,
	})
	local normalized, err = M.set_chat_roots(roots, persist)
	if not normalized then
		return nil, err
	end
	return M.get_chat_dirs()
end

M.remove_chat_dir = function(chat_dir, persist)
	local target = resolve_dir_key(chat_dir)
	local current_roots = M.get_chat_roots()
	if #current_roots > 0 and resolve_dir_key(current_roots[1].dir) == target then
		return nil, "cannot remove the primary chat directory"
	end
	local remaining = {}
	local removed = false

	for _, root in ipairs(current_roots) do
		if resolve_dir_key(root.dir) == target then
			removed = true
		else
			table.insert(remaining, root)
		end
	end

	if not removed then
		return nil, "chat directory not found: " .. chat_dir
	end

	if #remaining == 0 then
		return nil, "at least one chat directory is required"
	end

	local normalized, err = M.set_chat_roots(remaining, persist)
	if not normalized then
		return nil, err
	end
	return M.get_chat_dirs()
end

M.rename_chat_dir = function(chat_dir, label, persist)
	local target = resolve_dir_key(chat_dir)
	local roots = vim.deepcopy(M.get_chat_roots())
	local updated = false

	for _, root in ipairs(roots) do
		if resolve_dir_key(root.dir) == target then
			root.label = (type(label) == "string" and label ~= "") and label or default_chat_root_label(root.dir, root.is_primary)
			updated = true
			break
		end
	end

	if not updated then
		return nil, "chat directory not found: " .. chat_dir
	end

	local normalized, err = M.set_chat_roots(roots, persist)
	if not normalized then
		return nil, err
	end
	return M.get_chat_roots()
end

-- State shared between async callbacks while responding.
local original_free_cursor_value = nil
local last_content_line = nil

local function set_chat_topic_line(buf, lines, topic)
	local header_end = find_chat_header_end(lines)
	if not header_end then
		vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
		return
	end

	if lines[1] and lines[1]:gsub("^%s*(.-)%s*$", "%1") == "---" then
		for i = 2, header_end - 1 do
			if lines[i]:match("^%s*topic:%s*") then
				vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "topic: " .. topic })
				return
			end
		end
		vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "topic: " .. topic })
		return
	end

	vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
end

local function is_follow_cursor_enabled(override_free_cursor)
	if override_free_cursor ~= nil then
		return override_free_cursor
	end
	if M._state.follow_cursor ~= nil then
		return M._state.follow_cursor
	end
	return not M.config.chat_free_cursor
end

local function query_cursor_line(qt)
	if not qt then
		return nil
	end

	if type(qt.last_line) == "number" and qt.last_line >= 0 then
		return qt.last_line + 1
	end
	if type(qt.first_line) == "number" and qt.first_line >= 0 then
		return qt.first_line + 1
	end

	return nil
end

local function jump_to_active_response(buf, win)
	if not M.tasker.is_busy(buf, true) then
		return false
	end

	local qt = M.tasker.get_active_query_by_buf(buf)
	if not qt then
		return false
	end

	local line = query_cursor_line(qt)
	if not line then
		return false
	end

	M.helpers.cursor_to_line(line, buf, win)
	return true
end

local function shortcut_value(shortcut_config, fallback)
	if type(shortcut_config) == "table" and type(shortcut_config.shortcut) == "string" and shortcut_config.shortcut ~= "" then
		return shortcut_config.shortcut
	end
	return fallback
end

local function shortcut_modes(shortcut_config, fallback)
	if type(shortcut_config) == "table" and type(shortcut_config.modes) == "table" and #shortcut_config.modes > 0 then
		return shortcut_config.modes
	end
	return fallback
end

local function keymaps_for_mode(mode, bufnr)
	local opts = nil
	if bufnr ~= nil then
		opts = { buffer = bufnr }
	end
	local ok, maps = pcall(vim.keymap.get, mode, nil, opts)
	if ok and type(maps) == "table" then
		return maps
	end
	return {}
end

local function find_mapping_lhs_by_desc(desc, modes, bufnr)
	for _, mode in ipairs(modes) do
		if bufnr ~= nil then
			for _, map in ipairs(keymaps_for_mode(mode, bufnr)) do
				if map.desc == desc and type(map.lhs) == "string" and map.lhs ~= "" then
					return map.lhs
				end
			end
		end
		for _, map in ipairs(keymaps_for_mode(mode, nil)) do
			if map.desc == desc and type(map.lhs) == "string" and map.lhs ~= "" then
				return map.lhs
			end
		end
	end
	return nil
end

local function resolve_shortcut(descs, modes, shortcut_config, fallback, bufnr)
	local descriptions = type(descs) == "table" and descs or { descs }
	for _, desc in ipairs(descriptions) do
		local lhs = find_mapping_lhs_by_desc(desc, modes, bufnr)
		if lhs then
			return lhs
		end
	end
	return shortcut_value(shortcut_config, fallback)
end

M._keybinding_help_lines = function()
	local cfg = M.config or {}
	local current_buf = vim.api.nvim_get_current_buf()
	local lines = {
		"Parley Key Bindings",
		"",
		"Global",
	}

	local function add(shortcut, description)
		table.insert(lines, string.format("  %-12s %s", shortcut, description))
	end

	add(
		resolve_shortcut(
			"Show Parley key bindings",
			shortcut_modes(cfg.global_shortcut_keybindings, { "n", "i" }),
			cfg.global_shortcut_keybindings,
			"<C-g>?",
			current_buf
		),
		"Show key bindings"
	)
	add(
		resolve_shortcut("Create New Chat", shortcut_modes(cfg.global_shortcut_new, { "n", "i" }), cfg.global_shortcut_new, "<C-g>c", current_buf),
		"New chat"
	)
	add(
		resolve_shortcut(
			"Review current file in new Chat",
			shortcut_modes(cfg.global_shortcut_review, { "n" }),
			cfg.global_shortcut_review,
			"<C-g>C",
			current_buf
		),
		"Review current file in chat"
	)
	add(
		resolve_shortcut("Open Chat Finder", shortcut_modes(cfg.global_shortcut_finder, { "n", "i" }), cfg.global_shortcut_finder, "<C-g>f", current_buf),
		"Open chat finder"
	)
	add(
		resolve_shortcut(
			"Manage chat roots",
			shortcut_modes(cfg.global_shortcut_chat_dirs, { "n", "i" }),
			cfg.global_shortcut_chat_dirs,
			"<C-g>h",
			current_buf
		),
		"Manage chat roots"
	)
	add(
		resolve_shortcut("Create New Note", shortcut_modes(cfg.global_shortcut_note_new, { "n", "i" }), cfg.global_shortcut_note_new, "<C-n>c", current_buf),
		"New note"
	)
	add(
		resolve_shortcut(
			"Open Note Finder",
			shortcut_modes(cfg.global_shortcut_note_finder, { "n", "i" }),
			cfg.global_shortcut_note_finder,
			"<C-n>f",
			current_buf
		),
		"Open note finder"
	)
	add(
		resolve_shortcut(
			"Change directory to current year's note directory",
			shortcut_modes(cfg.global_shortcut_year_root, { "n", "i" }),
			cfg.global_shortcut_year_root,
			"<C-n>r",
			current_buf
		),
		"Jump to note year root"
	)
	add(
		resolve_shortcut("Open oil.nvim file explorer", shortcut_modes(cfg.global_shortcut_oil, { "n" }), cfg.global_shortcut_oil, "<leader>fo", current_buf),
		"Open oil file explorer"
	)
	add(resolve_shortcut("Toggle Interview Mode", { "n" }, nil, "<C-n>i", current_buf), "Toggle interview mode")
	add(resolve_shortcut("Create Note from Template", { "n" }, nil, "<C-n>t", current_buf), "New note from template")
	add(resolve_shortcut("Toggle web_search tool", { "n" }, nil, "<C-g>w", current_buf), "Toggle web_search")
	add(resolve_shortcut("Toggle raw request mode", { "n" }, nil, "<C-g>r", current_buf), "Toggle raw request mode")
	add(resolve_shortcut("Toggle raw response mode", { "n" }, nil, "<C-g>R", current_buf), "Toggle raw response mode")

	table.insert(lines, "")
	table.insert(lines, "Chat / Markdown")
	add(
		resolve_shortcut("Parley prompt Chat Respond", shortcut_modes(cfg.chat_shortcut_respond, { "n", "i", "v", "x" }), cfg.chat_shortcut_respond, "<C-g><C-g>", current_buf),
		"Respond"
	)
	add(
		resolve_shortcut(
			"Parley prompt Chat Respond All",
			shortcut_modes(cfg.chat_shortcut_respond_all, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_respond_all,
			"<C-g>G",
			current_buf
		),
		"Respond all"
	)
	add(
		resolve_shortcut("Parley prompt Chat Stop", shortcut_modes(cfg.chat_shortcut_stop, { "n", "i", "v", "x" }), cfg.chat_shortcut_stop, "<C-g>s", current_buf),
		"Stop active response"
	)
	add(
		resolve_shortcut(
			"Parley prompt Chat Delete",
			shortcut_modes(cfg.chat_shortcut_delete, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_delete,
			"<C-g>d",
			current_buf
		),
		"Delete chat"
	)
	add(
		resolve_shortcut(
			{ "Parley prompt Next Agent", "Parley add chat reference" },
			shortcut_modes(cfg.chat_shortcut_agent, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_agent,
			"<C-g>a",
			current_buf
		),
		"Next agent / add chat reference"
	)
	add(
		resolve_shortcut(
			"Parley prompt System Prompt Selector",
			shortcut_modes(cfg.chat_shortcut_system_prompt, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_system_prompt,
			"<C-g>p",
			current_buf
		),
		"Next system prompt"
	)
	add(
		resolve_shortcut(
			"Parley prompt Toggle Follow Cursor",
			shortcut_modes(cfg.chat_shortcut_follow_cursor, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_follow_cursor,
			"<C-g>l",
			current_buf
		),
		"Toggle follow cursor"
	)
	add(
		resolve_shortcut(
			{ "Parley prompt Search Chat Sections", "Parley create and insert new chat" },
			shortcut_modes(cfg.chat_shortcut_search, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_search,
			"<C-g>n",
			current_buf
		),
		"Search chat sections / insert chat reference"
	)
	add(
		resolve_shortcut(
			"Parley open file under cursor",
			shortcut_modes(cfg.chat_shortcut_open_file, { "n", "i" }),
			cfg.chat_shortcut_open_file,
			"<C-g>o",
			current_buf
		),
		"Open @@ file reference"
	)
	add(resolve_shortcut("Parley prompt Outline Navigator", { "n" }, nil, "<C-g>t", current_buf), "Outline picker")

table.insert(lines, "")
table.insert(lines, "Chat Finder")
local finder_mappings = cfg.chat_finder_mappings or {}
add(shortcut_value(finder_mappings.next_recency, "<C-a>"), "Cycle chat recency window left")
add(shortcut_value(finder_mappings.previous_recency, "<C-s>"), "Cycle chat recency window right")
add(shortcut_value(finder_mappings.delete, "<C-d>"), "Delete selected chat")
	add(shortcut_value(finder_mappings.move, "<C-r>"), "Move selected chat")
table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring((cfg.chat_finder_recency or {}).months or 6) .. " months)"))

	table.insert(lines, "")
	table.insert(lines, "Note Finder")
	local note_finder_mappings = cfg.note_finder_mappings or {}
	add(shortcut_value(note_finder_mappings.next_recency, "<C-a>"), "Cycle note recency window left")
	add(shortcut_value(note_finder_mappings.previous_recency, "<C-s>"), "Cycle note recency window right")
	add(shortcut_value(note_finder_mappings.delete, "<C-d>"), "Delete selected note")
	table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring((cfg.note_finder_recency or {}).months or 6) .. " months)"))

	table.insert(lines, "")
	table.insert(lines, "Close: q or <Esc>")
	return lines
end

-- Interview mode helper functions
M.format_timestamp = function()
	if not M._state.interview_start_time then
		return ""
	end

	local elapsed = os.time() - M._state.interview_start_time
	local minutes = math.floor(elapsed / 60)

	if minutes < 10 then
		return string.format(":0%dmin", minutes)
	else
		return string.format(":%dmin", minutes)
	end
end

-- In interview mode, insert timestamp and new line when Enter key is pressed
M.setup_interview_keymap = function()
	M.logger.info("Setting up interview keymap")

	-- Set up insert mode keymap for Enter key globally
	vim.keymap.set("i", "<CR>", function()
		print("DEBUG: interview_mode=" .. tostring(M._state.interview_mode)) -- Debug print

		-- Apply timestamp when interview mode is active (no folder restriction)
		if M._state.interview_mode then
			local timestamp = M.format_timestamp()
			M.logger.debug("Inserting timestamp: " .. timestamp)
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

M.remove_interview_keymap = function()
	M.logger.info("Removing interview keymap")
	-- Remove the insert mode keymap
	pcall(function()
		vim.keymap.del("i", "<CR>")
	end)
end

-- Interview timestamp highlighting function, basiclaly highlight the interview timestamp pattern.
-- Interview mode, line starts with :00min, :01min, etc.
M.highlight_interview_timestamps = function(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	-- Use a static match ID to avoid searching through all matches
	local match_id_key = "parley_interview_timestamps_" .. buf
	if not M._interview_match_ids then
		M._interview_match_ids = {}
	end

	-- Clear existing match for this buffer if it exists
	if M._interview_match_ids[match_id_key] then
		pcall(vim.fn.matchdelete, M._interview_match_ids[match_id_key])
		M._interview_match_ids[match_id_key] = nil
	end

	-- Add highlighting for the entire timestamp line with very low priority (-1)
	-- to ensure all search highlights (incsearch, Search, CurSearch) can take precedence
	local match_id = vim.fn.matchadd("InterviewTimestamp", "^\\s*:\\d\\+min.*$", -1)
	M._interview_match_ids[match_id_key] = match_id
end

-- Timer functions for interview mode statusline updates
M.start_interview_timer = function()
	-- Stop any existing timer first
	M.stop_interview_timer()

	-- Create a timer that updates the statusline every 15 seconds
	M._state.interview_timer = vim.loop.new_timer()
	M._state.interview_timer:start(
		15000,
		15000,
		vim.schedule_wrap(function()
			if M._state.interview_mode then
				-- Refresh lualine to update the timer display
				pcall(function()
					require("lualine").refresh()
				end)
			else
				-- Stop timer if interview mode is no longer active
				M.stop_interview_timer()
			end
		end)
	)

	M.logger.debug("Interview timer started")
end

M.stop_interview_timer = function()
	if M._state.interview_timer then
		stop_and_close_timer(M._state.interview_timer)
		M._state.interview_timer = nil
		M.logger.debug("Interview timer stopped")
	end
end

-- setup function
M._setup_called = false
---@param opts the one returned from config.lua, it can come from several sources, either fully specified
---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
M.setup = function(opts)
	M._setup_called = true

	math.randomseed(os.time())

	-- Initialize file tracker
	M.file_tracker = require("parley.file_tracker").init()

	-- make sure opts is a table
	opts = opts or {}
	if type(opts) ~= "table" then
		M.logger.error(string.format("setup() expects table, but got %s:\n%s", type(opts), vim.inspect(opts)))
		opts = {}
	end

	-- reset M.config
	M.config = vim.deepcopy(config)

	local curl_params = opts.curl_params or M.config.curl_params
		local state_dir = opts.state_dir or M.config.state_dir

	M.logger.setup(opts.log_file or M.config.log_file, opts.log_sensitive)

	M.vault.setup({ state_dir = state_dir, curl_params = curl_params })

	-- Process API keys from api_keys table and load them into vault
	local api_keys = opts.api_keys or M.config.api_keys or {}
	for provider_name, api_key in pairs(api_keys) do
		if api_key then
			M.logger.debug("Loading " .. provider_name .. " API key into vault")
			M.vault.add_secret(provider_name, api_key)
		end
	end

	-- Process providers and inject secrets from vault if needed
	local providers = opts.providers or M.config.providers or {}
	for provider_name, provider in pairs(providers) do
		if provider and type(provider) == "table" and not provider.secret and api_keys[provider_name] then
			M.logger.debug("Setting " .. provider_name .. " provider secret from api_keys")
			provider.secret = api_keys[provider_name]
		end
	end

	M.dispatcher.setup({ providers = providers, curl_params = curl_params })

	-- Clear sensitive data from config
	M.config.api_keys = nil
	opts.api_keys = nil
	M.config.providers = nil
	opts.providers = nil

	-- selectively merge some keys. this allows configuration to partially override this keys.
	local mergeTables = { "hooks", "agents", "system_prompts" }
	for _, tbl in ipairs(mergeTables) do
		M[tbl] = M[tbl] or {}
		---@diagnostic disable-next-line
		for k, v in pairs(M.config[tbl]) do
			if tbl == "hooks" then
				M[tbl][k] = v
			elseif tbl == "agents" then
				---@diagnostic disable-next-line
				M[tbl][v.name] = v
			elseif tbl == "system_prompts" then
				---@diagnostic disable-next-line
				M[tbl][v.name] = v
			end
		end
		M.config[tbl] = nil

		opts[tbl] = opts[tbl] or {}
		for k, v in pairs(opts[tbl]) do
			if tbl == "hooks" then
				M[tbl][k] = v
			elseif tbl == "agents" then
				M[tbl][v.name] = v
			elseif tbl == "system_prompts" then
				M[tbl][v.name] = v
			end
		end
		opts[tbl] = nil
	end

	-- now merge the rest of opts into M.config, this would be fully override.
	for k, v in pairs(opts) do
		M.config[k] = v
	end

	apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))

	-- make sure _dirs exists
	for k, v in pairs(M.config) do
		if k ~= "chat_dir" and k:match("_dir$") and type(v) == "string" then
			M.config[k] = M.helpers.prepare_dir(v, k)
		end
	end

	-- remove disabled agents
	for name, agent in pairs(M.agents) do
		if type(agent) ~= "table" or agent.disable then
			M.agents[name] = nil
		elseif not agent.model or not agent.system_prompt then
			M.logger.warning(
				"Agent "
					.. name
					.. " is missing model or system_prompt\n"
					.. "If you want to disable an agent, use: { name = '"
					.. name
					.. "', disable = true },"
			)
			M.agents[name] = nil
		end
	end

	-- prepare agent list
	M._agents = {}
	for name, _ in pairs(M.agents) do
		M.agents[name].provider = M.agents[name].provider or "openai"

		if M.dispatcher.providers[M.agents[name].provider] then
			table.insert(M._agents, name)
		else
			M.agents[name] = nil
		end
	end
	table.sort(M._agents)

	-- remove disabled system_prompts
	for name, prompt in pairs(M.system_prompts) do
		if type(prompt) ~= "table" or prompt.disable then
			M.system_prompts[name] = nil
		elseif not prompt.system_prompt then
			M.logger.warning(
				"System prompt "
					.. name
					.. " is missing system_prompt field\n"
					.. "If you want to disable a system prompt, use: { name = '"
					.. name
					.. "', disable = true },"
			)
			M.system_prompts[name] = nil
		end
	end

	-- prepare system_prompts list
	M._system_prompts = {}
	for name, _ in pairs(M.system_prompts) do
		table.insert(M._system_prompts, name)
	end
	table.sort(M._system_prompts)

	M.refresh_state()

	if M.config.default_agent then
		M.refresh_state({ agent = M.config.default_agent })
	end

	-- register user commands
	for hook, _ in pairs(M.hooks) do
		M.helpers.create_user_command(M.config.cmd_prefix .. hook, function(params)
			if M.hooks[hook] ~= nil then
				M.refresh_state()
				M.logger.debug("running hook: " .. hook)
				return M.hooks[hook](M, params)
			end
			M.logger.error("The hook '" .. hook .. "' does not exist.")
		end)
	end

	-- set up global keymaps for commands
	if M.config.global_shortcut_finder then
		for _, mode in ipairs(M.config.global_shortcut_finder.modes) do
			if mode == "n" then
				vim.keymap.set(
					mode,
					M.config.global_shortcut_finder.shortcut,
					":" .. M.config.cmd_prefix .. "ChatFinder<CR>",
					{ silent = true, desc = "Open Chat Finder" }
				)
			elseif mode == "i" then
				vim.keymap.set(
					mode,
					M.config.global_shortcut_finder.shortcut,
					"<ESC>:" .. M.config.cmd_prefix .. "ChatFinder<CR>",
					{ silent = true, desc = "Open Chat Finder" }
				)
			end
		end
	end

	if M.config.global_shortcut_new then
		for _, mode in ipairs(M.config.global_shortcut_new.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_new.shortcut, function()
					M.cmd.ChatNew({})
				end, { silent = true, desc = "Create New Chat" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_new.shortcut, function()
					vim.cmd("stopinsert")
					M.cmd.ChatNew({})
				end, { silent = true, desc = "Create New Chat" })
			end
		end
	end

	if M.config.global_shortcut_chat_dirs then
		for _, mode in ipairs(M.config.global_shortcut_chat_dirs.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_chat_dirs.shortcut, function()
					M.cmd.ChatDirs({})
				end, { silent = true, desc = "Manage chat roots" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_chat_dirs.shortcut, function()
					vim.cmd("stopinsert")
					M.cmd.ChatDirs({})
				end, { silent = true, desc = "Manage chat roots" })
			end
		end
	end

	if M.config.global_shortcut_keybindings then
		for _, mode in ipairs(M.config.global_shortcut_keybindings.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_keybindings.shortcut, function()
					M.cmd.KeyBindings()
				end, { silent = true, desc = "Show Parley key bindings" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_keybindings.shortcut, function()
					vim.cmd("stopinsert")
					M.cmd.KeyBindings()
				end, { silent = true, desc = "Show Parley key bindings" })
			end
		end
	end

	if M.config.global_shortcut_review then
		for _, mode in ipairs(M.config.global_shortcut_review.modes) do
			vim.keymap.set(mode, M.config.global_shortcut_review.shortcut, function()
				M.cmd.ChatReview({})
			end, { silent = true, desc = "Review current file in new Chat" })
		end
	end

	-- Set up global shortcuts for note-taking
	if M.config.global_shortcut_note_new then
		for _, mode in ipairs(M.config.global_shortcut_note_new.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_note_new.shortcut, function()
					M.cmd.NoteNew()
				end, { silent = true, desc = "Create New Note" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_note_new.shortcut, function()
					vim.cmd("stopinsert")
					M.cmd.NoteNew()
				end, { silent = true, desc = "Create New Note" })
			end
		end
	end

	if M.config.global_shortcut_note_finder then
		for _, mode in ipairs(M.config.global_shortcut_note_finder.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_note_finder.shortcut, function()
					M.cmd.NoteFinder({})
				end, { silent = true, desc = "Open Note Finder" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_note_finder.shortcut, function()
					vim.cmd("stopinsert")
					M.cmd.NoteFinder({})
				end, { silent = true, desc = "Open Note Finder" })
			end
		end
	end

	-- Set up global shortcut for navigating to current year's note directory
	if M.config.global_shortcut_year_root then
		for _, mode in ipairs(M.config.global_shortcut_year_root.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_year_root.shortcut, function()
					local current_year = os.date("%Y")
					local year_dir = M.config.notes_dir .. "/" .. current_year
					M.helpers.prepare_dir(year_dir, "year")
					vim.cmd("cd " .. year_dir)
				end, { silent = true, desc = "Change directory to current year's note directory" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_year_root.shortcut, function()
					vim.cmd("stopinsert")
					local current_year = os.date("%Y")
					local year_dir = M.config.notes_dir .. "/" .. current_year
					M.helpers.prepare_dir(year_dir, "year")
					vim.cmd("cd " .. year_dir)
				end, { silent = true, desc = "Change directory to current year's note directory" })
			end
		end
	end

	-- Set up global shortcut for opening oil.nvim
	if M.config.global_shortcut_oil then
		for _, mode in ipairs(M.config.global_shortcut_oil.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_oil.shortcut, function()
					-- Check if oil.nvim is available
					local ok, oil = pcall(require, "oil")
					if ok then
						oil.open()
					else
						M.logger.error("oil.nvim is not installed. Please install it with your package manager.")
					end
				end, { silent = true, desc = "Open oil.nvim file explorer" })
			end
		end
	end

	-- Set up global keymap for interview mode toggle
	vim.keymap.set("n", "<C-n>i", function()
		M.cmd.ToggleInterview()
	end, { silent = true, desc = "Toggle Interview Mode" })

	-- Set up global keymap for template-based note creation
	vim.keymap.set("n", "<C-n>t", function()
		M.cmd.NoteNewFromTemplate()
	end, { silent = true, desc = "Create Note from Template" })

	local completions = {
		ChatNew = {},
		Agent = agent_completion,
		ChatDirAdd = dir_completion,
		ChatDirRemove = chat_dir_completion,
		ChatMove = chat_dir_completion,
	}

	-- Add ChatRespondAll command
	M.cmd.ChatRespondAll = function()
		M.chat_respond_all()
	end

	-- Toggle Raw Request mode (parse_raw_request)
	M.cmd.ToggleRawRequest = function()
		if M.config.raw_mode and M.config.raw_mode.enable then
			M.config.raw_mode.parse_raw_request = not M.config.raw_mode.parse_raw_request
			M.logger.info("Raw Request mode " .. (M.config.raw_mode.parse_raw_request and "enabled" or "disabled"))
			vim.notify(
				"Raw Request mode " .. (M.config.raw_mode.parse_raw_request and "enabled" or "disabled"),
				vim.log.levels.INFO
			)
			pcall(function()
				require("lualine").refresh()
			end)
		else
			M.logger.warning("Raw mode is disabled in configuration")
			vim.notify("Raw mode is disabled in configuration", vim.log.levels.WARN)
		end
	end

	-- Toggle Raw Response mode (show_raw_response)
	M.cmd.ToggleRawResponse = function()
		if M.config.raw_mode and M.config.raw_mode.enable then
			M.config.raw_mode.show_raw_response = not M.config.raw_mode.show_raw_response
			M.logger.info("Raw Response mode " .. (M.config.raw_mode.show_raw_response and "enabled" or "disabled"))
			vim.notify(
				"Raw Response mode " .. (M.config.raw_mode.show_raw_response and "enabled" or "disabled"),
				vim.log.levels.INFO
			)
			pcall(function()
				require("lualine").refresh()
			end)
		else
			M.logger.warning("Raw mode is disabled in configuration")
			vim.notify("Raw mode is disabled in configuration", vim.log.levels.WARN)
		end
	end

	-- Toggle both Raw Request and Raw Response modes
	M.cmd.ToggleRaw = function()
		if M.config.raw_mode and M.config.raw_mode.enable then
			-- Toggle both settings to the same value (both on or both off)
			local current_state = M.config.raw_mode.show_raw_response or M.config.raw_mode.parse_raw_request
			M.config.raw_mode.show_raw_response = not current_state
			M.config.raw_mode.parse_raw_request = not current_state
			M.logger.info("Raw mode " .. (not current_state and "enabled" or "disabled") .. " (both request and response)")
			vim.notify(
				"Raw mode " .. (not current_state and "enabled" or "disabled") .. " (both request and response)",
				vim.log.levels.INFO
			)
			pcall(function()
				require("lualine").refresh()
			end)
		else
			M.logger.warning("Raw mode is disabled in configuration")
			vim.notify("Raw mode is disabled in configuration", vim.log.levels.WARN)
		end
	end

	-- Toggle Interview Mode
	M.cmd.ToggleInterview = function()
		-- First check if cursor is on an interview timestamp line
		local cursor_line = vim.api.nvim_get_current_line()
		local timestamp_match = cursor_line:match("^%s*:(%d+)min")

		if timestamp_match then
			-- Parse the minute value from the line
			local minutes = tonumber(timestamp_match)
			if minutes then
				-- Calculate the start time based on current time minus the elapsed minutes
				M._state.interview_start_time = os.time() - (minutes * 60)
				M._state.interview_mode = true
				M.logger.info(string.format("Interview mode enabled with timer set to %d minutes", minutes))
				vim.notify(string.format("Interview timer set to %d minutes", minutes), vim.log.levels.INFO)

				-- Set up insert mode keymap for timestamps
				M.setup_interview_keymap()
				-- Start timer for statusline updates
				M.start_interview_timer()

				-- Refresh lualine to update display
				pcall(function()
					require("lualine").refresh()
				end)
				return
			end
		end

		-- Normal toggle behavior if not on a timestamp line
		M._state.interview_mode = not M._state.interview_mode
		print("DEBUG: Interview mode is now: " .. tostring(M._state.interview_mode)) -- Debug print

		if M._state.interview_mode then
			M._state.interview_start_time = os.time()
			M.logger.info("Interview mode enabled")
			vim.notify("Interview mode enabled", vim.log.levels.INFO)

			-- Insert :00min marker at current cursor position
			local mode = vim.fn.mode()
			if mode == "i" then
				-- Already in insert mode, just insert the text
				vim.api.nvim_put({ ":00min " }, "c", true, true)
			else
				-- Enter insert mode and insert the marker
				vim.cmd("startinsert")
				vim.schedule(function()
					vim.api.nvim_put({ ":00min " }, "c", true, true)
				end)
			end

			-- Set up insert mode keymap for timestamps
			M.setup_interview_keymap()
			-- Start timer for statusline updates
			M.start_interview_timer()
		else
			M._state.interview_start_time = nil
			M.logger.info("Interview mode disabled")
			vim.notify("Interview mode disabled", vim.log.levels.INFO)
			-- Remove insert mode keymap and highlighting
			M.remove_interview_keymap()
			-- Stop timer
			M.stop_interview_timer()
		end
		-- Refresh lualine to update display
		pcall(function()
			require("lualine").refresh()
		end)
	end

	-- Toggle server-side web_search tool per chat
	M.cmd.ToggleWebSearch = function()
		local agent = M._state.agent
		local conf = M.agents[agent]
		local provider = conf and conf.provider or nil
		local model_conf = conf and conf.model or nil
		local enable = not M._state.web_search
		-- Only allow enabling for providers that support web_search
		local prov = require("parley.providers")
		if enable and not prov.has_feature(provider, "web_search", model_conf) then
			local msg = string.format("Agent %s does not support web_search", agent)
			M.logger.error(msg)
			vim.notify(msg, vim.log.levels.ERROR)
			return
		end
		-- For OpenAI, require search_model to be defined on the model config
		if enable and prov.resolve_name(provider) == "openai" then
			if type(model_conf) == "table" and not model_conf.search_model then
				local msg = string.format("Agent %s has no search_model defined", agent)
				M.logger.error(msg)
				vim.notify(msg, vim.log.levels.ERROR)
				return
			end
		end
		-- For CLIProxyAPI in openai_search_model mode, also require search_model.
		if enable and prov.resolve_name(provider) == "cliproxyapi" then
			local strategy = prov.get_web_search_strategy(provider, model_conf) or "none"
			if strategy == "openai_search_model" then
				if type(model_conf) == "table" and not model_conf.search_model then
					local msg = string.format("Agent %s has no search_model defined", agent)
					M.logger.error(msg)
					vim.notify(msg, vim.log.levels.ERROR)
					return
				end
			end
		end
		-- persist the toggle in chat state
		M.refresh_state({ web_search = enable })
		local status = enable and "enabled" or "disabled"
		local msg = string.format("web_search %s", status)
		M.logger.info(msg)
		vim.notify(msg, vim.log.levels.INFO)
	end

	M.cmd.ToggleFollowCursor = function()
		local buf = vim.api.nvim_get_current_buf()
		local win = vim.api.nvim_get_current_win()
		local enable = not is_follow_cursor_enabled(nil)

		M.refresh_state({ follow_cursor = enable })

		if enable then
			jump_to_active_response(buf, win)
		end

		local status = enable and "enabled" or "disabled"
		local msg = string.format("follow cursor %s", status)
		M.logger.info(msg)
		vim.notify(msg, vim.log.levels.INFO)
	end

	M.cmd.KeyBindings = function()
		local lines = M._keybinding_help_lines()
		local width = 0
		for _, line in ipairs(lines) do
			width = math.max(width, vim.fn.strdisplaywidth(line))
		end
		width = math.min(math.max(width + 4, 40), math.max(vim.o.columns - 4, 40))
		local height = math.min(#lines + 2, math.max(vim.o.lines - 4, 8))
		local row = math.max(math.floor((vim.o.lines - height) / 2 - 1), 0)
		local col = math.max(math.floor((vim.o.columns - width) / 2), 0)

		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false

		local win = vim.api.nvim_open_win(buf, true, {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal",
			border = "rounded",
		})

		local function close_window()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end

		vim.keymap.set("n", "q", close_window, { buffer = buf, silent = true })
		vim.keymap.set("n", "<Esc>", close_window, { buffer = buf, silent = true })
		vim.keymap.set("i", "<Esc>", close_window, { buffer = buf, silent = true })
	end
	-- Logout from Google Drive OAuth (remove stored tokens)
	M.cmd.GdriveLogout = function()
		local oauth = require("parley.oauth")
				oauth.logout(function(success)
					if success then
						vim.schedule(function()
							vim.notify("Google Drive OAuth accounts removed", vim.log.levels.INFO)
						end)
					else
						vim.schedule(function()
							vim.notify("No Google Drive OAuth accounts found", vim.log.levels.WARN)
						end)
					end
				end)
	end

	-- register default commands
	for cmd, _ in pairs(M.cmd) do
		if M.hooks[cmd] == nil then
			M.helpers.create_user_command(M.config.cmd_prefix .. cmd, function(params)
				M.logger.debug("running command: " .. cmd)
				M.refresh_state()
				M.cmd[cmd](params)
			end, completions[cmd])
		end
	end

	-- set up buffer update handler
	M.setup_buf_handler()
	-- bind <C-g>w to toggle web_search tool
	vim.keymap.set(
		"n",
		"<C-g>w",
		string.format("<cmd>%sToggleWebSearch<CR>", M.config.cmd_prefix),
		{ noremap = true, silent = true, desc = "Toggle web_search tool" }
	)
	-- bind <C-g>r to toggle raw request mode, <C-g>R to toggle raw response mode
	vim.keymap.set(
		"n",
		"<C-g>r",
		string.format("<cmd>%sToggleRawRequest<CR>", M.config.cmd_prefix),
		{ noremap = true, silent = true, desc = "Toggle raw request mode" }
	)
	vim.keymap.set(
		"n",
		"<C-g>R",
		string.format("<cmd>%sToggleRawResponse<CR>", M.config.cmd_prefix),
		{ noremap = true, silent = true, desc = "Toggle raw response mode" }
	)

	-- Setup lualine integration if lualine is enabled
	pcall(function()
		if M.config.lualine and M.config.lualine.enable then
			M.lualine.setup(M)
		end
	end)

	if vim.fn.executable("curl") == 0 then
		M.logger.error("curl is not installed, run :checkhealth parley")
	end

	-- Set up custom Search highlight for better visibility of all matches
	local st = vim.api.nvim_get_hl(0, { name = "PmenuSel" })
	vim.api.nvim_set_hl(0, "Search", {
		bg = st.bg or st.background,
		fg = st.fg or st.foreground,
		bold = false,
	})
	vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
		link = "IncSearch",
	})

	M.logger.debug("setup finished")
end

---@param update table | nil # table with options
M.refresh_state = function(update)
	local state_file = M.config.state_dir .. "/state.json"
	update = update or {}

	local old_state = vim.deepcopy(M._state)

	local disk_state = {}
	if vim.fn.filereadable(state_file) ~= 0 then
		disk_state = M.helpers.file_to_table(state_file) or {}
	end

	if not disk_state.updated then
		local primary_chat_dir = M.get_chat_dirs()[1]
		local last = primary_chat_dir and (primary_chat_dir .. "/last.md") or nil
		if last and vim.fn.filereadable(last) == 1 then
			os.remove(last)
		end
	end

	if not M._state.updated or (disk_state.updated and M._state.updated < disk_state.updated) then
		M._state = vim.deepcopy(disk_state)
	end
	M._state.updated = os.time()

	-- Always ensure interview mode starts as false (don't persist interview mode across sessions)
	M._state.interview_mode = false
	M._state.interview_start_time = nil
	-- Stop any running interview timer
	M.stop_interview_timer()

	-- apply in-memory updates
	for k, v in pairs(update) do
		M._state[k] = v
	end
	-- initialize per-chat web_search setting if missing (migrate from old key name)
	if M._state.web_search == nil then
		if M._state.claude_web_search ~= nil then
			M._state.web_search = M._state.claude_web_search
			M._state.claude_web_search = nil
		else
			M._state.web_search = M.config.web_search
		end
	end

	if M._state.follow_cursor == nil then
		M._state.follow_cursor = not M.config.chat_free_cursor
	end

	if type(M._state.chat_roots) == "table" and #M._state.chat_roots > 0 then
		apply_chat_roots(M._state.chat_roots)
	elseif type(M._state.chat_dirs) == "table" and #M._state.chat_dirs > 0 then
		apply_chat_dirs(M._state.chat_dirs)
		M._state.chat_roots = vim.deepcopy(M.get_chat_roots())
	else
		M._state.chat_roots = vim.deepcopy(M.get_chat_roots())
		M._state.chat_dirs = vim.deepcopy(M.get_chat_dirs())
	end

	if not M._state.agent or not M.agents[M._state.agent] then
		M._state.agent = M._agents[1]
	end

	if not M._state.system_prompt or not M.system_prompts[M._state.system_prompt] then
		M._state.system_prompt = "default"
	end

	if M._state.last_chat and vim.fn.filereadable(M._state.last_chat) == 0 then
		M._state.last_chat = nil
	end

	for k, _ in pairs(M._state) do
		if M._state[k] ~= old_state[k] or M._state[k] ~= disk_state[k] then
			M.logger.debug(
				string.format(
					"state[%s]: disk=%s old=%s new=%s",
					k,
					vim.inspect(disk_state[k]),
					vim.inspect(old_state[k]),
					vim.inspect(M._state[k])
				)
			)
		end
	end

	M.helpers.table_to_file(M._state, state_file)

	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	M.display_agent(buf, file_name)
end

---@return string
M._remote_reference_cache_file = function()
	return M.config.state_dir .. "/remote_reference_cache.json"
end

---@return table
M._load_remote_reference_cache = function()
	if M._remote_reference_cache ~= nil then
		return M._remote_reference_cache
	end

	local cache_file = M._remote_reference_cache_file()
	local cache = {}
	if vim.fn.filereadable(cache_file) ~= 0 then
		cache = M.helpers.file_to_table(cache_file) or {}
	end

	cache.chats = cache.chats or {}
	M._remote_reference_cache = cache
	return M._remote_reference_cache
end

M._save_remote_reference_cache = function()
	local cache = M._load_remote_reference_cache()
	M.helpers.prepare_dir(M.config.state_dir, "state")
	M.helpers.table_to_file(cache, M._remote_reference_cache_file())
end

---@param chat_file string|nil
---@return table
M._get_chat_remote_reference_cache = function(chat_file)
	local cache = M._load_remote_reference_cache()
	local chat_key = chat_file or ""
	cache.chats[chat_key] = cache.chats[chat_key] or {}
	return cache.chats[chat_key]
end

---@param url string
---@param err string|nil
---@return string
M._format_remote_reference_error_content = function(url, err)
	return "File: " .. url .. "\n[Error: " .. (err or "Failed to fetch") .. "]\n\n"
end

---@param url string
---@return string
M._format_missing_remote_reference_cache_content = function(url)
	return M._format_remote_reference_error_content(
		url,
		"Remote URL content is not cached. Refresh the question that introduced this URL to fetch it again."
	)
end

-- stop receiving responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.cmd.Stop = function(signal)
	-- If we were in the middle of a batch resubmission, make sure to restore the cursor setting
	if original_free_cursor_value ~= nil then
		M.logger.debug(
			"Stop called during resubmission - restoring chat_free_cursor to: " .. tostring(original_free_cursor_value)
		)
		M.config.chat_free_cursor = original_free_cursor_value
		original_free_cursor_value = nil
	end

	M.tasker.stop(signal)
end

-- Enhanced markdown to HTML converter with glow-like styling
M.simple_markdown_to_html = function(markdown)
	local html = markdown

	-- Escape HTML special characters first
	html = html:gsub("&", "&amp;")
	html = html:gsub("<", "&lt;")
	html = html:gsub(">", "&gt;")

	-- Convert code blocks with language-specific styling
	html = html:gsub("```([^\n]*)\n(.-)\n```", function(lang, code)
		local class_attr = ""
		if lang and lang ~= "" then
			class_attr = ' class="language-' .. lang .. '"'
		end
		return '\n<div class="code-block"><pre><code' .. class_attr .. ">" .. code .. "</code></pre></div>\n"
	end)

	-- Convert inline code
	html = html:gsub("`([^`\n]+)`", '<code class="inline-code">%1</code>')

	-- Convert headers with proper spacing
	html = html:gsub("^# ([^\n]+)", '<h1 class="main-header">%1</h1>')
	html = html:gsub("\n# ([^\n]+)", '\n<h1 class="main-header">%1</h1>')
	html = html:gsub("^## ([^\n]+)", '<h2 class="section-header">%1</h2>')
	html = html:gsub("\n## ([^\n]+)", '\n<h2 class="section-header">%1</h2>')
	html = html:gsub("^### ([^\n]+)", '<h3 class="sub-header">%1</h3>')
	html = html:gsub("\n### ([^\n]+)", '\n<h3 class="sub-header">%1</h3>')

	-- Convert bold and italic text
	html = html:gsub("%*%*([^%*\n]+)%*%*", '<strong class="bold-text">%1</strong>')
	html = html:gsub("__([^_\n]+)__", '<strong class="bold-text">%1</strong>')
	html = html:gsub("%*([^%*\n]+)%*", '<em class="italic-text">%1</em>')
	html = html:gsub("_([^_\n]+)_", '<em class="italic-text">%1</em>')

	-- Convert lists
	html = html:gsub("\n%- ([^\n]+)", '\n<li class="list-item">%1</li>')
	html = html:gsub("(<li[^>]*>.-</li>)", '<ul class="bullet-list">%1</ul>')

	-- Convert blockquotes
	html = html:gsub("\n> ([^\n]+)", '\n<blockquote class="quote">%1</blockquote>')

	-- Handle paragraphs more carefully
	html = html:gsub("\n\n+", "\n</p>\n<p class='paragraph'>\n")
	html = '<p class="paragraph">' .. html .. "</p>"

	-- Clean up and fix paragraph wrapping around block elements
	html = html:gsub("<p[^>]*>%s*<h", "<h")
	html = html:gsub("</h([123])>%s*</p>", "</h%1>")
	html = html:gsub("<p[^>]*>%s*<div", "<div")
	html = html:gsub("</div>%s*</p>", "</div>")
	html = html:gsub("<p[^>]*>%s*<ul", "<ul")
	html = html:gsub("</ul>%s*</p>", "</ul>")
	html = html:gsub("<p[^>]*>%s*<blockquote", "<blockquote")
	html = html:gsub("</blockquote>%s*</p>", "</blockquote>")
	html = html:gsub("<p[^>]*>%s*</p>", "")

	return html
end

-- Export current chat buffer as HTML
M.cmd.ExportHTML = function(params)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- Check if this is a valid chat file
	local validation_error = M.not_chat(buf, file_name)
	if validation_error then
		M.logger.error("Cannot export: " .. validation_error)
		print("Error: Cannot export - " .. validation_error)
		return
	end

	-- Get all buffer lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		M.logger.error("Buffer is empty")
		print("Error: Buffer is empty")
		return
	end

	-- Convert content to markdown format suitable for processing
	local content = table.concat(lines, "\n")

	-- Replace 💬: with ## Question (similar to your sed command)
	content = content:gsub("💬:", "## Question\n\n")

	-- Extract title from first line for filename and HTML title
	local title = "Untitled"
	local html_filename

	if lines[1] and lines[1]:match("^# (.+)") then
		title = lines[1]:match("^# (.+)")
		-- Clean title for filename (remove invalid characters and normalize)
		html_filename = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
		-- Limit filename length
		if #html_filename > 50 then
			html_filename = html_filename:sub(1, 50)
		end
	else
		-- Fallback to timestamp-based filename if no title found
		local basename = vim.fn.fnamemodify(file_name, ":t:r")
		html_filename = basename
	end

	local output_file = html_filename .. ".html"

	-- Export directory (configurable, with CLI override)
	local export_dir = params and params.args and params.args ~= "" and params.args or M.config.export_html_dir
	local full_output_path = export_dir .. "/" .. output_file

	-- Create HTML content with enhanced glow-like styling
	local html_template = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. title .. [[</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
    <style>
        /* Base styling inspired by glow */
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            background: linear-gradient(135deg, #fdfbfb 0%, #ebedee 100%);
            color: #2d3748;
            font-size: 16px;
        }

        /* Headers with glow-like styling */
        .main-header {
            font-size: 2.5rem;
            font-weight: 700;
            color: #1a365d;
            margin: 2rem 0 1.5rem 0;
            padding-bottom: 0.5rem;
            border-bottom: 3px solid #4299e1;
            text-shadow: 0 1px 2px rgba(0,0,0,0.1);
        }

        .section-header {
            font-size: 2rem;
            font-weight: 600;
            color: #2b6cb0;
            margin: 2.5rem 0 1rem 0;
            padding-bottom: 0.3rem;
            border-bottom: 2px solid #bee3f8;
            position: relative;
        }

        .section-header::before {
            content: '📋';
            margin-right: 0.5rem;
            font-size: 1.5rem;
        }

        .sub-header {
            font-size: 1.5rem;
            font-weight: 600;
            color: #3182ce;
            margin: 2rem 0 0.8rem 0;
            padding-left: 1rem;
            border-left: 4px solid #90cdf4;
        }

        /* Enhanced paragraphs */
        .paragraph {
            margin: 1.2rem 0;
            color: #4a5568;
            text-align: justify;
            text-justify: inter-word;
        }

        /* Code blocks with enhanced styling */
        .code-block {
            margin: 1.5rem 0;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            border: 1px solid #e2e8f0;
        }

        .code-block pre {
            margin: 0;
            padding: 1.5rem;
            background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%);
            border: none;
            overflow-x: auto;
            font-size: 0.9rem;
            line-height: 1.5;
        }

        .code-block code {
            font-family: 'Fira Code', 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            background: none;
            padding: 0;
            color: #2d3748;
        }

        /* Inline code with better styling */
        .inline-code {
            background: linear-gradient(135deg, #fed7e2 0%, #fbb6ce 100%);
            color: #97266d;
            padding: 0.2rem 0.4rem;
            border-radius: 6px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            font-size: 0.9em;
            font-weight: 500;
            border: 1px solid #f687b3;
        }

        /* Text formatting */
        .bold-text {
            color: #2d3748;
            font-weight: 700;
        }

        .italic-text {
            color: #4a5568;
            font-style: italic;
        }

        /* Lists with better styling */
        .bullet-list {
            margin: 1rem 0;
            padding-left: 0;
            list-style: none;
        }

        .list-item {
            position: relative;
            padding-left: 2rem;
            margin: 0.5rem 0;
            color: #4a5568;
        }

        .list-item::before {
            content: '•';
            color: #4299e1;
            font-weight: bold;
            position: absolute;
            left: 0.5rem;
            font-size: 1.2em;
        }

        /* Enhanced blockquotes */
        .quote {
            background: linear-gradient(135deg, #e6fffa 0%, #b2f5ea 100%);
            border-left: 4px solid #38b2ac;
            margin: 1.5rem 0;
            padding: 1rem 1.5rem;
            border-radius: 0 8px 8px 0;
            color: #234e52;
            font-style: italic;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        /* Special styling for chat elements */
        .chat-question {
            background: linear-gradient(135deg, #ebf8ff 0%, #bee3f8 100%);
            border-left: 4px solid #3182ce;
            border-radius: 0 12px 12px 0;
            padding: 1.5rem;
            margin: 2rem 0;
            position: relative;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }

        .chat-question::before {
            content: '💬';
            position: absolute;
            left: -0.5rem;
            top: 1rem;
            background: white;
            padding: 0.3rem;
            border-radius: 50%;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        /* Responsive design */
        @media (max-width: 768px) {
            body {
                padding: 20px 15px;
                font-size: 15px;
            }
            .main-header {
                font-size: 2rem;
            }
            .section-header {
                font-size: 1.6rem;
            }
            .code-block pre {
                padding: 1rem;
                font-size: 0.8rem;
            }
        }

        /* Syntax highlighting overrides */
        .hljs {
            background: transparent !important;
        }

        .hljs-keyword { color: #d73a49; font-weight: 600; }
        .hljs-string { color: #032f62; }
        .hljs-comment { color: #6a737d; font-style: italic; }
        .hljs-function { color: #6f42c1; }
        .hljs-number { color: #005cc5; }
        .hljs-variable { color: #e36209; }
    </style>
</head>
<body>
]] .. M.simple_markdown_to_html(content) .. [[
</body>
</html>]]

	-- Write HTML file
	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		M.logger.error("Failed to create output file: " .. full_output_path)
		print("Error: Failed to create output file: " .. full_output_path)
		return
	end

	file_handle:write(html_template)
	file_handle:close()

	M.logger.info("Exported chat to HTML: " .. full_output_path)
	print("✅ Exported chat to: " .. full_output_path)
end

-- Export current chat buffer as Markdown for Jekyll
M.cmd.ExportMarkdown = function(params)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- Check if this is a valid chat file
	local validation_error = M.not_chat(buf, file_name)
	if validation_error then
		M.logger.error("Cannot export: " .. validation_error)
		print("Error: Cannot export - " .. validation_error)
		return
	end

	-- Get all buffer lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		M.logger.error("Buffer is empty")
		print("Error: Buffer is empty")
		return
	end

	local headers, header_end = parse_chat_headers(lines)
	if not header_end then
		M.logger.error("Cannot export: invalid chat header format")
		print("Error: Cannot export - invalid chat header format")
		return
	end

	-- Extract Jekyll front matter data from Parley header
	local title = "Untitled"
	local post_date = os.date("%Y-%m-%d")
	local tags = "unclassified"
	local markdown_filename

	-- Extract title from parsed headers
	if headers and headers.topic and headers.topic ~= "" then
		title = headers.topic
	end

	-- Extract date from transcript header filename first, then fallback to current file
	local transcript_filename = headers and headers.file or nil

	-- Try to extract date from transcript header filename first
	if transcript_filename then
		local basename = transcript_filename:gsub("%.md$", ""):gsub("%.markdown$", "")
		local year, month, day = basename:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
		if year and month and day then
			post_date = year .. "-" .. month .. "-" .. day
		end
	end

	-- Fallback: extract date from current filename if not found in header
	if post_date == os.date("%Y-%m-%d") then
		local current_basename = vim.fn.fnamemodify(file_name, ":t:r")
		local year, month, day = current_basename:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
		if year and month and day then
			post_date = year .. "-" .. month .. "-" .. day
		end
	end

	-- Extract tags from parsed headers
	if headers and headers.tags then
		if type(headers.tags) == "table" then
			if #headers.tags > 0 then
				tags = table.concat(headers.tags, ", ")
			end
		elseif type(headers.tags) == "string" and headers.tags ~= "" then
			tags = headers.tags
		end
	end

	-- Clean title for filename (remove invalid characters and normalize)
	markdown_filename = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
	if #markdown_filename > 50 then
		markdown_filename = markdown_filename:sub(1, 50)
	end

	-- Create Jekyll front matter
	local jekyll_header = [[---
layout: post
title:  "]] .. title .. [["
date:   ]] .. post_date .. [[

tags: ]] .. tags .. [[

comments: true
---

]]

	-- Process content: replace 💬: with ## and remove Parley header
	local body_lines = {}
	for i = header_end + 1, #lines do
		table.insert(body_lines, lines[i])
	end
	local content = table.concat(body_lines, "\n")

	-- Replace 💬: with ## (the main transformation for Jekyll)
	content = content:gsub("💬:", "#### 💬:")

	-- Add watermark after Jekyll header
	local watermark = "This transcript is generated by [parley.nvim](https://github.com/xianxu/parley.nvim).\n\n"

	-- Combine Jekyll header with watermark and processed content
	content = jekyll_header .. watermark .. content

	-- Use extracted date for Jekyll filename prefix
	local output_file = post_date .. "-" .. markdown_filename .. ".markdown"

	-- Export directory (configurable, with CLI override)
	local export_dir = params and params.args and params.args ~= "" and params.args or M.config.export_markdown_dir
	local full_output_path = export_dir .. "/" .. output_file

	-- Write Markdown file
	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		M.logger.error("Failed to create output file: " .. full_output_path)
		print("Error: Failed to create output file: " .. full_output_path)
		return
	end

	file_handle:write(content)
	file_handle:close()

	M.logger.info("Exported chat to Markdown: " .. full_output_path)
	print("✅ Exported chat to: " .. full_output_path)
end

--------------------------------------------------------------------------------
-- Chat logic
--------------------------------------------------------------------------------

---@param buf number | nil # buffer number
M.prep_md = function(buf)
	-- disable swapping for this buffer and set filetype to markdown
	vim.api.nvim_command("setlocal noswapfile")
	-- better text wrapping
	vim.api.nvim_command("setlocal wrap linebreak")
	-- auto save on TextChanged, InsertLeave (debounced to avoid disk thrashing on large files)
	local save_timer = nil
	local SAVE_DEBOUNCE_MS = 1000
	vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
		buffer = buf,
		callback = function()
			if save_timer then
				stop_and_close_timer(save_timer)
			end
			local timer = vim.uv.new_timer()
			save_timer = timer
			timer:start(
				SAVE_DEBOUNCE_MS,
				0,
				vim.schedule_wrap(function()
					stop_and_close_timer(timer)
					if save_timer ~= timer then
						return
					end
					save_timer = nil
					if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
						vim.api.nvim_buf_call(buf, function()
							vim.cmd("silent! write")
						end)
					end
				end)
			)
		end,
	})

	-- register shortcuts local to this buffer
	buf = buf or vim.api.nvim_get_current_buf()

	-- ensure normal mode
	vim.api.nvim_command("stopinsert")
	M.helpers.feedkeys("<esc>", "xn")
end

--- Checks if a file should be considered a chat transcript, it enforces that a file needs to be in one configured chat root
--- and have a valid header portion.
---@param buf number # buffer number
---@param file_name string # file name
---@return string | nil # reason for not being a chat or nil if it is a chat
M.not_chat = function(buf, file_name)
	local chat_dir, resolved_file = find_chat_root(file_name)
	if not chat_dir then
		return "resolved file (" .. resolved_file .. ") not in configured chat roots (" .. table.concat(M.get_chat_dirs(), ", ") .. ")"
	end

	-- Check for timestamp format in filename
	local basename = vim.fn.fnamemodify(resolved_file, ":t")
	if not basename:match("^%d%d%d%d%-%d%d%-%d%d") then
		return "file does not have timestamp format"
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines < 5 then
		return "file too short"
	end

	local headers, header_end = parse_chat_headers(lines)
	if not header_end then
		return "missing header separator"
	end

	if not headers or not headers.topic or headers.topic == "" then
		return "missing topic header"
	end

	if not headers.file or headers.file == "" then
		return "missing file header"
	end

	return nil
end

M.display_agent = function(buf, file_name)
	if M.not_chat(buf, file_name) then
		return
	end

	if buf ~= vim.api.nvim_get_current_buf() then
		return
	end

	local ns_id = vim.api.nvim_create_namespace("ParleyChatExt_" .. file_name)
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local agent = M._state.agent
	local ag_conf = M.agents[agent]
	local display_name = M.agent_display_name_with_web_search(agent, ag_conf)
	vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
		strict = false,
		right_gravity = true,
		virt_text_pos = "right_align",
		virt_text = {
			{ "[" .. display_name .. "]", "DiagnosticHint" },
		},
		hl_mode = "combine",
	})
end

--- Build display label for an agent, including web_search indicator suffix.
---@param agent_name string
---@param ag_conf table|nil
---@return string
M.agent_display_name_with_web_search = function(agent_name, ag_conf)
	local display_name = agent_name
	if not M._state.web_search then
		return display_name
	end

	local prov = require("parley.providers")
	local model_conf = ag_conf and ag_conf.model or nil
	local supported = ag_conf and prov.has_feature(ag_conf.provider, "web_search", model_conf)
	local resolved_provider = ag_conf and prov.resolve_name(ag_conf.provider) or nil
	local requires_search_model = false
	if resolved_provider == "openai" then
		requires_search_model = true
	elseif resolved_provider == "cliproxyapi" then
		local strategy = prov.get_web_search_strategy(ag_conf.provider, model_conf) or "none"
		requires_search_model = strategy == "openai_search_model"
	end

	if supported and requires_search_model then
		if type(model_conf) == "table" and not model_conf.search_model then
			supported = false
		end
	end

	return display_name .. (supported and "[w]" or "[w?]")
end

M._prepared_bufs = {}
M.prep_chat = function(buf, file_name)
	if M.not_chat(buf, file_name) then
		return
	end

	if buf ~= vim.api.nvim_get_current_buf() then
		return
	end

	M.refresh_state({ last_chat = file_name })
	if M._prepared_bufs[buf] then
		-- 	M.logger.debug("buffer already prepared: " .. buf)
		return
	end
	M._prepared_bufs[buf] = true

	M.prep_md(buf)

	if M.config.chat_prompt_buf_type then
		vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })
		vim.fn.prompt_setprompt(buf, "")
		vim.fn.prompt_setcallback(buf, function()
			M.cmd.ChatRespond({ args = "" })
		end)
	end

	-- setup chat specific commands
	local range_commands = {
		{
			command = "ChatRespond",
			modes = M.config.chat_shortcut_respond.modes,
			shortcut = M.config.chat_shortcut_respond.shortcut,
			comment = "Parley prompt Chat Respond",
		},
		{
			command = "ChatRespondAll",
			modes = M.config.chat_shortcut_respond_all.modes,
			shortcut = M.config.chat_shortcut_respond_all.shortcut,
			comment = "Parley prompt Chat Respond All",
		},
	}

	for _, rc in ipairs(range_commands) do
		local cmd = M.config.cmd_prefix .. rc.command .. "<cr>"
		for _, mode in ipairs(rc.modes) do
			if mode == "n" or mode == "i" then
				M.helpers.set_keymap({ buf }, mode, rc.shortcut, function()
					vim.api.nvim_command(M.config.cmd_prefix .. rc.command)
					-- go to normal mode
					vim.api.nvim_command("stopinsert")
					M.helpers.feedkeys("<esc>", "xn")
				end, rc.comment)
			else
				M.helpers.set_keymap({ buf }, mode, rc.shortcut, ":<C-u>'<,'>" .. cmd, rc.comment)
			end
		end
	end

	local ds = M.config.chat_shortcut_delete
	M.helpers.set_keymap({ buf }, ds.modes, ds.shortcut, M.cmd.ChatDelete, "Parley prompt Chat Delete")

	local ss = M.config.chat_shortcut_stop
	M.helpers.set_keymap({ buf }, ss.modes, ss.shortcut, M.cmd.Stop, "Parley prompt Chat Stop")

	-- Note: ChatFinder is now handled by global shortcuts

	local as = M.config.chat_shortcut_agent
	M.helpers.set_keymap({ buf }, as.modes, as.shortcut, M.cmd.NextAgent, "Parley prompt Next Agent")

	local sps = M.config.chat_shortcut_system_prompt
	M.helpers.set_keymap({ buf }, sps.modes, sps.shortcut, M.cmd.NextSystemPrompt, "Parley prompt System Prompt Selector")

	local fcs = M.config.chat_shortcut_follow_cursor
	if fcs then
		M.helpers.set_keymap({ buf }, fcs.modes, fcs.shortcut, M.cmd.ToggleFollowCursor, "Parley prompt Toggle Follow Cursor")
	end

	local search_shortcut = M.config.chat_shortcut_search
	if search_shortcut then
		-- Create a function for searching chat sections (questions only)
		local function search_chat_sections()
			local user_prefix = M.config.chat_user_prefix
			vim.cmd("/^" .. vim.pesc(user_prefix))
		end

		for _, mode in ipairs(search_shortcut.modes) do
			M.helpers.set_keymap({ buf }, mode, search_shortcut.shortcut, search_chat_sections, "Parley prompt Search Chat Sections")
		end
	end

	-- Set outline navigation keybinding
	M.helpers.set_keymap({ buf }, "n", "<C-g>t", M.cmd.Outline, "Parley prompt Outline Navigator")

	-- Set file opening keybinding
	local of = M.config.chat_shortcut_open_file
	if of then
		for _, mode in ipairs(of.modes) do
			M.helpers.set_keymap({ buf }, mode, of.shortcut, M.cmd.OpenFileUnderCursor, "Parley open file under cursor")
		end
	end

	-- conceal parameters in model header so it's not distracting
	if M.config.chat_conceal_model_params then
		vim.opt_local.conceallevel = 2
		vim.opt_local.concealcursor = ""
		vim.fn.matchadd("Conceal", [[^- model: .*model.:.[^"]*\zs".*\ze]], 10, -1, { conceal = "…" })
		vim.fn.matchadd("Conceal", [[^- model: \zs.*model.:.\ze.*]], 10, -1, { conceal = "…" })
		vim.fn.matchadd("Conceal", [[^- system_prompt: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
		vim.fn.matchadd("Conceal", [[^- system_prompt: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
		-- Backward compatibility for old headers.
		vim.fn.matchadd("Conceal", [[^- role: .\{64,64\}\zs.*\ze]], 10, -1, { conceal = "…" })
		vim.fn.matchadd("Conceal", [[^- role: .[^\\]*\zs\\.*\ze]], 10, -1, { conceal = "…" })
	end
end

-- Check if a file is a non-chat markdown file
M.is_markdown = function(buf, file_name)
	-- Skip if not a valid buffer
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end

	-- Skip if it's a chat file (already handled by chat logic)
	if M.not_chat(buf, file_name) == nil then
		return false
	end

	-- Check if the file has a markdown extension (.md or .markdown)
	if file_name:match("%.md$") or file_name:match("%.markdown$") then
		return true
	end

	-- Check if the filetype is markdown
	local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
	if filetype == "markdown" then
		return true
	end

	return false
end

-- Helper function to extract chat topic from file
M.get_chat_topic = function(file_path)
	if vim.fn.filereadable(file_path) == 0 then
		if M._chat_topic_cache then
			M._chat_topic_cache[file_path] = nil
		end
		return nil
	end

	M._chat_topic_cache = M._chat_topic_cache or {}
	local uv = vim.uv or vim.loop
	local stat = uv and uv.fs_stat and uv.fs_stat(file_path) or nil
	local cache_entry = M._chat_topic_cache[file_path]
	local stat_mtime = stat and stat.mtime or nil

	if cache_entry and stat_mtime then
		local cache_sec = cache_entry.mtime and cache_entry.mtime.sec or 0
		local cache_nsec = cache_entry.mtime and cache_entry.mtime.nsec or 0
		local stat_sec = stat_mtime.sec or 0
		local stat_nsec = stat_mtime.nsec or 0
		if cache_sec == stat_sec and cache_nsec == stat_nsec then
			return cache_entry.topic
		end
	end

	local lines = vim.fn.readfile(file_path, "", 20)
	local headers = parse_chat_headers(lines)
	local topic = headers and headers.topic or nil

	M._chat_topic_cache[file_path] = {
		mtime = stat_mtime or { sec = 0, nsec = 0 },
		topic = topic,
	}

	return topic
end

-- Define namespace and highlighting colors for questions, annotations, and thinking
M.setup_highlight = function()
	-- Set up namespace
	local ns = vim.api.nvim_create_namespace("parley_question")

	-- Create theme-agnostic highlight groups that work in both light and dark themes
	-- Check for user-defined highlight settings
	local user_highlights = M.config.highlight or {}

	-- Questions - Create a highlight that stands out but works in both themes
	-- Link to existing highlights when possible for theme compatibility
	if user_highlights.question then
		-- Use user-defined highlighting if provided
		vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
	else
		vim.api.nvim_set_hl(0, "ParleyQuestion", {
			link = "Keyword", -- Keyword is usually a standout color in most themes
		})
	end

	-- File references - Should stand out similar to questions but with special emphasis
	if user_highlights.file_reference then
		vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
	else
		vim.api.nvim_set_hl(0, "ParleyFileReference", {
			link = "WarningMsg", -- Use built-in warning colors which work across themes
		})
	end

	-- Thinking/reasoning - Should be dimmed but visible in both themes
	if user_highlights.thinking then
		vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
	else
		vim.api.nvim_set_hl(0, "ParleyThinking", {
			link = "Comment", -- Comments are usually appropriately dimmed in all themes
		})
	end

	-- Annotations - Use existing highlight groups that work across themes
	if user_highlights.annotation then
		vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
	else
		vim.api.nvim_set_hl(0, "ParleyAnnotation", {
			link = "DiffAdd", -- Usually a green background with appropriate text color
		})
	end

	-- Tags - Highlighted tags in @@tag@@ format
	if user_highlights.tag then
		vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
	else
		vim.api.nvim_set_hl(0, "ParleyTag", {
			link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
		})
	end

	-- Picker typo-tolerance edits - distinct from exact Search highlights
	if user_highlights.approximate_match then
		vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
	else
		vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
			link = "IncSearch",
		})
	end

	-- Interview timestamps - Highlighted timestamp lines like :15min
	-- Use only background color to allow search highlights to show through
	local diffadd_hl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
	vim.api.nvim_set_hl(0, "InterviewTimestamp", {
		bg = diffadd_hl.bg or diffadd_hl.background,
		-- Explicitly don't set fg to allow other highlights to show through
	})

	return ns
end

local HIGHLIGHT_VIEWPORT_MARGIN = 20
local HIGHLIGHT_CONTEXT_LINES = 200

local function get_chat_highlight_prefix_patterns()
	local user_prefix = M.config.chat_user_prefix
	local local_prefix = M.config.chat_local_prefix
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	local reasoning_prefix = memory_enabled and M.config.chat_memory.reasoning_prefix or "🧠:"
	local summary_prefix = memory_enabled and M.config.chat_memory.summary_prefix or "📝:"

	local assistant_prefix
	if type(M.config.chat_assistant_prefix) == "string" then
		assistant_prefix = M.config.chat_assistant_prefix
	elseif type(M.config.chat_assistant_prefix) == "table" then
		assistant_prefix = M.config.chat_assistant_prefix[1]
	end

	return {
		reasoning_pattern = "^" .. vim.pesc(reasoning_prefix),
		summary_pattern = "^" .. vim.pesc(summary_prefix),
		user_pattern = "^" .. vim.pesc(user_prefix),
		assistant_pattern = "^" .. vim.pesc(assistant_prefix),
		local_pattern = "^" .. vim.pesc(local_prefix),
	}
end

local function bootstrap_chat_highlight_state(buf, start_line, patterns)
	if start_line <= 1 then
		return false, false
	end

	local scan_start = math.max(1, start_line - HIGHLIGHT_CONTEXT_LINES)
	local bootstrap_start = scan_start
	local bootstrap_in_block = false

	while bootstrap_start > 1 do
		local previous_lines = vim.api.nvim_buf_get_lines(buf, bootstrap_start - 2, bootstrap_start - 1, false)
		local previous_line = previous_lines[1] or ""
		if previous_line:match(patterns.user_pattern) then
			bootstrap_in_block = true
			break
		end
		if previous_line:match(patterns.assistant_pattern) or previous_line:match(patterns.local_pattern) then
			bootstrap_in_block = false
			break
		end
		bootstrap_start = bootstrap_start - 1
	end

	local in_block = bootstrap_in_block
	local in_code_block = false
	if start_line <= bootstrap_start then
		return in_block, in_code_block
	end

	local prefix_lines = vim.api.nvim_buf_get_lines(buf, bootstrap_start - 1, start_line - 1, false)
	for _, line in ipairs(prefix_lines) do
		if line:match("^%s*```") then
			in_code_block = not in_code_block
		end

		if line:match(patterns.user_pattern) then
			in_block = true
		elseif line:match(patterns.assistant_pattern) or line:match(patterns.local_pattern) then
			in_block = false
		end
	end

	return in_block, in_code_block
end

local function merge_line_ranges(ranges)
	if #ranges <= 1 then
		return ranges
	end

	table.sort(ranges, function(a, b)
		return a.start_line < b.start_line
	end)

	local merged = {}
	for _, range in ipairs(ranges) do
		local last = merged[#merged]
		if not last or range.start_line > (last.end_line + 1) then
			table.insert(merged, { start_line = range.start_line, end_line = range.end_line })
		else
			last.end_line = math.max(last.end_line, range.end_line)
		end
	end

	return merged
end

local function get_visible_line_ranges(buf, margin)
	margin = margin or HIGHLIGHT_VIEWPORT_MARGIN
	local line_count = vim.api.nvim_buf_line_count(buf)
	local ranges = {}

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_buf(win) == buf then
			local ok, bounds = pcall(vim.api.nvim_win_call, win, function()
				return { top = vim.fn.line("w0"), bottom = vim.fn.line("w$") }
			end)
			if ok and bounds then
				local start_line = math.max(1, (bounds.top or 1) - margin)
				local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
				if start_line <= end_line then
					table.insert(ranges, { start_line = start_line, end_line = end_line })
				end
			end
		end
	end

	if #ranges == 0 and line_count > 0 then
		table.insert(ranges, { start_line = 1, end_line = line_count })
	end

	return merge_line_ranges(ranges)
end

-- Refresh topic labels for chat references in non-chat markdown files.
-- Highlighting is handled by the decoration provider; this only does topic updates.
M.highlight_markdown_chat_refs = function(buf)
	local ranges = get_visible_line_ranges(buf)
	local has_chat_refs = false

	for _, range in ipairs(ranges) do
		local lines = vim.api.nvim_buf_get_lines(buf, range.start_line - 1, range.end_line, false)
		for _, line in ipairs(lines) do
			if line:match("^@@%s*[^+]") or line:match("^@@/") then
				has_chat_refs = true
				break
			end
		end
		if has_chat_refs then break end
	end

	-- Defer topic updates so editing stays fast in large markdown files.
	M._markdown_topic_timers = M._markdown_topic_timers or {}
	local existing_timer = M._markdown_topic_timers[buf]
	if existing_timer then
		stop_and_close_timer(existing_timer)
		M._markdown_topic_timers[buf] = nil
	end

	if not has_chat_refs then
		return
	end

	local TOPIC_REFRESH_DEBOUNCE_MS = 500
	local timer = vim.uv.new_timer()
	M._markdown_topic_timers[buf] = timer
	timer:start(
		TOPIC_REFRESH_DEBOUNCE_MS,
		0,
		vim.schedule_wrap(function()
			stop_and_close_timer(timer)
			if M._markdown_topic_timers[buf] ~= timer then
				return
			end
			M._markdown_topic_timers[buf] = nil
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end

			local refresh_ranges = get_visible_line_ranges(buf)
			for _, range in ipairs(refresh_ranges) do
				local latest_lines = vim.api.nvim_buf_get_lines(buf, range.start_line - 1, range.end_line, false)
				for offset, line in ipairs(latest_lines) do
					local line_nr = range.start_line + offset - 1
					-- Refresh topic only for @@ file references.
					if line:match("^@@%s*[^+]") or line:match("^@@/") then
						local chat_path = line:match("^@@%s*([^:]+)")
						if chat_path then
							local trimmed_path = chat_path:gsub("^%s*(.-)%s*$", "%1")
							local expanded_path = vim.fn.expand(trimmed_path)
							if vim.fn.filereadable(expanded_path) == 1 then
								local topic = M.get_chat_topic(expanded_path)
								if topic then
									local current_topic = line:match("^@@%s*[^:]+:%s*(.+)$")
									if not current_topic or current_topic ~= topic then
										vim.api.nvim_buf_set_lines(buf, line_nr - 1, line_nr, false, {
											"@@" .. trimmed_path .. ": " .. topic,
										})
										M.logger.debug("Updated chat reference topic for " .. trimmed_path .. " to: " .. topic)
									end
								end
							end
						end
					end
				end
			end
		end)
	)
end

-- Compute desired chat highlights for a 1-indexed line range.
-- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
-- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
local function compute_chat_highlights(buf, start_line, end_line)
	local result = {}
	local patterns = get_chat_highlight_prefix_patterns()
	local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
	local in_block, in_code_block = bootstrap_chat_highlight_state(buf, start_line, patterns)

	for offset, line in ipairs(lines) do
		local line_nr = start_line + offset - 1
		if line:match("^%s*```") then
			in_code_block = not in_code_block
		end

		local highlighted_regions = {}
		local row = line_nr - 1

		result[row] = result[row] or {}

		local pos = 1
		while true do
			local tag_start, content_start = line:find("@@", pos)
			if not tag_start then break end
			local content_end, tag_end = line:find("@@", content_start + 1)
			if not content_end then break end
			table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
			table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
			pos = tag_end + 1
		end

		if line:match(patterns.reasoning_pattern) or line:match(patterns.summary_pattern) then
			table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
		elseif line:match(patterns.user_pattern) then
			table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
			in_block = true
		elseif line:match(patterns.assistant_pattern) then
			in_block = false
		elseif line:match(patterns.local_pattern) then
			in_block = false
		elseif in_block and not in_code_block then
			table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
			if line:match("^@@") then
				local is_tag_at_start = false
				if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
					is_tag_at_start = true
				end
				if not is_tag_at_start then
					table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
				end
			end
		end

		for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
			table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
		end
	end

	return result
end

-- Compute desired markdown highlights for a 1-indexed line range.
-- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
local function compute_markdown_highlights(buf, start_line, end_line)
	local result = {}
	local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
	for offset, line in ipairs(lines) do
		local row = start_line + offset - 2
		if line:match("^@@%s*[^+]") or line:match("^@@/") then
			result[row] = result[row] or {}
			table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
		end
	end
	return result
end

-- Buffers tracked for decoration provider: { [bufnr] = "chat" | "markdown" }
M._parley_bufs = {}

-- Apply highlighting to chat blocks in the current buffer.
-- Simple clear-and-apply; used by tests on scratch buffers.
-- Production highlighting is handled by the decoration provider.
M.highlight_question_block = function(buf)
	local ns = M.setup_highlight()
	local ranges = get_visible_line_ranges(buf)

	for _, range in ipairs(ranges) do
		vim.api.nvim_buf_clear_namespace(buf, ns, range.start_line - 1, range.end_line)
	end

	for _, range in ipairs(ranges) do
		local row_map = compute_chat_highlights(buf, range.start_line, range.end_line)
		for row, hls in pairs(row_map) do
			for _, hl in ipairs(hls) do
				vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, row, hl.col_start, hl.col_end)
			end
		end
	end
end

M.setup_markdown_keymaps = function(buf)
	-- Add <C-g>o keybinding to open chat file references
	local of = M.config.chat_shortcut_open_file
	if of then
		for _, mode in ipairs(of.modes) do
			M.helpers.set_keymap(
				{ buf },
				mode,
				of.shortcut,
				M.cmd.OpenFileUnderCursor,
				"Parley open chat reference under cursor"
			)
		end
	end

	-- Add <C-g>f keybinding to FIND chat references
	M.helpers.set_keymap({ buf }, "n", "<C-g>f", function()
		-- Remember source window for returning after selection
		M._chat_finder.insert_mode = false
		M._chat_finder.source_win = nil
		M._chat_finder.source_win = vim.api.nvim_get_current_win()

		M.logger.debug("FIND MODE: Passing window: " .. M._chat_finder.source_win)
		M.cmd.ChatFinder()
	end, "Parley find chat")

	-- Add <C-g>a keybinding to ADD chat references via ChatFinder (NORMAL MODE)
	M.helpers.set_keymap({ buf }, "n", "<C-g>a", function()
		-- Remember cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(0)

		-- Set chat finder in insert mode and store cursor position
		M._chat_finder.insert_mode = true
		M._chat_finder.insert_buf = buf
		M._chat_finder.insert_line = cursor_pos[1]
		M._chat_finder.insert_normal_mode = true

		-- IMPORTANT: Clear and set source window immediately before opening
		M._chat_finder.source_win = nil
		M._chat_finder.source_win = vim.api.nvim_get_current_win()
		M.logger.debug("NORMAL MODE ADD: Passing window: " .. M._chat_finder.source_win)
		M.cmd.ChatFinder()
	end, "Parley add chat reference")

		-- Add <C-g>a keybinding to ADD chat references via ChatFinder (INSERT MODE)
		M.helpers.set_keymap({ buf }, "i", "<C-g>a", function()
			-- Remember cursor position
			local cursor_pos = vim.api.nvim_win_get_cursor(0)

			-- Store position for later insertion
		M._chat_finder.insert_mode = true
		M._chat_finder.insert_buf = buf
		M._chat_finder.insert_line = cursor_pos[1]
		M._chat_finder.insert_col = cursor_pos[2]
		M._chat_finder.insert_normal_mode = false

		-- IMPORTANT: Clear and set source window immediately before opening
		M._chat_finder.source_win = nil
		M._chat_finder.source_win = vim.api.nvim_get_current_win()
		M.logger.debug("INSERT MODE ADD: Passing window: " .. M._chat_finder.source_win)

		-- Exit insert mode before opening chat finder
		vim.cmd("stopinsert")
		M.cmd.ChatFinder()
	end, "Parley add chat reference")

	-- Add <C-g>n keybinding to create and insert new chat
	-- Normal mode implementation
	M.helpers.set_keymap({ buf }, "n", "<C-g>n", function()
		-- Get the current cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(0)

		-- Create a new chat file path (timestamp format only)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":~:.")

		-- Insert the chat reference at the cursor position
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1] - 1, cursor_pos[1] - 1, false, {
			"@@" .. rel_path .. ": New chat",
		})

		M.logger.info("Created reference to new chat: " .. rel_path)
	end, "Parley create and insert new chat")

	-- Insert mode implementation
	M.helpers.set_keymap({ buf }, "i", "<C-g>n", function()
		-- Get the current cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local current_line = vim.api.nvim_get_current_line()

		-- Create a new chat file path (timestamp format only)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":~:.")

		-- Insert the chat reference at the current cursor position
		local col = cursor_pos[2]
		local new_line = current_line:sub(1, col) .. "@@" .. rel_path .. ": New chat" .. current_line:sub(col + 1)
		vim.api.nvim_set_current_line(new_line)

		-- Return to insert mode at the end of the inserted reference
		vim.api.nvim_win_set_cursor(0, { cursor_pos[1], col + #("@@" .. rel_path .. ": New chat") })

		-- Make sure we stay in insert mode
		vim.schedule(function()
			vim.cmd("startinsert")
		end)

		M.logger.info("Created reference to new chat: " .. rel_path)
	end, "Parley create and insert new chat")
end

M.setup_buf_handler = function()
	local gid = M.helpers.create_augroup("ParleyBufHandler", { clear = true })

	-- Register decoration provider: highlights are computed synchronously
	-- during Neovim's redraw cycle using ephemeral extmarks, just like
	-- built-in syntax highlighting. Zero flicker, always up-to-date.
	local decor_ns = M.setup_highlight()
	local _decor_cache = {} -- winid → { bufnr = number, rows = { [row] = { ... } } }

	vim.api.nvim_set_decoration_provider(decor_ns, {
		on_buf = function(_, bufnr, _)
			if not M._parley_bufs[bufnr] then
				return false
			end
		end,
		on_win = function(_, winid, bufnr, toprow, botrow)
			if not M._parley_bufs[bufnr] then
				return false
			end
			local buf_type = M._parley_bufs[bufnr]
			local start_line = toprow + 1
			local line_count = vim.api.nvim_buf_line_count(bufnr)
			local end_line = math.min(botrow + 1 + HIGHLIGHT_VIEWPORT_MARGIN, line_count)
			local row_map = nil

			if buf_type == "chat" then
				row_map = compute_chat_highlights(bufnr, start_line, end_line)
			elseif buf_type == "markdown" then
				row_map = compute_markdown_highlights(bufnr, start_line, end_line)
			end

			_decor_cache[winid] = {
				bufnr = bufnr,
				rows = row_map or {},
			}
		end,
		on_line = function(_, winid, bufnr, row)
			local cache = _decor_cache[winid]
			if not cache or cache.bufnr ~= bufnr then return end
			local highlights = cache.rows[row]
			if not highlights then return end
			for _, hl in ipairs(highlights) do
				local end_col = hl.col_end
				if end_col == -1 then
					local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
					end_col = lines[1] and #lines[1] or 0
				end
				pcall(vim.api.nvim_buf_set_extmark, bufnr, decor_ns, row, hl.col_start, {
					end_row = row,
					end_col = end_col,
					hl_group = hl.hl_group,
					ephemeral = true,
					priority = 100,
				})
			end
		end,
	})

	-- Setup functions that only need to run when buffer is first loaded or entered
	M.helpers.autocmd({ "BufEnter" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		-- Handle chat files
		if M.not_chat(buf, file_name) == nil then
			M._parley_bufs[buf] = "chat"
			M.prep_chat(buf, file_name)
			M.display_agent(buf, file_name)
			M.highlight_interview_timestamps(buf)
		-- Handle non-chat markdown files
		elseif M.is_markdown(buf, file_name) then
			M._parley_bufs[buf] = "markdown"
			M.prep_md(buf)
			M.setup_markdown_keymaps(buf)
			M.highlight_markdown_chat_refs(buf)
			M.highlight_interview_timestamps(buf)
		end
	end, gid)

	M.helpers.autocmd({ "WinEnter" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		-- Handle chat files
		if M.not_chat(buf, file_name) == nil then
			M.display_agent(buf, file_name)
			M.highlight_interview_timestamps(buf)
		-- Handle non-chat markdown files
		elseif M.is_markdown(buf, file_name) then
			M.highlight_interview_timestamps(buf)
		end
	end, gid)

	-- Clean up when buffers are deleted
	M.helpers.autocmd({ "BufDelete", "BufUnload" }, nil, function(event)
		local buf = event.buf
		M._parley_bufs[buf] = nil
		for winid, cache in pairs(_decor_cache) do
			if cache.bufnr == buf then
				_decor_cache[winid] = nil
			end
		end
		local match_id_key = "parley_interview_timestamps_" .. buf
		if M._interview_match_ids and M._interview_match_ids[match_id_key] then
			M._interview_match_ids[match_id_key] = nil
		end
		if M._markdown_topic_timers and M._markdown_topic_timers[buf] then
			stop_and_close_timer(M._markdown_topic_timers[buf])
			M._markdown_topic_timers[buf] = nil
		end
	end, gid)
end

---@param file_name string
---@param from_chat_finder boolean | nil # whether this is called from ChatFinder
---@return number # buffer number
M.open_buf = function(file_name, from_chat_finder)
	-- Track file access when opening a file
	local file_tracker = require("parley.file_tracker")
	file_tracker.track_file_access(file_name)

	-- Is the file already open in a buffer?
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(b) == file_name then
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_get_buf(w) == b then
					vim.api.nvim_set_current_win(w)
					return b
				end
			end
		end
	end

	-- Get all windows in the current tab
	local tab_wins = vim.api.nvim_tabpage_list_wins(0)

	-- If we have exactly two splits AND we're not from ChatFinder, open in the other split
	if #tab_wins == 2 and not from_chat_finder then
		local current_win = vim.api.nvim_get_current_win()
		local other_win

		-- Find the other window that's not the current one
		for _, win in ipairs(tab_wins) do
			if win ~= current_win then
				other_win = win
				break
			end
		end

		-- Switch to the other window and open the file
		if other_win then
			M.logger.debug("Opening file in other split: " .. file_name)
			vim.api.nvim_set_current_win(other_win)
			vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_name))
			local buf = vim.api.nvim_get_current_buf()
			return buf
		end
	end

	-- If from ChatFinder or not using the other split, just open in current window
	local open_mode = from_chat_finder and "Opening file in current window (from ChatFinder)"
		or "Opening file in current window"
	M.logger.debug(open_mode .. ": " .. file_name)
	vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_name))
	local buf = vim.api.nvim_get_current_buf()
	return buf
end

local function registered_chat_dir(dir)
	local resolved = resolve_dir_key(dir)
	for _, root in ipairs(M.get_chat_roots()) do
		if resolve_dir_key(root.dir) == resolved then
			return resolved
		end
	end
	return nil
end

local function chat_root_display(root, include_dir)
	local prefix = root.is_primary and "* primary" or "  extra  "
	local display = string.format("%s [%s]", prefix, root.label)
	if include_dir then
		display = string.format("%s %s", display, root.dir)
	end
	return display
end

local function sync_moved_chat_buffers(old_path, new_path)
	local resolved_old = resolve_dir_key(old_path)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and resolve_dir_key(vim.api.nvim_buf_get_name(buf)) == resolved_old then
			if vim.bo[buf].modified then
				vim.api.nvim_buf_call(buf, function()
					vim.cmd("silent! write")
				end)
			end
			if new_path and new_path ~= "" and resolve_dir_key(new_path) ~= resolved_old then
				vim.api.nvim_buf_set_name(buf, new_path)
			end
		end
	end
end

M.move_chat = function(file_name, target_dir)
	local current_root, resolved_file = find_chat_root(file_name)
	if not current_root then
		return nil, "file is not in configured chat roots: " .. file_name
	end

	local target_root = registered_chat_dir(target_dir)
	if not target_root then
		return nil, "target is not a registered chat directory: " .. target_dir
	end

	if resolve_dir_key(current_root) == resolve_dir_key(target_root) then
		return nil, "chat is already in that directory"
	end

	local basename = vim.fn.fnamemodify(resolved_file, ":t")
	local target_file = target_root .. "/" .. basename
	if vim.fn.filereadable(target_file) == 1 then
		return nil, "target chat already exists: " .. target_file
	end

	sync_moved_chat_buffers(resolved_file, nil)

	local ok, err = os.rename(resolved_file, target_file)
	if not ok then
		return nil, "failed to move chat: " .. tostring(err)
	end

	sync_moved_chat_buffers(resolved_file, target_file)

	if M._state.last_chat and resolve_dir_key(M._state.last_chat) == resolved_file then
		M.refresh_state({ last_chat = target_file })
	end

	require("parley.file_tracker").track_file_access(target_file)
	return target_file
end

M.prompt_chat_move = function(file_name, on_complete, on_cancel)
	local current_root, resolved_file = find_chat_root_record(file_name)
	if not current_root then
		local err = "file is not in configured chat roots: " .. file_name
		vim.notify(err, vim.log.levels.WARN)
		if on_cancel then
			on_cancel()
		end
		return
	end

	local items = {}
	for _, root in ipairs(M.get_chat_roots()) do
		if resolve_dir_key(root.dir) ~= resolve_dir_key(current_root.dir) then
			table.insert(items, {
				display = chat_root_display(root, true),
				value = root.dir,
			})
		end
	end

	if #items == 0 then
		vim.notify("No alternate chat directories are registered", vim.log.levels.WARN)
		if on_cancel then
			on_cancel()
		end
		return
	end

	M.float_picker.open({
		title = "Move Chat To",
		items = items,
		anchor = "top",
		on_select = function(item)
			local new_file, err = M.move_chat(resolved_file, item.value)
			if not new_file then
				vim.notify("Failed to move chat: " .. err, vim.log.levels.WARN)
				if on_cancel then
					on_cancel()
				end
				return
			end

			M.logger.info("Moved chat to: " .. new_file)
			vim.notify("Moved chat to: " .. new_file, vim.log.levels.INFO)
			if on_complete then
				on_complete(new_file, item.value)
			end
		end,
		on_cancel = function()
			if on_cancel then
				on_cancel()
			end
		end,
	})
end

---@param system_prompt string | nil # system prompt to use
---@param agent table | nil # obtained from get_agent
---@return number # buffer number
M.new_chat = function(system_prompt, agent, initial_question)
	local filename = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"

	-- encode as json if model is a table
	local model = ""
	local provider = ""
	if agent and agent.model and agent.provider then
		model = agent.model
		provider = agent.provider
		if type(model) == "table" then
			model = "model: " .. vim.json.encode(model) .. "\n"
		else
			model = "model: " .. model .. "\n"
		end

		provider = "provider: " .. provider:gsub("\n", "\\n") .. "\n"
	end

	-- display system prompt as single line with escaped newlines
	if system_prompt then
		system_prompt = "system_prompt: " .. system_prompt:gsub("\n", "\\n") .. "\n"
	else
		-- Use the selected system prompt from state
		local selected_system_prompt = M._state.system_prompt or "default"
		if M.system_prompts[selected_system_prompt] then
			system_prompt = "system_prompt: " .. M.system_prompts[selected_system_prompt].system_prompt:gsub("\n", "\\n") .. "\n"
		else
			system_prompt = ""
		end
	end

	local template = M.render.template(M.config.chat_template or require("parley.defaults").chat_template, {
		["{{filename}}"] = string.match(filename, "([^/]+)$"),
		["{{optional_headers}}"] = model .. provider .. system_prompt,
		["{{user_prefix}}"] = M.config.chat_user_prefix,
		["{{respond_shortcut}}"] = M.config.chat_shortcut_respond.shortcut,
		["{{cmd_prefix}}"] = M.config.cmd_prefix,
		["{{stop_shortcut}}"] = M.config.chat_shortcut_stop.shortcut,
		["{{delete_shortcut}}"] = M.config.chat_shortcut_delete.shortcut,
		["{{new_shortcut}}"] = M.config.global_shortcut_new.shortcut,
	})

	-- escape underscores (for markdown)
	template = template:gsub("_", "\\_")

	-- If an initial question is provided, append it after the user prefix
	-- (done after underscore escaping so file paths in @@references stay intact)
	if initial_question then
		template = template:gsub(
			M.config.chat_user_prefix .. "%s*$",
			M.config.chat_user_prefix .. " " .. initial_question
		)
	end

	-- strip leading and trailing newlines
	template = template:gsub("^%s*(.-)%s*$", "%1") .. "\n"

	-- create chat file
	vim.fn.writefile(vim.split(template, "\n"), filename)
	local buf = M.open_buf(filename)

	M.helpers.feedkeys("G", "xn")
	return buf
end

---@param params table
---@param system_prompt string | nil
---@param agent table | nil # obtained from get_agent
---@return number # buffer number
M.cmd.ChatNew = function(_params, system_prompt, agent)
	-- Simple version that just creates a new chat
	return M.new_chat(system_prompt, agent)
end

-- Create a new chat pre-populated with a review question for the current file
M.cmd.ChatReview = function(_params)
	local file_path = vim.api.nvim_buf_get_name(0)
	if file_path == "" then
		M.logger.warning("No file associated with current buffer")
		return
	end
	local question = "proof read the following file:\n\n@@" .. file_path
	return M.new_chat(nil, nil, question)
end

-- Function to create a new note
M.cmd.NoteNew = function()
	-- Prompt user for note subject
	vim.ui.input({ prompt = "Note subject: " }, function(subject)
		if subject and subject ~= "" then
			M.new_note(subject)
		end
	end)
end

-- Create default templates in the templates directory
M.create_default_templates = function(template_dir)
	-- Meeting Notes template
	local meeting_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

## Attendees
-
-

## Agenda
1.
2.

## Notes


## Action Items
- [ ]
- [ ]

## Next Steps

]]

	-- Daily Note template
	local daily_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

## Today's Goals
- [ ]
- [ ]
- [ ]

## Notes


## Tomorrow's Priorities
-
-

## Reflection

]]

	-- Interview template (for the interview mode feature)
	local interview_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

:00min Interview started

## Interview Notes


## Key Points


## Follow-up Actions
- [ ]
- [ ]

]]

	-- Basic template
	local basic_template = [[# {{title}}

**Date:** {{date}}
**Week:** {{week}}

]]

	-- Write template files
	vim.fn.writefile(vim.split(meeting_template, "\n"), template_dir .. "/meeting-notes.md")
	vim.fn.writefile(vim.split(daily_template, "\n"), template_dir .. "/daily-note.md")
	vim.fn.writefile(vim.split(interview_template, "\n"), template_dir .. "/interview.md")
	vim.fn.writefile(vim.split(basic_template, "\n"), template_dir .. "/basic.md")
end

-- Function to create a new note from template
M.cmd.NoteNewFromTemplate = function()
	local template_dir = M.config.notes_dir .. "/templates"

	-- Check if template directory exists, create it if not
	if vim.fn.isdirectory(template_dir) == 0 then
		vim.notify("Creating templates directory: " .. template_dir, vim.log.levels.INFO)
		M.logger.info("Creating templates directory: " .. template_dir)

		-- Create the templates directory
		vim.fn.mkdir(template_dir, "p")

		-- Create some default templates
		M.create_default_templates(template_dir)

		vim.notify("Templates directory created with default templates", vim.log.levels.INFO)
	end

	-- Get all template files
	local template_files = {}
	local handle = vim.loop.fs_scandir(template_dir)
	if handle then
		local name, type
		repeat
			name, type = vim.loop.fs_scandir_next(handle)
			if name and type == "file" and name:match("%.md$") then
				table.insert(template_files, {
					filename = name,
					path = template_dir .. "/" .. name,
					display = name:gsub("%.md$", ""),
				})
			end
		until not name
	end

	if #template_files == 0 then
		vim.notify("No template files found in: " .. template_dir, vim.log.levels.WARN)
		return
	end

	-- Use float picker to select template
	local items = {}
	for _, tfile in ipairs(template_files) do
		table.insert(items, { display = tfile.display, value = tfile })
	end

	M.float_picker.open({
		title = "Select Template",
		items = items,
		anchor = "top",
		on_select = function(item)
			-- Read template lines to preserve blank lines
			local template_lines = vim.fn.readfile(item.value.path)
			-- Prompt for note subject (command-line input)
			local subject = vim.fn.input("Note subject: ")
			-- Cancel if no title provided
			if not subject or subject == "" then
				return
			end
			M.new_note_from_template(subject, template_lines)
		end,
	})
end

-- Internal helper: create a note file with a title and metadata (array of {key, value})
M._create_note_file = function(filename, title, metadata, template_content)
	local lines = {}

	if template_content then
		-- Generate lines from template_content (string or table), preserving empty lines
		local tlines = {}
		if type(template_content) == "string" then
			-- Split string on newline, keep empty entries
			tlines = vim.split(template_content, "\n", true, false)
		elseif type(template_content) == "table" then
			tlines = template_content
		end
		-- Process each line: replace placeholders
		for _, raw in ipairs(tlines) do
			local ln = raw
			-- Replace title placeholder
			ln = ln:gsub("{{title}}", title)
			-- Replace metadata placeholders
			for _, kv in ipairs(metadata) do
				ln = ln:gsub("{{" .. kv[1]:lower() .. "}}", kv[2])
			end
			table.insert(lines, ln)
		end
	else
		-- Default note format
		table.insert(lines, "# " .. title)
		table.insert(lines, "")
		for _, kv in ipairs(metadata) do
			table.insert(lines, kv[1] .. ": " .. kv[2])
			table.insert(lines, "")
		end
	end

	vim.fn.writefile(lines, filename)
	local buf = M.open_buf(filename)
	vim.api.nvim_command("normal! G")
	vim.api.nvim_command("startinsert")
	return buf
end

-- Note finder state and helpers

-- Variable to store state for NoteFinder
-- Initial state for note finder, will be updated from persisted state
M._note_finder = {
	opened = false,
	source_win = nil,
	show_all = false,
	recency_index = nil,
	initial_index = nil,
	initial_value = nil,
	sticky_query = nil,
}

local function try_create_top_level_note(subject, current_date, template_content)
	if subject == "{}" or subject:match("^%{%}%s+") then
		return nil, "Bare {} is reserved for Note Finder filters and cannot be used during note creation"
	end

	local folder, rest = subject:match("^%{([^{}%s/]+)%}%s+(.+)$")

	if not folder or not rest then
		return nil, nil
	end
	if rest:match("^%b{}%s+") then
		return nil, "Only a single leading {dir} segment is supported during note creation"
	end

	local target_dir = M.config.notes_dir .. "/" .. folder
	M.helpers.prepare_dir(target_dir)
	local slug = rest:gsub("%s+", "-")
	local filename = target_dir .. "/" .. slug .. ".md"
	local y = string.format("%04d", current_date.year)
	local mon = string.format("%02d", current_date.month)
	local d = string.format("%02d", current_date.day)
	return M._create_note_file(
		filename,
		rest,
		{ { "Date", y .. "-" .. mon .. "-" .. d } },
		template_content
	)
end

-- Create a new note with given subject
M.new_note = function(subject)
	-- Get current date
	local current_date = os.date("*t")
	local year = current_date.year
	local month = current_date.month
	local day = current_date.day

	-- Parse date from subject if provided in one of the formats:
	-- "YYYY-MM-DD subject" or "MM-DD subject" or "DD subject"
	do
		local top_level_note, top_level_note_err = try_create_top_level_note(subject, current_date)
		if top_level_note_err then
			vim.notify(top_level_note_err, vim.log.levels.WARN)
			return nil
		end
		if top_level_note then
			return top_level_note
		end
	end
	local date_pattern1 = "^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(.+)$" -- YYYY-MM-DD
	local date_pattern2 = "^(%d%d)%-(%d%d)%s+(.+)$" -- MM-DD
	local date_pattern3 = "^(%d%d)%s+(.+)$" -- DD

	local parsed_year, parsed_month, parsed_day, parsed_subject

	if subject:match(date_pattern1) then
		-- Full date format: YYYY-MM-DD subject
		parsed_year, parsed_month, parsed_day, parsed_subject = subject:match(date_pattern1)
		year = tonumber(parsed_year)
		month = tonumber(parsed_month)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from full pattern: " .. year .. "-" .. month .. "-" .. day)
	elseif subject:match(date_pattern2) then
		-- Month-day format: MM-DD subject
		parsed_month, parsed_day, parsed_subject = subject:match(date_pattern2)
		month = tonumber(parsed_month)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from MM-DD pattern: " .. year .. "-" .. month .. "-" .. day)
	elseif subject:match(date_pattern3) then
		-- Day only format: DD subject
		parsed_day, parsed_subject = subject:match(date_pattern3)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from day pattern: " .. year .. "-" .. month .. "-" .. day)
	end

	-- Validate and format date components with fallbacks
	if not month or type(month) ~= "number" then
		month = os.date("*t").month
	end
	if not day or type(day) ~= "number" then
		day = os.date("*t").day
	end
	month = string.format("%02d", month)
	day = string.format("%02d", day)

	-- Create directory structure if it doesn't exist
	local year_dir = M.config.notes_dir .. "/" .. year
	local month_dir = year_dir .. "/" .. month

	-- Calculate week number and create week folder
	local date_str = year .. "-" .. month .. "-" .. day
	local week_number = M.helpers.get_week_number_sunday_based(date_str)
	if not week_number or type(week_number) ~= "number" then
		week_number = 1
	end
	local week_folder = "W" .. string.format("%02d", week_number)
	local week_dir = month_dir .. "/" .. week_folder

	M.helpers.prepare_dir(year_dir)
	M.helpers.prepare_dir(month_dir)
	M.helpers.prepare_dir(week_dir)

	-- Replace spaces with dashes in subject
	subject = subject:gsub(" ", "-")

	-- Create filename
	local filename = week_dir .. "/" .. day .. "-" .. subject .. ".md"

	-- Create note stub with date and week metadata
	local title = subject:gsub("-", " ")
	local note_date = year .. "-" .. month .. "-" .. day
	return M._create_note_file(filename, title, { { "Date", note_date }, { "Week", week_folder } })
end

-- Create a new note from template with given subject and template content
M.new_note_from_template = function(subject, template_content)
	-- Get current date
	local current_date = os.date("*t")
	local year = current_date.year
	local month = current_date.month
	local day = current_date.day

	-- Parse date from subject if provided in one of the formats (same logic as new_note)
	do
		local top_level_note, top_level_note_err = try_create_top_level_note(subject, current_date, template_content)
		if top_level_note_err then
			vim.notify(top_level_note_err, vim.log.levels.WARN)
			return nil
		end
		if top_level_note then
			return top_level_note
		end
	end

	-- Same date parsing logic as new_note function
	local date_pattern1 = "^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(.+)$" -- YYYY-MM-DD
	local date_pattern2 = "^(%d%d)%-(%d%d)%s+(.+)$" -- MM-DD
	local date_pattern3 = "^(%d%d)%s+(.+)$" -- DD

	local parsed_year, parsed_month, parsed_day, parsed_subject

	if subject:match(date_pattern1) then
		parsed_year, parsed_month, parsed_day, parsed_subject = subject:match(date_pattern1)
		year = tonumber(parsed_year)
		month = tonumber(parsed_month)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from full pattern: " .. year .. "-" .. month .. "-" .. day)
	elseif subject:match(date_pattern2) then
		parsed_month, parsed_day, parsed_subject = subject:match(date_pattern2)
		month = tonumber(parsed_month)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from MM-DD pattern: " .. year .. "-" .. month .. "-" .. day)
	elseif subject:match(date_pattern3) then
		parsed_day, parsed_subject = subject:match(date_pattern3)
		day = tonumber(parsed_day)
		subject = parsed_subject
		M.logger.info("Using date from day pattern: " .. year .. "-" .. month .. "-" .. day)
	end

	-- Validate and format date components with fallbacks
	if not month or type(month) ~= "number" then
		month = os.date("*t").month
	end
	if not day or type(day) ~= "number" then
		day = os.date("*t").day
	end
	month = string.format("%02d", month)
	day = string.format("%02d", day)

	-- Create directory structure (same logic as new_note)
	local year_dir = M.config.notes_dir .. "/" .. year
	local month_dir = year_dir .. "/" .. month

	-- Calculate week number and create week folder
	local date_str = year .. "-" .. month .. "-" .. day
	local week_number = M.helpers.get_week_number_sunday_based(date_str)
	if not week_number or type(week_number) ~= "number" then
		week_number = 1
	end
	local week_folder = "W" .. string.format("%02d", week_number)
	local week_dir = month_dir .. "/" .. week_folder

	M.helpers.prepare_dir(year_dir)
	M.helpers.prepare_dir(month_dir)
	M.helpers.prepare_dir(week_dir)

	-- Replace spaces with dashes in subject
	subject = subject:gsub(" ", "-")

	-- Create filename
	local filename = week_dir .. "/" .. day .. "-" .. subject .. ".md"

	-- Create note with template content
	local title = subject:gsub("-", " ")
	local note_date = year .. "-" .. month .. "-" .. day
	return M._create_note_file(filename, title, { { "Date", note_date }, { "Week", week_folder } }, template_content)
end

M.cmd.ChatDelete = function()
	-- get buffer and file
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- check if file is in the chat dir
	if not find_chat_root(file_name) then
		M.logger.warning("File " .. vim.inspect(file_name) .. " is not in configured chat roots")
		return
	end

	-- delete without confirmation
	if not M.config.chat_confirm_delete then
		M.helpers.delete_file(file_name)
		return
	end

	-- ask for confirmation
	vim.ui.input({ prompt = "Delete " .. file_name .. "? [y/N] " }, function(input)
		if input and input:lower() == "y" then
			M.helpers.delete_file(file_name)
		end
	end)
end

-- Structure to represent a parsed chat:
-- {
--   headers = { key-value pairs },
--   exchanges = {
--     {
--       question = { line_start = N, line_end = N, content = "text" },
--       answer = { line_start = N, line_end = N, content = "text" },
--       summary = { line = N, content = "text" },       -- optional
--       reasoning = { line = N, content = "text" },     -- optional
--     },
--     ...
--   }
-- }

-- Parse a chat file into a structured representation.
-- Delegates to chat_parser module, passing the current config explicitly.
M.parse_chat = function(lines, header_end)
	return M.chat_parser.parse_chat(lines, header_end, M.config)
end

-- Find which exchange contains the given line
M.find_exchange_at_line = function(parsed_chat, line_number)
	for i, exchange in ipairs(parsed_chat.exchanges) do
		-- Check if the line is in the question
		if
			exchange.question
			and line_number >= exchange.question.line_start
			and line_number <= exchange.question.line_end
		then
			return i, "question"
		end

		-- Check if the line is in the answer
		if exchange.answer and line_number >= exchange.answer.line_start and line_number <= exchange.answer.line_end then
			return i, "answer"
		end
	end

	return nil, nil
end

-- Internal: Build messages array for LLM from parsed chat
-- This is extracted for testability - pure logic with injected dependencies
M._build_messages = function(opts)
	local parsed_chat = opts.parsed_chat
	local start_index = opts.start_index
	local end_index = opts.end_index
	local exchange_idx = opts.exchange_idx
	local agent = opts.agent
	local opts_config = opts.config
	local helpers = opts.helpers
	local logger = opts.logger or { debug = function() end, warning = function() end }

	-- Process headers for agent information
	local headers = parsed_chat.headers

	-- Prepare for summary extraction
	local memory_enabled = opts_config.chat_memory and opts_config.chat_memory.enable

	-- Use header-defined max_full_exchanges if available, otherwise use config value
	local max_exchanges = 999999
	if memory_enabled then
		if headers.config_max_full_exchanges then
			max_exchanges = headers.config_max_full_exchanges
			logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
		else
			max_exchanges = opts_config.chat_memory.max_full_exchanges
		end
	end

	local omit_user_text = memory_enabled and opts_config.chat_memory.omit_user_text or "[Previous messages omitted]"

	-- Get combined agent information using the helper function
	local agent_info = M.get_agent_info(headers, agent)

	-- Convert parsed_chat to messages for the model using a single-pass approach
	local messages = { { role = "", content = "" } } -- Start with empty message for system prompt

	-- Process each exchange, determining whether to preserve or summarize
	local total_exchanges = #parsed_chat.exchanges

	-- Single pass through all exchanges
	for idx, exchange in ipairs(parsed_chat.exchanges) do
		if exchange.question and exchange.question.line_start >= start_index and idx <= exchange_idx then
			-- Determine if this exchange should be preserved in full
			local should_preserve = false

			-- Preserve if this is the current question
			if idx == exchange_idx then
				should_preserve = true
				logger.debug("Exchange #" .. idx .. " preserved as current question")
			end
			-- Preserve if it's a recent exchange (within max_full_exchanges from the end)
			if idx > total_exchanges - max_exchanges then
				should_preserve = true
				logger.debug("Exchange #" .. idx .. " preserved as recent exchange")
			end

			-- Preserve if it contains file references
			if #exchange.question.file_references > 0 then
				should_preserve = true
				logger.debug("Exchange #" .. idx .. " preserved due to file references")
			end

				-- Process the question
				if should_preserve then
					-- Get the question content and process any file loading directives
					local question_content = exchange.question.content
					local file_content_parts = {}

					-- Handle raw request mode - parse JSON from typed code fences
					-- Look for ```json {"type": "request"} fences; when present, use as raw payload
					-- regardless of parse_raw_request toggle (the fence metadata is authoritative)
					do
						local json_content = question_content:match('```json%s+{"type":%s*"request"}%s*\n(.-)\n```')

						if json_content then
							logger.debug("Found typed JSON request block in question, using raw request mode")

							-- Try to parse the JSON
							local success, payload = pcall(vim.json.decode, json_content)
							if success and type(payload) == "table" then
								-- Store the raw payload for direct use
								exchange.question.raw_payload = payload
								logger.debug("Successfully parsed JSON payload: " .. vim.inspect(payload))
							else
								logger.warning("Failed to parse JSON in raw request mode: " .. tostring(payload))
							end
						end
					end

					-- Use the precomputed file references instead of scanning for them again
					for _, file_ref in ipairs(exchange.question.file_references) do
						local path = file_ref.path

						logger.debug("Processing file reference: " .. path)

						-- Check if this is a pre-resolved remote reference
						if opts.resolved_remote_content and opts.resolved_remote_content[path] then
							table.insert(
								file_content_parts,
								"[The following content was already fetched from "
									.. path
									.. ". Do NOT use web_fetch or web_search to access this URL.]\n"
									.. opts.resolved_remote_content[path]
							)
						elseif helpers.is_remote_url and helpers.is_remote_url(path) then
							table.insert(file_content_parts, M._format_missing_remote_reference_cache_content(path))
						-- Check if this is a directory or has directory pattern markers (* or **/)
						elseif
							helpers.is_directory(path)
							or path:match("/%*%*?/?") -- Contains /** or /**/
							or path:match("/%*%.%w+$")
						then -- Contains /*.ext pattern
							table.insert(file_content_parts, helpers.process_directory_pattern(path))
						else
							table.insert(file_content_parts, helpers.format_file_content(path))
						end
					end

					-- Handle provider-specific file reference processing for questions with file references
					if exchange.question.file_references and #exchange.question.file_references > 0 then
						-- split user question with file inclusion (@@ pattern) into two messages.
						-- a system message that contains file content. and a user message containing the question.
						-- the cache-control key is only needed for Anthropic, but since it doesn't cause problem
						-- with Google or OpenAI, I'll leave it here.
						table.insert(messages, {
							role = "system",
							content = table.concat(file_content_parts, "\n") .. "\n",
							cache_control = { type = "ephemeral" },
						})
						table.insert(messages, { role = "user", content = question_content })
					else
						-- No file references, just add the question as user message
						table.insert(messages, { role = "user", content = question_content })
					end
			else
				-- Use the placeholder text for summarized questions
				table.insert(messages, { role = "user", content = omit_user_text })
			end

			-- Process the answer if it exists and is within our range
			if exchange.answer and exchange.answer.line_start <= end_index and idx < exchange_idx then
				-- when we preserve due to have file inclusion in question, we still summarize the answer
				if should_preserve and not (exchange.question.file_references and #exchange.question.file_references > 0) then
					-- Use the full answer content
					table.insert(messages, { role = "assistant", content = exchange.answer.content })
				else
					-- Use the summary if available
					if exchange.summary then
						table.insert(messages, { role = "assistant", content = exchange.summary.content })
					else
						-- If no summary is available, use the full content (fallback)
						table.insert(messages, { role = "assistant", content = exchange.answer.content })
					end
				end
			end
		end
	end

	-- replace first empty message with system prompt (use agent_info which has already resolved this)
	local content = agent_info.system_prompt
	if content and content:match("%S") then
		messages[1] = { role = "system", content = content }

		-- For providers that support cache_control, add ephemeral caching to system prompt
		local prov = require("parley.providers")
		if prov.has_feature(agent_info.provider, "cache_control") then
			messages[1].cache_control = { type = "ephemeral" }
		end
	end

	-- strip whitespace from ends of content
	for _, message in ipairs(messages) do
		message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
	end

	-- Preserve a trailing newline for appended system prompt lines.
	local has_system_prompt_append = false
	if type(headers) == "table" and type(headers._append) == "table" then
		local canonical = headers._append.system_prompt
		local legacy = headers._append.role
		has_system_prompt_append = (type(canonical) == "table" and #canonical > 0) or (type(legacy) == "table" and #legacy > 0)
	end
	if has_system_prompt_append and messages[1] and messages[1].role == "system" and messages[1].content ~= "" then
		if messages[1].content:sub(-1) ~= "\n" then
			messages[1].content = messages[1].content .. "\n"
		end
	end

	return messages
end

-- Resolve all remote (URL-based) file references asynchronously before building messages
-- Calls callback with resolved_remote_content map when all fetches complete
---@param opts table # { parsed_chat, config, chat_file, exchange_idx }
---@param callback function # called with resolved_remote_content table
M._resolve_remote_references = function(opts, callback)
	local helpers = require("parley.helper")
	local oauth = require("parley.oauth")
	local parsed_chat = opts.parsed_chat
	local opts_config = opts.config
	local chat_file = opts.chat_file or ""
	local exchange_idx = opts.exchange_idx or #parsed_chat.exchanges
	local resolved = {}
	local seen_prior = {}
	local seen_current = {}
	local queued_fetches = {}
	local urls_to_fetch = {}
	local chat_cache = M._get_chat_remote_reference_cache(chat_file)

	local function queue_fetch(url)
		if not queued_fetches[url] then
			queued_fetches[url] = true
			table.insert(urls_to_fetch, url)
		end
	end

	for idx, exchange in ipairs(parsed_chat.exchanges) do
		if idx > exchange_idx then
			break
		end

		if exchange.question and exchange.question.file_references then
			for _, file_ref in ipairs(exchange.question.file_references) do
				local url = file_ref.path
				if helpers.is_remote_url(url) then
					if idx == exchange_idx and not seen_current[url] then
						seen_current[url] = true
						queue_fetch(url)
					elseif idx < exchange_idx and not seen_prior[url] then
						seen_prior[url] = true
						if chat_cache[url] then
							resolved[url] = chat_cache[url]
						else
							queue_fetch(url)
						end
					end
				end
			end
		end
	end

	if #urls_to_fetch == 0 then
		callback(resolved)
		return
	end

	local pending = #urls_to_fetch

	for _, url in ipairs(urls_to_fetch) do
		-- Delegate remote URL handling to the OAuth fetcher. It owns provider
		-- detection and can fall back to the auth picker for unknown patterns.
		oauth.fetch_content(url, opts_config.oauth or opts_config.google_drive, function(content, err)
			local cached_content = content
			if not cached_content then
				cached_content = M._format_remote_reference_error_content(url, err)
				M.logger.warning("Failed to fetch remote content: " .. (err or "unknown error"))
			end

			resolved[url] = cached_content
			chat_cache[url] = cached_content
			M._save_remote_reference_cache()
			pending = pending - 1
			if pending == 0 then
				callback(resolved)
			end
		end)
	end
end

M.chat_respond = function(params, callback, override_free_cursor, force)
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor_pos[1]

	local use_free_cursor = not is_follow_cursor_enabled(override_free_cursor)
	M.logger.debug(
		"chat_respond configured cursor behavior - override: "
			.. tostring(override_free_cursor)
			.. ", final follow_cursor: "
			.. tostring(not use_free_cursor)
	)

	-- Check if there's already an active process for this buffer
	if not force and M.tasker.is_busy(buf, false) then
		M.logger.warning("A Parley process is already running. Use stop to cancel or force to override.")
		return
	end

	-- go to normal mode
	vim.cmd("stopinsert")

	-- get all lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- check if file looks like a chat file
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("File " .. vim.inspect(file_name) .. " does not look like a chat file: " .. vim.inspect(reason))
		return
	end

	-- Find header section end
	local header_end = find_chat_header_end(lines)

	if header_end == nil then
		M.logger.error("Error while parsing headers: --- not found. Check your chat template.")
		return
	end

	-- Parse chat into structured representation
	local parsed_chat = M.parse_chat(lines, header_end)
	M.logger.debug("chat_respond: parsed chat: " .. vim.inspect(parsed_chat))

	-- Determine which part of the chat to process based on cursor position
	local end_index = #lines
	local start_index = header_end + 1
	local exchange_idx, component = M.find_exchange_at_line(parsed_chat, cursor_line)
	M.logger.debug(
		"chat_respond: exchange_idx and component under cursor " .. tostring(exchange_idx) .. " " .. tostring(component)
	)

	-- If range was explicitly provided, respect it
	if params.range == 2 then
		start_index = math.max(start_index, params.line1)
		end_index = math.min(end_index, params.line2)
	else
		-- Check if cursor is in the middle of the document on a question
		if exchange_idx and component == "question" then
			-- Cursor is on a question - process up to the end of this question's answer
			M.logger.debug("Resubmitting question at exchange #" .. exchange_idx)

			if parsed_chat.exchanges[exchange_idx].answer then
				end_index = parsed_chat.exchanges[exchange_idx].answer.line_end
			else
				-- If the question has no answer yet, process to the end
				end_index = #lines
			end

			-- Highlight the lines that will be reprocessed
			local ns_id = vim.api.nvim_create_namespace("ParleyResubmit")
			vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

			local highlight_start = parsed_chat.exchanges[exchange_idx].question.line_start
			vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)

			-- Always schedule the highlight to clear after a brief delay
			vim.defer_fn(function()
				vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
			end, 1000)
		end
	end

	-- Get agent to use
	local agent = M.get_agent()

	-- Get headers for later use (needed in completion callback)
	local headers = parsed_chat.headers

	-- Resolve remote file references, then build messages and continue
	M._resolve_remote_references({
		parsed_chat = parsed_chat,
		config = M.config,
		chat_file = file_name,
		exchange_idx = exchange_idx,
	}, function(resolved_remote_content)
		-- Build messages array using extracted testable function
		local messages = M._build_messages({
			parsed_chat = parsed_chat,
			start_index = start_index,
			end_index = end_index,
			exchange_idx = exchange_idx,
			agent = agent,
			config = M.config,
			helpers = M.helpers,
			logger = M.logger,
			resolved_remote_content = resolved_remote_content,
		})

		-- Get agent info for display and dispatcher
		local agent_info = M.get_agent_info(headers, agent)
		local agent_name = agent_info.display_name

		-- Set up agent prefixes
		local agent_prefix = M.config.chat_assistant_prefix[1]
		local agent_suffix = config.chat_assistant_prefix[2]
		if type(M.config.chat_assistant_prefix) == "string" then
			agent_prefix = M.config.chat_assistant_prefix
		elseif type(M.config.chat_assistant_prefix) == "table" then
			agent_prefix = M.config.chat_assistant_prefix[1]
			agent_suffix = M.config.chat_assistant_prefix[2] or ""
		end
		agent_suffix = M.render.template(agent_suffix, { ["{{agent}}"] = agent_name })

		-- Find where to insert assistant response
		local response_line = M.helpers.last_content_line(buf)

		-- If cursor is on a question, handle insertion based on question position
		if exchange_idx and (component == "question" or component == "answer") then
			if parsed_chat.exchanges[exchange_idx].answer then
				-- If question already has an answer, replace it
				local answer = parsed_chat.exchanges[exchange_idx].answer

				-- Delete the existing answer, keeping one blank line as separator before next question
				vim.api.nvim_buf_set_lines(buf, answer.line_start - 1, answer.line_end, false, { "" })

				-- Set response line to insert at answer position
				response_line = answer.line_start - 2
			else
				-- New question (no answer yet)
				-- Insert right after the question
				local question_end = parsed_chat.exchanges[exchange_idx].question.line_end
				response_line = question_end - 1

				-- Check if this is a question in the middle (not the last one)
				-- If so, we need to make sure we don't have to insert anything
				-- since we'll just insert at the end of the question anyway
				M.logger.debug("New question in middle - inserting after line " .. question_end)
			end
		end

		-- Check if the last line of the question is empty
		local last_question_line
		if response_line >= 0 then
			last_question_line = vim.api.nvim_buf_get_lines(buf, response_line, response_line + 1, false)[1]
		end

		-- If the line isn't empty, insert an empty line to ensure proper spacing
		if last_question_line and last_question_line:match("%S") then
			M.logger.debug("Adding empty line after question for proper spacing")
			vim.api.nvim_buf_set_lines(buf, response_line + 1, response_line + 1, false, { "" })
			response_line = response_line + 1
		end

		local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
		local spinner_message = "Submitting..."
		local progress_detail_text = ""
		local progress_detail_key = nil
		local spinner_frame_index = 1
		local spinner_timer = nil
		local spinner_active = M._state.web_search and true or false
		local spinner_running = false
		local initial_progress_text = ""
		if spinner_active then
			initial_progress_text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
		end

		local response_block_lines = { "", agent_prefix .. agent_suffix, "", initial_progress_text }
		if spinner_active then
			table.insert(response_block_lines, "")
		end

		-- Write assistant prompt with extra newline; progress line starts at
		-- response_line + 3 and may shift by raw_request_offset.
		vim.api.nvim_buf_set_lines(buf, response_line, response_line, false, response_block_lines)

		M.logger.debug("messages to send: " .. vim.inspect(messages))

		-- Check if we're in raw request mode and have a raw payload to use
		local raw_payload = nil
		if
			exchange_idx
			and parsed_chat.exchanges[exchange_idx].question
			and parsed_chat.exchanges[exchange_idx].question.raw_payload
		then
			raw_payload = parsed_chat.exchanges[exchange_idx].question.raw_payload
			M.logger.debug("Using raw payload for request: " .. vim.inspect(raw_payload))
		end

		-- Compute payload once for both display and query
		local final_payload = raw_payload or M.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider)

		-- In raw request mode, insert the request payload after the question, before the agent response
		-- Skip if the question already contains a typed request fence (raw_payload was parsed from it)
		local raw_request_offset = 0
		if M.config.raw_mode and M.config.raw_mode.parse_raw_request and not raw_payload then
			local json_str = vim.json.encode(final_payload)
			-- Pretty-print via python3 json.tool
			local ok, formatted = pcall(function()
				return vim.fn.system({ "python3", "-m", "json.tool" }, json_str)
			end)
			if not ok or vim.v.shell_error ~= 0 then
				formatted = json_str
			end
			local request_lines = { '', '```json {"type": "request"}' }
			for line in formatted:gmatch("[^\n]+") do
				table.insert(request_lines, line)
			end
			table.insert(request_lines, "```")
			-- Insert right before the agent header (at response_line, pushing agent header down)
			vim.api.nvim_buf_set_lines(buf, response_line, response_line, false, request_lines)
			raw_request_offset = #request_lines
		end

		local progress_line = response_line + 3 + raw_request_offset
		local response_start_line = spinner_active and (progress_line + 2) or progress_line

		local function set_progress_indicator_line(text)
			if not spinner_active then
				return
			end
			if vim.in_fast_event() then
				vim.schedule(function()
					set_progress_indicator_line(text)
				end)
				return
			end
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local existing = vim.api.nvim_buf_get_lines(buf, progress_line, progress_line + 1, false)[1]
			if existing == nil then
				return
			end
			vim.api.nvim_buf_set_lines(buf, progress_line, progress_line + 1, false, { text or "" })
		end

		local function render_spinner_line()
			if not spinner_active then
				return
			end
			if vim.in_fast_event() then
				vim.schedule(render_spinner_line)
				return
			end
			local text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
			set_progress_indicator_line(text)
		end

		local function stop_spinner()
			if not spinner_running then
				return
			end
			spinner_running = false
			stop_and_close_timer(spinner_timer)
			spinner_timer = nil
		end

		local function clear_progress_indicator(qt)
			if not spinner_active then
				return
			end
			if vim.in_fast_event() then
				vim.schedule(function()
					clear_progress_indicator(qt)
				end)
				return
			end
			stop_spinner()
			spinner_active = false
			if vim.api.nvim_buf_is_valid(buf) then
				local line_count = vim.api.nvim_buf_line_count(buf)
				local delete_end = math.min(progress_line + 2, line_count)
				local existing = vim.api.nvim_buf_get_lines(buf, progress_line, delete_end, false)
				if #existing > 0 then
					local deleted_line_count = delete_end - progress_line
					vim.api.nvim_buf_set_lines(buf, progress_line, delete_end, false, {})
					if qt then
						if type(qt.first_line) == "number" and qt.first_line >= progress_line then
							qt.first_line = qt.first_line - deleted_line_count
						end
						if type(qt.last_line) == "number" and qt.last_line >= progress_line then
							qt.last_line = qt.last_line - deleted_line_count
						end
					end
				end
			end
		end

		local function start_spinner()
			if not spinner_active then
				return
			end
			spinner_running = true
			render_spinner_line()
			spinner_timer = vim.loop.new_timer()
			spinner_timer:start(
				90,
				90,
				vim.schedule_wrap(function()
					if not spinner_running then
						return
					end
					spinner_frame_index = spinner_frame_index + 1
					if spinner_frame_index > #spinner_frames then
						spinner_frame_index = 1
					end
					render_spinner_line()
				end)
			)
		end

		start_spinner()

		local base_handler = M.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
			return is_follow_cursor_enabled(override_free_cursor)
		end)
		local function request_clear_progress_indicator(qt)
			if vim.in_fast_event() then
				vim.schedule(function()
					clear_progress_indicator(qt)
				end)
				return
			end
			clear_progress_indicator(qt)
		end
		local response_handler = function(qid, chunk)
			if type(chunk) == "string" and chunk ~= "" then
				stop_spinner()
			end
			base_handler(qid, chunk)
		end

		-- call the model and write response
		M.dispatcher.query(
			buf,
			agent_info.provider,
			final_payload,
			response_handler,
			vim.schedule_wrap(function(qid)
				local qt = M.tasker.get_query(qid)
				if not qt then
					return
				end
				request_clear_progress_indicator(qt)
				local streamed_cursor_line = query_cursor_line(qt)

				-- Only add a new user prompt at the end if we're not in the middle of the document
				M.logger.debug("exchange_idx: " .. tostring(exchange_idx) .. " and #parsed_chat: " .. tostring(#parsed_chat))

				if exchange_idx == #parsed_chat.exchanges then
					-- write user prompt at the end
					last_content_line = M.helpers.last_content_line(buf)
					M.helpers.undojoin(buf)
					vim.api.nvim_buf_set_lines(
						buf,
						last_content_line,
						last_content_line,
						false,
						{ "", M.config.chat_user_prefix, "" }
					)

					-- delete whitespace lines at the end of the file
					last_content_line = M.helpers.last_content_line(buf)
					M.helpers.undojoin(buf)
					vim.api.nvim_buf_set_lines(buf, last_content_line, -1, false, {})
					-- insert a new line at the end of the file
					M.helpers.undojoin(buf)
					vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
				end

				-- if topic is ?, then generate it
				if headers.topic == "?" then
					-- insert last model response
					table.insert(messages, { role = "assistant", content = qt.response })

					-- ask model to generate topic/title for the chat
					table.insert(messages, { role = "user", content = M.config.chat_topic_gen_prompt })

					-- prepare invisible buffer for the model to write to
					local topic_buf = vim.api.nvim_create_buf(false, true)
					local topic_handler = M.dispatcher.create_handler(topic_buf, nil, 0, false, "", false)

					-- call the model
					M.dispatcher.query(
						nil,
						agent_info.provider,
						M.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider),
						topic_handler,
						vim.schedule_wrap(function()
							-- get topic from invisible buffer
							local topic = vim.api.nvim_buf_get_lines(topic_buf, 0, -1, false)[1]
							-- close invisible buffer
							vim.api.nvim_buf_delete(topic_buf, { force = true })
							-- strip whitespace from ends of topic
							topic = topic:gsub("^%s*(.-)%s*$", "%1")
							-- strip dot from end of topic
							topic = topic:gsub("%.$", "")

							-- if topic is empty do not replace it
							if topic == "" then
								return
							end

							-- replace topic in current buffer
							M.helpers.undojoin(buf)
							local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
							set_chat_topic_line(buf, all_lines, topic)
						end)
					)
				end

				-- Place cursor appropriately
				M.logger.debug(
					"Cursor movement check - use_free_cursor: "
						.. tostring(use_free_cursor)
						.. ", config.chat_free_cursor: "
						.. tostring(M.config.chat_free_cursor)
				)

				if is_follow_cursor_enabled(override_free_cursor) then
					M.logger.debug(
						"Moving cursor - exchange_idx: "
							.. tostring(exchange_idx)
							.. ", component: "
							.. tostring(component)
							.. ", streamed_cursor_line: "
							.. tostring(streamed_cursor_line)
					)

					local line = streamed_cursor_line
					if not line then
						if exchange_idx and component == "question" then
							line = response_line + 2
						else
							line = vim.api.nvim_buf_line_count(buf)
						end
					end
					M.logger.debug("Moving cursor to completion position: " .. tostring(line))
					M.helpers.cursor_to_line(line, buf, win)
				else
					M.logger.debug("Not moving cursor due to free_cursor setting")
				end
				-- Refresh interview timestamps (decoration provider handles chat highlights)
				M.highlight_interview_timestamps(buf)

				vim.cmd("doautocmd User ParleyDone")

				-- Call the callback if provided
				if callback then
					callback()
				end
			end),
			nil,
			vim.schedule_wrap(function(_, progress_event)
				if not progress_event or type(progress_event) ~= "table" then
					return
				end
				if not spinner_active then
					return
				end
				local message = progress_event.message
				local detail = progress_event.text
				if type(detail) == "string" and detail ~= "" then
					local detail_key = table.concat({
						tostring(progress_event.phase or ""),
						tostring(progress_event.kind or ""),
						tostring(progress_event.tool or ""),
						tostring(progress_event.block_type or ""),
					}, ":")
					if progress_detail_key ~= detail_key then
						progress_detail_key = detail_key
						progress_detail_text = ""
					end
					progress_detail_text = progress_detail_text .. detail
					local compact = progress_detail_text:gsub("%s+", " "):gsub("^%s+", "")
					if compact ~= "" then
						if progress_event.kind == "reasoning" then
							message = "Reasoning: " .. compact
						else
							local base = (type(progress_event.message) == "string" and progress_event.message ~= "")
							    and progress_event.message
							    or "Working..."
							message = base .. " " .. compact
						end
					end
				else
					progress_detail_text = ""
					progress_detail_key = nil
				end

				if type(message) == "string" and message ~= "" and message ~= spinner_message then
					spinner_message = message
					render_spinner_line()
				end
			end)
		)
	end)
end

-- Function to resubmit all questions up to the cursor position
M.chat_respond_all = function()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor_pos[1]

	if M.tasker.is_busy(buf, false) then
		return
	end

	-- Get all lines and check if this is a chat file
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("File " .. vim.inspect(file_name) .. " does not look like a chat file: " .. vim.inspect(reason))
		return
	end

	-- Get all lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	-- Find header section end
	local header_end = find_chat_header_end(lines)

	if header_end == nil then
		M.logger.error("Error while parsing headers: --- not found. Check your chat template.")
		return
	end

	-- Parse chat into structured representation
	local parsed_chat = M.parse_chat(lines, header_end)

	-- Find which exchange contains the cursor
	local current_exchange_idx, _ = M.find_exchange_at_line(parsed_chat, cursor_line)
	if not current_exchange_idx then
		-- If cursor isn't on any exchange, find the last exchange before cursor
		for i = #parsed_chat.exchanges, 1, -1 do
			local exchange = parsed_chat.exchanges[i]
			if exchange.question and exchange.question.line_start < cursor_line then
				current_exchange_idx = i
				break
			end
		end
	end

	if not current_exchange_idx then
		M.logger.warning("No questions found before cursor position")
		return
	end

	-- Save the original position for later restoration
	local original_question_line = nil
	if current_exchange_idx and parsed_chat.exchanges[current_exchange_idx] then
		original_question_line = parsed_chat.exchanges[current_exchange_idx].question.line_start
	end

	-- Start recursive resubmission process
	M.logger.info("Resubmitting all " .. current_exchange_idx .. " questions...")

	-- Show a notification to the user
	vim.api.nvim_echo({
		{ "Parley: ", "Type" },
		{ "Resubmitting all " .. current_exchange_idx .. " questions...", "WarningMsg" },
	}, true, {})

	M.resubmit_questions_recursively(parsed_chat, 1, current_exchange_idx, header_end, original_question_line, win)
end

M.resubmit_questions_recursively = function(
	parsed_chat,
	current_idx,
	max_idx,
	header_end,
	original_position,
	original_win
)
	-- Save the original value on the first call
	if current_idx == 1 then
		original_free_cursor_value = M.config.chat_free_cursor
		M.logger.debug(
			"Starting recursive resubmission - saving original chat_free_cursor: " .. tostring(original_free_cursor_value)
		)
	end

	-- Check if we've processed all questions
	if current_idx > max_idx then
		M.logger.info("Completed resubmitting all questions")

		-- Always restore original setting at the end
		if original_free_cursor_value ~= nil then
			M.config.chat_free_cursor = original_free_cursor_value
			M.logger.debug("End of resubmission - restored chat_free_cursor to: " .. tostring(original_free_cursor_value))

			-- Notify user of completion
			vim.api.nvim_echo({
				{ "Parley: ", "Type" },
				{ "Completed resubmitting all questions", "String" },
			}, true, {})

			-- Reset tracking variable
			original_free_cursor_value = nil
		end

		-- Return cursor to the original position (question under cursor) after everything is done
		local buf = vim.api.nvim_get_current_buf()

		-- If we have an original position saved, restore it
		if original_position and original_win and vim.api.nvim_win_is_valid(original_win) then
			-- Get current lines - the line numbers may have changed during processing
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			local parsed_chat_final = M.parse_chat(lines, header_end)

			-- Find the original question's new position
			if parsed_chat_final.exchanges[max_idx] and parsed_chat_final.exchanges[max_idx].question then
				local new_position = parsed_chat_final.exchanges[max_idx].question.line_start
				M.helpers.cursor_to_line(new_position, buf, original_win)
			else
				-- Fallback if we can't find the original question
				M.helpers.cursor_to_line(original_position, buf, original_win)
			end
		end

		return
	end

	-- Create params for the current question
	local params = {}
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()

	-- Highlight the current question being processed
	local ns_id = vim.api.nvim_create_namespace("ParleyResubmitAll")
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	-- Find the question and position the cursor on it to ensure the correct context
	local question = parsed_chat.exchanges[current_idx].question
	local highlight_start = question.line_start
	vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)

	-- Set the cursor to this question to ensure proper context processing
	M.helpers.cursor_to_line(highlight_start, buf, win)

	-- Schedule highlight to clear after processing is complete
	vim.defer_fn(function()
		vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	end, 1000)

	-- This is key: we use a simulated fake params object
	-- but actually we set the cursor on the right question first
	-- so the proper context is used and answer is placed in correct position
	-- We force free_cursor to false to ensure cursor follows during resubmission
	-- The parameter true means "force cursor movement" - it will override chat_free_cursor setting
	M.logger.debug("Resubmitting question " .. current_idx .. " of " .. max_idx .. " with forced cursor movement")

	-- Force cursor movement for each individual question
	M.config.chat_free_cursor = false -- Will be restored at the end of the resubmission

	M.chat_respond(params, function()
		-- After this question is processed, move to the next one
		-- We need to reparse the chat since content has changed
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local parsed_chat_updated = M.parse_chat(lines, header_end)

		-- Continue with the next question
		vim.defer_fn(function()
			M.resubmit_questions_recursively(
				parsed_chat_updated,
				current_idx + 1,
				max_idx,
				header_end,
				original_position,
				original_win
			)
		end, 500) -- Small delay to allow UI to update
	end)
end

M.cmd.ChatRespond = function(params)
	local force = false

	-- Check for force flag
	if params.args and params.args:match("!$") then
		force = true
		params.args = params.args:gsub("!$", "")
		M.logger.info("Forcing response even if another process is running")
	end

	-- Simply call chat_respond with the current parameters
	M.chat_respond(params, nil, nil, force)
end

-- Command for navigating questions and headers in chat documents
M.cmd.Outline = function()
	-- Check if current buffer is a chat file
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	if M.not_chat(buf, file_name) then
		M.logger.warning("Outline command is only available in chat files")
		return
	end

	-- Launch the question picker
	M.outline.question_picker(M.config)
end

-- Internal: Parse @@ references from a line and return the closest one to cursor
-- Pure function for testability
M._parse_at_reference = function(line, cursor_col)
	local references = {}

	-- Look for instances of @@ in the line
	local start_idx = 1
	while true do
		local match_start, match_end = line:find("@@", start_idx)
		if not match_start then
			break
		end

		-- Find the end of this path (space, line end, or next @@)
		local content_end

		-- Look for the next @@ after this one
		local next_marker = line:find("@@", match_end + 1)

		-- If there's no next marker, use the end of line
		if not next_marker then
			content_end = #line
		else
			content_end = next_marker - 1
		end

		-- Extract the path
		local path = line:sub(match_end + 1, content_end):gsub("^%s*(.-)%s*$", "%1")

		table.insert(references, {
			start = match_start,
			content = path,
		})

		start_idx = match_end + 1
	end

	if #references == 0 then
		return nil
	end

	-- Find the closest reference to cursor position
	local closest_ref = nil
	local min_distance = math.huge

	for _, ref in ipairs(references) do
		local distance = math.abs(cursor_col - ref.start)
		if distance < min_distance then
			min_distance = distance
			closest_ref = ref
		end
	end

	return closest_ref and closest_ref.content or nil
end

-- Function to open a chat reference from a markdown file
M.open_chat_reference = function(current_line, cursor_col, _in_insert_mode, full_line)
	-- Extract the chat path
	local chat_path

	-- First check if the line begins with @@
	if current_line:match("^@@") then
		-- Extract the chat path (up to the colon if present)
		chat_path = current_line:match("^@@%s*([^:]+)")
		if not chat_path then
			chat_path = current_line:match("^@@(.+)$")
		end

		-- Clean up whitespace
		chat_path = chat_path:gsub("^%s*(.-)%s*$", "%1")
	else
		-- Use extracted pure function to find closest @@ reference
		chat_path = M._parse_at_reference(current_line, cursor_col)

		if not chat_path then
			M.logger.warning("No chat reference (@@ syntax) found on current line")
			return
		end
	end

	if not chat_path then
		M.logger.warning("Could not extract chat path from line")
		return
	end

	-- Expand the path
	local expanded_path = vim.fn.expand(chat_path)

	-- Check if the file exists
	if vim.fn.filereadable(expanded_path) == 1 then
		-- Open the chat file
		M.logger.info("Opening chat file: " .. expanded_path)
		M.open_buf(expanded_path)

		-- No need to explicitly handle insert mode here as M.open_buf now
		-- checks for two splits and the caller (OpenFileUnderCursor) handles insert mode
		return true
	else
		-- Check if it's a chat file reference (timestamp format)
		if expanded_path:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
			-- This is a chat file reference that doesn't exist yet - create it
			M.logger.info("Creating new chat file: " .. expanded_path)

			-- Determine agent info
			local agent = M.get_agent()

			-- Create parent directories if they don't exist
			local parent_dir = vim.fn.fnamemodify(expanded_path, ":h")
			M.helpers.prepare_dir(parent_dir)

			-- Extract topic from the reference line or use default
			local topic = "New chat"
			if full_line and full_line:match("@@[^:]+:%s*(.+)") then
				topic = full_line:match("@@[^:]+:%s*(.+)")
			end

			-- Prepare template
			local template = M.get_default_template(agent)
			template = template:gsub("{{topic}}", topic)

			-- Make sure the file has UTF-8 encoding header
			vim.fn.writefile(vim.split(template, "\n"), expanded_path)

			-- Open the file
			M.open_buf(expanded_path)
			return true
		else
			M.logger.warning("Chat file not found: " .. expanded_path)
			return false
		end
	end
end

-- Command to extract and open a file referenced with @@ syntax
M.cmd.OpenFileUnderCursor = function()
	-- Get current buffer and line
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local line_num = cursor_pos[1]
	local current_line = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)[1]
	local cursor_col = cursor_pos[2]

	-- Check if we're in insert mode
	local current_mode = vim.api.nvim_get_mode().mode
	local in_insert_mode = current_mode:match("^i") or current_mode:match("^R")

	-- Log the current file name for debugging
	M.logger.debug("OpenFileUnderCursor called on file: " .. file_name)

	-- Check if it's a markdown file (but not a chat file)
	if M.is_markdown(buf, file_name) then
		M.logger.debug("File is recognized as markdown")
		-- Try to open as a chat reference, passing insert mode status
		if M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line) then
			return
		end
	end

	-- If not a markdown file or not a chat reference, check if it's a chat file
	if M.not_chat(buf, file_name) then
		M.logger.warning("OpenFileUnderCursor command is only available in chat files and markdown files")
		return
	end

	-- Process standard @@ file references in chat files
	local filepath

	-- First check if the line begins with @@
	if current_line:match("^@@") then
		filepath = current_line:match("^@@(.+)$"):gsub("^%s*(.-)%s*$", "%1")
	else
		-- Use extracted pure function to find closest @@ reference
		filepath = M._parse_at_reference(current_line, cursor_col)

		if not filepath then
			M.logger.warning("No file reference (@@ syntax) found on current line")
			return
		end
	end

	-- Expand the path (handle relative paths, ~, etc.)
	local expanded_path = vim.fn.expand(filepath)

	-- Check if it's a directory or a directory pattern
	if
		M.helpers.is_directory(expanded_path)
		or filepath:match("/$")
		or filepath:match("/%*%*?/?")
		or filepath:match("/%*%.%w+$")
	then
		-- Open file explorer for the directory
		-- Try to handle glob patterns by extracting the base directory
		local base_dir = filepath:gsub("/%*%*?/?.*$", ""):gsub("/%*%.%w+$", "")
		expanded_path = vim.fn.expand(base_dir)

		if vim.fn.isdirectory(expanded_path) == 0 then
			M.logger.warning("Directory not found: " .. expanded_path)
			return
		end

		M.logger.info("Opening directory: " .. expanded_path)

		-- Get all windows in the current tab
		local tab_wins = vim.api.nvim_tabpage_list_wins(0)

		-- If we have exactly two splits, open in the other split
		if #tab_wins == 2 then
			local current_win = vim.api.nvim_get_current_win()
			local other_win

			-- Find the other window that's not the current one
			for _, win in ipairs(tab_wins) do
				if win ~= current_win then
					other_win = win
					break
				end
			end

			-- Switch to the other window and open the directory
			if other_win then
				M.logger.debug("Opening directory in other split: " .. expanded_path)
				vim.api.nvim_set_current_win(other_win)
				vim.cmd("Explore " .. vim.fn.fnameescape(expanded_path))

				-- Restore insert mode if needed
				if in_insert_mode then
					vim.schedule(function()
						vim.cmd("startinsert")
					end)
				end

				return
			end
		end

		-- Use netrw (built-in file explorer) to view the directory
		vim.cmd("Explore " .. vim.fn.fnameescape(expanded_path))
	else
		-- Handle as a normal file
		-- Check if file exists
		if vim.fn.filereadable(expanded_path) == 0 then
			-- Check if it's a chat file reference (timestamp format)
			if expanded_path:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
				-- This is a chat file reference that doesn't exist yet - create it
				M.logger.info("Creating new chat file: " .. expanded_path)

				-- Determine agent info
				local agent = M.get_agent()

				-- Create parent directories if they don't exist
				local parent_dir = vim.fn.fnamemodify(expanded_path, ":h")
				M.helpers.prepare_dir(parent_dir)

				-- Extract topic from the reference line or use default
				local topic = "New chat"
				if current_line:match("@@[^:]+:%s*(.+)") then
					topic = current_line:match("@@[^:]+:%s*(.+)")
				end

				-- Prepare template
				local template = M.get_default_template(agent)
				template = template:gsub("{{topic}}", topic)

				-- Make sure the file has UTF-8 encoding header
				vim.fn.writefile(vim.split(template, "\n"), expanded_path)

				-- Open the file
				M.open_buf(expanded_path)
				return
			else
				M.logger.warning("File not found: " .. expanded_path)
				return
			end
		end

		-- Open the file in a new buffer
		M.logger.info("Opening file: " .. expanded_path)

		-- Get all windows in the current tab
		local tab_wins = vim.api.nvim_tabpage_list_wins(0)

		-- If we have exactly two splits, open in the other split
		if #tab_wins == 2 then
			local current_win = vim.api.nvim_get_current_win()
			local other_win

			-- Find the other window that's not the current one
			for _, win in ipairs(tab_wins) do
				if win ~= current_win then
					other_win = win
					break
				end
			end

			-- Switch to the other window and open the file
			if other_win then
				M.logger.debug("Opening file in other split: " .. expanded_path)
				vim.api.nvim_set_current_win(other_win)
				vim.cmd("edit " .. vim.fn.fnameescape(expanded_path))

				-- Restore insert mode if needed
				if in_insert_mode then
					vim.schedule(function()
						vim.cmd("startinsert")
					end)
				end

				return
			end
		end

		-- Otherwise open in current window
		vim.cmd("edit " .. vim.fn.fnameescape(expanded_path))
	end

	-- Return to insert mode if we were in it before
	if in_insert_mode then
		vim.schedule(function()
			vim.cmd("startinsert")
		end)
	end
end

-- State for chat finder
M._chat_finder = {
	opened = false,
	show_all = false, -- Compatibility mirror for the active recency state
	recency_index = nil, -- Current index within the configured recency cycle
	active_window = nil, -- Track the active window that initiated ChatFinder
	source_win = nil, -- Track the source window where ChatFinder was invoked
	initial_index = nil, -- Optional selection index to restore when reopening the picker
	initial_value = nil, -- Preferred item value to restore when reopening after list changes
	sticky_query = nil, -- Preserved [tag] / {root-label} filter fragments carried across invocations
	insert_mode = false, -- Whether we're in insert mode (inserting chat references)
	insert_buf = nil, -- The buffer to insert into
	insert_line = nil, -- The line to insert at
	insert_col = nil, -- The column to insert at (for insert mode)
	insert_normal_mode = nil, -- Whether we're inserting in normal mode or insert mode
}

local function extract_chat_finder_sticky_query(query)
	if type(query) ~= "string" or query == "" then
		return nil
	end

	local fragments = {}
	for token in query:gmatch("%S+") do
		if token:match("^%b[]$") then
			local value = vim.trim(token:sub(2, -2))
			if value ~= "" and not value:find("[%[%]]") then
				table.insert(fragments, "[" .. value .. "]")
			end
		elseif token:match("^%b{}$") then
			local value = vim.trim(token:sub(2, -2))
			if value == "" then
				table.insert(fragments, "{}")
			elseif not value:find("[{}]") then
				table.insert(fragments, "{" .. value .. "}")
			end
		end
	end

	if #fragments == 0 then
		return nil
	end

	return table.concat(fragments, " ")
end

local function extract_note_finder_sticky_query(query)
	if type(query) ~= "string" or query == "" then
		return nil
	end

	local fragments = {}
	for token in query:gmatch("%S+") do
		if token:match("^%b{}$") then
			local value = vim.trim(token:sub(2, -2))
			if value == "" then
				table.insert(fragments, "{}")
			elseif not value:find("[{}]") then
				table.insert(fragments, "{" .. value .. "}")
			end
		end
	end

	if #fragments == 0 then
		return nil
	end

	return table.concat(fragments, " ")
end

local function format_finder_initial_query(sticky_query)
	if type(sticky_query) ~= "string" or sticky_query == "" then
		return nil
	end

	return sticky_query .. " "
end

local function unique_positive_months(values)
	local dedup = {}
	local months = {}
	for _, value in ipairs(values) do
		if type(value) == "number" and value > 0 then
			local normalized = math.floor(value)
			if normalized > 0 and not dedup[normalized] then
				dedup[normalized] = true
				table.insert(months, normalized)
			end
		end
	end
	table.sort(months)
	return months
end

local function resolve_finder_recency(recency_config, recency_index)
	recency_config = recency_config or {}

	local configured_months = {}
	if type(recency_config.presets) == "table" then
		vim.list_extend(configured_months, recency_config.presets)
	end
	if type(recency_config.months) == "number" then
		table.insert(configured_months, recency_config.months)
	end

	local presets = unique_positive_months(configured_months)
	if #presets == 0 then
		presets = { 3 }
	end

	local states = {}
	for _, months in ipairs(presets) do
		table.insert(states, {
			label = string.format("Recent: %d months", months),
			months = months,
			is_all = false,
		})
	end
	table.insert(states, {
		label = "All",
		months = nil,
		is_all = true,
	})

	local resolved_index = recency_index
	if type(resolved_index) ~= "number" or resolved_index < 1 or resolved_index > #states then
		if recency_config.filter_by_default == false then
			resolved_index = #states
		else
			resolved_index = 1
			local default_months = type(recency_config.months) == "number" and math.floor(recency_config.months) or nil
			if default_months then
				for idx, state in ipairs(states) do
					if state.months == default_months then
						resolved_index = idx
						break
					end
				end
			end
		end
	end

	return {
		states = states,
		index = resolved_index,
		current = states[resolved_index],
	}
end

local function cycle_finder_recency(recency_config, recency_index, direction)
	local resolved = resolve_finder_recency(recency_config, recency_index)
	local step = direction == "previous" and -1 or 1
	local next_index = ((resolved.index - 1 + step) % #resolved.states) + 1
	return next_index, resolved.states[next_index]
end

M._resolve_chat_finder_recency = resolve_finder_recency
M._resolve_note_finder_recency = resolve_finder_recency
M._cycle_chat_finder_recency = cycle_finder_recency
M._cycle_note_finder_recency = cycle_finder_recency

local function resolve_finder_initial_index(state, items, label)
	local initial_value = state.initial_value
	if initial_value then
		for idx, item in ipairs(items) do
			if item.value == initial_value then
				M.logger.debug(string.format(
					"%s trace: resolve initial by value matched idx=%s value=%s fallback_index=%s item_count=%s",
					label,
					tostring(idx),
					initial_value,
					tostring(state.initial_index),
					tostring(#items)
				))
				return idx
			end
		end
		M.logger.debug(string.format(
			"%s trace: resolve initial by value missed value=%s fallback_index=%s item_count=%s",
			label,
			initial_value,
			tostring(state.initial_index),
			tostring(#items)
		))
	end

	M.logger.debug(string.format(
		"%s trace: resolve initial by fallback index=%s item_count=%s",
		label,
		tostring(state.initial_index),
		tostring(#items)
	))
	return state.initial_index
end

local function infer_note_directory_cutoff_time(file_path, notes_root)
	local expanded_root = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_root), ":p")):gsub("/+$", "")
	local absolute_path = vim.fn.resolve(vim.fn.fnamemodify(file_path, ":p")):gsub("/+$", "")
	local relative = absolute_path
	local prefix = expanded_root .. "/"
	if absolute_path:sub(1, #prefix) == prefix then
		relative = absolute_path:sub(#prefix + 1)
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local year = tonumber(parts[1] and parts[1]:match("^(%d%d%d%d)$"))
	local month = tonumber(parts[2] and parts[2]:match("^(%d%d)$"))
	local day = tonumber(vim.fn.fnamemodify(file_path, ":t"):match("^(%d%d)%-"))

	if year and month and day then
		return os.time({
			year = year,
			month = month,
			day = day,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	if year and month then
		return os.time({
			year = year,
			month = month + 1,
			day = 0,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	if year then
		return os.time({
			year = year,
			month = 12,
			day = 31,
			hour = 23,
			min = 59,
			sec = 59,
		})
	end

	return nil
end

local function classify_note_finder_path(file_path, notes_root)
	local expanded_root = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_root), ":p")):gsub("/+$", "")
	local absolute_path = vim.fn.resolve(vim.fn.fnamemodify(file_path, ":p")):gsub("/+$", "")
	local relative = absolute_path
	local prefix = expanded_root .. "/"
	if absolute_path:sub(1, #prefix) == prefix then
		relative = absolute_path:sub(#prefix + 1)
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local first_part = parts[1]
	if not first_part or first_part == "templates" then
		return {
			is_template = first_part == "templates",
			relative_path = relative,
		}
	end

	local is_year = first_part:match("^%d%d%d%d$") ~= nil
	local base_folder = nil
	if not is_year then
		base_folder = first_part
	end
	return {
		is_template = false,
		relative_path = relative,
		base_folder = base_folder,
	}
end

M._reopen_chat_finder = function(source_win, selection_index, selection_value)
	M.logger.debug(string.format(
		"ChatFinder trace: schedule reopen source_win=%s selection_index=%s selection_value=%s",
		tostring(source_win),
		tostring(selection_index),
		tostring(selection_value)
	))
	vim.defer_fn(function()
		M._chat_finder.opened = false
		M._chat_finder.source_win = source_win
		M._chat_finder.initial_index = selection_index
		M._chat_finder.initial_value = selection_value
		M.logger.debug(string.format(
			"ChatFinder trace: executing reopen source_win=%s initial_index=%s initial_value=%s",
			tostring(source_win),
			tostring(M._chat_finder.initial_index),
			tostring(M._chat_finder.initial_value)
		))
		M.cmd.ChatFinder()
	end, 100)
end

M._handle_chat_finder_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
	M.logger.debug(string.format(
		"ChatFinder trace: delete response input=%s item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(input),
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if input and input:lower() == "y" then
		M.helpers.delete_file(item_value)
		if close_fn then
			close_fn()
		end
		local next_index = math.min(selected_index, math.max(1, items_count - 1))
		local next_value = nil
		local items = context and context.chat_finder_items or nil
		if type(items) == "table" then
			-- ChatFinder items are stored newest-first but rendered bottom-up, so the
			-- item that stays in the same visual row after delete is the next logical
			-- item (older entry). Fall back to the previous item when deleting the
			-- oldest visible entry.
			local next_item = items[selected_index + 1] or items[selected_index - 1]
			next_value = next_item and next_item.value or nil
			M.logger.debug(string.format(
				"ChatFinder trace: confirmed delete selected_item=%s next_item=%s selected_index=%s next_index=%s item_count=%s",
				tostring(item_value),
				tostring(next_value),
				tostring(selected_index),
				tostring(next_index),
				tostring(#items)
			))
		end
		M._reopen_chat_finder(source_win, next_index, next_value)
		return
	end

	if context then
		context.resume_after_external_ui()
		vim.schedule(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end)
		vim.defer_fn(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end, 10)
		return
	end

	M._reopen_chat_finder(source_win, selected_index, item_value)
end

M._prompt_chat_finder_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
	M.logger.debug(string.format(
		"ChatFinder trace: prompt delete item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		vim.api.nvim_set_current_win(source_win)
	end

	vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
		M._handle_chat_finder_delete_response(
			input,
			item_value,
			selected_index,
			items_count,
			source_win,
			close_fn,
			context
		)
	end)
end

M._reopen_note_finder = function(source_win, selection_index, selection_value)
	M.logger.debug(string.format(
		"NoteFinder trace: schedule reopen source_win=%s selection_index=%s selection_value=%s",
		tostring(source_win),
		tostring(selection_index),
		tostring(selection_value)
	))
	vim.defer_fn(function()
		M._note_finder.opened = false
		M._note_finder.source_win = source_win
		M._note_finder.initial_index = selection_index
		M._note_finder.initial_value = selection_value
		M.logger.debug(string.format(
			"NoteFinder trace: executing reopen source_win=%s initial_index=%s initial_value=%s",
			tostring(source_win),
			tostring(M._note_finder.initial_index),
			tostring(M._note_finder.initial_value)
		))
		M.cmd.NoteFinder()
	end, 100)
end

M._handle_note_finder_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
	M.logger.debug(string.format(
		"NoteFinder trace: delete response input=%s item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(input),
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if input and input:lower() == "y" then
		M.helpers.delete_file(item_value)
		if close_fn then
			close_fn()
		end
		local next_index = math.min(selected_index, math.max(1, items_count - 1))
		local next_value = nil
		local items = context and context.note_finder_items or nil
		if type(items) == "table" then
			local next_item = items[selected_index + 1] or items[selected_index - 1]
			next_value = next_item and next_item.value or nil
		end
		M._reopen_note_finder(source_win, next_index, next_value)
		return
	end

	if context then
		context.resume_after_external_ui()
		vim.schedule(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end)
		vim.defer_fn(function()
			if context.focus_prompt then
				context.focus_prompt()
			end
		end, 10)
		return
	end

	M._reopen_note_finder(source_win, selected_index, item_value)
end

M._prompt_note_finder_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
	M.logger.debug(string.format(
		"NoteFinder trace: prompt delete item=%s selected_index=%s items_count=%s source_win=%s",
		tostring(item_value),
		tostring(selected_index),
		tostring(items_count),
		tostring(source_win)
	))
	if source_win and vim.api.nvim_win_is_valid(source_win) then
		vim.api.nvim_set_current_win(source_win)
	end

	vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
		M._handle_note_finder_delete_response(
			input,
			item_value,
			selected_index,
			items_count,
			source_win,
			close_fn,
			context
		)
	end)
end

M.cmd.ChatFinder = function(_options)
	if M._chat_finder.opened then
		M.logger.warning("Chat finder is already open")
		return
	end
	M._chat_finder.opened = true

	-- IMPORTANT: The window should have been captured from the keybinding
	M.logger.debug("ChatFinder using source_win: " .. (M._chat_finder.source_win or "nil"))

	local chat_roots = M.get_chat_roots()
	local delete_shortcut = M.config.chat_finder_mappings.delete or M.config.chat_shortcut_delete
	local move_shortcut = M.config.chat_finder_mappings.move or { shortcut = "<C-r>" }
	local next_recency_shortcut = M.config.chat_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = M.config.chat_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = M.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }

	-- Launch float picker for chat finder
	do
		-- Get all timestamp format files
		local files = {}
		local seen_files = {}
		for _, root in ipairs(chat_roots) do
			local dir = root.dir
			local pattern = vim.fn.fnameescape(dir) .. "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md"
			for _, file in ipairs(vim.fn.glob(pattern, false, true)) do
				local resolved = vim.fn.resolve(file)
				if not seen_files[resolved] then
					seen_files[resolved] = true
					table.insert(files, {
						path = file,
						root = root,
					})
				end
			end
		end
		local entries = {}

		-- Get recency configuration
		local recency_config = M.config.chat_finder_recency
			or {
				filter_by_default = true,
				months = 3,
				use_mtime = true,
			}
		local resolved_recency = M._resolve_chat_finder_recency(recency_config, M._chat_finder.recency_index)
		M._chat_finder.recency_index = resolved_recency.index
		M._chat_finder.show_all = resolved_recency.current.is_all

		local cutoff_time = nil
		if resolved_recency.current.months then
			local current_time = os.time()
			local months_in_seconds = resolved_recency.current.months * 30 * 24 * 60 * 60
			cutoff_time = current_time - months_in_seconds
		end

		local is_filtering = not resolved_recency.current.is_all

		for _, item in ipairs(files) do
			local file = item.path
			local root = item.root
			local resolved_root_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"))
			local resolved_primary_dir = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(M.config.chat_dir), ":p"))
			local is_primary_root = root.is_primary or resolved_root_dir == resolved_primary_dir
			-- Get file info
			local stat = vim.loop.fs_stat(file)
			if not stat then
				goto continue
			end

			-- Try to infer timestamp from chat filename first
			-- Chat files typically have format: YYYY-MM-DD-HH-MM-SS-topic.md
			local file_time
			local filename = vim.fn.fnamemodify(file, ":t:r")
			local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")

			if year and month and day and hour and min and sec then
				-- Create date table and convert to timestamp
				local date_table = {
					year = tonumber(year),
					month = tonumber(month),
					day = tonumber(day),
					hour = tonumber(hour),
					min = tonumber(min),
					sec = tonumber(sec),
				}
				file_time = os.time(date_table)
			else
				-- Fallback to file system times if we couldn't infer from filename
				file_time = stat.mtime.sec or (stat.birthtime and stat.birthtime.sec) or stat.mtime.sec
			end

			-- Skip files older than cutoff if filtering is active
			if is_filtering and file_time < cutoff_time then
				goto continue
			end

			-- Get topic and tags from the file
			local lines = vim.fn.readfile(file, "", 10) -- Read first 10 lines to get headers
			local topic = ""
			local tags = {}

			-- Parse the file headers to get topic and tags
			local header_end = find_chat_header_end(lines)
			if header_end then
				local parsed_chat = M.parse_chat(lines, header_end)
				if parsed_chat.headers.topic then
					topic = parsed_chat.headers.topic
				end
				if parsed_chat.headers.tags and type(parsed_chat.headers.tags) == "table" then
					tags = parsed_chat.headers.tags
				end
			else
				-- Fallback: look for topic in old format
				for _, line in ipairs(lines) do
					local t = line:match("^# topic: (.+)")
					if t then
						topic = t
						break
					end
				end
			end

			-- Format date string
			local date_str = os.date("%Y-%m-%d", file_time)

			-- Format tags for display
			local tags_display = ""
			if #tags > 0 then
				local tag_parts = {}
				for _, tag in ipairs(tags) do
					table.insert(tag_parts, "[" .. tag .. "]")
				end
				tags_display = table.concat(tag_parts, " ") .. " "
			end

			-- Format tags for search ordinal
			local tags_searchable = #tags > 0 and (" [" .. table.concat(tags, "] [") .. "]") or ""

			local display_filename = vim.fn.fnamemodify(file, ":t")
			local root_prefix = is_primary_root and "" or string.format("{%s} ", root.label)
			local root_searchable = is_primary_root and " {}" or (" {" .. root.label .. "}")
			table.insert(entries, {
				value = file,
				display = display_filename .. " - " .. root_prefix .. tags_display .. topic .. " [" .. date_str .. "]",
				ordinal = display_filename .. root_searchable .. " " .. tags_searchable .. " " .. topic,
				timestamp = file_time,
			})

			::continue::
		end

		-- Sort entries by timestamp (newest first)
		table.sort(entries, function(a, b)
			return a.timestamp > b.timestamp
		end)

		-- Determine prompt title based on filtering state
		local prompt_title = string.format(
			"Chat Files (%s  %s/%s: cycle)",
			resolved_recency.current.label,
			next_recency_shortcut.shortcut,
			previous_recency_shortcut.shortcut
		)

		M.logger.debug("ChatFinder using active_window: " .. (M._chat_finder.active_window or "nil"))

		-- Build float-picker items from sorted entries
		local items = {}
		for _, entry in ipairs(entries) do
			table.insert(items, {
				display = entry.display,
				search_text = entry.ordinal,
				value = entry.value,
			})
		end

		local source_win = M._chat_finder.source_win
		if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
			source_win = vim.api.nvim_get_current_win()
			M._chat_finder.source_win = source_win
			M.logger.debug("ChatFinder captured fallback source_win: " .. source_win)
		end

		M.logger.debug(string.format(
			"ChatFinder trace: opening picker item_count=%s initial_index=%s initial_value=%s first_item=%s",
			tostring(#items),
			tostring(M._chat_finder.initial_index),
			tostring(M._chat_finder.initial_value),
			items[1] and items[1].value or "nil"
		))

		M.float_picker.open({
			title = prompt_title,
			items = items,
			initial_index = resolve_finder_initial_index(M._chat_finder, items, "ChatFinder"),
			initial_query = format_finder_initial_query(M._chat_finder.sticky_query),
			on_query_change = function(query)
				M._chat_finder.sticky_query = extract_chat_finder_sticky_query(query)
			end,
			on_select = function(item)
				local file_path = item.value
				local display = item.display

				-- Check if we're in insert mode (for inserting chat references)
				if M._chat_finder.insert_mode then
					-- Switch to the original source window first
					if source_win and vim.api.nvim_win_is_valid(source_win) then
						vim.api.nvim_set_current_win(source_win)
						M.logger.debug("Switched to source window for insert: " .. source_win)
					end

					if M._chat_finder.insert_buf and vim.api.nvim_buf_is_valid(M._chat_finder.insert_buf) then
						-- Extract topic from the display
						local topic = display:match(" %- (.+) %[") or "Chat"

						-- Get relative path for better readability
						local rel_path = vim.fn.fnamemodify(file_path, ":~:.")

						-- Handle normal mode insertion
						if M._chat_finder.insert_normal_mode then
							vim.api.nvim_buf_set_lines(
								M._chat_finder.insert_buf,
								M._chat_finder.insert_line - 1,
								M._chat_finder.insert_line - 1,
								false,
								{ "@@" .. rel_path .. ": " .. topic }
							)
						else
							-- Handle insert mode insertion by modifying the current line
							local current_line = vim.api.nvim_buf_get_lines(
								M._chat_finder.insert_buf,
								M._chat_finder.insert_line - 1,
								M._chat_finder.insert_line,
								false
							)[1]

							local col = M._chat_finder.insert_col
							local new_line = current_line:sub(1, col) .. "@@" .. rel_path .. ": " .. topic .. current_line:sub(col + 1)

							vim.api.nvim_buf_set_lines(
								M._chat_finder.insert_buf,
								M._chat_finder.insert_line - 1,
								M._chat_finder.insert_line,
								false,
								{ new_line }
							)

							-- Move cursor to the end of the inserted reference
							vim.api.nvim_win_set_cursor(0, {
								M._chat_finder.insert_line,
								col + #("@@" .. rel_path .. ": " .. topic),
							})

							-- Return to insert mode
							vim.schedule(function()
								vim.cmd("startinsert")
							end)
						end

						M.logger.info("Inserted chat reference: " .. rel_path)
					end

					-- Reset insert mode flags
					M._chat_finder.insert_mode = false
					M._chat_finder.insert_buf = nil
					M._chat_finder.insert_line = nil
					M._chat_finder.insert_col = nil
					M._chat_finder.insert_normal_mode = nil
				else
					-- Normal behavior - open the selected chat
					if source_win and vim.api.nvim_win_is_valid(source_win) then
						vim.api.nvim_set_current_win(source_win)
						M.logger.debug("Switched to source window for file open: " .. source_win)
					end
					M.open_buf(file_path, true)
				end
			end,
			on_cancel = function()
				M._chat_finder.opened = false
				M._chat_finder.initial_index = nil
				M._chat_finder.initial_value = nil
			end,
			mappings = {
				-- Delete selected chat file
				{
					key = delete_shortcut.shortcut,
					fn = function(item, close_fn, context)
						if not item then
							M.logger.debug("ChatFinder trace: delete mapping invoked with nil item")
							return
						end
						local selected_index = 1
						for idx, picker_item in ipairs(items) do
							if picker_item.value == item.value then
								selected_index = idx
								break
							end
						end

						M.logger.debug(string.format(
							"ChatFinder trace: delete mapping item=%s selected_index=%s item_count=%s first_item=%s",
							tostring(item.value),
							tostring(selected_index),
							tostring(#items),
							items[1] and items[1].value or "nil"
						))

						context.skip_focus_restore = true
						context.chat_finder_items = items
						context.suspend_for_external_ui()
						vim.defer_fn(function()
							M._prompt_chat_finder_delete_confirmation(
								item.value,
								selected_index,
								#items,
								source_win,
								close_fn,
								context
							)
						end, 20)
					end,
				},
				-- Move selected chat file to another registered chat root
				{
					key = move_shortcut.shortcut,
					fn = function(item, close_fn)
						if not item then
							return
						end

						close_fn()
						vim.schedule(function()
							M.prompt_chat_move(item.value, function(new_file)
								M._chat_finder.opened = false
								M._chat_finder.source_win = source_win
								M._reopen_chat_finder(source_win, nil, new_file)
							end, function()
								M._chat_finder.opened = false
								M._chat_finder.source_win = source_win
								M._reopen_chat_finder(source_win, nil, item.value)
							end)
						end)
					end,
				},
				-- Move left through recency presets
				{
					key = next_recency_shortcut.shortcut,
					fn = function(_, close_fn)
						local next_index, next_state = M._cycle_chat_finder_recency(
							recency_config,
							M._chat_finder.recency_index,
							"previous"
						)
						M._chat_finder.recency_index = next_index
						M._chat_finder.show_all = next_state.is_all
						close_fn()
						vim.defer_fn(function()
							M._chat_finder.opened = false
							M._chat_finder.source_win = source_win
							M.cmd.ChatFinder()
						end, 100)
					end,
				},
				-- Move right through recency presets and "All"
				{
					key = previous_recency_shortcut.shortcut,
					fn = function(_, close_fn)
						local next_index, next_state = M._cycle_chat_finder_recency(
							recency_config,
							M._chat_finder.recency_index,
							"next"
						)
						M._chat_finder.recency_index = next_index
						M._chat_finder.show_all = next_state.is_all
						close_fn()
						vim.defer_fn(function()
							M._chat_finder.opened = false
							M._chat_finder.source_win = source_win
							M.cmd.ChatFinder()
						end, 100)
					end,
				},
				-- Show key bindings help
				{
					key = keybindings_shortcut.shortcut,
					fn = function(_, _)
						vim.schedule(function()
							M.cmd.KeyBindings()
						end)
					end,
				},
			},
	})
	end

	M._chat_finder.initial_index = nil
	M._chat_finder.initial_value = nil
	M._chat_finder.opened = false
end

M.cmd.NoteFinder = function(_options)
	if M._note_finder.opened then
		M.logger.warning("Note finder is already open")
		return
	end
	M._note_finder.opened = true

	local note_finder_mappings = M.config.note_finder_mappings or {}
	local delete_shortcut = note_finder_mappings.delete or M.config.chat_shortcut_delete
	local next_recency_shortcut = note_finder_mappings.next_recency or { shortcut = "<C-a>" }
	local previous_recency_shortcut = note_finder_mappings.previous_recency or { shortcut = "<C-s>" }
	local keybindings_shortcut = M.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }
	local notes_root = vim.fn.expand(M.config.notes_dir)
	local files = M.helpers.find_files(notes_root, "*.md", true)
	local entries = {}
	local recency_config = M.config.note_finder_recency or {
		filter_by_default = true,
		months = 3,
	}
	local resolved_recency = M._resolve_note_finder_recency(recency_config, M._note_finder.recency_index)
	M._note_finder.recency_index = resolved_recency.index
	M._note_finder.show_all = resolved_recency.current.is_all

	local cutoff_time = nil
	if resolved_recency.current.months then
		cutoff_time = os.time() - (resolved_recency.current.months * 30 * 24 * 60 * 60)
	end

	for _, file in ipairs(files) do
		local classification = classify_note_finder_path(file, notes_root)
		if not classification.is_template then
			local stat = vim.loop.fs_stat(file)
			if stat then
				local inferred_time = infer_note_directory_cutoff_time(file, notes_root)
				local modified_time = stat.mtime.sec
				local sort_time = inferred_time or modified_time
				local range_time = inferred_time or modified_time
				local is_special_folder = classification.base_folder ~= nil
				if is_special_folder or not cutoff_time or range_time >= cutoff_time then
					local display
					local search_text
					if is_special_folder then
						local file_name = vim.fn.fnamemodify(file, ":t")
						display = string.format("{%s} %s [%s]", classification.base_folder, file_name, os.date("%Y-%m-%d", sort_time))
						search_text = string.format("{%s} %s %s", classification.base_folder, file_name, classification.relative_path:gsub("%-", " "))
					else
						display = classification.relative_path .. " [" .. os.date("%Y-%m-%d", sort_time) .. "]"
						search_text = "{} " .. classification.relative_path:gsub("%-", " ")
					end
					table.insert(entries, {
						value = file,
						display = display,
						ordinal = search_text,
						timestamp = sort_time,
						modified_time = modified_time,
						base_folder = classification.base_folder,
					})
				end
			end
		end
	end

	table.sort(entries, function(a, b)
		if a.timestamp == b.timestamp then
			if a.modified_time ~= b.modified_time then
				return a.modified_time > b.modified_time
			end
			return a.value < b.value
		end
		return a.timestamp > b.timestamp
	end)

	local items = {}
	for _, entry in ipairs(entries) do
		table.insert(items, {
			display = entry.display,
			search_text = entry.ordinal,
			value = entry.value,
		})
	end

	local source_win = M._note_finder.source_win
	if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
		source_win = vim.api.nvim_get_current_win()
		M._note_finder.source_win = source_win
	end

	local prompt_title = string.format(
		"Note Files (%s  %s/%s: cycle)",
		resolved_recency.current.label,
		next_recency_shortcut.shortcut,
		previous_recency_shortcut.shortcut
	)

	M.float_picker.open({
		title = prompt_title,
		items = items,
		initial_index = resolve_finder_initial_index(M._note_finder, items, "NoteFinder"),
		initial_query = format_finder_initial_query(M._note_finder.sticky_query),
		anchor = "bottom",
		on_query_change = function(query)
			M._note_finder.sticky_query = extract_note_finder_sticky_query(query)
		end,
		on_select = function(item)
			if source_win and vim.api.nvim_win_is_valid(source_win) then
				vim.api.nvim_set_current_win(source_win)
			end
			M.open_buf(item.value, true)
		end,
		on_cancel = function()
			M._note_finder.opened = false
			M._note_finder.initial_index = nil
			M._note_finder.initial_value = nil
		end,
		mappings = {
			{
				key = delete_shortcut.shortcut,
				fn = function(item, close_fn, context)
					if not item then
						return
					end
					local selected_index = 1
					for idx, picker_item in ipairs(items) do
						if picker_item.value == item.value then
							selected_index = idx
							break
						end
					end

					context.skip_focus_restore = true
					context.note_finder_items = items
					context.suspend_for_external_ui()
					vim.defer_fn(function()
						M._prompt_note_finder_delete_confirmation(
							item.value,
							selected_index,
							#items,
							source_win,
							close_fn,
							context
						)
					end, 20)
				end,
			},
			{
				key = next_recency_shortcut.shortcut,
				fn = function(_, close_fn)
					local next_index, next_state = M._cycle_note_finder_recency(
						recency_config,
						M._note_finder.recency_index,
						"previous"
					)
					M._note_finder.recency_index = next_index
					M._note_finder.show_all = next_state.is_all
					close_fn()
					vim.defer_fn(function()
						M._note_finder.opened = false
						M._note_finder.source_win = source_win
						M.cmd.NoteFinder()
					end, 100)
				end,
			},
			{
				key = previous_recency_shortcut.shortcut,
				fn = function(_, close_fn)
					local next_index, next_state = M._cycle_note_finder_recency(
						recency_config,
						M._note_finder.recency_index,
						"next"
					)
					M._note_finder.recency_index = next_index
					M._note_finder.show_all = next_state.is_all
					close_fn()
					vim.defer_fn(function()
						M._note_finder.opened = false
						M._note_finder.source_win = source_win
						M.cmd.NoteFinder()
					end, 100)
				end,
			},
			{
				key = keybindings_shortcut.shortcut,
				fn = function(_, _)
					vim.schedule(function()
						M.cmd.KeyBindings()
					end)
				end,
			},
		},
	})

	M._note_finder.initial_index = nil
	M._note_finder.initial_value = nil
	M._note_finder.opened = false
end

M.cmd.ChatDirs = function(_params)
	M.chat_dir_picker.chat_dir_picker(M)
end

M.cmd.ChatMove = function(params)
	local file_name = vim.api.nvim_buf_get_name(0)
	local target_dir = params and params.args or ""

	if target_dir ~= "" then
		local new_file, err = M.move_chat(file_name, target_dir)
		if not new_file then
			vim.notify("Failed to move chat: " .. err, vim.log.levels.WARN)
			return
		end

		vim.notify("Moved chat to: " .. new_file, vim.log.levels.INFO)
		return
	end

	M.prompt_chat_move(file_name)
end

M.cmd.ChatDirAdd = function(params)
	local dir = params and params.args or ""
	if dir == "" then
		dir = vim.fn.input({
			prompt = "Add chat dir: ",
			default = vim.fn.getcwd() .. "/",
			completion = "dir",
		})
		vim.cmd("redraw")
	end

	if not dir or dir == "" then
		return
	end

	local normalized, err = M.add_chat_dir(dir, true)
	if not normalized then
		vim.notify("Failed to add chat dir: " .. err, vim.log.levels.WARN)
		return
	end

	local added_dir = normalized[#normalized]
	M.logger.info("Added chat dir: " .. added_dir)
	vim.notify("Added chat dir: " .. added_dir, vim.log.levels.INFO)
end

M.cmd.ChatDirRemove = function(params)
	local dir = params and params.args or ""
	if dir == "" then
		vim.notify("Usage: :" .. M.config.cmd_prefix .. "ChatDirRemove <dir>", vim.log.levels.WARN)
		return
	end

	local normalized, err = M.remove_chat_dir(dir, true)
	if not normalized then
		vim.notify("Failed to remove chat dir: " .. err, vim.log.levels.WARN)
		return
	end

	M.logger.info("Removed chat dir: " .. dir)
	vim.notify("Removed chat dir: " .. dir, vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Agent functionality
--------------------------------------------------------------------------------

M.cmd.Agent = function(params)
	local agent_name = string.gsub(params.args, "^%s*(.-)%s*$", "%1")

	-- If no arguments provided, show the agent picker
	if agent_name == "" then
		M.agent_picker.agent_picker(M)
		return
	end

	-- Handle specific agent selection by name
	if not M.agents[agent_name] then
		M.logger.warning("Unknown agent: " .. agent_name)
		return
	end

	M.refresh_state({ agent = agent_name })
	M.logger.info("Agent set to: " .. M._state.agent)
	vim.cmd("doautocmd User ParleyAgentChanged")
end

M.cmd.NextAgent = function()
	M.agent_picker.agent_picker(M)
end

-- System prompt selection command
M.cmd.SystemPrompt = function(params)
	local prompt_name = params and params.args or ""

	-- If no arguments provided, show the system prompt picker
	if prompt_name == "" then
		M.system_prompt_picker.system_prompt_picker(M)
		return
	end

	-- Handle specific system prompt selection by name
	if not M.system_prompts[prompt_name] then
		M.logger.warning("Unknown system prompt: " .. prompt_name)
		return
	end

	M.refresh_state({ system_prompt = prompt_name })
	M.logger.info("System prompt set to: " .. M._state.system_prompt)
	vim.cmd("doautocmd User ParleySystemPromptChanged")
end

M.cmd.NextSystemPrompt = function()
	M.system_prompt_picker.system_prompt_picker(M)
end

---@param name string | nil
---@return table # { cmd_prefix, name, model, system_prompt, provider }
-- Get basic agent information from agent configuration
M.get_agent = function(name)
	name = name or M._state.agent
	if M.agents[name] == nil then
		M.logger.warning("Agent " .. name .. " not found, using " .. M._state.agent)
		name = M._state.agent
	end
	local template = M.config.command_prompt_prefix_template
	local cmd_prefix = M.render.template(template, { ["{{agent}}"] = name })
	local model = M.agents[name].model
	local system_prompt = M.agents[name].system_prompt
	local provider = M.agents[name].provider
	-- M.logger.debug("getting agent: " .. name)
	return {
		cmd_prefix = cmd_prefix,
		name = name,
		model = model,
		system_prompt = system_prompt,
		provider = provider,
	}
end

-- Get combined agent information from both headers and agent config
-- This resolves the final provider, model, and other settings by merging header overrides with agent defaults
---@param headers table # The parsed headers from the chat file
---@param agent table # The agent configuration obtained from get_agent()
---@return table # A table containing the resolved agent information
-- Generate a default template for a new chat file
M.get_default_template = function(agent)
	local model = ""
	local provider = ""
	local system_prompt = ""

	-- If agent is provided, extract model and provider info
	if agent then
		if agent.model then
			model = agent.model
			if type(model) == "table" then
				model = "- model: " .. vim.json.encode(model) .. "\n"
			else
				model = "- model: " .. model .. "\n"
			end
		end

		if agent.provider then
			provider = "- provider: " .. agent.provider:gsub("\n", "\\n") .. "\n"
		end

		if agent.system_prompt then
			-- Use the selected system prompt from state instead of agent's system prompt
			local selected_system_prompt = M._state.system_prompt or "default"
			if M.system_prompts[selected_system_prompt] then
				system_prompt = "- system_prompt: " .. M.system_prompts[selected_system_prompt].system_prompt:gsub("\n", "\\n") .. "\n"
			else
				system_prompt = "- system_prompt: " .. agent.system_prompt:gsub("\n", "\\n") .. "\n"
			end
		end
	end

	-- Generate template using the same pattern as M.new_chat
	-- Get shortcuts, handling potentially missing values
	local respond_shortcut = M.config.chat_shortcut_respond and M.config.chat_shortcut_respond.shortcut or "<C-g><C-g>"
	local stop_shortcut = M.config.chat_shortcut_stop and M.config.chat_shortcut_stop.shortcut or "<C-g>s"
	local delete_shortcut = M.config.chat_shortcut_delete and M.config.chat_shortcut_delete.shortcut or "<C-g>d"
	local new_shortcut = M.config.global_shortcut_new and M.config.global_shortcut_new.shortcut or "<C-g>c"

	local template = M.render.template(M.config.chat_template or require("parley.defaults").chat_template, {
		["{{filename}}"] = "{{topic}}", -- Will be replaced later with actual topic
		["{{optional_headers}}"] = model .. provider .. system_prompt,
		["{{user_prefix}}"] = M.config.chat_user_prefix,
		["{{respond_shortcut}}"] = respond_shortcut,
		["{{cmd_prefix}}"] = M.config.cmd_prefix,
		["{{stop_shortcut}}"] = stop_shortcut,
		["{{delete_shortcut}}"] = delete_shortcut,
		["{{new_shortcut}}"] = new_shortcut,
	})

	return template
end

M.get_agent_info = function(headers, agent)
	local function parse_prompt_header(value)
		if type(value) ~= "string" then
			return nil
		end
		if not value:match("%S") then
			return nil
		end
		return value:gsub("\\n", "\n")
	end

	local function collect_appended_header_values(key)
		if type(headers) ~= "table" or type(headers._append) ~= "table" then
			return {}
		end
		local values = headers._append[key]
		if type(values) ~= "table" then
			return {}
		end
		return values
	end

	local function append_prompt_line(base, extra)
		if not base or base == "" then
			return extra .. "\n"
		end
		if base:sub(-1) ~= "\n" then
			base = base .. "\n"
		end
		return base .. extra .. "\n"
	end

	-- Get the selected system prompt from state, fallback to agent's system prompt
	local selected_system_prompt = M._state.system_prompt or "default"
	local system_prompt = M.system_prompts[selected_system_prompt]
			and M.system_prompts[selected_system_prompt].system_prompt
		or agent.system_prompt

	local info = {
		name = agent.name,
		provider = agent.provider,
		model = agent.model,
		system_prompt = system_prompt,
		display_name = agent.name,
	}

	-- Override with header values if they exist
	if headers then
		-- Provider from headers takes precedence
		if headers.provider then
			info.provider = headers.provider
		end

		-- Override model from headers
		if headers.model then
			-- If model is a JSON string, decode it
			if type(headers.model) == "string" and headers.model:match("{.*}") then
				-- If headers.model is a string containing JSON, parse it
				local success, decoded = pcall(vim.json.decode, headers.model)
				if success then
					info.model = decoded
				else
					-- If JSON parsing fails, use it as a string model name
					info.model = headers.model
					M.logger.warning("Failed to parse model JSON: " .. headers.model)
				end
			else
				info.model = headers.model
			end
		end

		-- Override system prompt from headers.
		-- Canonical key: system_prompt; role is kept as backward-compatible alias.
		local header_system_prompt = parse_prompt_header(headers.system_prompt) or parse_prompt_header(headers.role)
		if header_system_prompt then
			info.system_prompt = header_system_prompt
		end

		-- Append system prompt additions in-order.
		local append_values = collect_appended_header_values("system_prompt")
		if #append_values == 0 then
			append_values = collect_appended_header_values("role")
		end
		for _, prompt_append in ipairs(append_values) do
			local parsed_append = parse_prompt_header(prompt_append)
			if parsed_append then
				info.system_prompt = append_prompt_line(info.system_prompt, parsed_append)
			end
		end

		-- Update display name if model or role is overridden
		if headers.model then
			if type(info.model) == "table" and info.model.model then
				info.display_name = info.model.model
			else
				info.display_name = tostring(info.model)
			end

				if header_system_prompt or #append_values > 0 then
					info.display_name = info.display_name .. " & custom system prompt"
				end
			end

		-- Set a default provider if one is specified in header model but not provider
		if headers.model and not headers.provider then
			info.provider = info.provider or "openai"
		end
	end

	-- Check model validity - if it's not a string or a table, make it a string
	if type(info.model) ~= "string" and type(info.model) ~= "table" then
		info.model = tostring(info.model)
	end

	-- For OpenAI/string models, ensure they're well-formed for dispatcher.prepare_payload
	if type(info.model) == "string" then
		info.model = { model = info.model }
	end

	-- 	M.logger.debug("Resolved agent info: " .. vim.inspect(info))
	return info
end

return M
