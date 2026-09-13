-- tests/unit/argv_recipe_spec.lua
-- Decision tables for the recipe grammar both external-tool modules share.
local ar = require("parley.argv_recipe")

describe("argv_recipe: substitute / has_token", function()
    it("replaces whole-argument tokens only and never mutates the input", function()
        local argv = { "tool", "{in}", "x{in}y", "{out}", "{max}x{max}>" }
        local out = ar.substitute(argv, { ["{in}"] = "/a", ["{out}"] = "/b" })
        assert.same({ "tool", "/a", "x{in}y", "/b", "{max}x{max}>" }, out)
        assert.same({ "tool", "{in}", "x{in}y", "{out}", "{max}x{max}>" }, argv)
    end)
    it("has_token is whole-argument", function()
        assert.is_true(ar.has_token({ "a", "{out}" }, "{out}"))
        assert.is_false(ar.has_token({ "a", "x{out}" }, "{out}"))
        assert.is_false(ar.has_token({}, "{out}"))
    end)
    it("permits embedded tokens only when requested explicitly", function()
        assert.is_true(ar.has_token({ "{max}x{max}>" }, "{max}", true))
        assert.is_false(ar.has_token({ "x{out}" }, "{out}"))
    end)
    it("substitutes embedded numeric tokens without rescanning substituted paths", function()
        local argv = { "tool", "{in}", "{out}", "{max}x{max}>", "prefix{in}" }
        local paths = { ["{in}"] = "/tmp/{max}/input", ["{out}"] = "/tmp/out%1{max}" }
        assert.same({ "tool", paths["{in}"], paths["{out}"], "1600x1600>", "prefix{in}" },
            ar.substitute(argv, paths, { ["{max}"] = "1600" }))
        assert.equals("{max}x{max}>", argv[4])
    end)
end)

describe("argv_recipe: select", function()
    local words = { config_key = "assets.clipboard_cmd", tokens = { "{out}" },
        purpose = "for the PNG path to write", none = "no clipboard image tool found" }
    local candidates = {
        { tool = "one", argv = { "one", "{out}" }, install = "install one" },
        { tool = "two", argv = { "two", "{out}" }, install = "install two" },
    }
    local function exe(set) return function(t) return set[t] == true end end

    it("a configured argv wins verbatim when it carries every token", function()
        local r = ar.select({ "mine", "{out}" }, candidates, exe({}), words)
        assert.same({ tool = "mine", argv = { "mine", "{out}" }, install = nil }, r)
    end)
    it("a configured argv missing a token names the token, key and purpose", function()
        local r, err = ar.select({ "mine" }, candidates, exe({ one = true }), words)
        assert.is_nil(r)
        assert.equals("assets.clipboard_cmd must contain the {out} token (as its own argument) for the PNG path to write", err)
    end)
    it("an empty or non-table config falls through to the candidates", function()
        assert.equals(candidates[2], ar.select({}, candidates, exe({ two = true }), words))
        assert.equals(candidates[1], ar.select(nil, candidates, exe({ one = true, two = true }), words))
    end)
    it("no executable candidate → hints in order", function()
        local r, err = ar.select(nil, candidates, exe({}), words)
        assert.is_nil(r)
        assert.equals("no clipboard image tool found: install one or install two", err)
    end)
    it("several required tokens: the first missing one is named", function()
        local w = vim.tbl_extend("force", words, { tokens = { "{in}", "{out}" }, config_key = "assets.shrink_cmd", purpose = "for the image paths" })
        local _, err = ar.select({ "t", "{out}" }, candidates, exe({}), w)
        assert.equals("assets.shrink_cmd must contain the {in} token (as its own argument) for the image paths", err)
    end)
    it("validates configured numeric tokens with the same embedded grammar", function()
        local w = { config_key = "assets.shrink_cmd", tokens = { "{in}", "{out}" },
            embedded_tokens = { "{max}" }, purpose = "for image conversion", none = "none" }
        local cmd = { "magick", "{in}", "-resize", "{max}x{max}>", "{out}" }
        assert.same(cmd, ar.select(cmd, {}, exe({}), w).argv)
        local result, err = ar.select({ "tool", "{in}", "{out}" }, {}, exe({}), w)
        assert.is_nil(result)
        assert.matches("must contain the {max} token", err, 1, true)
        assert.is_nil(ar.select({ "tool", "embedded{in}", "{out}", "{max}" }, {}, exe({}), w))
    end)
end)
