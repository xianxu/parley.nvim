local exchange_model = require("parley.exchange_model")

describe("fold_projection", function()
    it("projects only positive semantic fold blocks in block order", function()
        local model = exchange_model.new(4)
        model:add_exchange(2)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "thinking", 2)
        model:add_block(1, "text", 3)
        model:add_block(1, "summary", 1)
        model:add_block(1, "tool_use", 4)
        model:add_block(1, "tool_result", 2)
        model:add_block(1, "thinking", 0)

        model:add_exchange(1)
        model:add_block(2, "agent_header", 1)
        model:add_block(2, "summary", 2)

        local projection = require("parley.fold_projection")
        assert.same({
            { block_index = 3, kind = "thinking", start_0 = 10, end_0 = 11 },
            { block_index = 5, kind = "summary", start_0 = 17, end_0 = 17 },
            { block_index = 6, kind = "tool_use", start_0 = 19, end_0 = 22 },
            { block_index = 7, kind = "tool_result", start_0 = 24, end_0 = 25 },
        }, projection.desired_folds(model, 1))
        assert.same({
            { block_index = 3, kind = "summary", start_0 = 31, end_0 = 32 },
        }, projection.desired_folds(model, 2))
        assert.same({}, projection.desired_folds(model, 3))
    end)

    -- The purity claim, stated exactly. The module LOADS without vim, and the
    -- two predicates that need no classifier RUN without it. verify_anchors
    -- does not — it reaches highlight_structure.classify — and a test that
    -- exercised only the passing pair let a false comment stand.
    it("needs a Neovim global for verify_anchors but not for the rest", function()
        local projection = require("parley.fold_projection")
        local patterns = require("parley.highlight_structure").patterns({})
        projection.verify_anchors({}, {}, patterns)  -- preload the requires
        local saved = _G.vim
        _G.vim = nil
        local anchors_ok = pcall(projection.verify_anchors,
            { { kind = "tool_result", start_0 = 1, end_0 = 2 } },
            { [1] = "📎: x", [2] = "body" }, patterns)
        _G.vim = saved
        assert.is_false(anchors_ok)
    end)

    it("verifies without a Neovim global when patterns are supplied", function()
        local projection = require("parley.fold_projection")
        local patterns = require("parley.highlight_structure").patterns({})
        local saved = _G.vim
        _G.vim = nil
        local ok, result = pcall(projection.verify_starts, { 1, 4 },
            { [1] = "💬: q1", [4] = "💬: q2" }, patterns)
        local ok2, result2 = pcall(projection.ranges_within,
            { { start_0 = 5, end_0 = 6 } }, 4, 8)
        _G.vim = saved

        assert.is_true(ok)
        assert.is_true(result)
        assert.is_true(ok2)
        assert.is_true(result2)
    end)

    it("loads without a Neovim global", function()
        local path = vim.api.nvim_get_runtime_file("lua/parley/fold_projection.lua", false)[1]
        local loader = assert(loadfile(path))
        local saved_vim = _G.vim
        _G.vim = nil
        local ok, projection = pcall(loader)
        _G.vim = saved_vim

        assert.is_true(ok)
        assert.is_function(projection.desired_folds)
    end)
end)

-- #200: the projection is a DESIRED state that must be checked against the
-- buffer before it is applied. A model that drifted from the buffer (any
-- mutation not wrapped in with_exchange_update) otherwise anchors a fold on a
-- 💬: line and leaves it there for the rest of the session.
describe("anchor verification", function()
    local projection = require("parley.fold_projection")
    local patterns = require("parley.highlight_structure").patterns({})

    it("maps every foldable block kind to the marker kind it must anchor on", function()
        assert.equals("reasoning", projection.anchor_kind("thinking"))
        assert.equals("summary", projection.anchor_kind("summary"))
        assert.equals("tool_use", projection.anchor_kind("tool_use"))
        assert.equals("tool_result", projection.anchor_kind("tool_result"))
        assert.is_nil(projection.anchor_kind("text"))
        assert.is_nil(projection.anchor_kind("question"))
    end)

    it("accepts ranges whose anchor line carries the expected marker", function()
        local ranges = {
            { kind = "tool_result", start_0 = 4, end_0 = 5 },
            { kind = "summary", start_0 = 9, end_0 = 9 },
        }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "body",
            [9] = "📝: did the thing",
        }, patterns)
        assert.is_true(ok)
        assert.is_nil(failed)
    end)

    it("rejects a range anchored on a user question and names the offender", function()
        local ranges = {
            { kind = "tool_result", start_0 = 4, end_0 = 4 },
            { kind = "tool_use", start_0 = 9, end_0 = 9 },
        }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [9] = "💬: second question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(2, failed)
    end)

    it("rejects a range whose anchor line is missing from the buffer", function()
        local ranges = { { kind = "tool_use", start_0 = 40, end_0 = 44 } }
        local ok, failed = projection.verify_anchors(ranges, {}, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    -- The Spec's invariant is "a question is never INSIDE a fold" — not merely
    -- "never a fold header". End-drift keeps the anchor correct while the range
    -- overshoots into the next exchange's question.
    it("rejects a range whose interior swallows a user question", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 8 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "```",
            [6] = "body",
            [7] = "```",
            [8] = "💬: next question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("rejects a range whose interior runs past the end of the buffer", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 6 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "body",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    -- The interior scan is a guard against DRIFT, not a second fence parser:
    -- it must reject only a line classified as `user` at column 0. M2 owns
    -- in-body marker suppression.
    -- M2 accepted a marker inside a body even at COLUMN 0, on the premise that
    -- "tool output quotes transcripts". #203 measured that premise false: every
    -- tool prefixes its output, so a transcript read by read_file arrives as
    -- "    1  💬: …" and its marker is never at column 0. The reachable case is
    -- the prefixed one, and that is what this now pins. The guard must still
    -- fire for a marker OUTSIDE the body — the drift it exists to catch.
    it("accepts a quoted question marker inside the fenced body", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 8 } }
        assert.is_true(projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "```",
            [6] = "    1  💬: a question quoted from the file being read",
            [7] = "    2  🤖: and its answer",
            [8] = "```",
        }, patterns))
    end)

    -- The inverted half (#203): a COLUMN-0 marker inside a body cannot have come
    -- from a tool, so the content is hand-edited, truncated, or pasted. The body
    -- does not span it — forking there is the visible degradation chosen over
    -- silently swallowing every exchange that follows.
    it("does not extend a body across a column-0 question marker", function()
        local lines = {
            "📎: read_file", "```",
            "💬: pasted, not tool output",
            "```",
        }
        local hs = require("parley.highlight_structure")
        local bodies = require("parley.fence").scan(lines,
            function(_, row) return row == 1 end,
            function(line) return hs.is_structural_kind(hs.classify(line, patterns).kind) end)
        assert.message("a body spanned a column-0 marker it cannot have produced")
            .is_nil(bodies[1])
    end)

    it("still rejects a question after the body has closed", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 8 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "```",
            [6] = "content",
            [7] = "```",
            [8] = "💬: next question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("keeps a longer nested fence from closing the body early", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 9 } }
        assert.is_true(projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = "````",
            [6] = "```",
            [7] = "    1  💬: still inside the outer body",
            [8] = "```",
            [9] = "````",
        }, patterns))
    end)

    -- BR-33: entering body mode on ANY fence, for ANY range kind, silently
    -- disables the question guard for the rest of the range. A bare run is
    -- indistinguishable from an opener, so one grammar-rejected fence desyncs
    -- the scan — and render_buffer emits ```json {"type": "request"}, whose
    -- info string the grammar rejects.
    -- Characterization, NOT a fix pin: verified green against b2bf1d5~1 too.
    -- The rejected-opener case below is the one that actually pins BR-33.
    it("keeps guarding a thinking block, which has no fenced body", function()
        local ranges = { { kind = "thinking", start_0 = 4, end_0 = 8 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "🧠: reasoning",
            [5] = "```",
            [6] = "some code the model was thinking about",
            [7] = "```",
            [8] = "💬: drifted into the next question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("keeps guarding after a fence the grammar does not accept as an opener", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 9 } }
        local ok, failed = projection.verify_anchors(ranges, {
            [4] = "📎: read_file",
            [5] = '```json {"type": "request"}',  -- info string the grammar rejects
            [6] = "body",
            [7] = "```",
            [8] = "more",
            [9] = "💬: drifted into the next question",
        }, patterns)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("does not mistake a question marker inside a fenced body for a turn", function()
        local ranges = { { kind = "tool_result", start_0 = 4, end_0 = 7 } }
        local ok = projection.verify_anchors(ranges, {
            [4] = "📎: grep",
            [5] = "```",
            [6] = "  💬: matched line from a transcript",
            [7] = "```",
        }, patterns)
        assert.is_true(ok)
    end)
end)

-- #200: positional reasoning cannot police an individual clear (a row-span is
-- not an identity — see exchange_anchors), but it is the right check for
-- deciding whether a model is sound enough to anchor identity FROM.
-- #200: containment is what ties the two halves together — verification proves
-- a range matches the buffer's text, identity proves which rows the exchange
-- owns, and only this proves they describe the same exchange. Pure, so it is
-- pinned here rather than only through an integration path.
describe("range containment", function()
    local projection = require("parley.fold_projection")

    it("accepts ranges wholly inside the owned rows", function()
        local ok, failed = projection.ranges_within(
            { { start_0 = 5, end_0 = 8 }, { start_0 = 10, end_0 = 10 } }, 4, 12)
        assert.is_true(ok)
        assert.is_nil(failed)
    end)

    it("rejects a range starting before the owned rows and names it", function()
        local ok, failed = projection.ranges_within(
            { { start_0 = 5, end_0 = 8 }, { start_0 = 2, end_0 = 6 } }, 4, 12)
        assert.is_false(ok)
        assert.equals(2, failed)
    end)

    it("rejects a range running past the owned rows", function()
        local ok, failed = projection.ranges_within({ { start_0 = 5, end_0 = 13 } }, 4, 12)
        assert.is_false(ok)
        assert.equals(1, failed)
    end)

    it("rejects when no rows are owned at all", function()
        assert.is_false(projection.ranges_within({ { start_0 = 5, end_0 = 8 } }, nil, nil))
    end)

    it("accepts an empty range list inside owned rows", function()
        assert.is_true(projection.ranges_within({}, 4, 12))
    end)
end)

describe("start-row validation", function()
    local projection = require("parley.fold_projection")
    local patterns = require("parley.highlight_structure").patterns({})

    it("accepts ascending starts that each begin on a question", function()
        assert.is_true(projection.verify_starts({ 1, 4, 7 }, {
            [1] = "💬: q1", [4] = "💬: q2", [7] = "💬: q3",
        }, patterns))
    end)

    it("rejects a start that is not a question", function()
        assert.is_false(projection.verify_starts({ 1, 4 }, {
            [1] = "💬: q1", [4] = "just prose",
        }, patterns))
    end)

    -- chat_parser fabricates a question block for an assistant-first
    -- transcript, so exchange 1 legitimately starts off-question. Refusing it
    -- would leave identity permanently unavailable for those transcripts.
    it("exempts exchange 1, which the parser may start off-question", function()
        assert.is_true(projection.verify_starts({ 0, 4 }, {
            [0] = "", [4] = "💬: q2",
        }, patterns))
    end)

    it("rejects starts that are not strictly ascending", function()
        assert.is_false(projection.verify_starts({ 4, 4 }, {
            [4] = "💬: q1",
        }, patterns))
    end)

    it("rejects a start past the end of the buffer", function()
        assert.is_false(projection.verify_starts({ 1, 40 }, { [1] = "💬: q1" }, patterns))
    end)

    it("rejects an empty model", function()
        assert.is_false(projection.verify_starts({}, {}, patterns))
    end)
end)
