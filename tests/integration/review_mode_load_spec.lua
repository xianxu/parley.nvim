-- Integration tests for the mode IO seam (lua/parley/skills/review/mode.lua):
-- mode.load / mode.list read modes/<name>.md from disk and hand content to the
-- pure mode.parse. Also asserts the six shipped mode files load cleanly. (#133)

local mode = require("parley.skills.review.mode")

local function write_file(path, content)
    local f = assert(io.open(path, "w"))
    f:write(content)
    f:close()
end

describe("review.mode IO seam", function()
    local dir

    before_each(function()
        dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        write_file(dir .. "/alpha.md", "---\nname: alpha\nscope: whole-doc\n---\nAlpha body.")
        write_file(dir .. "/beta.md", "---\nname: beta\n---\nBeta body.")
        write_file(dir .. "/broken.md", "no frontmatter — should be skipped")
        -- name (frontmatter) ≠ basename → must be dropped by list (identity = basename)
        write_file(dir .. "/mismatch.md", "---\nname: not-mismatch\n---\nbody")
    end)

    after_each(function()
        vim.fn.delete(dir, "rf")
    end)

    it("loads one mode by name", function()
        local m = mode.load(dir, "alpha")
        assert.are.equal("alpha", m.name)
        assert.are.equal("whole-doc", m.scope)
        assert.are.equal("Alpha body.", m.body)
    end)

    it("errors on a missing mode file", function()
        local m, err = mode.load(dir, "nope")
        assert.is_nil(m)
        assert.is_truthy(err)
    end)

    it("lists valid modes sorted by name, skipping unparseable + name≠basename files", function()
        local list = mode.list(dir)
        assert.are.equal(2, #list) -- broken.md + mismatch.md both dropped
        assert.are.equal("alpha", list[1].name)
        assert.are.equal("beta", list[2].name)
        for _, m in ipairs(list) do
            assert.are_not.equal("not-mismatch", m.name, "name≠basename file must be dropped")
        end
    end)
end)

describe("review skill source composition", function()
    local function source(args)
        local dir = vim.api.nvim_get_runtime_file("lua/parley/skills/review", false)[1]
        local base = table.concat(vim.fn.readfile(dir .. "/SKILL.md"), "\n")
        return require("parley.skills.review").skill.source({ skill_md = base, skill_dir = dir, args = args })
    end

    it("orders canonical round and grammar, selected mode data, then the local tool adapter", function()
        local body = source({ mode = "developmental", instruction = "tighten the intro" })
        local round = assert(body:find("# Review round", 1, true))
        local grammar = assert(body:find("# Target: Review convention", 1, true))
        local selected = assert(body:find("## Review mode: developmental", 1, true))
        local adapter = assert(body:find("# Parley local review adapter", 1, true))
        assert.is_true(round < grammar and grammar < selected and selected < adapter)
        assert.truthy(body:find("scope: whole-doc\ndeletions: apply-with-gutter-why\nfrontier: off", 1, true))
        assert.truthy(body:find("tighten the intro", 1, true))
        assert.truthy(body:find("propose_edits", adapter, true))
        assert.falsy(body:find("couch --session-sync", 1, true))
    end)

    it("includes every selected body and only the first mode flags", function()
        local body = source({ modes = { "proofreading", "copy-editing" }, instruction = "keep the voice" })
        local first = assert(body:find("## Review mode: proofreading", 1, true))
        local second = assert(body:find("## Review mode: copy-editing", 1, true))
        assert.is_true(first < second)
        assert.truthy(body:find("scope: whole-doc\ndeletions: apply\nfrontier: on", second, true))
        assert.falsy(body:find("## How to apply this round", 1, true))
        assert.truthy(body:find("## Operator instruction\nkeep the voice", 1, true))
    end)

    it("keeps legacy no-mode invocation marker-only with the local tool adapter", function()
        local body = source({})
        assert.truthy(body:find("scope: markers-only\ndeletions: propose-strike\nfrontier: on", 1, true))
        assert.truthy(body:find("# Parley local review adapter", 1, true))
    end)

    it("composes from a copied package without a source checkout", function()
        local shipped = vim.api.nvim_get_runtime_file("lua/parley/skills/review", false)[1]
        local root = vim.fn.tempname()
        local package_dir = root .. "/standalone-review"
        vim.fn.mkdir(package_dir .. "/modes", "p")
        for _, name in ipairs({ "SKILL.md", "local-adapter.md", "modes/copy-editing.md" }) do
            vim.fn.writefile(vim.fn.readfile(shipped .. "/" .. name), package_dir .. "/" .. name)
        end
        local ok, body = pcall(require("parley.skills.review").skill.source, {
            skill_md = table.concat(vim.fn.readfile(package_dir .. "/SKILL.md"), "\n"),
            skill_dir = package_dir, args = { mode = "copy-editing", instruction = "keep the voice" },
        })
        vim.fn.delete(root, "rf")
        assert.is_true(ok, body)
        assert.truthy(body:find("# Review round", 1, true))
        assert.truthy(body:find("# Target: Review convention", 1, true))
        assert.truthy(body:find("## Review mode: copy-editing", 1, true))
        assert.truthy(body:find("# Parley local review adapter", 1, true))
    end)

    it("refuses missing selected mode data rather than silently widening scope", function()
        assert.has_error(function() source({ mode = "missing-mode" }) end)
    end)

    it("refuses an incomplete local package", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        local ok = pcall(require("parley.skills.review").skill.source,
            { skill_md = "BASE", skill_dir = dir, args = {} })
        vim.fn.delete(dir, "rf")
        assert.is_false(ok)
    end)
end)

describe("shipped review mode files", function()
    it("all six load in editorial order (developmental → … → free-form)", function()
        local modes_dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
        assert.is_truthy(modes_dir, "review/modes dir must be on the runtimepath")
        local list = mode.list(modes_dir)
        local names = {}
        for i, m in ipairs(list) do
            names[i] = m.name -- canonical name == kebab basename; menu prettifies
        end
        -- Sorted by `order:` (the document-construction workflow), NOT alphabetically.
        assert.are.same(
            { "developmental", "line-editing", "copy-editing", "proofreading", "fact-check", "free-form" },
            names
        )
    end)
end)
