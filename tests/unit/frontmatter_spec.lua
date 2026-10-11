-- #316: the shared frontmatter reader — hyphenated keys, raw values, quoting.
local fm = require("parley.frontmatter")

describe("frontmatter.parse", function()
    it("reads hyphenated keys, raw and plain values, and their lines", function()
        local r = fm.parse({
            "---",
            "type: session-sync",
            "Process-Instruction: [copy-edit] keep # the voice",
            "owner: ops:0 # who",
            "---",
            "body",
        })
        assert.equals("session-sync", r.fields.type)
        assert.equals("[copy-edit] keep # the voice", r.raw["process-instruction"])
        assert.equals("[copy-edit] keep", r.fields["process-instruction"])
        assert.equals("ops:0", r.fields.owner)
        assert.equals(3, r.lnum["process-instruction"])
        assert.equals(5, r.close)
    end)

    it("unquotes a quoted value, keeping a # inside it", function()
        local r = fm.parse({ "---", 'process-instruction: "[x] a # b"', "---" })
        assert.equals("[x] a # b", r.fields["process-instruction"])
        assert.equals('"[x] a # b"', r.raw["process-instruction"])
    end)

    it("is nil without an opening or a closing fence", function()
        assert.is_nil(fm.parse({ "# title", "a: b" }))
        assert.is_nil(fm.parse({ "---", "a: b" }))
    end)

    it("leaves an empty value unset in fields", function()
        local r = fm.parse({ "---", "a:", "---" })
        assert.is_nil(r.fields.a)
        assert.equals("", r.raw.a)
    end)
end)

describe("frontmatter quoting", function()
    it("round-trips strings built from its own delimiters", function()
        local atoms = { '"', "\\", "[", "]", "#", ": ", "'", "x", " " }
        -- Every 3-atom combination: the escape must be injective over them.
        for _, a in ipairs(atoms) do
            for _, b in ipairs(atoms) do
                for _, c in ipairs(atoms) do
                    local s = a .. b .. c
                    assert.equals(s, fm.unquote(fm.quote(s)), "round-trip of " .. s)
                    local r = fm.parse({ "---", "k: " .. fm.quote(s), "---" })
                    assert.equals(s, fm.unquote(r.raw.k))
                end
            end
        end
    end)

    it("unquotes single-quoted YAML", function()
        assert.equals("it's", fm.unquote("'it''s'"))
    end)

    it("knows which plain values a strict YAML reader rejects", function()
        assert.is_true(fm.needs_quote("[copy-edit] keep the voice"))
        assert.is_true(fm.needs_quote("note: this"))
        assert.is_true(fm.needs_quote("a # b"))
        assert.is_true(fm.needs_quote('"half'))
        assert.is_false(fm.needs_quote("keep the voice"))
        assert.is_false(fm.needs_quote("ratio 3:1"))
    end)
end)
