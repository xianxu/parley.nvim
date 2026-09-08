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
    -- #214 M3: the topic becomes the child's `topic:` header and therefore its
    -- filename slug, so it names the SUBJECT. It used to return
    -- `what is "widget"`, which put a question form in every branched filename.
    -- The question wording moved to branch_submit.seed_question.
    it("is the selected text, so the slug names the subject", function()
        assert.are.equal("widget", br.topic_for_selection("widget"))
    end)

    it("collapses internal whitespace so a multi-line selection still slugs", function()
        assert.are.equal("monad transformers",
            br.topic_for_selection("  monad\n  transformers  "))
    end)

    -- The caller must reject this, and #214 BR-86 found that it did not: the
    -- visual path guarded `selected == ""`, and "   " is not "". Asserted at the
    -- call site in branch_child_spec, not just here.
    it("a whitespace-only selection derives the empty topic callers must reject", function()
        assert.are.equal("", br.topic_for_selection("   "))
        assert.are.equal("", br.topic_for_selection("\n\t "))
    end)
end)

-- #214 BR-68: "one blank line each side" was claimed in three artifacts and
-- held by neither insert path — one emitted a blank before only, the other no
-- blanks at all. The tests that "covered" it passed because their fixtures
-- happened to have a blank in the right place.
describe("branch_ref.ref_block", function()
    it("adds a blank on each side when the neighbours are prose", function()
        assert.same({ "", "🌿: x", "" }, br.ref_block("🌿: x", "above", "below"))
    end)

    it("does not double a blank that is already there", function()
        assert.same({ "🌿: x" }, br.ref_block("🌿: x", "", ""))
        assert.same({ "🌿: x", "" }, br.ref_block("🌿: x", "", "below"))
        assert.same({ "", "🌿: x" }, br.ref_block("🌿: x", "above", ""))
    end)

    it("treats the buffer edges as already-blank", function()
        assert.same({ "🌿: x" }, br.ref_block("🌿: x", nil, nil))
    end)

    it("treats a whitespace-only line as blank", function()
        assert.same({ "🌿: x" }, br.ref_block("🌿: x", "   ", "\t"))
    end)
end)
