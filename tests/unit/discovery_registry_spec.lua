-- Unit tests for lua/parley/discovery/registry.lua
--
-- Registry is `name → TypeDescriptor` plus the two pure consumers:
--   query(type, term) → DiscoverySpec   (decide the search)
--   spec_to_command(spec) → string      (compile the search to an rg pipeline)
-- "Decide the search" stays pure and testable apart from "run the search"
-- (execution is IO, M2/consumer side). This is the deterministic-shell
-- surface: the model only picks a noun + term; the registry compiles the rest.

local registry = require("parley.discovery.registry")
local base = require("parley.discovery.base")
local config = require("parley.config")

local function reg()
    return registry.of(base.descriptors)
end

describe("registry.of / get / names", function()
    it("get returns the descriptor for a known name", function()
        local d = reg():get("pensive")
        assert.is_not_nil(d)
        assert.are.equal("pensive", d.name)
    end)

    it("get returns nil for an unknown name", function()
        assert.is_nil(reg():get("nope"))
    end)

    it("names lists every registered type", function()
        local names = reg():names()
        assert.is_table(names)
        assert.are.equal(#base.descriptors, #names)
    end)
end)

describe("registry.query → DiscoverySpec", function()
    it("frontmatter type: builds a frontmatter-filtered spec", function()
        local spec = reg():query("pensive", "duality")
        assert.are.same({ "**/*.md" }, spec.roots)
        assert.are.same({ field = "type", value = "pensive" }, spec.frontmatter)
        assert.are.equal("duality", spec.content_term)
    end)

    it("an `any` matcher yields frontmatter = nil (the glob discriminates)", function()
        local spec = reg():query("note", "async")
        assert.is_nil(spec.frontmatter)
        assert.are.equal("async", spec.content_term)
    end)

    it("omitting the term yields content_term = nil", function()
        local spec = reg():query("pensive")
        assert.is_nil(spec.content_term)
    end)

    it("returns nil for an unknown type (mirrors get's miss)", function()
        assert.is_nil(reg():query("nope", "x"))
    end)

    it("issue and plan produce different roots (locate glob, not basename, separates them)", function()
        local issue_spec = reg():query("issue")
        local plan_spec = reg():query("plan")
        assert.are.same({ config.issues_dir .. "/*.md" }, issue_spec.roots)
        assert.are.same({ "workshop/plans/*.md" }, plan_spec.roots)
        assert.are_not.same(issue_spec.roots, plan_spec.roots)
    end)
end)

describe("registry.spec_to_command", function()
    it("compiles a frontmatter spec to an rg-filter-then-content pipeline", function()
        local spec = reg():query("pensive", "duality")
        local cmd = registry.spec_to_command(spec)
        assert.are.equal(
            "rg -l '^type: pensive' -g '**/*.md' . | xargs -r rg -il 'duality'",
            cmd
        )
    end)

    it("compiles a no-frontmatter spec to a plain content search", function()
        -- issue: `any` matcher, single repo-relative glob → deterministic command.
        local spec = reg():query("issue", "async")
        local cmd = registry.spec_to_command(spec)
        assert.are.equal(
            "rg -il 'async' -g '" .. config.issues_dir .. "/*.md' .",
            cmd
        )
    end)

    it("compiles a frontmatter spec with no term to a file-list command", function()
        local spec = reg():query("pensive")
        local cmd = registry.spec_to_command(spec)
        assert.are.equal("rg -l '^type: pensive' -g '**/*.md' .", cmd)
    end)

    it("compiles a no-frontmatter spec with no term to --files", function()
        local spec = reg():query("issue")
        local cmd = registry.spec_to_command(spec)
        assert.are.equal("rg --files -g '" .. config.issues_dir .. "/*.md' .", cmd)
    end)
end)

describe("registry.render — the #128 repo_discovery body", function()
    -- render()'s output is a CONTRACT with parley.nvim#128: when this format
    -- changes the repo_discovery skill body changes. These verbatim-line
    -- assertions are the guard.
    local out = reg():render()

    it("lists every type's label and blurb", function()
        for _, d in ipairs(base.descriptors) do
            assert.is_not_nil(out:find(d.label, 1, true), "missing label: " .. d.label)
            assert.is_not_nil(out:find(d.blurb, 1, true), "missing blurb: " .. d.blurb)
        end
    end)

    it("includes a derived search hint per type", function()
        -- frontmatter → `type: <value>`; frontmatter_present → `header <field>:`
        assert.is_not_nil(out:find("type: pensive", 1, true))
        assert.is_not_nil(out:find("header `file:`", 1, true))
    end)

    it("renders the pensive and chat lines verbatim (the contract)", function()
        assert.is_not_nil(
            out:find("- Pensive (`pensive`) — a per-topic thinking note; find by type: pensive", 1, true),
            "pensive line drifted:\n" .. out
        )
        assert.is_not_nil(
            out:find("- Chat (`chat`) — a parley chat session; find by header `file:`", 1, true),
            "chat line drifted:\n" .. out
        )
    end)

    it("is stable / sorted by name", function()
        local lines = vim.split(out, "\n", { plain = true })
        local names = {}
        for _, line in ipairs(lines) do
            local n = line:match("^%- .- %(`([%w]+)`%)")
            if n then
                table.insert(names, n)
            end
        end
        local sorted = vim.deepcopy(names)
        table.sort(sorted)
        assert.are.same(sorted, names, "render lines are not sorted by name")
        assert.are.equal(#base.descriptors, #names)
    end)
end)
