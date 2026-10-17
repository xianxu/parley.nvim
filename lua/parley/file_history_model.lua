local M = {}

local DEFAULT_LIMIT = 200

local function copy_cursor(cursor)
    return { row = cursor.row, col = cursor.col }
end

local function copy_trail(trail)
    if not trail then return nil end
    local paths = {}
    for i, path in ipairs(trail.paths) do paths[i] = path end
    return { version = trail.version, paths = paths, omitted = trail.omitted }
end

local function make_entry(path, cursor, trail)
    local entry = { path = path, cursor = copy_cursor(cursor) }
    if trail then entry.trail = copy_trail(trail) end
    return entry
end

local function copy_entry(entry)
    return make_entry(entry.path, entry.cursor, entry.trail)
end

local function copy_entries(entries, last_index)
    local result = {}
    for index = 1, last_index do
        result[index] = copy_entry(entries[index])
    end
    return result
end

function M.transition(history, event, limit)
    limit = limit or DEFAULT_LIMIT
    local entries = history and history.entries or {}
    local index = history and history.index or 0

    if event.kind == "visit" then
        local current = entries[index]
        if current and current.path == event.path then
            local updated = copy_entries(entries, #entries)
            updated[index] = make_entry(event.path, event.cursor, event.trail or current.trail)
            return { entries = updated, index = index }
        end

        local retained = current and index or #entries
        local updated = copy_entries(entries, retained)
        updated[#updated + 1] = make_entry(event.path, event.cursor, event.trail)
        local next_index = #updated

        while #updated > limit do
            table.remove(updated, 1)
            next_index = next_index - 1
        end

        return { entries = updated, index = next_index }
    end

    if event.kind == "snapshot" then
        local current = entries[index]
        if not current or current.path ~= event.path then
            return history
        end

        local updated = copy_entries(entries, #entries)
        updated[index] = make_entry(current.path, event.cursor, event.trail or current.trail)
        return { entries = updated, index = index }
    end

    if event.kind == "back" then
        local current = entries[index]
        if not current then return history, nil end

        for candidate = index - 1, 1, -1 do
            if entries[candidate].path ~= current.path then
                return { entries = copy_entries(entries, #entries), index = candidate }, copy_entry(entries[candidate])
            end
        end
        return history, nil
    end

    return history
end

-- Replace the provisional current visit with a coherent ancestry chain. Only
-- contiguous ordered overlap counts: repeated paths are meaningful visits.
function M.install_trail(history, trail, cursors, limit)
    limit = limit or DEFAULT_LIMIT
    local entries = history and history.entries or {}
    local retained = history and math.max(0, history.index - 1) or 0
    local overlap = 0
    for count = math.min(retained, #trail.paths), 1, -1 do
        local matches = true
        for i = 1, count do
            if entries[retained - count + i].path ~= trail.paths[i] then
                matches = false
                break
            end
        end
        if matches then overlap = count; break end
    end
    local result = copy_entries(entries, retained - overlap)
    local prefix = {}
    for i, path in ipairs(trail.paths) do
        prefix[i] = path
        local previous = i <= overlap and entries[retained - overlap + i] or nil
        local cursor = cursors and cursors[i] or previous and previous.cursor or { row = 1, col = 0 }
        result[#result + 1] = make_entry(path, cursor, {
            version = trail.version, paths = prefix, omitted = i == 1 and 0 or trail.omitted,
        })
    end
    while #result > limit do table.remove(result, 1) end
    return { entries = result, index = #result }
end

return M
