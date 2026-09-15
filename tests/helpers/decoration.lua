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

return M
