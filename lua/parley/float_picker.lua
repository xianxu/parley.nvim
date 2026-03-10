-- float_picker.lua
-- A self-contained floating window picker for Parley.nvim.
-- Replaces Telescope for all Parley pickers with proper mouse support:
--   <LeftMouse>   – move cursor to clicked line (select without closing)
--   <2-LeftMouse> – confirm selected item and close
-- Keyboard: j/k / Up/Down navigate, <CR> confirms, <Esc>/q cancels.
-- Use native '/' to search/filter within the item list.
-- Extra key mappings: opts.mappings = { { key=..., fn=function(item, close_fn) end } }

local M = {}

--- Open a floating picker.
--- @param opts table:
---   title      string   – window title
---   items      table    – list of { display: string, value: any }
---   on_select  function(item) – called on confirmation
---   on_cancel  function()    – called on cancel/dismiss (optional)
---   mappings   table    – list of { key: string, fn: function(item, close_fn) }
function M.open(opts)
    local items = opts.items or {}
    local title = opts.title or "Select"
    local on_select = opts.on_select or function() end
    local on_cancel = opts.on_cancel or function() end
    local extra_mappings = opts.mappings or {}

    if #items == 0 then
        vim.notify("No items to pick from", vim.log.levels.WARN)
        return
    end

    -- Compute window dimensions
    local max_w = vim.fn.strdisplaywidth(title) + 4
    for _, item in ipairs(items) do
        local w = vim.fn.strdisplaywidth(item.display) + 2
        if w > max_w then
            max_w = w
        end
    end

    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local win_w = math.min(max_w, math.floor(ui.width * 0.85))
    local win_h = math.min(#items, math.floor(ui.height * 0.75))
    local row = math.floor((ui.height - win_h) / 2)
    local col = math.floor((ui.width - win_w) / 2)

    -- Scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype = "nofile"

    -- Truncate display text to fit window width (leave 1 char margin)
    local trunc_w = win_w - 1
    local lines = {}
    for _, item in ipairs(items) do
        local text = " " .. item.display
        if vim.fn.strdisplaywidth(text) > trunc_w then
            -- Truncate with ellipsis using strcharpart for correct UTF-8 iteration
            local truncated = ""
            local w = 0
            local n = 0
            local char_count = vim.fn.strchars(text)
            while n < char_count do
                local char = vim.fn.strcharpart(text, n, 1)
                local cw = vim.fn.strdisplaywidth(char)
                if w + cw + 1 > trunc_w then
                    truncated = truncated .. "…"
                    break
                end
                truncated = truncated .. char
                w = w + cw
                n = n + 1
            end
            text = truncated
        end
        table.insert(lines, text)
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Build window config; title requires nvim 0.9+
    local win_cfg = {
        relative = "editor",
        row = row,
        col = col,
        width = win_w,
        height = win_h,
        style = "minimal",
        border = "rounded",
    }
    if vim.fn.has("nvim-0.9") == 1 then
        win_cfg.title = " " .. title .. " "
        win_cfg.title_pos = "center"
    end

    local win = vim.api.nvim_open_win(buf, true, win_cfg)
    vim.wo[win].cursorline = true
    vim.wo[win].wrap = false
    vim.wo[win].scrolloff = 3
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"

    -- Closed-state guard to prevent double-close / double-callback
    local closed = false

    local function close_win()
        if closed then
            return
        end
        closed = true
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function get_item()
        if not vim.api.nvim_win_is_valid(win) then
            return nil
        end
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        return items[idx]
    end

    local function confirm()
        local item = get_item()
        close_win()
        if item then
            vim.schedule(function()
                on_select(item)
            end)
        end
    end

    local function cancel()
        close_win()
        vim.schedule(on_cancel)
    end

    -- Keymaps (normal mode only – picker opens in normal mode)
    local function nmap(key, fn)
        vim.keymap.set("n", key, fn, { buffer = buf, noremap = true, silent = true, nowait = true })
    end

    nmap("<CR>", confirm)
    nmap("<Esc>", cancel)
    nmap("q", cancel)
    -- Single click: cursor moves natively; we just suppress any default action
    -- that might close the window, so the pick remains open.
    nmap("<LeftMouse>", function()
        -- Move cursor to click position and stay open
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
    end)
    -- Double-click confirms
    nmap("<2-LeftMouse>", confirm)

    -- Extra caller-supplied mappings
    for _, m in ipairs(extra_mappings) do
        local key = m.key
        local fn = m.fn
        nmap(key, function()
            local item = get_item()
            fn(item, close_win)
        end)
    end

    -- Dismiss on WinLeave (user clicked outside or used another command)
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = buf,
        once = true,
        callback = function()
            vim.schedule(function()
                if not closed then
                    close_win()
                    on_cancel()
                end
            end)
        end,
    })
end

return M
