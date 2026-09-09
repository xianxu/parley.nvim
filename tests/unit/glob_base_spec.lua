-- helper.glob_base — the directory part of a glob-ish reference (#225).
--
-- PURE, and single-sourced: this derivation had two near-copies (helper's
-- process_directory_pattern and the @@-reference chain in init.lua) that
-- stripped different shapes. Neither was wrong; the pair could drift.

local helpers = require("parley.helper")

describe("helper.glob_base", function()
    local cases = {
        { "a/b/**/*.md", "a/b" },
        { "a/b/**/*",    "a/b" },
        { "a/b/**/",     "a/b" },
        { "a/b/*.md",    "a/b" },
        { "a/b/*",       "a/b" },
        { "a/b/",        "a/b" },
        { "/abs/dir/",   "/abs/dir" },
        -- not a glob: left alone, so a plain file reference is unharmed
        { "a/b/c.md",    "a/b/c.md" },
        { "/abs/c.md",   "/abs/c.md" },
        { "plain",       "plain" },
    }
    for _, c in ipairs(cases) do
        it(("%q -> %q"):format(c[1], c[2]), function()
            assert.equals(c[2], helpers.glob_base(c[1]))
        end)
    end

    it("agrees with what process_directory_pattern needs", function()
        -- The behaviour that mattered at the old call site: a recursive spec
        -- and its non-recursive sibling reduce to the same directory.
        assert.equals(helpers.glob_base("x/y/*.lua"), helpers.glob_base("x/y/**/*.lua"))
    end)
end)
