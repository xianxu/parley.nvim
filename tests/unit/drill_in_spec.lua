-- Unit tests for lua/parley/drill_in.lua

local drill_in = require("parley.drill_in")

describe("drill_in.parse", function()
    it("parses a basic 🤖{T}[Q] drill-in marker", function()
        local markers = drill_in.parse("foo 🤖{Term}[What is this?] bar")
        assert.equals(1, #markers)
        local m = markers[1]
        assert.equals(2, #m.sections)
        assert.equals("agent", m.sections[1].type)
        assert.equals("Term", m.sections[1].text)
        assert.equals("user", m.sections[2].type)
        assert.equals("What is this?", m.sections[2].text)
        assert.is_true(m.has_quoted_body)
        assert.is_true(m.ready)
        assert.is_false(m.pending)
    end)

    it("supports multi-line text inside {} and []", function()
        local markers = drill_in.parse("🤖{multi\nline term}[multi\nline question]")
        assert.equals(1, #markers)
        assert.equals("multi\nline term", markers[1].sections[1].text)
        assert.equals("multi\nline question", markers[1].sections[2].text)
        assert.is_true(markers[1].ready)
    end)

    it("flags non-{T} (plain review) markers as has_quoted_body=false", function()
        local markers = drill_in.parse("🤖[just a comment]")
        assert.equals(1, #markers)
        assert.is_false(markers[1].has_quoted_body)
        assert.is_true(markers[1].ready)
    end)

    it("classifies pending when last section is non-empty {}", function()
        local markers = drill_in.parse("🤖{T}[Q]{A}")
        assert.equals(1, #markers)
        assert.is_false(markers[1].ready)
        assert.is_true(markers[1].pending)
    end)

    it("returns empty list when no markers", function()
        assert.equals(0, #drill_in.parse("plain text without any markers"))
    end)

    it("returns multiple markers in document order", function()
        local markers = drill_in.parse("🤖{A}[Qa] mid 🤖{B}[Qb]")
        assert.equals(2, #markers)
        assert.equals("A", markers[1].sections[1].text)
        assert.equals("B", markers[2].sections[1].text)
        assert.is_true(markers[1].byte_start < markers[2].byte_start)
    end)
end)

describe("drill_in.gather_and_strip", function()
    it("converts a single ready drill-in to a block and strips to T", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "this is 🤖{RedShift}[what is this?] cool"
        )
        assert.equals(1, #blocks)
        assert.equals("RedShift", blocks[1].quoted)
        assert.equals("what is this?", blocks[1].question)
        assert.equals("this is RedShift cool", new_text)
    end)

    it("handles multiple drill-ins in document order", function()
        local blocks, new_text = drill_in.gather_and_strip("🤖{A}[Qa] mid 🤖{B}[Qb]")
        assert.equals(2, #blocks)
        assert.equals("A", blocks[1].quoted)
        assert.equals("Qa", blocks[1].question)
        assert.equals("B", blocks[2].quoted)
        assert.equals("Qb", blocks[2].question)
        assert.equals("A mid B", new_text)
    end)

    it("leaves non-{T} review markers and pending markers untouched", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "🤖[review only] 🤖{T}[Q] 🤖{T2}[Q2]{A}"
        )
        assert.equals(1, #blocks)
        assert.equals("T", blocks[1].quoted)
        assert.equals("Q", blocks[1].question)
        assert.equals("🤖[review only] T 🤖{T2}[Q2]{A}", new_text)
    end)

    it("handles multi-line content correctly", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖{multi\nline term}[multi\nline question] y"
        )
        assert.equals(1, #blocks)
        assert.equals("multi\nline term", blocks[1].quoted)
        assert.equals("multi\nline question", blocks[1].question)
        assert.equals("x multi\nline term y", new_text)
    end)

    it("returns original text when there are no ready drill-ins", function()
        local input = "plain text 🤖[review marker only]"
        local blocks, new_text = drill_in.gather_and_strip(input)
        assert.equals(0, #blocks)
        assert.equals(input, new_text)
    end)
end)

describe("drill_in.resolve_all", function()
    it("strips all 🤖{T}[..].. markers regardless of ready/pending state", function()
        local new_text, count = drill_in.resolve_all(
            "x 🤖{T}[Q] y 🤖{T2}[Q2]{A2} z"
        )
        assert.equals("x T y T2 z", new_text)
        assert.equals(2, count)
    end)

    it("leaves non-{T} (review-style) markers untouched", function()
        local new_text, count = drill_in.resolve_all("x 🤖[just review] y")
        assert.equals("x 🤖[just review] y", new_text)
        assert.equals(0, count)
    end)

    it("returns input unchanged when nothing to resolve", function()
        local new_text, count = drill_in.resolve_all("plain text")
        assert.equals("plain text", new_text)
        assert.equals(0, count)
    end)
end)

describe("drill_in.format_block / format_blocks", function()
    it("formats single block with single-line T and Q", function()
        assert.same(
            { "> RedShift", "what is this?" },
            drill_in.format_block("RedShift", "what is this?")
        )
    end)

    it("formats multi-line T as multiple > lines, multi-line Q verbatim", function()
        assert.same(
            { "> foo", "> bar", "Q1", "Q2" },
            drill_in.format_block("foo\nbar", "Q1\nQ2")
        )
    end)

    it("joins multiple blocks with a single blank-line separator", function()
        local lines = drill_in.format_blocks({
            { quoted = "A", question = "Qa" },
            { quoted = "B", question = "Qb" },
        })
        assert.same({ "> A", "Qa", "", "> B", "Qb" }, lines)
    end)

    it("returns empty table for empty block list", function()
        assert.same({}, drill_in.format_blocks({}))
    end)
end)

describe("drill_in.wrap", function()
    it("wraps text as 🤖{T}[]", function()
        assert.equals("🤖{Term}[]", drill_in.wrap("Term"))
    end)

    it("wraps multi-line text", function()
        assert.equals("🤖{line one\nline two}[]", drill_in.wrap("line one\nline two"))
    end)
end)

describe("drill_in.append_blocks", function()
    it("appends with one blank-line separator when lines exist", function()
        local lines = { "💬: my question" }
        local blocks = { { quoted = "Term", question = "What?" } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: my question", "", "> Term", "What?" }, result)
    end)

    it("trims trailing empties before adding separator", function()
        local lines = { "💬: question", "", "" }
        local blocks = { { quoted = "T", question = "Q" } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: question", "", "> T", "Q" }, result)
    end)

    it("no separator when input lines are empty", function()
        local result = drill_in.append_blocks({}, { { quoted = "T", question = "Q" } })
        assert.same({ "> T", "Q" }, result)
    end)

    it("returns input unchanged when blocks is empty", function()
        assert.same({ "a", "b" }, drill_in.append_blocks({ "a", "b" }, {}))
    end)

    it("joins multiple blocks with internal blank-line separators", function()
        local result = drill_in.append_blocks({ "🤖" }, {
            { quoted = "A", question = "Qa" },
            { quoted = "B", question = "Qb" },
        })
        assert.same({ "🤖", "", "> A", "Qa", "", "> B", "Qb" }, result)
    end)
end)
