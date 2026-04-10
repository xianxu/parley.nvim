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

return M
