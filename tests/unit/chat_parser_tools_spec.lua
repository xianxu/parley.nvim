local chat_parser = require("parley.chat_parser")
local config = require("parley.config")

-- #200 M2: cb_append_line already tracked tool-body fences correctly
-- (chat_parser.lua:455-469), but the main loop classified every line without
-- consulting that state. Tool output routinely contains 💬:/🤖:/📎: lines —
-- reading a transcript, grepping this repo — and each one forked a spurious
-- exchange that then dragged the rest of the tool body out of its block.
describe("structural markers inside a tool body (#200)", function()
    local function parse(lines)
        return chat_parser.parse_chat(lines, 4, config)
    end

    local header = { "---", "topic: t", "file: f.md", "---" }

    it("treats a question marker inside a tool result as content", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: show me the transcript",
            "",
            "🤖: [A]",
            "📎: read_file id=r1",
            "```",
            "💬: a question from the file being read",
            "🤖: and its answer",
            "```",
            "",
            "💬: second real question",
        })
        local parsed = parse(lines)
        assert.message("an in-body 💬: forked a spurious exchange")
            .equals(2, #parsed.exchanges)
        -- Line 11 is the marker INSIDE the body; the real second question is
        -- at 15, after the closing fence and the blank line.
        assert.equals(15, parsed.exchanges[2].question.line_start)
    end)

    it("treats a tool-result marker inside a tool body as content", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q",
            "",
            "🤖: [A]",
            "📎: grep id=r1",
            "```",
            "match: 📎: read_file id=other",
            "📎: read_file id=other",
            "```",
        })
        local parsed = parse(lines)
        assert.equals(1, #parsed.exchanges)
    end)

    it("resumes structural parsing after the body closes", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "📎: read id=r1",
            "```",
            "💬: not a turn",
            "```",
            "",
            "💬: q2",
            "",
            "🤖: [A]",
            "",
            "💬: q3",
        })
        local parsed = parse(lines)
        assert.equals(3, #parsed.exchanges)
    end)

    it("keeps a longer nested fence inside the body", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q",
            "",
            "🤖: [A]",
            "📎: read id=r1",
            "````",
            "```lua",
            "💬: still content",
            "```",
            "````",
            "",
            "💬: real",
        })
        local parsed = parse(lines)
        assert.equals(2, #parsed.exchanges)
    end)

    it("does not suppress markers outside a tool body", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "```",
            "💬: inside ordinary answer prose, still a turn today",
            "```",
        })
        -- Scope boundary, recorded as a non-goal in the plan: only tool bodies
        -- are suppressed. Ordinary answer prose stays fence-naive.
        assert.equals(2, #parse(lines).exchanges)
    end)
end)
