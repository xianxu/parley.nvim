-- float_picker.lua
-- A self-contained floating window picker for Parley.nvim.
--
-- Layout: two adjacent floating windows —
--   Results window (top, focusable): items with cursorline showing selection.
--   Prompt window  (bottom, focused):  user types query here; results filter live.
--
-- Mouse:
--   <LeftMouse> in results  – move selection, return focus to prompt
--   <2-LeftMouse> in results – confirm selected item and close
--
-- Keyboard (from prompt, insert mode):
--   <CR>          – confirm selected item
--   <Esc>/<C-c>   – cancel
--   <C-j>/<Down>  – move selection down
--   <C-k>/<Up>    – move selection up
--
-- Fuzzy matching (multi-word):
--   Query is split on whitespace into words.
--   ALL words must match for an item to appear.
--   Word order in the query does NOT matter ("gpt open" matches "openai gpt-4").
--   Within each word, characters must appear IN ORDER in the haystack (subsequence).
--   Items are ranked by total score (higher = better match).
--
-- Sizing:
--   desired_w = max(title+4, longest item+2) or opts.width.
--   desired_h = #items or opts.height (results rows only).
--   Actual size clamped to screen minus MARGIN_H / MARGIN_V on each side.
--   Total vertical space = results_h + 5 (borders for both windows + prompt row).
--   VimResized repositions both windows (global autocmd, cleaned up on close).

local M = {}

local MIN_W    = 20  -- minimum picker width  (chars)
local MIN_H    = 1   -- minimum results height (lines)
local MARGIN_H = 4   -- cols kept clear on each horizontal edge
local MARGIN_V = 3   -- rows kept clear on each vertical edge
-- Rows consumed by borders of both windows + 1 prompt content row:
--   results top-border(1) + results bottom-border(1) +
--   prompt  top-border(1) + prompt  content(1) + prompt bottom-border(1) = 5
local PROMPT_OVERHEAD = 5

-- Highlight namespace for fuzzy match characters in results.
local MATCH_NS = vim.api.nvim_create_namespace("float_picker_match")

-- ---------------------------------------------------------------------------
-- Fuzzy scoring
-- ---------------------------------------------------------------------------

-- Score a single word (query fragment) against a haystack string.
-- Returns a numeric score if every character in `word` appears in order
-- in `haystack` (case-insensitive), or nil if there is no match.
-- Scoring bonuses:
--   +5  for each character that immediately follows the previous match (consecutive run)
--   +10 for a match at a word boundary (space, '-', '_', '.' precedes it)
--   +15 for a match at position 1 (prefix of the whole string)
local function score_word(word, haystack)
    local hw = haystack:lower()
    local ww = word:lower()
    local wlen = #ww
    if wlen == 0 then return 0 end

    local hi = 1       -- current position in haystack (1-based byte index)
    local prev_hi = nil
    local score = 0

    for wi = 1, wlen do
        local wchar = ww:sub(wi, wi)
        local found = hw:find(wchar, hi, true)
        if not found then return nil end  -- word is not a subsequence

        -- Consecutive bonus
        if prev_hi and found == prev_hi + 1 then
            score = score + 5
        end
        -- Word-boundary bonus
        if found == 1 then
            score = score + 15
        elseif found > 1 then
            local preceding = hw:sub(found - 1, found - 1)
            if preceding == " " or preceding == "-" or preceding == "_" or preceding == "." then
                score = score + 10
            end
        end

        prev_hi = found
        hi = found + 1
    end

    return score
end

-- Return the 1-based byte positions in `text` where the characters of `word`
-- matched (same greedy left-to-right scan as score_word), or nil on no match.
local function match_positions(word, text)
    local hw = text:lower()
    local ww = word:lower()
    if #ww == 0 then return {} end
    local positions = {}
    local hi = 1
    for wi = 1, #ww do
        local found = hw:find(ww:sub(wi, wi), hi, true)
        if not found then return nil end
        table.insert(positions, found)
        hi = found + 1
    end
    return positions
end

-- Score a multi-word query against a haystack.
-- Splits query on whitespace; ALL words must match (order irrelevant).
-- Returns total score (sum of per-word scores) or nil if any word fails.
function M._fuzzy_score(query, haystack)
    if not query or query == "" then return 0 end
    local total = 0
    for word in query:gmatch("%S+") do
        local s = score_word(word, haystack)
        if s == nil then return nil end
        total = total + s
    end
    return total
end

-- ---------------------------------------------------------------------------
-- Layout helpers
-- ---------------------------------------------------------------------------

-- Compute actual dimensions and positions for results and prompt windows.
local function compute_layout(desired_w, desired_h, ui)
    local screen_w = ui.width
    local screen_h = ui.height
    local win_w   = math.max(MIN_W, math.min(desired_w, screen_w - MARGIN_H * 2))
    local max_h   = math.max(MIN_H, screen_h - MARGIN_V * 2 - PROMPT_OVERHEAD)
    local win_h   = math.max(MIN_H, math.min(desired_h, max_h))
    -- Centre based on total visual height (results borders + prompt borders + content)
    local total_h = win_h + PROMPT_OVERHEAD
    local row     = math.floor((screen_h - total_h) / 2)
    local col     = math.floor((screen_w - win_w)   / 2)
    -- Prompt sits immediately below results (results takes row..row+win_h+1 visually)
    local prompt_row = row + win_h + 2
    return win_w, win_h, row, col, prompt_row
end

-- Truncate a display string to fit within max_w display columns, appending "…".
local function truncate(text, max_w)
    if vim.fn.strdisplaywidth(text) <= max_w then return text end
    local result = ""
    local w, n = 0, 0
    local nchars = vim.fn.strchars(text)
    while n < nchars do
        local char = vim.fn.strcharpart(text, n, 1)
        local cw   = vim.fn.strdisplaywidth(char)
        if w + cw + 1 > max_w then
            return result .. "…"
        end
        result = result .. char
        w = w + cw
        n = n + 1
    end
    return result
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Open a floating picker.
--- @param opts table:
---   title      string   – window title (shown on results window)
---   items      table    – list of { display: string, value: any }
---   width      number   – desired window width  (optional, content-driven by default)
---   height     number   – desired results height (optional, #items by default)
---   on_select  function(item) – called on confirmation
---   on_cancel  function()    – called on cancel/dismiss (optional)
---   mappings   table    – list of { key: string, fn: function(item, close_fn) }
---                         keys are mapped in the prompt (insert mode)
function M.open(opts)
    local items          = opts.items or {}
    local title          = opts.title or "Select"
    local on_select      = opts.on_select  or function() end
    local on_cancel      = opts.on_cancel  or function() end
    local extra_mappings = opts.mappings   or {}

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
    local win_w, win_h, row, col, prompt_row = compute_layout(desired_w, desired_h, ui)

    -- -----------------------------------------------------------------------
    -- Buffers
    -- -----------------------------------------------------------------------
    local results_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[results_buf].bufhidden = "wipe"
    vim.bo[results_buf].buftype   = "nofile"

    local prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[prompt_buf].bufhidden = "wipe"
    vim.bo[prompt_buf].buftype   = "nofile"
    vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { "" })

    -- -----------------------------------------------------------------------
    -- Filtered items + selection state
    -- -----------------------------------------------------------------------
    local filtered = vim.deepcopy(items)  -- current filtered+sorted subset
    local sel_idx  = 1                    -- 1-based index into filtered

    -- Rewrite results buffer from current `filtered` list.
    local function refresh_results()
        vim.bo[results_buf].modifiable = true
        local lines = {}
        for _, item in ipairs(filtered) do
            table.insert(lines, truncate(" " .. item.display, win_w - 1))
        end
        if #lines == 0 then
            lines = { "  (no matches)" }
        end
        vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)
        vim.bo[results_buf].modifiable = false
    end
    refresh_results()

    -- -----------------------------------------------------------------------
    -- Windows
    -- -----------------------------------------------------------------------
    local results_cfg = {
        relative  = "editor",
        row = row, col = col, width = win_w, height = win_h,
        style     = "minimal",
        border    = "rounded",
        focusable = true,
    }
    if vim.fn.has("nvim-0.9") == 1 then
        results_cfg.title     = " " .. title .. " "
        results_cfg.title_pos = "center"
    end

    -- Results window is NOT focused on open (false = don't enter it)
    local results_win = vim.api.nvim_open_win(results_buf, false, results_cfg)
    vim.wo[results_win].cursorline     = true
    vim.wo[results_win].wrap           = false
    vim.wo[results_win].scrolloff      = 3
    vim.wo[results_win].number         = false
    vim.wo[results_win].relativenumber = false
    vim.wo[results_win].signcolumn     = "no"
    vim.wo[results_win].spell          = false

    local prompt_cfg = {
        relative  = "editor",
        row = prompt_row, col = col, width = win_w, height = 1,
        style     = "minimal",
        border    = "rounded",
        focusable = true,
    }
    -- Prompt window IS focused (true = enter it)
    local prompt_win = vim.api.nvim_open_win(prompt_buf, true, prompt_cfg)
    vim.wo[prompt_win].wrap           = false
    vim.wo[prompt_win].number         = false
    vim.wo[prompt_win].relativenumber = false
    vim.wo[prompt_win].signcolumn     = "no"

    -- Enter insert mode immediately
    vim.cmd("startinsert!")

    -- -----------------------------------------------------------------------
    -- Close / confirm / cancel helpers
    -- -----------------------------------------------------------------------
    local closed            = false
    local resize_autocmd_id = nil

    local function close_all()
        if closed then return end
        closed = true
        if resize_autocmd_id then
            pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
            resize_autocmd_id = nil
        end
        -- Exit insert mode before closing windows
        local mode = vim.api.nvim_get_mode().mode
        if mode == "i" or mode == "ic" then
            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
        end
        if vim.api.nvim_win_is_valid(prompt_win) then
            vim.api.nvim_win_close(prompt_win, true)
        end
        if vim.api.nvim_win_is_valid(results_win) then
            vim.api.nvim_win_close(results_win, true)
        end
    end

    local function get_selected_item()
        if #filtered == 0 then return nil end
        return filtered[math.max(1, math.min(sel_idx, #filtered))]
    end

    local function set_selection(idx)
        sel_idx = math.max(1, math.min(idx, math.max(1, #filtered)))
        if vim.api.nvim_win_is_valid(results_win) then
            vim.api.nvim_win_set_cursor(results_win, { sel_idx, 0 })
        end
    end

    local function confirm()
        local item = get_selected_item()
        close_all()
        if item then
            vim.schedule(function() on_select(item) end)
        end
    end

    local function cancel()
        close_all()
        vim.schedule(on_cancel)
    end

    -- -----------------------------------------------------------------------
    -- Match highlighting
    -- -----------------------------------------------------------------------

    -- Highlight matched characters for every visible result row.
    -- Operates on the actual buffer lines so truncation is respected automatically.
    -- ASCII query chars cannot alias into multi-byte UTF-8 sequences, so byte
    -- positions are always valid column boundaries for nvim_buf_add_highlight.
    local function highlight_matches(query)
        vim.api.nvim_buf_clear_namespace(results_buf, MATCH_NS, 0, -1)
        if not query or query == "" then return end
        local buf_lines = vim.api.nvim_buf_get_lines(results_buf, 0, -1, false)
        for i, _ in ipairs(filtered) do
            local line = buf_lines[i]
            if not line then break end
            for word in query:gmatch("%S+") do
                local positions = match_positions(word, line)
                if positions then
                    for _, pos in ipairs(positions) do
                        -- pos is 1-based byte offset in `line`; convert to 0-based col range
                        vim.api.nvim_buf_add_highlight(
                            results_buf, MATCH_NS, "Search", i - 1, pos - 1, pos)
                    end
                end
            end
        end
    end

    -- -----------------------------------------------------------------------
    -- Live filtering
    -- -----------------------------------------------------------------------
    local function apply_filter()
        local query = (vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or ""):gsub("^%s+", "")

        if query == "" then
            filtered = vim.deepcopy(items)
        else
            local scored = {}
            for _, item in ipairs(items) do
                local s = M._fuzzy_score(query, item.display)
                if s then
                    table.insert(scored, { item = item, score = s })
                end
            end
            table.sort(scored, function(a, b) return a.score > b.score end)
            filtered = {}
            for _, entry in ipairs(scored) do
                table.insert(filtered, entry.item)
            end
        end

        refresh_results()
        set_selection(1)
        highlight_matches(query)
    end

    -- -----------------------------------------------------------------------
    -- Key mappings – results window
    -- -----------------------------------------------------------------------
    local function nmap_r(key, fn)
        vim.keymap.set("n", key, fn,
            { buffer = results_buf, noremap = true, silent = true, nowait = true })
    end

    -- Single click reaching results (only possible when prompt is in normal mode and
    -- the user clicked results directly): sync sel_idx and return to prompt.
    nmap_r("<LeftMouse>", function()
        if vim.api.nvim_win_is_valid(results_win) then
            sel_idx = vim.api.nvim_win_get_cursor(results_win)[1]
        end
        vim.schedule(function()
            if not closed and vim.api.nvim_win_is_valid(prompt_win) then
                vim.api.nvim_set_current_win(prompt_win)
            end
        end)
    end)

    -- Suppress drag and release so clicking never starts a visual selection.
    nmap_r("<LeftDrag>",    function() end)
    nmap_r("<LeftRelease>", function() end)

    -- Double-click: confirm immediately.
    nmap_r("<2-LeftMouse>", function()
        if vim.api.nvim_win_is_valid(results_win) then
            sel_idx = vim.api.nvim_win_get_cursor(results_win)[1]
        end
        confirm()
    end)

    -- Keyboard fallback if focus somehow lands in results.
    nmap_r("<CR>",  confirm)
    nmap_r("<Esc>", cancel)
    nmap_r("q",     cancel)

    -- -----------------------------------------------------------------------
    -- Key mappings – prompt (insert + normal mode)
    -- -----------------------------------------------------------------------
    local function imap(key, fn)
        vim.keymap.set("i", key, fn,
            { buffer = prompt_buf, noremap = true, silent = true, nowait = true })
    end
    local function nmap_p(key, fn)
        vim.keymap.set("n", key, fn,
            { buffer = prompt_buf, noremap = true, silent = true, nowait = true })
    end

    -- Mouse in prompt: <LeftMouse> from insert mode is consumed here BEFORE Neovim's
    -- default insert-mode click behavior (exit-insert + window-switch). We update
    -- the selection and stay in prompt insert mode — no focus change at all.
    local function prompt_click()
        local pos = vim.fn.getmousepos()
        if pos.winid == results_win and pos.line >= 1 then
            set_selection(pos.line)
        end
    end
    local function prompt_dblclick()
        local pos = vim.fn.getmousepos()
        if pos.winid == results_win and pos.line >= 1 then
            set_selection(pos.line)
            confirm()
        end
    end
    imap("<LeftMouse>",    prompt_click)
    imap("<2-LeftMouse>",  prompt_dblclick)
    nmap_p("<LeftMouse>",   prompt_click)
    nmap_p("<2-LeftMouse>", prompt_dblclick)

    imap("<CR>",   confirm)
    imap("<Esc>",  cancel)
    imap("<C-c>",  cancel)
    imap("<C-j>",  function() set_selection(sel_idx + 1) end)
    imap("<Down>", function() set_selection(sel_idx + 1) end)
    imap("<C-k>",  function() set_selection(sel_idx - 1) end)
    imap("<Up>",   function() set_selection(sel_idx - 1) end)
    nmap_p("<CR>",  confirm)
    nmap_p("<Esc>", cancel)
    nmap_p("q",     cancel)

    -- Extra caller-supplied mappings (e.g. delete, toggle in ChatFinder)
    for _, m in ipairs(extra_mappings) do
        local key = m.key
        local fn  = m.fn
        imap(key, function()
            local item = get_selected_item()
            fn(item, close_all)
        end)
        nmap_p(key, function()
            local item = get_selected_item()
            fn(item, close_all)
        end)
    end

    -- -----------------------------------------------------------------------
    -- TextChangedI – trigger live filter on every keystroke
    -- -----------------------------------------------------------------------
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        buffer   = prompt_buf,
        callback = apply_filter,
    })

    -- -----------------------------------------------------------------------
    -- VimResized – reposition both windows (global autocmd)
    -- -----------------------------------------------------------------------
    resize_autocmd_id = vim.api.nvim_create_autocmd("VimResized", {
        callback = function()
            if not vim.api.nvim_win_is_valid(results_win) then
                if resize_autocmd_id then
                    pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
                    resize_autocmd_id = nil
                end
                return
            end
            local new_ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
            local nw, nh, nr, nc, npr = compute_layout(desired_w, desired_h, new_ui)
            vim.api.nvim_win_set_config(results_win, {
                relative = "editor", row = nr,  col = nc, width = nw, height = nh,
            })
            if vim.api.nvim_win_is_valid(prompt_win) then
                vim.api.nvim_win_set_config(prompt_win, {
                    relative = "editor", row = npr, col = nc, width = nw, height = 1,
                })
            end
        end,
    })

    -- -----------------------------------------------------------------------
    -- WinLeave – dismiss picker when focus leaves both picker windows
    -- -----------------------------------------------------------------------
    local function on_win_leave()
        vim.schedule(function()
            if closed then return end
            local cur = vim.api.nvim_get_current_win()
            if cur == results_win or cur == prompt_win then return end
            cancel()
        end)
    end

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer   = prompt_buf,
        callback = on_win_leave,
    })
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer   = results_buf,
        callback = on_win_leave,
    })
end

return M
