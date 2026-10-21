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
end)
