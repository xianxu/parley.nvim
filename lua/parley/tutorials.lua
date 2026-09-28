-- Canonical stable tutorial names, in reading order. No filesystem discovery:
-- personal chats in the source directory must never become packaged lessons.
local M = { names = { 'welcome', 'basics', 'advanced', 'vim-basics' } }
M.filenames = {}
local known = {}
for _, name in ipairs(M.names) do
    local filename = name .. '.md'
    M.filenames[#M.filenames + 1] = filename
    known[filename] = true
end
function M.contains(filename)
    return known[filename] == true
end
return M
