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

-- Chat slug module for filename slug generation and parsing
local chat_slug = require("parley.chat_slug")

-- Custom system prompts persistence (loaded here; wired up via custom_prompts.setup() inside M.setup())
local custom_prompts = require("parley.custom_prompts")

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

-- Memory preferences module (loaded here; wired up immediately since it only needs M reference)
local memory_prefs = require("parley.memory_prefs")
memory_prefs.setup(M)

-- Issues module (loaded here; wired up immediately since it only needs M reference)
local issues_mod = require("parley.issues")
issues_mod.setup(M)

-- Issue finder module
local issue_finder_mod = require("parley.issue_finder")
issue_finder_mod.setup(M)

-- Vision tracker module
local vision_mod = require("parley.vision")
vision_mod.setup(M)

-- Vision finder module
local vision_finder_mod = require("parley.vision_finder")
vision_finder_mod.setup(M)

-- Keybinding registry (scope hierarchy, entries, help generation, registration)
local kb_registry = require("parley.keybinding_registry")

-- Exporter module (loaded here; wired up at module-load time with M reference)
local exporter = require("parley.exporter")
exporter.setup(M)

local exchange_clipboard = require("parley.exchange_clipboard")

-- Chat finder module (loaded here; wired up immediately since it only needs M reference)
local chat_finder_mod = require("parley.chat_finder")
chat_finder_mod.setup(M)

-- Note finder module (loaded here; wired up immediately since it only needs M reference)
local note_finder_mod = require("parley.note_finder")
note_finder_mod.setup(M)

-- Markdown finder module
local markdown_finder_mod = require("parley.markdown_finder")
markdown_finder_mod.setup(M)

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

	-- Register builtin tool-use tools (M1 of #81). Runs before any
	-- agent validation so agents can reference tools by name. The
	-- registry module handles reset-idempotence internally.
	require("parley.tools").register_builtins()

	local curl_params = opts.curl_params or M.config.curl_params
		local state_dir = opts.state_dir or M.config.state_dir

	M.logger.setup(opts.log_file or M.config.log_file, opts.log_sensitive)

	M.vault.setup({ state_dir = state_dir, curl_params = curl_params })
	custom_prompts.setup(M.helpers, state_dir)

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

	-- Detect parley-enabled repo via marker file and set up repo-local directories
	-- Skip if user explicitly set chat_dir in opts (e.g. tests)
	local function apply_repo_local()
		if opts.chat_dir then return end

		local marker = M.config.repo_marker
		if not marker then return end

		local git_root = M.helpers.find_git_root(vim.fn.getcwd())
		if git_root == "" then return end

		local marker_path = git_root .. "/" .. marker
		if vim.fn.filereadable(marker_path) ~= 1 then return end

		M.config.repo_root = git_root

		-- Ensure repo-local directories exist
		local repo_dirs = { M.config.repo_chat_dir, M.config.issues_dir, M.config.vision_dir, M.config.history_dir }
		for _, dir in ipairs(repo_dirs) do
			if dir and dir ~= "" and not dir:match("^/") then
				M.helpers.prepare_dir(git_root .. "/" .. dir, "repo")
			end
		end

		-- Prepend repo chat dir as primary, demoting global chat_dir to extra
		if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
			local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
			local old_dir = M.config.chat_dir
			local old_dirs = M.config.chat_dirs

			M.config.chat_dir = repo_chat
			-- Preserve existing dirs as extras
			local extras = {}
			if type(old_dirs) == "table" and #old_dirs > 0 then
				extras = vim.deepcopy(old_dirs)
			end
			if old_dir and old_dir ~= repo_chat then
				table.insert(extras, 1, old_dir)
			end
			M.config.chat_dirs = extras
			M.config.chat_roots = {}
		end

		-- Disable chat memory and memory prefs for repo-local chats
		if type(M.config.chat_memory) == "table" then
			M.config.chat_memory.enable = false
		end
		if type(M.config.memory_prefs) == "table" then
			M.config.memory_prefs.enable = false
		end
	end
	apply_repo_local()

	apply_chat_roots(normalize_chat_roots(M.config.chat_dir, M.config.chat_dirs, M.config.chat_roots))

	-- repo-local dirs (issues, history, vision) are resolved in apply_repo_local
	-- against git root; skip them here to avoid creating in CWD
	local skip_prepare = { chat_dir = true, repo_chat_dir = true, issues_dir = true, history_dir = true, vision_dir = true }
	for k, v in pairs(M.config) do
		if not skip_prepare[k] and k:match("_dir$") and type(v) == "string" then
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
	local tools_mod = require("parley.tools")
	for name, _ in pairs(M.agents) do
		M.agents[name].provider = M.agents[name].provider or "openai"

		if M.dispatcher.providers[M.agents[name].provider] then
			-- Validate per-agent tool-use config (M1 of #81). Agents opting
			-- into client-side tool use must reference only registered
			-- builtin names. Unknown names raise with the offending name.
			-- Defaults for max_tool_iterations and tool_result_max_bytes
			-- are applied here, not on vanilla agents (byte-identity lock).
			local agent = M.agents[name]
			if agent.tools and #agent.tools > 0 then
				-- `tools_mod.select` raises on unknown names
				local ok, err = pcall(tools_mod.select, agent.tools)
				if not ok then
					error(string.format("agent %q: %s", name, tostring(err)))
				end
				agent.max_tool_iterations = agent.max_tool_iterations or 20
				agent.tool_result_max_bytes = agent.tool_result_max_bytes or 102400
			end

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

	-- snapshot builtin prompts (after config merge and disabled removal)
	M._builtin_system_prompts = vim.deepcopy(M.system_prompts)

	-- merge custom (user-edited) prompts over builtins
	local user_prompts = custom_prompts.load()
	for name, prompt in pairs(user_prompts) do
		if type(prompt) == "table" and prompt.system_prompt then
			M.system_prompts[name] = prompt
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

	-- Register all global keymaps from the keybinding registry
	kb_registry.register_global(
		{ "global", "repo", "note", "issue", "vision", "chat" },
		M.config,
		{
			help = function() M.cmd.KeyBindings() end,
			chat_new = function() M.cmd.ChatNew({}) end,
			chat_finder = function() M.cmd.ChatFinder() end,
			chat_dirs = function() M.cmd.ChatDirs({}) end,
			chat_review = function() M.cmd.ChatReview({}) end,
			note_new = function() M.cmd.NoteNew() end,
			note_finder = function() M.cmd.NoteFinder({}) end,
			year_root = function()
				local current_year = os.date("%Y")
				local year_dir = M.config.notes_dir .. "/" .. current_year
				M.helpers.prepare_dir(year_dir, "year")
				vim.cmd("cd " .. year_dir)
			end,
			markdown_finder = function() M.cmd.MarkdownFinder() end,
			oil = function()
				local ok, oil = pcall(require, "oil")
				if ok then
					oil.open()
				else
					M.logger.error("oil.nvim is not installed. Please install it with your package manager.")
				end
			end,
			copy_location = function() M.cmd.CopyLocation() end,
			copy_location_content = function() M.cmd.CopyLocationContent() end,
			copy_context = function() M.cmd.CopyContext() end,
			copy_context_wide = function() M.cmd.CopyContextWide() end,
			review_finder = function() require("parley.skills.review").cmd_review_finder() end,
			skill_picker = function() require("parley.skill_picker").open() end,
			-- Repo scope
			issue_new = function() M.cmd.IssueNew() end,
			issue_finder = function() M.cmd.IssueFinder({}) end,
			issue_next = function() M.cmd.IssueNext() end,
			-- Issue scope (globally registered, shown in issue context)
			issue_status = function() M.cmd.IssueStatus() end,
			issue_decompose = function() M.cmd.IssueDecompose() end,
			issue_goto = function() M.cmd.IssueGoto() end,
			-- Vision scope
			vision_finder = function() M.cmd.VisionShow() end,
			vision_new = function() M.cmd.VisionNew() end,
			vision_goto = function() M.cmd.VisionGoto() end,
			vision_validate = function() M.cmd.VisionValidate() end,
			vision_export_csv = function() M.cmd.VisionExportCsv({}) end,
			vision_export_dot = function() M.cmd.VisionExportDot({}) end,
			vision_allocation = function() M.cmd.VisionAllocation({}) end,
			-- Note scope (globally registered)
			interview_start = function() M.cmd.EnterInterview() end,
			interview_stop = function() M.cmd.ExitInterview() end,
			note_template = function() M.cmd.NoteNewFromTemplate() end,
			-- Chat scope (globally registered toggles)
			chat_toggle_web_search = function() vim.cmd(M.config.cmd_prefix .. "ToggleWebSearch") end,
			chat_toggle_raw_request = function() vim.cmd(M.config.cmd_prefix .. "ToggleRawRequest") end,
			chat_toggle_raw_response = function() vim.cmd(M.config.cmd_prefix .. "ToggleRawResponse") end,
		}
	)

	-- Set up typeahead completion for vision YAML files
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		pattern = "*.yaml",
		callback = function(ev)
			local vision_dir = M.config.vision_dir
			if not vision_dir or vision_dir == "" then return end
			local git_root = M.helpers.find_git_root(vim.fn.getcwd())
			if git_root == "" then git_root = vim.fn.getcwd() end
			local abs_vision = vim.fn.resolve(git_root .. "/" .. vision_dir)
			local file_dir = vim.fn.resolve(vim.fn.fnamemodify(ev.file, ":p:h"))
			if file_dir:sub(1, #abs_vision) == abs_vision then
				-- Disable nvim-cmp for vision YAML buffers
				local cmp_ok, cmp = pcall(require, "cmp")
				if cmp_ok and cmp then
					cmp.setup.buffer({ enabled = false })
				end
				vim.api.nvim_create_autocmd("TextChangedI", {
					buffer = ev.buf,
					callback = function()
						vision_mod.on_text_changed_i(ev.buf)
					end,
				})
			end
		end,
	})

	-- Set up typeahead completion for status: field in issue files
	vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
		pattern = "*.md",
		callback = function(ev)
			local issues_dir = M.config.issues_dir
			if not issues_dir or issues_dir == "" then return end
			local git_root = M.helpers.find_git_root(vim.fn.getcwd())
			if git_root == "" then git_root = vim.fn.getcwd() end
			local abs_issues = vim.fn.resolve(git_root .. "/" .. issues_dir)
			local file_dir = vim.fn.resolve(vim.fn.fnamemodify(ev.file, ":p:h"))
			if file_dir:sub(1, #abs_issues) == abs_issues then
				vim.api.nvim_create_autocmd("TextChangedI", {
					buffer = ev.buf,
					callback = function()
						local line = vim.api.nvim_get_current_line()
						local row = vim.api.nvim_win_get_cursor(0)[1]
						-- Only complete within frontmatter on status: lines
						if row > 10 or not line:match("^status:%s*") then return end
						local prefix_end = line:find(":%s*")
						if not prefix_end then return end
						local col = prefix_end + (line:sub(prefix_end + 1, prefix_end + 1) == " " and 1 or 0)
						local partial = line:sub(col + 1)
						local matches = {}
						for _, s in ipairs(issues_mod.status_values) do
							if s:sub(1, #partial) == partial then
								table.insert(matches, s)
							end
						end
						if #matches == 0 then return end
						local saved = vim.o.completeopt
						vim.o.completeopt = "menuone,noinsert,noselect"
						vim.fn.complete(col + 1, matches)
						vim.defer_fn(function() vim.o.completeopt = saved end, 100)
					end,
				})
			end
		end,
	})

	-- Auto-rename chat files to include slug from topic header
	local slug_augroup = vim.api.nvim_create_augroup("ParleySlug", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = slug_augroup,
		pattern = "*.md",
		callback = function(ev)
			-- Guard: skip if we're already inside a slug rename (prevents recursion)
			if M._in_slug_rename then
				return
			end
			local buf = ev.buf
			local file = vim.api.nvim_buf_get_name(buf)
			-- Only for chat files in configured roots
			if M.not_chat(buf, file) then
				return
			end
			M._slug_rename_chat(buf)
		end,
	})

	-- Interview mode and note template keymaps now registered via kb_registry.register_global above

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

	-- Interview Mode commands
	M.cmd.EnterInterview = function()
		interview.enter()
	end
	M.cmd.ExitInterview = function()
		interview.exit()
	end
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

	M.cmd.KeyBindings = function(context)
		show_keybindings(context)
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
	-- Toggle keymaps (web_search, raw request/response) now registered via kb_registry.register_global above

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

	-- Prewarm finder caches in the background (deferred, non-blocking)
	chat_finder_mod.prewarm()
	note_finder_mod.prewarm()

	-- Auto-generate memory preferences if enabled and stale
	memory_prefs.maybe_generate()

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

	-- In repo mode, ensure repo chat dir is the primary root (overrides persisted state)
	if M.config.repo_root and M.config.repo_chat_dir then
		local repo_chat = M.config.repo_root .. "/" .. M.config.repo_chat_dir
		local resolved_repo = vim.fn.resolve(vim.fn.expand(repo_chat)):gsub("/+$", "")
		local current_roots = M.get_chat_roots()
		local already_primary = #current_roots > 0
			and vim.fn.resolve(vim.fn.expand(current_roots[1].dir)):gsub("/+$", "") == resolved_repo

		if not already_primary then
			-- Remove repo_chat from extras if present, then prepend as primary
			local new_roots = { { dir = repo_chat, label = "repo" } }
			for _, root in ipairs(current_roots) do
				if vim.fn.resolve(vim.fn.expand(root.dir)):gsub("/+$", "") ~= resolved_repo then
					table.insert(new_roots, root)
				end
			end
			apply_chat_roots(new_roots)
			M._state.chat_roots = vim.deepcopy(M.get_chat_roots())
			M._state.chat_dirs = vim.deepcopy(M.get_chat_dirs())
		end
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

	-- Repo-mode roots are transient (determined by cwd + marker at startup).
	-- Never persist them — otherwise a later session with a different cwd
	-- restores repo roots it shouldn't have access to.
	local persist_state = vim.deepcopy(M._state)
	if type(persist_state.chat_roots) == "table" then
		local filtered = {}
		for _, root in ipairs(persist_state.chat_roots) do
			if root.label ~= "repo" then
				table.insert(filtered, root)
			end
		end
		persist_state.chat_roots = #filtered > 0 and filtered or nil
	end
	-- Rebuild chat_dirs from filtered chat_roots to keep them in sync
	if type(persist_state.chat_roots) == "table" then
		local dirs = {}
		for _, root in ipairs(persist_state.chat_roots) do
			table.insert(dirs, root.dir)
		end
		persist_state.chat_dirs = #dirs > 0 and dirs or nil
	else
		persist_state.chat_dirs = nil
	end
	M.helpers.table_to_file(persist_state, state_file)

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
-- Keybinding help (driven by keybinding_registry)
--------------------------------------------------------------------------------

-- Detect the buffer context for scoped keybinding help.
-- Returns a scope from the registry forest.
local function detect_buffer_context(buf)
	local file_name = vim.api.nvim_buf_get_name(buf)
	if not M.not_chat(buf, file_name) then
		return "chat"
	end
	if M.is_markdown(buf, file_name) then
		local resolved = vim.fn.resolve(vim.fn.fnamemodify(file_name, ":p"))
		-- Check note
		local notes_dir = M.config.notes_dir
		if notes_dir and notes_dir ~= "" then
			local norm_notes = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(notes_dir), ":p"))
			if not norm_notes:match("/$") then norm_notes = norm_notes .. "/" end
			if resolved:sub(1, #norm_notes) == norm_notes then
				return "note"
			end
		end
		-- Check issue
		local issues = require("parley.issues")
		local issues_dir = issues.get_issues_dir()
		if issues_dir then
			local norm_issues = vim.fn.resolve(vim.fn.fnamemodify(issues_dir, ":p"))
			if not norm_issues:match("/$") then norm_issues = norm_issues .. "/" end
			if resolved:sub(1, #norm_issues) == norm_issues then
				return "issue"
			end
		end
		return "markdown"
	end
	-- Check vision YAML
	if file_name:match("%.yaml$") or file_name:match("%.yml$") then
		local vision_dir = M.config.vision_dir
		if vision_dir and vision_dir ~= "" then
			local git_root = M.helpers.find_git_root(vim.fn.getcwd())
			if git_root ~= "" then
				local abs_vision = vim.fn.resolve(git_root .. "/" .. vision_dir)
				local resolved = vim.fn.resolve(vim.fn.fnamemodify(file_name, ":p"))
				if not abs_vision:match("/$") then abs_vision = abs_vision .. "/" end
				if resolved:sub(1, #abs_vision) == abs_vision then
					return "vision"
				end
			end
		end
	end
	-- Check if in a repo (has .parley marker)
	local git_root = M.helpers.find_git_root(vim.fn.getcwd())
	if git_root ~= "" then
		local marker = git_root .. "/" .. (M.config.repo_marker or ".parley")
		if vim.fn.filereadable(marker) == 1 then
			return "repo"
		end
	end
	return "other"
end

M._detect_buffer_context = detect_buffer_context

local function keybinding_help_lines(context)
	local cfg = M.config or {}
	local current_buf = vim.api.nvim_get_current_buf()
	context = context or detect_buffer_context(current_buf)
	return kb_registry.help_lines(context, cfg, current_buf)
end

M._keybinding_help_lines = function(context)
	return keybinding_help_lines(context)
end

show_keybindings = function(context)
	local lines = keybinding_help_lines(context)
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

	-- Set up tool block folding (clickable foldcolumn icons)
	require("parley.tool_folds").setup(buf)

	if M.config.chat_prompt_buf_type then
		vim.api.nvim_set_option_value("buftype", "prompt", { buf = buf })
		vim.fn.prompt_setprompt(buf, "")
		vim.fn.prompt_setcallback(buf, function()
			M.cmd.ChatRespond({ args = "" })
		end)
	end

	-- Register chat buffer-local keymaps from registry
	-- Helper: make respond callback for a given command name
	local function make_respond_cb(command_name)
		local cmd_str = M.config.cmd_prefix .. command_name
		local range_cmd = ":<C-u>'<,'>" .. cmd_str .. "<cr>"
		return {
			n = function()
				vim.api.nvim_command(cmd_str)
				vim.api.nvim_command("stopinsert")
				M.helpers.feedkeys("<esc>", "xn")
			end,
			i = function()
				vim.api.nvim_command(cmd_str)
				vim.api.nvim_command("stopinsert")
				M.helpers.feedkeys("<esc>", "xn")
			end,
			v = range_cmd,
			x = range_cmd,
		}
	end

	-- Branch ref helpers (chat-specific: uses relative path)
	local function chat_insert_branch_ref()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":t")
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1], cursor_pos[1], false, {
			branch_prefix .. " " .. rel_path .. ": ",
		})
		vim.api.nvim_win_set_cursor(0, { cursor_pos[1] + 1, 0 })
		vim.schedule(function() vim.cmd("startinsert!") end)
		M.logger.info("Created branch reference to new chat: " .. rel_path)
		M.highlight_chat_branch_refs(buf)
	end

	local function chat_insert_inline_branch_ref()
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local start_line, start_col = start_pos[2], start_pos[3]
		local end_line, end_col = end_pos[2], end_pos[3]
		if start_line ~= end_line then
			M.logger.warning("Inline branch links only support single-line selections")
			return
		end
		local line = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1]
		local selected_text = line:sub(start_col, end_col)
		if selected_text == "" then
			M.logger.warning("No text selected")
			return
		end
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":t")
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		local topic = 'what is "' .. selected_text .. '"'
		local before = line:sub(1, start_col - 1)
		local after = line:sub(end_col + 1)
		local inline_link = "[" .. branch_prefix .. selected_text .. "](" .. rel_path .. ")"
		vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, { before .. inline_link .. after })
		M.create_child_chat(new_chat_file, topic, buf, topic .. "?")
		M.logger.debug("Created inline branch to new chat: " .. rel_path .. " (" .. topic .. ")")
		M.highlight_chat_branch_refs(buf)
	end

	kb_registry.register_buffer(
		{ "parley_buffer", "chat" },
		buf,
		M.config,
		{
			-- parley_buffer scope (shared with markdown)
			open_file = M.cmd.OpenFileUnderCursor,
			copy_fence = M.cmd.CopyCodeFence,
			outline = M.cmd.Outline,
			branch_ref = {
				n = chat_insert_branch_ref,
				i = function()
					vim.cmd("stopinsert")
					chat_insert_branch_ref()
				end,
				v = function()
					vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
					chat_insert_inline_branch_ref()
				end,
			},
			-- chat scope
			chat_respond = make_respond_cb("ChatRespond"),
			chat_respond_all = make_respond_cb("ChatRespondAll"),
			chat_stop = M.cmd.Stop,
			chat_delete = M.cmd.ChatDelete,
			chat_delete_tree = M.cmd.ChatDeleteTree,
			chat_agent = M.cmd.NextAgent,
			chat_system_prompt = M.cmd.NextSystemPrompt,
			chat_follow_cursor = M.cmd.ToggleFollowCursor,
			chat_search = function()
				local user_prefix = M.config.chat_user_prefix
				local branch_prefix = M.config.chat_branch_prefix
				vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(branch_prefix))
			end,
			chat_prune = M.cmd.ChatPrune,
			chat_export_markdown = M.cmd.ExportMarkdown,
			chat_export_html = M.cmd.ExportHTML,
			chat_exchange_cut = {
				n = function() M.cmd.ExchangeCut() end,
				v = function()
					vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
					M.cmd.ExchangeCut({ visual = true })
				end,
				x = function()
					vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
					M.cmd.ExchangeCut({ visual = true })
				end,
			},
			chat_exchange_paste = M.cmd.ExchangePaste,
			chat_toggle_tool_folds = function()
				vim.wo.foldenable = not vim.wo.foldenable
			end,
		},
		M.helpers.set_keymap
	)

	-- conceallevel=2 for inline branch link concealing and model header params
	vim.opt_local.conceallevel = 2
	vim.opt_local.concealcursor = ""

	-- conceal parameters in model header so it's not distracting
	if M.config.chat_conceal_model_params then
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
M.highlight_chat_branch_refs = function(buf)
	highlighter.highlight_chat_branch_refs(buf)
end

-- Apply highlighting to chat blocks in the current buffer.
-- Simple clear-and-apply; used by tests on scratch buffers.
-- Production highlighting is handled by the decoration provider.
M.highlight_question_block = function(buf)
	highlighter.highlight_question_block(buf)
end

-- Return the branch prefix string from config.
local function get_branch_prefix()
	return M.config.chat_branch_prefix or "🌿:"
end

-- Format a 🌿: branch reference line.
local function format_branch_ref(rel_path, topic)
	return get_branch_prefix() .. " " .. rel_path .. ": " .. (topic or "")
end

M.setup_markdown_keymaps = function(buf)
	-- Document review keybindings (via skill system, not registry-managed)
	local review_skill = require("parley.skills.review")
	review_skill.setup_keymaps(buf)

	-- Branch ref helpers (markdown-specific: uses format_branch_ref and absolute paths)
	local function md_insert_branch_ref()
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":t")
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1], cursor_pos[1], false, {
			format_branch_ref(rel_path, ""),
		})
		vim.api.nvim_win_set_cursor(0, { cursor_pos[1] + 1, 0 })
		vim.schedule(function() vim.cmd("startinsert!") end)
		M.logger.info("Created branch reference to new chat: " .. rel_path)
		M.highlight_chat_branch_refs(buf)
	end

	local function md_insert_inline_branch_ref()
		vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
		local start_pos = vim.fn.getpos("'<")
		local end_pos = vim.fn.getpos("'>")
		local start_line, start_col = start_pos[2], start_pos[3]
		local end_line, end_col = end_pos[2], end_pos[3]
		if start_line ~= end_line then
			M.logger.warning("Inline branch links only support single-line selections")
			return
		end
		local line = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1]
		local selected_text = line:sub(start_col, end_col)
		if selected_text == "" then
			M.logger.warning("No text selected")
			return
		end
		local new_chat_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		local chat_path = vim.fn.fnamemodify(new_chat_file, ":p")
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		local topic = 'what is "' .. selected_text .. '"'
		local before = line:sub(1, start_col - 1)
		local after = line:sub(end_col + 1)
		local inline_link = "[" .. branch_prefix .. selected_text .. "](" .. chat_path .. ")"
		vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, { before .. inline_link .. after })
		M.create_child_chat(new_chat_file, topic, buf, topic .. "?")
		M.logger.debug("Created inline branch to new chat: " .. chat_path .. " (" .. topic .. ")")
		M.highlight_chat_branch_refs(buf)
	end

	-- Register markdown buffer-local keymaps from registry
	kb_registry.register_buffer(
		{ "parley_buffer", "markdown" },
		buf,
		M.config,
		{
			-- parley_buffer scope (shared with chat)
			open_file = M.cmd.OpenFileUnderCursor,
			copy_fence = M.cmd.CopyCodeFence,
			outline = M.cmd.Outline,
			branch_ref = {
				n = md_insert_branch_ref,
				i = function()
					vim.cmd("stopinsert")
					md_insert_branch_ref()
				end,
				v = md_insert_inline_branch_ref,
			},
			-- markdown scope
			md_add_chat_ref = {
				n = function()
					local cursor_pos = vim.api.nvim_win_get_cursor(0)
					M._chat_finder.insert_mode = true
					M._chat_finder.insert_buf = buf
					M._chat_finder.insert_line = cursor_pos[1]
					M._chat_finder.insert_normal_mode = true
					M._chat_finder.source_win = nil
					M._chat_finder.source_win = vim.api.nvim_get_current_win()
					M.logger.debug("NORMAL MODE ADD: Passing window: " .. M._chat_finder.source_win)
					M.cmd.ChatFinder()
				end,
				i = function()
					local cursor_pos = vim.api.nvim_win_get_cursor(0)
					M._chat_finder.insert_mode = true
					M._chat_finder.insert_buf = buf
					M._chat_finder.insert_line = cursor_pos[1]
					M._chat_finder.insert_col = cursor_pos[2]
					M._chat_finder.insert_normal_mode = false
					M._chat_finder.source_win = nil
					M._chat_finder.source_win = vim.api.nvim_get_current_win()
					M.logger.debug("INSERT MODE ADD: Passing window: " .. M._chat_finder.source_win)
					vim.cmd("stopinsert")
					M.cmd.ChatFinder()
				end,
			},
			md_delete_file = function()
				local file = vim.api.nvim_buf_get_name(buf)
				if file ~= "" then
					local rel = vim.fn.fnamemodify(file, ":~:.")
					local choice = vim.fn.confirm("Delete " .. rel .. "?", "&Yes\n&No", 2)
					if choice == 1 then
						M.helpers.delete_file(file)
					end
				end
			end,
			md_delete_tree = M.cmd.ChatDeleteTree,
			md_export_html = function() exporter.pandoc_export_html() end,
		},
		M.helpers.set_keymap
	)

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

-- Rename a chat file to include/update slug from topic header.
-- Returns (new_path, nil) on success, (nil, reason) on skip/error.
M._slug_rename_chat = function(buf)
	local file_path = vim.api.nvim_buf_get_name(buf)
	if file_path == "" then
		return nil, "no file"
	end

	-- Don't rename during streaming
	if M.tasker and M.tasker.is_busy(buf, true) then
		return nil, "busy"
	end

	local dir = vim.fn.fnamemodify(file_path, ":h")
	local basename = vim.fn.fnamemodify(file_path, ":t")

	local ts, old_slug = chat_slug.parse_filename(basename)
	if not ts then
		return nil, "not a timestamp chat file"
	end

	-- Read topic from buffer header
	local lines = vim.api.nvim_buf_get_lines(buf, 0, 20, false)
	local headers = parse_chat_headers(lines)
	if not headers or not headers.topic or headers.topic == "" or headers.topic == "?" then
		return nil, "no topic"
	end

	local new_slug = chat_slug.slugify(headers.topic)
	if new_slug == old_slug then
		return nil, "slug unchanged"
	end

	local new_basename = chat_slug.make_filename(ts, new_slug)
	local new_path = dir .. "/" .. new_basename

	-- Rename on disk
	local ok = vim.fn.rename(file_path, new_path)
	if ok ~= 0 then
		return nil, "rename failed"
	end

	-- Update all buffers pointing to old path
	sync_moved_chat_buffers(file_path, new_path)

	-- Update file: header in buffer
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, 20, false)) do
		if line:match("^file:") then
			vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "file: " .. new_basename })
			-- Save the updated header; guard flag prevents recursive rename
			M._in_slug_rename = true
			local write_ok, write_err = pcall(function()
				vim.api.nvim_buf_call(buf, function()
					vim.cmd("silent! write!")
					-- Reload to clear "new file" flag so next :w doesn't warn "file exists"
					vim.cmd("silent! edit!")
				end)
			end)
			M._in_slug_rename = false
			if not write_ok then
				M.logger.warning("Slug rename write failed: " .. tostring(write_err))
			end
			break
		end
	end

	-- Invalidate topic cache for old path, prime for new
	if M._chat_topic_cache then
		M._chat_topic_cache[file_path] = nil
	end

	return new_path, nil
end

-- Best-effort read repair: update a stale filename reference in a file.
-- Called when fuzzy resolution finds a file under a different name.
-- Does NOT repair if the referring buffer is mid-stream.
M._read_repair_reference = function(referring_file, old_basename, new_basename)
	if old_basename == new_basename then
		return
	end

	-- Check if referring file's buffer is busy
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
			local buf_name = vim.api.nvim_buf_get_name(buf)
			if buf_name ~= "" and vim.fn.resolve(buf_name) == vim.fn.resolve(referring_file) then
				if M.tasker and M.tasker.is_busy(buf, true) then
					return -- defer
				end
			end
		end
	end

	if vim.fn.filereadable(referring_file) ~= 1 then
		return
	end

	local lines = vim.fn.readfile(referring_file)
	local changed = false
	for i, line in ipairs(lines) do
		if line:find(old_basename, 1, true) then
			-- Escape % in replacement string (Lua gsub treats % as capture ref)
			local safe_new = new_basename:gsub("%%", "%%%%")
			lines[i] = line:gsub(vim.pesc(old_basename), safe_new)
			changed = true
		end
	end
	if changed then
		vim.fn.writefile(lines, referring_file)
		-- Reload if open in a buffer
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
				local buf_name = vim.api.nvim_buf_get_name(buf)
				if buf_name ~= "" and vim.fn.resolve(buf_name) == vim.fn.resolve(referring_file) then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("silent! edit!")
					end)
				end
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


-- Pure: return ordered list of candidate paths for a chat reference.
-- For absolute/~ paths, returns a single candidate.
-- For relative paths, tries base_dir first, then all chat roots.
M._resolve_chat_path_candidates = function(path, base_dir, dirs)
	if path:match("^~/") or path == "~" then
		return { vim.fn.resolve(vim.fn.expand(path)) }
	elseif path:sub(1, 1) == "/" then
		return { vim.fn.resolve(path) }
	end
	local candidates = { vim.fn.resolve(base_dir .. "/" .. path) }
	for _, dir in ipairs(dirs or {}) do
		local c = vim.fn.resolve(dir .. "/" .. path)
		if c ~= candidates[1] then
			table.insert(candidates, c)
		end
	end
	return candidates
end

-- Resolve a chat path: absolute/~ paths directly, relative paths by searching
-- base_dir first, then all registered chat roots. Falls back to fuzzy timestamp
-- glob when exact match not found (supports slugged filenames).
-- Optional referring_file enables read-repair of stale references.
local function resolve_chat_path(path, base_dir, referring_file)
	local candidates = M._resolve_chat_path_candidates(path, base_dir, M.get_chat_dirs())
	for _, candidate in ipairs(candidates) do
		if vim.fn.filereadable(candidate) == 1 then
			return candidate
		end
	end

	-- Fuzzy fallback: extract timestamp, glob for any slug variant
	local basename = vim.fn.fnamemodify(path, ":t")
	local ts = chat_slug.parse_filename(basename)
	if ts then
		local pattern = chat_slug.glob_pattern(ts)
		-- Search in base_dir and all chat roots
		local search_dirs = { base_dir }
		for _, d in ipairs(M.get_chat_dirs() or {}) do
			if d ~= base_dir then
				table.insert(search_dirs, d)
			end
		end
		for _, dir in ipairs(search_dirs) do
			local matches = vim.fn.glob(dir .. "/" .. pattern, false, true)
			-- Post-filter: verify each match has the exact same timestamp
			local verified = {}
			for _, m in ipairs(matches) do
				local m_ts = chat_slug.parse_filename(vim.fn.fnamemodify(m, ":t"))
				if m_ts == ts then
					table.insert(verified, m)
				end
			end
			if #verified > 0 then
				-- Prefer the match with a slug (most recent rename)
				table.sort(verified, function(a, b)
					return #a > #b
				end)
				local found = verified[1]
				-- Schedule read repair if we have a referring file
				if referring_file and referring_file ~= "" then
					local new_basename = vim.fn.fnamemodify(found, ":t")
					if new_basename ~= basename then
						vim.schedule(function()
							M._read_repair_reference(referring_file, basename, new_basename)
						end)
					end
				end
				return found
			end
		end
	end

	return candidates[1]
end
M.resolve_chat_path = resolve_chat_path

-- Pure: parse a 🌿: branch reference line into {path, topic} or nil.
M._parse_branch_ref = function(line)
	local prefix = get_branch_prefix()
	if line:sub(1, #prefix) ~= prefix then
		return nil
	end
	local rest = line:sub(#prefix + 1):gsub("^%s*(.-)%s*$", "%1")
	local path = rest:match("^([^:]+)") or rest
	path = path:gsub("^%s*(.-)%s*$", "%1")
	if path == "" then
		return nil
	end
	local topic = rest:match("^[^:]+:%s*(.+)$") or ""
	topic = topic:gsub("^%s*(.-)%s*$", "%1")
	topic = topic:gsub("%s*⚠️%s*$", "")
	return { path = path, topic = topic }
end

-- Try to open an inline branch link [🌿:text](file) under the cursor.
-- Returns true if a link was found (and handled), false otherwise.
local function try_open_inline_branch_link(current_line, cursor_col, parent_buf)
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"
	local chat_parser = require("parley.chat_parser")
	local inline_links = chat_parser.extract_inline_branch_links(current_line, branch_prefix)
	for _, link in ipairs(inline_links) do
		-- cursor_col is 0-indexed, col_start/col_end are 1-indexed
		if cursor_col + 1 >= link.col_start and cursor_col + 1 <= link.col_end then
			local referring = vim.api.nvim_buf_get_name(parent_buf)
			local current_dir = vim.fn.fnamemodify(referring, ":p:h")
			local expanded = resolve_chat_path(link.path, current_dir, referring)
			if vim.fn.filereadable(expanded) == 1 then
				M.open_buf(expanded)
			elseif expanded:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
				local topic = link.topic ~= "" and ('what is "' .. link.topic .. '"') or "New chat"
				M.create_child_chat(expanded, topic, parent_buf, topic .. "?")
				M.open_buf(expanded)
			else
				M.logger.warning("Chat file not found: " .. expanded)
			end
			return true
		end
	end
	return false
end

-- Walk parent_link chain to find the tree root file path.
local function find_tree_root_file(file_path, depth)
	depth = depth or 0
	if depth > 20 then return file_path end
	local abs_path = vim.fn.resolve(vim.fn.expand(file_path))
	if vim.fn.filereadable(abs_path) == 0 then return abs_path end
	local lines = vim.fn.readfile(abs_path)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then return abs_path end
	local parsed = M.chat_parser.parse_chat(lines, header_end, M.config)
	if not parsed.parent_link then return abs_path end
	local parent_dir = vim.fn.fnamemodify(abs_path, ":h")
	local parent_abs = resolve_chat_path(parsed.parent_link.path, parent_dir, abs_path)
	if vim.fn.filereadable(parent_abs) == 0 then return abs_path end
	return find_tree_root_file(parent_abs, depth + 1)
end

-- Collect all file paths in a chat tree (root + all descendants via branches).
local function collect_tree_files(file_path, visited)
	visited = visited or {}
	local abs_path = vim.fn.resolve(vim.fn.expand(file_path))
	if visited[abs_path] then return {} end
	visited[abs_path] = true
	if vim.fn.filereadable(abs_path) == 0 then return {} end

	local result = { abs_path }
	local lines = vim.fn.readfile(abs_path)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then return result end
	local parsed = M.chat_parser.parse_chat(lines, header_end, M.config)
	local file_dir = vim.fn.fnamemodify(abs_path, ":h")

	for _, branch in ipairs(parsed.branches) do
		local child_abs = resolve_chat_path(branch.path, file_dir, abs_path)
		local child_files = collect_tree_files(child_abs, visited)
		for _, f in ipairs(child_files) do
			table.insert(result, f)
		end
	end
	return result
end

-- Delete an entire chat tree (root + all descendants) after confirmation.
M.delete_chat_tree = function(buf)
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then return end
	local root = find_tree_root_file(file)
	local tree_files = collect_tree_files(root)
	if #tree_files == 0 then return end

	local root_rel = vim.fn.fnamemodify(root, ":~:.")
	local msg = "Delete " .. #tree_files .. " chat file(s) in tree rooted at " .. root_rel .. "?\n\n"
	for _, f in ipairs(tree_files) do
		msg = msg .. "  " .. vim.fn.fnamemodify(f, ":~:.") .. "\n"
	end
	local choice = vim.fn.confirm(msg, "&Yes\n&No", 2)
	if choice == 1 then
		for _, f in ipairs(tree_files) do
			M.helpers.delete_file(f)
		end
	end
end

-- Move an entire chat tree to a new directory, updating all 🌿: references.
M.move_chat_tree = function(file_name, target_dir)
	local current_root, _ = find_chat_root(file_name)
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

	-- Find tree root and collect all files
	local tree_root = find_tree_root_file(file_name)
	local tree_files = collect_tree_files(tree_root)

	if #tree_files == 0 then
		return nil, "no files found in tree"
	end

	-- Check for conflicts
	for _, src in ipairs(tree_files) do
		local basename = vim.fn.fnamemodify(src, ":t")
		local dst = target_root .. "/" .. basename
		if vim.fn.filereadable(dst) == 1 then
			return nil, "target already exists: " .. dst
		end
	end

	-- Build old_path -> new_path mapping
	local path_map = {}  -- old_abs -> new_abs
	for _, src in ipairs(tree_files) do
		local basename = vim.fn.fnamemodify(src, ":t")
		path_map[src] = target_root .. "/" .. basename
	end

	-- Move all files
	for _, src in ipairs(tree_files) do
		sync_moved_chat_buffers(src, nil)
		local ok, err = os.rename(src, path_map[src])
		if not ok then
			return nil, "failed to move " .. src .. ": " .. tostring(err)
		end
		sync_moved_chat_buffers(src, path_map[src])

		if M._state.last_chat and resolve_dir_key(M._state.last_chat) == resolve_dir_key(src) then
			M.refresh_state({ last_chat = path_map[src] })
		end
		require("parley.file_tracker").track_file_access(path_map[src])
	end

	-- Update 🌿: references in all moved files
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"
	for _, new_path in pairs(path_map) do
		if vim.fn.filereadable(new_path) == 1 then
			local lines = vim.fn.readfile(new_path)
			local changed = false
			for i, line in ipairs(lines) do
				if line:sub(1, #branch_prefix) == branch_prefix then
					local rest = line:sub(#branch_prefix + 1)
					local ref_path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
					if ref_path then
						ref_path = ref_path:gsub("^%s*(.-)%s*$", "%1")
						local ref_abs = resolve_chat_path(ref_path, vim.fn.fnamemodify(new_path, ":h"))
						-- Check if this reference pointed to a file in the old location
						for old_abs, new_abs in pairs(path_map) do
							if ref_abs == old_abs or resolve_chat_path(ref_path, current_root) == old_abs then
								local new_rel = vim.fn.fnamemodify(new_abs, ":t")
								lines[i] = branch_prefix .. " " .. new_rel .. ": " .. (topic or "")
								changed = true
								break
							end
						end
					end
				end
			end
			if changed then
				vim.fn.writefile(lines, new_path)
				-- Update buffer if open
				local buf = vim.fn.bufnr(new_path)
				if buf ~= -1 and vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd("edit!")
					end)
				end
			end
		end
	end

	-- Return the new path of the originally requested file
	local resolved_file = vim.fn.resolve(vim.fn.expand(file_name))
	return path_map[resolved_file] or path_map[tree_root]
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
			local new_file, err = M.move_chat_tree(resolved_file, item.value)
			if not new_file then
				vim.notify("Failed to move chat: " .. err, vim.log.levels.WARN)
				if on_cancel then
					on_cancel()
				end
				return
			end

			M.logger.info("Moved chat tree to: " .. new_file)
			vim.notify("Moved chat tree to: " .. new_file, vim.log.levels.INFO)
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

	local source_buf = vim.api.nvim_get_current_buf()

	local question = "proof read the following file:\n\n@@" .. file_path .. "@@"
	local buf = M.new_chat(nil, nil, question)

	-- insert reference as last line in source file's front matter
	local chat_filename = vim.api.nvim_buf_get_name(buf)
	local rel_path = vim.fn.fnamemodify(chat_filename, ":t")
	local chat_parser = require("parley.chat_parser")
	local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
	local header_end = chat_parser.find_header_end(lines)
	if header_end then
		vim.api.nvim_buf_set_lines(source_buf, header_end - 1, header_end - 1, false, {
			format_branch_ref(rel_path, "proof read"),
		})
	end

	return buf
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

M._issue_finder = {
	opened = false,
	source_win = nil,
	view_mode = 0, -- 0=open+blocked, 1=all, 2=all+history
	initial_index = nil,
	initial_value = nil,
}

M._vision_finder = {
	opened = false,
	initial_index = nil,
	initial_value = nil,
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

M.cmd.ChatDeleteTree = function()
	local buf = vim.api.nvim_get_current_buf()
	M.delete_chat_tree(buf)
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

		-- Check if the line is in the margin after the question (between
		-- question.line_end and answer.line_start, or after the last
		-- question when there's no answer). Associate with the question.
		if exchange.question and line_number > exchange.question.line_end then
			if exchange.answer then
				if line_number < exchange.answer.line_start then
					return i, "question"
				end
			else
				-- No answer — check if before the next exchange
				local next_ex = parsed_chat.exchanges[i + 1]
				if not next_ex or line_number < next_ex.question.line_start then
					return i, "question"
				end
			end
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

-- Debug: print the exchange model structure of the current buffer.
-- Invoke with :lua require('parley').dump_model()
M.dump_model = function()
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local chat_parser = require("parley.chat_parser")
	local header_end = chat_parser.find_header_end(lines) or 0
	local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
	local em = require("parley.exchange_model")
	local model = em.from_parsed_chat(parsed)
	local out = { "=== Model (buf=" .. buf .. ", " .. #lines .. " lines, header=" .. model.header_lines .. ") ===" }
	out[#out + 1] = "  Stored fields per block: kind, size (positions are computed on the fly)"
	for k, ex in ipairs(model.exchanges) do
		if k > 1 then out[#out + 1] = "" end
		table.insert(out, string.format("  Exchange %d (%d blocks, total_size=%d):",
			k, #ex.blocks, model:exchange_total_size(k)))
		for b, blk in ipairs(ex.blocks) do
			-- start is computed (not stored) — shown here for debugging only
			local computed_start = model:block_start(k, b)
			local preview = ""
			if blk.size > 0 and computed_start < #lines then
				local l = vim.api.nvim_buf_get_lines(buf, computed_start, computed_start + 1, false)[1] or ""
				preview = l:sub(1, 60)
			end
			table.insert(out, string.format("    [%d] %-18s size=%-3d (line %d) %q",
				b, blk.kind, blk.size, computed_start, preview))
		end
	end
	print(table.concat(out, "\n"))
end

-- Diagnostic: validate buffer for tool-use invariants.
-- Invoke with :lua require('parley').check_buffer()
M.check_buffer = function()
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local chat_parser = require("parley.chat_parser")
	local header_end = chat_parser.find_header_end(lines)
	if not header_end then
		print("Not a chat buffer (no header separator found)")
		return
	end
	local parsed = chat_parser.parse_chat(lines, header_end, require("parley.config"))
	local serialize = require("parley.tools.serialize")
	local issues = {}

	for i, ex in ipairs(parsed.exchanges) do
		local sections = ex.answer and ex.answer.sections or {}
		-- Track tool_use ids that need matching tool_result
		local pending_tool_ids = {}

		for j, sec in ipairs(sections) do
			local sec_lines = {}
			for ln = sec.line_start, sec.line_end do
				table.insert(sec_lines, lines[ln] or "")
			end
			local text = table.concat(sec_lines, "\n")

			if sec.kind == "tool_use" then
				local parsed_call = serialize.parse_call(text)
				if not parsed_call then
					table.insert(issues, string.format(
						"Exchange %d, section %d (line %d): malformed 🔧: block — cannot parse tool_use",
						i, j, sec.line_start))
				else
					pending_tool_ids[parsed_call.id] = { name = parsed_call.name, line = sec.line_start }
				end
			elseif sec.kind == "tool_result" then
				local parsed_result = serialize.parse_result(text)
				if not parsed_result then
					table.insert(issues, string.format(
						"Exchange %d, section %d (line %d): malformed 📎: block — cannot parse tool_result",
						i, j, sec.line_start))
				else
					if pending_tool_ids[parsed_result.id] then
						pending_tool_ids[parsed_result.id] = nil
					else
						table.insert(issues, string.format(
							"Exchange %d, section %d (line %d): 📎: %s has no matching 🔧: (id=%s)",
							i, j, sec.line_start, parsed_result.name, parsed_result.id))
					end
				end
			end
		end

		-- Report unmatched tool_use blocks
		for id, info in pairs(pending_tool_ids) do
			table.insert(issues, string.format(
				"Exchange %d (line %d): 🔧: %s has no matching 📎: (id=%s)",
				i, info.line, info.name, id))
		end
	end

	if #issues == 0 then
		print("✓ Buffer is valid — no tool-use invariant violations found")
	else
		print("⚠ Found " .. #issues .. " issue(s):")
		for _, issue in ipairs(issues) do
			print("  " .. issue)
		end
	end
end

-- Prune: move cursored exchange + all following into a new child chat file.
-- Replaces pruned content in parent with a 🌿: branch reference.
M.cmd.ChatPrune = function()
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("Prune is only available in chat files: " .. reason)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then
		M.logger.error("Prune: could not find header separator ---")
		return
	end

	local parsed_chat = M.parse_chat(lines, header_end)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local exchange_idx = M.find_exchange_at_line(parsed_chat, cursor_line)

	-- If cursor isn't directly on an exchange, find the nearest one at or after cursor
	if not exchange_idx then
		for i, ex in ipairs(parsed_chat.exchanges) do
			if ex.question and ex.question.line_start >= cursor_line then
				exchange_idx = i
				break
			end
		end
	end

	if not exchange_idx then
		M.logger.warning("Prune: no exchange found at or after cursor")
		return
	end

	if exchange_idx < 1 or exchange_idx > #parsed_chat.exchanges then
		M.logger.warning("Prune: exchange index out of range")
		return
	end

	-- Determine the line range to prune: from the question start of the target
	-- exchange through the end of the file.
	local prune_start = parsed_chat.exchanges[exchange_idx].question.line_start
	local prune_end = #lines

	-- Collect pruned lines (1-indexed inclusive)
	local pruned_lines = {}
	for i = prune_start, prune_end do
		table.insert(pruned_lines, lines[i])
	end

	-- Build the new child file
	local new_file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
	local rel_child = vim.fn.fnamemodify(new_file, ":t")
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"

	-- Copy parent headers, patching topic and file fields
	local child_lines = {}
	local basename = rel_child
	for i = 1, header_end do
		local line = lines[i]
		if line:match("^%s*topic:%s*") then
			line = "topic: ?"
		elseif line:match("^%s*file:%s*") then
			line = "file: " .. basename
		end
		table.insert(child_lines, line)
	end

	-- Insert parent back-link as first transcript line
	local parent_rel = vim.fn.fnamemodify(file_name, ":t")
	local parent_topic = M.get_chat_topic(file_name) or ""
	table.insert(child_lines, branch_prefix .. " " .. parent_rel .. ": " .. parent_topic)
	table.insert(child_lines, "")

	-- Append the pruned exchanges
	for _, l in ipairs(pruned_lines) do
		table.insert(child_lines, l)
	end

	-- Write child file
	M.helpers.prepare_dir(vim.fn.fnamemodify(new_file, ":h"))
	vim.fn.writefile(child_lines, new_file)

	-- Replace pruned lines in parent with a branch reference + fresh question starter
	local branch_line = branch_prefix .. " " .. rel_child .. ": "
	local user_prefix = M.config.chat_user_prefix
	vim.api.nvim_buf_set_lines(buf, prune_start - 1, prune_end, false, { "", branch_line, "", user_prefix, "", "" })

	-- Save parent
	vim.cmd("write")

	-- Open the child
	M.open_buf(new_file)
	M.logger.info("Pruned " .. #pruned_lines .. " lines into " .. rel_child)

	-- Generate topic from the pruned exchanges asynchronously
	local topic_msgs = {}
	for idx = exchange_idx, #parsed_chat.exchanges do
		local ex = parsed_chat.exchanges[idx]
		if ex.question then
			table.insert(topic_msgs, { role = "user", content = ex.question.content })
		end
		if ex.answer then
			table.insert(topic_msgs, { role = "assistant", content = ex.answer.content })
		end
	end

	if #topic_msgs > 0 then
		local agent = M.get_agent()
		local agent_info = M.get_agent_info(parsed_chat.headers, agent)
		-- The child is now the active buffer — animate its topic line
		local child_buf = vim.fn.bufnr(new_file)
		local spinner_opts = nil
		if child_buf ~= -1 then
			spinner_opts = { buf = child_buf, find_line = function()
				return chat_respond.find_topic_line(child_buf)
			end }
		end
		chat_respond.generate_topic(topic_msgs, agent_info.provider, agent_info.model, function(topic)
			-- Update child file's topic header
			local cbuf = vim.fn.bufnr(new_file)
			if cbuf ~= -1 and vim.api.nvim_buf_is_valid(cbuf) then
				local child_lines_now = vim.api.nvim_buf_get_lines(cbuf, 0, -1, false)
				set_chat_topic_line(cbuf, child_lines_now, topic)
			else
				-- Child not open in a buffer — update the file directly
				local file_lines = vim.fn.readfile(new_file)
				for i, line in ipairs(file_lines) do
					if line:match("^%s*topic:%s*") then
						file_lines[i] = "topic: " .. topic
						vim.fn.writefile(file_lines, new_file)
						break
					end
				end
			end

			-- Update parent's 🌿: line with the generated topic
			if vim.api.nvim_buf_is_valid(buf) then
				local parent_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				for i, line in ipairs(parent_lines) do
					if line:match("^" .. vim.pesc(branch_prefix)) and line:find(rel_child, 1, true) then
						local updated = branch_prefix .. " " .. rel_child .. ": " .. topic
						vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { updated })
						vim.cmd("write")
						break
					end
				end
			end

			M.logger.info("Prune topic generated: " .. topic)
		end, spinner_opts)
	end
end

-- Internal clipboard for exchange cut/paste (buffer-local lines)
local _exchange_clipboard = nil

--- Cut exchange(s) at cursor (normal) or overlapping visual selection (visual).
--- @param opts table|nil  { visual = bool }
M.cmd.ExchangeCut = function(opts)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("ExchangeCut is only available in chat files: " .. reason)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then
		M.logger.error("ExchangeCut: could not find header separator ---")
		return
	end

	local parsed_chat = M.parse_chat(lines, header_end)
	local total_lines = #lines
	local exchange_indices

	if opts and opts.visual then
		local sel_start = vim.fn.line("'<")
		local sel_end = vim.fn.line("'>")
		exchange_indices = exchange_clipboard.get_exchanges_for_range(parsed_chat, sel_start, sel_end, total_lines)
	else
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
		local idx = M.find_exchange_at_line(parsed_chat, cursor_line)
		if not idx then
			-- Try nearest exchange at or after cursor
			for i, ex in ipairs(parsed_chat.exchanges) do
				if ex.question and ex.question.line_start >= cursor_line then
					idx = i
					break
				end
			end
		end
		if idx then
			exchange_indices = { idx }
		else
			exchange_indices = {}
		end
	end

	if #exchange_indices == 0 then
		M.logger.warning("ExchangeCut: no exchange found at cursor")
		return
	end

	local extracted, start_line, end_line = exchange_clipboard.extract_exchange_lines(lines, parsed_chat, exchange_indices, total_lines)
	if #extracted == 0 then
		M.logger.warning("ExchangeCut: nothing to cut")
		return
	end

	_exchange_clipboard = extracted
	vim.fn.setreg("+", table.concat(extracted, "\n") .. "\n")
	vim.api.nvim_buf_set_lines(buf, start_line - 1, end_line, false, {})

	-- Clean up consecutive blank lines at the cut seam
	local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local cut_point = math.min(start_line, #new_lines + 1)
	local seam_start, seam_end, replacement = exchange_clipboard.compute_cut_cleanup(new_lines, cut_point, #new_lines)
	if seam_start then
		vim.api.nvim_buf_set_lines(buf, seam_start - 1, seam_end, false, replacement)
	end

	M.logger.info("Cut " .. #exchange_indices .. " exchange(s) (" .. #extracted .. " lines)")
end

--- Paste previously cut exchanges after the exchange at cursor.
M.cmd.ExchangePaste = function()
	if not _exchange_clipboard or #_exchange_clipboard == 0 then
		M.logger.warning("ExchangePaste: clipboard is empty — cut an exchange first")
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local reason = M.not_chat(buf, file_name)
	if reason then
		M.logger.warning("ExchangePaste is only available in chat files: " .. reason)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then
		M.logger.error("ExchangePaste: could not find header separator ---")
		return
	end

	local parsed_chat = M.parse_chat(lines, header_end)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	local paste_after = exchange_clipboard.get_paste_line(parsed_chat, cursor_line, header_end, #lines)

	local to_insert = exchange_clipboard.build_paste_lines(lines, paste_after, _exchange_clipboard, #lines)
	vim.api.nvim_buf_set_lines(buf, paste_after, paste_after, false, to_insert)
	M.logger.info("Pasted " .. #_exchange_clipboard .. " lines after line " .. paste_after)
end

-- Command for navigating questions and headers in chat documents
M.cmd.Outline = function()
	-- Allow outline on any markdown file, not just chat files
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	if not file_name:match("%.md$") and M.not_chat(buf, file_name) then
		M.logger.warning("Outline command is only available in markdown files")
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

-- Open or create a chat file from a 🌿: branch reference line.
-- Shared by both chat-buffer and markdown-buffer <C-g>o handlers.
local function open_branch_ref(current_line, buf)
	local parsed = M._parse_branch_ref(current_line)
	if parsed == nil then
		return false
	end

	local referring = vim.api.nvim_buf_get_name(buf)
	local current_dir = vim.fn.fnamemodify(referring, ":p:h")
	local expanded = resolve_chat_path(parsed.path, current_dir, referring)

	if vim.fn.filereadable(expanded) == 1 then
		M.open_buf(expanded)
		return true
	end

	-- Chat file doesn't exist yet — create it if it looks like a chat timestamp
	if expanded:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
		local topic = parsed.topic ~= "" and parsed.topic or "New chat"

		-- Place new file in default chat_dir (not relative to source file)
		local chat_file = M.config.chat_dir .. "/" .. vim.fn.fnamemodify(expanded, ":t")
		M.helpers.prepare_dir(vim.fn.fnamemodify(chat_file, ":h"))

		local agent = M.get_agent()
		local template = M.get_default_template(agent, chat_file)
		template = template:gsub("{{topic}}", topic)
		local file_lines = vim.split(template, "\n")

		-- Insert parent back-link only when source is a chat file
		local parent_path = vim.api.nvim_buf_get_name(buf)
		if not M.not_chat(buf, parent_path) then
			local chat_parser = require("parley.chat_parser")
			local header_end = chat_parser.find_header_end(file_lines)
			if header_end then
				local parent_rel = vim.fn.fnamemodify(parent_path, ":t")
				local parent_topic = M.get_chat_topic(parent_path) or ""
				table.insert(file_lines, header_end + 1, format_branch_ref(parent_rel, parent_topic))
			end
		end

		vim.fn.writefile(file_lines, chat_file)
		M.open_buf(chat_file)
		return true
	end

	M.logger.warning("Chat file not found: " .. expanded)
	return true
end

-- Resolve a src: path to an absolute filesystem path.
-- Tries git rev-parse --show-toplevel from the buffer file's directory first;
-- falls back to M.config.src_root. Returns absolute path or nil.
local resolve_src_link = function(src_path, buf_file)
	local buf_dir = vim.fn.fnamemodify(buf_file, ":p:h")
	local git_root = vim.fn.system(
		"git -C " .. vim.fn.shellescape(buf_dir) .. " rev-parse --show-toplevel 2>/dev/null"
	):gsub("\n$", "")
	if vim.v.shell_error == 0 and git_root ~= "" then
		return vim.fn.fnamemodify(git_root, ":h") .. "/" .. src_path
	end
	if M.config.src_root then
		return vim.fn.expand(M.config.src_root) .. "/" .. src_path
	end
	return nil
end

-- Try to open a src: markdown link under cursor_col (0-indexed). Returns true if handled.
local try_open_src_link = function(line, cursor_col, buf)
	local link = issues_mod.parse_md_link_at_cursor(line, cursor_col + 1)
	if not link then return false end
	local src_path = issues_mod.parse_src_url(link.url)
	if not src_path then return false end
	local buf_file = vim.api.nvim_buf_get_name(buf)
	local abs_path = resolve_src_link(src_path, buf_file)
	if not abs_path then
		M.logger.warning("src: link: no git root found and src_root not configured")
		return true
	end
	abs_path = vim.fn.simplify(abs_path)
	if vim.fn.filereadable(abs_path) == 1 or vim.fn.isdirectory(abs_path) == 1 then
		M.open_buf(abs_path)
	else
		M.logger.warning("src: link target not found: " .. abs_path)
	end
	return true
end

-- Function to open a chat reference from a markdown file
M.open_chat_reference = function(current_line, cursor_col, _in_insert_mode, full_line)
	-- Check for src: links first
	if try_open_src_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
		return true
	end

	-- Check for inline branch links [🌿:text](file) first
	if try_open_inline_branch_link(current_line, cursor_col, vim.api.nvim_get_current_buf()) then
		return true
	end

	-- Check for 🌿: branch reference lines
	if open_branch_ref(current_line, vim.api.nvim_get_current_buf()) then
		return true
	end

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

	-- Expand ~ and resolve relative paths (searches chat roots for bare filenames)
	local expanded_path = vim.fn.expand(chat_path)
	if expanded_path:sub(1, 1) ~= "/" then
		local current_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p:h")
		expanded_path = resolve_chat_path(expanded_path, current_dir)
	end

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

-- Copy commands (delegated to parley.copy module)
local copy_mod = require("parley.copy")
M.cmd.CopyCodeFence = copy_mod.copy_code_fence
M.cmd.CopyLocation = copy_mod.copy_location
M.cmd.CopyLocationContent = copy_mod.copy_location_content
M.cmd.CopyContext = function() copy_mod.copy_context(2, 2) end
M.cmd.CopyContextWide = function() copy_mod.copy_context(5, 10) end

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
	if open_branch_ref(current_line, buf) then
		return
	end

	-- Handle inline branch links [🌿:text](file) — check if cursor is within one
	if try_open_inline_branch_link(current_line, cursor_col, buf) then
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
	tag_state = nil, -- Map of tag_label -> bool (true=enabled). nil means all enabled (initial state).
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

M._handle_chat_finder_delete_tree_response = function(...)
	chat_finder_mod.handle_delete_tree_response(...)
end

M._prompt_chat_finder_delete_tree_confirmation = function(...)
	chat_finder_mod.prompt_delete_tree_confirmation(...)
end

-- Get all files in a chat tree (root + descendants) for a given file path.
M.get_chat_tree_files = function(file_path)
	local root = find_tree_root_file(file_path)
	return collect_tree_files(root)
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

M.cmd.MarkdownFinder = function() markdown_finder_mod.open() end


-- Issue management commands
M.cmd.IssueNew = function() issues_mod.cmd_issue_new() end
M.cmd.IssueFinder = function(opts) issue_finder_mod.open(opts) end
M.cmd.IssueNext = function() issues_mod.cmd_issue_next() end
M.cmd.IssueStatus = function() issues_mod.cmd_issue_status() end
M.cmd.IssueDecompose = function() issues_mod.cmd_issue_decompose() end
M.cmd.IssueGoto = function() issues_mod.cmd_issue_goto() end

-- Vision tracker commands
M.cmd.VisionValidate = function() vision_mod.cmd_validate() end
M.cmd.VisionExportCsv = function(params) vision_mod.cmd_export_csv(params) end
M.cmd.VisionExportDot = function(params) vision_mod.cmd_export_dot(params) end
M.cmd.VisionNew = function() vision_mod.cmd_new() end
M.cmd.VisionGoto = function() vision_mod.cmd_goto_ref() end
M.cmd.VisionShow = function() vision_finder_mod.open() end
M.cmd.VisionAllocation = function(params) vision_mod.cmd_export_allocation(params) end

-- Memory preferences command
M.cmd.MemoryPrefs = function() memory_prefs.generate() end

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
	local agent_rec = M.agents[name]
	local model = agent_rec.model
	local system_prompt = agent_rec.system_prompt
	local provider = agent_rec.provider
	-- M.logger.debug("getting agent: " .. name)
	return {
		cmd_prefix = cmd_prefix,
		name = name,
		model = model,
		system_prompt = system_prompt,
		provider = provider,
		-- Forward client-side tool-use config (M1 of #81) so downstream
		-- get_agent_info / prepare_payload can see it. Without these,
		-- get_agent_info receives a sanitized snapshot and agent_info.tools
		-- is nil, silently dropping the tools from the request payload.
		tools = agent_rec.tools,
		max_tool_iterations = agent_rec.max_tool_iterations,
		tool_result_max_bytes = agent_rec.tool_result_max_bytes,
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

--- Create a child chat file with topic, parent back-link, and optional first question.
--- @param file_path string path for the new child chat file
--- @param topic string topic for the child chat header
--- @param parent_buf number buffer handle of the parent chat
--- @param question string|nil optional first question to insert
M.create_child_chat = function(file_path, topic, parent_buf, question)
	local agent = M.get_agent()
	M.helpers.prepare_dir(vim.fn.fnamemodify(file_path, ":h"))
	local template = M.get_default_template(agent, file_path)
	template = template:gsub("topic: %?", "topic: " .. topic)
	local file_lines = vim.split(template, "\n")

	local chat_parser = require("parley.chat_parser")
	local header_end = chat_parser.find_header_end(file_lines)
	if header_end then
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		local parent_path = vim.api.nvim_buf_get_name(parent_buf)
		local parent_rel = vim.fn.fnamemodify(parent_path, ":t")
		local parent_topic = M.get_chat_topic(parent_path) or ""
		local back_link = branch_prefix .. " " .. parent_rel .. ": " .. parent_topic
		table.insert(file_lines, header_end + 1, back_link)

		if question then
			local user_prefix = M.config.chat_user_prefix or "💬:"
			table.insert(file_lines, header_end + 2, "")
			table.insert(file_lines, header_end + 3, user_prefix .. " " .. question)
			table.insert(file_lines, header_end + 4, "")
		end
	end

	vim.fn.writefile(file_lines, file_path)
end

-- Agent info resolution (delegated to parley.agent_info module)
local agent_info_mod = require("parley.agent_info")
M.get_agent_info = function(headers, agent)
	return agent_info_mod.resolve(headers, agent, M._state, M.system_prompts, memory_prefs, M.logger)
end

return M
