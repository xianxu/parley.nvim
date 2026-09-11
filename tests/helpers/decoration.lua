-- Decoration-provider fixtures shared by the highlighting specs.
local M = {}

--- The provider `setup_buf_handler` registers, captured without installing it.
function M.capture_provider(parley)
    local original = vim.api.nvim_set_decoration_provider
    local captured
    vim.api.nvim_set_decoration_provider = function(_, provider) captured = provider end
    local ok, err = pcall(parley.setup_buf_handler)
    vim.api.nvim_set_decoration_provider = original
    assert(ok, err)
    return captured
end

--- One redraw frame over rows [top, bot]: `false` when on_win declined to draw,
--- else every extmark on_line placed, as { row, col, end_col, hl_group }.
function M.frame(provider, win, buf, top, bot)
    if provider.on_win(nil, win, buf, top, bot) == false then
        return false
    end
    local drawn = {}
    local original = vim.api.nvim_buf_set_extmark
    vim.api.nvim_buf_set_extmark = function(_, _, row, col, opts)
        drawn[#drawn + 1] = { row = row, col = col, end_col = opts.end_col, hl_group = opts.hl_group }
        return 1
    end
    local ok, err = pcall(function()
        for row = top, bot do provider.on_line(nil, win, buf, row) end
    end)
    vim.api.nvim_buf_set_extmark = original
    assert(ok, err)
    return drawn
end

function M.has(drawn, row, hl_group)
    for _, mark in ipairs(drawn or {}) do
        if mark.row == row and mark.hl_group == hl_group then return true end
    end
    return false
end

--- Structure-repair deferrals the test fires by hand (#227), for
--- `highlighter._set_repair_deferral(log.factory)`: arm / restart / cancel
--- ordering is then constructed rather than sampled from a real clock.
function M.manual_deferrals()
    local log = { starts = 0, all = {} }
    function log.factory()
        local d = { pending = nil, closed = false }
        function d:start(_, fn)
            log.starts = log.starts + 1
            self.pending = fn
        end
        function d:stop() self.pending = nil end
        function d:close()
            self.closed = true
            self.pending = nil
        end
        log.all[#log.all + 1] = d
        return d
    end
    function log.pending()
        local n = 0
        for _, d in ipairs(log.all) do
            if d.pending then n = n + 1 end
        end
        return n
    end
    function log.fire()
        local fired = 0
        for _, d in ipairs(log.all) do
            local fn = d.pending
            d.pending = nil
            if fn then
                fired = fired + 1
                fn()
            end
        end
        return fired
    end
    return log
end

return M
