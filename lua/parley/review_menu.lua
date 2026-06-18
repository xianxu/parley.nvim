-- review_menu.lua — the composite review-mode menu (#133 M4).
--
-- A two-window float: a mode SELECTOR on top + a multi-line instruction EDITOR
-- below (a real, modifiable buffer — full vim editing). Submit sends
-- { mode, instruction } to on_submit. The last-used mode is sticky (session
-- recall) and pre-selected. Reuses float_picker.compute_layout for geometry
-- (ARCH-DRY). This is the only net-new UI in the feature.

local M = {}

-- Session-sticky last selected mode (cross-session persistence is v2).
local _last_mode

local function modes_dir()
    return (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
end

-- Display a kebab mode name with spaces: "line-editing" → "line editing".
local function pretty(name)
    return (name:gsub("%-", " "))
end

--- Open the review menu on `buf`.
--- @param buf number  the artifact buffer the review will run on
--- @param opts table|nil { on_submit = fun({mode,instruction}), mode?, instruction? }
--- @return table|nil handle  { submit, move, selected, close } (nil if no modes)
function M.open(buf, opts)
    opts = opts or {}
    local on_submit = opts.on_submit or function() end
    local mode = require("parley.skills.review.mode")
    local float_picker = require("parley.float_picker")
    local parley = require("parley")

    local dir = modes_dir()
    local modes = dir and mode.list(dir) or {}
    if #modes == 0 then
        parley.logger.warning("Review menu: no modes found")
        return nil
    end

    -- Selection: sticky last mode (or an explicit opts.mode), else the first.
    local sel = 1
    local want = opts.mode or _last_mode
    for i, m in ipairs(modes) do
        if m.name == want then
            sel = i
            break
        end
    end

    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local win_w, win_h, row, col, _, instr_row = float_picker.compute_layout(70, #modes, ui, false)

    -- Mode list window (top).
    local list_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[list_buf].buftype = "nofile"
    vim.bo[list_buf].bufhidden = "wipe"
    local function render_list()
        local lines = {}
        for i, m in ipairs(modes) do
            lines[i] = (i == sel and "▶ " or "  ") .. pretty(m.name)
        end
        vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    end
    render_list()
    local list_win = vim.api.nvim_open_win(list_buf, false, {
        relative = "editor", row = row, col = col, width = win_w, height = win_h,
        style = "minimal", border = "rounded", title = " Review mode (C-j/C-k or Tab) ",
    })

    -- Instruction editor window (bottom) — a normal modifiable buffer.
    local instr_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[instr_buf].buftype = ""
    vim.bo[instr_buf].bufhidden = "wipe"
    if opts.instruction and opts.instruction ~= "" then
        vim.api.nvim_buf_set_lines(instr_buf, 0, -1, false, vim.split(opts.instruction, "\n"))
    end
    local instr_win = vim.api.nvim_open_win(instr_buf, true, {
        relative = "editor", row = instr_row, col = col, width = win_w, height = 5,
        style = "minimal", border = "rounded", title = " Instruction — optional (Enter=newline, M-CR=submit, Esc=cancel) ",
    })

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        pcall(vim.api.nvim_win_close, list_win, true)
        pcall(vim.api.nvim_win_close, instr_win, true)
    end

    local function move(delta)
        sel = ((sel - 1 + delta) % #modes) + 1
        render_list()
    end

    local function submit()
        local m = modes[sel]
        local instruction = table.concat(vim.api.nvim_buf_get_lines(instr_buf, 0, -1, false), "\n")
        instruction = instruction:gsub("^%s+", ""):gsub("%s+$", "")
        if m.name == "free-form" and instruction == "" then
            parley.logger.warning("Review menu: free-form mode requires an instruction")
            return
        end
        _last_mode = m.name
        close()
        on_submit({ mode = m.name, instruction = instruction })
    end

    -- Keymaps live on the instruction buffer (focused, always typeable): C-j/C-k
    -- and Tab/S-Tab move the mode selection; M-CR / C-s submit; Esc cancels.
    -- Enter stays a normal newline so the instruction can be multi-line.
    local function map(modes_, lhs, fn)
        vim.keymap.set(modes_, lhs, fn, { buffer = instr_buf, nowait = true, silent = true })
    end
    map({ "n", "i" }, "<C-j>", function() move(1) end)
    map({ "n", "i" }, "<C-k>", function() move(-1) end)
    map({ "n", "i" }, "<Tab>", function() move(1) end)
    map({ "n", "i" }, "<S-Tab>", function() move(-1) end)
    map({ "n", "i" }, "<M-CR>", submit)
    map({ "n", "i" }, "<C-s>", submit)
    map("n", "<CR>", submit)
    map({ "n", "i" }, "<Esc>", close)

    vim.api.nvim_set_current_win(instr_win)
    pcall(vim.cmd, "startinsert")

    return {
        list_win = list_win,
        instr_win = instr_win,
        submit = submit,
        move = move,
        close = close,
        selected = function() return modes[sel].name end,
    }
end

return M
