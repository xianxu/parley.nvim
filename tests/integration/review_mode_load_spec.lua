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
    it("composes SKILL.md ⊕ mode body ⊕ directives ⊕ instruction", function()
        local review = require("parley.skills.review")
        local review_dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review", false) or {})[1]
        assert.is_truthy(review_dir)
        local body = review.skill.source({
            skill_md = "BASE-SKILL-MD",
            skill_dir = review_dir,
            args = { mode = "developmental", instruction = "tighten the intro" },
        })
        assert.is_truthy(body:find("BASE-SKILL-MD", 1, true), "includes base SKILL.md")
        assert.is_truthy(body:find("Review mode: developmental", 1, true), "names the mode")
        assert.is_truthy(body:lower():find("whole document", 1, true), "includes scope directive")
        assert.is_truthy(body:find("tighten the intro", 1, true), "includes operator instruction")
    end)

    it("returns base SKILL.md alone when no mode is given (legacy marker-only review)", function()
        local review = require("parley.skills.review")
        local body = review.skill.source({ skill_md = "ONLY-BASE", args = {} })
        assert.are.equal("ONLY-BASE", body)
    end)
end)

describe("shipped review mode files", function()
    it("all six load and parse cleanly", function()
        local modes_dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
        assert.is_truthy(modes_dir, "review/modes dir must be on the runtimepath")
        local list = mode.list(modes_dir)
        local names = {}
        for _, m in ipairs(list) do
            names[m.name] = m
        end
        -- Canonical name == file basename (kebab), so mode.load(dir, name) resolves;
        -- the M4 menu prettifies kebab → spaces for display.
        for _, want in ipairs({ "developmental", "line-editing", "copy-editing", "proofreading", "fact-check", "free-form" }) do
            assert.is_truthy(names[want], "missing mode: " .. want)
        end
        assert.are.equal(6, #list)
    end)
end)
