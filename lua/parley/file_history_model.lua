local M = {}

local DEFAULT_LIMIT = 200

local function copy_cursor(cursor)
    return { row = cursor.row, col = cursor.col }
end

local function make_entry(path, cursor)
    return { path = path, cursor = copy_cursor(cursor) }
end

local function copy_entry(entry)
    return make_entry(entry.path, entry.cursor)
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
            updated[index] = make_entry(event.path, event.cursor)
            return { entries = updated, index = index }
        end

        local retained = current and index or #entries
        local updated = copy_entries(entries, retained)
        updated[#updated + 1] = make_entry(event.path, event.cursor)
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
        updated[index] = make_entry(current.path, event.cursor)
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

return M
