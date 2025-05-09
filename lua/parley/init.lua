-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- A streamlined LLM chat interface for Neovim with highlighting and navigation

--------------------------------------------------------------------------------
-- This is the main module
--------------------------------------------------------------------------------
local config = require("parley.config")

local M = {
	_Name = "Parley", -- plugin name
	_state = {}, -- table of state variables
	agents = {}, -- table of agents
	cmd = {}, -- default command functions
	config = {}, -- config variables
	hooks = {}, -- user defined command functions
	defaults = require("parley.defaults"), -- some useful defaults
	deprecator = require("parley.deprecator"), -- handle deprecated options
	dispatcher = require("parley.dispatcher"), -- handle communication with LLM providers
	helpers = require("parley.helper"), -- helper functions
	logger = require("parley.logger"), -- logger module
	outline = require("parley.outline"), -- outline navigation module
	render = require("parley.render"), -- render module
	tasker = require("parley.tasker"), -- tasker module
	vault = require("parley.vault"), -- handles secrets
	lualine = require("parley.lualine"), -- lualine integration
}

--------------------------------------------------------------------------------
-- Module helper functions and variables
--------------------------------------------------------------------------------

local agent_completion = function()
	return M._agents
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
	local cmd_prefix = opts.cmd_prefix or M.config.cmd_prefix
	local state_dir = opts.state_dir or M.config.state_dir
	local openai_api_key = opts.openai_api_key or M.config.openai_api_key

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

	-- merge nested tables
	local mergeTables = { "hooks", "agents" }
	for _, tbl in ipairs(mergeTables) do
		M[tbl] = M[tbl] or {}
		---@diagnostic disable-next-line
		for k, v in pairs(M.config[tbl]) do
			if tbl == "hooks" then
				M[tbl][k] = v
			elseif tbl == "agents" then
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
			end
		end
		opts[tbl] = nil
	end

	for k, v in pairs(opts) do
		if M.deprecator.is_valid(k, v) then
			M.config[k] = v
		end
	end
	M.deprecator.report()

	-- make sure _dirs exists
	for k, v in pairs(M.config) do
		if k:match("_dir$") and type(v) == "string" then
			M.config[k] = M.helpers.prepare_dir(v, k)
		end
	end
	

	-- remove invalid agents
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
	for name, agent in pairs(M.agents) do
		M.agents[name].provider = M.agents[name].provider or "openai"

		if M.dispatcher.providers[M.agents[name].provider] then
			table.insert(M._agents, name)
		else
			M.agents[name] = nil
		end
	end
	table.sort(M._agents)

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
	
	-- Set up global keymaps for commands
	if M.config.global_shortcut_finder then
		for _, mode in ipairs(M.config.global_shortcut_finder.modes) do
			if mode == "n" then
				vim.keymap.set(mode, M.config.global_shortcut_finder.shortcut, ":" .. M.config.cmd_prefix .. "ChatFinder<CR>", { silent = true, desc = "Open Chat Finder" })
			elseif mode == "i" then
				vim.keymap.set(mode, M.config.global_shortcut_finder.shortcut, "<ESC>:" .. M.config.cmd_prefix .. "ChatFinder<CR>", { silent = true, desc = "Open Chat Finder" })
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
	
	-- Note: Agent switching is now handled in buffer-local bindings
	
	-- Note: Chat section navigation is now handled in the buffer-local bindings

	local completions = {
		ChatNew = { },
		Agent = agent_completion,
	}

	-- Add ChatRespondAll command
	M.cmd.ChatRespondAll = function()
		M.chat_respond_all()
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

	M.buf_handler()
	
	-- Setup lualine integration if lualine is enabled
	pcall(function()
		if M.config.lualine and M.config.lualine.enable then
			M.lualine.setup(M)
		end
	end)

	if vim.fn.executable("curl") == 0 then
		M.logger.error("curl is not installed, run :checkhealth parley")
	end

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
		local last = M.config.chat_dir .. "/last.md"
		if vim.fn.filereadable(last) == 1 then
			os.remove(last)
		end
	end

	if not M._state.updated or (disk_state.updated and M._state.updated < disk_state.updated) then
		M._state = vim.deepcopy(disk_state)
	end
	M._state.updated = os.time()

	for k, v in pairs(update) do
		M._state[k] = v
	end

	if not M._state.agent or not M.agents[M._state.agent] then
		M._state.agent = M._agents[1]
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

-- stop receiving gpt responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.cmd.Stop = function(signal)
	-- If we were in the middle of a batch resubmission, make sure to restore the cursor setting
	if original_free_cursor_value ~= nil then
		M.logger.debug("Stop called during resubmission - restoring chat_free_cursor to: " .. tostring(original_free_cursor_value))
		M.config.chat_free_cursor = original_free_cursor_value
		original_free_cursor_value = nil
	end
	
	M.tasker.stop(signal)
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
	-- auto save on TextChanged, InsertLeave
	vim.api.nvim_command("autocmd TextChanged,InsertLeave <buffer=" .. buf .. "> silent! write")

	-- register shortcuts local to this buffer
	buf = buf or vim.api.nvim_get_current_buf()

	-- ensure normal mode
	vim.api.nvim_command("stopinsert")
	M.helpers.feedkeys("<esc>", "xn")
end

--- Checks if a file should be considered a chat transcript, it enforces that a file needs to be in chat_dir
--- and have header portion. Also first line needs to start with # (for the topic)
---@param buf number # buffer number
---@param file_name string # file name
---@return string | nil # reason for not being a chat or nil if it is a chat
M.not_chat = function(buf, file_name)
	file_name = vim.fn.resolve(file_name)
	local chat_dir = vim.fn.resolve(M.config.chat_dir)

	if not M.helpers.starts_with(file_name, chat_dir) then
		return "resolved file (" .. file_name .. ") not in chat dir (" .. chat_dir .. ")"
	end

    -- Check for timestamp format in filename
    local basename = vim.fn.fnamemodify(file_name, ":t")
    if not basename:match("^%d%d%d%d%-%d%d%-%d%d") then
        return "file does not have timestamp format"
    end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines < 5 then
		return "file too short"
	end

	if not lines[1]:match("^# ") then
		return "missing topic header"
	end

	local header_found = nil
	for i = 1, 10 do
		if i < #lines and lines[i]:match("^- file: ") then
			header_found = true
			break
		end
	end
	if not header_found then
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

	vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
		strict = false,
		right_gravity = true,
		virt_text_pos = "right_align",
		virt_text = {
			{ "Current Agent: [" .. M._state.agent .. "]", "DiagnosticHint" },
		},
		hl_mode = "combine",
	})
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
	
	-- Add markdown code block shortcuts
	local md = require("parley.md")
	
	if M.config.chat_shortcut_copy_code_block then
		M.helpers.set_keymap({buf}, M.config.chat_shortcut_copy_code_block.modes, 
			M.config.chat_shortcut_copy_code_block.shortcut, md.copy_markdown_code_block, "Copy markdown code block")
	end
	
	if M.config.chat_shortcut_save_code_block then
		M.helpers.set_keymap({buf}, M.config.chat_shortcut_save_code_block.modes, 
			M.config.chat_shortcut_save_code_block.shortcut, md.save_markdown_code_block, "Save markdown code block")
	end
	
	if M.config.chat_shortcut_run_code_block then
		M.helpers.set_keymap({buf}, M.config.chat_shortcut_run_code_block.modes, 
			M.config.chat_shortcut_run_code_block.shortcut, md.run_code_block_in_terminal, "Run code block in terminal")
	end
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
	
	local ss = M.config.chat_shortcut_search
	if ss then
		-- Create a function for searching chat sections
		local function search_chat_sections()
			local user_prefix = M.config.chat_user_prefix
			local assistant_prefix = type(M.config.chat_assistant_prefix) == "string" 
				and M.config.chat_assistant_prefix 
				or M.config.chat_assistant_prefix[1] or ""
			vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(assistant_prefix))
		end
		
		for _, mode in ipairs(ss.modes) do
			M.helpers.set_keymap({ buf }, mode, ss.shortcut, search_chat_sections, "Parley prompt Search Chat Sections")
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
	if not vim.fn.filereadable(file_path) then
		return nil
	end
	
	local lines = vim.fn.readfile(file_path, "", 5) -- Read first 5 lines
	for _, line in ipairs(lines) do
		local topic = line:match("^# topic: (.+)")
		if topic then
			return topic
		end
	end
	
	return nil
end

-- Define namespace and highlighting colors for questions, annotations, and thinking
M.highlight_questions = function()
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
	
	-- Create aliases for backward compatibility
	vim.api.nvim_set_hl(0, "Question", { link = "ParleyQuestion" })
	vim.api.nvim_set_hl(0, "FileLoading", { link = "ParleyFileReference" })
	vim.api.nvim_set_hl(0, "Think", { link = "ParleyThinking" })
	vim.api.nvim_set_hl(0, "Annotation", { link = "ParleyAnnotation" })
	vim.api.nvim_set_hl(0, "Tag", { link = "ParleyTag" })
	
	return ns
end

-- Function to highlight chat references in non-chat markdown files
M.highlight_markdown_chat_refs = function(buf)
	local ns = M.highlight_questions()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	
	-- Track chat references to refresh topics
	local chat_references = {}
	
	for i, line in ipairs(lines) do
		-- Highlight chat file references (starts with @@/)
		if line:match("^@@%s*[^+]") or line:match("^@@/") then
			vim.api.nvim_buf_add_highlight(buf, ns, "FileLoading", i - 1, 0, -1)
			
			-- Extract chat path for topic refreshing
			local chat_path = line:match("^@@%s*([^:]+)")
			if chat_path then
				table.insert(chat_references, {
					line = i - 1,
					path = chat_path:gsub("^%s*(.-)%s*$", "%1"),
					line_text = line
				})
			end
		end
	end
	
	-- Refresh chat topics for all chat references
	for _, ref in ipairs(chat_references) do
		local expanded_path = vim.fn.expand(ref.path)
		
		-- Check if file exists and is readable
		if vim.fn.filereadable(expanded_path) == 1 then
			local topic = M.get_chat_topic(expanded_path)
			
			if topic then
				-- Check if the line already has a topic
				local current_topic = ref.line_text:match("^@@%s*[^:]+:%s*(.+)$")
				
				-- If topic changed or there wasn't one before, update it
				if not current_topic or current_topic ~= topic then
					-- Update the line with the new topic
					vim.api.nvim_buf_set_lines(buf, ref.line, ref.line + 1, false, {
						"@@" .. ref.path .. ": " .. topic
					})
					
					-- Log the topic update
					M.logger.debug("Updated chat reference topic for " .. ref.path .. " to: " .. topic)
				end
			end
		end
	end
end

-- Function to apply highlighting to chat blocks in the current buffer
M.highlight_question_block = function(buf)
	local ns = M.highlight_questions()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

	local in_block = false
	
	-- Get the configured prefix values from config
	local user_prefix = M.config.chat_user_prefix
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	local reasoning_prefix = memory_enabled and M.config.chat_memory.reasoning_prefix or "🧠:"
	local summary_prefix = memory_enabled and M.config.chat_memory.summary_prefix or "📝:"
	
	-- Get the assistant prefix (first part)
	local assistant_prefix
	if type(M.config.chat_assistant_prefix) == "string" then
		assistant_prefix = M.config.chat_assistant_prefix
	elseif type(M.config.chat_assistant_prefix) == "table" then
		assistant_prefix = M.config.chat_assistant_prefix[1]
	end

	for i, line in ipairs(lines) do
		-- Track which parts of the line have already been highlighted as tags
		local highlighted_regions = {}
		
		-- First, identify and mark all @@tag@@ patterns (closed tags)
		local pos = 1
		while true do
			local tag_start, content_start = line:find("@@", pos)
			if not tag_start then break end
			
			local content_end, tag_end = line:find("@@", content_start + 1)
			if not content_end then break end
			
			-- Record this region as a tag
			table.insert(highlighted_regions, {start = tag_start, finish = tag_end})
			
			-- Highlight the entire tag pattern including the @@ markers
			vim.api.nvim_buf_add_highlight(buf, ns, "Tag", i - 1, tag_start - 1, tag_end)
			
			-- Move to position after this tag
			pos = tag_end + 1
		end
		
		-- Process line based on its type
		if line:match("^" .. vim.pesc(reasoning_prefix)) or line:match("^" .. vim.pesc(summary_prefix)) then
			vim.api.nvim_buf_add_highlight(buf, ns, "Think", i - 1, 0, -1)
		elseif line:match("^" .. vim.pesc(user_prefix)) then
			vim.api.nvim_buf_add_highlight(buf, ns, "Question", i - 1, 0, -1)
			in_block = true
		elseif line:match("^" .. vim.pesc(assistant_prefix)) then
			in_block = false
		elseif in_block then
			vim.api.nvim_buf_add_highlight(buf, ns, "Question", i - 1, 0, -1)
			
			-- Simplified file path handling - only if line starts with @@ and isn't a tag
			if line:match("^@@") then
				-- Check if the beginning of the line is already part of a tag
				local is_tag_at_start = false
				if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
					is_tag_at_start = true
				end
				
				-- If not a tag, highlight as file inclusion
				if not is_tag_at_start then
					vim.api.nvim_buf_add_highlight(buf, ns, "FileLoading", i - 1, 0, -1)
				end
			end
		end

		-- Highlight annotations in the format @...@
		for start_idx, match_text, end_idx in line:gmatch"()@(.-)@()" do
			vim.api.nvim_buf_add_highlight(buf, ns, "Annotation", i - 1, start_idx - 1, end_idx - 1)
		end
	end
end

M.setup_markdown_keymaps = function(buf)
	-- Add <C-g>o keybinding to open chat file references
	local of = M.config.chat_shortcut_open_file
	if of then
		for _, mode in ipairs(of.modes) do
			M.helpers.set_keymap({ buf }, mode, of.shortcut, M.cmd.OpenFileUnderCursor, "Parley open chat reference under cursor")
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
		local current_line = vim.api.nvim_get_current_line()
		
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
			"@@" .. rel_path .. ": New chat"
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
		vim.api.nvim_win_set_cursor(0, {cursor_pos[1], col + #("@@" .. rel_path .. ": New chat")})
		
		-- Make sure we stay in insert mode
		vim.schedule(function()
			vim.cmd("startinsert")
		end)
		
		M.logger.info("Created reference to new chat: " .. rel_path)
	end, "Parley create and insert new chat")
end

M.buf_handler = function()
	local gid = M.helpers.create_augroup("ParleyBufHandler", { clear = true })

	-- Setup functions that only need to run when buffer is first loaded or entered
	M.helpers.autocmd({ "BufEnter" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		-- Handle chat files
		if M.not_chat(buf, file_name) == nil then
			M.prep_chat(buf, file_name)
			M.display_agent(buf, file_name)
			M.highlight_question_block(buf)
		-- Handle non-chat markdown files
		elseif M.is_markdown(buf, file_name) then
			-- Set up markdown features
			M.prep_md(buf)
			-- Set up keymaps for chat references
			M.setup_markdown_keymaps(buf)
			-- Highlight chat references
			M.highlight_markdown_chat_refs(buf)
		end
	end, gid)

	-- Highlighting refresh that can run on text changes
	M.helpers.autocmd({ "TextChanged", "TextChangedI" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		-- Handle chat files
		if M.not_chat(buf, file_name) == nil then
			M.highlight_question_block(buf)
		-- Handle non-chat markdown files
		elseif M.is_markdown(buf, file_name) then
			-- Refresh markdown highlighting only
			M.highlight_markdown_chat_refs(buf)
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
			M.highlight_question_block(buf)
		-- Handle non-chat markdown files
		elseif M.is_markdown(buf, file_name) then
			-- Refresh markdown highlighting
			M.highlight_markdown_chat_refs(buf)
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
	local open_mode = from_chat_finder and "Opening file in current window (from ChatFinder)" or "Opening file in current window"
	M.logger.debug(open_mode .. ": " .. file_name)
	vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_name))
	local buf = vim.api.nvim_get_current_buf()
	return buf
end

---@param system_prompt string | nil # system prompt to use
---@param agent table | nil # obtained from get_agent
---@return number # buffer number
M.new_chat = function(system_prompt, agent)
	local filename = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"

	-- encode as json if model is a table
	local model = ""
	local provider = ""
	if agent and agent.model and agent.provider then
		model = agent.model
		provider = agent.provider
		if type(model) == "table" then
			model = "- model: " .. vim.json.encode(model) .. "\n"
		else
			model = "- model: " .. model .. "\n"
		end

		provider = "- provider: " .. provider:gsub("\n", "\\n") .. "\n"
	end

	-- display system prompt as single line with escaped newlines
	if system_prompt then
		system_prompt = "- role: " .. system_prompt:gsub("\n", "\\n") .. "\n"
	else
		system_prompt = ""
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
M.cmd.ChatNew = function(params, system_prompt, agent)
	-- Simple version that just creates a new chat
	return M.new_chat(system_prompt, agent)
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

-- Internal helper: create a note file with a title and metadata (array of {key, value})
M._create_note_file = function(filename, title, metadata)
	local lines = {}
	table.insert(lines, "# " .. title)
	table.insert(lines, "")
	for _, kv in ipairs(metadata) do
		table.insert(lines, kv[1] .. ": " .. kv[2])
		table.insert(lines, "")
	end
	vim.fn.writefile(lines, filename)
	local buf = M.open_buf(filename)
	vim.api.nvim_command("normal! G")
	vim.api.nvim_command("startinsert")
	return buf
end

-- Function to find notes using telescope

-- Variable to store state for NoteFinder
-- Initial state for note finder, will be updated from persisted state
M._note_finder = {
	opened = false,
	source_win = nil,
	filter_mode = "recent", -- Filter mode: "recent" (3 months), "week" (this week), or "all"
	sort_mode = "access"    -- Sort mode: "access" (by last access time), "name" (by filename), "date" (by date in filename)
}

-- Create a new note with given subject
M.new_note = function(subject)
	-- Get current date
	local current_date = os.date("*t")
	local year = current_date.year
	local month = current_date.month
	local day = current_date.day
	
	-- Parse date from subject if provided in one of the formats:
	-- "YYYY-MM-DD subject" or "MM-DD subject" or "DD subject"
	local original_subject = subject
		-- Special-case: if the first word matches a directory under notes_root (including subfolders), create note there without date prefix
		do
			local head, rest = original_subject:match("^(%S+)%s+(.+)$")
			if head and rest then
				local notes_root = M.config.notes_dir
				local p = notes_root .. "/" .. head
				local target_dir = nil
				if vim.fn.isdirectory(p) == 1 then
					target_dir = p
				end
				if target_dir then
					local slug = rest:gsub(" ", "-")
					local filename = target_dir .. "/" .. slug .. ".md"
					-- Create the note using helper (no week metadata)
					local y = string.format("%04d", current_date.year)
					local mon = string.format("%02d", current_date.month)
					local d = string.format("%02d", current_date.day)
					return M._create_note_file(filename, rest, {{ "Date", y .. "-" .. mon .. "-" .. d }})
				end
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
	if not month or type(month) ~= "number" then month = os.date("*t").month end
	if not day or type(day) ~= "number" then day = os.date("*t").day end
	month = string.format("%02d", month)
	day = string.format("%02d", day)
	
	-- Create directory structure if it doesn't exist
	local year_dir = M.config.notes_dir .. "/" .. year
	local month_dir = year_dir .. "/" .. month
	
	-- Calculate week number and create week folder
	local date_str = year .. "-" .. month .. "-" .. day
	local week_number = M.helpers.get_week_number_sunday_based(date_str)
	if not week_number or type(week_number) ~= "number" then week_number = 1 end
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
    local date_str = year .. "-" .. month .. "-" .. day
    return M._create_note_file(filename, title, {{ "Date", date_str }, { "Week", week_folder }})
end

M.cmd.ChatDelete = function()
	-- get buffer and file
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- check if file is in the chat dir
	if not M.helpers.starts_with(file_name, vim.fn.resolve(M.config.chat_dir)) then
		M.logger.warning("File " .. vim.inspect(file_name) .. " is not in chat dir")
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

-- Parse a chat file into a structured representation
M.parse_chat = function(lines, header_end)
	local result = {
		headers = {},
		exchanges = {}
	}
	
	-- Parse headers
	for i = 1, header_end do
		local line = lines[i]
		local key, value = line:match("^[-#] (%w+): (.*)")
		if key ~= nil then
			result.headers[key] = value
		end
		
		-- Parse configuration override parameters
		local config_key, config_value = line:match("^%- ([%w_]+): (.*)")
		if config_key ~= nil and config_key ~= "file" and config_key ~= "model" and config_key ~= "provider" and config_key ~= "role" then
			-- Try to convert to number if possible
			if tonumber(config_value) ~= nil then
				config_value = tonumber(config_value)
			end
			result.headers["config_" .. config_key] = config_value
		end
	end
	
	-- Get prefixes
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	local summary_prefix = memory_enabled and M.config.chat_memory.summary_prefix or "📝:"
	local reasoning_prefix = memory_enabled and M.config.chat_memory.reasoning_prefix or "🧠:"
	local user_prefix = M.config.chat_user_prefix
	local old_user_prefix = "🗨:"

	M.logger.debug("memory config: " .. vim.inspect({memory_enabled, summary_prefix, reasoning_prefix}))

	-- Determine agent prefix
	local agent_prefix = M.config.chat_assistant_prefix[1]
	if type(M.config.chat_assistant_prefix) == "string" then
		agent_prefix = M.config.chat_assistant_prefix
	elseif type(M.config.chat_assistant_prefix) == "table" then
		agent_prefix = M.config.chat_assistant_prefix[1]
	end
	
	-- Track the current exchange and component being built
	local current_exchange = nil
	local current_component = nil
	
	-- Loop through content lines
	for i = header_end + 1, #lines do
		local line = lines[i]
		
		-- Check for user message start
		if line:sub(1, #user_prefix) == user_prefix or line:sub(1, #old_user_prefix) == old_user_prefix then
			-- If we were building a previous exchange, finalize it
			if current_exchange and current_component then
				current_exchange[current_component].line_end = i - 1
				current_exchange[current_component].content = current_exchange[current_component].content:gsub("^%s*(.-)%s*$", "%1")
			end
			
			-- Extract question content
			local question_content = line:sub(line:sub(1, #user_prefix) == user_prefix and #user_prefix + 1 or #old_user_prefix + 1)
			
			-- Start a new exchange
			current_exchange = {
				question = {
					line_start = i,
					line_end = nil,
					content = question_content,
					file_references = {} -- Will store file references we find (length > 0 means has references)
				},
				answer = nil
			}
			table.insert(result.exchanges, current_exchange)
			current_component = "question"
		
		-- Check for assistant message start
		elseif line:sub(1, #agent_prefix) == agent_prefix then
			-- If we were building a previous component, finalize it
			if current_exchange and current_component then
				current_exchange[current_component].line_end = i - 1
				current_exchange[current_component].content = current_exchange[current_component].content:gsub("^%s*(.-)%s*$", "%1")
			end
			
			-- Make sure we have an exchange to add this answer to
			if not current_exchange then
				-- Handle edge case: assistant message without preceding user message
				current_exchange = {
					question = {
						line_start = header_end + 1,
						line_end = i - 1,
						content = ""
					},
					answer = nil
				}
				table.insert(result.exchanges, current_exchange)
			end
			
			-- Start the answer component
			current_exchange.answer = {
				line_start = i,
				line_end = nil,
				content = ""
			}
			current_component = "answer"
			
		-- Check for summary line
		elseif current_component == "answer" and line:sub(1, #summary_prefix) == summary_prefix then
			current_exchange.summary = {
				line = i,
				content = line:sub(#summary_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}
			
		-- Check for reasoning line
		elseif current_component == "answer" and line:sub(1, #reasoning_prefix) == reasoning_prefix then
			current_exchange.reasoning = {
				line = i,
				content = line:sub(#reasoning_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}
			
		-- Handle content continuation
		elseif current_exchange and current_component then
			current_exchange[current_component].content = current_exchange[current_component].content .. "\n" .. line
			
			-- Check for file references in question content - ONLY at the beginning of a line
			local file_path = current_component == "question" and line:match("^@@%s*([^:]+)")

			if file_path then
				table.insert(current_exchange[current_component].file_references, {
					line = line,
					path = file_path:gsub("^%s*(.-)%s*$", "%1"),
					original_line_index = i,
				})
				M.logger.debug("Found file reference at line start: " .. line .. ", extracted path: " .. file_path)
			end
		end
	end
	
	-- Finalize the last component if needed
	if current_exchange and current_component then
		current_exchange[current_component].line_end = #lines
		current_exchange[current_component].content = current_exchange[current_component].content:gsub("^%s*(.-)%s*$", "%1")
	end
	
	return result
end

-- Find which exchange contains the given line
M.find_exchange_at_line = function(parsed_chat, line_number)
	for i, exchange in ipairs(parsed_chat.exchanges) do
		-- Check if the line is in the question
		if exchange.question and 
		   line_number >= exchange.question.line_start and 
		   line_number <= exchange.question.line_end then
			return i, "question"
		end
		
		-- Check if the line is in the answer
		if exchange.answer and 
		   line_number >= exchange.answer.line_start and 
		   line_number <= exchange.answer.line_end then
			return i, "answer"
		end
	end
	
	return nil, nil
end

M.chat_respond = function(params, callback, override_free_cursor, force)
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor_pos[1]
	
	-- Use the user's setting by default, but allow overriding
	-- This logic means:
	-- 1. If override_free_cursor is true, use_free_cursor should be false (force cursor movement)
	-- 2. If override_free_cursor is false, use_free_cursor should be true (prevent cursor movement)
	-- 3. If override_free_cursor is nil, fall back to config setting
	local use_free_cursor
	if override_free_cursor ~= nil then
		use_free_cursor = not override_free_cursor
	else
		use_free_cursor = M.config.chat_free_cursor
	end
	M.logger.debug("chat_respond configured cursor behavior - override: " .. tostring(override_free_cursor) .. 
	               ", final setting: " .. tostring(use_free_cursor))

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
	local header_end = nil
	for i, line in ipairs(lines) do
		if line:sub(1, 3) == "---" then
			header_end = i
			break
		end
	end

	if header_end == nil then
		M.logger.error("Error while parsing headers: --- not found. Check your chat template.")
		return
	end

	-- Parse chat into structured representation
	local parsed_chat = M.parse_chat(lines, header_end)
    M.logger.debug("chat_respond: parsed chat: ".. vim.inspect(parsed_chat))
	
	-- Determine which part of the chat to process based on cursor position
	local end_index = #lines
	local start_index = header_end + 1
	local exchange_idx, component = M.find_exchange_at_line(parsed_chat, cursor_line)
    M.logger.debug("chat_respond: exchange_idx and component under cursor ".. tostring(exchange_idx) .. " " .. tostring(component))
	
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
	local agent_name = agent.name
	
	-- Process headers for agent information
	local headers = parsed_chat.headers
	
	-- Prepare for summary extraction
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	
	-- Use header-defined max_full_exchanges if available, otherwise use config value
	local max_exchanges = 999999
	if memory_enabled then
		if headers.config_max_full_exchanges then
			max_exchanges = headers.config_max_full_exchanges
			M.logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
		else
			max_exchanges = M.config.chat_memory.max_full_exchanges
		end
	end
	
	local omit_user_text = memory_enabled and M.config.chat_memory.omit_user_text or "[Previous messages omitted]"
	
	-- Unescaping any JSON model specification in headers happens in get_agent_info
	
	-- Get combined agent information using the new helper function
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
				M.logger.debug("Exchange #" .. idx .. " preserved as current question")
	        end
			-- Preserve if it's a recent exchange (within max_full_exchanges from the end)
			if idx > total_exchanges - max_exchanges then
				should_preserve = true
				M.logger.debug("Exchange #" .. idx .. " preserved as recent exchange")
			end
			
			-- Preserve if it contains file references
			if #exchange.question.file_references > 0 then
				should_preserve = true
				M.logger.debug("Exchange #" .. idx .. " preserved due to file references")
			end
			
			-- Process the question
			if should_preserve then
				-- Get the question content and process any file loading directives
				local question_content = exchange.question.content
				local file_content = ""
				
				-- Use the precomputed file references instead of scanning for them again
				for _, file_ref in ipairs(exchange.question.file_references) do
					local path = file_ref.path
					local original_line = file_ref.line
					local line_index = file_ref.original_line_index
					
					M.logger.debug("Processing file reference: " .. path)
					
					-- Check if this is a directory or has directory pattern markers (* or **/)
					if M.helpers.is_directory(path) or 
					   path:match("/%*%*?/?") or  -- Contains /** or /**/ 
					   path:match("/%*%.%w+$") then -- Contains /*.ext pattern
						file_content = M.helpers.process_directory_pattern(path)
					else
						file_content = M.helpers.format_file_content(path)
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
						content = file_content .. "\n",
						cache_control = { type = "ephemeral" }
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
		
		-- For Claude specifically, we want to persist the system prompt
		local is_anthropic = (agent_info.provider == "anthropic" or agent_info.provider == "claude")
		if is_anthropic then
			messages[1].cache_control = { type = "ephemeral" }
		end
	end
	
	-- strip whitespace from ends of content
	for _, message in ipairs(messages) do
		message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
	end

	-- Find where to insert assistant response
	local response_line = M.helpers.last_content_line(buf)
	
	-- If cursor is on a question, handle insertion based on question position
	if exchange_idx and (component == "question" or component == "answer") then
		if parsed_chat.exchanges[exchange_idx].answer then
			-- If question already has an answer, replace it
			local answer = parsed_chat.exchanges[exchange_idx].answer
			
			-- Delete the existing answer
			vim.api.nvim_buf_set_lines(buf, answer.line_start - 1, answer.line_end, false, {})
			
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
		vim.api.nvim_buf_set_lines(buf, response_line + 1, response_line + 1, false, {""})
		response_line = response_line + 1
	end

	-- Write assistant prompt with extra newline, note later insertion point is response_line + 3
	vim.api.nvim_buf_set_lines(buf, response_line, response_line, false, { "", agent_prefix .. agent_suffix, "", "" })

	M.logger.debug("messages to send: " .. vim.inspect(messages))

	-- call the model and write response
	M.dispatcher.query(
		buf,
		agent_info.provider,
		M.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider),
		M.dispatcher.create_handler(buf, win, response_line + 3, true, "", not use_free_cursor),
		vim.schedule_wrap(function(qid)
			local qt = M.tasker.get_query(qid)
			if not qt then
				return
			end

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
					{ "", "", M.config.chat_user_prefix, "" }
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
						vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })
					end)
				)
			end
			
			-- Place cursor appropriately
			M.logger.debug("Cursor movement check - use_free_cursor: " .. tostring(use_free_cursor) .. 
			               ", config.chat_free_cursor: " .. tostring(M.config.chat_free_cursor))
			
			if not use_free_cursor then
				M.logger.debug("Moving cursor - exchange_idx: " .. tostring(exchange_idx) .. 
				               ", component: " .. tostring(component) ..
				               ", response_line: " .. tostring(response_line))
				               
				if exchange_idx and component == "question" then
					-- If we replaced an answer in the middle, move cursor to that position
					local line = response_line + 2
					M.logger.debug("Moving cursor to middle position: " .. tostring(line))
					M.helpers.cursor_to_line(line, buf, win)
				else
					-- Otherwise, move to the end of the buffer
					local line = vim.api.nvim_buf_line_count(buf)
					M.logger.debug("Moving cursor to end: " .. tostring(line))
					M.helpers.cursor_to_line(line, buf, win)
				end
			else
				M.logger.debug("Not moving cursor due to free_cursor setting")
			end
			vim.cmd("doautocmd User ParleyDone")
			
			-- Call the callback if provided
			if callback then
				callback()
			end
		end)
	)
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
	local header_end = nil
	for i, line in ipairs(lines) do
		if line:sub(1, 3) == "---" then
			header_end = i
			break
		end
	end
	
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
		{"Parley: ", "Type"},
		{"Resubmitting all " .. current_exchange_idx .. " questions...", "WarningMsg"}
	}, true, {})
	
	M.resubmit_questions_recursively(parsed_chat, 1, current_exchange_idx, header_end, original_question_line, win)
end

-- Recursively resubmit questions one at a time
-- We keep track of the original chat_free_cursor value to restore when done
local original_free_cursor_value = nil

M.resubmit_questions_recursively = function(parsed_chat, current_idx, max_idx, header_end, original_position, original_win)
	-- Save the original value on the first call
	if current_idx == 1 then
		original_free_cursor_value = M.config.chat_free_cursor
		M.logger.debug("Starting recursive resubmission - saving original chat_free_cursor: " .. tostring(original_free_cursor_value))
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
				{"Parley: ", "Type"},
				{"Completed resubmitting all questions", "String"}
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
	M.config.chat_free_cursor = false  -- Will be restored at the end of the resubmission
	
	M.chat_respond(params, function()
		-- After this question is processed, move to the next one
		-- We need to reparse the chat since content has changed
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local parsed_chat_updated = M.parse_chat(lines, header_end)
		
		-- Continue with the next question
		vim.defer_fn(function()
			M.resubmit_questions_recursively(parsed_chat_updated, current_idx + 1, max_idx, header_end, original_position, original_win)
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

-- Function to open a chat reference from a markdown file
M.open_chat_reference = function(current_line, cursor_col, in_insert_mode, full_line)
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
		-- Find @@ occurrences in the line
		local references = {}
		
		-- Look for instances of @@ in the line
		local start_idx = 1
		while true do
			local match_start, match_end = current_line:find("@@", start_idx)
			if not match_start then break end
			
			-- Find the end of this path (space, line end, or next @@)
			local content_end = nil
			
			-- Look for the next @@ after this one
			local next_marker = current_line:find("@@", match_end + 1)
			
			-- If there's no next marker, use the end of line
			if not next_marker then
				content_end = #current_line
			else
				content_end = next_marker - 1
			end
			
			-- Extract the path
			local path = current_line:sub(match_end + 1, content_end):gsub("^%s*(.-)%s*$", "%1")
			
			table.insert(references, {
				start = match_start,
				content = path
			})
			
			start_idx = match_end + 1
		end
		
		if #references == 0 then
			M.logger.warning("No chat reference (@@ syntax) found on current line")
			return
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
		
		chat_path = closest_ref.content
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
	local current_line = vim.api.nvim_buf_get_lines(buf, line_num-1, line_num, false)[1]
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
	local filepath = nil
	
	-- First check if the line begins with @@
	if current_line:match("^@@") then
		filepath = current_line:match("^@@(.+)$"):gsub("^%s*(.-)%s*$", "%1")
	else
		-- Find @@ occurrences in the line
		local references = {}
		
		-- Look for instances of @@ in the line
		local start_idx = 1
		while true do
			local match_start, match_end = current_line:find("@@", start_idx)
			if not match_start then break end
			
			-- Find the end of this path (space, line end, or next @@)
			local content_end = nil
			
			-- Look for the next @@ after this one
			local next_marker = current_line:find("@@", match_end + 1)
			
			-- If there's no next marker, use the end of line
			if not next_marker then
				content_end = #current_line
			else
				content_end = next_marker - 1
			end
			
			-- Extract the path
			local path = current_line:sub(match_end + 1, content_end):gsub("^%s*(.-)%s*$", "%1")
			
			table.insert(references, {
				start = match_start,
				content = path
			})
			
			start_idx = match_end + 1
		end
		
		if #references == 0 then
			M.logger.warning("No file reference (@@ syntax) found on current line")
			return
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
		
		filepath = closest_ref.content
	end
	
	-- Expand the path (handle relative paths, ~, etc.)
	local expanded_path = vim.fn.expand(filepath)
	
	-- Check if it's a directory or a directory pattern
	if M.helpers.is_directory(expanded_path) or 
	   filepath:match("/$") or 
	   filepath:match("/%*%*?/?") or 
	   filepath:match("/%*%.%w+$") then
		
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
	show_all = false, -- Track whether we're showing all files or just recent ones
	active_window = nil, -- Track the active window that initiated ChatFinder
	source_win = nil, -- Track the source window where ChatFinder was invoked
	insert_mode = false, -- Whether we're in insert mode (inserting chat references)
	insert_buf = nil, -- The buffer to insert into
	insert_line = nil, -- The line to insert at
	insert_col = nil, -- The column to insert at (for insert mode)
	insert_normal_mode = nil -- Whether we're inserting in normal mode or insert mode
}

M.cmd.ChatFinder = function(options)
	if M._chat_finder.opened then
		M.logger.warning("Chat finder is already open")
		return
	end
	M._chat_finder.opened = true
	
	-- IMPORTANT: The window should have been captured from the keybinding
	M.logger.debug("ChatFinder using source_win: " .. (M._chat_finder.source_win or "nil"))

	local dir = M.config.chat_dir
	local delete_shortcut = M.config.chat_finder_mappings.delete or M.config.chat_shortcut_delete
	local toggle_shortcut = M.config.chat_finder_mappings.toggle_all or { shortcut = "<C-g>h" }

	-- Launch telescope finder
	if pcall(require, "telescope") then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		
		-- Get all timestamp format files
		local files = vim.fn.glob(dir .. "/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*.md", false, true)
		local entries = {}
		
		-- Get recency configuration
		local recency_config = M.config.chat_finder_recency or {
			filter_by_default = true,
			months = 3,
			use_mtime = true
		}
		
		-- Calculate cutoff timestamp (current time - configured months)
		local current_time = os.time()
		local months_in_seconds = recency_config.months * 30 * 24 * 60 * 60
		local cutoff_time = current_time - months_in_seconds
		
		-- For calculating the prompt title
		local is_filtering = recency_config.filter_by_default and not M._chat_finder.show_all
		
		for _, file in ipairs(files) do
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
					sec = tonumber(sec)
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
			
			-- Get topic from the file
			local lines = vim.fn.readfile(file, "", 5) -- Read first 5 lines to get topic
			local topic = ""
			for _, line in ipairs(lines) do
				local t = line:match("^# topic: (.+)")
				if t then
					topic = t
					break
				end
			end
			
			-- Format date string
			local date_str = os.date("%Y-%m-%d", file_time)
			
			local filename = vim.fn.fnamemodify(file, ":t")
			table.insert(entries, {
				value = file,
				display = filename .. " - " .. topic .. " [" .. date_str .. "]",
				ordinal = filename .. " " .. topic,
				timestamp = file_time,
			})
			
			::continue::
		end
		
		-- Sort entries by timestamp (newest first)
		table.sort(entries, function(a, b) 
			return a.timestamp > b.timestamp
		end)
		
		-- Determine prompt title based on filtering state
		local prompt_title = is_filtering 
			and string.format("Chat Files (Recent: %d months)", recency_config.months) 
			or "Chat Files (All)"
		
		-- We'll use the active_window saved in M._chat_finder.active_window
			M.logger.debug("ChatFinder using active_window: " .. (M._chat_finder.active_window or "nil"))
		
		pickers.new({
			-- Use default Telescope behavior which is more consistent
			initial_mode = "insert",
		}, {
			prompt_title = prompt_title,
			finder = finders.new_table({
				results = entries,
				entry_maker = function(entry)
					return entry
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					
					-- Check if we're in insert mode (for inserting chat references)
					if M._chat_finder.insert_mode then
						-- Switch to the original source window first
						if M._chat_finder.source_win and vim.api.nvim_win_is_valid(M._chat_finder.source_win) then
							vim.api.nvim_set_current_win(M._chat_finder.source_win)
							M.logger.debug("Switched to source window for insert: " .. M._chat_finder.source_win)
						end
						
						if M._chat_finder.insert_buf and vim.api.nvim_buf_is_valid(M._chat_finder.insert_buf) then
							-- Extract topic from the display
							local topic = selection.display:match(" %- (.+) %[") or "Chat"
							
							-- Get relative path for better readability
							local rel_path = vim.fn.fnamemodify(selection.value, ":~:.")
							
							-- Handle normal mode insertion
							if M._chat_finder.insert_normal_mode then
								-- Insert a new line with the chat reference
								vim.api.nvim_buf_set_lines(
									M._chat_finder.insert_buf, 
									M._chat_finder.insert_line - 1, 
									M._chat_finder.insert_line - 1, 
									false, 
									{"@@" .. rel_path .. ": " .. topic}
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
								local new_line = current_line:sub(1, col) .. 
									"@@" .. rel_path .. ": " .. topic .. 
									current_line:sub(col + 1)
								
								vim.api.nvim_buf_set_lines(
									M._chat_finder.insert_buf,
									M._chat_finder.insert_line - 1,
									M._chat_finder.insert_line,
									false,
									{new_line}
								)
								
								-- Move cursor to the end of the inserted reference
								vim.api.nvim_win_set_cursor(0, {
									M._chat_finder.insert_line, 
									col + #("@@" .. rel_path .. ": " .. topic)
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
						-- First switch back to the source window where ChatFinder was invoked
						if M._chat_finder.source_win and vim.api.nvim_win_is_valid(M._chat_finder.source_win) then
							vim.api.nvim_set_current_win(M._chat_finder.source_win)
							M.logger.debug("Switched to source window for file open: " .. M._chat_finder.source_win)
						end
						M.open_buf(selection.value, true) -- Pass true to indicate this is from ChatFinder
					end
				end)
				
				-- Map delete shortcut
				map("i", delete_shortcut.shortcut, function()
					local selection = action_state.get_selected_entry()
					vim.ui.input({ prompt = "Delete " .. selection.value .. "? [y/N] " }, function(input)
						if input and input:lower() == "y" then
							M.helpers.delete_file(selection.value)
							actions.close(prompt_bufnr)
							-- Reopen finder to show updated list
							local source_win = M._chat_finder.source_win
							vim.defer_fn(function()
								M._chat_finder.opened = false
								M._chat_finder.source_win = source_win
								M.cmd.ChatFinder()
							end, 100)
						end
					end)
				end)
				
				-- Map toggle_all shortcut
				map("i", toggle_shortcut.shortcut, function()
					M._chat_finder.show_all = not M._chat_finder.show_all
					actions.close(prompt_bufnr)
					-- Reopen finder with new filter setting
					local source_win = M._chat_finder.source_win
					vim.defer_fn(function()
						M._chat_finder.opened = false
						M._chat_finder.source_win = source_win
						M.cmd.ChatFinder()
					end, 100)
				end)
				
				-- Also add normal mode mapping for toggle
				map("n", toggle_shortcut.shortcut, function()
					M._chat_finder.show_all = not M._chat_finder.show_all
					actions.close(prompt_bufnr)
					-- Reopen finder with new filter setting
					local source_win = M._chat_finder.source_win
					vim.defer_fn(function()
						M._chat_finder.opened = false
						M._chat_finder.source_win = source_win
						M.cmd.ChatFinder()
					end, 100)
				end)
				
				return true
			end,
		}):find()
	else
		M.logger.error("Telescope not found. ChatFinder requires telescope.nvim to be installed.")
	end
	
	M._chat_finder.opened = false
end

--------------------------------------------------------------------------------
-- Agent functionality
--------------------------------------------------------------------------------

M.cmd.Agent = function(params)
	local agent_name = string.gsub(params.args, "^%s*(.-)%s*$", "%1")
	if agent_name == "" then
		M.logger.info("Current agent: " .. M._state.agent)
		return
	end

	if not M.agents[agent_name] then
		M.logger.warning("Unknown agent: " .. agent_name)
		return
	end

	M.refresh_state({ agent = agent_name })
	M.logger.info("Agent set to: " .. M._state.agent)
	vim.cmd("doautocmd User ParleyAgentChanged")
end

M.cmd.NextAgent = function()
	local current_agent = M._state.agent
	local agent_list = M._agents

	local set_agent = function(agent_name)
		M.refresh_state({ agent = agent_name })
		M.logger.info("Agent: " .. M._state.agent)
		vim.cmd("doautocmd User ParleyAgentChanged")
	end

	for i, agent_name in ipairs(agent_list) do
		if agent_name == current_agent then
			set_agent(agent_list[i % #agent_list + 1])
			return
		end
	end
	set_agent(agent_list[1])
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

-- Aliases for backwards compatibility
M.get_chat_agent = M.get_agent

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
			system_prompt = "- role: " .. agent.system_prompt:gsub("\n", "\\n") .. "\n"
		end
	end
	
	-- Generate template using the same pattern as M.new_chat
	-- Get shortcuts, handling potentially missing values
	local respond_shortcut = M.config.chat_shortcut_respond and M.config.chat_shortcut_respond.shortcut or "<C-g><C-g>"
	local stop_shortcut = M.config.chat_shortcut_stop and M.config.chat_shortcut_stop.shortcut or "<C-g>s"
	local delete_shortcut = M.config.chat_shortcut_delete and M.config.chat_shortcut_delete.shortcut or "<C-g>d"
	local new_shortcut = M.config.global_shortcut_new and M.config.global_shortcut_new.shortcut or "<C-g>c"
	
	local template = M.render.template(M.config.chat_template or require("parley.defaults").chat_template, {
		["{{filename}}"] = "{{topic}}",  -- Will be replaced later with actual topic
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
	local info = {
		name = agent.name,
		provider = agent.provider,
		model = agent.model,
		system_prompt = agent.system_prompt,
		display_name = agent.name
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
		
		-- Override system prompt from headers
		if headers.role and headers.role:match("%S") then
			info.system_prompt = headers.role:gsub("\\n", "\n") -- Convert escaped newlines
		end
		
		-- Update display name if model or role is overridden
		if headers.model then
			if type(info.model) == "table" and info.model.model then
				info.display_name = info.model.model
			else
				info.display_name = tostring(info.model)
			end
			
			if headers.role and headers.role:match("%S") then
				info.display_name = info.display_name .. " & custom role"
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
