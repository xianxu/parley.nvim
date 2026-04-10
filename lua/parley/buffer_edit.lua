-- Single mutation entry point for the chat buffer.
--
-- All nvim_buf_set_lines / nvim_buf_set_text calls in the chat buffer
-- rendering pipeline live here. The architectural fitness function in
-- tests/arch/buffer_mutation_spec.lua enforces this invariant.
--
-- See docs/plans/000090-renderer-refactor.md section 3.

local M = {}

local NS_NAME = "ParleyBufferEdit"
local ns_id = vim.api.nvim_create_namespace(NS_NAME)

-- ============================================================================
-- PosHandle: opaque extmark-backed position. Caller never sees raw line
-- numbers. Internally a { buf, ns_id, ex_id, dead } table; the line is
-- resolved on demand via nvim_buf_get_extmark_by_id, so concurrent
-- inserts at or before the position are handled by the extmark gravity
-- mechanism (right_gravity = false means inserts AT the position push
-- the handle right, perfect for "anchor before this line, append text").
-- ============================================================================

--- Create a position handle anchored at a 0-indexed buffer line.
--- @param buf integer
--- @param line_0_indexed integer
--- @return PosHandle
function M.make_handle(buf, line_0_indexed)
    local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_0_indexed, 0, {
        right_gravity = false,
        strict = false,
    })
    return { buf = buf, ns_id = ns_id, ex_id = ex_id, dead = false }
end

--- Resolve the current 0-indexed buffer line of a handle.
function M.handle_line(handle)
    if handle.dead then
        error("buffer_edit: handle is dead")
    end
    local pos = vim.api.nvim_buf_get_extmark_by_id(handle.buf, handle.ns_id, handle.ex_id, {})
    return pos[1]
end

--- Mark a handle dead and remove its extmark. Subsequent operations on
--- the handle raise.
function M.handle_invalidate(handle)
    if not handle.dead then
        pcall(vim.api.nvim_buf_del_extmark, handle.buf, handle.ns_id, handle.ex_id)
        handle.dead = true
    end
end

-- ============================================================================
-- Topic header ops
-- ============================================================================

--- Replace the line at line_0_indexed with `text`.
function M.set_topic_header_line(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text })
end

--- Insert `text` as a new line right after line_0_indexed.
function M.insert_topic_line(buf, after_line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { text })
end

-- ============================================================================
-- Answer region ops
-- ============================================================================

local render_buffer = require("parley.render_buffer")

--- Insert a single blank line after the given 0-indexed line. Used to
--- pad a question that doesn't already end with whitespace.
function M.pad_question_with_blank(buf, after_line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { "" })
end

--- Create a fresh answer region after the given 0-indexed line. Writes
--- a blank separator + agent header + trailing blank, returning a
--- PosHandle pointing at the trailing blank — the line where streaming
--- writes should append.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param agent_prefix string  e.g. "[Claude]"
--- @param agent_suffix string|nil  e.g. "[🔧]"
--- @return PosHandle
function M.create_answer_region(buf, after_line_0_indexed, agent_prefix, agent_suffix)
    local lines = render_buffer.agent_header_lines(agent_prefix, agent_suffix)
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, lines)
    -- Trailing blank is at insert_at + #lines - 1.
    return M.make_handle(buf, insert_at + #lines - 1)
end

--- Delete an answer region by inclusive 0-indexed line range.
function M.delete_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, {})
end

--- Replace an answer region with a single blank separator. Returns a
--- handle anchored at the blank — the next answer's create_answer_region
--- should be called using this handle's resolved line.
function M.replace_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, { "" })
    return M.make_handle(buf, line_start_0_indexed)
end

--- Insert pre-rendered raw_request fence lines at a 0-indexed line.
--- The lines come from render_buffer.raw_request_fence_lines.
function M.insert_raw_request_fence(buf, at_line_0_indexed, fence_lines)
    vim.api.nvim_buf_set_lines(buf, at_line_0_indexed, at_line_0_indexed, false, fence_lines)
end

--- Append a section to an answer. The section is rendered via
--- render_buffer.render_section. If the line at `after_line_0_indexed`
--- is non-empty, a blank separator is inserted first so blocks don't
--- concatenate. Returns a PosHandle anchored at the line right after
--- the last appended line — the next streaming or section append goes
--- there.
--- @param buf integer
--- @param after_line_0_indexed integer
--- @param section table
--- @return PosHandle
function M.append_section_to_answer(buf, after_line_0_indexed, section)
    local prev_line = vim.api.nvim_buf_get_lines(buf, after_line_0_indexed, after_line_0_indexed + 1, false)[1] or ""
    local rendered = render_buffer.render_section(section)
    local insert_lines = {}
    if prev_line:match("%S") then
        table.insert(insert_lines, "")
    end
    for _, l in ipairs(rendered) do
        table.insert(insert_lines, l)
    end
    local insert_at = after_line_0_indexed + 1
    vim.api.nvim_buf_set_lines(buf, insert_at, insert_at, false, insert_lines)
    return M.make_handle(buf, insert_at + #insert_lines - 1)
end

-- ============================================================================
-- Streaming
-- ============================================================================
--
-- The streaming protocol receives chunks of text that may not align on
-- newline boundaries. We accumulate any trailing partial line in
-- handle._stream.pending and write complete lines to the buffer as they
-- arrive. The pending partial line is also written to the buffer as a
-- "ghost" trailing line so the user sees streaming progress in real
-- time; subsequent chunks overwrite that line.
--
-- finished_lines counts complete (newline-terminated) lines we've
-- already written, so we know how far the handle has advanced from its
-- original anchor.
-- ============================================================================

local function ensure_stream_state(handle)
    handle._stream = handle._stream or { pending = "", finished_lines = 0 }
    return handle._stream
end

--- Write a chunk of text at the position indicated by `handle`.
function M.stream_into(handle, chunk)
    if handle.dead then
        return
    end
    local s = ensure_stream_state(handle)
    s.pending = s.pending .. chunk
    -- Split on \n, plain mode. The last entry is the new pending text.
    local parts = vim.split(s.pending, "\n", { plain = true })
    s.pending = parts[#parts]
    table.remove(parts)
    local first_line = M.handle_line(handle)
    local write_at = first_line + s.finished_lines
    table.insert(parts, s.pending)
    vim.api.nvim_buf_set_lines(handle.buf, write_at, write_at + 1, false, parts)
    s.finished_lines = s.finished_lines + (#parts - 1)
end

--- Finalize the stream — currently just invalidates the handle. The
--- pending partial line is already in the buffer as a ghost.
function M.stream_finalize(handle)
    M.handle_invalidate(handle)
end

-- ============================================================================
-- Progress indicator
-- ============================================================================

--- Replace the line at the handle's position with `text`.
function M.set_progress_line(handle, text)
    if handle.dead then
        return
    end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + 1, false, { text or "" })
end

--- Delete `count` lines starting at the handle's position.
function M.clear_progress_lines(handle, count)
    if handle.dead then
        return
    end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + count, false, {})
end

-- ============================================================================
-- Cancellation cleanup
-- ============================================================================

--- Delete `n` lines starting at the given 0-indexed line.
function M.delete_lines_after(buf, line_0_indexed, n)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + n, false, {})
end

--- Delete from `line_0_indexed` to the end of the buffer.
function M.delete_to_end(buf, line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, -1, false, {})
end

--- Insert raw lines at the given 0-indexed line. Used for the
--- end-of-stream "next user prompt" insert which is structurally
--- distinct from append_section_to_answer (no rendering, no separator
--- handling — caller passes the exact lines).
function M.insert_lines_at(buf, line_0_indexed, lines)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed, false, lines)
end

--- Replace the line at line_0_indexed with the given text. Distinct
--- from set_topic_header_line in name only — semantically identical,
--- but kept separate so the call sites read clearly at the migration
--- boundary. Used for the progress spinner line update path.
function M.replace_line_at(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text or "" })
end

--- Append a blank line at the very end of the buffer.
function M.append_blank_at_end(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
end

return M
