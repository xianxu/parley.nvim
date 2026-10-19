-- parley.attention_rows — the attention finder's rows (#354). Pure: model
-- scoped/sorted entries become preorder forest items; each row is
-- highlighted whole in its state's group.

local Model = require("parley.attention_model")

local M = {}

M.GROUPS = {
    waiting = "ParleyAttentionWaiting",
    answered = "ParleyAttentionAnswered",
    seen = "ParleyAttentionSeen",
}

local function dirname(path)
    return path:match("^(.*)/[^/]*$") or "."
end

local function basename(path)
    return path:match("([^/]*)$")
end

-- One ordered forest from already scoped/sorted entries. Cyclic components
-- have no root: follow parents to a cycle member, breaking only a cycle edge.
local function tree(entries)
    local by_path, parents, children, roots, result, seen = {}, {}, {}, {}, {}, {}
    for _, entry in ipairs(entries) do by_path[entry.path] = entry end
    for _, entry in ipairs(entries) do
        local parent = entry.kind == "side" and by_path[entry.parent]
        parents[entry.path] = parent
        if parent then
            children[parent.path] = children[parent.path] or {}
            table.insert(children[parent.path], entry)
        else roots[#roots + 1] = entry end
    end
    local function visit(entry, depth, parent)
        if seen[entry.path] then return end
        seen[entry.path] = true
        result[#result + 1] = { entry = entry, depth = depth, parent = parent }
        for _, child in ipairs(children[entry.path] or {}) do visit(child, depth + 1, entry.path) end
    end
    for _, entry in ipairs(roots) do visit(entry, 0) end
    for _, entry in ipairs(entries) do
        if not seen[entry.path] then
            local cursor, walked = entry, {}
            while not walked[cursor.path] do
                walked[cursor.path] = true
                cursor = parents[cursor.path]
            end
            visit(cursor, 0)
        end
    end
    return result
end

--- Matching rows plus ancestor context, in the original forest order.
--- `score(query, text)` is the picker's existing scorer; no duplicate grammar.
function M.filter(items, query, score)
    if query == "" then return items end
    local by_value, keep, result = {}, {}, {}
    for _, item in ipairs(items) do by_value[item.value] = item end
    for _, item in ipairs(items) do
        if score(query, item.search_text or item.display) then
            local cursor = item
            while cursor and not keep[cursor.value] do
                keep[cursor.value] = true
                cursor = by_value[cursor.parent_value]
            end
        end
    end
    for _, item in ipairs(items) do if keep[item.value] then result[#result + 1] = item end end
    return result
end

--- `entries` as float_picker items: `<state> <marker> <name>  <dir>  <HH:MM>`.
--- The marker is `?` for an entry whose last probe failed, `↳` for a side doc
--- the agent wrote (searchable by its parent's name). options: { home, clock }
--- where clock(seconds) formats a submit time (os.date by default).
--- Returns the unchanged rows and oldest-unread index (1 when none).
function M.items(entries, options)
    options = options or {}
    local home = options.home
    local clock = options.clock or function(t) return os.date("%H:%M", t) end
    local items, initial, oldest = {}, 1, nil
    for _, node in ipairs(tree(entries)) do
        local entry = node.entry
        local state = Model.state_of(entry)
        local answered = entry.answered_at or entry.submitted_at
        if state == "answered" and (not oldest or answered < oldest) then
            initial, oldest = #items + 1, answered
        end
        local dir = dirname(entry.path)
        local shown = dir
        if home and home ~= "" and (dir == home or dir:sub(1, #home + 1) == home .. "/") then
            shown = "~" .. dir:sub(#home + 1)
        end
        local marker = entry.unknown and "?" or (entry.kind == "side" and "↳" or " ")
        local display = string.rep("  ", node.depth) .. ("%-8s %s %s  %s  %s"):format(state, marker,
            basename(entry.path), shown, clock(entry.submitted_at))
        items[#items + 1] = {
            display = display,
            value = entry.path,
            parent_value = node.parent,
            search_text = basename(entry.path) .. " " .. dir .. (entry.parent and (" " .. basename(entry.parent)) or ""),
            highlights = { { 0, #display, M.GROUPS[state] } },
        }
    end
    return items, initial
end

return M
