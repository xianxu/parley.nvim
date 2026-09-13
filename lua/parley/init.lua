-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- A streamlined LLM chat interface for Neovim with highlighting and navigation

--------------------------------------------------------------------------------
-- This is the main module
--------------------------------------------------------------------------------
local config = require("parley.config")
local repo_artifacts = require("parley.repo_artifacts")

local M = {
	_Name = "Parley", -- plugin name
	_state = {
		interview_mode = false, -- interview mode state
		interview_start_time = nil, -- interview start timestamp
		-- (interview_timer lives in parley/interview.lua as a module-local: a
		-- libuv handle cannot be deepcopied, and refresh_state deepcopies
		-- _state — see #214 N2)
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
	note_dir_picker = require("parley.note_dir_picker"), -- note root management UI
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

-- Note dirs module (loaded here; wired up immediately since it only needs M reference)
local note_dirs = require("parley.note_dirs")
note_dirs.setup(M)

-- Canonical directory identity for persisted repo keys and root comparisons.
local resolve_dir_key = function(d) return vim.fn.resolve(vim.fn.expand(d)):gsub("/+$", "") end

-- Super-repo module (loaded here; wired up immediately since it only needs M reference)
local super_repo = require("parley.super_repo")
local repo_mode = require("parley.repo_mode")
super_repo.setup(M)
M.super_repo = super_repo
M.toggle_super_repo = function()
	local transitioned, err = super_repo.toggle()
	if not transitioned then
		return false, err
	end

	local root = M.config.repo_root
	if type(root) == "string" and root ~= "" then
		local canonical_root = resolve_dir_key(root)
		local mode = super_repo.is_active() and "super_repo" or "repo"
		M._state.repo_modes = repo_mode.updated(M._state.repo_modes, canonical_root, mode)
		local persisted = M.persist_state()
		if not persisted then
			M.logger.warning("super-repo: preference not saved")
		end
	end

	return true
end
M.is_super_repo_active = function() return super_repo.is_active() end

-- Discovery registry (#116): the repo's noun-vocabulary (what file types exist
-- and how to find their instances). Pure given mode context; current() reads it
-- from live config (repo_root + super_repo_members) via the injected M ref.
local discovery = require("parley.discovery")
discovery.setup(M)
M.discovery = discovery

-- Skill registry (#128): declarative skill manifests unioned from providers
-- (plugin-disk ∪ user-disk ∪ repo/virtual seams). current() discovers the live
-- stack; the per-turn assembly + read_skill tool (M2) consume it.
M.skills = require("parley.skill_registry")

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
	-- headers ONLY: `parsed.headers` is literally
	-- `parse_header_metadata(lines, header_end)` (chat_parser.lua:258), and every
	-- exchange/block/fold structure parse_chat builds here was discarded. That
	-- made `not_chat` — 15+ call sites, several on keystroke paths — pay a full
	-- parse to read four header lines: measured 3.07ms @ 1005 lines and 14.02ms
	-- @ 5005 vs 0.003ms. Identical return value, and parse_config is not even an
	-- input to header parsing. #215 (ARCH-CONSTRAINTS, ARCH-DRY).
	return M.chat_parser.parse_header_metadata(lines, header_end), header_end
end

-- Passthroughs to chat_dirs module (see lua/parley/chat_dirs.lua)
-- Local helpers are defined as wrappers at the top of this file (near require).
-- apply_chat_roots / normalize_chat_roots accessed via chat_dirs.*
local apply_chat_roots = function(...) return chat_dirs.apply_chat_roots(...) end
local normalize_chat_roots = function(...) return chat_dirs.normalize_chat_roots(...) end

M.get_chat_roots = function() return chat_dirs.get_chat_roots() end
M.get_chat_dirs = function() return chat_dirs.get_chat_dirs() end
M.set_chat_dirs = function(d, p) return chat_dirs.set_chat_dirs(d, p) end
M.set_chat_roots = function(r, p) return chat_dirs.set_chat_roots(r, p) end

-- Passthroughs to note_dirs module (see lua/parley/note_dirs.lua)
local apply_note_roots = function(...) return note_dirs.apply_note_roots(...) end
local normalize_note_roots = function(...) return note_dirs.normalize_note_roots(...) end

M.get_note_roots = function() return note_dirs.get_note_roots() end
M.get_note_dirs = function() return note_dirs.get_note_dirs() end
M.set_note_dirs = function(d, p) return note_dirs.set_note_dirs(d, p) end
M.set_note_roots = function(r, p) return note_dirs.set_note_roots(r, p) end
M.add_note_dir = function(d, p, l) return note_dirs.add_note_dir(d, p, l) end
M.remove_note_dir = function(d, p) return note_dirs.remove_note_dir(d, p) end
M.rename_note_dir = function(d, l, p) return note_dirs.rename_note_dir(d, l, p) end


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

--- Register `:<prefix>Proxy <subcommand>` to manage the optional bundled
--- cliproxyapi instance (issue #131). Harmless when the feature isn't opted
--- into — `status` just reports `managed: false`.
---@param prefix string # M.config.cmd_prefix (e.g. "Parley")
M.register_proxy_command = function(prefix)
	-- Single source of truth for the subcommands: drives the usage text AND the
	-- completion list (ARCH-DRY). `arg` is the per-subcommand argument shown in
	-- usage; nil for the no-arg ones.
	local SUBS_HELP = {
		{ name = "status", desc = "show proxy health, version vs latest, endpoint, binary, drift" },
		{ name = "start", desc = "ensure the proxy is running (spawn if needed)" },
		{ name = "stop", desc = "stop parley-spawned proxies (+ reap a leftover on the port)" },
		{ name = "restart", desc = "stop, then start with a freshly rendered config" },
		{ name = "models", arg = "<provider>", desc = "list the models a provider currently serves" },
		{ name = "providers", desc = "list the supported provider names" },
		{ name = "login", arg = "<provider>", desc = "run an interactive OAuth login for a provider" },
		{ name = "reap", desc = "stop other cliproxy processes racing this one's auth-dir" },
		{ name = "update", desc = "install the latest cliproxyapi release (or cliproxy.download_version), restarting parley's proxy" },
	}
	local SUBS = vim.tbl_map(function(e)
		return e.name
	end, SUBS_HELP)

	local function usage()
		local lines = { "usage: " .. prefix .. "Proxy <subcommand>" }
		for _, e in ipairs(SUBS_HELP) do
			local name = e.name .. (e.arg and (" " .. e.arg) or "")
			lines[#lines + 1] = ("  %-20s %s"):format(name, e.desc)
		end
		return table.concat(lines, "\n")
	end

	vim.api.nvim_create_user_command(prefix .. "Proxy", function(params)
		local cliproxy = require("parley.cliproxy")
		local sub = params.fargs[1]
		local arg = params.fargs[2]
		if sub == "status" then
			cliproxy.status(function(info)
				vim.notify(table.concat({
					"cliproxy status",
					"  managed:       " .. tostring(info.managed),
					"  health:        " .. tostring(info.health),
					"  version:       " .. require("parley.cliproxy_release").version_summary(
						info.version, ":" .. prefix .. "Proxy update"),
					"  binary:        " .. tostring(info.binary) .. " (" .. info.binary_source .. ")",
					"  endpoint:      " .. tostring(info.host) .. ":" .. tostring(info.port),
					"  auth-dir:      " .. tostring(info.auth_dir),
					"  config:        " .. tostring(info.config_path),
					"  spawned by us: " .. tostring(info.spawned_by_parley),
					"  config drift:  " .. tostring(info.config_drift),
				}, "\n"), vim.log.levels.INFO)
			end)
		elseif sub == "start" then
			cliproxy.start(function()
				vim.notify("cliproxy: running", vim.log.levels.INFO)
			end, function(msg)
				vim.notify(msg, vim.log.levels.ERROR)
			end)
		elseif sub == "stop" then
			local n = cliproxy.stop()
			vim.notify("cliproxy: stopped " .. n .. " parley-spawned proxy(ies)", vim.log.levels.INFO)
		elseif sub == "update" then
			vim.notify("cliproxy: finding the release to install…", vim.log.levels.INFO)
			vim.cmd("redraw") -- update blocks while it fetches: show the notice first
			cliproxy.update(function(ok, msg, warn)
				-- warn: installed, but a proxy parley did not start still serves the old
				-- version until the operator acts
				local levels = vim.log.levels
				vim.notify("cliproxy: " .. msg, not ok and levels.ERROR or warn and levels.WARN or levels.INFO)
			end)
		elseif sub == "restart" then
			-- restart_managed waits for the old proxy to release the port; the
			-- no-wait restart could reuse a proxy still shutting down (#237).
			cliproxy.restart_managed(function()
				vim.notify("cliproxy: restarted", vim.log.levels.INFO)
			end, function(msg)
				vim.notify(msg, vim.log.levels.ERROR)
			end)
		elseif sub == "providers" then
			vim.notify(
				"cliproxy providers: " .. table.concat(require("parley.cliproxy_config").providers(), ", "),
				vim.log.levels.INFO
			)
		elseif sub == "models" then
			if not arg then
				vim.notify(
					"usage: " .. prefix .. "Proxy models <provider>   (see `" .. prefix .. "Proxy providers`)",
					vim.log.levels.WARN
				)
				return
			end
			cliproxy.list_models(arg, function(ids, err)
				if err then
					vim.notify("cliproxy: " .. err, vim.log.levels.ERROR)
					return
				end
				if #ids == 0 then
					-- An empty list USED to be read as "not authenticated". #197
					-- disproved exactly that inference — /v1/models kept listing
					-- every model with the credential dead — so ask the proxy.
					--
					-- THREE axes exist and only two coincide: `arg` here is a
					-- model-owning provider (`google`), while credential health is
					-- keyed by cliproxy CHANNEL (`gemini`/`gemini-cli`/`aistudio`).
					-- Reading health under "google" finds nothing and would
					-- fabricate "no credential" for a perfectly good account.
					cliproxy.credential_health_for_login(arg, function(health)
						local action = require("parley.cliproxy_auth")
							.credential_action(health, arg)
						if not action then
							vim.notify(("cliproxy: %s is authenticated (%s) but serves no models — "
								.. "check the model catalog, not the login."):format(
								arg, tostring(health.account)), vim.log.levels.WARN)
							return
						end
						if action == "report" then
							-- Name the reason for an unreadable state: "unreachable"
							-- is what the operator can act on, the message alone
							-- often isn't.
							local why = health.reason
								and ("credential state could not be read (%s): %s"):format(
									health.reason, tostring(health.message))
								or tostring(health.message)
							vim.notify(("cliproxy: no %s models — %s"):format(arg, why),
								vim.log.levels.WARN)
							return
						end
						vim.ui.select({ "Log in (" .. arg .. ")", "Not now" }, {
							prompt = ("cliproxy: no %s models — %s"):format(arg, health.message),
						}, function(_, idx)
							if idx == 1 then
								vim.cmd(prefix .. "Proxy login " .. arg)
							end
						end)
					end)
					return
				end
				vim.notify(("cliproxy %s models:\n  %s"):format(arg, table.concat(ids, "\n  ")), vim.log.levels.INFO)
			end)
		elseif sub == "reap" then
			local peers = cliproxy.peers()
			if #peers == 0 then
				vim.notify("cliproxy: no other cliproxy processes are running", vim.log.levels.INFO)
				return
			end
			local lines = { ("cliproxy: %d other process(es):"):format(#peers) }
			for _, p in ipairs(peers) do
				lines[#lines + 1] = ("  %d  since %s"):format(p.pid, p.started)
			end
			lines[#lines + 1] = ""
			lines[#lines + 1] = "Each runs its own 15-minute auth refresh over the shared auth-dir,"
			lines[#lines + 1] = "and OAuth refresh tokens rotate on use — so they can invalidate"
			lines[#lines + 1] = "each other's credential."
			vim.ui.select({ "Stop them", "Cancel" }, { prompt = table.concat(lines, "\n") },
				function(_, idx)
					if idx ~= 1 then
						return
					end
					local killed, skipped = cliproxy.reap(peers)
					vim.notify(("cliproxy: stopped %d process(es)%s"):format(
						killed, skipped > 0 and (", skipped " .. skipped) or ""),
						vim.log.levels.INFO)
				end)
		elseif sub == "login" then
			local argv, err = cliproxy.login_argv(arg)
			if not argv then
				vim.notify(err, vim.log.levels.ERROR)
				return
			end
			-- Preflight the OAuth callback port. #197's dead end: the login
			-- process died, its listener went with it, and the browser redirect
			-- had nowhere to land — the account chooser just looked inert.
			local blocked = cliproxy.callback_port_blocked(arg)
			if blocked then
				vim.notify(blocked, vim.log.levels.ERROR)
				return
			end
			cliproxy.run_login(arg, argv)
		else
			-- nil (bare invocation) → help at INFO; an unknown subcommand → WARN.
			local level = sub == nil and vim.log.levels.INFO or vim.log.levels.WARN
			local head = sub and ("unknown subcommand '" .. sub .. "'\n") or ""
			vim.notify(head .. usage(), level)
		end
	end, {
		nargs = "*",
		desc = "Manage the optional bundled cliproxyapi proxy",
		complete = function(arglead, line)
			local function starts(list)
				return vim.tbl_filter(function(v)
					return v:find(arglead, 1, true) == 1
				end, list)
			end
			-- `models` and `login` draw from DIFFERENT provider axes: models from the
			-- model-owning providers, login from the login-method set (which also has
			-- codex-device). Keep them distinct (see cliproxy_config note).
			if line:match("Proxy%s+models%s+%S*$") then
				return starts(require("parley.cliproxy_config").providers())
			end
			if line:match("Proxy%s+login%s+%S*$") then
				return starts(require("parley.cliproxy").login_providers())
			end
			return starts(SUBS)
		end,
	})
end

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

	-- #214: record which shortcut knobs the USER set explicitly, so
	-- `default_keymaps = false` can suppress parley's DEFAULT claims without
	-- suppressing the keys you chose yourself. Without this the switch is a
	-- trap — you turn it on to take over the keyspace, and then no
	-- configuration can bind anything ever again. Lives on the config table
	-- (not on M) so `resolve_keys` stays a pure function of its argument.
	M.config._explicit_shortcuts = {}
	for k, v in pairs(opts) do
		if type(v) == "table" then
			if v.shortcut ~= nil then -- shortcut-read-ok: detecting user intent, not deriving a key
				M.config._explicit_shortcuts[k] = true
			end
			-- nested mapping tables, e.g. chat_finder_mappings.delete
			for nk, nv in pairs(v) do
				if type(nv) == "table" and nv.shortcut ~= nil then -- shortcut-read-ok: as above
					M.config._explicit_shortcuts[k .. "." .. nk] = true
				end
			end
		end
	end

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

	-- #214 BR-49: normalise shortcut shapes ONCE, here, where config enters the
	-- system — not on every resolution. `resolve_keys` used to warn when it met a
	-- number/boolean `shortcut`, which meant one typo produced a log write and a
	-- vim.notify popup on every <C-g>? press and every chat BufEnter, for the
	-- session; and it put file IO and a UI notification inside what the issue's
	-- Core-concepts table calls a PURE entity. Report once, drop the bad value so
	-- the binding falls back to its default, and leave the resolver total over
	-- already-typed input.
	do
		-- Every shape `resolve_keys` would otherwise tolerate by coercion, not
		-- just the top-level type (#214 N3). The element case is the one that
		-- matters most: `shortcut = { 5 }` used to resolve to nil — i.e. exactly
		-- what a deliberate `shortcut = ""` means — so a typo and a decision
		-- produced the same outcome, which is the defect this check was created
		-- to remove. Returns the normalised value plus a reason, or nothing when
		-- the value is already well-formed.
		local function normalise_shortcut(v)
			if type(v) == "string" then return nil end
			if type(v) ~= "table" then
				return "strip", "expected a string or a list, got " .. type(v)
			end
			local kept, dropped = {}, {}
			for _, el in ipairs(v) do
				if type(el) == "string" then
					kept[#kept + 1] = el
				else
					dropped[#dropped + 1] = type(el)
				end
			end
			if #dropped == 0 then return nil end
			if #kept == 0 then
				return "strip", "every list element was a non-string ("
					.. table.concat(dropped, ", ") .. ")"
			end
			return kept, "dropped non-string list element(s): " .. table.concat(dropped, ", ")
		end

		local offenders = {}
		local function check(key, tbl)
			if type(tbl) ~= "table" then return end
			if tbl.shortcut == nil then return end -- shortcut-read-ok: validating the shape, not deriving a key
			local fixed, why = normalise_shortcut(tbl.shortcut) -- shortcut-read-ok: as above
			if why then
				offenders[#offenders + 1] = key .. " — " .. why
				tbl.shortcut = (fixed ~= "strip") and fixed or nil -- shortcut-read-ok: normalising, not deriving
			end
		end
		local reg_entries = require("parley.keybinding_registry").entries
		for k, v in pairs(M.config) do
			if type(v) == "table" then
				check(k, v)
				for nk, nv in pairs(v) do
					if type(nv) == "table" then check(k .. "." .. nk, nv) end
				end
			end
		end
		-- A dotted config_key whose value is not a table (`chat_finder_mappings =
		-- 5`, or `.delete = 5`) never reaches `check` above, and resolve_keys just
		-- falls back with no word said. Walk the registry's own key list so the
		-- report covers every knob rather than every table that happens to exist.
		for _, e in ipairs(reg_entries) do
			if e.config_key:find(".", 1, true) then
				local root, leaf = e.config_key:match("^([^.]+)%.(.+)$")
				local parent = M.config[root]
				if parent ~= nil and type(parent) ~= "table" then
					offenders[#offenders + 1] = root .. " — expected a table, got " .. type(parent)
					M.config[root] = nil
				elseif type(parent) == "table" and parent[leaf] ~= nil
					and type(parent[leaf]) ~= "table" then
					offenders[#offenders + 1] = e.config_key
						.. " — expected a table, got " .. type(parent[leaf])
					parent[leaf] = nil
				end
			end
		end
		if #offenders > 0 then
			M.logger.warning("parley: ignoring malformed shortcut(s) — expected a string "
				.. "or a list of strings: " .. table.concat(offenders, ", "))
		end
	end

	-- #116 M2: seed issues_dir from the cue `discovery.home` (ariadne's issue.cue,
	-- exported to construct/generated/vocabulary/issue.json) when the user did NOT
	-- override it, so every config.issues_dir reader (get_issues_dir,
	-- get_issues_repo_root, the super-repo finder, the status autocmd, base.lua's
	-- issue descriptor) derives from the one cue source. Precedence: explicit user
	-- override > cue home > built-in default. home() returns nil in a fresh clone /
	-- pre-weave, so this is a no-op there (stays on the built-in default). Relative
	-- stays relative — issues_dir is in skip_prepare, never absolutized here.
	M.config.issues_dir = require("parley.issues").resolve_issues_dir(
		opts.issues_dir,
		require("parley.issue_vocabulary").home(),
		M.config.issues_dir
	)

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
		for _, dir in ipairs(repo_artifacts.relative_dirs(M.config)) do
			if dir and dir ~= "" and not dir:match("^/") then
				M.helpers.prepare_dir(git_root .. "/" .. dir, "repo")
			end
		end

		-- Prepend repo chat dir as primary, demoting global chat_dir to extra.
		-- Use the structured chat_roots list so labels are explicit:
		-- repo dir → "repo", original config.chat_dir → "global". Without
		-- explicit labels, the normalizer derives labels from the directory
		-- basename, which surfaces as e.g. {parley} in the finder when the
		-- global chat dir's basename is "parley".
		if M.config.repo_chat_dir and M.config.repo_chat_dir ~= "" then
			local repo_chat = git_root .. "/" .. M.config.repo_chat_dir
			local old_dir = M.config.chat_dir
			local old_dirs = M.config.chat_dirs

			M.config.chat_dir = repo_chat
			local roots = { { dir = repo_chat, label = "repo" } }
			if old_dir and old_dir ~= repo_chat then
				table.insert(roots, { dir = old_dir, label = "global" })
			end
			-- Preserve any pre-existing extras (legacy multi-root from setup
			-- config). They keep their default basename labels — the only
			-- relabels here are repo_chat → "repo" and config.chat_dir →
			-- "global". Issue #117 M2 will drop this preservation entirely.
			if type(old_dirs) == "table" then
				for _, d in ipairs(old_dirs) do
					if d ~= repo_chat and d ~= old_dir then
						table.insert(roots, { dir = d })
					end
				end
			end
			M.config.chat_roots = roots
			M.config.chat_dirs = vim.tbl_map(function(r) return r.dir end, roots)
		end

		-- Prepend repo note dir as primary, demoting global notes_dir to extra
		if M.config.repo_note_dir and M.config.repo_note_dir ~= "" then
			local repo_note = git_root .. "/" .. M.config.repo_note_dir
			local old_dir = M.config.notes_dir
			local old_dirs = M.config.note_dirs

			M.config.notes_dir = repo_note
			local extras = {}
			if type(old_dirs) == "table" and #old_dirs > 0 then
				extras = vim.deepcopy(old_dirs)
			end
			if old_dir and old_dir ~= repo_note then
				table.insert(extras, 1, old_dir)
			end
			M.config.note_dirs = extras
			M.config.note_roots = {}
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
	apply_note_roots(normalize_note_roots(M.config.notes_dir, M.config.note_dirs, M.config.note_roots))

	-- repo-local dirs (issues, history, vision, notes) are resolved in apply_repo_local
	-- against git root; skip them here to avoid creating in CWD
	local skip_prepare = { chat_dir = true }
	for _, key in ipairs(repo_artifacts.dir_keys) do
		skip_prepare[key] = true
	end
	for k, v in pairs(M.config) do
		if not skip_prepare[k] and k:match("_dir$") and type(v) == "string" then
			-- prepare_dir returns nil if it refuses (a backtick path); keep the
			-- original rather than nilling a config key. Config paths are
			-- operator-derived so this should never fire — it is here so the
			-- refusal contract is uniform across every sink (#225 review I2).
			M.config[k] = M.helpers.prepare_dir(v, k) or v
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
				agent.max_tool_iterations = agent.max_tool_iterations or M.defaults.max_tool_iterations
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

	-- Restore the current repo's explicit mode only after every state refresh has
	-- settled roots. This runtime transition is intentionally non-persisting.
	if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
		local canonical_root = resolve_dir_key(M.config.repo_root)
		local saved_mode = repo_mode.resolve(M._state.repo_modes, canonical_root)
		super_repo.set_active(saved_mode == "super_repo")
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

	-- :ParleyProxy <subcommand> — manage the optional bundled cliproxyapi (#131)
	M.register_proxy_command(M.config.cmd_prefix)

	-- :ParleyShowDiagnostics — toggle inline display of review "why" diagnostics
	-- (cursor-region auto-show, scoped to parley's namespace). Default on. (#133 M6)
	M.helpers.create_user_command(M.config.cmd_prefix .. "ShowDiagnostics", function()
		local on = require("parley.skills.review.diag_display").toggle()
		M.logger.info("Parley review diagnostics: inline display " .. (on and "ON" or "OFF"))
	end)
	require("parley.skills.review.diag_display").set(true)

	-- Register all global keymaps from the keybinding registry
	kb_registry.register_global(
		{ "global", "repo", "note", "issue", "vision", "chat" },
		M.config,
		{
			help = function() M.cmd.KeyBindings() end,
			chat_new = function() M.cmd.ChatNew({}) end,
			chat_finder = function() M.cmd.ChatFinder() end,
			chat_review = function() M.cmd.ChatReview({}) end,
			note_new = function() M.cmd.NoteNew() end,
			note_finder = function() M.cmd.NoteFinder({}) end,
			note_dirs = function() M.cmd.NoteDirs({}) end,
			year_root = function()
				local current_year = os.date("%Y")
				local year_dir = M.config.notes_dir .. "/" .. current_year
				M.helpers.prepare_dir(year_dir, "year")
				vim.cmd("cd " .. year_dir)
			end,
			markdown_finder = function() M.cmd.MarkdownFinder() end,
			super_repo_toggle = function()
				local before = M.is_super_repo_active()
				M.toggle_super_repo()
				local after = M.is_super_repo_active()
				if after and not before then
					local members = M.config.super_repo_members or {}
					local count = #members
					if count <= 1 then
						vim.notify(
							"super-repo: ON, but no sibling .parley repos found under " ..
								(M.config.super_repo_root or "?"),
							vim.log.levels.WARN
						)
					else
						vim.notify("super-repo: ON (" .. count .. " members)", vim.log.levels.INFO)
					end
				elseif not after and before then
					vim.notify("super-repo: OFF", vim.log.levels.INFO)
				end
			end,
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
						local matches = issues_mod.complete_frontmatter_values("status", partial)
						if #matches == 0 then return end
						require("parley.helper").complete_noselect(col + 1, matches)
					end,
				})
			end
		end,
	})

	-- Read-repair, on exactly one trigger: the cursor resting on a reference
	-- (#224). CursorHold, not CursorMoved — cursor motion is a keystroke path
	-- and a glob across the chat roots per motion is the repeated expensive
	-- work ARCH-CONSTRAINTS forbids. It READS `updatetime` and does not set it:
	-- this is the plugin's first cursor autocmd, and silently changing a global
	-- option to tune a cosmetic feature is the surprise `default_keymaps`
	-- exists to prevent.
	local repair_augroup = vim.api.nvim_create_augroup("ParleyReadRepair", { clear = true })
	vim.api.nvim_create_autocmd("CursorHold", {
		group = repair_augroup,
		pattern = "*.md",
		callback = function(ev)
			-- pcall so a repair bug cannot break cursor movement, but the error
			-- is REPORTED: a silently swallowed one would make this feature
			-- fail invisibly for as long as nobody looked.
			local ok, err = pcall(M.repair_reference_at_cursor, ev.buf,
				vim.api.nvim_win_get_cursor(0)[1])
			if not ok then
				M.logger.warning("read-repair failed: " .. tostring(err))
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
		ChatMove = chat_dir_completion,
	}

	-- Add ChatRespondAll command
	M.cmd.ChatRespondAll = function()
		M.chat_respond_all()
	end

	-- Open the current chat's exchange / raw log in a vertical split.
	local function open_log_for_current_buffer(kind)
		local buf = vim.api.nvim_get_current_buf()
		local chat_path = vim.api.nvim_buf_get_name(buf)
		if chat_path == "" then
			vim.notify("Parley: current buffer has no file path; open a chat first", vim.log.levels.WARN)
			return
		end
		local raw_log = require("parley.raw_log")
		local path = raw_log.log_path_for(chat_path, kind)
		if vim.fn.filereadable(path) == 0 then
			vim.notify("Parley: no " .. kind .. " log yet at " .. path, vim.log.levels.INFO)
			return
		end
		vim.cmd("vsplit " .. vim.fn.fnameescape(path))
	end
	M.cmd.OpenExchangeLog = function() open_log_for_current_buffer("exchange") end
	M.cmd.OpenRawLog = function() open_log_for_current_buffer("raw") end

	-- Toggle Exchange-level Logging (writes per-turn message lists to a side file).
	M.cmd.ToggleExchangeLog = function()
		if not (M.config.raw_mode and M.config.raw_mode.enable) then
			M.logger.warning("Raw mode is disabled in configuration")
			vim.notify("Raw mode is disabled in configuration", vim.log.levels.WARN)
			return
		end
		M.config.raw_mode.log_exchange = not M.config.raw_mode.log_exchange
		local state = M.config.raw_mode.log_exchange and "enabled" or "disabled"
		M.logger.info("Exchange log " .. state)
		vim.notify("Exchange log " .. state, vim.log.levels.INFO)
		pcall(function() require("lualine").refresh() end)
	end

	-- Toggle Raw API Logging (writes per-turn request payload + assembled
	-- response YAML + raw SSE chunks to a side file).
	M.cmd.ToggleRawLog = function()
		if not (M.config.raw_mode and M.config.raw_mode.enable) then
			M.logger.warning("Raw mode is disabled in configuration")
			vim.notify("Raw mode is disabled in configuration", vim.log.levels.WARN)
			return
		end
		M.config.raw_mode.log_raw = not M.config.raw_mode.log_raw
		local state = M.config.raw_mode.log_raw and "enabled" or "disabled"
		M.logger.info("Raw log " .. state)
		vim.notify("Raw log " .. state, vim.log.levels.INFO)
		pcall(function() require("lualine").refresh() end)
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

	-- Fold the 🔧:/📎: tool blocks in the current chat. Deliberately UNBOUND by
	-- default (#214): a tool call's result is low-value reading for the user, so
	-- folding it does not earn a key out of the shared <C-g> surface. It is a
	-- command so it is still reachable without editing config — set
	-- `chat_shortcut_toggle_tool_folds` to bind it.
	M.cmd.ToggleToolFolds = function()
		-- Scoped: foldenable is window-local, so an unscoped toggle would flip
		-- folds in whatever window happened to be current, including a source
		-- file that has nothing to do with parley (#214 BR-17).
		local buf = vim.api.nvim_get_current_buf()
		if not M._parley_bufs[buf] then
			M.logger.warning("Tool folds apply to parley chat buffers only")
			return
		end
		vim.wo.foldenable = not vim.wo.foldenable
		M.logger.info("Tool folds " .. (vim.wo.foldenable and "enabled" or "disabled"))
	end

	-- Toggle the server-side web_search tool for this chat.
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

--- Persist the current state without reloading disk state or reapplying roots.
--- Runtime-derived chat roots and repo/super-repo note roots are excluded.
---@return boolean ok
---@return string|nil err
M.persist_state = function()
	local persist_state = vim.deepcopy(M._state)
	persist_state.chat_roots = nil
	persist_state.chat_dirs = nil

	local pushed_note = {}
	for _, dir in ipairs(super_repo.get_pushed_note_dirs()) do
		pushed_note[dir] = true
	end
	if type(persist_state.note_roots) == "table" then
		local filtered = {}
		for _, root in ipairs(persist_state.note_roots) do
			if root.label ~= "repo" and not pushed_note[resolve_dir_key(root.dir)] then
				table.insert(filtered, root)
			end
		end
		persist_state.note_roots = #filtered > 0 and filtered or nil
	end
	if type(persist_state.note_roots) == "table" then
		local dirs = {}
		for _, root in ipairs(persist_state.note_roots) do
			table.insert(dirs, root.dir)
		end
		persist_state.note_dirs = #dirs > 0 and dirs or nil
	else
		persist_state.note_dirs = nil
	end

	local state_file = M.config.state_dir .. "/state.json"
	return M.helpers.table_to_file_atomic(persist_state, state_file)
end

--- Put a built agent into the roster. One writer for the mechanics; the two
--- call sites keep their DIFFERENT collision semantics, because the difference
--- is real and collapsing it was a regression (BR-109):
---
---   * **Selecting** a live row is the user naming this model right now, so it
---     wins. In practice the picker drops a model that is already an agent, so
---     a collision here is only reachable via `:ParleyAgent`-style re-entry.
---   * **Restoring** a persisted pick at startup must NOT win. `setup()` builds
---     `M.agents` from config and only then calls `refresh_state`, so keeping
---     would let a stale `<id>*` session pick clobber a configured agent of the
---     same name on every launch. Config is authoritative; the persisted pick is
---     a session convenience.
---
--- Collapsing both onto overwrite left no test able to tell: reverting the
--- assignment to the keep form kept the whole suite green.
---@param agent table|nil
---@param keep_existing boolean|nil # true = a configured entry of this name wins
---@return string|nil name
local function adopt_agent(agent, keep_existing)
	if not agent or not agent.name then
		return nil
	end
	if not (keep_existing and M.agents[agent.name]) then
		M.agents[agent.name] = agent
	end
	if not vim.tbl_contains(M._agents, agent.name) then
		table.insert(M._agents, agent.name)
		table.sort(M._agents)
	end
	return agent.name
end

--- Reconcile in-memory state with what is on disk, apply `update`, persist.
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

	-- Issue #117 M2: chat roots are derived from config.chat_dir + repo
	-- mode + super-repo, never restored from state.json. Old state files
	-- may still carry chat_dirs/chat_roots fields — they are ignored.

	-- Restore note roots from persisted state
	if type(M._state.note_roots) == "table" and #M._state.note_roots > 0 then
		apply_note_roots(M._state.note_roots)
	else
		M._state.note_roots = vim.deepcopy(M.get_note_roots())
		M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
	end

	-- Issue #117 M2: the chat-side defensive re-injection of repo_chat
	-- as primary lived here. With state.json no longer carrying chat
	-- roots, apply_repo_local at setup is the single source of truth
	-- for the chat roots list — there's no stale state to defend
	-- against. The note-side block below is unchanged because notes
	-- still persist their roots (separate cleanup, separate issue).

	-- In repo mode, ensure repo note dir is the primary root (overrides persisted state)
	if M.config.repo_root and M.config.repo_note_dir then
		local repo_note = M.config.repo_root .. "/" .. M.config.repo_note_dir
		local resolved_repo = resolve_dir_key(repo_note)
		local current_roots = M.get_note_roots()
		local already_primary = #current_roots > 0
			and resolve_dir_key(current_roots[1].dir) == resolved_repo

		if not already_primary then
			local new_roots = { { dir = repo_note, label = "repo" } }
			for _, root in ipairs(current_roots) do
				if resolve_dir_key(root.dir) ~= resolved_repo then
					table.insert(new_roots, root)
				end
			end
			apply_note_roots(new_roots)
			M._state.note_roots = vim.deepcopy(M.get_note_roots())
			M._state.note_dirs = vim.deepcopy(M.get_note_dirs())
		end
	end

	-- Re-register the last live cliproxy pick BEFORE the guard below. Without
	-- this ordering the guard finds the name absent from M.agents and resets to
	-- M._agents[1], so a live pick would silently evaporate on every restart.
	if type(M._state.live_agent) == "table" and type(M._state.live_agent.id) == "string" then
		local ok, agent = pcall(function()
			return require("parley.cliproxy_catalog").build_agent(M._state.live_agent)
		end)
		if ok then
			adopt_agent(agent, true) -- config wins over a persisted pick
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

	-- Runtime roots are filtered by the shared write-only boundary. Writing must
	-- not reload state or disturb a live super-repo overlay.
	local persisted, persist_err = M.persist_state()
	if not persisted then
		M.logger.warning("state: persistence failed: " .. tostring(persist_err or "unknown error"))
	end

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
M.cmd.Stop = function(signal) chat_respond.cmd_stop(signal) end

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
		-- Check note (across all note roots)
		local note_roots = M.get_note_roots()
		for _, root in ipairs(note_roots) do
			local norm_notes = vim.fn.resolve(vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"))
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

-- The key to advertise for `id` in chat-header prose. Resolves through the
-- registry, so a rebound, aliased or disabled binding is reported accurately
-- rather than from a second copy of the resolution rules; an unbound key
-- renders as the command, which the templates already offer as the alternative.
-- Module-scope because both call sites need it — #214 replaced a `primary`
-- helper that was duplicated at those same two sites, and copying the body
-- again would have preserved the duplication it was meant to retire.
local function key_hint(id, cmd)
	return kb_registry.key_for(id, M.config) or (":" .. M.config.cmd_prefix .. cmd)
end

local function keybinding_help_lines(context)
	local cfg = M.config or {}
	local current_buf = vim.api.nvim_get_current_buf()
	context = context or detect_buffer_context(current_buf)
	return kb_registry.help_lines(context, cfg)
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
	if type(M.config.repo_root) == "string" and M.config.repo_root ~= "" then
		require("parley.neighborhood").attach_completion(buf)
	end
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

-- Drill-in handlers — shared between chat and markdown buffers (any buffer
-- in `parley_buffer` scope). Take buf as an explicit param so they can be
-- wired into both prep_chat and setup_markdown_keymaps.
local _drill_in_mod = require("parley.drill_in")

local function drill_in_visual(buf)
	local sp = vim.fn.getpos("'<")
	local ep = vim.fn.getpos("'>")
	local sr, sc = sp[2], sp[3]
	local er, ec = ep[2], ep[3]
	if sr == 0 or er == 0 then return end

	local lines_in_range = vim.api.nvim_buf_get_lines(buf, sr - 1, er, false)
	if #lines_in_range == 0 then return end

	-- Clamp end col for V-line mode (col can be huge)
	local end_line_text = lines_in_range[#lines_in_range]
	if ec > #end_line_text then ec = #end_line_text end

	local prefix = lines_in_range[1]:sub(1, sc - 1)
	local suffix = end_line_text:sub(ec + 1)

	-- #161 ARCH-DRY: one shared visual-selection slice (define.slice_selection).
	-- lines_in_range is the [sr..er] slice, so line sr → index 1, er → er-sr+1;
	-- getpos cols are 1-based, slice_selection takes 0-based (sub(sc, ec)).
	local selected = require("parley.define").slice_selection(
		lines_in_range, 1, sc - 1, er - sr + 1, ec - 1)

	if selected == "" then
		M.logger.warning("Drill-in: empty selection")
		return
	end

	local wrapped_lines = vim.split(_drill_in_mod.wrap(selected), "\n", { plain = true })
	local new_lines = {}
	if #wrapped_lines == 1 then
		table.insert(new_lines, prefix .. wrapped_lines[1] .. suffix)
	else
		table.insert(new_lines, prefix .. wrapped_lines[1])
		for i = 2, #wrapped_lines - 1 do
			table.insert(new_lines, wrapped_lines[i])
		end
		table.insert(new_lines, wrapped_lines[#wrapped_lines] .. suffix)
	end

	vim.api.nvim_buf_set_lines(buf, sr - 1, er, false, new_lines)

	-- Cursor between [ and ] in the last line of wrapped text. Wrap always
	-- ends with `[]`, so placing the cursor at the index of `]` (0-based)
	-- puts it between `[` and `]`, ready for insert.
	local last_wrapped = wrapped_lines[#wrapped_lines]
	local target_row, target_col
	if #wrapped_lines == 1 then
		target_row = sr
		target_col = #prefix + #last_wrapped - 1
	else
		target_row = sr + #wrapped_lines - 1
		target_col = #last_wrapped - 1
	end
	vim.api.nvim_win_set_cursor(0, { target_row, target_col })
	vim.schedule(function() vim.cmd("startinsert") end)
end

-- Inline term definition (#161 + R1, #166). render_definition is the on_done IO
-- seam. On a successful lookup it stores the definition as a durable markdown
-- footnote (ONE undo entry — the anchor), highlights the selected term/reference
-- span (DiffChange), and shows the definition as an ephemeral INFO
-- diagnostic. Undo/redo coherence reuses review's projection watcher: undoing
-- the footnote edit lands on the pre-edit content-hash → the empty snapshot
-- renders → both decorations clear.
-- `span` = the visual selection {sr, sc, er, ec} (1-based getpos values).
local function render_definition(buf, span, phrase, result)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	-- Pick the emit_definition call (unforced → the model may answer in text or
	-- only call web_search; both mean "no definition"). Notify rather than
	-- silently doing nothing, and leave no footnote edit.
	local call
	if result and result.calls then
		for _, c in ipairs(result.calls) do
			if c.name == "emit_definition" then
				call = c
				break
			end
		end
	end
	if not call then
		M.logger.warning("Define: no definition returned")
		return
	end

	local sr, sc, er, ec = span[1], span[2], span[3], span[4]
	local define = require("parley.define")
	local skill_render = require("parley.skill_render")
	local projection = require("parley.skills.review.projection")

	-- The buffer may have changed under the in-flight call; skip the whole render
	-- rather than attach a footnote reference to shifted text.
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if define.slice_selection(lines, sr, sc - 1, er, ec - 1) ~= phrase then
		M.logger.warning("Define: selection changed during lookup — re-select to define")
		return
	end
	local original = table.concat(lines, "\n") -- pre-edit content (undo base)

	-- Store the definition as a markdown footnote in ONE full-buffer set_lines
	-- edit (single undo entry = the anchor). set_applying suppresses any prior
	-- define's projection watcher during our own edit (mirrors review).
	projection.set_applying(buf, true)
	local input = call.input or {}
	local e = define.apply_definition_footnote(lines, sr, sc - 1, er, ec - 1, input.term or phrase, input.definition)
	require("parley.buffer_edit").replace_all_lines_for_definition(buf, e.lines)

	local diag_span = e.diagnostic_span
	skill_render.highlight_span(buf, diag_span.lnum, diag_span.col, diag_span.end_lnum, diag_span.end_col)
	skill_render.refresh_footnote_diagnostics(buf)

	-- Record projection states so undo/redo of the footnote edit clears/restores
	-- the decorations (#133 M5 machinery, reused): pre-edit hash → empty
	-- snapshot, footnoted hash → highlight+diagnostic; attach the watcher.
	projection.record_empty_for(buf, original)
	projection.record(buf)
	projection.ensure_watch(buf)
	projection.set_applying(buf, false)

	-- Park the cursor on the term's line so diag_display's current-line
	-- virtual_lines reveals the definition immediately.
	pcall(vim.api.nvim_win_set_cursor, 0, { sr, math.max(0, sc - 1) })
	vim.cmd("redraw")
end

-- define_visual: the thin IO shell for visual-mode <M-CR>. Reads the selection,
-- computes the enclosing-exchange context, and fires a headless define skill
-- turn whose on_done stores + renders the definition inline. Pure logic lives
-- in lua/parley/define.lua. Exposed as M.define_visual for the keybinding.
function M.define_visual(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local sp = vim.fn.getpos("'<")
	local ep = vim.fn.getpos("'>")
	local sr, sc = sp[2], sp[3]
	local er, ec = ep[2], ep[3]
	if sr == 0 or er == 0 then return end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local define = require("parley.define")
	-- getpos cols are 1-based; slice_selection takes 0-based (sub(sc, ec)).
	local phrase = define.slice_selection(lines, sr, sc - 1, er, ec - 1)
	if phrase:gsub("%s", "") == "" then
		M.logger.warning("Define: empty selection")
		return
	end

	local header_end = M.chat_parser.find_header_end(lines) or 0
	local parsed = M.parse_chat(lines, header_end)
	local context = define.context_for_selection(parsed, sr, lines, M.find_exchange_at_line)

	local span = { sr, sc, er, ec }
	local manifest = require("parley.skills.define")
	local stop_selection_spinner = require("parley.selection_spinner").start(buf, er - 1, ec)
	require("parley.skill_invoke").invoke(buf, manifest, { phrase = phrase }, {
		document = context,
		no_reload = true,
		detached_progress = false,
		on_terminal = stop_selection_spinner,
		on_done = function(result) render_definition(buf, span, phrase, result) end,
	})
end

-- Accept/reject flash animation (#124). The resolver flashes the removed
-- marker red, then the inserted replacement green, so the user sees what left
-- and what landed. Persistent extmarks in their own namespace (not the
-- ephemeral decoration-provider one) so they survive redraws for the flash.
local drill_in_flash_ns = vim.api.nvim_create_namespace("parley_review_flash")
-- 500 ms per phase matches ../pair's draft-window flash effects (copy-on-select
-- paste, shell-output insert), so the two harnesses feel consistent.
local DRILL_IN_FLASH_DELETE_MS = 500
local DRILL_IN_FLASH_INSERT_MS = 500

-- Per-buffer pending mutation. The buffer change is deferred behind the red
-- phase so the removed text is visible before it goes; this holds the closure
-- that applies it so a second accept/reject during the red window can flush
-- the first to the buffer before reading fresh text (otherwise the second
-- resolve computes against stale text and clobbers the first).
local drill_in_pending = {}

-- Convert a 0-based byte offset into the joined ("\n") buffer text to a
-- 0-based (row, col) extmark position.
local function byte_offset_to_rowcol(lines, off)
	local pos = 0
	for i, line in ipairs(lines) do
		if off <= pos + #line then
			return i - 1, off - pos
		end
		pos = pos + #line + 1
	end
	local last = #lines
	return math.max(last - 1, 0), #(lines[last] or "")
end

-- Highlight byte range [start_off, end_off) (0-based, exclusive end) across
-- `lines` with `hl_group` in the flash namespace.
local function drill_in_flash(buf, lines, start_off, end_off, hl_group)
	if end_off <= start_off then return end
	local srow, scol = byte_offset_to_rowcol(lines, start_off)
	local erow, ecol = byte_offset_to_rowcol(lines, end_off)
	pcall(vim.api.nvim_buf_set_extmark, buf, drill_in_flash_ns, srow, scol, {
		end_row = erow,
		end_col = ecol,
		hl_group = hl_group,
		priority = 250,
	})
end

local function drill_in_flash_clear(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, drill_in_flash_ns, 0, -1)
	end
end

-- Apply a pending mutation immediately (timer fired, or flushed by a new
-- resolve). Idempotent: clears its own pending slot before running.
local function drill_in_flush_pending(buf)
	local p = drill_in_pending[buf]
	if not p then return end
	drill_in_pending[buf] = nil
	-- vim.defer_fn auto-closes its timer on normal fire; here we're pre-empting
	-- it, so stop+close ourselves to avoid leaking the handle.
	if p.timer then
		pcall(function() p.timer:stop() end)
		pcall(function() p.timer:close() end)
	end
	p.apply()
end

-- Accept or reject the marker the cursor sits inside per review-convention
-- §5 (#124). Returns true when a marker was acted on; false otherwise.
-- Cursor lands at the byte position where the marker used to start.
local function drill_in_resolve_at_cursor_with_mode(buf, mode)
	-- Flush any mid-flash mutation first so we read post-change text.
	drill_in_flush_pending(buf)

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local text = table.concat(lines, "\n")
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row = cursor[1]
	local col = cursor[2]

	local offset = 0
	for i = 1, row - 1 do
		offset = offset + #lines[i] + 1
	end
	offset = offset + col + 1

	local fn = mode == "accept" and _drill_in_mod.accept_at or _drill_in_mod.reject_at
	local new_text, m = fn(text, offset)
	if not m then return false end

	-- Byte math: the marker spans [byte_start, byte_end] (1-based, inclusive)
	-- in the old text; the replacement that lands in its place is inserted_len
	-- bytes long (negative net = pure deletion → no green phase).
	local marker_len = m.byte_end - m.byte_start + 1
	local inserted_len = #new_text - #text + marker_len

	-- Phase 1: flash the text that's about to be removed, red. For a strike
	-- marker (🤖~D~{R}) only `🤖~D~` is the deletion — the `{R}` chain is the
	-- replacement that survives, so red stops at the strike's closing `~`
	-- rather than spanning the whole marker. Other markers are removed whole.
	local del_end = (m.strike and m.strike.byte_end) or m.byte_end
	drill_in_flash_clear(buf)
	drill_in_flash(buf, lines, m.byte_start - 1, del_end, "ParleyReviewFlashDelete")

	-- Phase 2 (deferred): splice in the replacement, reposition the cursor,
	-- and flash the inserted text green.
	local function apply()
		if not vim.api.nvim_buf_is_valid(buf) then return end
		drill_in_flash_clear(buf)

		local new_lines = vim.split(new_text, "\n", { plain = true })
		-- Replace ONLY the marker's line range (not the whole buffer) so review
		-- decorations elsewhere RIDE the edit via extmark gravity — exactly like a
		-- manual edit. A full set_lines(0,-1) would wipe every extmark + diagnostic
		-- (#133). A content-verification fallback guarantees correctness if the
		-- range math is ever off.
		local start0, end0, region = _drill_in_mod.narrow_replace_range(lines, new_text, m.byte_start, m.byte_end)
		local ok_narrow = pcall(vim.api.nvim_buf_set_lines, buf, start0, end0, false, region)
		if not ok_narrow
			or table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") ~= new_text then
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines) -- safe fallback
		end

		local target = m.byte_start
		local target_row, target_col = 1, 0
		local pos = 1
		for i, line in ipairs(new_lines) do
			if pos + #line >= target then
				target_row = i
				target_col = target - pos
				break
			end
			pos = pos + #line + 1
		end
		local line_len = #(new_lines[target_row] or "")
		if target_col > line_len then target_col = line_len end
		if target_col < 0 then target_col = 0 end
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
			pcall(vim.api.nvim_win_set_cursor, win, { target_row, target_col })
		end

		if inserted_len > 0 then
			drill_in_flash(buf, new_lines, m.byte_start - 1, m.byte_start - 1 + inserted_len,
				"ParleyReviewFlashInsert")
			vim.defer_fn(function() drill_in_flash_clear(buf) end, DRILL_IN_FLASH_INSERT_MS)
		end
	end

	local timer = vim.defer_fn(function()
		drill_in_pending[buf] = nil
		apply()
	end, DRILL_IN_FLASH_DELETE_MS)
	drill_in_pending[buf] = { timer = timer, apply = apply }
	return true
end

local function drill_in_accept_at_cursor(buf)
	return drill_in_resolve_at_cursor_with_mode(buf, "accept")
end

local function drill_in_reject_at_cursor(buf)
	return drill_in_resolve_at_cursor_with_mode(buf, "reject")
end

-- Insert-mode: drop a bare `🤖[]` annotation marker at the cursor and place
-- the cursor between `[` and `]` so the user can type their comment without
-- leaving insert mode. No `<>` quoted body — that form is for visual-mode
-- wrap; here the marker refers to the surrounding text by position only.
local function drill_in_insert(buf)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	local before = line:sub(1, col)
	local after = line:sub(col + 1)
	vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { before .. "🤖[]" .. after })
	-- 🤖 = 4 bytes, `[` = 1 byte → cursor between [ and ] sits at col + 5.
	vim.api.nvim_win_set_cursor(0, { row + 1, col + 5 })
end

-- Build the registry callbacks table for drill-in / review markers.
-- Identical shape used in both prep_chat and setup_markdown_keymaps.
--
-- Marker convention bindings (see review-convention target, #124):
--   <M-q> / <C-g>q  — insert a marker (wrap selection or insert bare)
--   <M-a>           — accept the marker at cursor per §5
--   <M-r>           — reject the marker at cursor per §5
local function drill_in_callbacks(buf)
	return {
		chat_drill_in = {
			v = function()
				vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
				drill_in_visual(buf)
			end,
			x = function()
				vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
				drill_in_visual(buf)
			end,
			i = function() drill_in_insert(buf) end,
			n = function()
				-- Always insert in normal mode. Accept/reject have their
				-- own dedicated bindings (<M-a>, <M-r>) per the review
				-- convention; <M-q> doesn't overload to mean both.
				drill_in_insert(buf)
				vim.cmd("startinsert")
			end,
		},
		chat_accept_drill_in = function()
			if not drill_in_accept_at_cursor(buf) then
				M.logger.warning("No 🤖 marker at cursor")
			end
		end,
		chat_reject_drill_in = function()
			if not drill_in_reject_at_cursor(buf) then
				M.logger.warning("No 🤖 marker at cursor")
			end
		end,
	}
end

-- Return the branch prefix string from config.
local function get_branch_prefix()
	return M.config.chat_branch_prefix or "🌿:"
end

-- Format a 🌿: branch reference line.
local function format_branch_ref(rel_path, topic)
	-- Delegates: branch_ref.format_ref_line is the one definition (#214 BR-5).
	return require("parley.branch_ref").format_ref_line(get_branch_prefix(), rel_path, topic)
end


-- ONE branch-at-this-point implementation for chat and markdown buffers (#214).
--
-- There were four copies. They had drifted where it mattered: both VISUAL paths
-- called create_child_chat, neither n/i path did — so the no-selection case
-- wrote a reference to a file that did not exist. That gap is what made the two
-- invocations feel like different actions rather than one action with a
-- selection or without.
--
-- `abs_link` is the only real difference between the buffer types: a chat file
-- links its sibling by basename, a markdown file elsewhere needs the full path.
--
-- On the no-selection path the topic does not exist yet, so the child is created
-- with an empty topic and OPENED — the user types the question in the child
-- rather than on the parent's ref line. The child's filename gains its slug on
-- first write (the ParleySlug BufWritePost autocmd, which correctly skips an
-- empty/`?` topic), and the parent's link keeps resolving because
-- resolve_chat_path falls back to globbing the timestamp for any slug variant
-- via resolve_chat_path's glob fallback. Verified, not assumed.
--- @param buf number
--- @param abs_link boolean  inline links use an absolute path (markdown)
--- @param owns_file boolean parley owns this file and may write it (chat)
local function branch_inserters(buf, abs_link, owns_file)
	local br = require("parley.branch_ref")

	local function new_target()
		local file = M.config.chat_dir .. "/" .. M.logger.now() .. ".md"
		return file, (abs_link and vim.fn.fnamemodify(file, ":p") or vim.fn.fnamemodify(file, ":t"))
	end

	-- Every mode that creates a child MUST commit the reference in the same
	-- action: the child is a durable artifact on disk, discoverable ONLY through
	-- the in-buffer link, so a :q! or crash between the two orphans it (#214
	-- BR-19 / I3-3). The enumeration is the dispatch table below — n, i, v — not
	-- "the path I happened to be looking at".
	--
	-- Scoped to parley-owned CHAT buffers. `:write` commits the whole buffer, so
	-- writing an arbitrary markdown document would persist the user's unrelated
	-- pending edits, which they never asked for (I3-2). On a foreign buffer we
	-- keep the pre-#214 behaviour instead: leave the line unsaved and stay put,
	-- so nothing is written and nothing is navigated away from.
	--- Create the child ONLY where the reference can be made durable. Both modes
	--- call this; neither calls create_child_chat directly, because "apply the
	--- rule to the path I am looking at" is what left insert_inline creating
	--- orphans on markdown two rounds running (#214 BR-28).
	--- @return boolean created
	local function create_child_if_owned(file, topic, question)
		if not owns_file then return false end
		M.create_child_chat(file, topic, buf, question)
		return true
	end

	--- @return boolean committed  false when the caller must not navigate away
	local function commit_reference()
		if not owns_file then
			return false
		end
		local ok = pcall(function()
			vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
		end)
		if not ok then
			M.logger.warning("Branch: could not save the parent; staying put so "
				.. "the reference is not lost")
		end
		return ok
	end

	-- Two buffer types, two honest guarantees — stated once here rather than
	-- discovered per finding (#214 BR-27/BR-28).
	--
	-- A CHAT buffer is parley's own file, so the full flow is coherent: create
	-- the child, commit the parent so the only reference to it is durable, then
	-- focus the child because this is a submission redirected into a new branch.
	--
	-- A FOREIGN markdown buffer is the user's document. parley must not `:write`
	-- it (that persists their unrelated pending edits — I3-2), and without a
	-- write it cannot make the reference durable — so creating a child there
	-- would leave an orphan on disk reachable only through an unsaved line
	-- (BR-28). It therefore does what it did before #214: insert the reference,
	-- put the cursor on it, and let the user type the topic. The child is created
	-- when the link is followed.
	--- #214 M3: `<M-S-CR>` in normal/insert mode on a CHAT buffer submits what
	--- `<M-CR>` would submit, into a new child, leaving the reference where
	--- `<M-CR>`'s output would have appeared.
	---
	--- Returns false when there is nothing to submit — an empty transcript, or a
	--- cursor outside every exchange — and the caller then does what `<M-i>` did
	--- before M3: insert a bare reference and open the child. That fallback is
	--- deliberate. "Make me a side chat from here" is a real affordance M1
	--- shipped, and generalising the chord must not delete it; the chord should
	--- never be a no-op.
	local function insert_planned()
		local drill_in = require("parley.drill_in")
		local buffer_edit = require("parley.buffer_edit")
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local text = table.concat(lines, "\n")
		local header_end = M.chat_parser.find_header_end(lines)
		local parsed = M.parse_chat(lines, header_end)
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

		-- One parse, not two. This used to run `drill_in.parse` over the whole
		-- buffer to build a marker list carrying a `line` field the planner never
		-- read, and `gather_edit_plan` parsed it all again three lines later
		-- (#214 M3 review, Minor). The gather is the authority on whether there
		-- is anything to rearrange, so ask it first.
		local blocks, _, marker_edits = drill_in.gather_edit_plan(
			text, drill_in.chat_gather_opts(M.config))
		local plan, reason = require("parley.branch_submit").plan_submission(
			parsed, cursor_line, #blocks > 0)
		if not plan then
			M.logger.debug("Branch: nothing to submit (" .. tostring(reason)
				.. "); falling back to a plain reference")
			return false
		end

		local question = require("parley.branch_submit").seed_question(
			"quotes", table.concat(drill_in.format_blocks(blocks), "\n"))
		local label = require("parley.branch_ref").topic_for_selection(
			(blocks[1].sections[#blocks[1].sections] or {}).text or "")

		local new_chat_file = (new_target())
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":t")

		-- Create the child FIRST, before touching the parent (#214 BR-63). The
		-- write was pcall-guarded and this was not, so an unwritable chat_dir
		-- raised out of the keymap callback with the markers already stripped and
		-- the reference already inserted — a parent pointing at a file that does
		-- not exist, and the user's annotations gone. Ordering removes the
		-- window rather than trying to undo inside it: nothing is mutated until
		-- the child is on disk.
		--
		-- The reverse hazard (child on disk, reference not yet saved) is BR-19's
		-- orphan and is handled below by not navigating away on a failed write.
		local created_ok = pcall(create_child_if_owned, new_chat_file, "?", question)
		if not created_ok then
			M.logger.warning("Branch: could not create " .. rel_path
				.. " — nothing was changed in this chat")
			return true
		end

		-- #214 BR-58: anchor the insertion point BEFORE stripping. `ref_after` is
		-- a pre-strip line number and `apply_text_edits` changes the line count
		-- whenever a removed marker owned whole lines — which the ordinary
		-- standalone `🤖[…]` form does. An extmark travels with the edit;
		-- chat_respond solves the same problem the same way (`make_handle` around
		-- its own gather). The earlier code kept the raw number, so the reference
		-- drifted by however many lines the strip removed, in the common case
		-- landing past the exchange's `📝:` summary.
		-- Anchor ON the cursor line, not on the line after it. `ref_after` is
		-- 1-indexed and `make_handle` takes a 0-indexed row, so passing it
		-- directly put the mark on the following line — usually the blank gap
		-- that `drill_in`'s edit swallows, and with left gravity the mark then
		-- collapsed and the reference landed ABOVE the cursor. Visible only with
		-- a marker BELOW the cursor; every fixture in the first fix put one
		-- above, sampling one side of the axis (#214 BR-58, round 2).
		local anchor = buffer_edit.make_handle(buf, plan.ref_after - 1)
		buffer_edit.apply_text_edits(buf, 0, text, marker_edits)
		local insert_at = buffer_edit.handle_line(anchor) + 1
		buffer_edit.handle_invalidate(anchor)

		-- AT THE CURSOR (operator, 2026-09-07), as its own block — one blank line
		-- on each side, added only where there is not one already. `ref_block`
		-- owns that rule for both insert paths (#214 BR-68); this used to emit
		-- `{ "", ref }`, a blank before only, so the reference abutted whatever
		-- followed it.
		local around = vim.api.nvim_buf_get_lines(buf, math.max(insert_at - 1, 0),
			insert_at + 1, false)
		vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false,
			br.ref_block(br.format_ref_line(get_branch_prefix(), rel_path, label or ""),
				insert_at > 0 and around[1] or nil,
				around[insert_at > 0 and 2 or 1]))
		M.highlight_chat_branch_refs(buf)
		if not commit_reference() then
			return true
		end
		M.logger.info("Branched submission into: " .. rel_path)
		vim.schedule(function()
			vim.cmd("edit " .. vim.fn.fnameescape(new_chat_file))
			vim.cmd("normal! G")
			-- Insert mode at the end, the same landing the placeholder path
			-- gives. One key must not have two landing modes (#214 M3 review);
			-- and a gathered child usually wants a line of framing before it is
			-- submitted, so insert is the useful default in both cases.
			vim.cmd("startinsert!")
		end)
		return true
	end

	local function insert_plain()
		-- A chat buffer takes the planned path: parley owns the file, so it can
		-- make the reference durable, and the transcript has exchanges to plan
		-- against. A foreign markdown document has neither (#214 M1's rule), so
		-- it keeps the pre-M3 behaviour below.
		if owns_file and insert_planned() then
			return
		end

		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		-- The standalone ref line always uses the basename, in both buffer types:
		-- format_ref_line writes `🌿: <name>: `, which resolve_chat_path looks up
		-- across the chat roots. abs_link governs the INLINE link only.
		local new_chat_file = (new_target())
		local rel_path = vim.fn.fnamemodify(new_chat_file, ":t")
		-- Same block rule as the planned path (#214 BR-68): this inserted a bare
		-- line with no blank on either side, so a placeholder dropped into prose
		-- ran straight into it.
		local near = vim.api.nvim_buf_get_lines(buf, math.max(cursor_pos[1] - 1, 0),
			cursor_pos[1] + 1, false)
		local block = br.ref_block(br.format_ref_line(get_branch_prefix(), rel_path, ""),
			cursor_pos[1] > 0 and near[1] or nil,
			near[cursor_pos[1] > 0 and 2 or 1])
		vim.api.nvim_buf_set_lines(buf, cursor_pos[1], cursor_pos[1], false, block)
		M.highlight_chat_branch_refs(buf)

		-- Which of the inserted lines IS the reference — the block may open with
		-- a margin blank, and the cursor has to land on the reference itself so
		-- the topic can be typed (#214 BR-68 follow-on: adding the margin moved
		-- the cursor onto the blank).
		local ref_row = cursor_pos[1]
		for i, line in ipairs(block) do
			if line:match("%S") then ref_row = cursor_pos[1] + i break end
		end

		if not owns_file then
			-- Pre-#214 behaviour, restored deliberately: no child, no write, and
			-- the cursor lands on the new line in insert mode so the topic can be
			-- typed. An early `return` here once skipped these two lines and made
			-- the key look inert (BR-27).
			vim.api.nvim_win_set_cursor(0, { ref_row, 0 })
			vim.schedule(function() vim.cmd("startinsert!") end)
			M.logger.info("Inserted branch reference: " .. rel_path)
			return
		end

		-- The topic is "?", NOT "": `?` is the sentinel the rest of the lifecycle
		-- keys off. Auto-topic generation fires only on `headers.topic == "?"`,
		-- and the slug rename waits for a real topic rather than an empty one.
		-- Passing "" produced a child that was never titled and never slugged — a
		-- permanently anonymous <timestamp>.md whose parent ref line stayed
		-- `🌿: ….md: ` forever (BR-1). Verified by reading the created header.
		create_child_if_owned(new_chat_file, "?", nil)
		M.highlight_chat_branch_refs(buf)
		if not commit_reference() then
			-- Could not save: stay put rather than navigate away from the only
			-- reference to a file that now exists on disk.
			return
		end
		M.logger.info("Created branch to new chat: " .. rel_path)
		vim.schedule(function()
			vim.cmd("edit " .. vim.fn.fnameescape(new_chat_file))
			vim.cmd("normal! G")
			vim.cmd("startinsert!")
		end)
	end

	local function insert_inline()
		vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
		local sp, ep = vim.fn.getpos("'<"), vim.fn.getpos("'>")
		local start_line, start_col, end_line, end_col = sp[2], sp[3], ep[2], ep[3]
		if start_line ~= end_line then
			M.logger.warning("Inline branch links only support single-line selections")
			return
		end
		local line = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1]
		local new_chat_file, link = new_target()
		local spliced, selected = br.splice_inline_link(
			line, start_col, end_col, get_branch_prefix(), link)
		-- Guard the DERIVED topic, not the raw selection (#214 BR-86). Since
		-- `topic_for_selection` collapses and trims, a whitespace-only selection
		-- derives "" — and an empty topic is BR-1's anonymity bug: auto-titling
		-- fires only on "?" and the slug rename bails on "", so the child stays a
		-- nameless <timestamp>.md forever. `selected == ""` cannot see that,
		-- because "   " is not "".
		local topic = br.topic_for_selection(selected)
		if topic == "" then
			M.logger.warning("Branch: nothing but whitespace selected")
			return
		end
		-- #214 M3: the topic names the SUBJECT (it becomes the filename slug) and
		-- the child is seeded with the instruction, not with `<topic>?`. One
		-- place owns that wording — three call sites would each invent their own.
		vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, { spliced })
		create_child_if_owned(new_chat_file, topic,
			require("parley.branch_submit").seed_question("define", selected))
		M.highlight_chat_branch_refs(buf)
		-- Same durability rule as insert_plain: the child is on disk and only the
		-- in-buffer link points at it. Focus stays in the parent here, so Vim's
		-- own unsaved-buffer guard also applies — but :q! would still orphan it.
		commit_reference()
		M.logger.debug("Created inline branch to new chat: " .. link .. " (" .. topic .. ")")
	end

	--- ARCH-ORDER, applied to the WHOLE chord (#214 BR-69). A streaming response
	--- owns this buffer's exchange model and holds a chat lease on its 🤖: line;
	--- any of these three paths edits the transcript under it. The guard sat
	--- inside `insert_planned`, which only n/i reach, so visual mode created a
	--- child and wrote the parent mid-stream — while the README and the atlas
	--- said the chord declines. This file already states the governing rule
	--- ("The enumeration is the dispatch table below — n, i, v"); wrapping the
	--- table is what applies it, rather than guarding the path in front of me.
	local function refuse_while_pending(fn)
		return function()
			if require("parley.chat_pending").identity(buf) then
				M.logger.warning("Branch: this chat has a response in flight — "
					.. "wait for it, or stop it with the stop shortcut, then branch")
				return
			end
			fn()
		end
	end

	return {
		n = refuse_while_pending(insert_plain),
		i = refuse_while_pending(function() vim.cmd("stopinsert"); insert_plain() end),
		v = refuse_while_pending(insert_inline),
	}
end

-- Test seam (#214 BR-18): the inserters are buffer-local closures wired straight
-- into the keymap dispatch, so a test could reach create_child_chat but not the
-- CALL SITE that decides what topic it is handed — which is precisely where BR-1
-- lived.
M._branch_inserters = branch_inserters

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

	-- Spellcheck + as-you-type spell-suggestion typeahead (config.chat_spell).
	-- The spell <CR> map shadows interview's global <CR> map buffer-locally, so we
	-- inject interview.cr_keys as the no-popup base to keep timestamp insertion (#134).
	local cs = M.config.chat_spell
	if cs and (cs.enable or cs.typeahead) then
		require("parley.spell").attach(buf, vim.tbl_extend("force", cs, {
			prompt_buf_type = M.config.chat_prompt_buf_type,
			base_cr = require("parley.interview").cr_keys,
		}))
	end

	-- Set up tool block folding (clickable foldcolumn icons)
	require("parley.tool_folds").setup(buf)

	require("parley.neighborhood").attach_completion(buf)

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

	-- Branch inserters: shared with markdown buffers (#214). Chat links its
	-- sibling by basename.
	local chat_branch = branch_inserters(buf, false, true)

	-- Drill-in handlers (visual wrap + resolve) live at module scope and are
	-- wired identically in markdown buffers — see `drill_in_callbacks` near
	-- the top of this file.
	local drill_in_cbs = drill_in_callbacks(buf)

	-- Buffer-local wrappers around NATIVE keys. Each falls through to the
	-- builtin unless a parley-specific condition holds, so it claims no
	-- keyspace and has nothing to rebind — which is why it is not a registry
	-- entry. `native_map` enforces that exemption instead of trusting it: the
	-- key must carry a rationale in `keybinding_registry.native_overrides`, and
	-- the whole set honours the `default_keymaps` master switch (#214).
	local function native_map(key, fn, desc)
		if not kb_registry.native_overrides[key] then
			-- A developer mistake, not a user one, and prep_chat has already set
			-- _prepared_bufs — raising here would leave the buffer permanently
			-- half-prepared with no retry. Log and skip; the binding contract is
			-- enforced at test time instead (tests/arch/single_source_sweeps_spec).
			M.logger.warning("parley: un-registered native override '" .. key
				.. "' — add it to keybinding_registry.native_overrides with its "
				.. "rationale, or give it a registry entry so it can be rebound")
			return
		end
		if M.config.default_keymaps == false then
			return
		end
		vim.keymap.set("n", key, fn, { buffer = buf, silent = true, desc = desc })
	end

	-- #141: in chat buffers, `*`/`#` (and `g*`/`g#`) over a `[...]` anchor search
	-- the whole bracketed string, so a cursor inside a `[quoted text]` jumps to
	-- its twin (the decoration left at the source). Outside any bracket, fall
	-- through to the builtin motion.
	local function bracket_jump(builtin, back)
		local line = vim.api.nvim_get_current_line()
		local b = require("parley.drill_in").bracket_at(line, vim.fn.col("."))
		if not b then
			vim.cmd("normal! " .. builtin)
			return
		end
		-- Set the search register (like builtin `*`) and jump; let the user's own
		-- `hlsearch` setting govern highlight — don't force the global flag on
		-- (the fall-through path doesn't either, so this keeps both consistent).
		-- Backward (`#`/`g#`) from mid-bracket first lands on the current span's
		-- `[`, so reaching the twin can take a second press — acceptable for the
		-- two-occurrence anchor/twin case this targets.
		local pat = "\\V" .. vim.fn.escape(b, "\\")
		vim.fn.setreg("/", pat)
		vim.v.searchforward = back and 0 or 1
		vim.fn.search(pat, (back and "b" or "") .. "sw")
	end
	for _, m in ipairs({
		{ key = "*", back = false },
		{ key = "#", back = true },
		{ key = "g*", back = false },
		{ key = "g#", back = true },
	}) do
		native_map(m.key, function()
			bracket_jump(m.key, m.back)
		end, "Parley: search whole [...] anchor (#141)")
	end

	-- Standard history keys stay native unless this chat owns a pending response.
	-- Confirmed history changes stop only this buffer before retiring its session.
	local history = require("parley.chat_history")
	local function guarded_history(key)
		return function()
			local count = vim.v.count1
			local function native_history()
				if key == "u" then
					vim.cmd("normal! " .. count .. "u")
					return
				end
				local keys = vim.api.nvim_replace_termcodes(count .. "<C-r>", true, false, true)
				vim.api.nvim_feedkeys(keys, "nx", false)
			end
			history.guard({
				buf = buf,
				pending_identity = require("parley.chat_pending").identity,
				native_history = native_history,
				confirm = history.confirm,
				cancel_for_history = chat_respond.cancel_for_history,
			})
		end
	end
	native_map("u", guarded_history("u"), "Parley: guard chat history undo")
	native_map("<C-r>", guarded_history("redo"), "Parley: guard chat history redo")

	-- #161: one respond-callback set, shared by chat_respond and chat_define.
	local respond_cb = make_respond_cb("ChatRespond")
	local function chat_define_v()
		vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
		M.define_visual()
	end

	kb_registry.register_buffer(
		{ "parley_buffer", "chat" },
		buf,
		M.config,
		{
			-- parley_buffer scope (shared with markdown)
			open_file = M.cmd.OpenFileUnderCursor,
			resolve_ref_gf = M.cmd.ResolveRefOrGotoFile,
			resolve_ref_project = M.cmd.ResolveRefProject,
			copy_fence = M.cmd.CopyCodeFence,
			outline = M.cmd.Outline,
			-- All three modes come from branch_inserters; the dispatch used to
			-- re-implement i and v, which left `.i` dead and made the visual path
			-- <Esc> twice (#214 BR-4).
			branch_ref = chat_branch,
			paste_image = function() M.paste_image(vim.api.nvim_get_current_buf()) end,
			-- chat scope
			chat_respond = respond_cb,
			-- #161: <M-CR> — n/i reuse the respond closures; v/x <Esc>-commit the
			-- '<,'> marks then run define_visual (visual <C-g><C-g> keeps respond).
			chat_define = { n = respond_cb.n, i = respond_cb.i, v = chat_define_v, x = chat_define_v },
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
			chat_toggle_tool_folds = M.cmd.ToggleToolFolds,
			chat_drill_in = drill_in_cbs.chat_drill_in,
			chat_accept_drill_in = drill_in_cbs.chat_accept_drill_in,
			chat_reject_drill_in = drill_in_cbs.chat_reject_drill_in,
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

M.setup_markdown_keymaps = function(buf)
	-- Document review actions. The skill supplies the callbacks; the REGISTRY
	-- installs them (#214 C1) — it used to install them itself from raw config,
	-- which put <C-g>ve/<M-s>/<M-CR> outside the master switch and made a
	-- `shortcut = ""` disable raise on every markdown BufEnter. nil = journal
	-- sidecar, which gets no review keys.
	local review_skill = require("parley.skills.review")
	local review_cbs = review_skill.registry_callbacks(buf) or {}

	-- Branch inserters: shared with chat buffers (#214). Markdown links INLINE
	-- by absolute path, since the file may live anywhere; the standalone ref
	-- line uses the basename in both buffer types.
	local md_branch = branch_inserters(buf, true, false)

	-- Drill-in handlers (visual wrap + resolve) — same in markdown and chat,
	-- see `drill_in_callbacks` near the top of this file.
	local drill_in_cbs = drill_in_callbacks(buf)

	-- Register markdown buffer-local keymaps from registry
	kb_registry.register_buffer(
		{ "parley_buffer", "markdown" },
		buf,
		M.config,
		{
			-- parley_buffer scope (shared with chat)
			open_file = M.cmd.OpenFileUnderCursor,
			resolve_ref_gf = M.cmd.ResolveRefOrGotoFile,
			resolve_ref_project = M.cmd.ResolveRefProject,
			copy_fence = M.cmd.CopyCodeFence,
			outline = M.cmd.Outline,
			-- The whole dispatch table, as the chat path does (#214 BR-4). This
			-- rebuilt n/i/v inline, which left `branch_inserters(...).i` dead at
			-- zero call sites and re-derived a mapping the constructor already
			-- returns — the same drift M1 collapsed four copies to remove.
			branch_ref = md_branch,
			paste_image = function() M.paste_image(vim.api.nvim_get_current_buf()) end,
			chat_drill_in = drill_in_cbs.chat_drill_in,
			chat_accept_drill_in = drill_in_cbs.chat_accept_drill_in,
			chat_reject_drill_in = drill_in_cbs.chat_reject_drill_in,
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
					local note = require("parley.assets").removal_note(file)
					local choice = vim.fn.confirm("Delete " .. rel .. note .. "?", "&Yes\n&No", 2)
					if choice == 1 then
						M.delete_chat_file(file)
					end
				end
			end,
			md_delete_tree = M.cmd.ChatDeleteTree,
			md_export_html = function() exporter.pandoc_export_html() end,
			-- review scope (#214 C1) — callbacks from the skill, install here
			review_edit = review_cbs.review_edit,
			review_menu = review_cbs.review_menu,
			review_next = review_cbs.review_next,
		},
		M.helpers.set_keymap
	)

end

M.setup_buf_handler = function()
	highlighter.setup_buf_handler()
end

-- Move to the other window when the tab has exactly two. Returns whether it
-- moved. The two-split preference had THREE copies (#225): this one, and two
-- hand-inlined inside OpenFileUnderCursor. Netrw is why a separate call site
-- exists — a directory reference does not go through `open_buf` — but that is
-- a reason for two callers, not for two implementations.
---@param what string|nil # what is being opened, for the debug line
---@return boolean # whether it moved
local function focus_other_split(what)
	local tab_wins = vim.api.nvim_tabpage_list_wins(0)
	if #tab_wins ~= 2 then
		return false
	end
	local current_win = vim.api.nvim_get_current_win()
	for _, win in ipairs(tab_wins) do
		if win ~= current_win then
			M.logger.debug("Opening in other split: " .. (what or "?"))
			vim.api.nvim_set_current_win(win)
			return true
		end
	end
	return false
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

	-- Prefer the other split, unless ChatFinder asked for the current window.
	if not from_chat_finder and focus_other_split(file_name) then
		vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_name))
		return vim.api.nvim_get_current_buf()
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
--- Repair a stale chat reference on ONE line, in the buffer (#224).
---
--- Read-repair used to happen inside `resolve_chat_path` — navigating rewrote
--- files you might not have open. Under prefix identity a slug-stale reference
--- resolves correctly forever, so repair is cosmetic, and the operator chose a
--- single explicit trigger: the cursor entering the link. This is that trigger's
--- one writer.
---
--- Five guards, and each has a reason:
---   * the buffer is a chat file — nothing else carries these references;
---   * the cursor line actually holds one — a cheap string test gates the glob;
---   * the resolved name differs — otherwise there is nothing to do, and a
---     no-op must not set `modified`;
---   * not in insert mode — repair must not fight a half-typed reference;
---   * not busy — a streaming response is a concurrent writer, and `chat_lease`
---     invalidates on concurrent mutation. It IGNORES rather than queues: the
---     next CursorHold retries for free, and queuing would land the write at
---     the least predictable moment.
---
---@param buf integer
---@param lnum integer # 1-indexed
---@return boolean # whether the line was rewritten
M.repair_reference_at_cursor = function(buf, lnum)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	if M.not_chat(buf, vim.api.nvim_buf_get_name(buf)) ~= nil then
		return false
	end
	local mode = vim.api.nvim_get_mode().mode
	if mode:match("^i") or mode:match("^R") then
		return false
	end
	if M.tasker and M.tasker.is_busy(buf, true) then
		return false
	end

	local line = vim.api.nvim_buf_get_lines(buf, lnum - 1, lnum, false)[1]
	if not line or line == "" then
		return false
	end

	-- Cheap gate before any filesystem work: does this line carry a reference?
	local refs = {}
	local parsed = M._parse_branch_ref(line)
	if parsed then
		refs[#refs + 1] = parsed.path
	end
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"
	for _, link in ipairs(require("parley.chat_parser").extract_inline_branch_links(line, branch_prefix)) do
		refs[#refs + 1] = link.path
	end
	if #refs == 0 then
		return false
	end

	local referring = vim.api.nvim_buf_get_name(buf)
	local current_dir = vim.fn.fnamemodify(referring, ":p:h")
	local updated = line
	for _, ref in ipairs(refs) do
		local old_basename = vim.fn.fnamemodify(ref, ":t")
		-- M.resolve_chat_path, not the file-local: this function sits above
		-- the local's definition, and the export resolves at call time.
		local resolved = M.resolve_chat_path(ref, current_dir)
		if resolved and vim.fn.filereadable(resolved) == 1 then
			local rewritten = chat_slug.rewrite_reference(
				updated, old_basename, vim.fn.fnamemodify(resolved, ":t"))
			if rewritten then
				updated = rewritten
			end
		end
	end
	if updated == line then
		return false
	end

	-- buffer_edit, not nvim_buf_set_lines directly: init.lua sits on the
	-- SHRINKING allowlist in tests/arch/buffer_mutation_spec.lua (#90 — "after
	-- Phase 3, ONLY buffer_edit.lua remains"), so a new direct call moves that
	-- list the wrong way. replace_line_at is exactly this operation.
	require("parley.buffer_edit").replace_line_at(buf, lnum - 1, updated)
	return true
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

	-- #231: the assets folder moves with its chat. A clash is refused BEFORE
	-- the .md moves (the same rule move_with applies), so a refusal leaves
	-- everything in place.
	local assets = require("parley.assets")
	local src_folder, clash = assets.move_conflict(resolved_file, target_root)
	if not src_folder and clash then
		return nil, clash
	end

	sync_moved_chat_buffers(resolved_file, nil)

	local ok, err = os.rename(resolved_file, target_file)
	if not ok then
		return nil, "failed to move chat: " .. tostring(err)
	end

	sync_moved_chat_buffers(resolved_file, target_file)

	-- The .md move is done and stays done: the folder failing to follow is
	-- reported only after the state and tracking have followed the file.
	local carried, aerr = assets.move_with(resolved_file, target_file)

	if M._state.last_chat and resolve_dir_key(M._state.last_chat) == resolved_file then
		M.refresh_state({ last_chat = target_file })
	end

	require("parley.file_tracker").track_file_access(target_file)
	if not carried then
		return nil, "moved the chat but not its assets: " .. tostring(aerr)
	end
	return target_file
end


-- Pure: return ordered list of candidate paths for a chat reference.
-- For absolute/~ paths, returns a single candidate.
-- For relative paths, tries base_dir first, then all chat roots.
M._resolve_chat_path_candidates = function(path, base_dir, dirs)
	-- `path` is a 🌿: / inline-link target lifted out of a transcript, so the
	-- ~-branch goes through the guard. resolve_relative_path is TOTAL: on a
	-- refused (backtick) path it returns the literal unexpanded, `filereadable`
	-- says no, and the caller takes its ordinary not-found branch. Returning
	-- nil here is what crashed two callers in review round 2 (C2).
	--
	-- This was the FIFTH copy of the ~/absolute/relative triage; the arch guard
	-- in tests/arch/untrusted_path_spec.lua found it while the other four were
	-- being merged.
	local first = M.helpers.resolve_relative_path(path, base_dir)
	if path:match("^~/") or path == "~" or path:sub(1, 1) == "/" then
		return { first }
	end
	local candidates = { first }
	for _, dir in ipairs(dirs or {}) do
		local c = vim.fn.resolve(dir .. "/" .. path)
		if c ~= candidates[1] then
			table.insert(candidates, c)
		end
	end
	return candidates
end

--- Resolve a chat reference to a path on disk.
---
--- **The timestamp prefix IS the identity of a chat file** (#224). The trailing
--- slug exists so a human can read the directory listing; it carries no meaning
--- to resolution, and a chat earns or changes its slug long after references to
--- it have been written. So the rule is one rule:
---
---     reference → parse_filename() → timestamp → glob "<ts>*" across the roots
---
--- An exact-name hit is not a separate tier — it is the case where that glob
--- returns the name the reference already used, which `resolve_candidates`
--- prefers. Keeping it as a tier is what let a second, exact-match-only
--- resolver be written and go unnoticed: it worked for every reference whose
--- parent had not been renamed yet.
---
--- Falls back to plain existence checks for a reference that is not a chat
--- filename at all (an `@@./notes.md@@`, say) — there is no timestamp to glob.
---
--- Resolution is a READ: it performs no repair. A slug-stale reference resolves
--- correctly forever, so repair is cosmetic and has exactly one trigger, the
--- cursor entering the link (`repair_reference_at_cursor`).
---
---@param path string # the reference, as written in the transcript
---@param base_dir string # directory of the referring file
---@return string # resolved path, or the best candidate when nothing exists
local function resolve_chat_path(path, base_dir)
	local candidates = M._resolve_chat_path_candidates(path, base_dir, M.get_chat_dirs())
	local basename = vim.fn.fnamemodify(path, ":t")
	local ts = chat_slug.parse_filename(basename)

	-- Exact hit short-circuits. This is NOT the tier the Spec deletes: a tier
	-- changes the answer (exact-first, glob-as-fallback), and this cannot,
	-- because `resolve_candidates` already prefers an exact basename over every
	-- other same-timestamp match. With the glob set derived from `candidates`
	-- above, an existing exact target is always among the matches, so returning
	-- it here returns exactly what the glob would have chosen.
	--
	-- It is here for cost, and the cost is real (#224 BR-15). Globbing every
	-- chat root on every resolve changed the common case — a reference whose
	-- parent has not been renamed, which is most of them — from a `filereadable`
	-- to O(files in the roots): measured 0.033 ms → 2.49 ms at one root of 2000
	-- files, 0.041 ms → 7.69 ms at three. `<M-t>` resolves once per branch.
	for _, candidate in ipairs(candidates) do
		if vim.fn.filereadable(candidate) == 1 then
			return vim.fn.resolve(candidate)
		end
	end

	if ts then
		local pattern = chat_slug.glob_pattern(ts)
		-- The glob set is EVERY directory the candidate list can point into,
		-- derived from `candidates` rather than named one at a time, so it
		-- cannot go stale when `_resolve_chat_path_candidates` gains a source.
		-- A missing directory means a renamed target there loses to an
		-- unrelated same-timestamp file elsewhere — silently, because a single
		-- non-exact hit makes `resolve_candidates` report no ambiguity. That is
		-- the sharp form of the rule: **one non-exact glob hit is not evidence
		-- the reference is stale; it can mean the reference's own directory was
		-- never searched.** (#224 BR-1 named absolute paths and was fixed with
		-- `candidates[1]` alone — the instance; BR-14 was `sub/<ts>.md` under a
		-- second root, the class.)
		--
		-- Deduplicated by RESOLVED path, not by the caller's spelling:
		-- `base_dir` arrives as the referring file's directory (often `/tmp/…`)
		-- while `get_chat_dirs()` returns it resolved (`/private/tmp/…` on
		-- macOS), so a naive skip globs the same directory twice and every hit
		-- then looks like a collision.
		-- Candidate directories FIRST, because search order is the tie-break
		-- for non-exact matches (see chat_slug.resolve_candidates). They are
		-- where the reference actually points; `base_dir` is only where it was
		-- written from. For a bare basename the two coincide (candidates[1] is
		-- base_dir/<name>); for `sub/<ts>.md` they do not, and leading with
		-- base_dir resolves a renamed target to whatever sits at the root.
		local seen_dir, search_dirs = {}, {}
		local dirs = {}
		for _, c in ipairs(candidates) do
			dirs[#dirs + 1] = vim.fn.fnamemodify(c, ":h")
		end
		dirs[#dirs + 1] = base_dir
		vim.list_extend(dirs, M.get_chat_dirs() or {})
		for _, d in ipairs(dirs) do
			-- resolve_dir_key owns the canonical-directory-key spelling (:68).
			-- Hand-rolling a second one is how two "same directory?" answers
			-- drift apart.
			local key = resolve_dir_key(d)
			if not seen_dir[key] then
				seen_dir[key] = true
				search_dirs[#search_dirs + 1] = d
			end
		end
		-- Built in SEARCH ORDER (reference's own directories first), because
		-- that order is resolve_candidates' tie-break for non-exact matches.
		-- Sorted WITHIN each directory so filesystem order never leaks in.
		local seen, matched = {}, {}
		for _, dir in ipairs(search_dirs) do
			-- safe_glob, not glob: `dir` is a chat root but the slug pattern is
			-- derived from a transcript filename (#225 round 3 C2).
			local here = {}
			for _, m in ipairs(M.helpers.safe_glob(dir .. "/" .. pattern, false, true) or {}) do
				-- The glob is a prefix match, so `…001*` also catches `…0012`.
				-- Verify the parsed timestamp is equal, not merely a prefix.
				local key = vim.fn.resolve(m)
				if not seen[key] and chat_slug.parse_filename(vim.fn.fnamemodify(m, ":t")) == ts then
					seen[key] = true
					here[#here + 1] = m
				end
			end
			table.sort(here)
			vim.list_extend(matched, here)
		end
		local ordered, ambiguous = chat_slug.resolve_candidates(basename, matched)
		if ambiguous then
			M.logger.warning(
				("chat reference %s matches %d files with the same timestamp; using %s")
					:format(basename, #ordered, vim.fn.fnamemodify(ordered[1], ":t")))
		end
		if ordered[1] then
			-- RESOLVED, always. The glob echoes back whatever spelling the
			-- caller's base_dir used (`/tmp/…` vs `/private/tmp/…` on macOS),
			-- and the second consumer site compares this result against
			-- `vim.fn.resolve(current_file)` for equality. An unresolved return
			-- makes that comparison fail, `branch_after` stays 0, and the
			-- parent is truncated to nothing — the same symptom as not
			-- resolving at all, from the opposite cause.
			return vim.fn.resolve(ordered[1])
		end
	end

	-- No timestamp to glob, or the glob found nothing. The existence check
	-- already ran at the top as the short-circuit, and nothing since has
	-- touched `candidates` or the filesystem — so repeating it here was dead
	-- code, byte-identical and unreachable (close review round 3).
	return candidates[1] and vim.fn.resolve(candidates[1]) or candidates[1]
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
--- Try to open an inline `[🌿:anchor](file)` link under the cursor.
---@return "opened"|"failed"|nil # nil when the cursor is not inside one
local function try_open_inline_branch_link(current_line, cursor_col, parent_buf)
	local branch_prefix = M.config.chat_branch_prefix or "🌿:"
	local chat_parser = require("parley.chat_parser")
	local inline_links = chat_parser.extract_inline_branch_links(current_line, branch_prefix)
	for _, link in ipairs(inline_links) do
		-- cursor_col is 0-indexed, col_start/col_end are 1-indexed
		if cursor_col + 1 >= link.col_start and cursor_col + 1 <= link.col_end then
			local referring = vim.api.nvim_buf_get_name(parent_buf)
			local current_dir = vim.fn.fnamemodify(referring, ":p:h")
			local expanded = resolve_chat_path(link.path, current_dir)
			if vim.fn.filereadable(expanded) == 1 then
				M.open_buf(expanded)
				return "opened"
			elseif expanded:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
				-- Same wording, same owner (#214 M3): this built `what is "X"`
				-- inline, so the phrase lived in two places and the two branch
				-- paths seeded their children differently.
				local br_submit = require("parley.branch_submit")
				local topic = link.topic ~= "" and link.topic or "?"
				M.create_child_chat(expanded, topic, parent_buf,
					link.topic ~= "" and br_submit.seed_question("define", link.topic) or nil)
				M.open_buf(expanded)
				return "opened"
			else
				M.logger.warning("Chat file not found: " .. expanded)
				return "failed"
			end
		end
	end
	return nil
end

-- Walk parent_link chain to find the tree root file path.
local function find_tree_root_file(file_path, depth)
	depth = depth or 0
	if depth > 20 then return file_path end
	local abs_path = M.helpers.abs_path(file_path)
	if vim.fn.filereadable(abs_path) == 0 then return abs_path end
	local lines = vim.fn.readfile(abs_path)
	local header_end = M.chat_parser.find_header_end(lines)
	if not header_end then return abs_path end
	local parsed = M.chat_parser.parse_chat(lines, header_end, M.config)
	if not parsed.parent_link then return abs_path end
	local parent_dir = vim.fn.fnamemodify(abs_path, ":h")
	local parent_abs = resolve_chat_path(parsed.parent_link.path, parent_dir)
	if vim.fn.filereadable(parent_abs) == 0 then return abs_path end
	return find_tree_root_file(parent_abs, depth + 1)
end

-- Collect all file paths in a chat tree (root + all descendants via branches).
local function collect_tree_files(file_path, visited)
	visited = visited or {}
	local abs_path = M.helpers.abs_path(file_path)
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
		local child_abs = resolve_chat_path(branch.path, file_dir)
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

	-- #231: the operator consents to what the prompt names — every assets
	-- folder the tree owns is listed with the files.
	local assets = require("parley.assets")
	local folders = {}
	for _, f in ipairs(tree_files) do
		local folder = assets.folder_for(f)
		if folder and vim.fn.isdirectory(folder) == 1 then
			folders[#folders + 1] = folder
		end
	end
	local root_rel = vim.fn.fnamemodify(root, ":~:.")
	local msg = "Delete " .. #tree_files .. " chat file(s) in tree rooted at " .. root_rel
		.. (#folders > 0 and (" and " .. #folders .. " assets folder(s)") or "") .. "?\n\n"
	for _, f in ipairs(tree_files) do
		msg = msg .. "  " .. vim.fn.fnamemodify(f, ":~:.") .. "\n"
	end
	for _, d in ipairs(folders) do
		msg = msg .. "  " .. vim.fn.fnamemodify(d, ":~:.") .. "/\n"
	end
	local choice = vim.fn.confirm(msg, "&Yes\n&No", 2)
	if choice == 1 then
		for _, f in ipairs(tree_files) do
			M.delete_chat_file(f)
		end
	end
end

-- #231: THE door for deleting a chat file — assets/<ts>/ goes with it.
-- delete_with is a no-op for a non-timestamp name, so every caller is safe;
-- a folder that cannot be removed is reported (never assumed gone) and the
-- file is still deleted. tests/arch/chat_delete_sweep_spec.lua allows exactly
-- one helpers.delete_file call under lua/parley/**: this one.
M.delete_chat_file = function(path)
	local ok, err = require("parley.assets").delete_with(path)
	if not ok then
		vim.notify("Deleted " .. path .. " but " .. tostring(err), vim.log.levels.WARN)
	end
	M.helpers.delete_file(path)
end

-- #231: paste the clipboard image as an attachment of the chat in `buf`.
-- `deps` is for specs (a recording notify, a fake runner); the key passes nothing.
M.paste_image = function(buf, deps)
	deps = deps or {}
	require("parley.paste_image").paste(buf, {
		config = M.config,
		notify = deps.notify or function(msg, level)
			vim.notify(msg, vim.log.levels[level:upper()] or vim.log.levels.INFO)
		end,
		runner = deps.runner,
	})
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

	-- #231: refuse an assets clash BEFORE any .md moves — the same rule
	-- move_with applies, checked for every file so a refusal moves nothing.
	local assets = require("parley.assets")
	for _, src in ipairs(tree_files) do
		local src_folder, clash = assets.move_conflict(src, target_root)
		if not src_folder and clash then
			return nil, clash
		end
	end
	local asset_errors = {}

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

		-- The .md move stays done: a folder that fails to follow is collected
		-- and reported after the state refresh and the 🌿 rewrite complete.
		local carried, aerr = assets.move_with(src, path_map[src])
		if not carried then
			asset_errors[#asset_errors + 1] = tostring(aerr)
		end

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
								lines[i] = require("parley.branch_ref").format_ref_line(branch_prefix, new_rel, topic)
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

	if #asset_errors > 0 then
		return nil, "moved the tree but not every assets folder: " .. table.concat(asset_errors, "; ")
	end

	-- Return the new path of the originally requested file
	local resolved_file = M.helpers.abs_path(file_name)
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
		recall_key = "parley.move_chat_to",
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
		["{{respond_shortcut}}"] = key_hint("chat_respond", "ChatRespond"),
		["{{cmd_prefix}}"] = M.config.cmd_prefix,
		["{{stop_shortcut}}"] = key_hint("chat_stop", "ChatStop"),
		["{{delete_shortcut}}"] = key_hint("chat_delete", "ChatDelete"),
		["{{new_shortcut}}"] = key_hint("chat_new", "ChatNew"),
	})

	-- escape underscores (for markdown)
	template = template:gsub("_", "\\_")

	-- If an initial question is provided, append it after the user prefix
	-- (done after underscore escaping so file paths in @@references stay intact)
	if initial_question then
		-- Function replacement: `initial_question` is runtime text, and in LuaJIT
		-- a `%` in a gsub REPLACEMENT does not raise — it silently corrupts.
		-- "50% off" becomes "50 off" and "100%" writes a NUL byte into the file
		-- (#214 BR-34, ARCH-SECURE).
		template = template:gsub(
			M.config.chat_user_prefix .. "%s*$",
			function() return M.config.chat_user_prefix .. " " .. initial_question end
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
	view_mode = 0, -- 0=issues (default, done visible), 1=history (#158)
	initial_index = nil,
	initial_value = nil,
	query = nil, -- Complete prompt query preserved across invocations
	repo_facet_state = nil, -- Shared repo facet choices across issues/history and invocations
}

M._vision_finder = {
	opened = false,
	initial_index = nil,
	initial_value = nil,
	sticky_query = nil, -- Preserved {repo} filter across invocations
}

M._markdown_finder = {
	query = nil,
	directory_facet_state = nil,
	repo_facet_state = nil,
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
		M.delete_chat_file(file_name)
		return
	end

	-- ask for confirmation; the prompt names the assets folder it removes (#231)
	local note = require("parley.assets").removal_note(file_name)
	vim.ui.input({ prompt = "Delete " .. file_name .. note .. "? [y/N] " }, function(input)
		if input and input:lower() == "y" then
			M.delete_chat_file(file_name)
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
	table.insert(child_lines, require("parley.branch_ref").format_ref_line(branch_prefix, parent_rel, parent_topic))
	table.insert(child_lines, "")

	-- Append the pruned exchanges
	for _, l in ipairs(pruned_lines) do
		table.insert(child_lines, l)
	end

	-- Write child file
	M.helpers.prepare_dir(vim.fn.fnamemodify(new_file, ":h"))
	vim.fn.writefile(child_lines, new_file)

	-- Replace pruned lines in parent with a branch reference + fresh question starter
	local branch_line = require("parley.branch_ref").format_ref_line(branch_prefix, rel_child, "")
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
		chat_respond.generate_topic(topic_msgs, agent_info.provider, agent_info.model, function(topic, _reason)
			if not topic then return end
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
						local updated = require("parley.branch_ref").format_ref_line(branch_prefix, rel_child, topic)
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
	-- Stop insert before opening the picker — the outline takes over UI focus,
	-- so leaving the buffer in insert mode would strand the cursor on return.
	-- No-op outside insert mode.
	vim.cmd("stopinsert")

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
--- Open a `🌿:` reference line.
---@return "opened"|"failed"|nil # nil when the line is not a 🌿: reference
local function open_branch_ref(current_line, buf)
	local parsed = M._parse_branch_ref(current_line)
	if parsed == nil then
		return nil
	end

	local referring = vim.api.nvim_buf_get_name(buf)
	local current_dir = vim.fn.fnamemodify(referring, ":p:h")
	local expanded = resolve_chat_path(parsed.path, current_dir)

	if vim.fn.filereadable(expanded) == 1 then
		M.open_buf(expanded)
		return "opened"
	end

	-- Chat file doesn't exist yet — create it if it looks like a chat timestamp
	if expanded:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
		local topic = parsed.topic ~= "" and parsed.topic or "New chat"

		-- Place new file in default chat_dir (not relative to source file)
		local chat_file = M.config.chat_dir .. "/" .. vim.fn.fnamemodify(expanded, ":t")
		M.helpers.prepare_dir(vim.fn.fnamemodify(chat_file, ":h"))

		local agent = M.get_agent()
		local template = M.get_default_template(agent, chat_file)
		template = template:gsub("{{topic}}", function() return topic end)
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
		return "opened"
	end

	M.logger.warning("Chat file not found: " .. expanded)
	return "failed"
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

--- Try to open a src: markdown link under cursor_col (0-indexed).
---@return "opened"|"failed"|nil # nil when there is no src: link here
local try_open_src_link = function(line, cursor_col, buf)
	local link = issues_mod.parse_md_link_at_cursor(line, cursor_col + 1)
	if not link then return nil end
	local src_path = issues_mod.parse_src_url(link.url)
	if not src_path then return nil end
	local buf_file = vim.api.nvim_buf_get_name(buf)
	local abs_path = resolve_src_link(src_path, buf_file)
	if not abs_path then
		M.logger.warning("src: link: no git root found and src_root not configured")
		return "failed"
	end
	abs_path = vim.fn.simplify(abs_path)
	if vim.fn.filereadable(abs_path) == 1 or vim.fn.isdirectory(abs_path) == 1 then
		M.open_buf(abs_path)
		return "opened"
	end
	M.logger.warning("src: link target not found: " .. abs_path)
	return "failed"
end

--- Open whatever reference sits under the cursor.
---
--- One chain for chat buffers and markdown buffers alike (#225). They used to
--- be two, and two meant divergent: `src:` links, the `@@path: topic` form and
--- bare-name chat-root resolution worked only in markdown, while a directory
--- reference opened in netrw only in chat. The first three were omissions and
--- are now the union. The fourth is a real policy difference, so it stays,
--- behind `is_chat` — collapsing it away would have silently deleted a feature.
---
--- Three-valued, because letting the caller fall through to `gf` promotes
--- exits that used to be discarded, and they do not mean the same thing:
---   "opened" — a reference was recognised and acted on.
---   "none"   — nothing here looks like a reference; fall through to `gf`.
---   "failed" — a reference was recognised and could not be opened. The
---              diagnostic is already reported and the caller must NOT fall
---              through: `gf` would re-fail on a path we already know is
---              absent, trading a precise message for a vague one.
---
---@param buf integer
---@param current_line string|nil
---@param cursor_col integer # 0-indexed
---@param is_chat boolean # directory references open in netrw only when true
---@return "opened"|"none"|"failed"
local function open_reference_under_cursor(buf, current_line, cursor_col, is_chat)
	if not current_line then
		return "none"
	end

	-- Link forms that carry their own target. Each reports its own failure, so
	-- a non-nil answer is terminal either way.
	local handled = try_open_src_link(current_line, cursor_col, buf)
		or try_open_inline_branch_link(current_line, cursor_col, buf)
		or open_branch_ref(current_line, buf)
	if handled then
		return handled
	end

	-- @@ references: accept every form either chain used to accept.
	local ref_path
	if current_line:match("^@@") then
		-- A line that is ENTIRELY one reference is taken greedily, so a path
		-- containing an `@` survives (`@@/tmp/a@b/c.md@@`). Chat used to be
		-- greedy and markdown did not; adopting markdown's `[^@]+` wholesale
		-- was a fifth divergence resolved the wrong way, silently (#225 review).
		-- The `not whole:find("@@")` guard keeps it from swallowing a line that
		-- carries two references.
		local whole = current_line:match("^@@(.+)@@$")
		if whole and not whole:find("@@", 1, true) then
			ref_path = whole
		else
			ref_path = current_line:match("^@@%s*([^@]+)@@")
				or current_line:match("^@@%s*([^:]+):")
				or current_line:match("^@@(.+)$")
		end
		ref_path = ref_path and ref_path:gsub("^%s*(.-)%s*$", "%1")
	else
		ref_path = M._parse_at_reference(current_line, cursor_col)
	end
	if not ref_path or ref_path == "" then
		-- Not a reference. Silent by design: the caller falls through to `gf`,
		-- and warning about @@ syntax on every ordinary word would be noise.
		return "none"
	end

	-- `ref_path` is transcript text and vim.fn.expand() runs backticks, so this
	-- is the sink an @@`cmd`@@ line reaches. "failed", not "none": the cursor
	-- IS on a reference, we are refusing it, and falling through would hide
	-- that behind gf.
	local expanded_path = M.helpers.expand_path(ref_path)
	if not expanded_path then
		M.logger.warning("Refusing a reference whose path contains a backtick: " .. ref_path)
		return "failed"
	end

	-- Directory references — netrw, preferring the other split. Chat buffers
	-- only, and checked before chat-root resolution, which searches for files.
	if
		is_chat
		and (
			M.helpers.is_directory(expanded_path)
			or ref_path:match("/$")
			or ref_path:match("/%*%*?/?")
			or ref_path:match("/%*%.%w+$")
		)
	then
		local base_dir = M.helpers.glob_base(ref_path)
		local dir_path = M.helpers.expand_path(base_dir)
		if not dir_path or vim.fn.isdirectory(dir_path) == 0 then
			M.logger.warning("Directory not found: " .. (dir_path or base_dir))
			return "failed"
		end
		M.logger.info("Opening directory: " .. dir_path)
		focus_other_split(dir_path)
		vim.cmd("Explore " .. vim.fn.fnameescape(dir_path))
		return "opened"
	end

	-- A bare or relative name is looked up in the chat roots, timestamp-first,
	-- so a renamed slug still resolves.
	if expanded_path:sub(1, 1) ~= "/" then
		local current_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p:h")
		expanded_path = resolve_chat_path(expanded_path, current_dir)
	end

	if vim.fn.filereadable(expanded_path) == 1 then
		M.logger.info("Opening file: " .. expanded_path)
		M.open_buf(expanded_path)
		return "opened"
	end

	-- A missing target that names a chat timestamp is a forward reference:
	-- create the chat rather than complain about it.
	if expanded_path:match("%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d+%.md$") then
		M.logger.info("Creating new chat file: " .. expanded_path)
		M.helpers.prepare_dir(vim.fn.fnamemodify(expanded_path, ":h"))
		local topic = current_line:match("@@[^:]+:%s*(.+)") or "New chat"
		local template = M.get_default_template(M.get_agent(), expanded_path)
		template = template:gsub("{{topic}}", function() return topic end)
		vim.fn.writefile(vim.split(template, "\n"), expanded_path)
		M.open_buf(expanded_path)
		return "opened"
	end

	M.logger.warning("File not found: " .. expanded_path)
	return "failed"
end
M._open_reference_under_cursor = open_reference_under_cursor

-- Copy commands (delegated to parley.copy module)
local copy_mod = require("parley.copy")
M.cmd.CopyCodeFence = copy_mod.copy_code_fence
M.cmd.CopyLocation = copy_mod.copy_location
M.cmd.CopyLocationContent = copy_mod.copy_location_content
M.cmd.CopyContext = function() copy_mod.copy_context(2, 2) end
M.cmd.CopyContextWide = function() copy_mod.copy_context(5, 10) end

-- Open the reference under the cursor, falling back to `gf` (#225). One key
-- for "go to the thing I am looking at", in chat and markdown buffers alike.
M.cmd.OpenFileUnderCursor = function()
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)
	local cursor_pos = vim.api.nvim_win_get_cursor(0)
	local current_line = vim.api.nvim_buf_get_lines(buf, cursor_pos[1] - 1, cursor_pos[1], false)[1]
	local cursor_col = cursor_pos[2]

	local mode = vim.api.nvim_get_mode().mode
	local in_insert_mode = (mode:match("^i") or mode:match("^R")) ~= nil

	local is_chat = M.not_chat(buf, file_name) == nil
	if not is_chat and not M.is_markdown(buf, file_name) then
		M.logger.warning("OpenFileUnderCursor command is only available in chat files and markdown files")
		return
	end

	local outcome = open_reference_under_cursor(buf, current_line, cursor_col, is_chat)

	if outcome == "none" then
		-- Nothing here is a parley reference, so hand it to the general
		-- "go to what's under the cursor" — an ariadne artifact ref if it
		-- resolves, otherwise native gf. Its destinations are source you went
		-- to READ, so unlike a chat reference this one lands in normal mode.
		if in_insert_mode then
			vim.cmd("stopinsert")
		end
		M.cmd.ResolveRefOrGotoFile()
		return
	end

	-- A chat reference is somewhere you went to WRITE, so insert is restored.
	-- Also on "failed", where the cursor has not moved at all.
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
	sticky_query_initialized = false, -- One-shot guard: chat_finder.M.open seeds the default {repo} filter on first open in repo mode
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

-- #160: smart `gf` — resolve the ariadne artifact ref under the cursor (via
-- `sdlc resolve`; family picker when it resolves to many), else fall back to Vim's
-- native go-to-file (`normal! gf` bypasses this mapping), so `gf` keeps working on
-- plain paths.
M.cmd.ResolveRefOrGotoFile = function()
	require("parley.artifact_ref").goto_ref_at_cursor({
		on_no_ref = function() vim.cmd("normal! gf") end,
	})
end

-- ariadne#171 M4: project jump — resolve the issue ref under the cursor to the
-- PROJECT record(s) referencing it, fleet-wide and archive-inclusive (`sdlc
-- resolve --kind project`). A project is an always-cross-repo artifact class:
-- the record may live in a different repo than the issue, so this never
-- assumes a local path.
M.cmd.ResolveRefProject = function()
	require("parley.artifact_ref").goto_ref_at_cursor({ kind = "project" })
end

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

-- Issue #117 M1: freeform chat-root commands disabled. The
-- corresponding handlers (cmd_chat_dirs / cmd_chat_dir_add /
-- cmd_chat_dir_remove) and the underlying mutators (add_chat_dir /
-- remove_chat_dir / rename_chat_dir in root_dirs.lua) are kept in
-- place for one release as a rollback safety net but are not wired to
-- any user command or keybinding. They will be deleted in M2.
M.cmd.ChatMove = function(p) chat_dirs.cmd_chat_move(p) end

M.cmd.NoteDirs = function(p) note_dirs.cmd_note_dirs(p) end
M.cmd.NoteDirAdd = function(p) note_dirs.cmd_note_dir_add(p) end
M.cmd.NoteDirRemove = function(p) note_dirs.cmd_note_dir_remove(p) end

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

--- Register a live cliproxy catalog model as a session agent and select it.
---
--- Persisted as `_state.live_agent` so the choice survives a restart: without
--- the matching restore in refresh_state, the guard there would find the name
--- missing from M.agents and silently reset to the first configured agent.
---@param model table # a parsed catalog row { id, owner, display, … }
M.register_live_agent = function(model)
	local agent = require("parley.cliproxy_catalog").build_agent(model)
	if not adopt_agent(agent) then
		M.logger.warning("cliproxy: catalog row has no usable model id; not registering")
		return
	end
	M.refresh_state({ agent = agent.name, live_agent = model })
	M.logger.info("Agent set to: " .. agent.name)
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
		-- Falling back to _state.agent is a no-op when _state.agent IS the
		-- missing name — which is exactly what happens when an agent you had
		-- selected stops shipping (you edit it out of your config, or a default
		-- roster changes under a persisted selection). That path used to
		-- dereference nil one line below and crash the whole request.
		local fallback = M.agents[M._state.agent] and M._state.agent or M._agents[1]
		M.logger.warning("Agent " .. tostring(name) .. " not found, using " .. tostring(fallback))
		name = fallback
	end
	local template = M.config.command_prompt_prefix_template
	local cmd_prefix = M.render.template(template, { ["{{agent}}"] = name })
	local agent_rec = M.agents[name]
	if agent_rec == nil then
		-- No agents at all. `error` here reaches the user as a stack trace over
		-- whatever they were doing; the message has to carry the next action on
		-- its own, since nothing downstream will add one.
		error("parley: no agents are configured. Add at least one to the `agents` "
			.. "list in your setup{}, or remove `agents = {}` if you meant to keep "
			.. "the defaults.")
	end
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
		-- Issue #118: forward synthetic-system-prompt config too. Same
		-- sanitized-snapshot pitfall as the tools field above — leaving
		-- these out silently drops them before agent_info.resolve sees them.
		synthetic_system_prompt = agent_rec.synthetic_system_prompt,
		synthetic_system_prompt_ack = agent_rec.synthetic_system_prompt_ack,
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
	local respond_shortcut = key_hint("chat_respond", "ChatRespond")
	local stop_shortcut = key_hint("chat_stop", "ChatStop")
	local delete_shortcut = key_hint("chat_delete", "ChatDelete")
	local new_shortcut = key_hint("chat_new", "ChatNew")

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
	-- Function replacement, not string concat: a topic is user-selected text, and
	-- gsub treats `%` in a REPLACEMENT specially — `what is "50% off"` raises
	-- "invalid use of '%'", and a topic containing %1 silently substitutes a
	-- capture (#214 BR-21, ARCH-SECURE).
	template = template:gsub("topic: %?", function() return "topic: " .. topic end)
	local file_lines = vim.split(template, "\n")

	local chat_parser = require("parley.chat_parser")
	local header_end = chat_parser.find_header_end(file_lines)
	if header_end then
		local branch_prefix = M.config.chat_branch_prefix or "🌿:"
		local parent_path = vim.api.nvim_buf_get_name(parent_buf)
		local parent_rel = vim.fn.fnamemodify(parent_path, ":t")
		local parent_topic = M.get_chat_topic(parent_path) or ""
		-- A basename only resolves for a CHAT parent: resolve_chat_path searches
		-- the chat roots and then falls back to globbing a parseable timestamp.
		-- Branching from an arbitrary markdown file (`notes.md`) produced a
		-- back-link the child could never follow — pre-existing for the visual
		-- path, and reachable from the primary branch key once the n/i path
		-- started creating children too (#214 BR-10). Fall back to the absolute
		-- path, which resolve_chat_path handles directly.
		local parent_ref = chat_slug.parse_filename(parent_rel) and parent_rel
			or vim.fn.fnamemodify(parent_path, ":p")
		local back_link = require("parley.branch_ref").format_ref_line(branch_prefix, parent_ref, parent_topic)
		table.insert(file_lines, header_end + 1, back_link)

		if question then
			local user_prefix = M.config.chat_user_prefix or "💬:"
			-- One LINE per list element. `writefile` encodes a \n INSIDE an
			-- element as a NUL byte, so a multi-line question — the gathered
			-- <M-q> quote blocks are inherently multi-line — landed on disk as
			-- `> [abstractions]^@^@what's this`, a corrupt transcript (#214 M3).
			--
			-- A single-line question stays inline after the prefix; a multi-line
			-- one puts `💬:` on its own line and the body beneath, which is
			-- exactly how chat_respond writes a gathered drill-in turn
			-- (chat_respond.lua: `insert_lines = { "", user_prefix }` then the
			-- block lines). The chord's promise is that the two agree.
			local body = vim.split(question, "\n", { plain = true })
			local turn = #body == 1 and { user_prefix .. " " .. body[1] } or { user_prefix }
			if #body > 1 then
				for _, line in ipairs(body) do turn[#turn + 1] = line end
			end

			local at = header_end + 2
			table.insert(file_lines, at, "")
			for i, line in ipairs(turn) do
				table.insert(file_lines, at + i, line)
			end
			-- Only if the template does not already open with one. It does, so
			-- adding a second left every branched child with a double blank
			-- above its trailing `💬:` prompt.
			local follows = file_lines[at + #turn + 1]
			if follows and follows:match("%S") then
				table.insert(file_lines, at + #turn + 1, "")
			end
		end
	end

	-- `writefile` encodes a \n INSIDE an element as a NUL byte rather than
	-- rejecting it, so a caller that hands it a multi-line string silently writes
	-- a corrupt file. Flatten defensively: the cost is one pass, and the failure
	-- it prevents is invisible until someone reads the file outside Vim (readfile
	-- turns the NUL back into \n, so a round-trip test cannot see it either).
	vim.fn.writefile(M.helpers.flatten_lines(file_lines), file_path)
end

-- Agent info resolution (delegated to parley.agent_info module)
local agent_info_mod = require("parley.agent_info")
M.get_agent_info = function(headers, agent)
	return agent_info_mod.resolve(headers, agent, M._state, M.system_prompts, memory_prefs, M.logger)
end

return M
