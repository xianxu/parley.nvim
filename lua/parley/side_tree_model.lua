-- A side doc's place in its tree: the `parent:` chain from root to leaf (#391).
-- Pure; `read(path)` supplies `{ parent = abs|nil, tree = bool }`, or nil when
-- the file cannot be read. `cap` bounds the ancestors kept, nearest first.
local M = {}

M.CAP = 32

-- nil means the leaf is outside every side-doc tree and keeps its trail.
function M.chain(leaf, read, cap)
    cap = cap or M.CAP
    local node = read(leaf)
    if not node or (not node.parent and not node.tree) then return nil end
    local reversed, seen, marker = { leaf }, { [leaf] = true }, nil
    while node.parent do
        local parent = node.parent
        if seen[parent] then marker = "cycle" break end
        if #reversed > cap then marker = "depth" break end
        node = read(parent)
        if not node then marker = "missing" break end
        reversed[#reversed + 1], seen[parent] = parent, true
    end
    local paths = {}
    for i = #reversed, 1, -1 do paths[#paths + 1] = reversed[i] end
    return { version = 1, paths = paths, omitted = 0, marker = marker }
end

return M
