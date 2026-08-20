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

-- #200 C1: the diff widened DESTRUCTION (projected start rows → whole span)
-- but originally widened verification only over CREATION. A stale span is
-- handed to the fold clear, so it must be verified too — otherwise reconciling
-- a drifted exchange deletes a neighbour's fold, permanently (hydrate_window
-- latches per buf/win). That breaks the Spec's "always folded" invariant with
-- the same persistence signature #200 exists to eliminate.
describe("span verification", function()
    local projection = require("parley.fold_projection")
    local patterns = require("parley.highlight_structure").patterns({})

    it("accepts a span anchored on its own question and containing no other", function()
        assert.is_true(projection.verify_span(4, 7, {
            [4] = "💬: a question",
            [5] = "",
            [6] = "🤖: [A]",
            [7] = "prose",
        }, patterns))
    end)

    it("rejects a span that overshoots into the next question", function()
        assert.is_false(projection.verify_span(4, 7, {
            [4] = "💬: a question",
            [5] = "🤖: [A]",
            [6] = "prose",
            [7] = "💬: the next question",
        }, patterns))
    end)

    it("rejects a span whose first row is not a question", function()
        assert.is_false(projection.verify_span(4, 6, {
            [4] = "prose",
            [5] = "more",
            [6] = "still more",
        }, patterns))
    end)

    it("rejects a span running past the end of the buffer", function()
        assert.is_false(projection.verify_span(4, 6, { [4] = "💬: q", [5] = "x" }, patterns))
    end)

    it("accepts a single-row span holding only its question", function()
        assert.is_true(projection.verify_span(4, 4, { [4] = "💬: q" }, patterns))
    end)
end)
