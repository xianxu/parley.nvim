-- Integration test for voice_apply ported onto source(ctx) (#128 M4).
--
-- voice_apply has a DYNAMIC body: SKILL.md ⊕ ~/.personal/<slug>-writing-style.md.
-- The disk provider injects ctx.skill_md (the SKILL.md body, Task 1); voice_apply's
-- source(ctx) appends the per-slug style guide. This exercises both ends through
-- the real registry/disk provider (HOME pointed at a temp dir for the style file).

local skills = require("parley.skill_registry")

describe("voice_apply source(ctx)", function()
    local saved_home, tmp_home

    before_each(function()
        saved_home = vim.env.HOME
        tmp_home = vim.fn.tempname() .. "-voice-home"
        vim.fn.mkdir(tmp_home .. "/.personal", "p")
        vim.env.HOME = tmp_home
    end)

    after_each(function()
        vim.env.HOME = saved_home
        vim.fn.delete(tmp_home, "rf")
    end)

    local function voice_manifest()
        return skills.current().get("voice-apply")
    end

    it("composes SKILL.md ⊕ the per-slug style guide", function()
        vim.fn.writefile({ "STYLE-BODY-LINE" }, tmp_home .. "/.personal/myvoice-writing-style.md")
        local m = voice_manifest()
        assert.is_not_nil(m, "voice-apply manifest should be in the registry")
        local body = m.source({ args = { slug = "myvoice" } })
        assert.is_truthy(body:find("You are a voice editor", 1, true), "includes SKILL.md body (ctx.skill_md)")
        assert.is_truthy(body:find("Voice Style Guide", 1, true), "includes the style-guide heading")
        assert.is_truthy(body:find("STYLE-BODY-LINE", 1, true), "includes the per-slug style content")
    end)

    it("errors with a clear message when the style file is missing", function()
        local m = voice_manifest()
        local ok, err = pcall(function()
            return m.source({ args = { slug = "nope" } })
        end)
        assert.is_false(ok, "a bad slug should error, not silently return")
        assert.is_truthy(tostring(err):find("not found", 1, true), "the error names the missing file")
    end)
end)
