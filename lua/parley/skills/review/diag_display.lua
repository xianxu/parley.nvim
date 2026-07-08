-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
--
-- Controls how parley's review explanations render, scoped to parley's OWN
-- diagnostic namespace (never touches the user's LSP / global diagnostics).
-- Default ON: a custom diagnostic handler renders left-column virtual lines for
-- the cursor's current diagnostic region, so long wrapped prose doesn't hide
-- messages behind stock virtual-lines column indentation. `:ParleyShowDiagnostics`
-- toggles it.

local M = {}

M.enabled = true -- default on (cursor-region auto-show)

local HANDLER_NAME = "parley/virtual_lines"
local DISPLAY_NS = "parley_diagnostic_virtual_lines"
local DISPLAY_AUGROUP = "parley_diagnostic_virtual_lines"
local HEADER_HL = "ParleyDiagnosticVirtualLineHeader"
local MESSAGE_HL = "ParleyDiagnosticVirtualLine"

local display_ns_id
local display_augroup

-- Parley's review diagnostic namespace — single-sourced from skill_render (which
-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
local function ns()
    return require("parley.skill_render").diag_namespace()
end

local function ensure_display()
    if not display_ns_id then
        display_ns_id = vim.api.nvim_create_namespace(DISPLAY_NS)
    end
    if not display_augroup then
        display_augroup = vim.api.nvim_create_augroup(DISPLAY_AUGROUP, { clear = true })
    end
    vim.api.nvim_set_hl(0, HEADER_HL, { link = "DiagnosticInfo" })
    vim.api.nvim_set_hl(0, MESSAGE_HL, { link = "DiagnosticFloatingInfo" })
end

local function clear(buf)
    ensure_display()
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup, buffer = buf })
    end
end

local function current_line_for(buf)
    if vim.api.nvim_get_current_buf() ~= buf then
        return nil
    end
    return vim.api.nvim_win_get_cursor(0)[1] - 1
end

local function diagnostic_message_lines(diagnostic)
    local lines = {}
    for _, line in ipairs(vim.split(tostring(diagnostic.message or ""), "\n", { plain = true })) do
        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    end
    if #lines == 0 then
        table.insert(lines, { { " ", MESSAGE_HL } })
    end
    return lines
end

local function diagnostic_contains_line(diagnostic, line)
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    return line >= start_line and line <= end_line
end

local function render(buf, diagnostics, current_line_only)
    ensure_display()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)

    local line = current_line_only and current_line_for(buf) or nil
    if current_line_only and not line then
        return
    end

    local by_line = {}
    for _, diagnostic in ipairs(diagnostics or {}) do
        if not current_line_only or diagnostic_contains_line(diagnostic, line) then
            by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
            table.insert(by_line[diagnostic.lnum], diagnostic)
        end
    end

    for lnum, line_diagnostics in pairs(by_line) do
        table.sort(line_diagnostics, function(a, b)
            return (a.col or 0) < (b.col or 0)
        end)
        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
        for _, diagnostic in ipairs(line_diagnostics) do
            vim.list_extend(virt_lines, diagnostic_message_lines(diagnostic))
        end
        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, 0, {
            virt_lines = virt_lines,
            virt_lines_leftcol = true,
            virt_lines_above = false,
        })
    end
end

local function register_handler()
    ensure_display()
    vim.diagnostic.handlers[HANDLER_NAME] = {
        show = function(namespace, bufnr, diagnostics, opts)
            if namespace ~= ns() then
                return
            end
            bufnr = vim._resolve_bufnr(bufnr)
            local handler_opts = opts and opts[HANDLER_NAME] or {}
            local current_line_only = handler_opts.current_line == true
            clear(bufnr)
            if current_line_only then
                vim.api.nvim_create_autocmd("CursorMoved", {
                    buffer = bufnr,
                    group = display_augroup,
                    callback = function()
                        render(bufnr, diagnostics, true)
                    end,
                })
            end
            render(bufnr, diagnostics, current_line_only)
        end,
        hide = function(namespace, bufnr)
            if namespace ~= ns() then
                return
            end
            clear(vim._resolve_bufnr(bufnr))
        end,
    }
end

function M.refresh(buf)
    if not M.enabled then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
end

--- Apply the inline-display config for parley's review namespace.
--- @param on boolean
function M.set(on)
    M.enabled = on and true or false
    register_handler()
    vim.diagnostic.config({
        [HANDLER_NAME] = M.enabled and { current_line = true } or false,
        virtual_lines = false,
        virtual_text = false,
    }, ns())
    if M.enabled then
        M.refresh()
    else
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            clear(buf)
        end
    end
end

--- Toggle inline display; returns the new state.
--- @return boolean
function M.toggle()
    M.set(not M.enabled)
    return M.enabled
end

--- Is inline display currently enabled?
--- @return boolean
function M.is_enabled()
    return M.enabled
end

return M
