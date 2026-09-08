-- #214: `🌿:` and `🔒:` at the start of a line are SINGLE-LINE annotations.
--
-- The line itself is not submitted to the LLM — a branch reference is
-- bookkeeping, a local note is the user's own — but the line after it is
-- ordinary content again. Both used to latch `line_before_local`, which means
-- "everything from here to the end of this component is local". That is the
-- right semantics for a section marker and the wrong one for a one-line
-- annotation, and nothing distinguished the two: dropping a private note
-- halfway through an answer silently removed the rest of that answer from every
-- later submission, and the same for the second half of your own question.
--
-- Measured before the fix:
--   baseline        BEFORE line | | | AFTER line | | 📝: the summary
--   🌿: standalone  BEFORE line | | 📝: the summary        <- AFTER line gone
--   🔒: standalone  BEFORE line | | 📝: the summary        <- same

local parley = require("parley")

describe("single-line annotations (#214)", function()
    before_each(function() parley.setup({}) end)

    local function parse(lines)
        return parley.parse_chat(lines, parley.chat_parser.find_header_end(lines))
    end

    local function answer_of(mid)
        local lines = { "---", "topic: t", "file: f", "---", "",
                        "💬: q", "", "🤖:[A]", "", "BEFORE line", "" }
        vim.list_extend(lines, mid)
        vim.list_extend(lines, { "", "AFTER line", "", "📝: the summary", "", "💬: next" })
        local ex = parse(lines).exchanges[1]
        return ex.answer and ex.answer.content or ""
    end

    it("a 🌿: line does not swallow the rest of the answer", function()
        local a = answer_of({ "🌿: child.md: topic" })
        assert.is_truthy(a:find("BEFORE line", 1, true))
        assert.is_truthy(a:find("AFTER line", 1, true),
            "content after a branch reference was dropped from the submission")
    end)

    it("a 🔒: line does not swallow the rest of the answer", function()
        local a = answer_of({ "🔒: my private note" })
        assert.is_truthy(a:find("AFTER line", 1, true),
            "content after a private note was dropped from the submission")
    end)

    it("neither annotation's own text is submitted", function()
        local branch = answer_of({ "🌿: child.md: some topic" })
        assert.is_nil(branch:find("some topic", 1, true), "the branch line was submitted")
        local note = answer_of({ "🔒: SECRETNOTE" })
        assert.is_nil(note:find("SECRETNOTE", 1, true), "the private note was submitted")
    end)

    it("several annotations in one answer each skip only themselves", function()
        local a = answer_of({ "🔒: note one", "", "middle text", "", "🌿: c.md: t" })
        assert.is_truthy(a:find("BEFORE line", 1, true))
        assert.is_truthy(a:find("middle text", 1, true))
        assert.is_truthy(a:find("AFTER line", 1, true))
        assert.is_nil(a:find("note one", 1, true))
    end)

    it("a 🔒: mid-question does not truncate the question", function()
        local lines = { "---", "topic: t", "file: f", "---", "",
                        "💬: first part", "", "🔒: a private note", "", "second part", "",
                        "🤖:[A]", "", "an answer" }
        local q = parse(lines).exchanges[1].question.content
        assert.is_truthy(q:find("first part", 1, true))
        assert.is_truthy(q:find("second part", 1, true),
            "the second half of the user's own question was dropped")
        assert.is_nil(q:find("private note", 1, true))
    end)

    -- The span, not just the content: a reference sitting at the END of an
    -- answer must stay OUTSIDE that answer's line range, or a resubmit (which
    -- deletes question..answer.line_end and regenerates) would delete the only
    -- pointer to a child chat that exists on disk — BR-19's orphan, arriving by
    -- another route.
    it("a trailing 🌿: stays outside the answer's line span", function()
        local lines = { "---", "topic: t", "file: f", "---", "",
                        "💬: q", "", "🤖:[A]", "", "the answer", "", "📝: sum", "",
                        "🌿: child.md: topic", "", "💬: next" }
        local ex = parse(lines).exchanges[1]
        local ref_line = 14
        assert.is_true(ex.answer.line_end < ref_line,
            ("answer.line_end=%d includes the branch reference at %d; a resubmit "):format(
                ex.answer.line_end, ref_line)
            .. "would delete it and orphan the child")
    end)

    it("the back-link before the first question is unaffected", function()
        local lines = { "---", "topic: t", "file: f", "---", "",
                        "🌿: parent.md: parent topic", "",
                        "💬: the question", "", "🤖:[A]", "", "the answer", "", "📝: sum" }
        local parsed = parse(lines)
        assert.are.equal("parent.md", parsed.parent_link.path)
        assert.are.equal("the question", parsed.exchanges[1].question.content)
        assert.is_truthy(parsed.exchanges[1].answer.content:find("the answer", 1, true))
    end)

    -- Unchanged: an inline link already behaved this way, and is the model the
    -- line-start prefixes should have matched all along.
    it("an inline [🌿:anchor](file) still submits its anchor text", function()
        local a = answer_of({ "text with [🌿:anchor here](child.md) inline" })
        assert.is_truthy(a:find("text with anchor here inline", 1, true))
        assert.is_nil(a:find("child.md", 1, true), "the link target was submitted")
    end)
end)
