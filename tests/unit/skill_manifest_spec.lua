-- Unit tests for lua/parley/skill_manifest.lua
--
-- A SkillManifest is the declarative description of one skill — the single
-- shape every provider (disk / user / repo / virtual) emits:
--   { name, description, scope, activation, source, tools?, elevated?,
--     force_tool?, args?, agent? }
-- validate(m) returns (true) or (false, err), mirroring tools/types.lua.

local manifest = require("parley.skill_manifest")

local function valid()
    return {
        name = "review",
        description = "Edit this document per its 🤖 markers",
        scope = "global",
        activation = { manual = true, auto = true },
        source = function() return "body" end,
        tools = { "read_file" },
        elevated = { "propose_edits" },
        force_tool = "propose_edits",
    }
end

describe("skill_manifest.validate", function()
    it("accepts a fully-formed manifest", function()
        local ok, err = manifest.validate(valid())
        assert.is_true(ok)
        assert.is_nil(err)
    end)

    it("accepts a minimal manifest (no tools/elevated/force_tool/args/agent)", function()
        assert.is_true(manifest.validate({
            name = "x",
            description = "d",
            scope = "repo",
            activation = { always = true },
            source = function() return "" end,
        }))
    end)

    it("rejects non-table input", function()
        local ok, err = manifest.validate("nope")
        assert.is_false(ok)
        assert.matches("table", err)
    end)

    it("rejects a missing name", function()
        local m = valid()
        m.name = nil
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("name", err)
    end)

    it("rejects a missing description", function()
        local m = valid()
        m.description = nil
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("description", err)
    end)

    it("rejects a scope outside {global, repo, super_repo}", function()
        local m = valid()
        m.scope = "wild"
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("scope", err)
    end)

    it("accepts each valid scope", function()
        for _, s in ipairs({ "global", "repo", "super_repo" }) do
            local m = valid()
            m.scope = s
            assert.is_true(manifest.validate(m), "scope " .. s .. " should be valid")
        end
    end)

    it("rejects activation that is not a table", function()
        local m = valid()
        m.activation = true
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("activation", err)
    end)

    it("rejects an empty activation (a skill no one can activate is a bug)", function()
        local m = valid()
        m.activation = {}
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("activation", err)
    end)

    it("rejects an unknown activation flag", function()
        local m = valid()
        m.activation = { sometimes = true }
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("activation", err)
    end)

    it("rejects a non-boolean activation flag value", function()
        local m = valid()
        m.activation = { manual = "yes" }
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("activation", err)
    end)

    it("rejects a source that is not a function", function()
        local m = valid()
        m.source = "body"
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("source", err)
    end)

    it("rejects tools that is not a list of strings", function()
        local m = valid()
        m.tools = { 1, 2 }
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("tools", err)
    end)

    it("rejects elevated that is not a list of strings", function()
        local m = valid()
        m.elevated = "propose_edits"
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("elevated", err)
    end)

    it("rejects a non-string force_tool", function()
        local m = valid()
        m.force_tool = 42
        local ok, err = manifest.validate(m)
        assert.is_false(ok)
        assert.matches("force_tool", err)
    end)
end)

describe("skill_manifest constants", function()
    it("exposes SCOPES and ACTIVATION_FLAGS for reuse", function()
        assert.is_true(manifest.SCOPES.global)
        assert.is_true(manifest.SCOPES.repo)
        assert.is_true(manifest.SCOPES.super_repo)
        assert.is_true(manifest.ACTIVATION_FLAGS.always)
        assert.is_true(manifest.ACTIVATION_FLAGS.auto)
        assert.is_true(manifest.ACTIVATION_FLAGS.manual)
    end)
end)
