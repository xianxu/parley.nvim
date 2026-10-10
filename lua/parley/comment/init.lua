-- comment/init.lua — attach compact 🤖 marker behavior to a buffer (#312).
--
-- Markers stay concealed on the cursor line in every mode (concealcursor
-- "nvic" while the cursor is on a marker line) and the cursor never rests on
-- hidden marker text (view.snap), so neither
-- commands nor typing can reach hidden comment text. An edit that still breaks
-- a marker from a visible edge renders it raw + ParleyReviewBroken (fail
-- visible); `u` restores. Creates nothing durable: the autocmds are
-- buffer-scoped and the prev-col table is cleared on WinClosed.
local view = require("parley.comment.view")

local M = {}

local prev_col = {} -- [winid] = last cursor col, for the snap's direction

-- concealcursor is window-wide: forcing "nvic" everywhere would also keep
-- treesitter's link/emphasis conceals hidden on the cursor line while typing.
-- So it is "nvic" only while the cursor sits on a line with a rendered marker.
-- The window's own value is re-read every time we are NOT forcing, so a later
-- change by the user or another plugin is kept, not clobbered.
local function restore_concealcursor(win)
    if vim.w[win].parley_cc_forced then
        vim.wo[win].concealcursor = vim.w[win].parley_cc_base or ""
        vim.w[win].parley_cc_forced = false
    end
end

local function sync_concealcursor(win, line)
    if not view.has_marker(line) then
        restore_concealcursor(win)
    elseif not vim.w[win].parley_cc_forced then
        vim.w[win].parley_cc_base = vim.wo[win].concealcursor
        vim.w[win].parley_cc_forced = true
        vim.wo[win].concealcursor = "nvic"
    end
end

local function on_cursor(buf)
    local win = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    sync_concealcursor(win, line)
    if line:find("🤖", 1, true) then
        -- Normal mode can't rest past the last byte; insert mode can.
        local insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
        local max = insert and #line or math.max(#line - 1, 0)
        local to = view.snap(view.layout(line), prev_col[win] or 0, col, max, line, insert)
        if to then
            vim.api.nvim_win_set_cursor(win, { row, to })
            col = to
        end
    end
    prev_col[win] = col
end

function M.attach(buf)
    -- conceallevel is window-local, so re-applied on every attach (BufEnter).
    -- 2, not 3: level 3 would drop the `…` / `]` replacement chars too.
    vim.opt_local.conceallevel = 2
    on_cursor(buf)
    if vim.b[buf].parley_comment_attached then return end
    vim.b[buf].parley_comment_attached = true
    local group = vim.api.nvim_create_augroup("ParleyComment" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group,
        buffer = buf,
        callback = function() on_cursor(buf) end,
    })
    -- <CR> on a marker opens its thread; elsewhere it stays native. Declared
    -- in keybinding_registry.native_overrides (a wrapped native key, like `*`)
    -- and, like every parley map, absent under default_keymaps = false.
    local parley = package.loaded["parley"]
    local keymaps_on = not (parley and parley.config and parley.config.default_keymaps == false)
    if keymaps_on then vim.keymap.set("n", "<CR>", function()
        if not require("parley.comment.float").open_thread(buf) then
            local keys = (vim.v.count > 0 and tostring(vim.v.count) or "") .. "<CR>"
            vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
        end
    end, { buffer = buf, desc = "Parley: open 🤖 comment thread (#312)" }) end
    -- Leaving the buffer hands the window back with its own concealcursor.
    vim.api.nvim_create_autocmd("BufLeave", {
        group = group,
        buffer = buf,
        callback = function() restore_concealcursor(vim.api.nvim_get_current_win()) end,
    })
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group,
        callback = function(ev) prev_col[tonumber(ev.match)] = nil end,
    })
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = buf,
        callback = function() pcall(vim.api.nvim_del_augroup_by_id, group) end,
    })
end

return M
