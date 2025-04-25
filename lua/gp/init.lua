-- Gp (GPT prompt) lua plugin for Neovim - Simplified Version
-- https://github.com/Robitx/gp.nvim/
-- This is a simplified version focused on chat functionality only

--------------------------------------------------------------------------------
-- Module structure
--------------------------------------------------------------------------------
local config = require("gp.config")

local M = {
	_Name = "Gp", -- plugin name
	_state = {}, -- table of state variables
	agents = {}, -- table of agents
	cmd = {}, -- default command functions
	config = {}, -- config variables
	hooks = {}, -- user defined command functions
	defaults = require("gp.defaults"), -- some useful defaults
	deprecator = require("gp.deprecator"), -- handle deprecated options
	dispatcher = require("gp.dispatcher"), -- handle communication with LLM providers
	helpers = require("gp.helper"), -- helper functions
	logger = require("gp.logger"), -- logger module
	outline = require("gp.outline"), -- outline navigation module
	render = require("gp.render"), -- render module
	tasker = require("gp.tasker"), -- tasker module
	vault = require("gp.vault"), -- handles secrets
}

--------------------------------------------------------------------------------
-- Module helper functions and variables
--------------------------------------------------------------------------------

local agent_completion = function()
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	if M.not_chat(buf, file_name) == nil then
		return M._chat_agents
	end
	return M._command_agents
end

-- setup function
M._setup_called = false
---@param opts GpConfig? # table with options
M.setup = function(opts)
	M._setup_called = true

	math.randomseed(os.time())

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

	M.vault.add_secret("openai_api_key", openai_api_key)
	M.config.openai_api_key = nil
	opts.openai_api_key = nil

	M.dispatcher.setup({ providers = opts.providers, curl_params = curl_params })
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

	-- prepare agent completions
	M._chat_agents = {}
	M._command_agents = {}
	for name, agent in pairs(M.agents) do
		M.agents[name].provider = M.agents[name].provider or "openai"

		if M.dispatcher.providers[M.agents[name].provider] then
			if agent.command then
				table.insert(M._command_agents, name)
			end
			if agent.chat then
				table.insert(M._chat_agents, name)
			end
		else
			M.agents[name] = nil
		end
	end
	table.sort(M._chat_agents)
	table.sort(M._command_agents)

	M.refresh_state()

	if M.config.default_command_agent then
		M.refresh_state({ command_agent = M.config.default_command_agent })
	end

	if M.config.default_chat_agent then
		M.refresh_state({ chat_agent = M.config.default_chat_agent })
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
	vim.keymap.set("n", "<C-g>f", ":" .. M.config.cmd_prefix .. "ChatFinder<CR>", { silent = true, desc = "Open Chat Finder" })
	vim.keymap.set("i", "<C-g>f", "<ESC>:" .. M.config.cmd_prefix .. "ChatFinder<CR>", { silent = true, desc = "Open Chat Finder" })
	
	vim.keymap.set("n", "<C-g>c", ":" .. M.config.cmd_prefix .. "ChatNew<CR>", { silent = true, desc = "Create New Chat" })
	vim.keymap.set("i", "<C-g>c", "<ESC>:" .. M.config.cmd_prefix .. "ChatNew<CR>", { silent = true, desc = "Create New Chat" })
	
	vim.keymap.set("n", "<C-g>a", ":" .. M.config.cmd_prefix .. "NextAgent<CR>", { silent = true, desc = "Cycle to Next Agent" })
	vim.keymap.set("i", "<C-g>a", "<ESC>:" .. M.config.cmd_prefix .. "NextAgent<CR>", { silent = true, desc = "Cycle to Next Agent" })
	
	-- Chat section navigation (search for question/answer markers)
	vim.keymap.set("n", "<C-g>n", function()
		local user_prefix = M.config.chat_user_prefix
		local assistant_prefix = type(M.config.chat_assistant_prefix) == "string" 
			and M.config.chat_assistant_prefix 
			or M.config.chat_assistant_prefix[1] or ""
		vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(assistant_prefix))
	end, { silent = true, desc = "Search for chat sections" })
	
	vim.keymap.set("i", "<C-g>n", function()
		local user_prefix = M.config.chat_user_prefix
		local assistant_prefix = type(M.config.chat_assistant_prefix) == "string" 
			and M.config.chat_assistant_prefix 
			or M.config.chat_assistant_prefix[1] or ""
		vim.cmd("/^" .. vim.pesc(user_prefix) .. "\\|^" .. vim.pesc(assistant_prefix))
	end, { silent = true, desc = "Search for chat sections" })

	local completions = {
		ChatNew = { },
		Agent = agent_completion,
	}

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

	if vim.fn.executable("curl") == 0 then
		M.logger.error("curl is not installed, run :checkhealth gp")
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

	if not M._state.chat_agent or not M.agents[M._state.chat_agent] then
		M._state.chat_agent = M._chat_agents[1]
	end

	if not M._state.command_agent or not M.agents[M._state.command_agent] then
		M._state.command_agent = M._command_agents[1]
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
	M.display_chat_agent(buf, file_name)
end

-- stop receiving gpt responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.cmd.Stop = function(signal)
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

---@param buf number # buffer number
---@param file_name string # file name
---@return string | nil # reason for not being a chat or nil if it is a chat
M.not_chat = function(buf, file_name)
	file_name = vim.fn.resolve(file_name)
	local chat_dir = vim.fn.resolve(M.config.chat_dir)

	if not M.helpers.starts_with(file_name, chat_dir) then
		return "resolved file (" .. file_name .. ") not in chat dir (" .. chat_dir .. ")"
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

M.display_chat_agent = function(buf, file_name)
	if M.not_chat(buf, file_name) then
		return
	end

	if buf ~= vim.api.nvim_get_current_buf() then
		return
	end

	local ns_id = vim.api.nvim_create_namespace("GpChatExt_" .. file_name)
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
		strict = false,
		right_gravity = true,
		virt_text_pos = "right_align",
		virt_text = {
			{ "Current Agent: [" .. M._state.chat_agent .. "]", "DiagnosticHint" },
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
		M.logger.debug("buffer already prepared: " .. buf)
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
			comment = "GPT prompt Chat Respond",
		},
		{
			command = "ChatNew",
			modes = M.config.chat_shortcut_new.modes,
			shortcut = M.config.chat_shortcut_new.shortcut,
			comment = "GPT prompt Chat New",
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
	M.helpers.set_keymap({ buf }, ds.modes, ds.shortcut, M.cmd.ChatDelete, "GPT prompt Chat Delete")

	local ss = M.config.chat_shortcut_stop
	M.helpers.set_keymap({ buf }, ss.modes, ss.shortcut, M.cmd.Stop, "GPT prompt Chat Stop")
	
	-- Set outline navigation keybinding
	M.helpers.set_keymap({ buf }, "n", "<C-g>t", M.cmd.Outline, "GPT prompt Outline Navigator")

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

-- Define namespace and highlighting colors for questions, annotations, and thinking
M.highlight_questions = function()
	-- Set up namespace
	local ns = vim.api.nvim_create_namespace("gp_question")
	
	-- Set up highlight groups
	vim.api.nvim_set_hl(0, "Question", {
		fg = "#ffaf00",
		bold = false,
		italic = true,
		sp = "#ffaa00",
	})
	
	vim.api.nvim_set_hl(0, "Annotation", {
		bg = "#205c2c", 
		fg = "#ffffff" 
	})
	
	vim.api.nvim_set_hl(0, "Think", {
		fg = "#777777" 
	})
	
	return ns
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
		if line:match("^" .. vim.pesc(reasoning_prefix)) or line:match("^" .. vim.pesc(summary_prefix)) then
			vim.api.nvim_buf_add_highlight(buf, ns, "Think", i - 1, 0, -1)
		elseif line:match("^" .. vim.pesc(user_prefix)) then
			vim.api.nvim_buf_add_highlight(buf, ns, "Question", i - 1, 0, -1)
			in_block = true
		elseif line:match("^" .. vim.pesc(assistant_prefix)) then
			in_block = false
		elseif in_block then
			vim.api.nvim_buf_add_highlight(buf, ns, "Question", i - 1, 0, -1)
		end

		-- Highlight annotations in the format @...@
		for start_idx, match_text, end_idx in line:gmatch"()@(.-)@()" do
			vim.api.nvim_buf_add_highlight(buf, ns, "Annotation", i - 1, start_idx - 1, end_idx - 1)
		end
	end
end

M.buf_handler = function()
	local gid = M.helpers.create_augroup("GpBufHandler", { clear = true })

	M.helpers.autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		M.prep_chat(buf, file_name)
		M.display_chat_agent(buf, file_name)
		
		-- Apply highlighting to chat files
		if M.not_chat(buf, file_name) == nil then
			M.highlight_question_block(buf)
		end
	end, gid)

	M.helpers.autocmd({ "WinEnter" }, nil, function(event)
		local buf = event.buf

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		local file_name = vim.api.nvim_buf_get_name(buf)

		M.display_chat_agent(buf, file_name)
		
		-- Apply highlighting to chat files
		if M.not_chat(buf, file_name) == nil then
			M.highlight_question_block(buf)
		end
	end, gid)
end

---@param file_name string
---@return number # buffer number
M.open_buf = function(file_name)
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

	-- Open in new buffer
	vim.api.nvim_command("edit " .. file_name)
	local buf = vim.api.nvim_get_current_buf()
	return buf
end

---@param system_prompt string | nil # system prompt to use
---@param agent table | nil # obtained from get_chat_agent
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

	local template = M.render.template(M.config.chat_template or require("gp.defaults").chat_template, {
		["{{filename}}"] = string.match(filename, "([^/]+)$"),
		["{{optional_headers}}"] = model .. provider .. system_prompt,
		["{{user_prefix}}"] = M.config.chat_user_prefix,
		["{{respond_shortcut}}"] = M.config.chat_shortcut_respond.shortcut,
		["{{cmd_prefix}}"] = M.config.cmd_prefix,
		["{{stop_shortcut}}"] = M.config.chat_shortcut_stop.shortcut,
		["{{delete_shortcut}}"] = M.config.chat_shortcut_delete.shortcut,
		["{{new_shortcut}}"] = M.config.chat_shortcut_new.shortcut,
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
---@param agent table | nil # obtained from get_chat_agent
---@return number # buffer number
M.cmd.ChatNew = function(params, system_prompt, agent)
	-- Simple version that just creates a new chat
	return M.new_chat(system_prompt, agent)
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
	end
	
	-- Get prefixes
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	local summary_prefix = memory_enabled and M.config.chat_memory.summary_prefix or "📝:"
	local reasoning_prefix = memory_enabled and M.config.chat_memory.reasoning_prefix or "🧠:"
	local user_prefix = M.config.chat_user_prefix
	local old_user_prefix = "🗨:"

	M.logger.debug("memory config: " .. vim.inspect({memory_enabled, summary_prefix, reasoning_prefix}))

	-- Determine agent prefix
	local agent_prefix = config.chat_assistant_prefix[1]
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
			
			-- Start a new exchange
			current_exchange = {
				question = {
					line_start = i,
					line_end = nil,
					content = line:sub(line:sub(1, #user_prefix) == user_prefix and #user_prefix + 1 or #old_user_prefix + 1)
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

M.chat_respond = function(params)
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor_pos[1]

	if M.tasker.is_busy(buf) then
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
			local ns_id = vim.api.nvim_create_namespace("GpResubmit")
			vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
			
			local highlight_start = parsed_chat.exchanges[exchange_idx].question.line_start
			vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)
			
			-- Always schedule the highlight to clear after a brief delay
			vim.defer_fn(function()
				vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
			end, 3000)
		end
	end

	-- Get agent to use
	local agent = M.get_chat_agent()
	local agent_name = agent.name
	
	-- Process headers for agent information
	local headers = parsed_chat.headers
	
	-- prepare for summary extraction
	local memory_enabled = M.config.chat_memory and M.config.chat_memory.enable
	local max_exchanges = memory_enabled and M.config.chat_memory.max_full_exchanges or 999999
	local omit_user_text = memory_enabled and M.config.chat_memory.omit_user_text or "[Previous messages omitted]"

	-- if model contains { } then it is a json string otherwise it is a model name
	if headers.model and headers.model:match("{.*}") then
		-- unescape underscores before decoding json
		headers.model = headers.model:gsub("\\_", "_")
		headers.model = vim.json.decode(headers.model)
	end

	if headers.model and type(headers.model) == "table" then
		agent_name = headers.model.model
	elseif headers.model and headers.model:match("%S") then
		agent_name = headers.model
	end

	if headers.role and headers.role:match("%S") then
		agent_name = agent_name .. " & custom role"
	end

	if headers.model and not headers.provider then
		headers.provider = "openai"
	end

	-- Set up agent prefixes
	local agent_prefix = config.chat_assistant_prefix[1]
	local agent_suffix = config.chat_assistant_prefix[2]
	if type(M.config.chat_assistant_prefix) == "string" then
		agent_prefix = M.config.chat_assistant_prefix
	elseif type(M.config.chat_assistant_prefix) == "table" then
		agent_prefix = M.config.chat_assistant_prefix[1]
		agent_suffix = M.config.chat_assistant_prefix[2] or ""
	end
	agent_suffix = M.render.template(agent_suffix, { ["{{agent}}"] = agent_name })

	-- Convert parsed_chat to messages for the model
	local all_messages = {}
	-- message_summaries stores the summary of corresponding exchange.
	local message_summaries = {}
	
	-- Add empty first message that will be replaced with system prompt
	table.insert(all_messages, { role = "", content = "" })
	
	-- Extract exchanges within our processing range
	for idx, exchange in ipairs(parsed_chat.exchanges) do
		if exchange.question and exchange.question.line_start >= start_index and 
		    idx <= exchange_idx then
			table.insert(all_messages, { role = "user", content = exchange.question.content })
			
			if exchange.answer and exchange.answer.line_start <= end_index and idx < exchange_idx then
		        -- insert assistant response and summary for all previous questions.
				table.insert(all_messages, { role = "assistant", content = exchange.answer.content })
				
				if exchange.summary then
					table.insert(message_summaries, exchange.summary.content)
				end
			end
		end
	end

	M.logger.debug("Messages: " .. vim.inspect(all_messages))

	-- simplify all_messages and message_summaries into messages, by use message_summaries instead of precise exchange recorded in all_messages
	local messages = {}
	if memory_enabled and #all_messages > 1 then -- Skip the empty first message
		local total_exchanges = math.floor((#all_messages - 1) / 2)

		if total_exchanges > max_exchanges then
			-- Keep only the most recent exchanges
			local messages_to_keep = max_exchanges * 2
			if messages_to_keep < #all_messages - 2 then
				-- Create a summary message pair at the beginning
				messages = {
					{
						role = "user",
						content = omit_user_text
					}
				}

				-- Compile all summary lines into one message
				M.logger.debug("# of summaries: ".. tostring(#message_summaries) .. " and messages: " .. tostring(#all_messages))
				if #message_summaries > 0 then
					local summary_content = " "
					for i = 1, #message_summaries - max_exchanges do
						summary_content = summary_content .. message_summaries[i] .. "\n"
					end

					table.insert(messages, {
						role = "assistant",
						content = summary_content
					})
				end

				-- Add the remaining messages (most recent ones)
				for i = #all_messages - messages_to_keep, #all_messages do
					table.insert(messages, all_messages[i])
				end
			else
				-- If we don't actually have enough messages to summarize, use all of them
				messages = all_messages
			end
		else
			-- Not enough exchanges to trigger summarization
			messages = all_messages
		end
	else
		-- Memory feature disabled, use all messages
		messages = all_messages
	end

	M.logger.debug("messages to send" .. vim.inspect(messages))

	-- replace first empty message with system prompt
	content = ""
	if headers.role and headers.role:match("%S") then
		content = headers.role
	else
		content = agent.system_prompt
	end
	if content:match("%S") then
		-- make it multiline again if it contains escaped newlines
		content = content:gsub("\\n", "\n")
		messages[1] = { role = "system", content = content }
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

	-- Write assistant prompt
	vim.api.nvim_buf_set_lines(buf, response_line, response_line, false, { "", agent_prefix .. agent_suffix, "" })

	-- call the model and write response
	M.dispatcher.query(
		buf,
		headers.provider or agent.provider,
		M.dispatcher.prepare_payload(messages, headers.model or agent.model, headers.provider or agent.provider),
		M.dispatcher.create_handler(buf, win, response_line + 2, true, "", not M.config.chat_free_cursor),
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
					headers.provider or agent.provider,
					M.dispatcher.prepare_payload(messages, headers.model or agent.model, headers.provider or agent.provider),
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
			if not M.config.chat_free_cursor then
				if exchange_idx and component == "question" then
					-- If we replaced an answer in the middle, move cursor to that position
					local line = response_line + 2
					M.helpers.cursor_to_line(line, buf, win)
				else
					-- Otherwise, move to the end of the buffer
					local line = vim.api.nvim_buf_line_count(buf)
					M.helpers.cursor_to_line(line, buf, win)
				end
			end
			vim.cmd("doautocmd User GpDone")
		end)
	)
end

M.cmd.ChatRespond = function(params)
	if params.args == "" and vim.v.count == 0 then
		M.chat_respond(params)
		return
	elseif params.args == "" and vim.v.count ~= 0 then
		params.args = tostring(vim.v.count)
	end

	-- ensure args is a single positive number
	local n_requests = tonumber(params.args)
	if n_requests == nil or math.floor(n_requests) ~= n_requests or n_requests <= 0 then
		M.logger.warning("args for ChatRespond should be a single positive number, not: " .. params.args)
		return
	end

	-- Get all lines of the buffer
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	
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
	
	-- Parse chat structure to find exchanges
	local parsed_chat = M.parse_chat(lines, header_end)
    M.logger.debug("ChatRespond: parsed chat: ".. vim.inspect(parsed_chat))
	
	-- Find the nth question from the end
	if #parsed_chat.exchanges >= n_requests then
		local exchange_idx = #parsed_chat.exchanges - n_requests + 1
		
		-- Set range to process everything from start up to the identified exchange
		if parsed_chat.exchanges[exchange_idx].answer then
			params.range = 2
			params.line1 = header_end + 1
			params.line2 = parsed_chat.exchanges[exchange_idx].answer.line_end
		else
			-- If no answer, process to the end of the file
			params.range = 2
			params.line1 = header_end + 1
			params.line2 = #lines
		end
	else
		-- If not enough exchanges, process everything
		params.range = 2
		params.line1 = header_end + 1
		params.line2 = #lines
	end
	
	M.chat_respond(params)
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

M._chat_finder_opened = false
M.cmd.ChatFinder = function()
	if M._chat_finder_opened then
		M.logger.warning("Chat finder is already open")
		return
	end
	M._chat_finder_opened = true

	local dir = M.config.chat_dir
	local delete_shortcut = M.config.chat_finder_mappings.delete or M.config.chat_shortcut_delete

	-- Launch telescope finder
	if pcall(require, "telescope") then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")
		
		local files = vim.fn.glob(dir .. "/*.md", false, true)
		local entries = {}
		
		for _, file in ipairs(files) do
			local lines = vim.fn.readfile(file, "", 5) -- Read first 5 lines to get topic
			local topic = ""
			for _, line in ipairs(lines) do
				local t = line:match("^# topic: (.+)")
				if t then
					topic = t
					break
				end
			end
			
			local filename = vim.fn.fnamemodify(file, ":t")
			table.insert(entries, {
				value = file,
				display = filename .. " - " .. topic,
				ordinal = filename .. " " .. topic,
			})
		end
		
		pickers.new({}, {
			prompt_title = "Chat Files",
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
					M.open_buf(selection.value)
				end)
				
				map("i", delete_shortcut.shortcut, function()
					local selection = action_state.get_selected_entry()
					vim.ui.input({ prompt = "Delete " .. selection.value .. "? [y/N] " }, function(input)
						if input and input:lower() == "y" then
							M.helpers.delete_file(selection.value)
							actions.close(prompt_bufnr)
							-- Reopen finder to show updated list
							vim.defer_fn(function()
								M._chat_finder_opened = false
								M.cmd.ChatFinder()
							end, 100)
						end
					end)
				end)
				
				return true
			end,
		}):find()
	else
		M.logger.error("Telescope not found. ChatFinder requires telescope.nvim to be installed.")
	end
	
	M._chat_finder_opened = false
end

--------------------------------------------------------------------------------
-- Agent functionality
--------------------------------------------------------------------------------

M.cmd.Agent = function(params)
	local agent_name = string.gsub(params.args, "^%s*(.-)%s*$", "%1")
	if agent_name == "" then
		M.logger.info(" Chat agent: " .. M._state.chat_agent .. "  |  Command agent: " .. M._state.command_agent)
		return
	end

	if not M.agents[agent_name] then
		M.logger.warning("Unknown agent: " .. agent_name)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local is_chat = M.not_chat(buf, file_name) == nil
	if is_chat and M.agents[agent_name].chat then
		M.refresh_state({ chat_agent = agent_name })
		M.logger.info("Chat agent: " .. M._state.chat_agent)
	elseif M.agents[agent_name].command then
		M.refresh_state({ command_agent = agent_name })
		M.logger.info("Command agent: " .. M._state.command_agent)
	else
		M.logger.warning(agent_name .. " is not a valid agent for current buffer")
		M.refresh_state()
	end
end

M.cmd.NextAgent = function()
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local is_chat = M.not_chat(buf, file_name) == nil
	local current_agent, agent_list

	if is_chat then
		current_agent = M._state.chat_agent
		agent_list = M._chat_agents
	else
		current_agent = M._state.command_agent
		agent_list = M._command_agents
	end

	local set_agent = function(agent_name)
		if is_chat then
			M.refresh_state({ chat_agent = agent_name })
			M.logger.info("Chat agent: " .. M._state.chat_agent)
		else
			M.refresh_state({ command_agent = agent_name })
			M.logger.info("Command agent: " .. M._state.command_agent)
		end
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
---@return table | nil # { cmd_prefix, name, model, system_prompt, provider}
M.get_command_agent = function(name)
	name = name or M._state.command_agent
	if M.agents[name] == nil then
		M.logger.warning("Command Agent " .. name .. " not found, using " .. M._state.command_agent)
		name = M._state.command_agent
	end
	local template = M.config.command_prompt_prefix_template
	local cmd_prefix = M.render.template(template, { ["{{agent}}"] = name })
	local model = M.agents[name].model
	local system_prompt = M.agents[name].system_prompt
	local provider = M.agents[name].provider
	M.logger.debug("getting command agent: " .. name)
	return {
		cmd_prefix = cmd_prefix,
		name = name,
		model = model,
		system_prompt = system_prompt,
		provider = provider,
	}
end

---@param name string | nil
---@return table # { cmd_prefix, name, model, system_prompt, provider }
M.get_chat_agent = function(name)
	name = name or M._state.chat_agent
	if M.agents[name] == nil then
		M.logger.warning("Chat Agent " .. name .. " not found, using " .. M._state.chat_agent)
		name = M._state.chat_agent
	end
	local template = M.config.command_prompt_prefix_template
	local cmd_prefix = M.render.template(template, { ["{{agent}}"] = name })
	local model = M.agents[name].model
	local system_prompt = M.agents[name].system_prompt
	local provider = M.agents[name].provider
	M.logger.debug("getting chat agent: " .. name)
	return {
		cmd_prefix = cmd_prefix,
		name = name,
		model = model,
		system_prompt = system_prompt,
		provider = provider,
	}
end

return M