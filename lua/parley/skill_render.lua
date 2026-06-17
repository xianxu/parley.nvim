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

--- Attach INFO diagnostics from edit explanations.
--- @param buf number
--- @param edits table[]  applied edits with {pos, explain}
--- @param original_content string  file content before edits
function M.attach_diagnostics(buf, edits, original_content)
    ensure_namespaces()
    local diagnostics = {}
    for _, edit in ipairs(edits) do
        local line_num = 0
        for _ in original_content:sub(1, edit.pos):gmatch("\n") do
            line_num = line_num + 1
        end
        table.insert(diagnostics, {
            lnum = line_num,
            col = 0,
            message = edit.explain or "edit applied",
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
        local new_pos = new_content:find(edit.new_string, 1, true)
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

return M
