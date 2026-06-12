-- Integration tests for lua/parley/skill_providers.lua
--
-- Providers turn a source (disk root / runtime generator) into uniform
-- SkillManifests. The DiskProvider scans a root and builds each manifest's
-- `source` as a CLOSURE capturing the absolute dir path it already found —
-- so a skill's body load never does the debug.getinfo path-guessing dance.

local providers = require("parley.skill_providers")
local manifest = require("parley.skill_manifest")

local function write(path, lines)
    vim.fn.writefile(lines, path)
end

local function by_name(list, name)
    for _, m in ipairs(list) do
        if m.name == name then
            return m
        end
    end
    return nil
end

describe("providers.disk", function()
    local root = vim.fn.tempname() .. "-parley-skill-disk"

    before_each(function()
        -- alpha: declares fields in init.lua, body comes from SKILL.md
        vim.fn.mkdir(root .. "/alpha", "p")
        write(root .. "/alpha/init.lua", {
            "return {",
            '  name = "alpha",',
            '  description = "Alpha skill",',
            '  scope = "global",',
            "  activation = { manual = true },",
            '  tools = { "read_file" },',
            "}",
        })
        write(root .. "/alpha/SKILL.md", { "ALPHA BODY" })

        -- beta: { skill = {...} } shape, inline source closure, no SKILL.md
        vim.fn.mkdir(root .. "/beta", "p")
        write(root .. "/beta/init.lua", {
            "return {",
            "  skill = {",
            '    name = "beta",',
            '    description = "Beta skill",',
            '    scope = "repo",',
            "    activation = { always = true },",
            '    source = function() return "BETA INLINE" end,',
            "  },",
            "}",
        })

        -- empty dir (no init.lua) → skipped, not an error
        vim.fn.mkdir(root .. "/empty", "p")
        -- a stray file (not a dir) → ignored
        write(root .. "/notes.txt", { "ignore me" })
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    it("emits a valid manifest per skill dir, skipping dirs without init.lua", function()
        local list = providers.disk(root):list()
        assert.are.equal(2, #list, "expected alpha + beta only")
        for _, m in ipairs(list) do
            local ok, err = manifest.validate(m)
            assert.is_true(ok, "invalid manifest '" .. tostring(m.name) .. "': " .. tostring(err))
        end
    end)

    it("sources the body from SKILL.md via a closure over the captured path", function()
        local alpha = by_name(providers.disk(root):list(), "alpha")
        assert.is_not_nil(alpha)
        assert.are.equal("ALPHA BODY\n", alpha.source({}))
        assert.are.equal("global", alpha.scope)
        assert.are.same({ "read_file" }, alpha.tools)
    end)

    it("unwraps the { skill = {...} } shape and honors an inline source", function()
        local beta = by_name(providers.disk(root):list(), "beta")
        assert.is_not_nil(beta)
        assert.are.equal("BETA INLINE", beta.source({}))
        assert.are.equal("repo", beta.scope)
    end)
end)
