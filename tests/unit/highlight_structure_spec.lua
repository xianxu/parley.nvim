local structure = require("parley.highlight_structure")

local patterns = structure.patterns({
    chat_user_prefix = "💬:",
    chat_assistant_prefix = { "🤖:", "[agent]" },
    chat_local_prefix = "🔒:",
    chat_branch_prefix = "🌿:",
    chat_memory = { enable = true, reasoning_prefix = "🧠:", summary_prefix = "📝:" },
})

-- `fence_len` is the width of the OPEN fence, nil when closed (#218). It is
-- asserted explicitly rather than allowed to float: the whole state table is
-- compared with assert.are.same, and a state that claims in_code with no width
-- cannot match a closer correctly.
local function state(question, code, reasoning, explicit_end, tool, fence_len)
    return {
        in_question = question,
        in_code = code,
        code_fence_len = fence_len or (code and 3 or nil),
        in_reasoning = reasoning,
        reasoning_explicit_end = explicit_end,
        in_tool = tool,
    }
end

-- One document exercising every structural feature a splice must keep right:
-- a question block, a legacy 🧠: block (blank-terminated), a fence, an
-- explicit 🧠: block (🧠:[END]), a draft, a second question, and a footer.
-- The turn markers at 11-12 matter: a 🧠: row does not end the lookahead, so
-- without a marker between them the [END] at 15 would make row 4 explicit too.
local DOC = {
    "💬: q",            -- 0
    "question body",    -- 1
    "",                 -- 2
    "🤖: a",            -- 3
    "🧠: legacy",       -- 4
    "legacy more",      -- 5
    "",                 -- 6  ends the legacy block
    "answer prose",     -- 7
    "```lua",           -- 8
    "code",             -- 9
    "```",              -- 10
    "💬: middle",       -- 11
    "🤖: a2",           -- 12
    "🧠: explicit",     -- 13
    "",                 -- 14 inside the explicit block
    "🧠:[END]",         -- 15
    "=== draft ===",    -- 16
    "draft body",       -- 17
    "=== end ===",      -- 18
    "💬: q2",           -- 19
    "typing here",      -- 20
    "",                 -- 21
    "[^x]: footnote",   -- 22
    "[^y]: second",     -- 23
}

local function splice_lines(lines, first0, old_last0, new_lines)
    local out = {}
    for i = 1, first0 do out[#out + 1] = lines[i] end
    for _, line in ipairs(new_lines) do out[#out + 1] = line end
    for i = old_last0 + 1, #lines do out[#out + 1] = lines[i] end
    return out
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
        assert.are.same({ rows_visited = #lines * 3, entries_copied = 0 }, work)
        assert.is_true(structure.state_before(built, 2000).reasoning_explicit_end)
    end)

    it("splices a pure insertion exactly and accounts its copy", function()
        local original = structure.build({ "💬: q", "body" }, patterns)
        local replaced, rows, reason, work = structure.replace(original, 1, 1, { "inserted" }, patterns)
        assert.is_nil(reason)
        assert.equals(1, rows)
        assert.are.same(structure.build({ "💬: q", "inserted", "body" }, patterns), replaced)
        -- 1 classified + 1 walked; 3 token slots + 3 state slots written.
        assert.are.same({ rows_visited = 2, entries_copied = 6 }, work)
    end)

    it("returns an aligned structure for every edit shape, exact exactly when promised", function()
        local cases = {
            -- name, first0, old_last0, new_lines, expected reason
            { "Enter mid-line in a question", 1, 2, { "question", " body" }, nil },
            { "Enter at the end of the typing line", 20, 21, { "typing here", "" }, nil },
            { "join a line with the blank below it", 20, 22, { "typing here" }, nil },
            { "first character on a blank line", 21, 22, { "x" }, nil },
            { "pure insertion of prose", 2, 2, { "new" }, nil },
            { "pure deletion of prose", 7, 8, {}, nil },
            { "insertion at row 0", 0, 0, { "preamble" }, nil },
            { "append at EOF", 24, 24, { "tail" }, nil },
            { "blank inside explicit reasoning", 14, 14, { "" }, nil },
            { "Enter inside a draft", 17, 18, { "draft", " body" }, nil },
            { "delete the draft closer", 18, 19, {}, nil },
            { "body line becomes a draft opener", 1, 2, { "=== draft ===" }, nil },
            { "body line becomes blank", 1, 2, { "" }, nil },
            { "whole buffer replaced", 0, 24, { "💬: fresh", "🧠: t", "", "x" }, nil },
            { "delete the blank that ends legacy reasoning", 6, 7, {}, "structural" },
            { "open a fence in prose", 7, 8, { "```" }, "structural" },
            { "widen a fence", 8, 9, { "````lua" }, "structural" },
            { "insert a turn marker", 7, 8, { "💬: new" }, "structural" },
            { "delete a turn marker", 1, 4, {}, "structural" },
            { "insert a 🧠: line", 7, 7, { "🧠: new" }, "structural" },
            { "delete 🧠:[END]", 15, 16, {}, "structural" },
            { "insert a footnote above the footer", 20, 20, { "[^z]: early" }, "structural" },
            { "delete the first footnote", 22, 23, {}, "structural" },
            { "body line becomes a footnote", 1, 2, { "[^x]: footer" }, "structural" },
        }
        local original = structure.build(DOC, patterns)
        for _, case in ipairs(cases) do
            local name, first0, old_last0, new_lines, want_reason = unpack(case, 1, 5)
            local snapshot = vim.deepcopy(original)
            local out, rows, reason = structure.replace(original, first0, old_last0, new_lines, patterns)
            local want = structure.build(splice_lines(DOC, first0, old_last0, new_lines), patterns)
            assert.are.same(snapshot, original, name .. ": mutated its input")
            assert.equals(#new_lines, rows, name)
            assert.equals(want_reason, reason, name)
            assert.are.same(want.fingerprints, out.fingerprints, name)
            assert.equals(want.footer_start0, out.footer_start0, name)
            assert.are.same(want.draft_ranges, out.draft_ranges, name)
            if want_reason == nil then
                assert.are.same(want.state_before, out.state_before, name)
            end
        end
    end)

    it("never claims exact when an edit changes the lookahead of a 🧠: row above it", function()
        -- Inserting 🧠:[END] turns the legacy block at row 0 explicit, so the
        -- blank at row 1 stops terminating it: rows 1-2 change state ABOVE the
        -- edit, where the convergence check (which looks below) cannot see.
        -- Only the inertness rule rejects this.
        local lines = { "🧠: a", "", "x", "[^f]: n" }
        local original = structure.build(lines, patterns)
        local out, _, reason = structure.replace(original, 3, 3, { "🧠:[END]" }, patterns)
        assert.equals("structural", reason)
        local want = structure.build({ "🧠: a", "", "x", "🧠:[END]", "[^f]: n" }, patterns)
        assert.are_not.same(want.state_before, out.state_before, "fixture must exercise stale rows above")
    end)

    it("refuses an edit range that does not fit the structure", function()
        local original = structure.build({ "a" }, patterns)
        for _, edit in ipairs({ { 0, 2 }, { 1, 0 }, { 2, 2 } }) do
            local out, _, reason = structure.replace(original, edit[1], edit[2], { "x" }, patterns)
            assert.is_nil(out)
            assert.equals("misaligned", reason)
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

    it("terminates legacy reasoning on whitespace-only lines, not just empty ones", function()
        for _, blank in ipairs({ "", "   ", "\t" }) do
            local built = structure.build({ "🧠: thought", "more", blank, "after" }, patterns)
            assert.is_true(structure.state_before(built, 2).in_reasoning, vim.inspect(blank))
            assert.is_false(structure.state_before(built, 3).in_reasoning, vim.inspect(blank))
        end
    end)
end)

-- #203 BR-18: STRUCTURAL_KINDS had three hand-maintained restatements — the set
-- itself, TOKENS in the same module, and chat_parser's reasoning-termination
-- lookahead. Nothing pinned their agreement, so adding a kind would silently
-- stop terminating reasoning blocks on it. The set derives from TOKENS now;
-- this pins the membership so the derivation cannot quietly change what it means.
describe("STRUCTURAL_KINDS (#203)", function()
    local hs = require("parley.highlight_structure")

    it("is exactly the markers chat_parser calls structural", function()
        local want = { assistant = true, branch = true, ["local"] = true,
            summary = true, tool_result = true, tool_use = true, user = true }
        assert.same(want, hs.STRUCTURAL_KINDS)
    end)

    it("excludes reasoning — 🧠: is terminated BY a structural marker", function()
        assert.is_false(hs.is_structural_kind("reasoning"))
        assert.is_false(hs.is_structural_kind("reasoning_end"))
    end)

    it("every member is a real kind the classifier can produce", function()
        local patterns = hs.patterns(require("parley.config"))
        local produced = {}
        for _, line in ipairs({ "💬: q", "🤖: a", "📝: s", "🔧: t", "📎: r",
                                "🌿: b", "🔒: l" }) do
            produced[hs.classify(line, patterns).kind] = true
        end
        for kind in pairs(hs.STRUCTURAL_KINDS) do
            assert.message(kind .. " is in STRUCTURAL_KINDS but no marker classifies as it")
                .is_true(produced[kind] == true)
        end
    end)
end)

-- #218 — fence containment. The invariant, stated once: a 💬:/🤖: partition
-- terminates any open fence, so malformed output corrupts at most its own
-- exchange. Verified by mutation: removing reset_partition's in_code line turns
-- the property test red.
describe("fence containment across exchange partitions (#218)", function()
    local P = structure.patterns()

    it("build: in_code is false entering EVERY partition row, over random fence runs", function()
        -- Property/fuzz: arbitrary interleavings of fence runs (3-5 ticks),
        -- prose and partitions. No matter how unbalanced, a partition row must
        -- never be entered while in code.
        math.randomseed(218)
        for _ = 1, 200 do
            local lines, partition_rows = {}, {}
            for _ = 1, math.random(6, 30) do
                local r = math.random(4)
                if r == 1 then
                    lines[#lines + 1] = string.rep("`", math.random(3, 5))
                elseif r == 2 then
                    lines[#lines + 1] = "💬: q"
                    partition_rows[#lines] = true
                elseif r == 3 then
                    lines[#lines + 1] = "🤖: a"
                    partition_rows[#lines] = true
                else
                    lines[#lines + 1] = "prose"
                end
            end
            local built = structure.build(lines, P)
            for row1 in pairs(partition_rows) do
                local st = structure.state_before(built, row1 - 1)
                assert.is_false(st.in_code,
                    "partition at row " .. row1 .. " entered while in_code; lines:\n"
                    .. table.concat(lines, "\n"))
            end
        end
    end)

    it("build: an unmatched fence does not leak past the next partition", function()
        local lines = { "💬: q", "```lua", "code", "🤖: a", "plain answer", "💬: q2", "more" }
        local built = structure.build(lines, P)
        assert.is_true(structure.state_before(built, 2).in_code)   -- inside the run
        assert.is_false(structure.state_before(built, 3).in_code)  -- 🤖: clears it
        assert.is_false(structure.state_before(built, 4).in_code)
        assert.is_false(structure.state_before(built, 6).in_code)
    end)

    it("build: a shorter run does not close a longer fence (CommonMark)", function()
        local lines = { "🤖: a", "````", "```", "still inside", "````", "outside" }
        local built = structure.build(lines, P)
        assert.is_true(structure.state_before(built, 2).in_code, "``` must not close ````")
        assert.is_true(structure.state_before(built, 3).in_code)
        assert.is_false(structure.state_before(built, 5).in_code, "```` closes ````")
    end)

    it("replace: editing a fence's WIDTH is never claimed exact", function()
        -- PQ-2. TOKENS.fence used to be one token for every width, so this edit
        -- kept an identical fingerprint and M.replace served stale state for the
        -- rest of the buffer. Now it splices, and must say the state is stale.
        local lines = { "🤖: a", "```", "body", "```", "after" }
        local built = structure.build(lines, P)
        local out, _, reason = structure.replace(built, 1, 2, { "````" }, P)
        assert.equals("structural", reason, "a width edit must force a rebuild")
        assert.are.same(structure.build({ "🤖: a", "````", "body", "```", "after" }, P).fingerprints,
            out.fingerprints)
    end)

    it("is_partition recognises the turn prefixes and nothing else", function()
        assert.is_true(structure.is_partition("💬: q", P))
        assert.is_true(structure.is_partition("🤖: a", P))
        assert.is_false(structure.is_partition("```", P))
        assert.is_false(structure.is_partition("prose", P))
    end)
end)

-- #218 BR-3/BR-4: the review skill and outline carry their own fence walks. The
-- close review found the review change reverting GREEN across all eight review
-- specs, and outline's third tracker still exhibiting the bug. Both are pinned
-- here against the shared helpers they now use.
describe("shared fence helpers (#218)", function()
    it("is_fence_delim accepts indented fences — the shape the prompt asks for", function()
        assert.are.equal(3, structure.is_fence_delim("```"))
        assert.are.equal(3, structure.is_fence_delim("  ```lua"))
        assert.are.equal(4, structure.is_fence_delim("  ````"))
        assert.is_nil(structure.is_fence_delim("``"))
        assert.is_nil(structure.is_fence_delim("prose ```"))
        -- tildes only when asked (outline's grammar, not the render path's)
        assert.is_nil(structure.is_fence_delim("~~~"))
        assert.are.equal(3, structure.is_fence_delim("~~~", true))
    end)

    it("code_block_memo contains an unmatched fence at the partition", function()
        local P = structure.patterns()
        local memo = structure.code_block_memo({
            "🤖: a", "```", "code", "💬: q", "not code",
        }, P)
        assert.is_true(memo[3], "inside the open fence")
        assert.is_false(memo[4], "partition clears it")
        assert.is_false(memo[5], "and stays clear")
    end)

    it("code_block_memo honours CONFIGURED prefixes, not just defaults", function()
        -- BR-2: patterns() with no config silently disabled containment for
        -- anyone with a custom chat_user_prefix.
        local custom = structure.patterns({
            chat_user_prefix = "U:", chat_assistant_prefix = "A:",
        })
        local lines = { "A: answer", "```", "code", "U: question", "after" }
        local memo = structure.code_block_memo(lines, custom)
        assert.is_false(memo[4], "custom prefix must end the fence")
        assert.is_false(memo[5])
        -- and with default patterns the custom prefix is NOT a partition
        local memo_default = structure.code_block_memo(lines, structure.patterns())
        assert.is_true(memo_default[4], "sanity: defaults do not recognise U:")
    end)
end)

-- #218 BR-22: is_partition was rewritten from M.classify to four anchored
-- prefix matches for speed (6.06ms -> 0.84ms per 5000-line buffer). A perf
-- refactor produces no behavioural red, so the EQUIVALENCE is what needs
-- pinning — otherwise the fast path is free to be subtly wrong.
describe("is_partition fast path equals the classifier (#218)", function()
    it("agrees with classify over the whole decoration grammar", function()
        local P = structure.patterns()
        local corpus = {
            "💬: q", "🤖: a", "🔒: local", "🌿: branch.md: ", "📝: summary",
            "🧠: thinking", "🧠:[END]", "```", "  ```lua", "~~~", "prose",
            "", "   ", "=== draft ===", "=== end ===", "[^id]: a footnote",
            "🔧 tool", "  💬: indented, NOT a partition", "💬 no colon",
            "x💬: not at column zero", "````", "> quoted 💬:",
        }
        for _, line in ipairs(corpus) do
            local token = structure.classify(line, P).token
            local via_classify = token == "u" or token == "a" or token == "l" or token == "b"
            assert.are.equal(via_classify, structure.is_partition(line, P),
                "fast path disagrees with classify on: " .. vim.inspect(line))
        end
    end)
end)

-- #227: the splice's whole contract, over random documents and edit
-- sequences. Tokens, footer and drafts must ALWAYS match a fresh build; state
-- must match whenever replace claims exactness. The vocabulary is weighted to
-- inert rows so both outcomes are exercised heavily.
describe("replace splices stay aligned and honest about exactness (#227)", function()
    local VOCAB = {
        "prose", "prose", "prose", "prose", "more prose", "", "", "   ",
        "```", "````", "=== d ===", "=== end ===",
        "💬: q", "🤖: a", "🧠: r", "🧠:[END]", "[^n]: f", "📝: s", "🔧: t", "📎: r",
        "🌿: b", "🔒: l",
    }
    local function random_lines(count)
        local out = {}
        for i = 1, count do out[i] = VOCAB[math.random(#VOCAB)] end
        return out
    end

    it("matches build() on tokens/footer/drafts always, and on state whenever exact", function()
        math.randomseed(227)
        local exact, approximate = 0, 0
        for _ = 1, 300 do
            local lines = random_lines(math.random(0, 24))
            local current = structure.build(lines, patterns)
            for _ = 1, 12 do
                local first0 = math.random(0, #lines)
                local old_last0 = math.random(first0, math.min(#lines, first0 + 3))
                local inserted = random_lines(math.random(0, 3))
                local post = splice_lines(lines, first0, old_last0, inserted)
                local context = string.format("\nedit [%d,%d) <- %s\nlines:\n%s", first0, old_last0,
                    vim.inspect(inserted), table.concat(lines, "\n"))
                local snapshot = vim.deepcopy(current)
                local out, _, reason = structure.replace(current, first0, old_last0, inserted, patterns)
                local want = structure.build(post, patterns)
                assert.are.same(snapshot, current, "replace mutated its input" .. context)
                assert.are.same(want.fingerprints, out.fingerprints, context)
                assert.equals(want.footer_start0, out.footer_start0, context)
                assert.are.same(want.draft_ranges, out.draft_ranges, context)
                if reason == nil then
                    exact = exact + 1
                    assert.are.same(want.state_before, out.state_before, context)
                    current = out
                else
                    approximate = approximate + 1
                    assert.equals("structural", reason, context)
                    current = want -- what the caller's repair does
                end
                lines = post
            end
        end
        -- Non-vacuity: a property test that never reaches a branch proves nothing.
        assert.is_true(exact >= 150, "exact splices exercised: " .. exact)
        assert.is_true(approximate >= 150, "approximate splices exercised: " .. approximate)
    end)
end)
