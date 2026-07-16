local markdown_finder = require("parley.markdown_finder")

describe("markdown finder pure discovery policy", function()
	it("accepts only root-relative Markdown paths within component depth", function()
		assert.same({
			relative = "docs/note.md",
			unresolved_absolute = "/repo/docs/note.md",
		}, markdown_finder.path_candidate("/repo", "docs/note.md", 2))
		for _, path in ipairs({ "/absolute.md", "../escape.md", "docs/../../escape.md", "note.txt" }) do
			assert.is_nil(markdown_finder.path_candidate("/repo", path, 4))
		end
		assert.is_nil(markdown_finder.path_candidate("/repo", "one/two/too-deep.md", 2))
	end)

	it("materializes deterministic ordinary entries after canonical deduplication", function()
		local winner = {
			relative = "docs/a.md",
			root = { path = "/repo" },
			stat = { mtime = { sec = 20 } },
			identity = { key = "/real/a.md", source = { root_ordinal = 1, unresolved = "/repo/docs/a.md" } },
		}
		local duplicate = vim.deepcopy(winner)
		duplicate.identity.source = { root_ordinal = 2, unresolved = "/alias/a.md" }
		local older = {
			relative = "root.md",
			root = { path = "/repo" },
			stat = { mtime = { sec = 10 } },
			identity = { key = "/real/root.md", source = { root_ordinal = 1, unresolved = "/repo/root.md" } },
		}

		local entries = markdown_finder.materialize_records({
			mode = "ordinary",
			records = { older, duplicate, winner },
		})

		assert.equals(2, #entries)
		assert.same({ "/real/a.md", "/real/root.md" }, vim.tbl_map(function(value) return value.value end, entries))
		assert.equals("docs", entries[1].tag)
		assert.equals(".", entries[2].tag)
	end)

	it("uses repository identity and stable path ties in super-repo mode", function()
		local records = {
			{
				relative = "z.md", root = { name = "zeta" }, stat = { mtime = { sec = 10 } },
				identity = { key = "/z/z.md", source = { root_ordinal = 2, unresolved = "/z/z.md" } },
			},
			{
				relative = "a.md", root = { name = "alpha" }, stat = { mtime = { sec = 10 } },
				identity = { key = "/a/a.md", source = { root_ordinal = 1, unresolved = "/a/a.md" } },
			},
		}

		local entries = markdown_finder.materialize_records({ mode = "super_repo", records = records })

		assert.same({ "/a/a.md", "/z/z.md" }, vim.tbl_map(function(value) return value.value end, entries))
		assert.equals("alpha", entries[1].tag)
		assert.truthy(entries[1].display:find("{alpha}", 1, true))
	end)

	it("preserves newline path identity while keeping picker text on one line", function()
		local path = "docs/line\nbreak.md"
		local record = {
			relative = path,
			root = { path = "/repo" },
			stat = { mtime = { sec = 10 } },
			identity = { key = "/repo/" .. path, source = { root_ordinal = 1, unresolved = "/repo/" .. path } },
		}

		local entries = markdown_finder.materialize_records({ mode = "ordinary", records = { record } })

		assert.equals("/repo/" .. path, entries[1].value)
		assert.is_nil(entries[1].display:find("\n", 1, true))
		assert.is_nil(entries[1].search_text:find("\n", 1, true))
	end)
end)

local function entry(name, tag)
	return {
		display = name .. " display",
		search_text = name .. " search",
		value = "/repo/" .. name .. ".md",
		tag = tag,
	}
end

local function item(name)
	return {
		display = name .. " display",
		search_text = name .. " search",
		value = "/repo/" .. name .. ".md",
	}
end

describe("markdown finder picker policy", function()
	it("uses only source-ordered directory facets in ordinary mode", function()
		local entries = {
			entry("recent", "workshop"),
			entry("older", "docs"),
			entry("oldest", "workshop"),
		}

		local result = markdown_finder.build_picker_data({
			mode = "ordinary",
			entries = entries,
			member_roots = { { name = "zeta" }, { name = "alpha" } },
			directory_state = { workshop = false },
			repo_state = { docs = false },
		})

		assert.equals("directory", result.facet_domain)
		assert.same({
			{ label = "workshop", enabled = false },
			{ label = "docs", enabled = true },
		}, result.tags)
		assert.same({ item("older") }, result.items)
		assert.same({ docs = false }, result.repo_state)
	end)

	it("uses only alphabetized repository facets in eligible super-repo mode", function()
		local result = markdown_finder.build_picker_data({
			mode = "super_repo",
			entries = { entry("beta-note", "beta"), entry("alpha-note", "alpha") },
			member_roots = { { name = "beta" }, { name = "alpha" } },
			directory_state = { beta = false },
			repo_state = { alpha = false },
		})

		assert.equals("repo", result.facet_domain)
		assert.same({
			{ label = "alpha", enabled = false },
			{ label = "beta", enabled = true },
		}, result.tags)
		assert.same({ item("beta-note") }, result.items)
		assert.same({ beta = false }, result.directory_state)
	end)

	it("keeps an eligible member with no rows in the repository facets", function()
		local result = markdown_finder.build_picker_data({
			mode = "super_repo",
			entries = { entry("alpha-note", "alpha") },
			member_roots = { { name = "alpha" }, { name = "empty" } },
		})

		assert.same({
			{ label = "alpha", enabled = true },
			{ label = "empty", enabled = true },
		}, result.tags)
	end)

	it("retains the repository bar for an eligible zero-row input", function()
		local result = markdown_finder.build_picker_data({
			mode = "super_repo",
			entries = {},
			member_roots = { { name = "beta" }, { name = "alpha" } },
		})

		assert.equals("repo", result.facet_domain)
		assert.same({}, result.items)
		assert.same({
			{ label = "alpha", enabled = true },
			{ label = "beta", enabled = true },
		}, result.tags)
	end)

	it("renders invalid super-repo expansions unfiltered without a bar", function()
		local invalid_roots = {
			{ { name = "alpha" }, {} },
			{ { name = "alpha" }, { name = 2 } },
			{ { name = "alpha" }, { name = "" } },
			{ { name = "alpha" }, { name = "alpha" } },
		}
		local entries = { entry("alpha-note", "alpha"), entry("other-note", "other") }

		for _, member_roots in ipairs(invalid_roots) do
			local result = markdown_finder.build_picker_data({
				mode = "super_repo",
				entries = entries,
				member_roots = member_roots,
				directory_state = { alpha = false },
				repo_state = { alpha = false, absent = true },
			})

			assert.is_nil(result.facet_domain)
			assert.is_nil(result.tags)
			assert.same({ item("alpha-note"), item("other-note") }, result.items)
			assert.same({ alpha = false }, result.directory_state)
			assert.same({ alpha = false, absent = true }, result.repo_state)
		end
	end)

	it("renders repository identity mismatches unfiltered without a bar", function()
		local entries = { entry("alpha-note", "alpha"), entry("outside-note", "outside") }

		local result = markdown_finder.build_picker_data({
			mode = "super_repo",
			entries = entries,
			member_roots = { { name = "alpha" }, { name = "beta" } },
			repo_state = { outside = false },
		})

		assert.is_nil(result.facet_domain)
		assert.is_nil(result.tags)
		assert.same({ item("alpha-note"), item("outside-note") }, result.items)
	end)

	it("enables new repository facets and retains absent choices", function()
		local result = markdown_finder.build_picker_data({
			mode = "super_repo",
			entries = { entry("alpha-note", "alpha"), entry("beta-note", "beta") },
			member_roots = { { name = "alpha" }, { name = "beta" } },
			repo_state = { alpha = false, absent = false },
		})

		assert.same({ alpha = false, beta = true, absent = false }, result.repo_state)
		assert.same({
			{ label = "alpha", enabled = false },
			{ label = "beta", enabled = true },
		}, result.tags)
	end)

	it("does not mutate inputs and returns fresh tables", function()
		local opts = {
			mode = "ordinary",
			entries = { entry("recent", "workshop"), entry("older", "docs") },
			member_roots = { { name = "alpha" }, { name = "beta" } },
			directory_state = { workshop = false, absent = true },
			repo_state = { alpha = false },
		}
		local before = vim.deepcopy(opts)

		local result = markdown_finder.build_picker_data(opts)

		assert.same(before, opts)
		assert.is_not.equal(opts.entries, result.items)
		assert.is_not.equal(opts.directory_state, result.directory_state)
		assert.is_not.equal(opts.repo_state, result.repo_state)
		assert.is_not.equal(opts.entries[2], result.items[1])
	end)
end)

describe("markdown finder entry point", function()
	local base_dir
	local ordinary_root
	local fake
	local runtime_state
	local picker_calls
	local picker_updates
	local warnings

	local function write_markdown(path, timestamp)
		vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
		vim.fn.writefile({ "# note" }, path)
		if timestamp then
			vim.loop.fs_utime(path, timestamp, timestamp)
		end
	end

	local function labels(tags)
		local result = {}
		for _, tag in ipairs(tags or {}) do
			table.insert(result, tag.label)
		end
		return result
	end

	local function update_values(update)
		local result = {}
		for _, picker_item in ipairs(update.items) do
			table.insert(result, picker_item.value)
		end
		return result
	end

	local function set_runtime(active, members)
		runtime_state = { active = active, members = members or {} }
	end

	before_each(function()
		base_dir = vim.fn.tempname() .. "-markdown-finder-entry"
		ordinary_root = base_dir .. "/ordinary"
		picker_calls = {}
		picker_updates = {}
		warnings = {}
		set_runtime(false)

		local function list_markdown(options, on_complete)
			local prefix = options.root:gsub("/+$", "") .. "/"
			local paths = {}
			for _, path in ipairs(vim.fn.glob(options.root .. "/**/*.md", false, true)) do
				paths[#paths + 1] = path:sub(#prefix + 1)
			end
			table.sort(paths)
			on_complete({ root_ordinal = options.root_ordinal, status = "success", paths = paths })
			return { cancel = function() end, is_cancelled = function() return false end }
		end
		local function read_paths(options, on_complete)
			local candidates = {}
			for _, relative in ipairs(options.paths) do
				local absolute = options.root.path .. "/" .. relative
				local stat = vim.loop.fs_stat(absolute)
				if stat then
					candidates[#candidates + 1] = {
						root = options.root,
						root_ordinal = options.root_ordinal,
						relative = relative,
						unresolved_absolute = absolute,
						resolved_absolute = vim.fn.resolve(absolute),
						stat = stat,
					}
				end
			end
			on_complete({ candidates = candidates, failures = {} })
			return { cancel = function() end, is_cancelled = function() return false end }
		end

		fake = {
			_markdown_finder = {
				query = nil,
				directory_facet_state = nil,
				repo_facet_state = nil,
			},
			config = {
				repo_root = ordinary_root,
				markdown_finder_max_depth = 4,
				-- Deliberately stale: runtime super-repo state must win.
				super_repo_members = { { path = "/stale", name = "stale" } },
			},
			super_repo = {
				get_state = function()
					return vim.deepcopy(runtime_state)
				end,
			},
			helpers = {
				find_git_root = function() return ordinary_root end,
			},
			logger = { warning = function(message) warnings[#warnings + 1] = message end },
			_finder_dependencies = {
				git_markdown_source = { list = list_markdown },
				async_file_source = { read_paths = read_paths },
				schedule = function(callback) callback() end,
			},
			float_picker = {
				open = function(opts)
					table.insert(picker_calls, opts)
					local query = opts.initial_query or ""
					local closed = false
					local on_query_change = opts.on_query_change
					opts.on_query_change = function(value)
						query = value
						if on_query_change then on_query_change(value) end
					end
					return {
						update = function(...)
							local args = { ... }
							opts.items = args[1]
							if opts.tag_bar then opts.tag_bar.tags = args[2] or {} end
							table.insert(picker_updates, {
								items = args[1],
								tags = args[2],
								argument_count = select("#", ...),
								query = query,
							})
						end,
						set_status = function(status) opts.status = status end,
						current_query = function() return query end,
						set_query = function(value) query = value end,
						close = function() closed = true end,
						is_closed = function() return closed end,
					}
				end,
			},
			open_buf = function() end,
		}
		markdown_finder.setup(fake)
	end)

	after_each(function()
		markdown_finder.setup(require("parley"))
		if base_dir then vim.fn.delete(base_dir, "rf") end
	end)

	it("opens an ordinary directory bar and repaints without changing the live query", function()
		local now = os.time()
		write_markdown(ordinary_root .. "/workshop/recent.md", now)
		write_markdown(ordinary_root .. "/docs/older.md", now - 10)

		markdown_finder.open()
		local call = picker_calls[1]
		assert.same({ "workshop", "docs" }, labels(call.tag_bar.tags))
		call.on_query_change("  exact live query  ")
		call.tag_bar.on_toggle("workshop")

		local update = picker_updates[#picker_updates]
		assert.same({ vim.fn.resolve(ordinary_root .. "/docs/older.md") }, update_values(update))
		assert.equals(2, update.argument_count)
		assert.equals("  exact live query  ", fake._markdown_finder.query)
	end)

	it("preserves picker identity and restores the source window before opening a selection", function()
		local selected = ordinary_root .. "/selected.md"
		write_markdown(selected)
		local source_win = vim.api.nvim_get_current_win()
		local opened
		fake.open_buf = function(value, listed)
			opened = {
				value = value,
				listed = listed,
				win = vim.api.nvim_get_current_win(),
			}
		end

		markdown_finder.open()
		local call = picker_calls[1]
		assert.equals("parley.markdown_finder", call.recall_key)
		assert.equals("bottom", call.anchor)

		local other_buf = vim.api.nvim_create_buf(false, true)
		local other_win = vim.api.nvim_open_win(other_buf, true, {
			relative = "editor",
			row = 1,
			col = 1,
			width = 20,
			height = 2,
			style = "minimal",
		})
		call.on_select(call.items[1])
		local selected_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_close(other_win, true)

		assert.equals(source_win, selected_win)
		assert.same({
			value = vim.fn.resolve(selected),
			listed = true,
			win = source_win,
		}, opened)
	end)

	it("reopens with verbatim whitespace and a subsequently cleared query", function()
		write_markdown(ordinary_root .. "/note.md")
		markdown_finder.open()
		picker_calls[1].on_query_change("   ")

		markdown_finder.open()
		assert.equals("   ", picker_calls[2].initial_query)
		picker_calls[2].on_query_change("")

		markdown_finder.open()
		assert.equals("", picker_calls[3].initial_query)
	end)

	it("keeps directory and repository choices independent across runtime mode changes", function()
		local now = os.time()
		write_markdown(ordinary_root .. "/workshop/a.md", now)
		write_markdown(ordinary_root .. "/docs/b.md", now - 10)
		local alpha = base_dir .. "/alpha"
		local beta = base_dir .. "/beta"
		local gamma = base_dir .. "/gamma"
		write_markdown(alpha .. "/a.md", now)
		write_markdown(beta .. "/b.md", now - 10)
		write_markdown(gamma .. "/g.md", now - 20)

		markdown_finder.open()
		picker_calls[1].tag_bar.on_toggle("workshop")
		set_runtime(true, { { path = alpha, name = "alpha" }, { path = beta, name = "beta" } })
		markdown_finder.open()
		assert.same({ "alpha", "beta" }, labels(picker_calls[2].tag_bar.tags))
		picker_calls[2].tag_bar.on_toggle("alpha")

		set_runtime(false)
		markdown_finder.open()
		assert.is_false(fake._markdown_finder.directory_facet_state.workshop)
		assert.is_true(fake._markdown_finder.directory_facet_state.docs)

		set_runtime(true, { { path = beta, name = "beta" }, { path = gamma, name = "gamma" } })
		markdown_finder.open()
		assert.is_false(fake._markdown_finder.repo_facet_state.alpha)
		assert.is_true(fake._markdown_finder.repo_facet_state.beta)
		assert.is_true(fake._markdown_finder.repo_facet_state.gamma)
	end)

	it("reopens after NONE with the directory bar available for ALL restore", function()
		write_markdown(ordinary_root .. "/workshop/a.md")
		write_markdown(ordinary_root .. "/docs/b.md")
		markdown_finder.open()
		picker_calls[1].tag_bar.on_none()
		assert.equals(0, #picker_updates[#picker_updates].items)

		markdown_finder.open()
		assert.equals(0, #picker_calls[2].items)
		assert.is_table(picker_calls[2].tag_bar)
		picker_calls[2].tag_bar.on_all()
		assert.equals(2, #picker_updates[#picker_updates].items)
	end)

	it("scans invalidly labelled members and opens the aggregate without a bar", function()
		local alpha = base_dir .. "/alpha"
		local unlabelled = base_dir .. "/unlabelled"
		write_markdown(alpha .. "/a.md")
		write_markdown(unlabelled .. "/u.md")
		set_runtime(true, {
			{ path = alpha, name = "alpha" },
			{ path = unlabelled },
			{ path = "", name = "discard-path" },
			{ path = 3, name = "discard-number" },
		})

		assert.has_no.errors(markdown_finder.open)
		assert.equals(2, #picker_calls[1].items)
		assert.same({}, picker_calls[1].tag_bar.tags)
	end)

	it("opens an eligible zero-row super expansion with a sorted repository bar", function()
		set_runtime(true, {
			{ path = base_dir .. "/zeta", name = "zeta" },
			{ path = base_dir .. "/alpha", name = "alpha" },
		})

		markdown_finder.open()
		assert.same({}, picker_calls[1].items)
		assert.same({ "alpha", "zeta" }, labels(picker_calls[1].tag_bar.tags))
	end)

	it("opens the scanning shell before Git starts and settles against the live query", function()
		local listed_after_picker = false
		local finish_list
		fake._finder_dependencies.git_markdown_source.list = function(_, on_complete)
			listed_after_picker = #picker_calls == 1
			finish_list = on_complete
			return { cancel = function() end, is_cancelled = function() return false end }
		end
		write_markdown(ordinary_root .. "/docs/note.md")

		markdown_finder.open()

		assert.is_true(listed_after_picker)
		assert.same({}, picker_calls[1].items)
		assert.equals("scanning…", picker_calls[1].status.message)
		picker_calls[1].on_query_change("live query")
		finish_list({ root_ordinal = 1, status = "success", paths = { "docs/note.md" } })

		assert.equals("live query", picker_updates[1].query)
		assert.same({ vim.fn.resolve(ordinary_root .. "/docs/note.md") }, update_values(picker_updates[1]))
	end)

	it("cancels in-flight Markdown acquisition and ignores a late root result", function()
		local finish_list
		local cancel_count = 0
		fake._finder_dependencies.git_markdown_source.list = function(_, on_complete)
			finish_list = on_complete
			return {
				cancel = function() cancel_count = cancel_count + 1 end,
				is_cancelled = function() return cancel_count > 0 end,
			}
		end

		markdown_finder.open()
		picker_calls[1].on_cancel()
		finish_list({ root_ordinal = 1, status = "success", paths = {} })

		assert.equals(1, cancel_count)
		assert.equals(0, #picker_updates)
		assert.has_no.errors(markdown_finder.open)
		assert.equals(2, #picker_calls)
	end)

	it("keeps successful roots and warns once when another Git root fails", function()
		local alpha = base_dir .. "/alpha"
		local beta = base_dir .. "/beta"
		write_markdown(alpha .. "/note.md")
		set_runtime(true, { { path = alpha, name = "alpha" }, { path = beta, name = "beta" } })
		local default_list = fake._finder_dependencies.git_markdown_source.list
		fake._finder_dependencies.git_markdown_source.list = function(options, on_complete)
			if options.root == beta then
				on_complete({
					root_ordinal = options.root_ordinal,
					status = "failed",
					failure = { kind = "process_exit", diagnostic = "not a repository" },
				})
				return { cancel = function() end }
			end
			return default_list(options, on_complete)
		end

		markdown_finder.open()

		assert.equals(1, #picker_calls[1].items)
		assert.equals(1, #warnings)
		assert.truthy(warnings[1]:find("1 roots", 1, true))
	end)

	it("reports stat failures as partial without inventing a selectable row", function()
		fake._finder_dependencies.git_markdown_source.list = function(options, on_complete)
			on_complete({ root_ordinal = options.root_ordinal, status = "success", paths = { "gone.md" } })
			return { cancel = function() end }
		end
		fake._finder_dependencies.async_file_source.read_paths = function(_, on_complete)
			on_complete({
				candidates = {},
				failures = { { kind = "stat", diagnostic = "missing" } },
			})
			return { cancel = function() end }
		end

		markdown_finder.open()

		assert.same({}, picker_calls[1].items)
		assert.equals(1, #warnings)
		assert.truthy(warnings[1]:find("1 files", 1, true))
	end)

	it("leaves a bounded failure status when every Git root fails", function()
		fake._finder_dependencies.git_markdown_source.list = function(options, on_complete)
			on_complete({
				root_ordinal = options.root_ordinal,
				status = "failed",
				failure = { kind = "process_exit", diagnostic = "not a repository" },
			})
			return { cancel = function() end }
		end

		markdown_finder.open()

		assert.equals("Markdown Files: scan failed (roots: 1, files: 0)", picker_calls[1].status.message)
		assert.is_false(picker_calls[1].status.animated)
		assert.equals(0, #warnings)
	end)
end)
