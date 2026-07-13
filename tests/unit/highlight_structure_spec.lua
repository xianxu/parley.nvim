local structure = require("parley.highlight_structure")

local patterns = structure.patterns({
    chat_user_prefix = "💬:",
    chat_assistant_prefix = { "🤖:", "[agent]" },
    chat_local_prefix = "🔒:",
    chat_branch_prefix = "🌿:",
    chat_memory = { enable = true, reasoning_prefix = "🧠:", summary_prefix = "📝:" },
})

local function state(question, code, reasoning, explicit_end, tool)
    return {
        in_question = question,
        in_code = code,
        in_reasoning = reasoning,
        reasoning_explicit_end = explicit_end,
        in_tool = tool,
    }
end

describe("highlight_structure", function()
    it("classifies canonical decoration grammar into compact fingerprints", function()
        local cases = {
            { "ordinary prose", "text" }, { "💬: q", "user" },
            { "🤖: a", "assistant" }, { "🔒: local", "local" },
            { "🌿: branch", "branch" }, { "📝: summary", "summary" },
            { "🧠: think", "reasoning" }, { "🧠:[END]", "reasoning_end" },
            { "🔧: call", "tool_use" }, { "📎: result", "tool_result" },
            { "```lua", "fence" }, { "=== draft ===", "draft_open" },
            { "=== end ===", "draft_end" }, { "[^term]: definition", "footnote" },
            { "", "blank" },
        }
        for _, case in ipairs(cases) do
            local token = structure.fingerprint(case[1], patterns)
            assert.equals("string", type(token))
            assert.is_true(#token <= 3)
            assert.equals(case[2], structure.classify(case[1], patterns).kind)
        end
    end)

    it("builds state, footer, and multiple half-open draft ranges", function()
        local lines = {
            "💬: q", "question", "```lua", "inside code", "```", "🤖: a",
            "🧠: first", "", "still reasoning", "🧠:[END]", "🔧: call", "```json",
            "{}", "```", "plain", "=== one ===", "draft", "=== end ===",
            "=== two ===", "open draft", "[^x]: definition", "tail",
        }
        local built, rows = structure.build(lines, patterns)
        assert.equals(#lines, rows)
        assert.are.same(state(false, false, false, false, false), structure.state_before(built, 0))
        assert.are.same(state(true, false, false, false, false), structure.state_before(built, 1))
        assert.are.same(state(true, true, false, false, false), structure.state_before(built, 3))
        assert.are.same(state(false, false, true, true, false), structure.state_before(built, 7))
        assert.are.same(state(false, true, false, false, true), structure.state_before(built, 12))
        assert.are.same({ start_row = 20, end_row_exclusive = 22 }, structure.footer_range(built, #lines))
        assert.are.same({
            { start_row = 15, end_row_exclusive = 18 },
            { start_row = 18, end_row_exclusive = 22 },
        }, structure.draft_blocks_in(built, 0, #lines))
    end)

    it("overlays active reasoning for streaming without mutating stored state", function()
        local built = structure.build({ "🤖: a", "🧠: think", "continued", "" }, patterns)
        local normal = structure.state_before(built, 2)
        local streaming = structure.state_before(built, 2, { streaming = true })
        assert.is_false(normal.reasoning_explicit_end)
        assert.is_true(streaming.reasoning_explicit_end)
        assert.is_false(structure.state_before(built, 2).reasoning_explicit_end)
    end)

    it("returns copied query values", function()
        local lines = { "💬: q", "=== d ===", "x", "=== end ===" }
        local lines_snapshot = vim.deepcopy(lines)
        local built = structure.build(lines, patterns)
        local second = structure.build(lines, patterns)
        assert.are.same(lines_snapshot, lines)
        assert.is_not.equal(built, second)
        assert.is_not.equal(built.state_before, second.state_before)
        local queried = structure.state_before(built, 1)
        queried.in_question = false
        local drafts = structure.draft_blocks_in(built, 0, 4)
        drafts[1].start_row = 99
        assert.is_true(structure.state_before(built, 1).in_question)
        assert.equals(1, structure.draft_blocks_in(built, 0, 4)[1].start_row)
    end)

    it("fast-replaces fingerprint-identical body edits with exact bounded work", function()
        for _, count in ipairs({ 100, 1000, 5000 }) do
            local lines = { "💬: q" }
            for i = 2, count do lines[i] = "prose " .. i end
            local original = structure.build(lines, patterns)
            local snapshot = vim.deepcopy(original)
            local replaced, rows, reason, work = structure.replace(original, 50, 51, { "changed prose" }, patterns)
            assert.equals(1, rows)
            assert.is_nil(reason)
            assert.are.same({ rows_visited = 1, entries_copied = 0 }, work)
            assert.is_not_nil(replaced)
            assert.are.same(snapshot, original)
            assert.is_not.equal(original, replaced)
            assert.equals(original.fingerprints, replaced.fingerprints)
            assert.equals(original.state_before, replaced.state_before)
            assert.equals(original.draft_ranges, replaced.draft_ranges)
        end
    end)

    it("indexes many reasoning openers with linear, exactly-accounted work", function()
        local lines = { "🤖: answer" }
        for i = 1, 2000 do
            lines[#lines + 1] = "🧠: pass " .. i
        end
        lines[#lines + 1] = "🧠:[END]"
        local built, rows, work = structure.build(lines, patterns)
        assert.equals(#lines, rows)
        assert.are.same({ rows_visited = #lines * 2, entries_copied = 0 }, work)
        assert.is_true(structure.state_before(built, 2000).reasoning_explicit_end)
    end)

    it("rejects structural replacements without suffix work or mutation", function()
        local lines = { "💬: q", "body", "🤖: a", "🧠: thought", "continued" }
        local original = structure.build(lines, patterns)
        for _, edit in ipairs({
            { 1, 2, { "🤖: changed" } },
            { 1, 1, { "new line" } },
            { 1, 3, {} },
            { 1, 2, { "[^x]: footer" } },
            { 1, 2, { "=== draft ===" } },
            { 1, 2, { "" } },
        }) do
            local snapshot = vim.deepcopy(original)
            local replaced, rows, reason = structure.replace(original, edit[1], edit[2], edit[3], patterns)
            assert.is_nil(replaced)
            assert.equals(#edit[3], rows)
            assert.equals("structural", reason)
            assert.are.same(snapshot, original)
        end
    end)

    it("rebuilds shifted footer/drafts and downstream state after structural edits", function()
        local before = structure.build({ "💬: q", "body", "🤖: a", "=== d ===", "x", "=== end ===", "[^x]: d" }, patterns)
        local after = structure.build({ "header", "💬: q", "body", "🤖: a", "=== d ===", "x", "=== end ===", "[^x]: d" }, patterns)
        assert.are.same({ start_row = 6, end_row_exclusive = 7 }, structure.footer_range(before, 7))
        assert.are.same({ start_row = 7, end_row_exclusive = 8 }, structure.footer_range(after, 8))
        assert.are.same({ { start_row = 4, end_row_exclusive = 7 } }, structure.draft_blocks_in(after, 0, 8))
        assert.is_true(structure.state_before(after, 2).in_question)
    end)
end)
