-- Single mutation entry point for the chat buffer.
--
-- All nvim_buf_set_lines / nvim_buf_set_text calls in the chat buffer
-- rendering pipeline live here. The architectural fitness function in
-- tests/arch/buffer_mutation_spec.lua enforces this invariant.
--
-- See workshop/plans/000090-renderer-refactor.md section 3.

local M = {}

-- Explicit user/maintenance edits to editable artifacts. Capture before any
-- asynchronous work; the document proof, not an extmark, owns the target.
function M.capture_user(buf, operation, regions)
    if buf == 0 then buf = vim.api.nvim_get_current_buf() end
    local document = require("parley.document")
    local doc = document.get(buf) or document.attach(buf)
    local token, reason = document.capture_user(doc, { operation = operation, regions = regions })
    if not token then return nil, reason end
    return { document = doc, token = token }
end

function M.resolve_user(capture)
    return require("parley.document").resolve_user(capture.document, capture.token)
end

function M.cancel_user(capture)
    if capture then return require("parley.document").cancel_user(capture.document, capture.token) end
end

function M.apply_user(capture, patches)
    local result = require("parley.document").apply_user(capture.document, capture.token, { patches = patches })
    M.cancel_user(capture)
    return result
end

-- Extend an existing provenance token with freshly computed local line hunks.
-- The original proof remains mandatory (e.g. a selected phrase before lookup).
function M.apply_user_line_hunks(capture, before, after)
    local regions, patches = {}, {}
    local hunks = vim.diff(table.concat(before, "\n") .. "\n", table.concat(after, "\n") .. "\n",
        { result_type = "indices" })
    local resolved, reason = M.resolve_user(capture)
    if not resolved then M.cancel_user(capture); return { status = "stale", reason = reason } end
    for _, hunk in ipairs(hunks) do
        local first = hunk[2] == 0 and hunk[1] or hunk[1] - 1
        local last = first + hunk[2]
        local text_lines = {}
        for row = hunk[3], hunk[3] + hunk[4] - 1 do text_lines[#text_lines + 1] = after[row] end
        local text = table.concat(text_lines, "\n")
        local a, b = { row = first, col = 0 }, { row = last, col = 0 }
        if first == #before then
            a = { row = #before - 1, col = #before[#before] }; b = a
            text = "\n" .. text
        elseif last == #before then
            b = { row = #before - 1, col = #before[#before] }
            if #text_lines==0 and first>0 then a={row=first-1,col=#before[first]} end
        elseif #text_lines > 0 then text = text .. "\n" end
        regions[#regions + 1] = { first = a, last = b }
        patches[#patches + 1] = { region = #resolved.regions + #regions, text = text }
    end
    local document = require("parley.document")
    local token, why = document.extend_user(capture.document, capture.token, { regions = regions })
    M.cancel_user(capture)
    if not token then return { status = "stale", reason = why } end
    return M.apply_user({document=capture.document,token=token}, patches)
end

-- Synchronous artifact commands capture the exact live range immediately.
function M.replace_user_lines(buf, first, last, _, lines)
    local count = vim.api.nvim_buf_line_count(buf)
    if last < 0 then last = count end
    local text = table.concat(lines, "\n")
    local a, b
    if first == count then
        local tail = vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] or ""
        a = { row = count - 1, col = #tail }
        b = a
        if #lines > 0 then text = "\n" .. text end
    elseif last == count then
        local tail = vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] or ""
        a = { row = first, col = 0 }
        b = { row = count - 1, col = #tail }
        if #lines == 0 and first > 0 then
            local previous = vim.api.nvim_buf_get_lines(buf, first - 1, first, false)[1] or ""
            a = { row = first - 1, col = #previous }
        end
    else
        a, b = { row = first, col = 0 }, { row = last, col = 0 }
        if #lines > 0 then text = text .. "\n" end
    end
    local capture, reason = M.capture_user(buf, "replace-lines", { { first = a, last = b } })
    if not capture then error("User edit unavailable: " .. tostring(reason)) end
    local result = M.apply_user(capture, { { region = 1, text = text } })
    if result.status ~= "applied" then error("User edit refused: " .. tostring(result.reason or result.error or result.status)) end
    return result
end

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
--- Delete an answer for regeneration, KEEPING the user's single-line
--- annotations (`🌿:` branch references, `🔒:` private notes).
---
--- A resubmit replaces the MODEL's output. An annotation is not the model's —
--- a branch reference is the only pointer to a child chat that exists on disk,
--- and a private note is the user's own writing. #214 made those lines part of
--- the answer's span (they used to truncate it), so a plain range delete started
--- destroying them: `<M-CR>` on an exchange erased the reference `<M-i>` had
--- just inserted into it, which is precisely where the chord puts one by design
--- (BR-75). Verified against the pre-#214 tree, where the truncation hid this.
---
--- Survivors are re-inserted in order at the deletion point, so the reference
--- stays attached to the exchange it annotates rather than drifting to the end.
--- @param buf integer
--- @param line_start_0_indexed integer
--- @param line_end_0_indexed integer
--- @param cfg table  parley config — REQUIRED, so the prefixes come from the
---                   caller rather than from module state this function happens
---                   to be able to reach (#214 BR-80)
function M.delete_answer(buf, line_start_0_indexed, line_end_0_indexed, cfg)
    local doomed = vim.api.nvim_buf_get_lines(
        buf, line_start_0_indexed, line_end_0_indexed + 1, false)
    local keep = require("parley.annotation").survivors(doomed, cfg)
    if #keep > 0 then
        -- one blank line above the kept block, so it does not abut the question
        table.insert(keep, 1, "")
    end
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, keep)
end

--- Replace an answer region with a single blank separator. Returns a
--- handle anchored at the blank — the next answer's create_answer_region
--- should be called using this handle's resolved line.
function M.replace_answer(buf, line_start_0_indexed, line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_start_0_indexed, line_end_0_indexed + 1, false, { "" })
    return M.make_handle(buf, line_start_0_indexed)
end

--- Replace the entire chat buffer with the given lines for callers whose
--- operation intentionally owns the complete document.
function M.replace_all_lines(buf, lines)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

--- Replace the entire chat buffer after a pure definition-footnote transform.
function M.replace_all_lines_for_definition(buf, lines)
    M.replace_all_lines(buf, lines)
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

--- Apply normalized half-open byte edits against an original joined-text slice.
--- Coordinates are 1-based byte boundaries; start == end is insertion.
--- The complete plan is validated and mapped before the first buffer mutation.
function M.apply_text_edits(buf, start_row0, source_text, edits)
    source_text = source_text or ""
    edits = edits or {}
    local limit = #source_text + 1

    local function boundary(byte)
        local row, col = start_row0, 0
        local cursor = 1
        while cursor < byte do
            local nl = source_text:find("\n", cursor, true)
            if not nl or nl >= byte then
                col = col + byte - cursor
                return row, col
            end
            row = row + 1
            col = 0
            cursor = nl + 1
        end
        return row, col
    end

    local mapped = {}
    local previous
    local line_delta = 0
    for index, edit in ipairs(edits) do
        assert(type(edit) == "table" and type(edit.start_byte) == "number"
            and type(edit.end_byte) == "number" and type(edit.replacement) == "string",
            "buffer_edit: invalid text edit")
        assert(edit.start_byte % 1 == 0 and edit.end_byte % 1 == 0
            and edit.start_byte >= 1 and edit.start_byte <= edit.end_byte
            and edit.end_byte <= limit, "buffer_edit: text edit out of range")
        if previous then
            assert(previous.end_byte <= edit.start_byte, "buffer_edit: overlapping text edits")
            assert(not (previous.start_byte == previous.end_byte
                and edit.start_byte == edit.end_byte
                and previous.start_byte == edit.start_byte),
                "buffer_edit: duplicate insertion boundary")
        end
        local start_row, start_col = boundary(edit.start_byte)
        local end_row, end_col = boundary(edit.end_byte)
        mapped[index] = {
            start_row = start_row, start_col = start_col,
            end_row = end_row, end_col = end_col,
            replacement = vim.split(edit.replacement, "\n", { plain = true }),
        }
        local removed = source_text:sub(edit.start_byte, edit.end_byte - 1)
        local _, removed_breaks = removed:gsub("\n", "")
        local _, added_breaks = edit.replacement:gsub("\n", "")
        line_delta = line_delta + added_breaks - removed_breaks
        previous = edit
    end

    for index = #mapped, 1, -1 do
        local edit = mapped[index]
        vim.api.nvim_buf_set_text(buf, edit.start_row, edit.start_col,
            edit.end_row, edit.end_col, edit.replacement)
    end
    return line_delta
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

--- Replace one line at line_0_indexed with multiple lines. Used by
--- dispatcher.create_handler's streaming chunk replacement path —
--- the existing single line at write_at gets replaced with the
--- newly-completed lines plus the trailing pending "ghost" line.
function M.stream_replace_at_line(buf, line_0_indexed, lines)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, lines)
end

--- Append a blank line at the very end of the buffer.
function M.append_blank_at_end(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
end

return M
