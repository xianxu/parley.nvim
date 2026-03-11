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
local PROMPT_PREFIX = "> "
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

function M._visual_row_for_index(idx, filtered_count, total_rows)
    if filtered_count <= 0 then
        return total_rows
    end
    return total_rows - math.max(1, math.min(idx, filtered_count)) + 1
end

function M._index_for_visual_row(visual_row, filtered_count, total_rows)
    if filtered_count <= 0 then
        return 1
    end
    local first_row = math.max(1, total_rows - filtered_count + 1)
    local clamped = math.max(first_row, math.min(visual_row, total_rows))
    return math.max(1, math.min(total_rows - clamped + 1, filtered_count))
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
    local on_select      = opts.on_select or function() end
    local on_cancel      = opts.on_cancel or function() end
    local extra_mappings = opts.mappings or {}

    if #items == 0 then
        vim.notify("No items to pick from", vim.log.levels.WARN)
        return
    end

    local desired_w = opts.width or (function()
        local w = vim.fn.strdisplaywidth(title) + 4
        for _, item in ipairs(items) do
            local iw = vim.fn.strdisplaywidth(item.display) + 2
            if iw > w then w = iw end
        end
        return w
    end)()
    local desired_h = opts.height or #items

    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local win_w, win_h, row, col, prompt_row = compute_layout(desired_w, desired_h, ui)

    local results_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[results_buf].bufhidden = "wipe"
    vim.bo[results_buf].buftype = "nofile"

    local prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[prompt_buf].bufhidden = "wipe"
    vim.bo[prompt_buf].buftype = "prompt"
    vim.fn.prompt_setprompt(prompt_buf, PROMPT_PREFIX)

    local filtered = vim.deepcopy(items)
    local initial_index = math.max(1, tonumber(opts.initial_index) or 1)
    local sel_idx = initial_index
    local query_text = ""
    local query_cursor = 0
    local closed = false
    local external_ui_active = false
    local resize_autocmd_id = nil
    local on_key_ns = vim.api.nvim_create_namespace("float_picker_on_key")

    local function keycode(key)
        return vim.api.nvim_replace_termcodes(key, true, false, true)
    end
    local function key_name(key)
        return vim.fn.keytrans(key)
    end

    local results_cfg = {
        relative = "editor",
        row = row,
        col = col,
        width = win_w,
        height = win_h,
        style = "minimal",
        border = "rounded",
        focusable = true,
    }
    if vim.fn.has("nvim-0.9") == 1 then
        results_cfg.title = " " .. title .. " "
        results_cfg.title_pos = "center"
    end

    local results_win = vim.api.nvim_open_win(results_buf, false, results_cfg)
    vim.wo[results_win].cursorline = true
    vim.wo[results_win].winhighlight = "CursorLine:PmenuSel"
    vim.wo[results_win].wrap = false
    vim.wo[results_win].scrolloff = 0
    vim.wo[results_win].number = false
    vim.wo[results_win].relativenumber = false
    vim.wo[results_win].signcolumn = "no"
    vim.wo[results_win].spell = false

    local prompt_cfg = {
        relative = "editor",
        row = prompt_row,
        col = col,
        width = win_w,
        height = 1,
        style = "minimal",
        border = "rounded",
        focusable = true,
    }
    local prompt_win = vim.api.nvim_open_win(prompt_buf, true, prompt_cfg)
    vim.wo[prompt_win].wrap = false
    vim.wo[prompt_win].number = false
    vim.wo[prompt_win].relativenumber = false
    vim.wo[prompt_win].signcolumn = "no"

    local function prompt_line()
        if not vim.api.nvim_buf_is_valid(prompt_buf) then
            return PROMPT_PREFIX
        end
        return vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1] or PROMPT_PREFIX
    end

    local function current_query_from_buffer()
        local line = prompt_line()
        if line:sub(1, #PROMPT_PREFIX) == PROMPT_PREFIX then
            return line:sub(#PROMPT_PREFIX + 1)
        end
        return line
    end

    local function render_prompt()
        if closed then return end
        if not vim.api.nvim_buf_is_valid(prompt_buf) then
            return
        end
        vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { PROMPT_PREFIX .. query_text })
        if vim.api.nvim_win_is_valid(prompt_win) then
            vim.api.nvim_win_set_cursor(prompt_win, { 1, #PROMPT_PREFIX + query_cursor })
        end
    end

    local function focus_prompt()
        if closed or not vim.api.nvim_win_is_valid(prompt_win) then
            return
        end
        vim.api.nvim_set_current_win(prompt_win)
        vim.api.nvim_win_set_cursor(prompt_win, { 1, #PROMPT_PREFIX + query_cursor })
        local mode = vim.api.nvim_get_mode().mode
        if mode ~= "i" and mode ~= "ic" then
            vim.cmd("startinsert!")
        end
    end

    local function sync_query_from_prompt()
        query_text = current_query_from_buffer()
        if vim.api.nvim_win_is_valid(prompt_win) then
            local prompt_col = vim.api.nvim_win_get_cursor(prompt_win)[2] - #PROMPT_PREFIX
            query_cursor = math.max(0, math.min(prompt_col, #query_text))
        else
            query_cursor = math.min(query_cursor, #query_text)
        end
    end

    local function refresh_results()
        vim.bo[results_buf].modifiable = true
        local lines = {}
        local total_rows = vim.api.nvim_win_is_valid(results_win) and vim.api.nvim_win_get_height(results_win) or win_h
        for i = #filtered, 1, -1 do
            table.insert(lines, truncate(" " .. filtered[i].display, win_w - 1))
        end
        if #lines == 0 then
            lines = { "  (no matches)" }
        end
        while #lines < total_rows do
            table.insert(lines, 1, "")
        end
        vim.api.nvim_buf_set_lines(results_buf, 0, -1, false, lines)
        vim.bo[results_buf].modifiable = false
    end

    local function results_row_count()
        if vim.api.nvim_buf_is_valid(results_buf) then
            return math.max(1, vim.api.nvim_buf_line_count(results_buf))
        end
        if vim.api.nvim_win_is_valid(results_win) then
            return math.max(1, vim.api.nvim_win_get_height(results_win))
        end
        return win_h
    end

    local function first_content_row()
        local content_count = math.max(1, #filtered)
        return math.max(1, results_row_count() - content_count + 1)
    end

    local function visual_row_for_index(idx)
        return M._visual_row_for_index(idx, #filtered, results_row_count())
    end

    local function index_for_visual_row(visual_row)
        return M._index_for_visual_row(visual_row, #filtered, results_row_count())
    end

    local function is_content_row(visual_row)
        if #filtered == 0 then
            return visual_row == results_row_count()
        end
        return visual_row >= first_content_row() and visual_row <= results_row_count()
    end

    local function close_all()
        if closed then return end
        closed = true
        if resize_autocmd_id then
            pcall(vim.api.nvim_del_autocmd, resize_autocmd_id)
            resize_autocmd_id = nil
        end
        vim.on_key(nil, on_key_ns)
        local mode = vim.api.nvim_get_mode().mode
        if mode == "i" or mode == "ic" then
            vim.api.nvim_feedkeys(keycode("<Esc>"), "n", true)
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

    local function set_selection(idx, selection_opts)
        selection_opts = selection_opts or {}
        sel_idx = math.max(1, math.min(idx, math.max(1, #filtered)))
        if vim.api.nvim_win_is_valid(results_win) then
            local target_row = visual_row_for_index(sel_idx)
            if selection_opts.preserve_view then
                local view = vim.api.nvim_win_call(results_win, vim.fn.winsaveview)
                vim.api.nvim_win_set_cursor(results_win, { target_row, 0 })
                view.lnum = target_row
                view.col = 0
                vim.api.nvim_win_call(results_win, function()
                    vim.fn.winrestview(view)
                end)
            elseif selection_opts.ensure_visible then
                local view = vim.api.nvim_win_call(results_win, vim.fn.winsaveview)
                local total_rows = results_row_count()
                local win_rows = vim.api.nvim_win_get_height(results_win)
                local max_topline = math.max(1, total_rows - win_rows + 1)
                local topline = view.topline
                local bottomline = topline + win_rows - 1

                if target_row < topline then
                    topline = target_row
                elseif target_row > bottomline then
                    topline = target_row - win_rows + 1
                end

                topline = math.max(1, math.min(topline, max_topline))

                vim.api.nvim_win_set_cursor(results_win, { target_row, 0 })
                vim.api.nvim_win_call(results_win, function()
                    vim.fn.winrestview({ topline = topline, leftcol = view.leftcol or 0 })
                end)
            else
                local total_rows = results_row_count()
                local win_rows = vim.api.nvim_win_get_height(results_win)
                local max_topline = math.max(1, total_rows - win_rows + 1)
                local topline = math.max(1, math.min(target_row - win_rows + 1, max_topline))

                vim.api.nvim_win_set_cursor(results_win, { target_row, 0 })
                vim.api.nvim_win_call(results_win, function()
                    vim.fn.winrestview({ topline = topline, leftcol = 0 })
                end)
            end
        end
    end

    local function move_selection(delta_rows)
        if #filtered == 0 then
            return
        end
        local current_row = visual_row_for_index(sel_idx)
        local next_row = math.max(first_content_row(), math.min(current_row + delta_rows, results_row_count()))
        set_selection(index_for_visual_row(next_row), { ensure_visible = true })
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

    local function suspend_for_external_ui()
        external_ui_active = true
    end

    local function resume_after_external_ui()
        external_ui_active = false
    end

    local function highlight_matches(query)
        vim.api.nvim_buf_clear_namespace(results_buf, MATCH_NS, 0, -1)
        if not query or query == "" then return end
        local buf_lines = vim.api.nvim_buf_get_lines(results_buf, 0, -1, false)
        for idx, _ in ipairs(filtered) do
            local visual_row = visual_row_for_index(idx)
            local line = buf_lines[visual_row]
            if not line then break end
            for word in query:gmatch("%S+") do
                local positions = match_positions(word, line)
                if positions then
                    for _, pos in ipairs(positions) do
                        vim.api.nvim_buf_add_highlight(
                            results_buf, MATCH_NS, "Search", visual_row - 1, pos - 1, pos)
                    end
                end
            end
        end
    end

    local function apply_filter(reset_selection)
        local query = query_text:gsub("^%s+", "")
        if query == "" then
            filtered = vim.deepcopy(items)
        else
            local scored = {}
            for _, item in ipairs(items) do
                local score = M._fuzzy_score(query, item.display)
                if score then
                    table.insert(scored, { item = item, score = score })
                end
            end
            table.sort(scored, function(a, b) return a.score > b.score end)
            filtered = {}
            for _, entry in ipairs(scored) do
                table.insert(filtered, entry.item)
            end
        end
        refresh_results()
        if reset_selection == false then
            set_selection(sel_idx)
        elseif initial_index and query == "" then
            set_selection(initial_index)
            initial_index = nil
        else
            set_selection(1)
        end
        highlight_matches(query)
    end

    local function invoke_extra_mapping(fn)
        local context = {
            suspend_for_external_ui = suspend_for_external_ui,
            resume_after_external_ui = resume_after_external_ui,
            focus_prompt = focus_prompt,
            skip_focus_restore = false,
        }
        fn(get_selected_item(), close_all, context)
        return context
    end

    render_prompt()
    apply_filter(true)

    local function nmap_r(key, fn)
        vim.keymap.set("n", key, fn, {
            buffer = results_buf,
            noremap = true,
            silent = true,
            nowait = true,
        })
    end

    local function nmap_p(key, fn)
        vim.keymap.set("n", key, fn, {
            buffer = prompt_buf,
            noremap = true,
            silent = true,
            nowait = true,
        })
    end
    local function imap_p(key, fn)
        vim.keymap.set("i", key, fn, {
            buffer = prompt_buf,
            noremap = true,
            silent = true,
            nowait = true,
        })
    end

    local function prompt_click()
        local pos = vim.fn.getmousepos()
        if pos.winid == results_win and is_content_row(pos.line) then
            set_selection(index_for_visual_row(pos.line), { preserve_view = true })
            focus_prompt()
        end
    end

    local function prompt_dblclick()
        local pos = vim.fn.getmousepos()
        if pos.winid == results_win and is_content_row(pos.line) then
            set_selection(index_for_visual_row(pos.line))
            confirm()
        end
    end

    nmap_r("<LeftMouse>", function()
        if vim.api.nvim_win_is_valid(results_win) then
            set_selection(index_for_visual_row(vim.api.nvim_win_get_cursor(results_win)[1]), { preserve_view = true })
        end
        vim.schedule(function()
            focus_prompt()
        end)
    end)
    nmap_r("<LeftDrag>", function() end)
    nmap_r("<LeftRelease>", function() end)
    nmap_r("<2-LeftMouse>", function()
        if vim.api.nvim_win_is_valid(results_win) then
            sel_idx = index_for_visual_row(vim.api.nvim_win_get_cursor(results_win)[1])
        end
        confirm()
    end)
    nmap_r("<CR>", confirm)
    nmap_r("<Esc>", cancel)
    nmap_r("q", cancel)

    nmap_p("<LeftMouse>", prompt_click)
    nmap_p("<2-LeftMouse>", prompt_dblclick)
    nmap_p("<CR>", confirm)
    nmap_p("<Esc>", cancel)
    nmap_p("q", cancel)
    imap_p("<LeftMouse>", prompt_click)
    imap_p("<2-LeftMouse>", prompt_dblclick)
    imap_p("<Up>", function()
        move_selection(-1)
        focus_prompt()
    end)
    imap_p("<Down>", function()
        move_selection(1)
        focus_prompt()
    end)
    imap_p("<Left>", function()
        query_cursor = math.max(0, query_cursor - 1)
        focus_prompt()
    end)
    imap_p("<Right>", function()
        query_cursor = math.min(#query_text, query_cursor + 1)
        focus_prompt()
    end)

    local function run_extra_mapping(fn)
        local context = invoke_extra_mapping(fn)
        if not closed and not context.skip_focus_restore and not external_ui_active then
            focus_prompt()
        end
    end

    for _, m in ipairs(extra_mappings) do
        imap_p(m.key, function()
            run_extra_mapping(m.fn)
        end)
        nmap_p(m.key, function()
            run_extra_mapping(m.fn)
        end)
        nmap_r(m.key, function()
            run_extra_mapping(m.fn)
        end)
    end

    vim.fn.prompt_setcallback(prompt_buf, function()
        confirm()
    end)
    vim.fn.prompt_setinterrupt(prompt_buf, function()
        cancel()
    end)

    local special_keys = {
        ["<Esc>"] = function()
            cancel()
        end,
        ["<C-j>"] = function()
            move_selection(1)
            focus_prompt()
        end,
        ["<C-k>"] = function()
            move_selection(-1)
            focus_prompt()
        end,
    }

    vim.on_key(function(key)
        if closed then return end

        local cur_win = vim.api.nvim_get_current_win()
        local mouse = vim.fn.getmousepos()
        local translated = key_name(key)
        if cur_win == prompt_win and mouse.winid == results_win then
            if translated == "<LeftMouse>" and is_content_row(mouse.line) then
                vim.schedule(function()
                    if closed then return end
                    set_selection(index_for_visual_row(mouse.line), { preserve_view = true })
                    focus_prompt()
                end)
                return
            elseif translated == "<2-LeftMouse>" and is_content_row(mouse.line) then
                vim.schedule(function()
                    if closed then return end
                    set_selection(index_for_visual_row(mouse.line))
                    confirm()
                end)
                return
            end
        end

        if cur_win ~= prompt_win then
            return
        end

        local special = special_keys[translated]
        if special then
            vim.schedule(function()
                if closed then return end
                special()
            end)
            return
        end

        if translated == "<CR>" then
            return
        end
    end, on_key_ns)

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        buffer = prompt_buf,
        callback = function()
            if closed or not vim.api.nvim_buf_is_valid(prompt_buf) then
                return
            end
            sync_query_from_prompt()
            apply_filter(true)
        end,
    })

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
                relative = "editor",
                row = nr,
                col = nc,
                width = nw,
                height = nh,
            })
            if vim.api.nvim_win_is_valid(prompt_win) then
                vim.api.nvim_win_set_config(prompt_win, {
                    relative = "editor",
                    row = npr,
                    col = nc,
                    width = nw,
                    height = 1,
                })
            end
            refresh_results()
            set_selection(sel_idx)
            highlight_matches(query_text:gsub("^%s+", ""))
        end,
    })

    local function on_win_leave()
        vim.schedule(function()
            if closed then return end
            if external_ui_active then
                return
            end
            local cur = vim.api.nvim_get_current_win()
            if cur == results_win or cur == prompt_win then
                return
            end
            cancel()
        end)
    end

    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = prompt_buf,
        callback = on_win_leave,
    })
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer = results_buf,
        callback = on_win_leave,
    })

    focus_prompt()
end

return M
