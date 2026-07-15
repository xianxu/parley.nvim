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
