local heading = require("parley.markdown_heading")

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
        assert.equals(5, heading.anchor_row(lines, "revised-plan-ready-10-21-0040"))
        assert.equals(6, heading.anchor_row(lines, "revised-plan-ready-10-21-0040-1"))
        assert.is_nil(heading.anchor_row(lines, "absent"))
    end)
    it("accepts percent-encoded fragments and ATX closing hashes", function()
        assert.equals(1, heading.anchor_row({"#### Keep_this: 42! ###"}, "keep_this%2D42"))
    end)
    it("trims heading edges and removes non-space whitespace before slugging", function()
        for _, case in ipairs({
            { "Target  \t", "target" }, { "Target\tName", "targetname" },
            { "Target  Name", "target--name" }, { "\t Target \t ###  ", "target" },
        }) do
            assert.equals(1, heading.anchor_row({ "# " .. case[1] }, case[2]), case[1])
        end
    end)
    it("slugs rendered inline content rather than markup and destinations", function()
        for _, text in ipairs({
            "_Target_", "__Target__", "**Target**", "***Target***", "~~Target~~",
            "`Target`", "[Target](file.md)", "[**Target**](file(name).md)",
            '<em class="label">Target</em>', "**_Target_**",
        }) do
            assert.equals(1, heading.anchor_row({"# " .. text}, "target"), text)
        end
    end)
    it("preserves literal underscores in words, escaped text and inline code", function()
        for _, case in ipairs({
            { "keep_this", "keep_this" }, { "keep_this_name", "keep_this_name" },
            { "`_keep_this_`", "_keep_this_" }, { "``_keep_this_``", "_keep_this_" },
            { "\\_keep_this\\_", "_keep_this_" },
        }) do
            assert.equals(1, heading.anchor_row({ "# " .. case[1] }, case[2]), case[1])
        end
    end)
    it("numbers duplicates after content normalization", function()
        local lines = { "# Target", "# _Target_", "# [Target](file.md)", "# <em>Target</em>  " }
        for row = 1, #lines do
            assert.equals(row, heading.anchor_row(lines, row == 1 and "target" or "target-" .. (row - 1)), "row " .. row)
        end
    end)
    it("trims whitespace exposed by removing inline HTML", function()
        assert.equals(1, heading.anchor_row({ "# <em> Target </em>" }, "target"), "rendered edges")
    end)
    it("retains autolink text rather than treating it as an HTML tag", function()
        assert.equals(1, heading.anchor_row({ "# <https://example.com>" }, "httpsexamplecom"), "autolink")
    end)
    it("keeps autolink underscores literal instead of treating them as emphasis", function()
        assert.equals(1, heading.anchor_row({ "# <https://example.com/_literal_>" },
            "httpsexamplecom_literal_"), "literal URL path")
        assert.equals(1, heading.anchor_row({ "# <_literal_@example.com>" },
            "_literal_examplecom"), "literal email address")
    end)
    it("removes inline HTML comments from heading content", function()
        assert.equals(1, heading.anchor_row({ "# <!-- hidden -->Target<!-- hidden -->" }, "target"), "comment")
    end)
    it("keeps false fence closers from exposing example headings", function()
        for _, fences in ipairs({
            { "````md", "```", "````" }, { "~~~~md", "~~~", "~~~~" },
            { "```md", "~~~", "```" }, { "~~~md", "```", "~~~" },
        }) do
            local lines = { fences[1], fences[2], "# Fake", fences[3], "# Real" }
            assert.is_nil(heading.anchor_row(lines, "fake"))
            assert.equals(5, heading.anchor_row(lines, "real"), fences[1])
        end
    end)
end)


describe("anchor normalization scan budget (#407)", function()
    it("does not repeatedly search a malformed HTML suffix", function()
        local function searched(n)
            local text = "# " .. string.rep("<a", n)
            local find, bytes = string.find, 0
            rawset(string, "find", function(value, needle, first, plain)
                if needle == ">" and plain then bytes = bytes + #value - (first or 1) + 1 end
                return find(value, needle, first, plain)
            end)
            local ok, err = pcall(heading.anchor_row, {text}, "absent")
            rawset(string, "find", find)
            assert.is_true(ok, err)
            assert.is_true(bytes <= #text)
            return bytes
        end
        assert.is_true(searched(256) <= 2 * searched(128) + 4)
    end)
end)
