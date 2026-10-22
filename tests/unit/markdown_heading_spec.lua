local heading = require("parley.markdown_heading")

-- Preserve an explicit nil result in luassert's varargs when the old resolver
-- returns no values, so RED reports the missing row rather than assert arity.
local function anchor_row(...)
    local row = heading.anchor_row(...)
    return row
end

describe("markdown_heading.level", function()
    it("returns the level for column-zero ATX headings", function()
        assert.equals(1, heading.level("# One"))
        assert.equals(2, heading.level("## Two"))
        assert.equals(3, heading.level("### Three"))
    end)

    it("requires a space after the hashes", function()
        assert.is_nil(heading.level("#NoSpace"))
        assert.is_nil(heading.level("##"))
    end)

    it("rejects indented headings and levels past the dialect cap", function()
        assert.is_nil(heading.level("  # Indented"))
        assert.is_nil(heading.level("#### Four"))
    end)

    it("rejects non-headings", function()
        assert.is_nil(heading.level(""))
        assert.is_nil(heading.level("plain text"))
        assert.is_nil(heading.level("💬: a question"))
        assert.is_nil(heading.level(nil))
    end)
end)


describe("Markdown link heading anchors (#407)", function()
    it("drops punctuation, keeps digits and skips fenced headings", function()
        local lines = {"```md", "## Revised plan ready (10-21: 0040)", "```", "# Intro",
            "## Revised plan ready (10-21: 0040)", "## Revised plan ready (10-21: 0040)"}
        assert.equals(5, anchor_row(lines, "revised-plan-ready-10-21-0040"))
        assert.equals(6, anchor_row(lines, "revised-plan-ready-10-21-0040-1"))
        assert.is_nil(anchor_row(lines, "absent"))
    end)
    it("accepts percent-encoded fragments and ATX closing hashes", function()
        assert.equals(1, anchor_row({"#### Keep_this: 42! ###"}, "keep_this%2D42"))
    end)
    it("matches heading edges and alternate whitespace canonically", function()
        for _, case in ipairs({
            { "Target  \t", "target" }, { "Target\tName", "targetname" },
            { "Target  Name", "target--name" }, { "\t Target \t ###  ", "target" },
        }) do
            assert.equals(1, anchor_row({ "# " .. case[1] }, case[2]), case[1])
        end
    end)
    it("matches parsed inline content rather than markup and destinations", function()
        for _, text in ipairs({
            "_Target_", "__Target__", "**Target**", "***Target***", "~~Target~~",
            "`Target`", "[Target](file.md)", "[**Target**](file(name).md)",
            "**_Target_**",
        }) do
            assert.equals(1, anchor_row({"# " .. text}, "target"), text)
        end
    end)
    it("matches literal underscores in words, escaped text and inline code", function()
        for _, case in ipairs({
            { "keep_this", "keep_this" }, { "keep_this_name", "keep_this_name" },
            { "`_keep_this_`", "_keep_this_" }, { "``_keep_this_``", "_keep_this_" },
            { "\\_keep_this\\_", "_keep_this_" },
        }) do
            assert.equals(1, anchor_row({ "# " .. case[1] }, case[2]), case[1])
        end
    end)
    it("numbers duplicates after content normalization", function()
        local lines = { "# Target", "# _Target_", "# [Target](file.md)", "# **Target**  " }
        for row = 1, #lines do
            assert.equals(row, anchor_row(lines, row == 1 and "target" or "target-" .. (row - 1)), "row " .. row)
        end
    end)
    it("retains autolink text rather than treating it as an HTML tag", function()
        assert.equals(1, anchor_row({ "# <https://example.com>" }, "httpsexamplecom"), "autolink")
    end)
    it("matches autolink punctuation through the same canonical key", function()
        assert.equals(1, anchor_row({ "# <https://example.com/_literal_>" },
            "httpsexamplecom_literal_"), "literal URL path")
        assert.equals(1, anchor_row({ "# <_literal_@example.com>" },
            "_literal_examplecom"), "literal email address")
    end)
    it("declines out-of-scope HTML and entity references without inventing raw-text anchors", function()
        for _, case in ipairs({
            {"# <em>Target</em>", "target"}, {"# <em title='> more'>Target</em>", "moretarget"},
            {"# <!-- hidden -->Target", "target"}, {"# &#84;arget", "84arget"},
            {"# &#x54;arget", "x54arget"}, {"# &amp; Target", "amp-target"},
            {"<h1>Target</h1>", "target"}, {"# Before &amp; Target", "before-amp-target"},
        }) do
            assert.is_nil(anchor_row({case[1]}, case[2]), case[1])
        end
        assert.equals(1, anchor_row({"# `<em>Target</em>`"}, "emtargetem"))
        assert.equals(1, anchor_row({"# `&#84;arget`"}, "84arget"))
        assert.equals(1, anchor_row({"# \\&amp; Target"}, "amp-target"))
        assert.equals(2, anchor_row({"# <em>Target</em>", "# Target"}, "target"))
    end)
    it("keeps false fence closers from exposing example headings", function()
        for _, fences in ipairs({
            { "````md", "```", "````" }, { "~~~~md", "~~~", "~~~~" },
            { "```md", "~~~", "```" }, { "~~~md", "```", "~~~" },
        }) do
            local lines = { fences[1], fences[2], "# Fake", fences[3], "# Real" }
            assert.is_nil(anchor_row(lines, "fake"))
            assert.equals(5, anchor_row(lines, "real"), fences[1])
        end
    end)
end)


describe("parser-based canonical heading keys (#407)", function()
    for _, case in ipairs({
        { name = "nested underscores", text = "_one _two_ three_", plain = "one two three", fragment = "one-two-three" },
        { name = "mixed underscore runs", text = "_Target __more___", plain = "Target more", fragment = "target-more" },
        { name = "code-span padding", text = "` a ` b", plain = "a b", fragment = "a-b" },
        { name = "link titles with unmatched destination punctuation", text = '[Target](file.md "(title")',
            plain = "Target", fragment = "target" },
    }) do
        it("matches the first heading with " .. case.name, function()
            assert.equals(1, anchor_row({ "# " .. case.text }, case.fragment))
        end)
        it("matches the duplicate heading after " .. case.name, function()
            local lines = { "# " .. case.text, "# " .. case.plain }
            assert.equals(1, anchor_row(lines, case.fragment))
            assert.equals(2, anchor_row(lines, case.fragment .. "-1"))
        end)
    end

    it("canonicalizes punctuation, spacing, underscores and case on both sides", function()
        for _, fragment in ipairs({ "target-more-42", "TARGET_more:42", "targetmore42", "target%20MORE__42" }) do
            assert.equals(1, anchor_row({ "# Target / more (42)" }, fragment), fragment)
        end
    end)

    it("keeps CJK letters instead of merging unrelated headings into an empty key", function()
        local lines = { "# 中文 标题", "# 其他标题", "# 中文标题" }
        assert.equals(1, anchor_row(lines, "中文-标题"))
        assert.equals(2, anchor_row(lines, "其他标题"))
        assert.equals(3, anchor_row(lines, "中文-标题-1"))
    end)

    it("preserves accented codepoints while lowercasing ASCII letters", function()
        local lines = { "# Été à Montréal", "# Ete a Montreal", "# Été à Montréal" }
        assert.equals(1, anchor_row(lines, "Été-à-montréal"))
        assert.equals(2, anchor_row(lines, "ete-a-montreal"))
        assert.equals(3, anchor_row(lines, "Été_à_MONTRéAL-1"))
    end)

    it("drops General and CJK punctuation but keeps other non-ASCII codepoints", function()
        assert.equals(1, anchor_row({ "# 中文—‘计划’、。" }, "中文计划"))
        assert.equals(1, anchor_row({ "# ‘Été’ — café" }, "Été-café"))
        assert.equals(1, anchor_row({ "# Party 🎉" }, "party-🎉"))
        assert.is_nil(anchor_row({ "# Party 🎉" }, "party"))
        assert.is_nil(anchor_row({ "# ÉTÉ" }, "été"))
    end)

    it("retains Unicode digits in heading keys", function()
        local lines = { "# 计划 １２٣", "# 计划", "# 计划１２٣" }
        assert.equals(1, anchor_row(lines, "计划-１２٣"))
        assert.equals(2, anchor_row(lines, "计划"))
        assert.equals(3, anchor_row(lines, "计划-１２٣-1"))
    end)

    it("resolves a full numeric fragment before interpreting a duplicate suffix", function()
        local lines = { "# 10 21", "# 10 21", "# 10-21-0040" }
        assert.equals(3, anchor_row(lines, "10-21-0040"))
        assert.equals(2, anchor_row(lines, "10-21-1"))
    end)

    it("prefers a natural heading ending in a number over a duplicate", function()
        local lines = { "# Topic", "# Topic", "# Topic 1" }
        assert.equals(3, anchor_row(lines, "topic-1"))
        assert.equals(2, anchor_row({ "# Topic", "# Topic" }, "topic-1"))
    end)

    it("never matches an empty key", function()
        for _, fragment in ipairs({ "", "---", "%20", "—“”、。" }) do
            assert.is_nil(anchor_row({ "# !!!", "# —“”、。" }, fragment), fragment)
        end
    end)

    it("falls back to raw heading keys when the inline grammar is unavailable", function()
        local unavailable = { parse = function() error("grammar unavailable") end }
        assert.equals(1, anchor_row({ "# 中文 Été 42" }, "中文-Été-42", unavailable))
        assert.equals(1, anchor_row({ "# 10-21-0040" }, "10-21-0040", unavailable))
        assert.is_nil(anchor_row({ "# [Target](file.md)" }, "target", unavailable))
    end)

    it("falls back to raw heading keys when parsing returns no root", function()
        local unavailable = { parse = function() return nil end }
        assert.equals(1, anchor_row({ "# Été 中文" }, "Été-中文", unavailable))
        assert.is_nil(anchor_row({ "# [Target](file.md)" }, "target", unavailable))
    end)

    it("returns no match for malformed inline input without throwing", function()
        assert.is_nil(anchor_row({ "# " .. string.rep("<a", 256) }, "absent"))
    end)
end)
