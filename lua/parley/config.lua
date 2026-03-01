-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/

--------------------------------------------------------------------------------
-- Default config
--------------------------------------------------------------------------------

---@class ParleyConfig
-- README_REFERENCE_MARKER_START
local config = {
	-- Please start with minimal config possible.
	-- Just openai_api_key if you don't have OPENAI_API_KEY env set up.
	-- Defaults change over time to improve things, options might get deprecated.
	-- It's better to change only things where the default doesn't fit your needs.

	-- required openai api key (string or table with command and arguments)
	-- openai_api_key = { "cat", "path_to/openai_api_key" },
	-- openai_api_key = { "bw", "get", "password", "OPENAI_API_KEY" },
	-- openai_api_key: "sk-...",
	-- openai_api_key = os.getenv("env_name.."),
	-- openai_api_key = os.getenv("OPENAI_API_KEY"),

	-- API keys for each provider - easy to override just this section without copying entire config
	-- Set these in your local configuration - this is separate from providers section
	api_keys = {
		-- Different ways to provide API keys (from lowest to highest security):
		-- 1. Hardcode: api_key = "sk-..."
		-- 2. Environment variable: api_key = os.getenv("OPENAI_API_KEY")
		-- 3. File: api_key = { "cat", "/path/to/api_key_file" }
		-- 4. Password manager: api_key = { "pass", "show", "openai-key" }
		-- 5. macOS Keychain: api_key = { "security", "find-generic-password", "-a", "your_username", "-s", "OPENAI_API_KEY", "-w" }
		
		openai = os.getenv("OPENAI_API_KEY"),
		anthropic = os.getenv("ANTHROPIC_API_KEY"),
		googleai = os.getenv("GOOGLEAI_API_KEY"),
		ollama = "dummy_secret", -- ollama typically uses a dummy token for local instances
		copilot = os.getenv("GITHUB_TOKEN"), -- for GitHub Copilot
	},
	
	-- at least one working provider is required
	-- to disable a provider set it to empty table like openai = {}
	providers = {
		openai = {
			disable = false,
			endpoint = "https://api.openai.com/v1/chat/completions",
			-- secret will be loaded from api_keys.openai
		},
		anthropic = {
			disable = false,
			endpoint = "https://api.anthropic.com/v1/messages",
			-- secret will be loaded from api_keys.anthropic
		},
		googleai = {
			disable = false,
			endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
			-- secret will be loaded from api_keys.googleai
		},
		ollama = {
			disable = true,
			endpoint = "http://localhost:11434/v1/chat/completions",
			-- secret will be loaded from api_keys.ollama
		},
	},

	-- prefix for all commands
	cmd_prefix = "Parley",
	-- optional curl parameters (for proxy, etc.)
	-- curl_params = { "--proxy", "http://X.X.X.X:XXXX" }
	curl_params = {},

	-- log file location
	log_file = vim.fn.stdpath("log"):gsub("/$", "") .. "/parley.nvim.log",
	-- write sensitive data to log file for debugging purposes (like api keys)
	log_sensitive = false,

	-- directory for persisting state dynamically changed by user (like model or persona)
	-- directory for persisting state dynamically changed by user (like model or persona)
	state_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/persisted",
  -- default per-chat: enable Claude server-side web_search tool
  claude_web_search = true,

	-- default agent name set during startup, if nil last used agent is used
	default_agent = nil,

	-- default agents (model + persona)
	-- name, model and system_prompt are mandatory fields
	-- to remove some default agent completely set it like:
	-- agents = {  { name = "ChatGPT3-5", disable = true, }, ... },
	agents = {
		{
			provider = "openai",
			name = "ChatGPT4",
			-- string with model name or table with model name and parameters
			model = { model = "gpt-4", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "openai",
			name = "ChatGPT5",
			-- string with model name or table with model name and parameters
			model = { model = "gpt-5", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
	        reasoning_effort = low,
		},
		{
			provider = "openai",
			name = "ChatGPT4o",
			-- string with model name or table with model name and parameters
			model = { model = "gpt-4o", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "openai",
			name = "ChatGPT-4o-search",
			-- string with model name or table with model name and parameters
			model = { model = "gpt-4o-search-preview", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "anthropic",
			name = "Claude-Sonnet",
			-- string with model name or table with model name and parameters
			model = { model = "claude-sonnet-4-20250514", temperature = 0.8, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "anthropic",
			name = "Claude-Haiku",
			-- string with model name or table with model name and parameters
			model = { model = "claude-3-5-haiku-latest", temperature = 0.8, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
	    },
		{
			provider = "ollama",
			name = "ChatOllamaLlama3.1-8B",
			-- string with model name or table with model name and parameters
			model = {
				model = "llama3.1",
				temperature = 0.6,
				top_p = 1,
				min_p = 0.05,
			},
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
			disable = true,
		},
		{
			provider = "googleai",
			name = "Gemini2.5-Pro",
			-- model list: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash
			-- string with model name or table with model name and parameters
			model = { model = "gemini-2.5-pro", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "googleai",
			name = "Gemini2.5-Flash",
			-- model list: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash
			-- string with model name or table with model name and parameters
			model = { model = "gemini-2.5-flash", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
	},

	-- named system prompts for reuse
	-- name, system_prompt are mandatory fields  
	-- to disable a system_prompt completely set it like:
	-- system_prompts = { { name = "creative", disable = true, }, ... },
	system_prompts = {
		{
			name = "default",
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			name = "creative", 
			system_prompt = "You are a creative and imaginative assistant. Think outside the box, offer unique perspectives, and help with creative problem-solving. Be expressive and engaging in your responses.",
		},
		{
			name = "concise",
			system_prompt = "You are a concise assistant. Provide brief, direct answers. No unnecessary explanations unless specifically requested. Get straight to the point.",
		},
		{
			name = "teacher",
			system_prompt = "You are a patient teacher. Break down complex concepts into simple explanations. Use examples and analogies when helpful. Encourage questions and learning.",
		},
		{
			name = "code_reviewer", 
			system_prompt = "You are a code reviewer focused on best practices, performance, security, and maintainability. Provide constructive feedback with specific improvement suggestions.",
		},
	},

	-- directory for storing chat files
	-- chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/chats",
    chat_dir = vim.fn.expand("~/Library/Mobile Documents/com~apple~CloudDocs/parley"),
    -- directory for storing notes
	notes_dir = vim.fn.expand("~/Library/Mobile Documents/com~apple~CloudDocs/notes"),
	-- export directories for different formats
	export_html_dir = vim.fn.expand("~/blogs/static"),
	export_markdown_dir = vim.fn.expand("~/blogs/_posts"),
	-- chat user prompt prefix
	chat_user_prefix = "💬:",
	-- chat assistant prompt prefix (static string or a table {static, template})
	-- first string has to be static, second string can contain template {{agent}}
	-- just a static string is legacy and the [{{agent}}] element is added automatically
	-- if you really want just a static string, make it a table with one element { "🤖:" }
	chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
	-- chat local section prefix (for content that should be ignored by parley processing)
	chat_local_prefix = "🔒:",
	-- The banner shown at the top of each chat file.
	chat_template = require("parley.defaults").short_chat_template,
	-- if you want more real estate in your chat files and don't need the helper text
	-- chat_template = require("parley.defaults").short_chat_template,
	-- chat topic generation prompt
	chat_topic_gen_prompt = "Summarize the topic of our conversation above"
		.. " in two or three words. Respond only with those words.",
	-- chat topic model (string with model name or table with model name and parameters)
	-- explicitly confirm deletion of a chat file
	chat_confirm_delete = true,
	-- conceal model parameters in chat
	chat_conceal_model_params = true,
	-- local shortcuts bound to the chat buffer
	-- (be careful to choose something which will work across specified modes)
	chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g><C-g>" },
	chat_shortcut_respond_all = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>G" },
	chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
	chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>s" },
	chat_shortcut_agent = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>a" },
	chat_shortcut_system_prompt = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>p" },
	chat_shortcut_search = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },
	chat_shortcut_open_file = { modes = { "n", "i" }, shortcut = "<C-g>o" },
	-- markdown code block shortcuts
	chat_shortcut_copy_code_block = { modes = { "n" }, shortcut = "<leader>gy" },
	chat_shortcut_save_code_block = { modes = { "n" }, shortcut = "<leader>gs" },
	chat_shortcut_run_code_block = { modes = { "n" }, shortcut = "<leader>gx" },
	chat_shortcut_copy_terminal = { modes = { "n" }, shortcut = "<leader>gc" },
	chat_shortcut_repeat_command = { modes = { "n" }, shortcut = "<leader>g!" },
	chat_shortcut_copy_terminal_from_chat = { modes = { "n" }, shortcut = "<leader>ge" },
	chat_shortcut_display_diff = { modes = { "n" }, shortcut = "<leader>gd" },
	
	-- global shortcuts (available in any buffer)
	global_shortcut_new = { modes = { "n", "i" }, shortcut = "<C-g>c" },
	global_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>f" },
	-- shortcut for adding chat references in markdown files
	global_shortcut_add_chat_ref = { modes = { "n", "i" }, shortcut = "<C-g>a" },
	-- global shortcuts for note taking
	global_shortcut_note_new = { modes = { "n", "i" }, shortcut = "<C-n>c" },
	global_shortcut_year_root = { modes = { "n", "i" }, shortcut = "<C-n>r" },
	-- shortcut for opening oil.nvim file explorer
	global_shortcut_oil = { modes = { "n" }, shortcut = "<leader>fo" },
	-- default search term when using :ParleyChatFinder
	chat_finder_pattern = "^# topic: ",
	chat_finder_mappings = {
		delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-d>" },
		toggle_all = { modes = { "n", "i", "v", "x" }, shortcut = "<C-a>" },
	},
	-- chat finder recency filtering configuration
	chat_finder_recency = {
		-- Enable recency filtering by default
		filter_by_default = true,
		-- Default recency period in months
		months = 6,
	},
	
	-- if true, finished ChatResponder won't move the cursor to the end of the buffer
	chat_free_cursor = true,
	-- use prompt buftype for chats (:h prompt-buffer)
	chat_prompt_buf_type = false,
	
	-- chat memory configuration (for summarizing older messages)
	chat_memory = {
		-- enable summary feature for older messages
		enable = true,
		-- maximum number of full exchanges to keep (a user and assistant pair)
		max_full_exchanges = 5,
		-- prefix for note lines in assistant responses (used to extract summaries)
		summary_prefix = "📝:",
		-- prefix for reasoning lines in assistant responses (used to ignore reasoning in subsequent requests)
		reasoning_prefix = "🧠:", 
		-- text to replace omitted user messages
		omit_user_text = "Summarize our chat",
	},

	-- styling for chatfinder
	---@type "single" | "double" | "rounded" | "solid" | "shadow" | "none"
	style_chat_finder_border = "single",
	-- margins are number of characters or lines
	style_chat_finder_margin_bottom = 8,
	style_chat_finder_margin_left = 1,
	style_chat_finder_margin_right = 2,
	style_chat_finder_margin_top = 2,
	-- how wide should the preview be, number between 0.0 and 1.0
	style_chat_finder_preview_ratio = 0.5,
	
	-- highlight styling (set to nil to use defaults that match your colorscheme)
	-- these settings override the default highlight links if provided
	highlight = {
		-- Use existing highlight groups by default (nil values)
		question = nil,       -- highlight for user questions (default: links to Keyword)
		file_reference = nil, -- highlight for file references (default: links to WarningMsg)
		thinking = nil,       -- highlight for reasoning lines (default: links to Comment)
		annotation = nil,     -- highlight for annotations (default: links to DiffAdd)
	},

	-- lualine integration options
	lualine = {
		-- enable lualine integration
		enable = true,
		-- which section to add the component to
		section = "lualine_x",
	},
	
	-- raw_mode configuration for easier debugging and iteration
	raw_mode = {
		-- Enable raw mode functionality
		enable = true,
		-- Mode 1: Show raw LLM JSON responses as code blocks
		show_raw_response = false,
		-- Mode 2: Parse user input as JSON to send directly to LLM
		parse_raw_request = false,
	},

    -- TODO: what are the following are needed?
    -- command config and templates below are used by commands like GpRewrite, GpEnew, etc.
	-- command prompt prefix for asking user for input (supports {{agent}} template variable)
	command_prompt_prefix_template = "🤖 {{agent}} ~ ",
	-- auto select command response (easier chaining of commands)
	-- if false it also frees up the buffer cursor for further editing elsewhere
	command_auto_select_response = true,

	-- example hook functions (see Extend functionality section in the README)
	hooks = {
		-- ParleyInspectPlugin provides a detailed inspection of the plugin state
		InspectPlugin = function(plugin, params)
			local bufnr = vim.api.nvim_create_buf(false, true)
			local copy = vim.deepcopy(plugin)
			local key = copy.config.openai_api_key or ""
			copy.config.openai_api_key = key:sub(1, 3) .. string.rep("*", #key - 6) .. key:sub(-3)
			local plugin_info = string.format("Plugin structure:\n%s", vim.inspect(copy))
			local params_info = string.format("Command params:\n%s", vim.inspect(params))
			local lines = vim.split(plugin_info .. "\n" .. params_info, "\n")
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
			vim.api.nvim_win_set_buf(0, bufnr)
		end,

		-- ParleyInspectLog for checking the log file
		InspectLog = function(plugin, params)
			local log_file = plugin.config.log_file
			local buffer = plugin.helpers.get_buffer(log_file)
			if not buffer then
				vim.cmd("e " .. log_file)
			else
				vim.cmd("buffer " .. buffer)
			end
		end,
	},
}
-- README_REFERENCE_MARKER_END

return config
