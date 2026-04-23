-- Keybinding registry: single source of truth for all parley keybindings.
--
-- Each entry declares: id, config_key (optional), default key/modes, scope,
-- description, and whether it's buffer-local. The registry drives both
-- keymap registration and context-aware help display.

local M = {}

-------------------------------------------------------------------
-- Scope forest
-------------------------------------------------------------------
-- Parent pointers define the hierarchy. Finders are standalone roots.

M.scope_parent = {
	chat = "parley_buffer",
	markdown = "parley_buffer",
	note = "markdown",
	issue = "markdown",
	parley_buffer = "repo",
	repo = "global",
	vision = "repo",
	global = nil,
	-- finders are standalone
	chat_finder = nil,
	note_finder = nil,
	issue_finder = nil,
}

-- Display labels for help section headers
M.scope_labels = {
	global = "Global",
	parley_buffer = "Buffer",
	chat = "Chat",
	markdown = "Markdown",
	note = "Note",
	issue = "Issue",
	repo = "Repo",
	vision = "Vision",
	chat_finder = "Chat Finder",
	note_finder = "Note Finder",
	issue_finder = "Issue Finder",
}

-- Display order for scopes in help output
M.scope_display_order = {
	"global",
	"repo",
	"parley_buffer",
	"chat",
	"note",
	"issue",
	"markdown",
	"vision",
	"chat_finder",
	"note_finder",
	"issue_finder",
}

--- Walk from a leaf scope up to root, returning all ancestor scopes
--- in display order (root first).
--- Unknown contexts (e.g. "other") are treated as "global".
--- @param context string
--- @return string[]
function M.get_ancestor_scopes(context)
	-- Normalize unknown contexts to "global"
	if M.scope_parent[context] == nil and context ~= "global"
		and context ~= "chat_finder" and context ~= "note_finder" and context ~= "issue_finder" then
		context = "global"
	end
	local scopes = {}
	local current = context
	while current do
		table.insert(scopes, 1, current) -- prepend
		current = M.scope_parent[current]
	end
	return scopes
end

--- Get scopes in display order, filtered to only those applicable to context.
--- @param context string
--- @return string[]
function M.get_display_scopes(context)
	local ancestor_set = {}
	for _, s in ipairs(M.get_ancestor_scopes(context)) do
		ancestor_set[s] = true
	end
	local result = {}
	for _, s in ipairs(M.scope_display_order) do
		if ancestor_set[s] then
			table.insert(result, s)
		end
	end
	return result
end

-------------------------------------------------------------------
-- Registry entries
-------------------------------------------------------------------
-- Each entry:
--   id           - unique identifier, used as callback key
--   config_key   - key in parley config table (nil if not configurable)
--   default_key  - default shortcut string
--   default_modes - default mode list
--   scope        - scope name from the forest
--   desc         - vim keymap description
--   help_desc    - displayed in help (defaults to desc)
--   buffer_local - true if registered per-buffer, false if global
--   help_only    - true if registration is handled elsewhere (finders, review)

M.entries = {
	-- ── Global ──────────────────────────────────────────────────────────
	{
		id = "help",
		config_key = "global_shortcut_keybindings",
		default_key = "<C-g>?",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Show Parley key bindings",
		help_desc = "Show key bindings",
	},
	{
		id = "chat_new",
		config_key = "global_shortcut_new",
		default_key = "<C-g>c",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Create New Chat",
		help_desc = "New chat",
	},
	{
		id = "chat_finder",
		config_key = "global_shortcut_finder",
		default_key = "<C-g>f",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Open Chat Finder",
		help_desc = "Open chat finder",
	},
	{
		id = "chat_dirs",
		config_key = "global_shortcut_chat_dirs",
		default_key = "<C-g>h",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Manage chat roots",
	},
	{
		id = "chat_review",
		config_key = "global_shortcut_review",
		default_key = "<C-g>C",
		default_modes = { "n" },
		scope = "global",
		desc = "Review current file in new Chat",
		help_desc = "Review current file in chat",
	},
	{
		id = "note_new",
		config_key = "global_shortcut_note_new",
		default_key = "<C-n>c",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Create New Note",
		help_desc = "New note",
	},
	{
		id = "note_finder",
		config_key = "global_shortcut_note_finder",
		default_key = "<C-n>f",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Open Note Finder",
		help_desc = "Open note finder",
	},
	{
		id = "year_root",
		config_key = "global_shortcut_year_root",
		default_key = "<C-n>r",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Change directory to current year's note directory",
		help_desc = "Jump to note year root",
	},
	{
		id = "markdown_finder",
		config_key = "global_shortcut_markdown_finder",
		default_key = "<C-g>m",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Open Markdown Finder",
		help_desc = "Find markdown files in repo",
	},
	{
		id = "oil",
		config_key = "global_shortcut_oil",
		default_key = "<leader>fo",
		default_modes = { "n" },
		scope = "global",
		desc = "Open oil.nvim file explorer",
		help_desc = "Open oil file explorer",
	},
	{
		id = "copy_location",
		config_key = "global_shortcut_copy_location",
		default_key = "<leader>cl",
		default_modes = { "n", "v" },
		scope = "global",
		desc = "Copy file:line to clipboard",
		help_desc = "Copy location (file:line)",
	},
	{
		id = "copy_location_content",
		config_key = "global_shortcut_copy_location_content",
		default_key = "<leader>cL",
		default_modes = { "n", "v" },
		scope = "global",
		desc = "Copy file:line + content to clipboard",
		help_desc = "Copy location + content",
	},
	{
		id = "copy_context",
		config_key = "global_shortcut_copy_context",
		default_key = "<leader>cc",
		default_modes = { "n", "v" },
		scope = "global",
		desc = "Copy location + context to clipboard",
		help_desc = "Copy context",
	},
	{
		id = "copy_context_wide",
		config_key = "global_shortcut_copy_context_wide",
		default_key = "<leader>cC",
		default_modes = { "n", "v" },
		scope = "global",
		desc = "Copy location + wide context to clipboard",
		help_desc = "Copy wide context",
	},
	{
		id = "review_finder",
		config_key = "review_shortcut_finder",
		default_key = "<C-g>vf",
		default_modes = { "n", "i" },
		scope = "global",
		desc = "Parley review finder",
		help_desc = "Review finder",
	},
	{
		id = "skill_picker",
		config_key = "skill_shortcut",
		default_key = "<C-g>s",
		default_modes = { "n" },
		scope = "global",
		desc = "Open Skill Picker",
		help_desc = "Skill picker",
	},

	-- ── Repo ────────────────────────────────────────────────────────────
	{
		id = "issue_new",
		config_key = "global_shortcut_issue_new",
		default_key = "<C-y>c",
		default_modes = { "n", "i" },
		scope = "repo",
		desc = "Create New Issue",
		help_desc = "New issue",
	},
	{
		id = "issue_finder",
		config_key = "global_shortcut_issue_finder",
		default_key = "<C-y>f",
		default_modes = { "n", "i" },
		scope = "repo",
		desc = "Open Issue Finder",
		help_desc = "Open issue finder",
	},
	{
		id = "issue_next",
		config_key = "global_shortcut_issue_next",
		default_key = "<C-y>x",
		default_modes = { "n", "i" },
		scope = "repo",
		desc = "Open Next Runnable Issue",
		help_desc = "Next issue",
	},
	{
		id = "vision_finder",
		config_key = "global_shortcut_vision_finder",
		default_key = "<C-j>f",
		default_modes = { "n", "i" },
		scope = "repo",
		desc = "Vision Finder",
		help_desc = "Open vision finder",
	},

	-- ── Note ────────────────────────────────────────────────────────────
	{
		id = "interview_start",
		default_key = "<C-n>i",
		default_modes = { "n" },
		scope = "note",
		desc = "Enter Interview Mode",
		help_desc = "Enter interview mode",
	},
	{
		id = "interview_stop",
		default_key = "<C-n>I",
		default_modes = { "n" },
		scope = "note",
		desc = "Exit Interview Mode",
		help_desc = "Exit interview mode",
	},
	{
		id = "note_template",
		default_key = "<C-n>t",
		default_modes = { "n" },
		scope = "note",
		desc = "Create Note from Template",
		help_desc = "New note from template",
	},

	-- ── Issue ───────────────────────────────────────────────────────────
	{
		id = "issue_status",
		config_key = "global_shortcut_issue_status",
		default_key = "<C-y>s",
		default_modes = { "n" },
		scope = "issue",
		desc = "Cycle Issue Status",
		help_desc = "Cycle issue status",
	},
	{
		id = "issue_decompose",
		config_key = "global_shortcut_issue_decompose",
		default_key = "<C-y>i",
		default_modes = { "n" },
		scope = "issue",
		desc = "Decompose Issue",
		help_desc = "Decompose issue",
	},
	{
		id = "issue_goto",
		config_key = "global_shortcut_issue_goto",
		default_key = "<C-y>g",
		default_modes = { "n" },
		scope = "issue",
		desc = "Goto Linked Issue",
		help_desc = "Goto linked issue (markdown link / parent)",
	},

	-- ── Vision ──────────────────────────────────────────────────────────
	{
		id = "vision_new",
		config_key = "global_shortcut_vision_new",
		default_key = "<C-j>n",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision New Project",
		help_desc = "New vision project",
	},
	{
		id = "vision_goto",
		config_key = "global_shortcut_vision_goto",
		default_key = "<C-j>o",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision Goto Ref",
		help_desc = "Goto vision ref",
	},
	{
		id = "vision_validate",
		config_key = "global_shortcut_vision_validate",
		default_key = "<C-j>v",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision Validate",
		help_desc = "Validate vision YAML",
	},
	{
		id = "vision_export_csv",
		config_key = "global_shortcut_vision_export_csv",
		default_key = "<C-j>ec",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision Export CSV",
		help_desc = "Export CSV",
	},
	{
		id = "vision_export_dot",
		config_key = "global_shortcut_vision_export_dot",
		default_key = "<C-j>ed",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision Export DOT",
		help_desc = "Export DOT graph",
	},
	{
		id = "vision_allocation",
		config_key = "global_shortcut_vision_allocation",
		default_key = "<C-j>ea",
		default_modes = { "n" },
		scope = "vision",
		desc = "Vision Allocation",
		help_desc = "Allocation view",
	},

	-- ── Parley Buffer (shared chat + markdown) ──────────────────────────
	{
		id = "open_file",
		config_key = "chat_shortcut_open_file",
		default_key = "<C-g>o",
		default_modes = { "n", "i" },
		scope = "parley_buffer",
		desc = "Parley open file under cursor",
		help_desc = "Open file reference",
		buffer_local = true,
	},
	{
		id = "copy_fence",
		config_key = "chat_shortcut_copy_fence",
		default_key = "<leader>cf",
		default_modes = { "n" },
		scope = "parley_buffer",
		desc = "Parley copy code fence",
		help_desc = "Copy code fence to clipboard",
		buffer_local = true,
	},
	{
		id = "outline",
		default_key = "<C-g>t",
		default_modes = { "n" },
		scope = "parley_buffer",
		desc = "Parley prompt Outline Navigator",
		help_desc = "Outline picker",
		buffer_local = true,
	},
	{
		id = "branch_ref",
		default_key = "<C-g>i",
		default_modes = { "n", "i", "v" },
		scope = "parley_buffer",
		desc = "Parley create and insert new chat",
		help_desc = "Insert branch reference",
		buffer_local = true,
	},

	-- ── Chat ────────────────────────────────────────────────────────────
	{
		id = "chat_respond",
		config_key = "chat_shortcut_respond",
		default_key = "<C-g><C-g>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Chat Respond",
		help_desc = "Respond",
		buffer_local = true,
	},
	{
		id = "chat_respond_all",
		config_key = "chat_shortcut_respond_all",
		default_key = "<C-g>G",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Chat Respond All",
		help_desc = "Respond all",
		buffer_local = true,
	},
	{
		id = "chat_stop",
		config_key = "chat_shortcut_stop",
		default_key = "<C-g>x",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Chat Stop",
		help_desc = "Stop active response",
		buffer_local = true,
	},
	{
		id = "chat_delete",
		config_key = "chat_shortcut_delete",
		default_key = "<C-g>d",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Chat Delete",
		help_desc = "Delete chat",
		buffer_local = true,
	},
	{
		id = "chat_delete_tree",
		config_key = "chat_shortcut_delete_tree",
		default_key = "<C-g>D",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley prompt Chat Delete Tree",
		help_desc = "Delete chat tree",
		buffer_local = true,
	},
	{
		id = "chat_agent",
		config_key = "chat_shortcut_agent",
		default_key = "<C-g>a",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Next Agent",
		help_desc = "Next agent",
		buffer_local = true,
	},
	{
		id = "chat_system_prompt",
		config_key = "chat_shortcut_system_prompt",
		default_key = "<C-g>P",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt System Prompt Selector",
		help_desc = "System prompt picker",
		buffer_local = true,
	},
	{
		id = "chat_follow_cursor",
		config_key = "chat_shortcut_follow_cursor",
		default_key = "<C-g>l",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Toggle Follow Cursor",
		help_desc = "Toggle follow cursor",
		buffer_local = true,
	},
	{
		id = "chat_search",
		config_key = "chat_shortcut_search",
		default_key = "<C-g>n",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat",
		desc = "Parley prompt Search Chat Sections",
		help_desc = "Search chat sections",
		buffer_local = true,
	},
	{
		id = "chat_prune",
		config_key = "chat_shortcut_prune",
		default_key = "<C-g>p",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley prune chat",
		help_desc = "Prune: move exchange + following to child",
		buffer_local = true,
	},
	{
		id = "chat_export_markdown",
		config_key = "chat_shortcut_export_markdown",
		default_key = "<C-g>em",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley export markdown",
		help_desc = "Export markdown (Jekyll)",
		buffer_local = true,
	},
	{
		id = "chat_exchange_cut",
		config_key = "chat_shortcut_exchange_cut",
		default_key = "<C-g>X",
		default_modes = { "n", "v" },
		scope = "chat",
		desc = "Parley cut exchange",
		help_desc = "Cut exchange(s)",
		buffer_local = true,
	},
	{
		id = "chat_exchange_paste",
		config_key = "chat_shortcut_exchange_paste",
		default_key = "<C-g>V",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley paste exchange",
		help_desc = "Paste exchange(s)",
		buffer_local = true,
	},
	{
		id = "chat_export_html",
		config_key = "chat_shortcut_export_html",
		default_key = "<C-g>eh",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley export HTML",
		help_desc = "Export HTML",
		buffer_local = true,
	},
	{
		id = "chat_toggle_tool_folds",
		config_key = "chat_shortcut_toggle_tool_folds",
		default_key = "<C-g>b",
		default_modes = { "n" },
		scope = "chat",
		desc = "Parley toggle tool folds",
		help_desc = "Toggle tool folds",
		buffer_local = true,
	},
	{
		id = "chat_toggle_web_search",
		default_key = "<C-g>w",
		default_modes = { "n" },
		scope = "chat",
		desc = "Toggle web_search tool",
		help_desc = "Toggle web_search",
	},
	{
		id = "chat_toggle_raw_request",
		default_key = "<C-g>r",
		default_modes = { "n" },
		scope = "chat",
		desc = "Toggle raw request mode",
	},
	{
		id = "chat_toggle_raw_response",
		default_key = "<C-g>R",
		default_modes = { "n" },
		scope = "chat",
		desc = "Toggle raw response mode",
	},

	-- ── Markdown (non-chat .md files) ───────────────────────────────────
	{
		id = "md_add_chat_ref",
		config_key = "global_shortcut_add_chat_ref",
		default_key = "<C-g>a",
		default_modes = { "n", "i" },
		scope = "markdown",
		desc = "Parley add chat reference",
		help_desc = "Add chat reference",
		buffer_local = true,
	},
	{
		id = "md_delete_file",
		default_key = "<C-g>d",
		default_modes = { "n" },
		scope = "markdown",
		desc = "Parley delete current file and buffer",
		help_desc = "Delete file",
		buffer_local = true,
	},
	{
		id = "md_delete_tree",
		config_key = "chat_shortcut_delete_tree",
		default_key = "<C-g>D",
		default_modes = { "n" },
		scope = "markdown",
		desc = "Parley prompt Chat Delete Tree",
		help_desc = "Delete chat tree",
		buffer_local = true,
	},
	{
		id = "md_export_html",
		config_key = "chat_shortcut_export_html",
		default_key = "<C-g>eh",
		default_modes = { "n" },
		scope = "markdown",
		desc = "Parley export markdown to HTML (pandoc)",
		help_desc = "Export HTML (pandoc)",
		buffer_local = true,
	},
	{
		id = "review_insert",
		config_key = "review_shortcut_insert",
		default_key = "<C-g>vi",
		default_modes = { "n", "v" },
		scope = "markdown",
		desc = "Parley review: insert marker",
		help_desc = "Insert review marker",
		buffer_local = true,
		help_only = true, -- registered by review skill
	},
	{
		id = "review_insert_machine",
		config_key = "review_shortcut_insert_machine",
		default_key = "<C-g>vr",
		default_modes = { "n" },
		scope = "markdown",
		desc = "Parley review: insert machine marker",
		help_desc = "AI review (insert markers)",
		buffer_local = true,
		help_only = true, -- registered by review skill
	},
	{
		id = "review_edit",
		config_key = "review_shortcut_edit",
		default_key = "<C-g>ve",
		default_modes = { "n" },
		scope = "markdown",
		desc = "Parley review: process markers",
		help_desc = "Apply review marker edits",
		buffer_local = true,
		help_only = true, -- registered by review skill
	},

	-- ── Finder: Chat ────────────────────────────────────────────────────
	{
		id = "cf_next_recency",
		config_key = "chat_finder_mappings.next_recency",
		default_key = "<C-a>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat_finder",
		desc = "Cycle recency window left",
		help_only = true,
	},
	{
		id = "cf_prev_recency",
		config_key = "chat_finder_mappings.previous_recency",
		default_key = "<C-s>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat_finder",
		desc = "Cycle recency window right",
		help_only = true,
	},
	{
		id = "cf_delete",
		config_key = "chat_finder_mappings.delete",
		default_key = "<C-d>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat_finder",
		desc = "Delete selected chat",
		help_only = true,
	},
	{
		id = "cf_delete_tree",
		config_key = "chat_finder_mappings.delete_tree",
		default_key = "<C-D>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat_finder",
		desc = "Delete chat tree",
		help_only = true,
	},
	{
		id = "cf_move",
		config_key = "chat_finder_mappings.move",
		default_key = "<C-x>",
		default_modes = { "n", "i", "v", "x" },
		scope = "chat_finder",
		desc = "Move selected chat",
		help_only = true,
	},

	-- ── Finder: Note ────────────────────────────────────────────────────
	{
		id = "nf_next_recency",
		config_key = "note_finder_mappings.next_recency",
		default_key = "<C-a>",
		default_modes = { "n", "i", "v", "x" },
		scope = "note_finder",
		desc = "Cycle recency window left",
		help_only = true,
	},
	{
		id = "nf_prev_recency",
		config_key = "note_finder_mappings.previous_recency",
		default_key = "<C-s>",
		default_modes = { "n", "i", "v", "x" },
		scope = "note_finder",
		desc = "Cycle recency window right",
		help_only = true,
	},
	{
		id = "nf_delete",
		config_key = "note_finder_mappings.delete",
		default_key = "<C-d>",
		default_modes = { "n", "i", "v", "x" },
		scope = "note_finder",
		desc = "Delete selected note",
		help_only = true,
	},

	-- ── Finder: Issue ───────────────────────────────────────────────────
	{
		id = "if_cycle_status",
		config_key = "issue_finder_mappings.cycle_status",
		default_key = "<C-s>",
		default_modes = { "n", "i", "v", "x" },
		scope = "issue_finder",
		desc = "Cycle issue status",
		help_only = true,
	},
	{
		id = "if_toggle_done",
		config_key = "issue_finder_mappings.toggle_done",
		default_key = "<C-a>",
		default_modes = { "n", "i", "v", "x" },
		scope = "issue_finder",
		desc = "Toggle show done/history",
		help_only = true,
	},
	{
		id = "if_delete",
		config_key = "issue_finder_mappings.delete",
		default_key = "<C-d>",
		default_modes = { "n", "i", "v", "x" },
		scope = "issue_finder",
		desc = "Delete selected issue",
		help_only = true,
	},
}

-- Build index by id for fast lookup
M._by_id = {}
for _, entry in ipairs(M.entries) do
	M._by_id[entry.id] = entry
end

-- Build index by scope for fast filtering
M._by_scope = {}
for _, entry in ipairs(M.entries) do
	if not M._by_scope[entry.scope] then
		M._by_scope[entry.scope] = {}
	end
	table.insert(M._by_scope[entry.scope], entry)
end

-------------------------------------------------------------------
-- Config resolution
-------------------------------------------------------------------

--- Resolve the key and modes for an entry, checking config overrides.
--- Handles both flat config keys (e.g. "global_shortcut_new") and
--- nested dot-notation (e.g. "chat_finder_mappings.delete").
--- @param entry table
--- @param config table
--- @return string|nil key
--- @return string[]|nil modes
function M.resolve_key(entry, config)
	if not entry.config_key then
		return entry.default_key, entry.default_modes
	end

	-- Handle dot-notation for nested config (e.g. "chat_finder_mappings.delete")
	local cfg_val
	if entry.config_key:find(".", 1, true) then
		local parts = {}
		for part in entry.config_key:gmatch("[^.]+") do
			table.insert(parts, part)
		end
		cfg_val = config
		for _, part in ipairs(parts) do
			if type(cfg_val) ~= "table" then
				cfg_val = nil
				break
			end
			cfg_val = cfg_val[part]
		end
	else
		cfg_val = config[entry.config_key]
	end

	if cfg_val and type(cfg_val) == "table" then
		return cfg_val.shortcut or entry.default_key, cfg_val.modes or entry.default_modes
	end
	return entry.default_key, entry.default_modes
end

-------------------------------------------------------------------
-- Help display
-------------------------------------------------------------------

--- Resolve the actual runtime shortcut by querying vim keymaps.
--- Falls back to config/default if runtime lookup fails.
--- @param entry table  registry entry
--- @param config table  parley config
--- @param bufnr integer|nil  buffer number for buffer-local lookup
--- @return string  display string for the shortcut
local function resolve_display_shortcut(entry, config, _bufnr)
	-- Use config resolution (preserves user-facing format like <C-g>?)
	local key, _ = M.resolve_key(entry, config)
	return key or entry.default_key
end

--- Generate help lines for a given context.
--- @param context string  buffer context (e.g. "chat", "issue", "other")
--- @param config table  parley config
--- @param bufnr integer|nil  current buffer number
--- @return string[]  lines for the help window
function M.help_lines(context, config, bufnr)
	-- Title
	local title_suffix = {
		chat = " (Chat)",
		note = " (Note)",
		issue = " (Issue)",
		markdown = " (Markdown)",
		chat_finder = " (Chat Finder)",
		note_finder = " (Note Finder)",
		issue_finder = " (Issue Finder)",
		vision = " (Vision)",
		repo = " (Repo)",
	}
	local lines = {
		"Parley Key Bindings" .. (title_suffix[context] or ""),
		"",
	}

	local function add(shortcut, description)
		table.insert(lines, string.format("  %-12s %s", shortcut, description))
	end

	-- Get applicable scopes in display order
	local display_scopes = M.get_display_scopes(context)

	for _, scope in ipairs(display_scopes) do
		local scope_entries = M._by_scope[scope]
		if scope_entries and #scope_entries > 0 then
			table.insert(lines, M.scope_labels[scope] or scope)
			for _, entry in ipairs(scope_entries) do
				local key = resolve_display_shortcut(entry, config, bufnr)
				add(key, entry.help_desc or entry.desc)
			end
			table.insert(lines, "")
		end
	end

	-- Finder recency note
	if context == "chat_finder" then
		local months = (config.chat_finder_recency or {}).months or 6
		table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
		table.insert(lines, "")
	elseif context == "note_finder" then
		local months = (config.note_finder_recency or {}).months or 6
		table.insert(lines, string.format("  %-12s %s", "", "(Recent window default: last " .. tostring(months) .. " months)"))
		table.insert(lines, "")
	end

	table.insert(lines, "Close: q or <Esc>")
	return lines
end

-------------------------------------------------------------------
-- Registration
-------------------------------------------------------------------

--- Register all non-buffer-local keybindings for the given scopes.
--- @param scopes string[]  list of scope names to register
--- @param config table  parley config
--- @param callbacks table  map of entry.id → callback function
function M.register_global(scopes, config, callbacks)
	local scope_set = {}
	for _, s in ipairs(scopes) do
		scope_set[s] = true
	end

	for _, entry in ipairs(M.entries) do
		if scope_set[entry.scope] and not entry.buffer_local and not entry.help_only then
			local cb = callbacks[entry.id]
			if cb then
				local key, modes = M.resolve_key(entry, config)
				if key and modes then
					for _, mode in ipairs(modes) do
						local wrapped
						if mode == "i" then
							wrapped = function()
								vim.cmd("stopinsert")
								cb()
							end
						else
							wrapped = cb
						end
						vim.keymap.set(mode, key, wrapped, { silent = true, desc = entry.desc })
					end
				end
			end
		end
	end
end

--- Register buffer-local keybindings for the given scopes on a buffer.
--- @param scopes string[]  list of scope names to register
--- @param buf integer  buffer number
--- @param config table  parley config
--- @param callbacks table  map of entry.id → callback function (or table of mode→fn)
--- @param set_keymap function  keymap setter (e.g. parley.helpers.set_keymap)
function M.register_buffer(scopes, buf, config, callbacks, set_keymap)
	local scope_set = {}
	for _, s in ipairs(scopes) do
		scope_set[s] = true
	end

	for _, entry in ipairs(M.entries) do
		if scope_set[entry.scope] and entry.buffer_local and not entry.help_only then
			local cb = callbacks[entry.id]
			if cb then
				local key, modes = M.resolve_key(entry, config)
				if key and modes then
					if type(cb) == "table" then
						-- Mode-specific callbacks: { n = fn, i = fn, v = fn }
						for _, mode in ipairs(modes) do
							local mode_cb = cb[mode]
							if mode_cb then
								set_keymap({ buf }, mode, key, mode_cb, entry.desc)
							end
						end
					else
						-- Single callback for all modes
						for _, mode in ipairs(modes) do
							set_keymap({ buf }, mode, key, cb, entry.desc)
						end
					end
				end
			end
		end
	end
end

return M
