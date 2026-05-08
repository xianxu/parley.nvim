-- Unit tests for lua/parley/drill_in.lua
-- See workshop/issues/000123-quoted-body-marker-syntax.md for the grammar.

local drill_in = require("parley.drill_in")

describe("drill_in.parse", function()
    it("parses a basic 🤖<T>[Q] drill-in marker", function()
        local markers = drill_in.parse("foo 🤖<Term>[What is this?] bar")
        assert.equals(1, #markers)
        local m = markers[1]
        assert.is_not_nil(m.quoted)
        assert.equals("Term", m.quoted.text)
        assert.equals(1, #m.sections)
        assert.equals("user", m.sections[1].type)
        assert.equals("What is this?", m.sections[1].text)
        assert.is_true(m.has_quoted_body)
        assert.is_true(m.ready)
        assert.is_false(m.pending)
    end)

    it("supports multi-line text inside <> and []", function()
        local markers = drill_in.parse("🤖<multi\nline term>[multi\nline question]")
        assert.equals(1, #markers)
        assert.equals("multi\nline term", markers[1].quoted.text)
        assert.equals("multi\nline question", markers[1].sections[1].text)
        assert.is_true(markers[1].ready)
    end)

    it("flags non-<T> (plain review) markers as has_quoted_body=false", function()
        local markers = drill_in.parse("🤖[just a comment]")
        assert.equals(1, #markers)
        assert.is_false(markers[1].has_quoted_body)
        assert.is_true(markers[1].ready)
    end)

    it("treats legacy 🤖{T}[Q] as plain review syntax (no quoted body)", function()
        -- Pre-#123 drill-ins are now parsed as {agent}[user]: not has_quoted_body.
        local markers = drill_in.parse("🤖{Old}[Q]")
        assert.equals(1, #markers)
        assert.is_false(markers[1].has_quoted_body)
        assert.equals("agent", markers[1].sections[1].type)
        assert.is_true(markers[1].ready)
    end)

    it("classifies pending when last section is non-empty {}", function()
        local markers = drill_in.parse("🤖<T>[Q]{A}")
        assert.equals(1, #markers)
        assert.is_false(markers[1].ready)
        assert.is_true(markers[1].pending)
    end)

    it("returns empty list when no markers", function()
        assert.equals(0, #drill_in.parse("plain text without any markers"))
    end)

    it("returns multiple markers in document order", function()
        local markers = drill_in.parse("🤖<A>[Qa] mid 🤖<B>[Qb]")
        assert.equals(2, #markers)
        assert.equals("A", markers[1].quoted.text)
        assert.equals("B", markers[2].quoted.text)
        assert.is_true(markers[1].byte_start < markers[2].byte_start)
    end)

    -- ── Edge cases (#123 review) ────────────────────────────────────
    it("normalizes empty 🤖<>[U] to no quoted body", function()
        -- Empty <> carries no information — treat it the same as a no-quote
        -- marker so downstream gather/resolve don't have to special-case it.
        local markers = drill_in.parse("🤖<>[ask]")
        assert.equals(1, #markers)
        assert.is_nil(markers[1].quoted)
        assert.is_false(markers[1].has_quoted_body)
        assert.is_true(markers[1].ready)
    end)

    it("ignores 🤖<unclosed [U] (malformed) — no marker emitted", function()
        -- An opening `<` without a matching `>` short-circuits the parser; the
        -- inner `[U]` is never consumed. Pinning this so a future refactor
        -- can't quietly change to recognizing the inner section.
        local markers = drill_in.parse("🤖<noclose [Q]")
        assert.equals(0, #markers)
    end)

    it("`>` inside [] / {} closes the <> early (parser limitation)", function()
        -- find_matching_bracket only depth-tracks the same bracket pair, so a
        -- `>` appearing inside a later `[` is still seen as the closer of `<`.
        -- Result: `🤖<a [b> c]` parses with quoted="a [b" and zero sections.
        -- Pinning this behavior; if it ever needs to change, the test must
        -- be updated explicitly.
        local markers = drill_in.parse("🤖<a [b> c]")
        assert.equals(1, #markers)
        assert.equals("a [b", markers[1].quoted.text)
        assert.equals(0, #markers[1].sections)
    end)
end)

describe("drill_in.gather_and_strip", function()
    it("converts 🤖<Q>[U] to a block and strips inline to Q", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "this is 🤖<RedShift>[what is this?] cool"
        )
        assert.equals(1, #blocks)
        assert.equals("RedShift", blocks[1].quoted)
        assert.equals(1, #blocks[1].sections)
        assert.equals("what is this?", blocks[1].sections[1].text)
        assert.equals("this is RedShift cool", new_text)
    end)

    it("strips 🤖[U] (no quote) and gathers the bare turn", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "preamble 🤖[just ask] tail"
        )
        assert.equals(1, #blocks)
        assert.is_nil(blocks[1].quoted)
        assert.equals("just ask", blocks[1].sections[1].text)
        -- Marker removed entirely (single space remains where it sat).
        assert.equals("preamble  tail", new_text)
    end)

    it("strips ready chain 🤖<Q>[U1]{A1}[U2]", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖<term>[Q1]{A1}[Q2] y"
        )
        assert.equals(1, #blocks)
        assert.equals("term", blocks[1].quoted)
        assert.equals(3, #blocks[1].sections)
        assert.equals("x term y", new_text)
    end)

    it("strips ready chain without <>", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖[Q1]{A1}[Q2] y"
        )
        assert.equals(1, #blocks)
        assert.is_nil(blocks[1].quoted)
        assert.equals(3, #blocks[1].sections)
        assert.equals("x  y", new_text)
    end)

    it("handles multiple ready markers in document order", function()
        local blocks, new_text = drill_in.gather_and_strip("🤖<A>[Qa] mid 🤖<B>[Qb]")
        assert.equals(2, #blocks)
        assert.equals("A", blocks[1].quoted)
        assert.equals("B", blocks[2].quoted)
        assert.equals("A mid B", new_text)
    end)

    it("leaves pending markers and bare {A} annotations untouched", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "🤖{annotation} 🤖<T>[Q] 🤖<T2>[Q2]{A2}"
        )
        assert.equals(1, #blocks)
        assert.equals("T", blocks[1].quoted)
        assert.equals("🤖{annotation} T 🤖<T2>[Q2]{A2}", new_text)
    end)

    it("handles multi-line content correctly", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖<multi\nline term>[multi\nline question] y"
        )
        assert.equals(1, #blocks)
        assert.equals("multi\nline term", blocks[1].quoted)
        assert.equals("multi\nline question", blocks[1].sections[1].text)
        assert.equals("x multi\nline term y", new_text)
    end)

    it("returns original text when there are no ready markers", function()
        local input = "plain 🤖<T>{A}"  -- has <> but ends in {} (pending)
        local blocks, new_text = drill_in.gather_and_strip(input)
        assert.equals(0, #blocks)
        assert.equals(input, new_text)
    end)
end)

describe("drill_in.resolve_all", function()
    it("strips all 🤖<T>... markers regardless of state", function()
        local new_text, count = drill_in.resolve_all(
            "x 🤖<T>[Q] y 🤖<T2>[Q2]{A2} z"
        )
        assert.equals("x T y T2 z", new_text)
        assert.equals(2, count)
    end)

    it("leaves markers without <> untouched", function()
        local new_text, count = drill_in.resolve_all("x 🤖[just review] 🤖{annotation} y")
        assert.equals("x 🤖[just review] 🤖{annotation} y", new_text)
        assert.equals(0, count)
    end)

    it("returns input unchanged when nothing to resolve", function()
        local new_text, count = drill_in.resolve_all("plain text")
        assert.equals("plain text", new_text)
        assert.equals(0, count)
    end)
end)

describe("drill_in.format_block", function()
    it("formats <Q>[U] as `> Q` then U", function()
        local lines = drill_in.format_block({
            quoted = "RedShift",
            sections = { { type = "user", text = "what is this?" } },
        })
        assert.same({ "> RedShift", "what is this?" }, lines)
    end)

    it("formats [U] (no quote) as just U", function()
        local lines = drill_in.format_block({
            quoted = nil,
            sections = { { type = "user", text = "just ask" } },
        })
        assert.same({ "just ask" }, lines)
    end)

    it("formats multi-line Q as multiple > lines, multi-line U verbatim", function()
        local lines = drill_in.format_block({
            quoted = "foo\nbar",
            sections = { { type = "user", text = "Q1\nQ2" } },
        })
        assert.same({ "> foo", "> bar", "Q1", "Q2" }, lines)
    end)

    it("formats <Q>[U1]{A1}[U2] chain", function()
        local lines = drill_in.format_block({
            quoted = "term",
            sections = {
                { type = "user", text = "U1" },
                { type = "agent", text = "A1" },
                { type = "user", text = "U2" },
            },
        })
        assert.same({
            "> term",
            "> User: U1",
            "> Agent: A1",
            "U2",
        }, lines)
    end)

    it("formats no-quote [U1]{A1}[U2] chain (no leading > line)", function()
        local lines = drill_in.format_block({
            quoted = nil,
            sections = {
                { type = "user", text = "U1" },
                { type = "agent", text = "A1" },
                { type = "user", text = "U2" },
            },
        })
        assert.same({
            "> User: U1",
            "> Agent: A1",
            "U2",
        }, lines)
    end)

    it("multi-line chain section continuation lines stay quoted", function()
        local lines = drill_in.format_block({
            quoted = "Q",
            sections = {
                { type = "user", text = "u1 line a\nu1 line b" },
                { type = "agent", text = "a1" },
                { type = "user", text = "final" },
            },
        })
        assert.same({
            "> Q",
            "> User: u1 line a",
            "> u1 line b",
            "> Agent: a1",
            "final",
        }, lines)
    end)
end)

describe("drill_in.format_blocks", function()
    it("joins multiple blocks with a single blank-line separator", function()
        local lines = drill_in.format_blocks({
            { quoted = "A", sections = { { type = "user", text = "Qa" } } },
            { quoted = "B", sections = { { type = "user", text = "Qb" } } },
        })
        assert.same({ "> A", "Qa", "", "> B", "Qb" }, lines)
    end)

    it("returns empty table for empty block list", function()
        assert.same({}, drill_in.format_blocks({}))
    end)
end)

describe("drill_in.wrap", function()
    it("wraps text as 🤖<T>[]", function()
        assert.equals("🤖<Term>[]", drill_in.wrap("Term"))
    end)

    it("wraps multi-line text", function()
        assert.equals("🤖<line one\nline two>[]", drill_in.wrap("line one\nline two"))
    end)
end)

describe("drill_in.append_blocks", function()
    it("appends with one blank-line separator when lines exist", function()
        local lines = { "💬: my question" }
        local blocks = { { quoted = "Term", sections = { { type = "user", text = "What?" } } } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: my question", "", "> Term", "What?" }, result)
    end)

    it("trims trailing empties before adding separator", function()
        local lines = { "💬: question", "", "" }
        local blocks = { { quoted = "T", sections = { { type = "user", text = "Q" } } } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: question", "", "> T", "Q" }, result)
    end)

    it("no separator when input lines are empty", function()
        local blocks = { { quoted = "T", sections = { { type = "user", text = "Q" } } } }
        local result = drill_in.append_blocks({}, blocks)
        assert.same({ "> T", "Q" }, result)
    end)

    it("returns input unchanged when blocks is empty", function()
        assert.same({ "a", "b" }, drill_in.append_blocks({ "a", "b" }, {}))
    end)

    it("joins multiple blocks with internal blank-line separators", function()
        local result = drill_in.append_blocks({ "🤖" }, {
            { quoted = "A", sections = { { type = "user", text = "Qa" } } },
            { quoted = "B", sections = { { type = "user", text = "Qb" } } },
        })
        assert.same({ "🤖", "", "> A", "Qa", "", "> B", "Qb" }, result)
    end)
end)
