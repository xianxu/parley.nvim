-- parley.skill_render — buffer decorations for applied skill edits.
--
-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
-- now the single source used by the skill_invoke driver (skill_runner was
-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
-- edit's `explain`, and a tint on each edited span only (#386, #387) —
-- ParleyEditAdd for added text, ParleyEditChange for changed text, never a
-- whole line, so unchanged text keeps its own color. A deletion leaves no trace.

local M = {}

local DIAG_NS = "parley_skill"
local HL_NS = "parley_skill_hl"
local FOOTNOTE_HL_NS = "parley_footnote_hl"
local FOOTNOTE_SOURCE = "parley-footnote"
local ROUND_HL_NS = "parley_round_hl"
local ROUND_SOURCE = "parley-round"
-- Each edited span's group by kind (defined in highlighter.setup_highlights):
-- "add" when the edit replaced nothing, "change" otherwise (#387).
local EDIT_HL = { add = "ParleyEditAdd", change = "ParleyEditChange" }

local diag_ns_id
local hl_ns_id
local footnote_hl_ns_id
local round_hl_ns_id
-- buf -> { [extmark id] = decoration }: what each round mark says, so its
-- diagnostic can follow the mark as the text moves (#383).
local round_marks = {}

local function ensure_namespaces()
    if not diag_ns_id then
        diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
    end
    if not hl_ns_id then
        hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
    end
    if not footnote_hl_ns_id then
        footnote_hl_ns_id = vim.api.nvim_create_namespace(FOOTNOTE_HL_NS)
    end
    if not round_hl_ns_id then
        round_hl_ns_id = vim.api.nvim_create_namespace(ROUND_HL_NS)
    end
end

local function is_footnote_diagnostic(diagnostic)
    local user_data = diagnostic.user_data or {}
    return diagnostic.source == FOOTNOTE_SOURCE or user_data.parley_kind == "footnote"
end

local function is_round_diagnostic(diagnostic)
    return diagnostic.source == ROUND_SOURCE or (diagnostic.user_data or {}).parley_kind == "round"
end

local function not_round(diagnostic)
    return not is_round_diagnostic(diagnostic)
end

-- The one rule for the shared diagnostic namespace: a writer replaces only the
-- diagnostics it owns (`owns`) and keeps every other kind. The agent's round
-- (#383) is owned by the round functions alone; every other writer owns
-- `not_round`, so a review-skill run, an undo/redo snapshot or a dismiss never
-- wipes it.
local function replace_kind(buf, owns, diagnostics)
    local out = {}
    for _, existing in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
        if not owns(existing) then
            table.insert(out, existing)
        end
    end
    for _, diagnostic in ipairs(diagnostics) do
        table.insert(out, diagnostic)
    end
    vim.diagnostic.set(diag_ns_id, buf, out)
    return out
end

--- Clear previous skill diagnostics and highlights from a buffer. The agent's
--- round is not the skill's: it stays until a confirmed submit (#383).
function M.clear_decorations(buf)
    ensure_namespaces()
    replace_kind(buf, not_round, {})
    vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, footnote_hl_ns_id, 0, -1)
end

--- Dismiss the review skill's live decorations (manual <dismiss> binding).
--- Decorations otherwise RIDE subsequent edits (behavior B, #133) and are
--- cleared only at the next round start; this lets the operator clear them on
--- demand. The agent's round (#383) is not the skill's and stays: it clears
--- on the next confirmed submit.
M.dismiss = M.clear_decorations

--- The review diagnostic namespace id — the single source other modules
--- (diag_display) target, so the namespace identity isn't duplicated as a literal
--- string in two places (#133 M6 review).
function M.diag_namespace()
    ensure_namespaces()
    return diag_ns_id
end

local function highlight_footnote_span(buf, lnum0, col_start, end_lnum0, col_end)
    ensure_namespaces()
    vim.api.nvim_buf_set_extmark(buf, footnote_hl_ns_id, lnum0, col_start, {
        end_row = end_lnum0,
        end_col = col_end,
        hl_group = EDIT_HL.add, -- a define adds its [^id] reference, replacing nothing
        strict = false,
    })
end

--- Rehydrate persisted managed markdown footnotes into Parley diagnostics.
--- Existing non-footnote diagnostics in the shared namespace are preserved.
--- @param buf number|nil
--- @param opts table|nil optional { reader = LineReader }
function M.refresh_footnote_diagnostics(buf,opts)
    return require('parley.diagnostic_refresh').refresh(buf or vim.api.nvim_get_current_buf(),opts)
end

function M.publish_footnotes(buf,footnotes)
    ensure_namespaces()
    local define=require('parley.define')
    local diagnostics = {}
    vim.api.nvim_buf_clear_namespace(buf, footnote_hl_ns_id, 0, -1)

    for _, footnote in ipairs(footnotes) do
        highlight_footnote_span(buf, footnote.lnum, footnote.col, footnote.end_lnum or footnote.lnum, footnote.end_col)
        table.insert(diagnostics, {
            lnum = footnote.lnum,
            col = footnote.col,
            end_lnum = footnote.end_lnum or footnote.lnum,
            end_col = footnote.end_col,
            message = define.format_definition(footnote.term or footnote.id, footnote.definition),
            severity = vim.diagnostic.severity.INFO,
            source = FOOTNOTE_SOURCE,
            user_data = { parley_kind = "footnote" },
        })
    end

    diagnostics = replace_kind(buf, is_footnote_diagnostic, diagnostics)
    local bytes=0;for _,record in ipairs(diagnostics) do bytes=bytes+#record.message end
    return {entries=#diagnostics,message_bytes=bytes}
end

--- Clear only managed-footnote diagnostics/highlights. Other diagnostics in
--- the shared skill namespace belong to live edit explanations and survive.
function M.clear_footnote_diagnostics(buf)
    ensure_namespaces()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, footnote_hl_ns_id, 0, -1)
    replace_kind(buf, is_footnote_diagnostic, {})
end

-- Set the round's diagnostics, from each mark's current place, beside the
-- shared namespace's other kinds.
local function set_round_diagnostics(buf)
    local diagnostics = {}
    local said = round_marks[buf] or {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, round_hl_ns_id, 0, -1, { details = true })) do
        local decoration = said[mark[1]]
        if decoration then
            table.insert(diagnostics, {
                lnum = mark[2],
                col = mark[3],
                end_lnum = mark[4].end_row or mark[2],
                end_col = mark[4].end_col or mark[3],
                message = decoration.message,
                severity = vim.diagnostic.severity.INFO,
                source = ROUND_SOURCE,
                user_data = { parley_kind = "round" },
            })
        end
    end
    replace_kind(buf, is_round_diagnostic, diagnostics)
end

--- Draw the agent's last round (#383): presentation.decorations as
--- highlights by kind (#387), each with an INFO diagnostic. Replaces any round
--- drawn before; other kinds are kept.
--- @param buf number
--- @param decorations table[] {lnum, col, end_lnum, end_col, message, kind}, 0-based
function M.publish_round(buf, decorations)
    ensure_namespaces()
    vim.api.nvim_buf_clear_namespace(buf, round_hl_ns_id, 0, -1)
    local said = {}
    for _, d in ipairs(decorations) do
        local id = vim.api.nvim_buf_set_extmark(buf, round_hl_ns_id, d.lnum, d.col, {
            end_row = d.end_lnum,
            end_col = d.end_col,
            hl_group = EDIT_HL[d.kind] or EDIT_HL.change,
            strict = false,
        })
        said[id] = d
    end
    round_marks[buf] = said
    set_round_diagnostics(buf)
end

--- Re-derive the round's diagnostics from where its marks are now: marks move
--- with the text, diagnostics do not.
function M.rederive_round(buf)
    ensure_namespaces()
    if round_marks[buf] and vim.api.nvim_buf_is_valid(buf) then
        set_round_diagnostics(buf)
    end
end

--- Clear only the round kind: its marks and diagnostics.
function M.clear_round(buf)
    ensure_namespaces()
    round_marks[buf] = nil
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, round_hl_ns_id, 0, -1)
    set_round_diagnostics(buf)
end

--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
--- message remains semantic; each consumer wraps it to its actual display width.
--- A pure deletion (kind "delete") leaves no trace, so it gets none (#387).
--- @param buf number
--- @param edits table[]  applied edits with {pos, explain, new_string?, kind}
--- @param original_content string  file content before edits
function M.attach_diagnostics(buf, edits, original_content)
    ensure_namespaces()
    local diagnostics = {}
    for _, edit in ipairs(vim.tbl_filter(function(e) return e.kind ~= "delete" end, edits)) do
        local line_num = 0
        for _ in original_content:sub(1, edit.pos):gmatch("\n") do
            line_num = line_num + 1
        end
        -- end_lnum spans the edit's own lines (newlines in the new text).
        local span = 0
        for _ in (edit.new_string or ""):gmatch("\n") do
            span = span + 1
        end
        table.insert(diagnostics, {
            lnum = line_num,
            end_lnum = line_num + span,
            col = 0,
            message = tostring(edit.explain or "edit applied"),
            severity = vim.diagnostic.severity.INFO,
            source = "parley-skill",
        })
    end
    replace_kind(buf, not_round, diagnostics)
end

-- 0-based (row, byte col) of the 1-based byte offset `pos` in `content`.
local function position_of(content, pos)
    local row, line_start = 0, 1
    for nl in content:sub(1, pos - 1):gmatch("()\n") do
        row, line_start = row + 1, nl + 1
    end
    return row, pos - line_start
end

--- Highlight each edit's new text, as one span of its kind.
--- @param buf number
--- @param edits table[]  applied edits with {new_string, kind = "add"|"change"|"delete"}
--- @param new_content string  file content after edits
function M.highlight_edits(buf, edits, new_content)
    ensure_namespaces()
    for _, edit in ipairs(edits) do
        -- A pure deletion has no new text and leaves no trace (#387).
        local new_pos = edit.kind ~= "delete" and new_content:find(edit.new_string, 1, true) or nil
        if new_pos then
            local row, col = position_of(new_content, new_pos)
            local end_row, end_col = position_of(new_content, new_pos + #edit.new_string)
            M.highlight_span(buf, row, col, end_row, end_col, edit.kind)
        end
    end
end

--- Highlight a span on the hl namespace with its kind's group (#387).
--- @param buf number
--- @param lnum0 number 0-based start line
--- @param col_start number 0-based start column
--- @param end_lnum0 number 0-based end line
--- @param col_end number 0-based exclusive end column
--- @param kind "add"|"change"|nil  default "change"
function M.highlight_span(buf, lnum0, col_start, end_lnum0, col_end, kind)
    ensure_namespaces()
    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
        end_row = end_lnum0,
        end_col = col_end,
        hl_group = EDIT_HL[kind] or EDIT_HL.change,
        strict = false,
    })
end

-- The kind an extmark's group stands for, so a snapshot can redraw it.
local function kind_of(hl_group)
    for kind, group in pairs(EDIT_HL) do
        if group == hl_group then return kind end
    end
    return "change"
end

--- Capture the current decoration set as redrawable data (for the undo/redo
--- projection record, #133 M5). Span highlights and diagnostics preserve
--- columns so exact anchors can be restored.
function M.snapshot(buf)
    ensure_namespaces()
    local hl_spans = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
        local details = m[4] or {} -- m = {id, row, col, details}
        table.insert(hl_spans, {
            lnum = m[2],
            col = m[3],
            end_lnum = details.end_row or m[2],
            end_col = details.end_col or m[3],
            kind = kind_of(details.hl_group),
        })
    end
    local diags = {}
    -- The agent's round is not part of a skill snapshot: it has its own owner.
    for _, d in ipairs(vim.tbl_filter(not_round, vim.diagnostic.get(buf, { namespace = diag_ns_id }))) do
        table.insert(diags, {
            lnum = d.lnum,
            col = d.col or 0,
            end_lnum = d.end_lnum,
            end_col = d.end_col,
            message = d.message,
            source = d.source,
            user_data = d.user_data,
        })
    end
    return { hl_spans = hl_spans, diags = diags }
end

--- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
--- content matches the state the snapshot was captured at (the projection caller
--- guarantees this via a content-hash match). #133 M5.
function M.apply_snapshot(buf, snap)
    ensure_namespaces()
    M.clear_decorations(buf)
    snap = snap or {}
    for _, span in ipairs(snap.hl_spans or {}) do
        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col, span.kind)
    end
    if snap.diags and #snap.diags > 0 then
        local diagnostics = {}
        for _, d in ipairs(snap.diags) do
            table.insert(diagnostics, {
                lnum = d.lnum,
                end_lnum = d.end_lnum or d.lnum,
                col = d.col or 0,
                end_col = d.end_col,
                message = d.message,
                severity = vim.diagnostic.severity.INFO,
                source = d.source or "parley-skill",
                user_data = d.user_data,
            })
        end
        replace_kind(buf, not_round, diagnostics)
    end
end

return M
