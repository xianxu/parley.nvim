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

describe("buffer_edit.pad_question_with_blank", function()
    it("inserts a blank line right after the given 0-indexed line", function()
        local b = mk_buf({ "💬: q", "next stuff" })
        be.pad_question_with_blank(b, 0)
        assert.same({ "💬: q", "", "next stuff" }, buf_lines(b))
    end)
end)

describe("buffer_edit.create_answer_region", function()
    it("inserts blank + agent header + blank after the given line, returns handle at write position", function()
        local b = mk_buf({ "💬: q" })
        local h = be.create_answer_region(b, 0, "[Claude]")
        assert.same({ "💬: q", "", "🤖: [Claude]", "" }, buf_lines(b))
        -- Handle points at the trailing blank (line index 3, 0-indexed)
        -- which is where streaming writes go.
        assert.equals(3, be.handle_line(h))
    end)

    it("supports an agent suffix", function()
        local b = mk_buf({ "💬: q" })
        be.create_answer_region(b, 0, "[Claude]", "[🔧]")
        assert.same({ "💬: q", "", "🤖: [Claude][🔧]", "" }, buf_lines(b))
    end)
end)

describe("buffer_edit.delete_answer", function()
    it("deletes the answer region (inclusive line range)", function()
        local b = mk_buf({ "💬: q", "🤖: [A]", "answer", "💬: q2" })
        be.delete_answer(b, 1, 2)
        assert.same({ "💬: q", "💬: q2" }, buf_lines(b))
    end)
end)

describe("buffer_edit.replace_answer", function()
    it("deletes the answer region and inserts a single blank separator, returns handle at the blank", function()
        local b = mk_buf({ "💬: q", "🤖: [A]", "old answer", "💬: q2" })
        local h = be.replace_answer(b, 1, 2)
        assert.same({ "💬: q", "", "💬: q2" }, buf_lines(b))
        assert.equals(1, be.handle_line(h))
    end)
end)

describe("buffer_edit.insert_raw_request_fence", function()
    it("inserts the fence lines at the given 0-indexed line", function()
        local b = mk_buf({ "💬: q", "next" })
        be.insert_raw_request_fence(b, 1, { "", "```json", "{}", "```" })
        assert.same({ "💬: q", "", "```json", "{}", "```", "next" }, buf_lines(b))
    end)
end)

describe("buffer_edit.append_section_to_answer", function()
    it("appends a rendered text section after a non-empty line, with a blank separator", function()
        local b = mk_buf({ "💬: q", "🤖: [A]", "first" })
        local h = be.append_section_to_answer(b, 2, { kind = "text", text = "second" })
        assert.same({ "💬: q", "🤖: [A]", "first", "", "second" }, buf_lines(b))
        -- Handle points at the line after the last appended line.
        assert.equals(4, be.handle_line(h))
    end)

    it("appends a rendered text section after a blank line WITHOUT extra separator", function()
        local b = mk_buf({ "💬: q", "🤖: [A]", "" })
        be.append_section_to_answer(b, 2, { kind = "text", text = "after blank" })
        assert.same({ "💬: q", "🤖: [A]", "", "after blank" }, buf_lines(b))
    end)

    it("appends a tool_use section", function()
        local b = mk_buf({ "💬: q", "🤖: [A]", "" })
        be.append_section_to_answer(b, 2, {
            kind = "tool_use",
            id = "toolu_X",
            name = "read_file",
            input = { path = "foo.txt" },
        })
        local lines = buf_lines(b)
        assert.equals("💬: q", lines[1])
        assert.equals("🤖: [A]", lines[2])
        assert.equals("", lines[3])
        assert.matches("^🔧: read_file id=toolu_X$", lines[4])
        assert.matches("^```json", lines[5])
    end)
end)
