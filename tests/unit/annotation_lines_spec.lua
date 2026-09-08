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

-- parse_chat is pure: no Neovim APIs, no setup() required — a config stub is
-- enough, exactly as tests/unit/parse_chat_spec.lua does it. This spec called
-- parley.setup({}) per test, which runs file_tracker.init and races the 8-way
-- unit runner on the shared XDG dir ("E739: Cannot create directory … already
-- exists"). It passed standalone and in a warm environment, and failed from a
-- clean one — a unit test reaching for the whole plugin to exercise a pure
-- function (#214 BR-62).
local chat_parser = require("parley.chat_parser")

local test_config = {
    chat_user_prefix      = "💬:",
    chat_local_prefix     = "🔒:",
    chat_branch_prefix    = "🌿:",
    chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
    chat_memory = {
        enable            = true,
        summary_prefix    = "📝:",
        reasoning_prefix  = "🧠:",
    },
}

describe("single-line annotations (#214)", function()
    local function parse(lines)
        return chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), test_config)
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

-- #214 BR-75 (Critical). Removing the `line_before_local` latch put annotation
-- lines INSIDE the component's span, and the restoration covered only the
-- trailing position. `<M-CR>`'s resubmit deletes question.line_end+1 ..
-- answer.line_end and regenerates — so a MID-answer `🌿:`, which is exactly
-- where the M3 chord now puts one by design, was deleted on the next resubmit,
-- orphaning a child chat that exists on disk. A mid-answer `🔒:` private note
-- went with it.
--
-- A resubmit regenerates the MODEL's output. An annotation is the user's, so it
-- is not the resubmit's to destroy.
describe("a resubmit preserves annotations (#214 BR-75)", function()
    local buffer_edit = require("parley.buffer_edit")

    local function after_delete(lines, from_1, to_1)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        buffer_edit.delete_answer(buf, from_1, to_1 - 1)
        local out = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        vim.api.nvim_buf_delete(buf, { force = true })
        return out
    end

    it("keeps a mid-answer branch reference", function()
        local out = after_delete({
            "💬: q", "", "🤖:[A]", "", "answer one", "",
            "🌿: child.md: a branch", "",
            "answer two", "", "📝: sum",
        }, 1, 11)
        local joined = table.concat(out, "\n")
        assert.is_truthy(joined:find("🌿: child.md: a branch", 1, true),
            "the resubmit deleted the only pointer to a child on disk: " .. vim.inspect(out))
        assert.is_nil(joined:find("answer one", 1, true), "the answer was not replaced")
    end)

    it("keeps a mid-answer private note", function()
        local out = after_delete({
            "💬: q", "", "🤖:[A]", "", "answer one", "",
            "🔒: my note", "",
            "answer two", "", "📝: sum",
        }, 1, 11)
        assert.is_truthy(table.concat(out, "\n"):find("🔒: my note", 1, true),
            "the resubmit destroyed the user's private note")
    end)

    it("keeps several, in order", function()
        local out = after_delete({
            "💬: q", "", "🤖:[A]", "", "a", "", "🔒: one", "", "b", "", "🌿: c.md: two", "", "c",
        }, 1, 13)
        local kept = {}
        for _, l in ipairs(out) do
            if l:match("^🔒:") or l:match("^🌿:") then kept[#kept + 1] = l end
        end
        assert.same({ "🔒: one", "🌿: c.md: two" }, kept)
    end)

    it("still removes the answer when there is nothing to keep", function()
        local out = after_delete({ "💬: q", "", "🤖:[A]", "", "answer", "", "📝: sum" }, 1, 7)
        assert.same({ "💬: q" }, out)
    end)
end)
