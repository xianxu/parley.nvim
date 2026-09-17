local nq = require("parley.new_question")
local chat_parser = require("parley.chat_parser")

local PREFIX = "💬:"

-- The same minimal stub `tests/unit/parse_chat_spec.lua` uses: it covers every
-- field parse_chat reads from config. A two-key table is NOT enough -- the
-- parser reaches chat_local_prefix, chat_branch_prefix and chat_memory too.
local function config_for(prefix)
    return {
        chat_user_prefix      = prefix or PREFIX,
        chat_local_prefix     = "🔒:",
        chat_branch_prefix    = "🌿:",
        chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
        chat_memory = {
            enable           = true,
            summary_prefix   = "📝:",
            reasoning_prefix = "🧠:",
        },
    }
end

--- Build (lines, parsed_chat, header_end) from a transcript body.
local function transcript(body, prefix)
    local lines = vim.split("---\ntopic: t\nfile: t.md\n---\n" .. body, "\n", { plain = true })
    local header_end = chat_parser.find_header_end(lines)
    local parsed = chat_parser.parse_chat(lines, header_end, config_for(prefix))
    return lines, parsed, header_end
end

describe("new_question.is_empty_question", function()
    it("accepts a bare prefix line with no answer", function()
        local lines, parsed = transcript("\n💬:\n")
        assert.is_true(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("accepts a prefix line that is only trailing whitespace", function()
        local lines, parsed = transcript("\n💬:   \n")
        assert.is_true(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("rejects a question that has text", function()
        local lines, parsed = transcript("\n💬: hello\n")
        assert.is_false(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)

    it("rejects an empty question that already has an answer", function()
        local lines, parsed = transcript("\n💬:\n\n🤖: [x]\n\nanswered\n")
        assert.is_false(nq.is_empty_question(lines, parsed.exchanges[1], PREFIX))
    end)
end)

describe("new_question.plan", function()
    -- One answered exchange, then a second answered exchange.
    local BODY = "\n💬: first\n\n🤖: [x]\n\nA1\n\n💬: second\n\n🤖: [x]\n\nA2\n"

    it("opens a question after the exchange the cursor is in, not at the end", function()
        local lines, parsed, header_end = transcript(BODY)
        local first_q = parsed.exchanges[1].question.line_start
        local p = nq.plan(parsed, lines, first_q, header_end, PREFIX)
        assert.equals("insert", p.kind)
        -- It lands inside the transcript, not appended at EOF.
        --
        -- `<=`, NOT `<`. Measured: for BODY, p.after = 11, p.row = 12 and
        -- exchange 2's PRE-insertion line_start is also 12. That is structural,
        -- not fixture luck -- get_paste_line returns the end of exchange 1,
        -- which includes its trailing blank, so the new question takes exactly
        -- the row exchange 2 used to occupy and pushes it down. `<` here fails
        -- against CORRECT code, and the tempting fix (shrink row by one)
        -- destroys the blank-line seam this module exists to preserve.
        assert.is_true(p.row <= parsed.exchanges[2].question.line_start)
        assert.is_true(p.row > parsed.exchanges[1].question.line_start)
        assert.is_true(vim.tbl_contains(p.lines, PREFIX .. " "))
    end)

    it("the planned row is the prefix line, with a trailing space", function()
        local lines, parsed, header_end = transcript(BODY)
        local p = nq.plan(parsed, lines, parsed.exchanges[2].question.line_start, header_end, PREFIX)
        -- Apply the plan to a copy and read row back: the post-condition, checked
        -- against the resulting text rather than against the planner's own math.
        local after = {}
        for i = 1, p.after do after[#after + 1] = lines[i] end
        for _, l in ipairs(p.lines) do after[#after + 1] = l end
        for i = p.after + 1, #lines do after[#after + 1] = lines[i] end
        assert.equals(PREFIX .. " ", after[p.row])
    end)

    it("focuses an existing empty question instead of creating a second one", function()
        local lines, parsed, header_end = transcript("\n💬: first\n\n🤖: [x]\n\nA1\n\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[2].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.equals(parsed.exchanges[2].question.line_start, p.row)
    end)

    it("gives a bare focused prefix its trailing space", function()
        local lines, parsed, header_end = transcript("\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.same({ PREFIX .. " " }, p.lines)
    end)

    it("leaves an already-spaced focused prefix untouched", function()
        local lines, parsed, header_end = transcript("\n💬:   \n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.is_nil(p.lines)
    end)

    -- A tab is whitespace, so is_empty_question accepts the line -- but it is
    -- not the separator the post-condition names, and leaving it would make
    -- startinsert! produce `💬:\thello`.
    it("normalizes a tab-separated focused prefix to a space", function()
        local lines, parsed, header_end = transcript("\n💬:\t\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.equals("focus", p.kind)
        assert.same({ PREFIX .. " " }, p.lines)
    end)

    -- The one path that can legitimately produce two consecutive `💬:` lines.
    -- Recorded as a DECISION, not an oversight: the rule is about the exchange
    -- the cursor is IN (the revision's wording), so pressing the chord from an
    -- answered exchange opens a question after it even when the next exchange
    -- is already empty. Reaching past the cursor's exchange to adopt a
    -- neighbour's empty question would make the chord's landing spot depend on
    -- content the user is not looking at.
    it("does not adopt the NEXT exchange's empty question", function()
        local lines, parsed, header_end = transcript(
            "\n💬: first\n\n🤖: [x]\n\nA1\n\n💬:\n")
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start,
            header_end, PREFIX)
        assert.equals("insert", p.kind)
    end)

    it("opens the first question when the chat has none", function()
        local lines, parsed, header_end = transcript("\n")
        local p = nq.plan(parsed, lines, 1, header_end, PREFIX)
        assert.equals("insert", p.kind)
        assert.is_true(p.after >= header_end)
        assert.is_true(p.row > header_end)
    end)

    it("honors a configured prefix that is full of Lua-pattern magic", function()
        local magic = "%-Q.:"
        local lines, parsed, header_end = transcript("\n" .. magic .. " first\n", magic)
        local p = nq.plan(parsed, lines, parsed.exchanges[1].question.line_start,
            header_end, magic)
        assert.equals("insert", p.kind)
        local found = false
        for _, l in ipairs(p.lines) do
            if l == magic .. " " then found = true end
        end
        assert.is_true(found)
    end)

    it("is a plan only -- it mutates nothing it was handed", function()
        local lines, parsed, header_end = transcript(BODY)
        local before = vim.deepcopy(lines)
        nq.plan(parsed, lines, parsed.exchanges[1].question.line_start, header_end, PREFIX)
        assert.same(before, lines)
    end)
end)
