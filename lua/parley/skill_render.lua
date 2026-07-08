-- parley.skill_render — buffer decorations for applied skill edits.
--
-- The diagnostics/highlights rendering salvaged out of skill_runner (#128 M3),
-- now the single source used by the skill_invoke driver (skill_runner was
-- deleted in M4). Thin vim-API/UI wrapper (not pure): INFO diagnostics from each
-- edit's `explain`, DiffChange highlights on edited regions.

local M = {}

local DIAG_NS = "parley_skill"
local HL_NS = "parley_skill_hl"

local diag_ns_id
local hl_ns_id

local function ensure_namespaces()
    if not diag_ns_id then
        diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
    end
    if not hl_ns_id then
        hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
    end
end

--- Clear previous skill diagnostics and highlights from a buffer.
function M.clear_decorations(buf)
    ensure_namespaces()
    vim.diagnostic.reset(diag_ns_id, buf)
    vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
end

--- Dismiss the live round decorations (manual <dismiss> binding). Decorations
--- otherwise RIDE subsequent edits (behavior B, #133) and are cleared only at
--- the next round start; this lets the operator clear them on demand.
M.dismiss = M.clear_decorations

--- The review diagnostic namespace id — the single source other modules
--- (diag_display) target, so the namespace identity isn't duplicated as a literal
--- string in two places (#133 M6 review).
function M.diag_namespace()
    ensure_namespaces()
    return diag_ns_id
end

--- Hard-wrap text to `width` columns at word boundaries (greedy), preserving any
--- existing newlines. PURE. Lets `virtual_lines` render a long "why" as multiple
--- wrapped rows (nvim doesn't soft-wrap virtual text). A word longer than width
--- stays on its own (overflowing) line rather than being split. (#133 M6)
--- @param text string
--- @param width number|nil  default 76
--- @return string
function M.wrap(text, width)
    width = width or 76
    local out = {}
    for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        if para == "" then
            table.insert(out, "")
        else
            local line = ""
            for word in para:gmatch("%S+") do
                if line == "" then
                    line = word
                elseif #line + 1 + #word <= width then
                    line = line .. " " .. word
                else
                    table.insert(out, line)
                    line = word
                end
            end
            table.insert(out, line)
        end
    end
    return table.concat(out, "\n")
end

-- Usable wrap width for the virtual_lines "why": the window's text columns
-- (total width minus the number/sign/fold gutter, via getwininfo.textoff) minus
-- a margin for the indent + connector nvim renders under the line. Wrapping to a
-- fixed 76 overflowed the indented virtual_lines and truncated the right edge
-- (#133 review). Falls back to 76 with no window.
local function diag_wrap_width()
    local ok, info = pcall(function()
        return vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
    end)
    if not ok or type(info) ~= "table" then
        return 76
    end
    return math.max(30, (info.width or 80) - (info.textoff or 0) - 10)
end

--- Attach INFO diagnostics from edit explanations. Each diagnostic spans the
--- edit's line range (lnum..end_lnum) so "cursor in the region" matches, and its
--- message is hard-wrapped to the window's usable width for `virtual_lines`
--- display (no right-edge truncation). (#133 M6)
--- @param buf number
--- @param edits table[]  applied edits with {pos, explain, new_string?}
--- @param original_content string  file content before edits
function M.attach_diagnostics(buf, edits, original_content)
    ensure_namespaces()
    local width = diag_wrap_width()
    local diagnostics = {}
    for _, edit in ipairs(edits) do
        local line_num = 0
        for _ in original_content:sub(1, edit.pos):gmatch("\n") do
            line_num = line_num + 1
        end
        -- end_lnum spans the edit's own lines (newlines in the new text); a pure
        -- deletion (no new_string) stays a single-line anchor.
        local span = 0
        for _ in (edit.new_string or ""):gmatch("\n") do
            span = span + 1
        end
        table.insert(diagnostics, {
            lnum = line_num,
            end_lnum = line_num + span,
            col = 0,
            message = M.wrap(edit.explain or "edit applied", width),
            severity = vim.diagnostic.severity.INFO,
            source = "parley-skill",
        })
    end
    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
end

--- Highlight edited regions with DiffChange.
--- @param buf number
--- @param edits table[]  applied edits with {new_string}
--- @param new_content string  file content after edits
function M.highlight_edits(buf, edits, new_content)
    ensure_namespaces()
    for _, edit in ipairs(edits) do
        -- Skip pure deletions: new_string is "" and `find("")` returns 1, which
        -- would spuriously highlight line 0. Deletions are oriented by their
        -- INFO gutter diagnostic (the "why") via attach_diagnostics, not a
        -- highlight (there's no new text to mark). #133.
        local new_pos = (edit.new_string and edit.new_string ~= "")
            and new_content:find(edit.new_string, 1, true)
            or nil
        if new_pos then
            local start_line = 0
            for _ in new_content:sub(1, new_pos):gmatch("\n") do
                start_line = start_line + 1
            end
            local end_line = start_line
            for _ in edit.new_string:gmatch("\n") do
                end_line = end_line + 1
            end
            for line = start_line, end_line do
                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
            end
        end
    end
end

--- Highlight a whole line with DiffChange on the hl namespace (#161 R1). Same
--- shape `apply_snapshot` restores (whole-line, col 0..-1), so it round-trips
--- through projection's line-granular undo/redo snapshotting.
--- @param buf number
--- @param lnum0 number  0-based line
function M.highlight_line(buf, lnum0)
    ensure_namespaces()
    vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", lnum0, 0, -1)
end

--- Highlight a column span with DiffChange on the hl namespace. The four-arg
--- form is same-line: (buf, lnum0, col_start, col_end). The five-arg form spans
--- rows: (buf, lnum0, col_start, end_lnum0, col_end).
--- @param buf number
--- @param lnum0 number 0-based start line
--- @param col_start number 0-based start column
--- @param end_lnum0_or_col_end number 0-based end line, or end column
--- @param col_end number|nil 0-based exclusive end column
function M.highlight_span(buf, lnum0, col_start, end_lnum0_or_col_end, col_end)
    ensure_namespaces()
    local end_lnum0 = lnum0
    if col_end == nil then
        col_end = end_lnum0_or_col_end
    else
        end_lnum0 = end_lnum0_or_col_end
    end
    vim.api.nvim_buf_set_extmark(buf, hl_ns_id, lnum0, col_start, {
        end_row = end_lnum0,
        end_col = col_end,
        hl_group = "DiffChange",
        strict = false,
    })
end

--- Capture the current decoration set as redrawable data (for the undo/redo
--- projection record, #133 M5). Whole-line highlights stay in `hl_lines`; span
--- highlights and diagnostics preserve columns so exact anchors can be restored.
function M.snapshot(buf)
    ensure_namespaces()
    local hl_lines = {}
    local hl_spans = {}
    for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, hl_ns_id, 0, -1, { details = true })) do
        local details = m[4] or {}
        local is_legacy_line = m[3] == 0 and details.end_row == m[2] + 1 and details.end_col == 0
        if is_legacy_line or details.end_row == nil or details.end_col == nil then
            table.insert(hl_lines, m[2]) -- m = {id, row, col}; row is the 0-based line
        else
            table.insert(hl_spans, {
                lnum = m[2],
                col = m[3],
                end_lnum = details.end_row,
                end_col = details.end_col,
            })
        end
    end
    local diags = {}
    for _, d in ipairs(vim.diagnostic.get(buf, { namespace = diag_ns_id })) do
        table.insert(diags, {
            lnum = d.lnum,
            col = d.col or 0,
            end_lnum = d.end_lnum,
            end_col = d.end_col,
            message = d.message,
        })
    end
    return { hl_lines = hl_lines, hl_spans = hl_spans, diags = diags }
end

--- Redraw a snapshot's decorations (clearing first). Only valid when the buffer
--- content matches the state the snapshot was captured at (the projection caller
--- guarantees this via a content-hash match). #133 M5.
function M.apply_snapshot(buf, snap)
    ensure_namespaces()
    M.clear_decorations(buf)
    snap = snap or {}
    for _, line in ipairs(snap.hl_lines or {}) do
        vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
    end
    for _, span in ipairs(snap.hl_spans or {}) do
        M.highlight_span(buf, span.lnum, span.col or 0, span.end_lnum or span.lnum, span.end_col)
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
                source = "parley-skill",
            })
        end
        vim.diagnostic.set(diag_ns_id, buf, diagnostics)
    end
end

return M
