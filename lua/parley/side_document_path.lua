-- A side file's owning folder and its immediate attachment are different facts.
-- Pure path/header projection; callers own realpath checks and Couch admission.
local M = {}
local Move = require("parley.document_move_plan")
local Tree = require("parley.side_tree_model")

local function normalized(path)
    if type(path) ~= "string" or path:sub(1, 1) ~= "/" or path:find("[%z\1-\31\127]") then return nil end
    return vim.fs.normalize(path)
end

function M.month(name)
    local month = name:match("^%d%d%d%d%-(%d%d)$")
    return month ~= nil and tonumber(month) >= 1 and tonumber(month) <= 12
end

-- Only the current flat/one-month layout. Historical nested roots are handled
-- by the exact direct-parent compatibility check in relation, never inferred.
function M.member(path)
    path = normalized(path)
    if not path then return nil end
    local root, tail = path:match("^(.-%.side)/(.+)$")
    if not root or root:find("%.side/") then return nil end
    if tail:match("^[^/]+%.md$") then return root end
    local month, file = tail:match("^([^/]+)/([^/]+%.md)$")
    if file and M.month(month) then return root end
end

function M.root(path)
    path = normalized(path)
    if not path then return nil end
    local member = M.member(path)
    if member then return member end
    if path:find("%.side/") then return nil end
    return Move.side_path(path)
end

-- `parent:` resolves from the actual child directory, including ../month/file.
-- No header means no attachment evidence; only relation's legacy direct case
-- can use that compatibility fallback.
function M.parent(child, lines)
    child = normalized(child)
    if not child then return nil end
    return Tree.parse(lines, vim.fs.dirname(child)).parent
end

function M.relation(child, parent, lines)
    child, parent = normalized(child), normalized(parent)
    if not child or not parent or child == parent then return false end
    local declared = M.parent(child, lines)
    local direct = vim.fs.dirname(child) == Move.side_path(parent)
    if direct then
        -- Preserve handwritten flat/nested documents. An explicit header is
        -- evidence, so unreadable or contradictory headers never use fallback.
        if not (lines[1] or ""):match("^%s*%-%-%-%s*$") then return true end
        return declared == parent
    end
    return declared == parent and M.member(child) ~= nil and M.member(child) == M.root(parent)
end

return M
