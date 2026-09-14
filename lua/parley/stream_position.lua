-- Shared query coordinates for streaming and completion. Rows are one-based;
-- columns are byte offsets, matching nvim_win_set_cursor.
local M = {}

function M.from_query(qt)
    if not qt then
        return nil
    end
    if type(qt.last_line) == "number" and qt.last_line >= 0 then
        return { qt.last_line + 1, qt.last_col or 0 }
    end
    if type(qt.first_line) == "number" and qt.first_line >= 0 then
        return { qt.first_line + 1, 0 }
    end
    return nil
end

return M
