-- parley.progress — a detached, reusable progress bar (#133 M7).
--
-- Parley's first "substantive progress" surface: most ops are instant, but a
-- review round takes ~30s and needs a visible running cue. A floating bar pinned
-- just above the statusline (detached — not lualine, not the native 'winbar' —
-- so it can grow to multi-line detail for future long-running ops), with an
-- animated spinner + message + elapsed seconds. One active bar at a time (parley
-- runs one such op at a time). Pure `frame`/`format`; the float + timer are the
-- thin IO seam.

local M = {}

-- The single source of the braille spinner glyphs — other surfaces (the two
-- chat_respond spinners) reuse this instead of open-coding their own copy (#133).
M.SPINNER = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

--- PURE: the spinner glyph for an animation tick.
--- @param tick number
--- @return string
function M.frame(tick)
    return M.SPINNER[(tick % #M.SPINNER) + 1]
end

--- PURE: the bar's display line.
--- @param spinner string
--- @param message string|nil
--- @param elapsed number|nil  seconds
--- @return string
function M.format(spinner, message, elapsed)
    return string.format(" %s %s  (%ds)", spinner or "", message or "", elapsed or 0)
end

-- The single active session: { buf, win, timer, tick, start, message }.
local _s = nil

local function render()
    if not _s or not vim.api.nvim_buf_is_valid(_s.buf) then
        return
    end
    local line = M.format(M.frame(_s.tick), _s.message, os.time() - _s.start)
    vim.api.nvim_buf_set_lines(_s.buf, 0, -1, false, { line })
end

--- Start (or replace) the progress bar with `message`.
--- @param message string|nil
--- @return boolean ok
function M.start(message)
    M.stop()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
    local ok, win = pcall(vim.api.nvim_open_win, buf, false, {
        relative = "editor",
        row = math.max(0, ui.height - 2), -- just above the statusline
        col = 0,
        width = math.max(1, ui.width),
        height = 1,
        style = "minimal",
        focusable = false,
        zindex = 200,
    })
    if not ok then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        return false
    end
    pcall(function()
        vim.wo[win].winhighlight = "Normal:StatusLine" -- read as a bar
    end)
    _s = { buf = buf, win = win, tick = 0, start = os.time(), message = message or "working…" }
    render()
    _s.timer = vim.loop.new_timer()
    _s.timer:start(120, 120, vim.schedule_wrap(function()
        if not _s then
            return
        end
        _s.tick = _s.tick + 1
        render()
    end))
    return true
end

--- Update the bar's message (no-op if not active).
--- @param message string
function M.update(message)
    if _s then
        _s.message = message
        render()
    end
end

--- Stop + tear down the bar (idempotent).
function M.stop()
    if not _s then
        return
    end
    if _s.timer then
        pcall(function()
            _s.timer:stop()
            _s.timer:close()
        end)
    end
    pcall(vim.api.nvim_win_close, _s.win, true)
    _s = nil
end

--- Is a progress bar currently shown?
--- @return boolean
function M.is_active()
    return _s ~= nil
end

return M
