-- diag_display.lua — inline display of Parley diagnostics (#133 M6, #173).
--
-- Controls how parley's review explanations render, scoped to parley's OWN
-- diagnostic namespace (never touches the user's LSP / global diagnostics).
-- Default ON: a custom diagnostic handler renders text-column virtual lines for
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
local DISPLAY_COL = 2

local display_ns_id
local display_augroup
local float_win
local float_buf
local float_owner_buf
local tracked_buffers = {}
local lifecycle_registered = false

-- Parley's review diagnostic namespace — single-sourced from skill_render (which
-- owns the namespace) so the identity isn't a duplicated literal (#133 M6 review).
local function ns()
    return require("parley.skill_render").diag_namespace()
end

local function close_float()
    if float_win and vim.api.nvim_win_is_valid(float_win) then
        pcall(vim.api.nvim_win_close, float_win, true)
    end
    if float_buf and vim.api.nvim_buf_is_valid(float_buf) then
        pcall(vim.api.nvim_buf_delete, float_buf, { force = true })
    end
    float_win = nil
    float_buf = nil
    float_owner_buf = nil
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
    if float_owner_buf == buf then
        close_float()
    end
    if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)
    end
end

local function windows_for_buffer(buf)
    local wins = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            wins[#wins + 1] = win
        end
    end
    return wins
end

local function position_for_buffer(buf)
    local current = vim.api.nvim_get_current_win()
    local win = vim.api.nvim_win_get_buf(current) == buf and current or windows_for_buffer(buf)[1]
    if not win then
        return nil
    end
    local pos = vim.api.nvim_win_get_cursor(win)
    return pos[1] - 1, pos[2], win
end

local function virtual_line_width(buf)
    local width
    for _, win in ipairs(windows_for_buffer(buf)) do
        local info = vim.fn.getwininfo(win)[1] or {}
        local usable = math.max(2, (info.width or vim.api.nvim_win_get_width(win)) - (info.textoff or 0) - DISPLAY_COL)
        width = width and math.min(width, usable) or usable
    end
    return width or 76
end

--- Shape one diagnostic for the custom virtual-line display.
--- @param diagnostic table
--- @param width integer
--- @return table[]
function M.diagnostic_message_lines(diagnostic, width)
    local lines = {}
    local rows = require("parley.diagnostic_text").wrap_rows(
        diagnostic.message or "",
        width,
        vim.fn.strdisplaywidth
    )
    for _, line in ipairs(rows) do
        table.insert(lines, { { line ~= "" and line or " ", MESSAGE_HL } })
    end
    if #lines == 0 then
        table.insert(lines, { { " ", MESSAGE_HL } })
    end
    return lines
end

local function diagnostic_float_lines(diagnostics, width)
    local lines = { "Diagnostics:" }
    for _, diagnostic in ipairs(diagnostics or {}) do
        local rows = require("parley.diagnostic_text").wrap_rows(
            diagnostic.message or "",
            width,
            vim.fn.strdisplaywidth
        )
        for _, line in ipairs(rows) do
            table.insert(lines, line ~= "" and line or " ")
        end
    end
    return lines
end

local function diagnostic_contains_line(diagnostic, line)
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    return line >= start_line and line <= end_line
end

local function diagnostic_contains_position(diagnostic, line, col)
    if not diagnostic_contains_line(diagnostic, line) then
        return false
    end
    local start_line = diagnostic.lnum or 0
    local end_line = diagnostic.end_lnum or start_line
    if line == start_line and col < (diagnostic.col or 0) then
        return false
    end
    if line == end_line and col >= (diagnostic.end_col or diagnostic.col or 0) then
        return false
    end
    return true
end

local function diagnostic_visible_at(diagnostic, line, col)
    if diagnostic.source == "parley-footnote" then
        return diagnostic_contains_position(diagnostic, line, col)
    end
    return diagnostic_contains_line(diagnostic, line)
end

local function float_content_width(win)
    local win_width = vim.api.nvim_win_get_width(win)
    return math.max(2, math.min(math.floor(win_width * 0.8), win_width - 2))
end

local function float_config(win, width, line_count)
    local win_width = vim.api.nvim_win_get_width(win)
    local win_height = vim.api.nvim_win_get_height(win)
    local height = math.max(1, math.min(line_count, math.max(1, win_height - 2)))
    return {
        relative = "win",
        win = win,
        width = width,
        height = height,
        row = math.min(math.max(0, vim.fn.winline() - 1), math.max(0, win_height - height - 2)),
        col = math.max(0, math.floor((win_width - width - 2) / 2)),
        style = "minimal",
        border = "rounded",
        focusable = false,
        title = { { "Diagnostics", HEADER_HL } },
        title_pos = "left",
    }
end

local function show_float(buf, diagnostics, win)
    close_float()
    if #diagnostics == 0 then
        return
    end
    local width = float_content_width(win)
    local lines = diagnostic_float_lines(diagnostics, width)
    float_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(float_buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(float_buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
    require("parley.buffer_edit").replace_all_lines(float_buf, lines)
    vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
    float_win = vim.api.nvim_open_win(float_buf, false, float_config(win, width, #lines))
    float_owner_buf = buf
    vim.api.nvim_win_set_option(float_win, "wrap", false)
    vim.api.nvim_win_set_option(float_win, "winhl", "NormalFloat:NormalFloat,FloatBorder:FloatBorder")
end

local function render(buf, diagnostics, current_line_only)
    ensure_display()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, display_ns_id, 0, -1)

    local line, col, position_win
    if current_line_only then
        line, col, position_win = position_for_buffer(buf)
    end
    local is_current = vim.api.nvim_get_current_buf() == buf
    if is_current or float_owner_buf == buf then
        close_float()
    end
    if current_line_only and line == nil then
        return
    end

    local by_line = {}
    local footnote_diagnostics = {}
    for _, diagnostic in ipairs(diagnostics or {}) do
        if not current_line_only or diagnostic_visible_at(diagnostic, line, col) then
            if diagnostic.source == "parley-footnote" then
                table.insert(footnote_diagnostics, diagnostic)
            else
                by_line[diagnostic.lnum] = by_line[diagnostic.lnum] or {}
                table.insert(by_line[diagnostic.lnum], diagnostic)
            end
        end
    end
    table.sort(footnote_diagnostics, function(a, b)
        return (a.col or 0) < (b.col or 0)
    end)
    if is_current then
        show_float(buf, footnote_diagnostics, position_win or vim.api.nvim_get_current_win())
    end

    local width = virtual_line_width(buf)
    for lnum, line_diagnostics in pairs(by_line) do
        table.sort(line_diagnostics, function(a, b)
            return (a.col or 0) < (b.col or 0)
        end)
        local virt_lines = { { { "Diagnostics:", HEADER_HL } } }
        for _, diagnostic in ipairs(line_diagnostics) do
            vim.list_extend(virt_lines, M.diagnostic_message_lines(diagnostic, width))
        end
        vim.api.nvim_buf_set_extmark(buf, display_ns_id, lnum, DISPLAY_COL, {
            virt_lines = virt_lines,
            virt_lines_above = false,
        })
    end
end

local function refresh_tracked(buf)
    if M.enabled and tracked_buffers[buf] and vim.api.nvim_buf_is_valid(buf) then
        render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
    end
end

local function ensure_lifecycle()
    ensure_display()
    if lifecycle_registered then
        return
    end
    lifecycle_registered = true
    vim.api.nvim_create_autocmd({ "CursorMoved", "WinEnter", "WinResized", "BufWipeout" }, {
        group = display_augroup,
        callback = function(args)
            if args.event == "BufWipeout" then
                tracked_buffers[args.buf] = nil
                if float_owner_buf == args.buf then
                    close_float()
                end
                return
            end

            if args.event == "WinEnter" and float_owner_buf
                and float_owner_buf ~= vim.api.nvim_get_current_buf()
            then
                close_float()
            end

            if args.event == "WinResized" then
                local affected = {}
                for _, win in ipairs((vim.v.event or {}).windows or {}) do
                    if vim.api.nvim_win_is_valid(win) then
                        affected[vim.api.nvim_win_get_buf(win)] = true
                    end
                end
                if next(affected) == nil then
                    affected = tracked_buffers
                end
                for buf in pairs(affected) do
                    refresh_tracked(buf)
                end
                return
            end

            refresh_tracked(vim.api.nvim_get_current_buf())
        end,
    })
end

local function stop_lifecycle()
    if display_augroup then
        pcall(vim.api.nvim_clear_autocmds, { group = display_augroup })
    end
    lifecycle_registered = false
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
                tracked_buffers[bufnr] = true
            end
            render(bufnr, diagnostics, current_line_only)
        end,
        hide = function(namespace, bufnr)
            if namespace ~= ns() then
                return
            end
            bufnr = vim._resolve_bufnr(bufnr)
            tracked_buffers[bufnr] = nil
            clear(bufnr)
        end,
    }
end

function M.refresh(buf)
    if not M.enabled then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    tracked_buffers[buf] = true
    render(buf, vim.diagnostic.get(buf, { namespace = ns() }), true)
end

--- Apply the inline-display config for parley's review namespace.
--- @param on boolean
function M.set(on)
    M.enabled = on and true or false
    register_handler()
    if M.enabled then
        ensure_lifecycle()
    end
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
        tracked_buffers = {}
        stop_lifecycle()
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
