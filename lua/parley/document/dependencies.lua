-- Conservative origin-to-witness dependencies. Stable handles are the only
-- position authority; the injected rank adapter resolves them in the live root.
local M = {}
local Index = {}
Index.__index = Index

local BUDGET = { status = "budget" }
local function height(node) return node and node.height or 0 end
local function count(node) return node and node.count or 0 end

local function operation(index, opts, fn)
    local limit = opts and opts.budget or 512
    assert(type(limit) == "number" and limit >= 0 and limit % 1 == 0, "budget must be a nonnegative integer")
    local visited, ranks = 0, {}
    local context = {}
    function context.visit(_, node)
        if not node then return end
        if visited >= limit then error(BUDGET, 0) end
        visited = visited + 1
    end
    function context:rank(handle)
        local value = ranks[handle]
        if value == nil then
            value = self.adapter(handle)
            if value == nil then error({ status = "stale", handle = handle }, 0) end
            assert(type(value) == "number" and value == value, "rank must return a number or nil")
            ranks[handle] = value
        end
        return value
    end
    context.adapter = index.rank
    local success, result = pcall(fn, context)
    if not success then
        if type(result) ~= "table" or (result.status ~= "budget" and result.status ~= "stale") then
            error(result, 0)
        end
        result = { status = result.status, handle = result.handle }
    else
        result.status = "ok"
    end
    result.work = { dependency_nodes_visited = visited }
    return result
end

-- Each rebuilt node inspects two child summaries; rotations inspect their
-- pivots too. These visits count even when a candidate root is not published.
local function make(ctx, origin, last, left, right)
    ctx:visit(left)
    ctx:visit(right)
    local farthest = last
    if left and ctx:rank(left.farthest) > ctx:rank(farthest) then farthest = left.farthest end
    if right and ctx:rank(right.farthest) > ctx:rank(farthest) then farthest = right.farthest end
    return {
        origin = origin, last = last, farthest = farthest, left = left, right = right,
        height = 1 + math.max(height(left), height(right)), count = 1 + count(left) + count(right),
    }
end

local function rotate_left(ctx, node)
    local pivot = node.right
    ctx:visit(pivot)
    local left = make(ctx, node.origin, node.last, node.left, pivot.left)
    return make(ctx, pivot.origin, pivot.last, left, pivot.right)
end

local function rotate_right(ctx, node)
    local pivot = node.left
    ctx:visit(pivot)
    local right = make(ctx, node.origin, node.last, pivot.right, node.right)
    return make(ctx, pivot.origin, pivot.last, pivot.left, right)
end

local function balance(ctx, origin, last, left, right)
    local node = make(ctx, origin, last, left, right)
    if height(left) > height(right) + 1 then
        if height(left.right) > height(left.left) then
            node = make(ctx, origin, last, rotate_left(ctx, left), right)
        end
        return rotate_right(ctx, node)
    elseif height(right) > height(left) + 1 then
        if height(right.left) > height(right.right) then
            node = make(ctx, origin, last, left, rotate_right(ctx, right))
        end
        return rotate_left(ctx, node)
    end
    return node
end

local function insert(ctx, node, origin, last, position)
    if not node then
        -- Allocating a leaf is work even in an empty index.
        ctx:visit(true)
        return make(ctx, origin, last)
    end
    ctx:visit(node)
    local current = ctx:rank(node.origin)
    if position < current then
        return balance(ctx, node.origin, node.last, insert(ctx, node.left, origin, last, position), node.right)
    elseif position > current then
        return balance(ctx, node.origin, node.last, node.left, insert(ctx, node.right, origin, last, position))
    end
    -- Coverage with the same start is a single interval. Keep its widest end.
    if ctx:rank(last) <= ctx:rank(node.last) then return node end
    return make(ctx, node.origin, last, node.left, node.right)
end

-- Join supports arbitrary height differences after a whole suffix detaches.
local function join(ctx, left, origin, last, right)
    if height(left) > height(right) + 1 then
        ctx:visit(left)
        return balance(ctx, left.origin, left.last, left.left, join(ctx, left.right, origin, last, right))
    elseif height(right) > height(left) + 1 then
        ctx:visit(right)
        return balance(ctx, right.origin, right.last, join(ctx, left, origin, last, right.left), right.right)
    end
    return make(ctx, origin, last, left, right)
end

local function prefix(ctx, node, position)
    if not node then return nil end
    ctx:visit(node)
    if ctx:rank(node.origin) >= position then return prefix(ctx, node.left, position) end
    return join(ctx, node.left, node.origin, node.last, prefix(ctx, node.right, position))
end

local function earliest(ctx, node, first, last)
    if not node then return nil end
    ctx:visit(node)
    if ctx:rank(node.farthest) < first then return nil end
    local position = ctx:rank(node.origin)
    if position > last then return earliest(ctx, node.left, first, last) end
    -- Every origin in the left subtree is already within the upper bound.
    -- A subtree whose maximum end reaches first therefore contains a match.
    local hit = earliest(ctx, node.left, first, last)
    if hit then return hit end
    if ctx:rank(node.last) >= first then return node.origin end
    return earliest(ctx, node.right, first, last)
end

function M.new(adapter)
    assert(type(adapter) == "table" and type(adapter.rank) == "function", "rank adapter required")
    return setmetatable({ rank = adapter.rank }, Index)
end

--- Add inclusive coverage. Equal origin coordinates coalesce to the widest end.
--- Candidate roots are immutable until success, including on budget exhaustion.
function Index:add(origin, last, opts)
    return operation(self, opts, function(ctx)
        local first = ctx:rank(origin)
        assert(first <= ctx:rank(last), "dependency end precedes origin")
        local root = insert(ctx, self.root, origin, last, first)
        self.root = root
        return {}
    end)
end

--- Retire every origin at/after this live handle without visiting its subtree.
--- Call before the text splice; retained endpoint membership must remain valid.
function Index:remove_from(origin, opts)
    return operation(self, opts, function(ctx)
        local root = prefix(ctx, self.root, ctx:rank(origin))
        local removed = count(self.root) - count(root)
        self.root = root
        return { removed = removed }
    end)
end

--- Query an inclusive numeric range in PRE-splice coordinates. Point insertions
--- and EOF boundaries intentionally overlap certificates ending at that point.
function Index:restart_origin(first, last, opts)
    assert(type(first) == "number" and type(last) == "number" and first <= last, "ordered edit range required")
    return operation(self, opts, function(ctx)
        return { origin = earliest(ctx, self.root, first, last) }
    end)
end

return M
