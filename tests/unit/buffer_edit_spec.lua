-- Unit tests for lua/parley/buffer_edit.lua
--
-- buffer_edit is the single mutation entry point for the chat buffer.
-- All nvim_buf_set_lines / nvim_buf_set_text calls in the plugin will
-- eventually live here. PosHandle is an opaque extmark-backed position
-- token that callers chain operations through.
--
-- Tests use real scratch buffers (nvim_create_buf(false, true)) to
-- exercise the actual nvim semantics.

local be = require("parley.buffer_edit")

local function mk_buf(lines)
    local b = vim.api.nvim_create_buf(false, true)
    if lines then
        vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    end
    return b
end

local function buf_lines(b)
    return vim.api.nvim_buf_get_lines(b, 0, -1, false)
end

describe("buffer_edit.PosHandle", function()
    it("make_handle / handle_line returns the line", function()
        local b = mk_buf({ "a", "b", "c" })
        local h = be.make_handle(b, 1)
        assert.equals(1, be.handle_line(h))
    end)

    it("handle position drifts naturally with extmark gravity", function()
        local b = mk_buf({ "a", "b", "c" })
        local h = be.make_handle(b, 2)  -- pointing at "c" (0-indexed line 2)
        be.set_topic_header_line(b, 0, "X")  -- replaces "a" → no shift
        assert.equals(2, be.handle_line(h))  -- still on "c"
        be.insert_topic_line(b, 0, "Y")  -- insert after line 0
        assert.equals(3, be.handle_line(h))  -- "c" pushed down by one
    end)

    it("handle_invalidate marks the handle dead and disables operations", function()
        local b = mk_buf({ "a", "b" })
        local h = be.make_handle(b, 0)
        be.handle_invalidate(h)
        assert.is_true(h.dead)
        assert.has_error(function() be.handle_line(h) end)
    end)
end)

describe("buffer_edit.topic header ops", function()
    it("set_topic_header_line replaces a single line", function()
        local b = mk_buf({ "old", "rest" })
        be.set_topic_header_line(b, 0, "new")
        assert.same({ "new", "rest" }, buf_lines(b))
    end)

    it("insert_topic_line inserts after the given 0-indexed line", function()
        local b = mk_buf({ "a", "c" })
        be.insert_topic_line(b, 0, "b")
        assert.same({ "a", "b", "c" }, buf_lines(b))
    end)
end)
