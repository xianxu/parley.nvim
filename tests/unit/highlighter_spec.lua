-- Unit tests for lua/parley/highlighter.lua pure predicates.

local highlighter = require("parley.highlighter")

-- Run M.is_reference_span over the FIRST `[...]` run in `line`, mirroring how
-- compute_markdown_highlights calls it. `match` returns the first run's
-- captures directly (a gmatch loop here is "executed at most once").
local function first_span_is_reference(line)
    local s, content, e = line:match("()%[([^%[%]]+)%]()")
    if not s then
        return nil -- no bracket run at all
    end
    return highlighter.is_reference_span(line, s, content, e)
end

describe("highlighter.is_reference_span (#127)", function()
    it("accepts a flattened reference span after ordinary prose", function()
        assert.is_true(first_span_is_reference("the [train on Soviet soil] dodged it"))
        assert.is_true(first_span_is_reference("They [rearmed in secret] really"))
        assert.is_true(first_span_is_reference("see [RedShift] cool")) -- single-word explicit quote
    end)

    it("rejects a markdown link", function()
        assert.is_false(first_span_is_reference("see the [docs](http://x) here"))
    end)

    it("rejects a footnote reference", function()
        assert.is_false(first_span_is_reference("a claim [^1] needs backing"))
    end)

    it("rejects 1-char content (checkboxes / citations)", function()
        assert.is_false(first_span_is_reference("- [ ] todo"))
        assert.is_false(first_span_is_reference("- [x] done"))
        assert.is_false(first_span_is_reference("ref [1] there"))
    end)

    it("rejects a live 🤖 marker's bare [U] section (preceded by 🤖)", function()
        assert.is_false(first_span_is_reference("🤖[my comment in progress]"))
    end)

    it("rejects a live marker's [U] chained after a section close or quote", function()
        -- first `[...]` follows `>` (close of <Q>)
        assert.is_false(first_span_is_reference("🤖<scope>[the question]"))
        -- first `[...]` follows `}` (close of {A})
        assert.is_false(first_span_is_reference("🤖{ans}[then ask]"))
    end)

    it("accepts an explicit-quote span [Q] once flattened (preceded by prose)", function()
        -- After flatten the marker is gone; `[Q]` follows a space, not 🤖.
        assert.is_true(first_span_is_reference("this is [RedShift] cool"))
    end)
end)
