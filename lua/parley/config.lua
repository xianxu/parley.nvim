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
		cliproxyapi = os.getenv("CLIPROXYAPI_API_KEY"),
	},

	-- Google Drive OAuth configuration for @@ URL references
	-- Users can override with plaintext values in their setup() call.
	google_drive = {
		client_id = "",
		client_secret = "",
		scopes = { "https://www.googleapis.com/auth/drive.readonly" },
	},

	-- Provider-neutral OAuth configuration for remote @@ URL references.
	-- New provider integrations should be added here. The legacy
	-- `google_drive` config above remains supported for backward compatibility.
	oauth = {
		dropbox = {
			client_id = "",
			client_secret = "",
			redirect_port = nil,
			scopes = { "sharing.read" },
		},
		google = {
			client_id = "",
			client_secret = "",
			redirect_port = nil,
			scopes = { "https://www.googleapis.com/auth/drive.readonly" },
		},
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
		cliproxyapi = {
			disable = false,
			endpoint = "http://127.0.0.1:8317/v1/chat/completions",
			-- default strategy; model.web_search_strategy can override per agent/model
			-- none | openai_search_model | openai_tools_route | anthropic_tools_route
			web_search_strategy = "openai_tools_route",
			-- secret will be loaded from api_keys.cliproxyapi
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
	-- default per-chat: enable server-side web_search tool (supported by Anthropic, GoogleAI, OpenAI)
	web_search = true,

	-- default agent name set during startup, if nil last used agent is used
	default_agent = nil,

	-- default agents (model + persona)
	-- name, model and system_prompt are mandatory fields
	-- to remove some default agent completely set it like:
	-- agents = {  { name = "ChatGPT3-5", disable = true, }, ... },
	agents = {
		{
			provider = "openai",
			name = "GPT5.4",
			-- string with model name or table with model name and parameters
			-- search_model: when web_search is enabled, swap to this model
			model = { model = "gpt-5.4", temperature = 0.8, top_p = 1, search_model = "gpt-5-search-api" },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "openai",
			name = "GPT5.4-pro",
			-- string with model name or table with model name and parameters
			-- search_model: when web_search is enabled, swap to this model
			model = { model = "gpt-5.4-pro", temperature = 0.8, top_p = 1, search_model = "gpt-5-search-api" },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "openai",
			name = "GPT5-mini",
			-- string with model name or table with model name and parameters
			-- search_model: when web_search is enabled, swap to this model
			model = { model = "gpt-5-mini", temperature = 0.8, top_p = 1, search_model = "gpt-5-search-api" },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "anthropic",
			name = "Claude-Opus",
			-- string with model name or table with model name and parameters
			model = { model = "claude-opus-4-6", temperature = 0.8 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "anthropic",
			name = "Claude-Sonnet",
			-- string with model name or table with model name and parameters
			model = { model = "claude-sonnet-4-6", temperature = 0.8 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			-- Agentic Claude: enables client-side filesystem tool use so the
			-- model can read, edit, and write files inside the working
			-- directory. Headline M1 deliverable of issue #81.
			provider = "anthropic",
			name = "ClaudeAgentTools",
			model = { model = "claude-sonnet-4-6", temperature = 0.8 },
			system_prompt = require("parley.defaults").chat_system_prompt,
			tools = { "read_file", "ls", "find", "grep", "edit_file", "write_file" },
			-- Optional: defaults applied at setup time when absent
			-- max_tool_iterations = 20,
			-- tool_result_max_bytes = 102400,
		},
		-- {
		-- 	provider = "anthropic",
		-- 	name = "Claude-Haiku",
		-- 	-- string with model name or table with model name and parameters
		-- 	model = { model = "claude-haiku-4-5", temperature = 0.8 },
		-- 	-- system prompt (use this to specify the persona/role of the AI)
		-- 	system_prompt = require("parley.defaults").chat_system_prompt,
		-- },
		-- {
		-- 	provider = "ollama",
		-- 	name = "ChatOllamaLlama3.1-8B",
		-- 	-- string with model name or table with model name and parameters
		-- 	model = {
		-- 		model = "llama3.1",
		-- 		temperature = 0.6,
		-- 		top_p = 1,
		-- 		min_p = 0.05,
		-- 	},
		-- 	-- system prompt (use this to specify the persona/role of the AI)
		-- 	system_prompt = require("parley.defaults").chat_system_prompt,
		-- 	disable = true,
		-- },
		{
			provider = "googleai",
			name = "Gemini3.1-Pro",
			-- model list: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash
			-- string with model name or table with model name and parameters
			model = { model = "gemini-3.1-pro-preview", temperature = 1.1, top_p = 1 },
			-- system prompt (use this to specify the persona/role of the AI)
			system_prompt = require("parley.defaults").chat_system_prompt,
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
			name = "Gemini3-Flash",
			-- model list: https://cloud.google.com/vertex-ai/generative-ai/docs/models/gemini/2-5-flash
			-- string with model name or table with model name and parameters
			model = { model = "gemini-3-flash-preview", temperature = 1.1, top_p = 1 },
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
		{
			provider = "cliproxyapi",
			name = "Claude-Code-Sonnet",
			-- CLIProxy web-search tool access currently requires code_execution model family.
			model = { model = "claude-sonnet-4-6", temperature = 0.8, web_search_strategy = "anthropic_tools_route" },
			system_prompt = require("parley.defaults").chat_system_prompt,
		},
		{
			provider = "cliproxyapi",
			name = "Claude-Code-Opus",
			-- CLIProxy web-search tool access currently requires code_execution model family.
			model = { model = "claude-opus-4-6", temperature = 0.8, web_search_strategy = "anthropic_tools_route" },
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
	-- structured chat roots metadata; if empty, it is derived from chat_dir + chat_dirs
	chat_roots = {},
	-- additional chat roots searched by chat-aware features; new chats still use chat_dir
	chat_dirs = {},
	-- directory for storing notes
	notes_dir = vim.fn.expand("~/Library/Mobile Documents/com~apple~CloudDocs/notes"),
	-- export directories for different formats
	export_html_dir = vim.fn.expand("~/blogs/static"),
	export_markdown_dir = vim.fn.expand("~/blogs/posts"),
	-- chat user prompt prefix
	chat_user_prefix = "💬:",
	-- chat assistant prompt prefix (static string or a table {static, template})
	-- first string has to be static, second string can contain template {{agent}}
	-- just a static string is legacy and the [{{agent}}] element is added automatically
	-- if you really want just a static string, make it a table with one element { "🤖:" }
	chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
	-- chat local section prefix (for content that should be ignored by parley processing)
	chat_local_prefix = "🔒:",
	-- chat branch prefix (for tree-of-chat links: parent back-link on first line, child branches in body)
	chat_branch_prefix = "🌿:",
	-- tool use prefix (client-side tool call emitted by the LLM during agentic loop)
	chat_tool_use_prefix = "🔧:",
	-- tool result prefix (parley's response to a tool_use, or synthetic cancel/cap marker)
	chat_tool_result_prefix = "📎:",
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
	chat_shortcut_delete_tree = { modes = { "n" }, shortcut = "<C-g>D" },
	chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>x" },
	-- Toggle folds of 🔧:/📎: components within the exchange under cursor
	chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<C-g>b" },
	chat_shortcut_agent = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>a" },
	chat_shortcut_system_prompt = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>s" },
	chat_shortcut_follow_cursor = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>l" },
	chat_shortcut_search = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>n" },
	chat_shortcut_open_file = { modes = { "n", "i" }, shortcut = "<C-g>o" },
	chat_shortcut_prune = { modes = { "n" }, shortcut = "<C-g>p" },
	chat_shortcut_export_markdown = { modes = { "n" }, shortcut = "<C-g>em" },
	chat_shortcut_export_html = { modes = { "n" }, shortcut = "<C-g>eh" },
	chat_shortcut_exchange_cut = { modes = { "n", "v" }, shortcut = "<C-g>X" },
	chat_shortcut_exchange_paste = { modes = { "n" }, shortcut = "<C-g>V" },
	chat_shortcut_copy_fence = { modes = { "n" }, shortcut = "<leader>cf" },
	-- global shortcuts (available in any buffer)
	global_shortcut_copy_location = { modes = { "n", "v" }, shortcut = "<leader>cl" },
	global_shortcut_copy_location_content = { modes = { "n", "v" }, shortcut = "<leader>cL" },
	global_shortcut_copy_context = { modes = { "n", "v" }, shortcut = "<leader>cc" },
	global_shortcut_new = { modes = { "n", "i" }, shortcut = "<C-g>c" },
	global_shortcut_review = { modes = { "n" }, shortcut = "<C-g>C" },
	global_shortcut_finder = { modes = { "n", "i" }, shortcut = "<C-g>f" },
	global_shortcut_chat_dirs = { modes = { "n", "i" }, shortcut = "<C-g>h" },
	global_shortcut_keybindings = { modes = { "n", "i" }, shortcut = "<C-g>?" },
	-- shortcut for adding chat references in markdown files
	global_shortcut_add_chat_ref = { modes = { "n", "i" }, shortcut = "<C-g>a" },
	-- global shortcuts for note taking
	global_shortcut_note_new = { modes = { "n", "i" }, shortcut = "<C-n>c" },
	global_shortcut_note_finder = { modes = { "n", "i" }, shortcut = "<C-n>f" },
	global_shortcut_year_root = { modes = { "n", "i" }, shortcut = "<C-n>r" },
	-- shortcut for opening oil.nvim file explorer
	global_shortcut_oil = { modes = { "n" }, shortcut = "<leader>fo" },
	-- default search term when using :ParleyChatFinder
	chat_finder_pattern = "",
	chat_finder_mappings = {
		delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-d>" },
		delete_tree = { modes = { "n", "i", "v", "x" }, shortcut = "<C-D>" },
		move = { modes = { "n", "i", "v", "x" }, shortcut = "<C-x>" },
		next_recency = { modes = { "n", "i", "v", "x" }, shortcut = "<C-a>" },
		previous_recency = { modes = { "n", "i", "v", "x" }, shortcut = "<C-s>" },
	},
	-- chat finder recency filtering configuration
	chat_finder_recency = {
		-- Enable recency filtering by default
		filter_by_default = true,
		-- Default recency period in months
		months = 12,
		-- Additional recency presets cycled in the finder before "All"
		presets = { 6, 12 },
	},
	note_finder_mappings = {
		delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-d>" },
		next_recency = { modes = { "n", "i", "v", "x" }, shortcut = "<C-a>" },
		previous_recency = { modes = { "n", "i", "v", "x" }, shortcut = "<C-s>" },
	},
	note_finder_recency = {
		filter_by_default = true,
		months = 3,
		presets = { 3, 6, 12 },
	},
	-- repo-local parley detection (marker file in git root enables repo mode)
	repo_marker = ".parley",
	-- chat dir within repo when repo mode is active (relative to git root)
	repo_chat_dir = "design",
	-- issue management (repo-local, relative to git root)
	issues_dir = "issues",
	-- issue history (repo-local, relative to git root)
	history_dir = "history",
	-- vision tracker (repo-local, relative to git root)
	vision_dir = "vision",
	-- global shortcuts for vision tracker
	global_shortcut_vision_validate = { modes = { "n" }, shortcut = "<C-j>v" },
	global_shortcut_vision_export_csv = { modes = { "n" }, shortcut = "<C-j>ec" },
	global_shortcut_vision_export_dot = { modes = { "n" }, shortcut = "<C-j>ed" },
	global_shortcut_vision_finder = { modes = { "n", "i" }, shortcut = "<C-j>f" },
	global_shortcut_vision_new = { modes = { "n" }, shortcut = "<C-j>n" },
	global_shortcut_vision_goto = { modes = { "n" }, shortcut = "<C-j>o" },
	-- global shortcuts for issue management
	global_shortcut_issue_new = { modes = { "n", "i" }, shortcut = "<C-y>c" },
	global_shortcut_issue_finder = { modes = { "n", "i" }, shortcut = "<C-y>f" },
	global_shortcut_issue_next = { modes = { "n", "i" }, shortcut = "<C-y>x" },
	global_shortcut_issue_status = { modes = { "n" }, shortcut = "<C-y>s" },
	global_shortcut_issue_decompose = { modes = { "n" }, shortcut = "<C-y>i" },
	global_shortcut_issue_goto = { modes = { "n" }, shortcut = "<C-y>g" },
	issue_finder_mappings = {
		delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-d>" },
		cycle_status = { modes = { "n", "i", "v", "x" }, shortcut = "<C-s>" },
		toggle_done = { modes = { "n", "i", "v", "x" }, shortcut = "<C-a>" },
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
		max_full_exchanges = 42,
		-- prefix for note lines in assistant responses (used to extract summaries)
		summary_prefix = "📝:",
		-- prefix for reasoning lines in assistant responses (used to ignore reasoning in subsequent requests)
		reasoning_prefix = "🧠:",
		-- text to replace omitted user messages
		omit_user_text = "Summarize our chat",
	},

	-- memory preferences: per-tag user preference profiles from chat history
	memory_prefs = {
		-- enable auto-generation and system prompt injection
		enable = true,
		-- max recent files per tag to include summaries from
		max_files = 100,
		-- max age in days before re-generating
		max_age_days = 1,
		-- prompt sent to LLM to generate preference profile
		prompt = "Based on the following chat history summaries, generate a concise user preference profile that captures the user's interests, expertise level, and communication preferences. Output only the profile text.",
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
		question = nil, -- highlight for user questions (default: links to Keyword)
		file_reference = nil, -- highlight for file references (default: links to WarningMsg)
		thinking = nil, -- highlight for reasoning lines (default: links to Comment)
		annotation = nil, -- highlight for annotations (default: links to DiffAdd)
		approximate_match = nil, -- highlight for typo-tolerance edit positions in picker matches (default: links to IncSearch)
		chat_reference = nil, -- highlight for 🌿: chat branch/parent links (default: links to Special)
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
			vim.bo[bufnr].bufhidden = "wipe"
			vim.bo[bufnr].buflisted = false
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
		InspectLog = function(plugin, _params)
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
