-- Unit tests for chat_parser.lua recognition of `🔧:` (tool_use) and
-- `📎:` (tool_result) components inside a `🤖:` assistant answer.
--
-- M2 Task 2.5 of issue #81. The parser walks the chat buffer line
-- by line (see chat_parser.lua:261). Before this task, an answer
-- had a single flat `content` string. After this task, an answer
-- ALSO has a `content_blocks` list preserving the buffer order of
-- interleaved text / tool_use / tool_result components.
--
-- Backward compatibility invariant: `answer.content` still holds
-- the full concatenated text of the answer region (same behavior
-- as before this task). Existing callers that only read .content
-- are unaffected.
--
-- The parser delegates tool block body parsing to
-- lua/parley/tools/serialize.lua (landed in Task 2.1), so changes
-- to the 🔧:/📎: serialization schema automatically propagate into
-- the parser without re-writing any regex here.

local parser = require("parley.chat_parser")
local serialize = require("parley.tools.serialize")

-- Minimal config table the parser needs. Pulled from config.lua
-- defaults but inlined so this test doesn't depend on parley.setup().
local function test_config()
    return {
        chat_user_prefix = "💬:",
        chat_local_prefix = "🔒:",
        chat_branch_prefix = "🌿:",
        chat_assistant_prefix = { "🤖:", "[{{agent}}]" },
        chat_tool_use_prefix = "🔧:",
        chat_tool_result_prefix = "📎:",
        chat_memory = { enable = false },
    }
end

-- Helper to build a chat buffer: skips the YAML front matter by
-- returning (lines, header_end=0).
local function buf(line_list)
    return line_list, 0
end

-- Finds the first exchange's answer block list. Returns nil if
-- the exchange or answer is missing.
local function first_answer_blocks(parsed)
    local ex = parsed.exchanges[1]
    if not ex or not ex.answer then return nil end
    return ex.answer.content_blocks
end

--------------------------------------------------------------------------------
-- Shape
--------------------------------------------------------------------------------

describe("chat_parser content_blocks shape", function()
    it("answer without tool blocks gets a single-text content_blocks list", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "hi there",
            "second line",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_table(blocks)
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("hi there", blocks[1].text)
        assert.matches("second line", blocks[1].text)
    end)

    it("preserves the flat answer.content for backward compat", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "flat text",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        assert.equals("flat text", parsed.exchanges[1].answer.content)
    end)

    it("empty answer produces either empty list or a single empty-trimmed text block", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        -- Either zero blocks (empty trimmed text filtered out) OR one
        -- empty-text block. Both are valid; just ensure it's a table
        -- and doesn't crash downstream consumers.
        assert.is_table(blocks)
    end)
end)

--------------------------------------------------------------------------------
-- Tool blocks
--------------------------------------------------------------------------------

describe("chat_parser tool_use / tool_result recognition", function()
    it("recognizes a single tool_use block inside an answer", function()
        -- Build a serialized tool_use block the way tool_loop would
        -- write it, so the parser's body-decoding stays in sync with
        -- the writer (via serialize.parse_call).
        local tool_use_block = serialize.render_call({
            id = "toolu_01",
            name = "read_file",
            input = { path = "foo.txt" },
        })
        local lines = { "💬: question", "🤖: [Claude]", "Let me read that file." }
        for l in tool_use_block:gmatch("[^\n]+") do
            table.insert(lines, l)
        end
        -- Also capture the empty trailing line the serializer produces
        -- (none — render_call has no trailing newline — ok)

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- Expected block order: [text "Let me read that file.", tool_use]
        assert.equals(2, #blocks)

        assert.equals("text", blocks[1].type)
        assert.matches("Let me read that file%.", blocks[1].text)

        assert.equals("tool_use", blocks[2].type)
        assert.equals("toolu_01", blocks[2].id)
        assert.equals("read_file", blocks[2].name)
        assert.equals("foo.txt", blocks[2].input.path)
    end)

    it("recognizes a tool_use followed by a tool_result", function()
        local tool_use_block = serialize.render_call({
            id = "toolu_02",
            name = "read_file",
            input = { path = "bar.txt" },
        })
        local tool_result_block = serialize.render_result({
            id = "toolu_02",
            name = "read_file",
            content = "    1  line one\n    2  line two",
            is_error = false,
        })

        local lines = { "💬: q", "🤖: [Claude]" }
        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end
        table.insert(lines, "Based on that file, the first line is 'line one'.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- Expected: tool_use, tool_result, text
        assert.equals(3, #blocks)
        assert.equals("tool_use", blocks[1].type)
        assert.equals("toolu_02", blocks[1].id)
        assert.equals("tool_result", blocks[2].type)
        assert.equals("toolu_02", blocks[2].id)
        assert.equals(false, blocks[2].is_error)
        assert.matches("line one", blocks[2].content)
        assert.equals("text", blocks[3].type)
        assert.matches("first line is 'line one'", blocks[3].text)
    end)

    it("handles multiple tool_use/result pairs in one answer", function()
        local lines = { "💬: q", "🤖: [Claude]", "Reading two files." }
        for _, cfg in ipairs({
            { id = "toolu_A", path = "a.txt" },
            { id = "toolu_B", path = "b.txt" },
        }) do
            local tu = serialize.render_call({
                id = cfg.id,
                name = "read_file",
                input = { path = cfg.path },
            })
            local tr = serialize.render_result({
                id = cfg.id,
                name = "read_file",
                content = "body of " .. cfg.path,
                is_error = false,
            })
            for l in tu:gmatch("[^\n]+") do table.insert(lines, l) end
            for l in tr:gmatch("[^\n]+") do table.insert(lines, l) end
        end
        table.insert(lines, "Both files read successfully.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)

        -- Expected: text, tu_A, tr_A, tu_B, tr_B, text
        local types_in_order = {}
        for _, b in ipairs(blocks) do table.insert(types_in_order, b.type) end
        assert.same({ "text", "tool_use", "tool_result", "tool_use", "tool_result", "text" }, types_in_order)

        -- Verify the tool blocks carry the right ids in the right order
        local tool_block_ids = {}
        for _, b in ipairs(blocks) do
            if b.id then table.insert(tool_block_ids, b.id) end
        end
        assert.same({ "toolu_A", "toolu_A", "toolu_B", "toolu_B" }, tool_block_ids)
    end)

    it("recognizes an error tool_result (is_error=true)", function()
        local tool_use_block = serialize.render_call({
            id = "toolu_err", name = "edit_file",
            input = { path = "x", old_string = "a", new_string = "b" },
        })
        local tool_result_block = serialize.render_result({
            id = "toolu_err", name = "edit_file",
            content = "old_string not found in file",
            is_error = true,
        })
        local lines = { "💬: q", "🤖: [Claude]" }
        for l in tool_use_block:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tool_result_block:gmatch("[^\n]+") do table.insert(lines, l) end

        local parsed = parser.parse_chat(lines, 0, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.equals(2, #blocks)
        assert.equals("tool_result", blocks[2].type)
        assert.equals(true, blocks[2].is_error)
        assert.matches("not found", blocks[2].content)
    end)
end)

--------------------------------------------------------------------------------
-- Multiple exchanges (state reset)
--------------------------------------------------------------------------------

describe("chat_parser content_blocks across multiple exchanges", function()
    it("each answer's content_blocks is independent", function()
        local tu1 = serialize.render_call({ id = "toolu_E1", name = "read_file", input = { path = "a" } })
        local tr1 = serialize.render_result({ id = "toolu_E1", name = "read_file", content = "body a", is_error = false })

        local lines = { "💬: first", "🤖: [Claude]", "Reading a." }
        for l in tu1:gmatch("[^\n]+") do table.insert(lines, l) end
        for l in tr1:gmatch("[^\n]+") do table.insert(lines, l) end

        table.insert(lines, "💬: second")
        table.insert(lines, "🤖: [Claude]")
        table.insert(lines, "Just text, no tools.")

        local parsed = parser.parse_chat(lines, 0, test_config())
        assert.equals(2, #parsed.exchanges)

        local first_blocks = parsed.exchanges[1].answer.content_blocks
        local second_blocks = parsed.exchanges[2].answer.content_blocks

        -- First exchange has tool blocks
        local first_types = {}
        for _, b in ipairs(first_blocks) do table.insert(first_types, b.type) end
        assert.is_true(#first_blocks >= 2)
        local has_tool_use = false
        for _, t in ipairs(first_types) do if t == "tool_use" then has_tool_use = true end end
        assert.is_true(has_tool_use, "first exchange should contain a tool_use block")

        -- Second exchange has NO tool blocks (pure text)
        assert.equals(1, #second_blocks)
        assert.equals("text", second_blocks[1].type)
        assert.matches("Just text, no tools", second_blocks[1].text)
    end)
end)

--------------------------------------------------------------------------------
-- Interaction with other prefixes
--------------------------------------------------------------------------------

describe("chat_parser content_blocks vs other prefixes", function()
    it("summary and reasoning lines do not split text blocks", function()
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "🧠: thinking about it",
            "First part of answer.",
            "📝: one-liner summary",
            "Second part of answer.",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        -- summary and reasoning are stored as separate fields on the
        -- exchange, NOT as content blocks. The text block should
        -- contain both "First part" and "Second part".
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("First part", blocks[1].text)
        assert.matches("Second part", blocks[1].text)
        -- And the reasoning/summary are still captured as exchange
        -- fields (existing behavior — regression check)
        assert.is_not_nil(parsed.exchanges[1].reasoning)
        assert.is_not_nil(parsed.exchanges[1].summary)
    end)

    it("local 🔒: section inside an answer stops content block accumulation", function()
        -- Existing parser behavior: once 🔒: is seen, content continuation
        -- is skipped until the next 💬:/🤖: prefix. Our content_blocks
        -- should match that behavior — no local-section lines leak in.
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "Visible text.",
            "🔒: private scratch notes",
            "still private because line_before_local is set",
            "💬: second turn",
            "🤖: [Claude]",
            "next answer",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.equals(1, #blocks)
        assert.equals("text", blocks[1].type)
        assert.matches("Visible text", blocks[1].text)
        assert.not_matches("still private", blocks[1].text)
        assert.not_matches("private scratch notes", blocks[1].text)
    end)
end)

--------------------------------------------------------------------------------
-- Malformed tool blocks
--------------------------------------------------------------------------------

describe("chat_parser tolerates malformed tool blocks", function()
    it("a tool_use prefix without a fenced body still produces a tool_use block with empty input", function()
        -- The user may have hand-typed a 🔧: header and moved on.
        -- Parser must not crash. Empty input is the safest fallback.
        local lines, header_end = buf({
            "💬: hello",
            "🤖: [Claude]",
            "🔧: read_file id=toolu_bare",
        })
        local parsed = parser.parse_chat(lines, header_end, test_config())
        local blocks = first_answer_blocks(parsed)
        assert.is_not_nil(blocks)
        -- At least one tool_use block with the expected id
        local found = nil
        for _, b in ipairs(blocks) do
            if b.type == "tool_use" then found = b end
        end
        assert.is_not_nil(found)
        assert.equals("toolu_bare", found.id)
        assert.equals("read_file", found.name)
        assert.same({}, found.input)
    end)
end)

-- #200 M2: cb_append_line already tracked tool-body fences correctly
-- (chat_parser.lua:455-469), but the main loop classified every line without
-- consulting that state. Tool output routinely contains 💬:/🤖:/📎: lines —
-- reading a transcript, grepping this repo — and each one forked a spurious
-- exchange that then dragged the rest of the tool body out of its block.
describe("structural markers inside a tool body (#200)", function()
    -- Reuses the file's existing `parser` and `test_config()` helpers rather
    -- than introducing a second set.
    local function parse(lines)
        return parser.parse_chat(lines, 4, test_config())
    end

    local header = { "---", "topic: t", "file: f.md", "---" }

    -- #203: the reachable shape. read_file emits "%5d  %s", so a transcript it
    -- reads carries its markers indented — those are content, and the body spans
    -- them. The column-0 variant is pinned separately below, and forks.
    it("treats a quoted question marker inside a tool result as content", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: show me the transcript",
            "",
            "🤖: [A]",
            "📎: read_file id=r1",
            "```",
            "    1  💬: a question from the file being read",
            "    2  🤖: and its answer",
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

    -- #203's inverted half. The body above is prefixed, so it spans its
    -- markers. This one is not — which means the content did not come from a
    -- parley tool, so the body does not span it and the question forks. Visible
    -- over-forking is the degradation chosen over silently swallowing the rest
    -- of the chat.
    it("forks on a column-0 question marker no tool could have produced", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "📎: read_file id=r1",
            "```",
            "💬: pasted from elsewhere, not tool output",
            "```",
            "",
            "💬: q2",
        })
        assert.message("a column-0 marker was swallowed as body content")
            .equals(3, #parse(lines).exchanges)
    end)

    -- #203 BR-14: this asserted only "1 exchange", which is true whether the
    -- body SPANS the marker or is REFUSED — so it could not see the change, and
    -- its name went on claiming the premise this issue refuted. It asserts the
    -- body extent now, which is the thing that actually differs, and splits into
    -- the two cases the old fixture conflated.
    it("treats a PREFIXED tool-result marker inside a tool body as content", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q",
            "",
            "🤖: [A]",
            "📎: grep id=r1",
            "```",
            "match: 📎: read_file id=other",
            "chat.md:12: 📎: read_file id=other",
            "```",
        })
        local parsed = parse(lines)
        assert.equals(1, #parsed.exchanges)
        assert.message("a prefixed marker is grep output, so the body must span it")
            .is_true(#(parsed.exchanges[1].answer.content_blocks or {}) > 0)
    end)

    -- The tool-marker members of STRUCTURAL_KINDS had no coverage at all: every
    -- other case in this issue exercises 💬:. A body must refuse to span these
    -- too, or a column-0 📎: inside one body swallows the NEXT tool block.
    -- Asserted on fence.scan's BODY EXTENT, not on an exchange count. The count
    -- is 2 whether the body spans the marker or refuses it, so it cannot see the
    -- rule — which is the exact defect BR-14 named, and which the first version
    -- of these very cases committed again (#203 BR-14 round 4). The extent
    -- discriminates: nil when refused, {first,last,close} when spanned.
    for _, marker in ipairs({ "📎: read_file id=other", "🔧: read_file id=next",
                              "📝: a summary", "🔒: local", "🌿: branch" }) do
        it("refuses to span a column-0 " .. marker:sub(1, 4) .. " inside a body", function()
            local hs = require("parley.highlight_structure")
            local patterns = hs.patterns(require("parley.config"))
            local body = { "📎: grep id=r1", "```", marker, "```" }
            local bodies = require("parley.fence").scan(body,
                function(line) return hs.classify(line, patterns).kind == "tool_result"
                    or hs.classify(line, patterns).kind == "tool_use" end,
                function(line) return hs.is_structural_kind(hs.classify(line, patterns).kind) end)
            assert.message(("a body spanned a column-0 %q, which no tool emits"):format(marker))
                .is_nil(bodies[1])
        end)

        it("DOES span the same marker when prefixed, as a tool emits it", function()
            local hs = require("parley.highlight_structure")
            local patterns = hs.patterns(require("parley.config"))
            local body = { "📎: grep id=r1", "```", "chat.md:12: " .. marker, "```" }
            local bodies = require("parley.fence").scan(body,
                function(line) return hs.classify(line, patterns).kind == "tool_result"
                    or hs.classify(line, patterns).kind == "tool_use" end,
                function(line) return hs.is_structural_kind(hs.classify(line, patterns).kind) end)
            assert.message("a prefixed marker is tool output; the body must span it")
                .is_not_nil(bodies[1])
        end)
    end

    it("resumes structural parsing after the body closes", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "📎: read id=r1",
            "```",
            "    1  💬: not a turn",
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
            "    1  💬: still content",
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

-- BR-30: suppression was gated on "fence open and body not complete", with no
-- terminator. An opener that never gets a matching bare close reclassified
-- every later marker as text, so the rest of the chat forked no exchanges at
-- all. Reachable without a malformed file: an answer quoting a 📎: line in
-- ordinary prose starts a tool block whose body never closes.
describe("unterminated tool body (#200 BR-30)", function()
    local function parse(lines)
        return parser.parse_chat(lines, 4, test_config())
    end
    local header = { "---", "topic: t", "file: f.md", "---" }

    it("does not swallow the rest of the chat after an unclosed fence", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "📎: read id=r1",
            "```",
            "a body whose fence is never closed",
            "",
            "💬: q2",
            "",
            "🤖: [A]",
            "",
            "💬: q3",
        })
        assert.message("an unclosed fence swallowed the following exchanges")
            .equals(3, #parse(lines).exchanges)
    end)

    -- Characterization, NOT a fix pin: verified green against b2bf1d5 as well.
    -- The swallow case above is the one that pins BR-30.
    it("does not swallow the chat when prose quotes a tool marker", function()
        local lines = vim.list_extend(vim.deepcopy(header), {
            "",
            "💬: q1",
            "",
            "🤖: [A]",
            "The transcript format uses lines like",
            "📎: read_file id=example",
            "to mark a tool result.",
            "",
            "💬: q2",
        })
        assert.equals(2, #parse(lines).exchanges)
    end)
end)

-- BR-43: three shapes where a tool-body scan that accepts an opener anywhere
-- after the marker, or rejects a legitimate CommonMark opener, reads a CLOSING
-- fence as an opening one — and the rest of the chat stops forking exchanges.
-- None of them appears in the live 115-file corpus.
describe("tool-body extent desync (#200 BR-43)", function()
    local function count(extra)
        local lines = { "---", "topic: t", "file: f.md", "---" }
        vim.list_extend(lines, extra)
        return #parser.parse_chat(lines, 4, test_config()).exchanges
    end

    it("survives an opener whose info string the old grammar rejected", function()
        assert.equals(3, count({
            "", "💬: q1", "", "🤖: [A]", "📎: r id=1",
            '```json {"type": "request"}', "body", "```",
            "", "💬: q2", "", "🤖: [A]", "", "💬: q3",
        }))
    end)

    -- Deferred to #203 (operator decision, 2026-08-21). An unclosed body
    -- that latches onto a later unrelated bare fence is locally
    -- indistinguishable from a legitimate body quoting a transcript: both have
    -- an opener after the marker and a matching bare close further down. Every
    -- local discriminator tried either reintroduces the swallow or defeats M2's
    -- headline case (suppressing a 💬: that really is tool output). Bounding at
    -- the "next structural boundary" is circular — the boundary may itself be
    -- inside the body.
    --
    -- FIXED by #203, and not with the fence-depth parser this comment once
    -- predicted. A body may not span a column-0 structural marker, which is
    -- safe because no tool emits one — every tool prefixes its output. So the
    -- unclosed body stops at 💬: q2 instead of latching onto the later bare
    -- fence, and the exchanges it used to swallow survive.
    it("survives an unclosed body followed by a later bare fence", function()
        assert.equals(3, count({
            "", "💬: q1", "", "🤖: [A]", "📎: r id=1", "```", "never closed",
            "", "💬: q2", "", "🤖: [A]", "```", "", "💬: q3",
        }))
    end)

    -- #203: chat_parser carries a SECOND fence tracker (cb_state.tool_fence_len,
    -- chat_parser.lua:456) that closes a content block on the first
    -- matching-length bare fence, with no structural-marker bound. It can
    -- therefore disagree with fence.scan on the malformed shape. It does not,
    -- because the fork finalizes the block before the later fence is reached —
    -- but "does not" needs a pin, since a second grammar for the same fence is
    -- what #200 removed. This asserts the two agree where they could differ.
    it("does not let the second fence tracker swallow the forked exchanges", function()
        local lines = { "---", "topic: t", "file: f.md", "---" }
        vim.list_extend(lines, {
            "", "💬: q1", "", "🤖: [A]", "📎: r id=1", "```", "never closed",
            "", "💬: q2", "", "🤖: [A]", "```", "", "💬: q3",
        })
        local parsed = parser.parse_chat(lines, 4, test_config())
        assert.equals(3, #parsed.exchanges)
        for _, block in ipairs(parsed.exchanges[1].answer.content_blocks or {}) do
            local text = type(block.content) == "string" and block.content or ""
            assert.message("exchange 1's block absorbed a later exchange: " .. text)
                .is_nil(text:find("q2", 1, true))
        end
    end)

    -- The truncated-mid-write shape: the writer died after the opener, so there
    -- is no close anywhere. Nothing later may be absorbed.
    it("survives a body truncated mid-write with no close at all", function()
        assert.equals(3, count({
            "", "💬: q1", "", "🤖: [A]", "📎: r id=1", "````", "partial output",
            "", "💬: q2", "", "🤖: [A]", "", "💬: q3",
        }))
    end)

    -- The shape that folded a question at HEAD: a 📎: inside a ```text block is
    -- not a marker, and treating it as one made that block's CLOSER read as a
    -- body opener, so the "body" spanned 💬: q2 and fold_projection suppressed
    -- its own guard over those rows.
    it("does not treat a marker inside an ordinary fenced block as structural", function()
        assert.equals(3, count({
            "", "💬: q1", "🤖: [A]", "```text", "📎: read_file id=x", "```", "",
            "💬: q2", "", "🤖: [A]", "```", "code", "```", "", "💬: q3",
        }))
    end)

    it("survives an answer that shows the transcript format in a plain block", function()
        assert.equals(3, count({
            "", "💬: q1", "", "🤖: [A]", "the transcript format looks like",
            "```text", "📎: read_file id=x", "```",
            "", "💬: q2", "", "🤖: [A]", "", "💬: q3",
        }))
    end)
end)
