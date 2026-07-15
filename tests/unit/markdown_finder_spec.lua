local markdown_finder = require("parley.markdown_finder")

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
		set_runtime(false)

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
			logger = { warning = function() end },
			float_picker = {
				open = function(opts)
					table.insert(picker_calls, opts)
					return {
						update = function(...)
							local args = { ... }
							table.insert(picker_updates, {
								items = args[1],
								tags = args[2],
								argument_count = select("#", ...),
							})
						end,
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

		assert.same({ vim.fn.resolve(ordinary_root .. "/docs/older.md") }, update_values(picker_updates[1]))
		assert.equals(2, picker_updates[1].argument_count)
		assert.equals("  exact live query  ", fake._markdown_finder.query)
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
		assert.equals(0, #picker_updates[1].items)

		markdown_finder.open()
		assert.equals(0, #picker_calls[2].items)
		assert.is_table(picker_calls[2].tag_bar)
		picker_calls[2].tag_bar.on_all()
		assert.equals(2, #picker_updates[2].items)
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
		assert.is_nil(picker_calls[1].tag_bar)
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
end)
