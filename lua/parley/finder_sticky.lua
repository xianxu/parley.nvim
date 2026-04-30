-- finder_sticky.lua
-- Shared sticky-query helpers for finder pickers.
--
-- A "sticky" query fragment is a `{root}` or `[tag]` filter the user typed in
-- the picker prompt that should be re-seeded on the next invocation of the
-- same finder. Plain text is intentionally NOT preserved — only the structured
-- filter fragments. Both completed (`{xxx}` / `[xxx]`) and in-progress
-- (`{xxx` / `[xxx`) forms are kept; the in-progress form is normalised to its
-- completed equivalent so the prompt comes back tidy.

local M = {}

-- kinds: list of accepted kinds, e.g. { "root" } or { "root", "tag" }.
-- Returns the sticky string (e.g. "{charon} [bug]") or nil if no fragments.
function M.extract(query, kinds)
    if type(query) ~= "string" or query == "" then
        return nil
    end

    local accept = {}
    for _, kind in ipairs(kinds or { "root" }) do
        accept[kind] = true
    end

    local fragments = {}
    for token in query:gmatch("%S+") do
        local first = token:sub(1, 1)
        if first == "[" and accept.tag then
            local value
            if token:match("^%b[]$") then
                value = vim.trim(token:sub(2, -2))
            elseif not token:find("]", 2, true) then
                value = vim.trim(token:sub(2))
            end
            if value and value ~= "" and not value:find("[%[%]]") then
                table.insert(fragments, "[" .. value .. "]")
            end
        elseif first == "{" and accept.root then
            local value
            local is_complete = token:match("^%b{}$")
            if is_complete then
                value = vim.trim(token:sub(2, -2))
            elseif not token:find("}", 2, true) then
                value = vim.trim(token:sub(2))
            end
            if value then
                if value == "" and is_complete then
                    table.insert(fragments, "{}")
                elseif value ~= "" and not value:find("[{}]") then
                    table.insert(fragments, "{" .. value .. "}")
                end
            end
        end
    end

    if #fragments == 0 then
        return nil
    end

    return table.concat(fragments, " ")
end

-- Format a sticky query for use as `initial_query` when reopening a picker.
-- Trailing space lets the user type more without first inserting one.
function M.format_initial_query(sticky_query)
    if type(sticky_query) ~= "string" or sticky_query == "" then
        return nil
    end
    return sticky_query .. " "
end

return M
