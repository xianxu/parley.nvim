-- Unit tests for lua/parley/review.lua — parse_markers and apply_edits

local review = require("parley.review")

describe("parse_markers", function()
    it("parses a simple single-section marker", function()
        local markers = review.parse_markers({ "Hello ㊷[too offensive] world" })
        assert.equals(1, #markers)
        assert.equals(0, markers[1].line)
        assert.equals(1, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("too offensive", markers[1].sections[1].text)
        assert.is_true(markers[1].ready)
    end)

    it("parses a two-section marker (user + agent question)", function()
        local markers = review.parse_markers({ "㊷[comment]{question?}" })
        assert.equals(1, #markers)
        assert.equals(2, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("comment", markers[1].sections[1].text)
        assert.equals("agent", markers[1].sections[2].type)
        assert.equals("question?", markers[1].sections[2].text)
        assert.is_false(markers[1].ready)  -- even count = awaiting user
    end)

    it("parses a three-section marker (user + agent + user reply)", function()
        local markers = review.parse_markers({ "㊷[offensive]{which part?}[the joke]" })
        assert.equals(1, #markers)
        assert.equals(3, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("agent", markers[1].sections[2].type)
        assert.equals("user", markers[1].sections[3].type)
        assert.equals("the joke", markers[1].sections[3].text)
        assert.is_true(markers[1].ready)  -- odd count = ready
    end)

    it("handles multiple markers on the same line", function()
        local markers = review.parse_markers({ "㊷[first] text ㊷[second]" })
        assert.equals(2, #markers)
        assert.equals("first", markers[1].sections[1].text)
        assert.equals("second", markers[2].sections[1].text)
    end)

    it("handles markers on different lines", function()
        local markers = review.parse_markers({
            "Line one ㊷[fix this]",
            "Line two is fine",
            "Line three ㊷[rewrite]{how?}",
        })
        assert.equals(2, #markers)
        assert.equals(0, markers[1].line)
        assert.equals(2, markers[2].line)
        assert.is_true(markers[1].ready)
        assert.is_false(markers[2].ready)
    end)

    it("skips markers inside fenced code blocks", function()
        local markers = review.parse_markers({
            "Before",
            "```",
            "㊷[inside code fence]",
            "```",
            "㊷[outside code fence]",
        })
        assert.equals(1, #markers)
        assert.equals(4, markers[1].line)
        assert.equals("outside code fence", markers[1].sections[1].text)
    end)

    it("skips markers inside fenced code blocks with language tag", function()
        local markers = review.parse_markers({
            "```lua",
            "㊷[inside]",
            "```",
            "㊷[outside]",
        })
        assert.equals(1, #markers)
        assert.equals("outside", markers[1].sections[1].text)
    end)

    it("handles unclosed code fence (extends to end)", function()
        local markers = review.parse_markers({
            "```",
            "㊷[inside unclosed]",
            "more text",
        })
        assert.equals(0, #markers)
    end)

    it("handles nested brackets in user comment", function()
        local markers = review.parse_markers({ "㊷[comment with [nested] brackets]" })
        assert.equals(1, #markers)
        assert.equals("comment with [nested] brackets", markers[1].sections[1].text)
    end)

    it("handles nested curly braces in agent question", function()
        local markers = review.parse_markers({ "㊷[comment]{question with {nested} braces}" })
        assert.equals(2, #markers[1].sections)
        assert.equals("question with {nested} braces", markers[1].sections[2].text)
    end)

    it("returns empty list when no markers present", function()
        local markers = review.parse_markers({ "Just normal text", "Nothing to see here" })
        assert.equals(0, #markers)
    end)

    it("ignores ㊷ not followed by brackets", function()
        local markers = review.parse_markers({ "The character ㊷ alone" })
        assert.equals(0, #markers)
    end)

    it("captures the raw marker text", function()
        local markers = review.parse_markers({ "text ㊷[comment]{question} more" })
        assert.equals("㊷[comment]{question}", markers[1].raw)
    end)

    it("records correct column position", function()
        -- "text " is 5 bytes, so ㊷ starts at byte 6 (0-indexed: 5)
        local markers = review.parse_markers({ "text ㊷[comment]" })
        assert.equals(5, markers[1].col)
    end)
end)

describe("apply_edits", function()
    local tmpfile

    before_each(function()
        tmpfile = vim.fn.tempname() .. ".md"
    end)

    after_each(function()
        os.remove(tmpfile)
    end)

    local function write_file(content)
        local f = io.open(tmpfile, "w")
        f:write(content)
        f:close()
    end

    local function read_file()
        local f = io.open(tmpfile, "r")
        local content = f:read("*a")
        f:close()
        return content
    end

    it("applies a single edit", function()
        write_file("Hello world.\n㊷[fix greeting]\nGoodbye.\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "Hello world.\n㊷[fix greeting]", new_string = "Hi there.", explain = "simplified" },
        })
        assert.is_true(result.ok)
        assert.equals(1, #result.applied)
        assert.equals("Hi there.\nGoodbye.\n", read_file())
    end)

    it("applies multiple edits in correct order", function()
        write_file("AAA\nBBB\nCCC\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "AAA", new_string = "aaa", explain = "first" },
            { old_string = "CCC", new_string = "ccc", explain = "third" },
        })
        assert.is_true(result.ok)
        assert.equals(2, #result.applied)
        assert.equals("aaa\nBBB\nccc\n", read_file())
    end)

    it("handles edits that change string length", function()
        write_file("short\nmedium text\nlong long long text\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "short", new_string = "very very long replacement", explain = "expand" },
            { old_string = "long long long text", new_string = "x", explain = "shrink" },
        })
        assert.is_true(result.ok)
        assert.equals("very very long replacement\nmedium text\nx\n", read_file())
    end)

    it("errors when old_string not found", function()
        write_file("Hello world\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "nonexistent", new_string = "replacement", explain = "test" },
        })
        assert.is_false(result.ok)
        assert.is_truthy(result.msg:find("not found"))
    end)

    it("errors when old_string is not unique", function()
        write_file("repeat\nrepeat\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "repeat", new_string = "unique", explain = "test" },
        })
        assert.is_false(result.ok)
        assert.is_truthy(result.msg:find("not unique"))
    end)

    it("errors when file does not exist", function()
        local result = review.apply_edits("/nonexistent/path/file.md", {
            { old_string = "x", new_string = "y", explain = "test" },
        })
        assert.is_false(result.ok)
        assert.is_truthy(result.msg:find("cannot open"))
    end)

    it("returns empty applied list on error", function()
        write_file("content\n")
        local result = review.apply_edits(tmpfile, {
            { old_string = "missing", new_string = "replacement", explain = "test" },
        })
        assert.equals(0, #result.applied)
    end)

    it("preserves file content when no edits given", function()
        write_file("unchanged\n")
        local result = review.apply_edits(tmpfile, {})
        assert.is_true(result.ok)
        assert.equals("unchanged\n", read_file())
    end)
end)
