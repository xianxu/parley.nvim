-- parley.window_views — keep every window's cursor and top line on its text
-- across a rewrite of the whole buffer (#356, #358).
--
-- A partial edit keeps Neovim's own cursor adjustment; a reload or a
-- whole-buffer replace keeps only line NUMBERS, so an edit above moved the
-- operator. capture() before the rewrite, restore() after it: each view is
-- mapped through the diff of the two texts by the pure `view_map`.

local M = {}

--- Every window's view of `buf`, with the text it was taken against.
---@param buf integer
---@return table snap { lines, wins = {[win] = view} }
function M.capture(buf)
    local snap = { lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false), wins = {} }
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        snap.wins[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
    return snap
end

--- Put each captured window's cursor and top line back on the text they showed.
---@param buf integer
---@param snap table from capture(buf)
function M.restore(buf, snap)
    local view_map = require("parley.view_map")
    local new = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local hs = view_map.hunks(snap.lines, new)
    for win, view in pairs(snap.wins) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
            local pos = view_map.map(snap.lines, new, { view.lnum, view.col }, hs)
            -- curswant is a virtual column ($-sticky as MAXCOL): kept while the
            -- column is, re-derived from the screen when the text moved it.
            local moved = pos[2] ~= view.col
            view.lnum, view.col = pos[1], pos[2]
            if moved then view.curswant = nil end
            view.topline = view_map.map_line(snap.lines, new, view.topline, hs)
            vim.api.nvim_win_call(win, function()
                vim.fn.winrestview(view)
                if moved then vim.fn.winrestview({ curswant = vim.fn.virtcol(".") - 1 }) end
            end)
        end
    end
end

return M
