local M = {}

local MAX_PATHS, MAX_BYTES = 200, 1024 * 1024
local MARKERS = { missing = "?", cycle = "↻", depth = "…" }

local function path_ok(path)
    return type(path) == "string" and path:sub(1, 1) == "/" and not path:find("[%z\1-\31\127]")
end

function M.validate(value, final_path)
    if type(value) ~= "table" or value.version ~= 1 or type(value.paths) ~= "table"
        or type(value.omitted) ~= "number" or value.omitted < 0 or value.omitted == math.huge
        or value.omitted % 1 ~= 0 then
        return nil, "invalid breadcrumb value"
    end
    local paths, count, bytes = {}, 0, 0
    for key, path in pairs(value.paths) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > MAX_PATHS or not path_ok(path) then
            return nil, "invalid breadcrumb path"
        end
        count = count + 1
        bytes = bytes + #path
        paths[key] = path
    end
    if count == 0 or bytes > MAX_BYTES then return nil, "breadcrumb exceeds bounds" end
    for i = 1, count do
        if paths[i] == nil then return nil, "breadcrumb paths must be dense" end
    end
    if final_path and paths[count] ~= final_path then return nil, "breadcrumb target mismatch" end
    return { version = 1, paths = paths, omitted = value.omitted }
end

function M.transition(value, event)
    if type(event) ~= "table" or not path_ok(event.path) or #event.path > MAX_BYTES then
        return nil, "invalid breadcrumb event path"
    end
    if event.kind == "root" or not value then
        return { version = 1, paths = { event.path }, omitted = 0 }
    end
    if event.kind ~= "follow" then return nil, "invalid breadcrumb event" end
    local result, reason = M.validate(value)
    if not result then return nil, reason end
    if result.paths[#result.paths] == event.path then return result end
    result.paths[#result.paths + 1] = event.path
    local bytes = 0
    for _, path in ipairs(result.paths) do bytes = bytes + #path end
    while #result.paths > MAX_PATHS or bytes > MAX_BYTES do
        if #result.paths <= 2 then return nil, "breadcrumb root and leaf exceed bounds" end
        bytes = bytes - #table.remove(result.paths, 2)
        result.omitted = result.omitted + 1
    end
    return result
end

local function parts(path)
    local result = {}
    for part in path:gmatch("[^/]+") do result[#result + 1] = part end
    if #result == 0 then return { "/" } end
    result[#result] = result[#result]:gsub("%.md$", ""):gsub("^%d%d%d%d%-%d%d%-%d%d%-", "")
    return result
end

local function labels_for(paths)
    local components, depths, labels = {}, {}, {}
    for i, path in ipairs(paths) do components[i], depths[i] = parts(path), 1 end
    while true do
        for i, components_i in ipairs(components) do
            labels[i] = table.concat(components_i, "/", math.max(1, #components_i - depths[i] + 1))
        end
        local grow = {}
        for i = 1, #paths do
            for j = i + 1, #paths do
                if paths[i] ~= paths[j] and labels[i] == labels[j] then
                    if depths[i] < #components[i] then grow[i] = true end
                    if depths[j] < #components[j] then grow[j] = true end
                end
            end
        end
        if next(grow) == nil then
            -- Stripping a date/suffix can erase the only distinguishing bytes,
            -- even after every parent component has been included. Preserve
            -- identity for that collision family with the original paths.
            local raw = {}
            for i = 1, #paths do
                for j = i + 1, #paths do
                    if paths[i] ~= paths[j] and labels[i] == labels[j] then
                        raw[i], raw[j] = true, true
                    end
                end
            end
            for i in pairs(raw) do labels[i] = paths[i] end
            return labels
        end
        for i in pairs(grow) do depths[i] = depths[i] + 1 end
    end
end

local function shorten(text, budget, ops, from_end)
    if ops.width(text) <= budget then return text end
    if budget <= 0 then return "" end
    local ellipsis = "…"
    if ops.width(ellipsis) > budget then return "" end
    local units, kept, width = ops.units(text), {}, ops.width(ellipsis)
    if from_end then
        for i = #units, 1, -1 do
            local size = ops.width(units[i])
            if width + size > budget then break end
            table.insert(kept, 1, units[i])
            width = width + size
        end
        return ellipsis .. table.concat(kept)
    end
    for _, unit in ipairs(units) do
        local size = ops.width(unit)
        if width + size > budget then break end
        kept[#kept + 1], width = unit, width + size
    end
    return table.concat(kept) .. ellipsis
end

-- Reserve a readable fragment of every protected segment before giving the
-- leaf its full width and distributing the rest across its ancestors. Interior
-- gaps are fixed markers; shortening labels must not silently remove a parent.
local function fit_protected(labels, budget, ops)
    local available = budget - ops.width(" › ") * (#labels - 1)
    local widths, limits, remaining = {}, {}, available
    for i, label in ipairs(labels) do
        local units = ops.units(label)
        local edge = i == #labels and units[#units] or units[1]
        limits[i] = ops.width(label)
        widths[i] = math.min(limits[i], ops.width(edge or "") + ops.width("…"))
        remaining = remaining - widths[i]
    end
    if remaining < 0 then return nil end
    local leaf = #labels
    local growth = math.min(remaining, limits[leaf] - widths[leaf])
    widths[leaf], remaining = widths[leaf] + growth, remaining - growth
    while remaining > 0 do
        local grew = false
        for i = 1, leaf - 1 do
            if remaining > 0 and widths[i] < limits[i] then
                widths[i], remaining, grew = widths[i] + 1, remaining - 1, true
            end
        end
        if not grew then break end
    end
    local result = {}
    for i, label in ipairs(labels) do result[i] = shorten(label, widths[i], ops, i == leaf) end
    return table.concat(result, " › ")
end

-- A file outside any side-doc tree shows its own path (#391): one segment per
-- directory below `base`, led by `prefix` (e.g. "~") when given.
function M.path_value(path, base, prefix)
    local relative = base ~= "/" and path:sub(1, #base + 1) == base .. "/" and path:sub(#base + 2) or path
    local labels = prefix and { prefix } or {}
    local segments = parts("/" .. relative)
    for _, segment in ipairs(segments) do labels[#labels + 1] = segment end
    return { version = 1, paths = { path }, omitted = 0, labels = labels }
end

-- A lone navigation root shows nothing; tree paths with a marker and file
-- paths always show.
function M.visible(value)
    return value ~= nil and (value.labels ~= nil or #value.paths > 1 or value.marker ~= nil)
end

function M.project(value, budget, ops)
    budget = math.max(0, math.floor(budget))
    if budget == 0 or not M.visible(value) then return "" end
    local labels = value.labels and { unpack(value.labels) } or labels_for(value.paths)
    -- A side-doc tree path that stopped early leads with why (#391).
    if value.marker then table.insert(labels, 1, MARKERS[value.marker] or "?") end
    local display = {}
    for i, label in ipairs(labels) do
        display[#display + 1] = label
        if i == 1 and value.omitted > 0 then display[#display + 1] = "…" end
    end
    local full = table.concat(display, " › ")
    if ops.width(full) <= budget then return full end
    local compact = #labels > 3 and { labels[1], "…", labels[#labels - 1], labels[#labels] } or display
    local collapsed = table.concat(compact, " › ")
    if ops.width(collapsed) <= budget then return collapsed end
    local protected = fit_protected(compact, budget, ops)
    if protected then return protected end
    -- The leaf is the useful identity when separators alone would consume the
    -- space. A leading ellipsis also makes the missing ancestry explicit.
    local leaf = labels[#labels]
    if budget <= ops.width(leaf) + 1 then
        return shorten("…" .. leaf, budget, ops, true)
    end
    local separator_width = ops.width(" › ")
    local available = budget - separator_width * 2
    if available >= 3 then
        local leaf_budget = math.min(ops.width(leaf), math.max(1, math.floor(available / 2)))
        local root_budget = math.max(1, available - leaf_budget - 1)
        local result = shorten(labels[1], root_budget, ops) .. " › … › " .. shorten(leaf, leaf_budget, ops, true)
        if ops.width(result) <= budget then return result end
    end
    return shorten("…" .. leaf, budget, ops, true)
end

return M
