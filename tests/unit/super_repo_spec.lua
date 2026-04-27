local parley = require("parley")
local super_repo = require("parley.super_repo")
local issues_mod = require("parley.issues")

local function mkdir(path)
	vim.fn.mkdir(path, "p")
end

local function touch(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
	local fh = io.open(path, "w")
	if fh then fh:close() end
end

local function resolve(p)
	local out = vim.fn.resolve(vim.fn.expand(p)):gsub("/+$", "")
	return out
end

local function names(members)
	local out = {}
	for _, m in ipairs(members) do
		table.insert(out, m.name)
	end
	return out
end

local function dirs(roots)
	local out = {}
	for _, r in ipairs(roots) do
		table.insert(out, resolve(r.dir))
	end
	return out
end

describe("super_repo.compute_members", function()
	local base_dir

	before_each(function()
		base_dir = vim.fn.tempname() .. "-parley-super-repo-compute"
	end)

	after_each(function()
		if base_dir then vim.fn.delete(base_dir, "rf") end
	end)

	it("discovers sibling .parley repos sorted by name", function()
		mkdir(base_dir .. "/workspace")
		touch(base_dir .. "/workspace/brain/.parley")
		touch(base_dir .. "/workspace/charon/.parley")
		touch(base_dir .. "/workspace/ariadne/.parley")
		mkdir(base_dir .. "/workspace/diary") -- no marker

		local result = assert(super_repo.compute_members(base_dir .. "/workspace/charon"))
		assert.equal(resolve(base_dir .. "/workspace"), result.workspace_root)
		assert.same({ "ariadne", "brain", "charon" }, names(result.members))
	end)

	it("returns the current repo as one of the members (writes still go there)", function()
		mkdir(base_dir .. "/workspace")
		touch(base_dir .. "/workspace/parley.nvim/.parley")
		touch(base_dir .. "/workspace/brain/.parley")

		local result = assert(super_repo.compute_members(base_dir .. "/workspace/parley.nvim"))
		assert.same({ "brain", "parley.nvim" }, names(result.members))
	end)

	it("returns empty members list when no siblings have .parley", function()
		mkdir(base_dir .. "/workspace")
		touch(base_dir .. "/workspace/solo/.parley")
		mkdir(base_dir .. "/workspace/d") -- no marker

		local result = assert(super_repo.compute_members(base_dir .. "/workspace/solo"))
		assert.same({ "solo" }, names(result.members))
	end)

	it("returns nil + err for empty input", function()
		local result, err = super_repo.compute_members("")
		assert.is_nil(result)
		assert.is_string(err)
	end)

	it("returns nil + err for non-string input", function()
		local result, err = super_repo.compute_members(nil)
		assert.is_nil(result)
		assert.is_string(err)
	end)
end)

describe("super_repo.toggle", function()
	local base_dir
	local workspace
	local current_repo
	local sibling_a
	local sibling_b
	local primary_chat
	local primary_note
	local state_dir

	before_each(function()
		base_dir = vim.fn.tempname() .. "-parley-super-repo-toggle"
		workspace = base_dir .. "/workspace"
		current_repo = workspace .. "/parley.nvim"
		sibling_a = workspace .. "/ariadne"
		sibling_b = workspace .. "/brain"
		primary_chat = base_dir .. "/global-chat"
		primary_note = base_dir .. "/global-note"
		state_dir = base_dir .. "/state"

		mkdir(workspace)
		touch(current_repo .. "/.parley")
		touch(sibling_a .. "/.parley")
		touch(sibling_b .. "/.parley")
		mkdir(workspace .. "/no-marker") -- ignored

		parley._state = {}
		-- Pass chat_dir explicitly to bypass apply_repo_local's marker auto-detection
		-- (we don't want it picking up the cwd of the test runner). We then set
		-- repo_root manually to simulate plain repo mode being active.
		parley.setup({
			chat_dir = primary_chat,
			notes_dir = primary_note,
			state_dir = state_dir,
			providers = {},
			api_keys = {},
		})
		parley.config.repo_root = current_repo
		parley.config.repo_chat_dir = "workshop/parley"
		parley.config.repo_note_dir = "workshop/notes"
	end)

	after_each(function()
		-- Ensure deactivated for next test
		if parley.is_super_repo_active() then
			parley.toggle_super_repo()
		end
		if base_dir then vim.fn.delete(base_dir, "rf") end
	end)

	it("activates and adds sibling chat & note roots", function()
		assert.is_false(parley.is_super_repo_active())
		local chat_before = vim.deepcopy(parley.get_chat_roots())
		local note_before = vim.deepcopy(parley.get_note_roots())

		assert.is_true(parley.toggle_super_repo())
		assert.is_true(parley.is_super_repo_active())

		local chat_after = parley.get_chat_roots()
		local note_after = parley.get_note_roots()
		assert.equal(#chat_before + 2, #chat_after) -- ariadne + brain (parley.nvim is current repo, excluded)
		assert.equal(#note_before + 2, #note_after)

		local chat_dirs_after = dirs(chat_after)
		assert.is_true(vim.tbl_contains(chat_dirs_after, resolve(sibling_a .. "/workshop/parley")))
		assert.is_true(vim.tbl_contains(chat_dirs_after, resolve(sibling_b .. "/workshop/parley")))

		local note_dirs_after = dirs(note_after)
		assert.is_true(vim.tbl_contains(note_dirs_after, resolve(sibling_a .. "/workshop/notes")))
		assert.is_true(vim.tbl_contains(note_dirs_after, resolve(sibling_b .. "/workshop/notes")))
	end)

	it("labels pushed roots with the sibling repo name (so finder shows {ariadne} etc.)", function()
		parley.toggle_super_repo()

		local pushed_chat = vim.tbl_filter(function(r)
			return resolve(r.dir) == resolve(sibling_a .. "/workshop/parley")
		end, parley.get_chat_roots())
		assert.equal(1, #pushed_chat)
		assert.equal("ariadne", pushed_chat[1].label)

		local pushed_note = vim.tbl_filter(function(r)
			return resolve(r.dir) == resolve(sibling_b .. "/workshop/notes")
		end, parley.get_note_roots())
		assert.equal(1, #pushed_note)
		assert.equal("brain", pushed_note[1].label)
	end)

	it("exposes pushed dirs via get_pushed_*_dirs for the persistence gate", function()
		assert.same({}, parley.super_repo.get_pushed_chat_dirs())
		assert.same({}, parley.super_repo.get_pushed_note_dirs())

		parley.toggle_super_repo()

		local chat_pushed = parley.super_repo.get_pushed_chat_dirs()
		assert.is_true(vim.tbl_contains(chat_pushed, resolve(sibling_a .. "/workshop/parley")))
		assert.is_true(vim.tbl_contains(chat_pushed, resolve(sibling_b .. "/workshop/parley")))

		local note_pushed = parley.super_repo.get_pushed_note_dirs()
		assert.is_true(vim.tbl_contains(note_pushed, resolve(sibling_a .. "/workshop/notes")))
		assert.is_true(vim.tbl_contains(note_pushed, resolve(sibling_b .. "/workshop/notes")))

		parley.toggle_super_repo()
		assert.same({}, parley.super_repo.get_pushed_chat_dirs())
		assert.same({}, parley.super_repo.get_pushed_note_dirs())
	end)

	it("sets super_repo_root and super_repo_members on config", function()
		parley.toggle_super_repo()
		assert.equal(resolve(workspace), parley.config.super_repo_root)
		assert.same({ "ariadne", "brain", "parley.nvim" }, names(parley.config.super_repo_members))
	end)

	it("toggle off restores prior chat & note roots", function()
		local chat_before = vim.deepcopy(parley.get_chat_roots())
		local note_before = vim.deepcopy(parley.get_note_roots())

		parley.toggle_super_repo()
		assert.is_true(parley.is_super_repo_active())
		parley.toggle_super_repo()

		assert.is_false(parley.is_super_repo_active())
		assert.same(dirs(chat_before), dirs(parley.get_chat_roots()))
		assert.same(dirs(note_before), dirs(parley.get_note_roots()))
		assert.is_nil(parley.config.super_repo_root)
		assert.is_nil(parley.config.super_repo_members)
	end)

	it("does not modify write paths (chat_dir / notes_dir / repo_root unchanged)", function()
		local chat_dir_before = parley.config.chat_dir
		local notes_dir_before = parley.config.notes_dir
		local repo_root_before = parley.config.repo_root

		parley.toggle_super_repo()
		assert.equal(chat_dir_before, parley.config.chat_dir)
		assert.equal(notes_dir_before, parley.config.notes_dir)
		assert.equal(repo_root_before, parley.config.repo_root)

		parley.toggle_super_repo()
		assert.equal(chat_dir_before, parley.config.chat_dir)
		assert.equal(notes_dir_before, parley.config.notes_dir)
		assert.equal(repo_root_before, parley.config.repo_root)
	end)

	it("fails to activate when repo_root is unset", function()
		parley.config.repo_root = nil
		local chat_before = vim.deepcopy(parley.get_chat_roots())

		local ok = parley.toggle_super_repo()
		assert.is_false(ok)
		assert.is_false(parley.is_super_repo_active())
		assert.same(dirs(chat_before), dirs(parley.get_chat_roots()))
	end)

	it("markdown_finder._scan_members aggregates with <repo>/ prefix and repo_name tag", function()
		local md_finder = require("parley.markdown_finder")
		md_finder.setup(parley)

		-- Seed markdown files in two members.
		vim.fn.writefile({ "# foo" }, sibling_a .. "/notes.md")
		vim.fn.mkdir(sibling_a .. "/workshop", "p")
		vim.fn.writefile({ "# bar" }, sibling_a .. "/workshop/foo.md")
		vim.fn.writefile({ "# baz" }, sibling_b .. "/README.md")

		local members = {
			{ path = sibling_a, name = "ariadne" },
			{ path = sibling_b, name = "brain" },
		}
		local entries = md_finder._scan_members(members, 4)

		assert.is_true(#entries >= 3)
		local found_a_root, found_a_nested, found_b = false, false, false
		for _, e in ipairs(entries) do
			if e.display:match("^ariadne/notes%.md") then
				found_a_root = true
				assert.equal("ariadne", e.tag)
				assert.is_true(e.search_text:find("ariadne", 1, true) == 1)
			end
			if e.display:match("^ariadne/workshop/foo%.md") then
				found_a_nested = true
				assert.equal("ariadne", e.tag)
			end
			if e.display:match("^brain/README%.md") then
				found_b = true
				assert.equal("brain", e.tag)
			end
		end
		assert.is_true(found_a_root, "expected 'ariadne/notes.md' entry")
		assert.is_true(found_a_nested, "expected 'ariadne/workshop/foo.md' entry")
		assert.is_true(found_b, "expected 'brain/README.md' entry")
	end)

	it("scan_issues honours repo_name and history_dir_override (multi-root)", function()
		-- Seed an issue in sibling_a's issues dir, and a done one in sibling_b's history.
		local issues_a = sibling_a .. "/workshop/issues"
		local history_b = sibling_b .. "/workshop/history"
		mkdir(issues_a)
		mkdir(history_b)
		local issue_a = issues_a .. "/000007-foo.md"
		vim.fn.writefile({
			"---",
			"id: 000007",
			"status: open",
			"deps: []",
			"created: 2026-04-27",
			"updated: 2026-04-27",
			"---",
			"",
			"# foo",
		}, issue_a)
		local archived_b = history_b .. "/000003-bar.md"
		vim.fn.writefile({
			"---",
			"id: 000003",
			"status: done",
			"deps: []",
			"created: 2026-04-20",
			"updated: 2026-04-22",
			"---",
			"",
			"# bar",
		}, archived_b)

		local from_a = issues_mod.scan_issues(issues_a, { repo_name = "ariadne" })
		assert.equal(1, #from_a)
		assert.equal("ariadne", from_a[1].repo_name)
		assert.equal("000007", from_a[1].id)
		assert.is_false(from_a[1].archived)

		-- include_history with override picks up the archived issue.
		local from_b = issues_mod.scan_issues(sibling_b .. "/workshop/issues", {
			include_history = true,
			history_dir_override = history_b,
			repo_name = "brain",
		})
		assert.equal(1, #from_b)
		assert.equal("brain", from_b[1].repo_name)
		assert.equal("000003", from_b[1].id)
		assert.is_true(from_b[1].archived)

		-- Single-root, no repo_name: backwards-compat (no .repo_name field set).
		local from_a_plain = issues_mod.scan_issues(issues_a, {})
		assert.equal(1, #from_a_plain)
		assert.is_nil(from_a_plain[1].repo_name)
	end)

	it("expand_roots returns per-member abs paths when super-repo is active, nil otherwise", function()
		assert.is_nil(parley.super_repo.expand_roots("workshop/issues"))

		parley.toggle_super_repo()

		local roots = parley.super_repo.expand_roots("workshop/issues")
		assert.is_not_nil(roots)
		assert.equal(3, #roots) -- ariadne + brain + parley.nvim
		local by_name = {}
		for _, r in ipairs(roots) do by_name[r.repo_name] = r.dir end
		assert.equal(sibling_a .. "/workshop/issues", by_name["ariadne"])
		assert.equal(sibling_b .. "/workshop/issues", by_name["brain"])
		assert.equal(current_repo .. "/workshop/issues", by_name["parley.nvim"])

		-- Absolute subdir is left as-is for every member (uncommon, but supported).
		local abs = parley.super_repo.expand_roots("/abs/path")
		for _, r in ipairs(abs) do
			assert.equal("/abs/path", r.dir)
		end

		-- Empty / non-string subdir returns nil.
		assert.is_nil(parley.super_repo.expand_roots(""))
		assert.is_nil(parley.super_repo.expand_roots(nil))
	end)

	it("super-repo siblings are stripped from persisted state.json", function()
		parley.toggle_super_repo()

		-- Force a state writeback.
		parley.refresh_state({})

		local state_file = state_dir .. "/state.json"
		assert.equal(1, vim.fn.filereadable(state_file))
		local state = parley.helpers.file_to_table(state_file) or {}
		local persisted_chat_dirs = state.chat_dirs or {}
		local persisted_note_dirs = state.note_dirs or {}

		-- Resolve everything before comparing
		local function resolved_set(list)
			local s = {}
			for _, d in ipairs(list) do s[resolve(d)] = true end
			return s
		end
		local persisted_chat_set = resolved_set(persisted_chat_dirs)
		local persisted_note_set = resolved_set(persisted_note_dirs)

		assert.is_nil(persisted_chat_set[resolve(sibling_a .. "/workshop/parley")])
		assert.is_nil(persisted_chat_set[resolve(sibling_b .. "/workshop/parley")])
		assert.is_nil(persisted_note_set[resolve(sibling_a .. "/workshop/notes")])
		assert.is_nil(persisted_note_set[resolve(sibling_b .. "/workshop/notes")])
	end)

	it("lualine.format_mode returns ○ / ⊚ / ⦿ for global / repo / super-repo", function()
		local lualine = require("parley.lualine")

		-- Synthesize a fake parley instance for each state to keep the
		-- assertion local (no leakage from the test's parley.setup()).
		local global_parley = {
			config = { repo_root = nil },
			is_super_repo_active = function() return false end,
		}
		assert.equal("○", lualine.format_mode(global_parley))

		local repo_parley = {
			config = { repo_root = "/tmp/some/repo" },
			is_super_repo_active = function() return false end,
		}
		assert.equal("⊚", lualine.format_mode(repo_parley))

		local super_parley = {
			config = { repo_root = "/tmp/some/repo" },
			is_super_repo_active = function() return true end,
		}
		assert.equal("⦿", lualine.format_mode(super_parley))
	end)

	it("fires User ParleySuperRepoChanged on toggle on and off", function()
		local fired = 0
		local augroup = vim.api.nvim_create_augroup("ParleySuperRepoSpec", { clear = true })
		vim.api.nvim_create_autocmd("User", {
			group = augroup,
			pattern = "ParleySuperRepoChanged",
			callback = function() fired = fired + 1 end,
		})

		parley.toggle_super_repo()
		parley.toggle_super_repo()

		vim.api.nvim_del_augroup_by_id(augroup)
		assert.equal(2, fired)
	end)
end)
