-- Unit tests for lua/parley/define.lua (pure core).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

local define = require("parley.define")

describe("define.slice_selection", function()
    local lines = { "the quick brown", "fox jumps over", "the lazy dog" }

    it("extracts a single-line span", function()
        -- select "quick" on line 1: 0-based cols [4,8] (inclusive end)
        assert.equals("quick", define.slice_selection(lines, 1, 4, 1, 8))
    end)

    it("extracts a multi-line span joined with newline", function()
        -- "brown" .. "\n" .. "fox"
        assert.equals("brown\nfox", define.slice_selection(lines, 1, 10, 2, 2))
    end)

    it("clamps an end column past line length", function()
        assert.equals("dog", define.slice_selection(lines, 3, 9, 3, 999))
    end)

    it("returns empty string for a reversed/empty span", function()
        assert.equals("", define.slice_selection(lines, 1, 5, 1, 4))
    end)
end)

describe("define.context_for_selection", function()
    local all_lines = {}
    for i = 1, 20 do
        all_lines[i] = "line " .. i
    end
    local parsed = {
        exchanges = {
            { question = { line_start = 3, line_end = 4 }, answer = { line_start = 5, line_end = 8 } },
            { question = { line_start = 10, line_end = 10 }, answer = nil },
        },
    }
    -- injected finder: idx if sel_line within [q.start, (a and a.end or q.end)]
    local function finder(pc, line)
        for i, ex in ipairs(pc.exchanges) do
            local lo = ex.question.line_start
            local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
            if line >= lo and line <= hi then
                return i, "question"
            end
        end
        return nil, nil
    end

    it("returns the enclosing exchange's lines (question..answer)", function()
        local ctx = define.context_for_selection(parsed, 6, all_lines, finder)
        assert.equals("line 3\nline 4\nline 5\nline 6\nline 7\nline 8", ctx)
    end)

    it("handles an answerless exchange (question only)", function()
        local ctx = define.context_for_selection(parsed, 10, all_lines, finder)
        assert.equals("line 10", ctx)
    end)

    it("falls back to the whole buffer when outside any exchange", function()
        local ctx = define.context_for_selection(parsed, 1, all_lines, finder)
        assert.equals(table.concat(all_lines, "\n"), ctx)
    end)
end)

describe("define.format_definition", function()
    it("composes 'TERM — definition'", function()
        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
        assert.equals("ASIN — Amazon Standard Identification Number.", msg)
    end)

    it("hard-wraps to width", function()
        local msg = define.format_definition("X", string.rep("word ", 30), 40)
        for _, l in ipairs(vim.split(msg, "\n", { plain = true })) do
            assert.is_true(#l <= 40)
        end
    end)

    it("trims a nil/blank definition to a safe string", function()
        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
    end)
end)

describe("define.bracket_edit", function()
    it("wraps a single-line span into a set_lines edit", function()
        -- "here is ASIN in context": ASIN at 0-based cols 8..11 inclusive
        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
        assert.are.equal(0, e.first0)
        assert.are.equal(1, e.last)
        assert.are.same({ "here is [ASIN] in context" }, e.lines)
    end)

    it("clamps end col past line length", function()
        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
        assert.are.same({ "the lazy [dog]" }, e.lines)
    end)

    it("wraps a multi-line span", function()
        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
        assert.are.equal(0, e.first0)
        assert.are.equal(3, e.last)
        assert.are.same({ "brown [fox", "jumps over", "the] dog" }, e.lines)
    end)
end)
