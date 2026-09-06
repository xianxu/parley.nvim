-- Unit tests for lua/parley/branch_ref.lua — the pure half of "branch at this
-- point in the chat tree" (#214). Extracted from four near-identical copies;
-- it shipped with no tests at all, which is how a pure extraction quietly
-- becomes a fifth copy nobody checks (BR-2).

local br = require("parley.branch_ref")

describe("branch_ref.splice_inline_link", function()
    it("replaces the selected span with a link, preserving both sides", function()
        local out, sel = br.splice_inline_link("see the widget here", 9, 14, "🌿:", "f.md")
        assert.are.equal("see the [🌿:widget](f.md) here", out)
        assert.are.equal("widget", sel)
    end)

    it("handles a selection at the start of the line", function()
        local out, sel = br.splice_inline_link("widget here", 1, 6, "🌿:", "f.md")
        assert.are.equal("[🌿:widget](f.md) here", out)
        assert.are.equal("widget", sel)
    end)

    it("handles a selection at the end of the line", function()
        local out = br.splice_inline_link("see the widget", 9, 14, "🌿:", "f.md")
        assert.are.equal("see the [🌿:widget](f.md)", out)
    end)

    it("returns an empty selection for an inverted span, so callers can bail", function()
        local _, sel = br.splice_inline_link("abc", 3, 1, "🌿:", "f.md")
        assert.are.equal("", sel)
    end)
end)

describe("branch_ref.format_ref_line", function()
    it("formats a ref line with a topic", function()
        assert.are.equal("🌿: f.md: my topic", br.format_ref_line("🌿:", "f.md", "my topic"))
    end)

    it("tolerates a nil topic — the no-selection path has none yet", function()
        assert.are.equal("🌿: f.md: ", br.format_ref_line("🌿:", "f.md", nil))
    end)
end)

describe("branch_ref.topic_for_selection", function()
    it("quotes the selection so the child opens with a real question", function()
        assert.are.equal('what is "widget"', br.topic_for_selection("widget"))
    end)
end)

-- #214 BR-21: a topic is user-selected text and reaches a gsub REPLACEMENT,
-- where `%` is special. `what is "50% off"` used to raise "invalid use of '%'",
-- and a selection containing %1 silently substituted a capture.
describe("branch_ref.topic_for_selection with pattern metacharacters", function()
    it("survives a selection containing %", function()
        local topic = br.topic_for_selection("50% off")
        assert.are.equal('what is "50% off"', topic)
        local ok = pcall(function()
            return ("topic: ?"):gsub("topic: %?", function() return "topic: " .. topic end)
        end)
        assert.is_true(ok, "a % in the selection must not break template substitution")
    end)

    it("does not let %1 in a selection substitute a capture", function()
        local topic = br.topic_for_selection("%1 placeholder")
        local out = ("topic: ?"):gsub("topic: %?", function() return "topic: " .. topic end)
        assert.is_truthy(out:find("%%1 placeholder"), "got: " .. out)
    end)
end)
