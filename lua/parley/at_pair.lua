local M = {}

-- byte_column is the insertion offset (zero-based); tokens are line-local.
function M.keys(line, byte_column)
    local before, after = line:sub(1, byte_column), line:sub(byte_column + 1)
    local _, delimiters = before:gsub("@@", "")
    if delimiters % 2 == 1 and after:sub(1, 1) == "@" then
        return "<C-g>U<Right>"
    end
    local trailing = before:match("@+$") or ""
    if delimiters % 2 == 0 and #trailing % 2 == 1 then
        if after:sub(1, 2) == "@@" then return "@" end
        return "@@@<C-g>U<Left><C-g>U<Left>"
    end
    return "@"
end

return M
