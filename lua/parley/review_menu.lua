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

--- Open the review menu. The menu manages its own windows; the caller's
--- `on_submit` carries the action on the artifact buffer, so no buffer arg is
--- needed here.
--- @param opts table|nil { on_submit = fun({mode,instruction}), mode?, instruction? }
--- @return table|nil handle  { list_win, instr_win, submit, move, selected, close } (nil if no modes)
function M.open(opts)
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

    -- Sticky start line: the last-used mode (or an explicit opts.mode), else 1.
    -- Selection is the LIST window's cursor line — so j/k, arrows, and mouse all
    -- move it natively (the old C-j/C-k-in-insert scheme was undiscoverable and
    -- C-j is eaten as <NL> by most terminals). #133.
    local start_line = 1
    local want = opts.mode or _last_mode
    for i, m in ipairs(modes) do
        if m.name == want then
            start_line = i
            break
        end
    end

    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local win_w, win_h, row, col, _, instr_row = float_picker.compute_layout(70, #modes, ui, false)

    -- Mode list window (top) — focused; selection = cursor line.
    local list_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[list_buf].buftype = "nofile"
    vim.bo[list_buf].bufhidden = "wipe"
    do
        local lines = {}
        for i, m in ipairs(modes) do
            lines[i] = pretty(m.name)
        end
        vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    end
    vim.bo[list_buf].modifiable = false
    local list_win = vim.api.nvim_open_win(list_buf, true, {
        relative = "editor", row = row, col = col, width = win_w, height = win_h,
        style = "minimal", border = "rounded", title = " Review mode — j/k select · Enter run · Tab→instruction ",
    })
    vim.wo[list_win].cursorline = true -- visual selection marker
    vim.api.nvim_win_set_cursor(list_win, { start_line, 0 })

    -- Instruction editor window (bottom) — a normal modifiable buffer.
    local instr_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[instr_buf].buftype = ""
    vim.bo[instr_buf].bufhidden = "wipe"
    if opts.instruction and opts.instruction ~= "" then
        vim.api.nvim_buf_set_lines(instr_buf, 0, -1, false, vim.split(opts.instruction, "\n"))
    end
    local instr_win = vim.api.nvim_open_win(instr_buf, false, {
        relative = "editor", row = instr_row, col = col, width = win_w, height = 5,
        style = "minimal", border = "rounded", title = " Instruction — optional (M-CR/C-s submit · Tab/Esc→list) ",
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

    -- Selection = the list window's cursor line.
    local function selected_mode()
        local line = 1
        if vim.api.nvim_win_is_valid(list_win) then
            line = vim.api.nvim_win_get_cursor(list_win)[1]
        end
        return modes[line] or modes[1]
    end

    -- Programmatic move (used by tests + the optional C-j/C-k binding) — wraps.
    local function move(delta)
        if not vim.api.nvim_win_is_valid(list_win) then
            return
        end
        local n = #modes
        local cur = vim.api.nvim_win_get_cursor(list_win)[1]
        vim.api.nvim_win_set_cursor(list_win, { ((cur - 1 + delta) % n) + 1, 0 })
    end

    local function submit()
        local m = selected_mode()
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

    local function focus_instr()
        if vim.api.nvim_win_is_valid(instr_win) then
            vim.api.nvim_set_current_win(instr_win)
            pcall(vim.cmd, "startinsert")
        end
    end
    local function focus_list()
        if vim.api.nvim_win_is_valid(list_win) then
            pcall(vim.cmd, "stopinsert")
            vim.api.nvim_set_current_win(list_win)
        end
    end

    -- LIST window keymaps. Plain j/k/arrows/mouse move the cursor (= selection)
    -- natively — no mapping needed. Enter/M-CR/C-s run; Tab/i go to the
    -- instruction box; Esc/C-c cancel. C-j/C-k kept as belt-and-suspenders.
    local function lmap(lhs, fn)
        vim.keymap.set("n", lhs, fn, { buffer = list_buf, nowait = true, silent = true })
    end
    lmap("<CR>", submit)
    lmap("<M-CR>", submit)
    lmap("<C-s>", submit)
    lmap("<C-j>", function() move(1) end)
    lmap("<C-k>", function() move(-1) end)
    lmap("<Tab>", focus_instr)
    lmap("i", focus_instr)
    lmap("a", focus_instr)
    lmap("<Esc>", close)
    lmap("<C-c>", close)

    -- INSTRUCTION window keymaps: submit from either mode; Tab/normal-Esc return
    -- to the list (insert-Esc → normal mode so the box keeps full vim editing);
    -- C-c cancels. Enter stays a literal newline.
    local function imap(modes_, lhs, fn)
        vim.keymap.set(modes_, lhs, fn, { buffer = instr_buf, nowait = true, silent = true })
    end
    imap({ "n", "i" }, "<M-CR>", submit)
    imap({ "n", "i" }, "<C-s>", submit)
    imap({ "n", "i" }, "<C-c>", close)
    imap("n", "<Tab>", focus_list)
    imap("n", "<Esc>", focus_list)

    vim.api.nvim_set_current_win(list_win)

    return {
        list_win = list_win,
        instr_win = instr_win,
        submit = submit,
        move = move,
        focus_instr = focus_instr,
        close = close,
        selected = function() return selected_mode().name end,
    }
end

return M
