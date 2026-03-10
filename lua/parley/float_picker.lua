-- float_picker.lua
-- A self-contained floating window picker for Parley.nvim.
-- Replaces Telescope for all Parley pickers with proper mouse support:
--   <LeftMouse>   – move cursor to clicked line (select without closing)
--   <2-LeftMouse> – confirm selected item and close
-- Keyboard: j/k / Up/Down navigate, <CR> confirms, <Esc>/q cancels.
-- Use native '/' to search/filter within the item list.
-- Extra key mappings: opts.mappings = { { key=..., fn=function(item, close_fn) end } }
--
-- Sizing rules
--   Desired width  = max(title width + 4, longest item display + 2), or opts.width if given.
--   Desired height = number of items, or opts.height if given.
--   Actual size    = desired size clamped to (screen - margins), never below MIN_W / MIN_H.
--   Margins        = MARGIN_H cols on each side, MARGIN_V rows on top and bottom.
--   VimResized     = window is repositioned and resized whenever the terminal resizes.

local M = {}

local MIN_W   = 20  -- minimum picker width  (chars)
local MIN_H   = 1   -- minimum picker height (lines)
local MARGIN_H = 4  -- cols kept clear on each horizontal edge
local MARGIN_V = 3  -- rows kept clear on each vertical edge

-- Compute actual window width, height, row, col from desired dimensions and screen size.
local function compute_layout(desired_w, desired_h, ui)
    local screen_w = ui.width
    local screen_h = ui.height
    local win_w = math.max(MIN_W, math.min(desired_w, screen_w - MARGIN_H * 2))
    local win_h = math.max(MIN_H, math.min(desired_h, screen_h - MARGIN_V * 2))
    local row   = math.floor((screen_h - win_h) / 2)
    local col   = math.floor((screen_w - win_w) / 2)
    return win_w, win_h, row, col
end

-- Truncate a display string to fit within max_w display columns, appending "…".
local function truncate(text, max_w)
    if vim.fn.strdisplaywidth(text) <= max_w then
        return text
    end
    local result = ""
    local w = 0
    local n = 0
    local char_count = vim.fn.strchars(text)
    while n < char_count do
        local char = vim.fn.strcharpart(text, n, 1)
        local cw   = vim.fn.strdisplaywidth(char)
        if w + cw + 1 > max_w then   -- +1 reserved for "…"
            result = result .. "…"
            break
        end
        result = result .. char
        w = w + cw
        n = n + 1
    end
    return result
end

--- Open a floating picker.
--- @param opts table:
---   title      string   – window title
---   items      table    – list of { display: string, value: any }
---   width      number   – desired window width  (optional, content-driven by default)
---   height     number   – desired window height (optional, #items by default)
---   on_select  function(item) – called on confirmation
---   on_cancel  function()    – called on cancel/dismiss (optional)
---   mappings   table    – list of { key: string, fn: function(item, close_fn) }
function M.open(opts)
    local items         = opts.items or {}
    local title         = opts.title or "Select"
    local on_select     = opts.on_select or function() end
    local on_cancel     = opts.on_cancel or function() end
    local extra_mappings = opts.mappings or {}

    if #items == 0 then
        vim.notify("No items to pick from", vim.log.levels.WARN)
        return
    end

    -- Desired dimensions (content-driven unless caller overrides)
    local desired_w = opts.width or (function()
        local w = vim.fn.strdisplaywidth(title) + 4
        for _, item in ipairs(items) do
            local iw = vim.fn.strdisplaywidth(item.display) + 2
            if iw > w then w = iw end
        end
        return w
    end)()
    local desired_h = opts.height or #items

    -- Initial layout
    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local win_w, win_h, row, col = compute_layout(desired_w, desired_h, ui)

    -- Scratch buffer – populate with (potentially truncated) display lines
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].buftype   = "nofile"

    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, truncate(" " .. item.display, win_w - 1))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    -- Build initial window config; title field requires nvim 0.9+
    local win_cfg = {
        relative = "editor",
        row      = row,
        col      = col,
        width    = win_w,
        height   = win_h,
        style    = "minimal",
        border   = "rounded",
    }
    if vim.fn.has("nvim-0.9") == 1 then
        win_cfg.title     = " " .. title .. " "
        win_cfg.title_pos = "center"
    end

    local win = vim.api.nvim_open_win(buf, true, win_cfg)
    vim.wo[win].cursorline     = true
    vim.wo[win].wrap           = false
    vim.wo[win].scrolloff      = 3
    vim.wo[win].number         = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn     = "no"

    -- Closed-state guard to prevent double-close / double-callback
    local closed = false
    local resize_autocmd_id = nil

    local function close_win()
        if closed then return end
        closed = true
        if resize_autocmd_id then
            pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
            resize_autocmd_id = nil
        end
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    local function get_item()
        if not vim.api.nvim_win_is_valid(win) then return nil end
        local idx = vim.api.nvim_win_get_cursor(win)[1]
        return items[idx]
    end

    local function confirm()
        local item = get_item()
        close_win()
        if item then
            vim.schedule(function() on_select(item) end)
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
    -- Single click: cursor moves natively; suppress any action that might close the window.
    nmap("<LeftMouse>", function()
        vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
    end)
    -- Double-click confirms
    nmap("<2-LeftMouse>", confirm)

    -- Extra caller-supplied mappings
    for _, m in ipairs(extra_mappings) do
        local key = m.key
        local fn  = m.fn
        nmap(key, function()
            local item = get_item()
            fn(item, close_win)
        end)
    end

    -- Reposition and resize when the terminal window is resized.
    -- Must be a global autocmd (no buffer= filter) because VimResized is a
    -- global event and does not fire for buffer-local autocmds.
    resize_autocmd_id = vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            if not vim.api.nvim_win_is_valid(win) then
                -- Window already gone; clean up this autocmd
                if resize_autocmd_id then
                    pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
                    resize_autocmd_id = nil
                end
                return
            end
            local new_ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
            local nw, nh, nr, nc = compute_layout(desired_w, desired_h, new_ui)
            vim.api.nvim_win_set_config(win, {
                relative = "editor",
                row      = nr,
                col      = nc,
                width    = nw,
                height   = nh,
            })
        end,
    })

    -- Dismiss on WinLeave (user clicked outside or used another command)
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer   = buf,
        once     = true,
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
