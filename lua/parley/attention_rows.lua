-- parley.attention_rows — the attention finder's rows (#354). Pure: model
-- entries, in the order given, become float_picker items; each row is
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

--- `entries` as float_picker items: `<state> [?] <name>  <dir>  <HH:MM>`.
--- `?` marks an entry whose last probe failed. options: { home, clock }
--- where clock(seconds) formats a submit time (os.date by default).
function M.items(entries, options)
    options = options or {}
    local home = options.home
    local clock = options.clock or function(t) return os.date("%H:%M", t) end
    local items = {}
    for _, entry in ipairs(entries) do
        local state = Model.state_of(entry)
        local dir = dirname(entry.path)
        local shown = dir
        if home and home ~= "" and (dir == home or dir:sub(1, #home + 1) == home .. "/") then
            shown = "~" .. dir:sub(#home + 1)
        end
        local display = ("%-8s %s %s  %s  %s"):format(state, entry.unknown and "?" or " ",
            basename(entry.path), shown, clock(entry.submitted_at))
        items[#items + 1] = {
            display = display,
            value = entry.path,
            search_text = basename(entry.path) .. " " .. dir,
            highlights = { { 0, #display, M.GROUPS[state] } },
        }
    end
    return items
end

return M
