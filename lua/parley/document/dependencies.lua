-- Channel-partitioned conservative dependencies. Stable handles remain the
-- position authority; no suffix coordinate sweep follows an edit.
local M = {}
local Index = {}
Index.__index = Index
local CHANNELS = require("parley.document.grammar").CHANNELS
local allowed = {}
for _, name in ipairs(CHANNELS) do allowed[name] = true end
local BUDGET = { status = "budget" }
local function height(node) return node and node.height or 0 end
local function count(node) return node and node.count or 0 end

local function selected(channels, legacy)
    local out, seen = {}, {}
    if legacy then out[1], seen["*"] = "*", true end
    if channels == nil then
        if not legacy then return { "*" } end
        for _, name in ipairs(CHANNELS) do out[#out + 1] = name end
    else
        for key, value in pairs(channels) do
            local name = type(key) == "number" and value or key
            if type(key) == "number" or value then
                assert(allowed[name], "unknown dependency channel: " .. tostring(name))
                seen[name] = true
            end
        end
        for _, name in ipairs(CHANNELS) do if seen[name] then out[#out + 1] = name end end
    end
    return out
end

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
            local admitted=opts and opts.before_rank and opts.before_rank(handle)
            if opts and opts.before_rank and not admitted then error(BUDGET, 0) end
            local reason
            value,reason = self.adapter(handle,type(admitted)=="table" and admitted or nil)
            if reason=="budget" then error(BUDGET,0) end
            if value == nil then error({ status = "stale", handle = handle }, 0) end
            assert(type(value) == "number" and value == value, "rank must return a number or nil")
            ranks[handle] = value
        end
        return value
    end
    context.adapter = index.rank
    local success, result = pcall(fn, context)
    if not success then
        if type(result) ~= "table" or (result.status ~= "budget" and result.status ~= "stale") then error(result, 0) end
        result = { status = result.status, handle = result.handle }
    else result.status = "ok" end
    result.work = { dependency_nodes_visited = visited }
    return result
end

local function make(ctx, origin, first, last, left, right)
    ctx:visit(left); ctx:visit(right)
    local farthest, nearest = last, first
    if left then
        if ctx:rank(left.farthest) > ctx:rank(farthest) then farthest = left.farthest end
        if ctx:rank(left.nearest) < ctx:rank(nearest) then nearest = left.nearest end
    end
    if right then
        if ctx:rank(right.farthest) > ctx:rank(farthest) then farthest = right.farthest end
        if ctx:rank(right.nearest) < ctx:rank(nearest) then nearest = right.nearest end
    end
    return { origin = origin, first = first, last = last, farthest = farthest, nearest = nearest,
        left = left, right = right, height = 1 + math.max(height(left), height(right)),
        count = 1 + count(left) + count(right) }
end
local function rotate_left(ctx, node)
    local pivot = node.right; ctx:visit(pivot)
    local left = make(ctx, node.origin, node.first, node.last, node.left, pivot.left)
    return make(ctx, pivot.origin, pivot.first, pivot.last, left, pivot.right)
end
local function rotate_right(ctx, node)
    local pivot = node.left; ctx:visit(pivot)
    local right = make(ctx, node.origin, node.first, node.last, pivot.right, node.right)
    return make(ctx, pivot.origin, pivot.first, pivot.last, pivot.left, right)
end
local function balance(ctx, origin, first, last, left, right)
    local node = make(ctx, origin, first, last, left, right)
    if height(left) > height(right) + 1 then
        if height(left.right) > height(left.left) then
            node = make(ctx, origin, first, last, rotate_left(ctx, left), right)
        end
        return rotate_right(ctx, node)
    elseif height(right) > height(left) + 1 then
        if height(right.left) > height(right.right) then
            node = make(ctx, origin, first, last, left, rotate_right(ctx, right))
        end
        return rotate_left(ctx, node)
    end
    return node
end
local function insert(ctx, node, origin, first, last, position)
    if not node then ctx:visit(true); return make(ctx, origin, first, last) end
    ctx:visit(node)
    local current = ctx:rank(node.origin)
    if position < current then
        return balance(ctx, node.origin, node.first, node.last,
            insert(ctx, node.left, origin, first, last, position), node.right)
    elseif position > current then
        return balance(ctx, node.origin, node.first, node.last, node.left,
            insert(ctx, node.right, origin, first, last, position))
    end
    -- Separate channel roots keep unrelated predicates apart. Duplicate origins
    -- within one channel widen coverage conservatively, including any gap.
    if ctx:rank(first) >= ctx:rank(node.first) then first = node.first end
    if ctx:rank(last) <= ctx:rank(node.last) then last = node.last end
    if first == node.first and last == node.last then return node end
    return make(ctx, node.origin, first, last, node.left, node.right)
end
local function join(ctx, left, origin, first, last, right)
    if height(left) > height(right) + 1 then
        ctx:visit(left)
        return balance(ctx, left.origin, left.first, left.last, left.left,
            join(ctx, left.right, origin, first, last, right))
    elseif height(right) > height(left) + 1 then
        ctx:visit(right)
        return balance(ctx, right.origin, right.first, right.last,
            join(ctx, left, origin, first, last, right.left), right.right)
    end
    return make(ctx, origin, first, last, left, right)
end
local function prefix(ctx, node, position)
    if not node then return nil end
    ctx:visit(node)
    if ctx:rank(node.origin) >= position then return prefix(ctx, node.left, position) end
    return join(ctx, node.left, node.origin, node.first, node.last, prefix(ctx, node.right, position))
end
local function earliest(ctx, node, first, last)
    if not node then return nil end
    ctx:visit(node)
    if ctx:rank(node.farthest) < first or ctx:rank(node.nearest) > last then return nil end
    local position = ctx:rank(node.origin)
    if position > last then return earliest(ctx, node.left, first, last) end
    local hit = earliest(ctx, node.left, first, last)
    if hit then return hit end
    if ctx:rank(node.first) <= last and ctx:rank(node.last) >= first then return node.origin end
    return earliest(ctx, node.right, first, last)
end
function M.new(adapter)
    assert(type(adapter) == "table" and type(adapter.rank) == "function", "rank adapter required")
    return setmetatable({ rank = adapter.rank, roots = {} }, Index)
end
function Index:add(origin, last, opts)
    opts = opts or {}
    return operation(self, opts, function(ctx)
        local position, first = ctx:rank(origin), opts.first or origin
        assert(position <= ctx:rank(first) and ctx:rank(first) <= ctx:rank(last), "unordered dependency bounds")
        local roots = {}
        for key, root in pairs(self.roots) do roots[key] = root end
        for _, channel in ipairs(selected(opts.channels, false)) do
            roots[channel] = insert(ctx, roots[channel], origin, first, last, position)
        end
        self.roots = roots
        return {}
    end)
end
--- Retire all suffix records atomically across the fixed channel forest.
function Index:remove_from(origin, opts)
    return operation(self, opts, function(ctx)
        local roots, removed, position = {}, 0, ctx:rank(origin)
        for _, channel in ipairs(selected(nil, true)) do
            local root = prefix(ctx, self.roots[channel], position)
            roots[channel] = root
            removed = removed + count(self.roots[channel]) - count(root)
        end
        self.roots = roots
        return { removed = removed }
    end)
end
--- Aligned trigger/origin intervals retain the ordinary logarithmic descent.
--- Arbitrary nonmonotonic triggers can exhaust the explicit node budget; no
--- universal logarithmic bound is claimed for that more general case.
function Index:restart_origin(first, last, opts)
    assert(type(first) == "number" and type(last) == "number" and first <= last, "ordered edit range required")
    return operation(self, opts, function(ctx)
        local origin
        for _, channel in ipairs(selected(opts and opts.channels, true)) do
            local hit = earliest(ctx, self.roots[channel], first, last)
            if hit and (not origin or ctx:rank(hit) < ctx:rank(origin)) then origin = hit end
        end
        return { origin = origin }
    end)
end
return M
