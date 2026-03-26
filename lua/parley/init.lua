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

-- Interview mode module (loaded here; wired up via interview.setup() inside M.setup())
local interview = require("parley.interview")

-- Notes module (loaded here; wired up immediately since it only needs M reference)
local notes = require("parley.notes")
notes.setup(M)

-- Chat dirs module (loaded here; wired up immediately since it only needs M reference)
local chat_dirs = require("parley.chat_dirs")
chat_dirs.setup(M)
-- Local wrappers so all existing callers in init.lua work unchanged
local find_chat_root = function(f) return chat_dirs.find_chat_root(f) end
local find_chat_root_record = function(f) return chat_dirs.find_chat_root_record(f) end
local registered_chat_dir = function(d) return chat_dirs.registered_chat_dir(d) end
local chat_root_display = function(r, i) return chat_dirs.chat_root_display(r, i) end

-- Exporter module (loaded here; wired up at module-load time with M reference)
local exporter = require("parley.exporter")
exporter.setup(M)

-- Chat finder module (loaded here; wired up immediately since it only needs M reference)
local chat_finder_mod = require("parley.chat_finder")
chat_finder_mod.setup(M)

-- Note finder module (loaded here; wired up immediately since it only needs M reference)
local note_finder_mod = require("parley.note_finder")
note_finder_mod.setup(M)

-- Highlighter module (loaded here; wired up immediately since it only needs M reference)
local highlighter = require("parley.highlighter")
highlighter.setup(M)

-- Chat respond module (loaded here; wired up immediately since it only needs M reference)
local chat_respond = require("parley.chat_respond")
chat_respond.setup(M)

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

-- Passthroughs to chat_dirs module (see lua/parley/chat_dirs.lua)
-- Local helpers are defined as wrappers at the top of this file (near require).
-- apply_chat_roots / apply_chat_dirs / normalize_chat_roots accessed via chat_dirs.*
local apply_chat_roots = function(...) return chat_dirs.apply_chat_roots(...) end
local apply_chat_dirs = function(...) return chat_dirs.apply_chat_dirs(...) end
local normalize_chat_roots = function(...) return chat_dirs.normalize_chat_roots(...) end
local resolve_dir_key = function(d) return vim.fn.resolve(vim.fn.expand(d)):gsub("/+$", "") end

M.get_chat_roots = function() return chat_dirs.get_chat_roots() end
M.get_chat_dirs = function() return chat_dirs.get_chat_dirs() end
M.set_chat_dirs = function(d, p) return chat_dirs.set_chat_dirs(d, p) end
M.set_chat_roots = function(r, p) return chat_dirs.set_chat_roots(r, p) end
M.add_chat_dir = function(d, p, l) return chat_dirs.add_chat_dir(d, p, l) end
M.remove_chat_dir = function(d, p) return chat_dirs.remove_chat_dir(d, p) end
M.rename_chat_dir = function(d, l, p) return chat_dirs.rename_chat_dir(d, l, p) end


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

-- Forward declaration so setup() closure can reference it (defined after setup())
local show_keybindings

-- setup function
M._setup_called = false
---@param opts the one returned from config.lua, it can come from several sources, either fully specified
---            in ~/.config/nvim/lua/parley/config.lua, or partially overrides from ~/.config/nvim/lua/plugins/parley.lua
M.setup = function(opts)
	M._setup_called = true

	math.randomseed(os.time())

	-- Wire up interview module with shared state/logger references
	interview.setup(M, M.logger)

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
		interview.toggle()
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
		show_keybindings()
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
	interview.stop_timer()

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
M._remote_reference_cache_file = function() return chat_respond.remote_reference_cache_file() end
M._load_remote_reference_cache = function() return chat_respond.load_remote_reference_cache() end
M._save_remote_reference_cache = function() return chat_respond.save_remote_reference_cache() end
M._get_chat_remote_reference_cache = function(f) return chat_respond.get_chat_remote_reference_cache(f) end
M._format_remote_reference_error_content = function(u, e) return chat_respond.format_remote_reference_error_content(u, e) end
M._format_missing_remote_reference_cache_content = function(u) return chat_respond.format_missing_remote_reference_cache_content(u) end

-- stop receiving responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.cmd.Stop = function(s) chat_respond.cmd_stop(s) end

--------------------------------------------------------------------------------
-- Keybinding help
--------------------------------------------------------------------------------

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

local function keybinding_help_lines()
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
		resolve_shortcut("Parley prompt Chat Stop", shortcut_modes(cfg.chat_shortcut_stop, { "n", "i", "v", "x" }), cfg.chat_shortcut_stop, "<C-g>x", current_buf),
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
		"Delete chat / file"
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
			"<C-g>s",
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
			"Parley prompt Search Chat Sections",
			shortcut_modes(cfg.chat_shortcut_search, { "n", "i", "v", "x" }),
			cfg.chat_shortcut_search,
			"<C-g>n",
			current_buf
		),
		"Search chat sections"
	)
	add(
		resolve_shortcut(
			"Parley create and insert new chat",
			{ "n", "i" },
			nil,
			"<C-g>i",
			current_buf
		),
		"Insert new chat reference"
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

M._keybinding_help_lines = function()
	return keybinding_help_lines()
end

show_keybindings = function()
	local lines = keybinding_help_lines()
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

-- Enhanced markdown to HTML converter with glow-like styling (delegated to exporter)
M.simple_markdown_to_html = function(markdown)
	return exporter.simple_markdown_to_html(markdown)
end

-- Export current chat buffer as HTML (delegated to exporter)
M.cmd.ExportHTML = function(params)
	exporter.export_html(params)
end


-- Export current chat buffer as Markdown for Jekyll (delegated to exporter)
M.cmd.ExportMarkdown = function(params)
	exporter.export_markdown(params)
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
	highlighter.display_agent(buf, file_name)
end

--- Build display label for an agent, including web_search indicator suffix.
---@param agent_name string
---@param ag_conf table|nil
---@return string
M.agent_display_name_with_web_search = function(agent_name, ag_conf)
	return highlighter.agent_display_name_with_web_search(agent_name, ag_conf)
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

	-- <C-g>i: create and insert new child chat branch reference (normal + insert mode)
	-- Always inserts as a standalone 🌿: line after the current line.
	local function insert_branch_ref()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":~:.")
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1], cursor_pos[1], false, {
			branch_prefix .. " " .. rel_path .. ": ",
		})
		vim.api.nvim_win_set_cursor(0, { cursor_pos[1] + 1, 0 })
		-- Enter insert mode at end of line so user can type the topic immediately
		vim.schedule(function() vim.cmd("startinsert!") end)
		M.logger.info("Created branch reference to new chat: " .. rel_path)
	end
	M.helpers.set_keymap({ buf }, "n", "<C-g>i", insert_branch_ref, "Parley create and insert new chat")
	M.helpers.set_keymap({ buf }, "i", "<C-g>i", function()
		vim.cmd("stopinsert")
		insert_branch_ref()
	end, "Parley create and insert new chat")

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
	local basename = vim.fn.fnamemodify(file_path, ":t")

	if not basename:match("^%d%d%d%d%-%d%d%-%d%d") then
		return nil
	end

	local function get_open_buf_lines()
		local target = vim.fn.resolve(file_path)
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if buf_name ~= "" and vim.fn.resolve(buf_name) == target then
					return vim.api.nvim_buf_get_lines(buf, 0, 20, false), true
				end
			end
		end
		return nil, false
	end

	if cache_entry and stat_mtime then
		local cache_sec = cache_entry.mtime and cache_entry.mtime.sec or 0
		local cache_nsec = cache_entry.mtime and cache_entry.mtime.nsec or 0
		local stat_sec = stat_mtime.sec or 0
		local stat_nsec = stat_mtime.nsec or 0
		if cache_sec == stat_sec and cache_nsec == stat_nsec and not cache_entry.from_buffer then
			return cache_entry.topic
		end
	end

	local lines, from_buffer = get_open_buf_lines()
	if not lines then
		lines = vim.fn.readfile(file_path, "", 20)
		from_buffer = false
	end
	local headers = parse_chat_headers(lines)
	local topic = nil
	if headers and headers.topic and headers.topic ~= "" and headers.file and headers.file ~= "" then
		topic = headers.topic
	end

	M._chat_topic_cache[file_path] = {
		mtime = stat_mtime or { sec = 0, nsec = 0 },
		topic = topic,
		from_buffer = from_buffer,
	}

	return topic
end

-- Define namespace and highlighting colors for questions, annotations, and thinking
M.setup_highlight = function()
	return highlighter.setup_highlights()
end

-- Buffers tracked for decoration provider: { [bufnr] = "chat" | "markdown" }
M._parley_bufs = {}

-- Refresh topic labels for chat references in non-chat markdown files.
M.highlight_markdown_chat_refs = function(buf)
	highlighter.highlight_markdown_chat_refs(buf)
end

M.highlight_chat_branch_refs = function(buf)
	highlighter.highlight_chat_branch_refs(buf)
end

-- Apply highlighting to chat blocks in the current buffer.
-- Simple clear-and-apply; used by tests on scratch buffers.
-- Production highlighting is handled by the decoration provider.
M.highlight_question_block = function(buf)
	highlighter.highlight_question_block(buf)
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

	-- Add <C-g>i keybinding to create and insert new chat
	-- Normal mode implementation
	M.helpers.set_keymap({ buf }, "n", "<C-g>i", function()
		-- Get the current cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(0)

		-- Create a new chat file path (timestamp format only)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":~:.")

		-- Insert the chat reference at the cursor position
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1] - 1, cursor_pos[1] - 1, false, {
			"@@" .. rel_path .. "@@",
		})

		M.logger.info("Created reference to new chat: " .. rel_path)
	end, "Parley create and insert new chat")

	-- Insert mode implementation
	M.helpers.set_keymap({ buf }, "i", "<C-g>i", function()
		-- Get the current cursor position
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local current_line = vim.api.nvim_get_current_line()

		-- Create a new chat file path (timestamp format only)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":~:.")

		-- Insert the chat reference at the current cursor position
		local col = cursor_pos[2]
		local new_line = current_line:sub(1, col) .. "@@" .. rel_path .. "@@" .. current_line:sub(col + 1)
		vim.api.nvim_set_current_line(new_line)

		-- Return to insert mode at the end of the inserted reference
		vim.api.nvim_win_set_cursor(0, { cursor_pos[1], col + #("@@" .. rel_path .. "@@") })

		-- Make sure we stay in insert mode
		vim.schedule(function()
			vim.cmd("startinsert")
		end)

		M.logger.info("Created reference to new chat: " .. rel_path)
	end, "Parley create and insert new chat")

	-- Add <C-g>d keybinding to delete current file and buffer
	M.helpers.set_keymap({ buf }, "n", "<C-g>d", function()
		local file = vim.api.nvim_buf_get_name(buf)
		if file ~= "" then
			local rel = vim.fn.fnamemodify(file, ":~:.")
			local choice = vim.fn.confirm("Delete " .. rel .. "?", "&Yes\n&No", 2)
			if choice == 1 then
				M.helpers.delete_file(file)
			end
		end
	end, "Parley delete current file and buffer")
end

M.setup_buf_handler = function()
	highlighter.setup_buf_handler()
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

-- registered_chat_dir and chat_root_display are local wrappers defined at top of file.

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
	local question = "proof read the following file:\n\n@@" .. file_path .. "@@"
	return M.new_chat(nil, nil, question)
end

-- Function to create a new note
M.cmd.NoteNew = function()
	notes.cmd_note_new()
end

-- Create default templates in the templates directory
M.create_default_templates = function(template_dir)
	notes.create_default_templates(template_dir)
end

-- Function to create a new note from template
M.cmd.NoteNewFromTemplate = function()
	notes.cmd_note_new_from_template()
end

-- Internal helper: create a note file with a title and metadata (array of {key, value})
M._create_note_file = function(...)
	return notes._create_note_file_impl(...)
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

-- Create a new note with given subject
M.new_note = function(subject)
	return notes.new_note(subject)
end

-- Create a new note from template with given subject and template content
M.new_note_from_template = function(subject, template_content, template_filename)
	return notes.new_note_from_template(subject, template_content, template_filename)
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

M._build_messages = function(opts) return chat_respond.build_messages(opts) end

M._resolve_remote_references = function(opts, cb) return chat_respond.resolve_remote_references(opts, cb) end

M.chat_respond = function(p, cb, ofc, f) return chat_respond.respond(p, cb, ofc, f) end

M.chat_respond_all = function() return chat_respond.respond_all() end

M.resubmit_questions_recursively = function(...) return chat_respond.resubmit_questions_recursively(...) end

M.cmd.ChatRespond = function(p) chat_respond.cmd_respond(p) end

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

-- Internal: Parse @@ref@@ references from a line and return the closest one to cursor.
-- Canonical form: @@<ref>@@ with explicit closing marker. Pure function for testability.
M._parse_at_reference = function(line, cursor_col)
	local references = {}
	local start_idx = 1
	while true do
		local open_start, open_end = line:find("@@", start_idx, true)
		if not open_start then break end
		local close_start, close_end = line:find("@@", open_end + 1, true)
		if not close_start then break end
		local content = line:sub(open_end + 1, close_start - 1):gsub("^%s*(.-)%s*$", "%1")
		if content ~= "" then
			table.insert(references, { start = open_start, content = content })
		end
		start_idx = close_end + 1
	end

	if #references == 0 then return nil end

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
		-- Extract the chat path: prefer @@ref@@ form, then @@path: topic (strip topic), then rest of line
		chat_path = current_line:match("^@@%s*([^@]+)@@")
			or current_line:match("^@@%s*([^:]+):")
			or current_line:match("^@@(.+)$")

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
			local template = M.get_default_template(agent, expanded_path)
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
		-- Try to open as a chat reference; return regardless (success or not) since
		-- the markdown handler owns this case
		M.open_chat_reference(current_line, cursor_col, in_insert_mode, current_line)
		return
	end

	-- If not a markdown file or not a chat reference, check if it's a chat file
	if M.not_chat(buf, file_name) then
		M.logger.warning("OpenFileUnderCursor command is only available in chat files and markdown files")
		return
	end

	-- Handle 🌿: branch reference lines
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"
	if current_line:sub(1, #branch_prefix) == branch_prefix then
		local rest = current_line:sub(#branch_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
		-- format: "filename.md: topic" — extract path before the first ":"
		local path = rest:match("^([^:]+)") or rest
		path = path:gsub("^%s*(.-)%s*$", "%1")
		if path ~= "" then
			local expanded = vim.fn.expand(path)
			if vim.fn.filereadable(expanded) == 1 then
				M.open_buf(expanded)
			elseif expanded:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
				-- New chat file — extract topic from line and create from template
				local topic = rest:match("^[^:]+:%s*(.+)$") or "New chat"
				topic = topic:gsub("^%s*(.-)%s*$", "%1")
				if topic == "" then topic = "New chat" end
				local agent = M.get_agent()
				M.helpers.prepare_dir(vim.fn.fnamemodify(expanded, ":h"))
				local template = M.get_default_template(agent, expanded)
				template = template:gsub("{{topic}}", topic)
				local file_lines = vim.split(template, "\n")

				-- Insert parent back-link as first transcript line
				local chat_parser = require("parley.chat_parser")
				local header_end = chat_parser.find_header_end(file_lines)
				if header_end then
					local parent_path = vim.api.nvim_buf_get_name(buf)
					local parent_rel = vim.fn.fnamemodify(parent_path, ":~:.")
					local parent_topic = M.get_chat_topic(parent_path) or ""
					local back_link = branch_prefix .. " " .. parent_rel .. ": " .. parent_topic
					table.insert(file_lines, header_end + 1, back_link)
				end

				vim.fn.writefile(file_lines, expanded)
				M.open_buf(expanded)
			else
				M.logger.warning("Chat file not found: " .. expanded)
			end
		else
			M.logger.warning("Could not extract path from branch reference line")
		end
		return
	end

	-- Process standard @@ file references in chat files
	local filepath

	-- First check if the line begins with @@
	if current_line:match("^@@") then
		filepath = (current_line:match("^@@(.+)@@") or current_line:match("^@@(.+)$")):gsub("^%s*(.-)%s*$", "%1")
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
				local template = M.get_default_template(agent, expanded_path)
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

-- Passthroughs: recency helpers (called by tests and internally)
M._resolve_chat_finder_recency = function(...) return chat_finder_mod.resolve_finder_recency(...) end
M._resolve_note_finder_recency = function(...) return chat_finder_mod.resolve_finder_recency(...) end
M._cycle_chat_finder_recency = function(...) return chat_finder_mod.cycle_finder_recency(...) end
M._cycle_note_finder_recency = function(...) return chat_finder_mod.cycle_finder_recency(...) end

M._reopen_chat_finder = function(source_win, selection_index, selection_value)
	chat_finder_mod.reopen(source_win, selection_index, selection_value)
end

M._handle_chat_finder_delete_response = function(...)
	chat_finder_mod.handle_delete_response(...)
end

M._prompt_chat_finder_delete_confirmation = function(...)
	chat_finder_mod.prompt_delete_confirmation(...)
end

M._reopen_note_finder = function(source_win, selection_index, selection_value)
	note_finder_mod.reopen(source_win, selection_index, selection_value)
end

M._handle_note_finder_delete_response = function(...)
	note_finder_mod.handle_delete_response(...)
end

M._prompt_note_finder_delete_confirmation = function(...)
	note_finder_mod.prompt_delete_confirmation(...)
end

M.cmd.ChatFinder = function(opts) chat_finder_mod.open(opts) end


M.cmd.NoteFinder = function(opts) note_finder_mod.open(opts) end


M.cmd.ChatDirs = function(p) chat_dirs.cmd_chat_dirs(p) end
M.cmd.ChatMove = function(p) chat_dirs.cmd_chat_move(p) end
M.cmd.ChatDirAdd = function(p) chat_dirs.cmd_chat_dir_add(p) end
M.cmd.ChatDirRemove = function(p) chat_dirs.cmd_chat_dir_remove(p) end

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
M.get_default_template = function(agent, file_path)
	local model = ""
	local provider = ""
	local system_prompt = ""
	local basename = file_path and vim.fn.fnamemodify(file_path, ":t") or "{{filename}}"

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
	local stop_shortcut = M.config.chat_shortcut_stop and M.config.chat_shortcut_stop.shortcut or "<C-g>x"
	local delete_shortcut = M.config.chat_shortcut_delete and M.config.chat_shortcut_delete.shortcut or "<C-g>d"
	local new_shortcut = M.config.global_shortcut_new and M.config.global_shortcut_new.shortcut or "<C-g>c"

	local template = M.render.template(M.config.chat_template or require("parley.defaults").chat_template, {
		["{{filename}}"] = basename,
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
