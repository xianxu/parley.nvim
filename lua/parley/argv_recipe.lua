-- lua/parley/argv_recipe.lua
--
-- The recipe-as-data grammar shared by every module that runs an external
-- tool (#231 clipboard_image, #244 image_shrink): a recipe is
-- `{ tool, argv, dependency }` where argv carries TOKENS as WHOLE arguments
-- standing for paths or values the caller fills in. A path never enters a
-- shell string: it is substituted as its own argv element, or handed to
-- `sh -c` as `$1` (ARCH-SECURE). PURE.

local M = {}

--- argv with every argument that IS a key of `map` replaced by map[arg].
--- Path values are never rescanned. Optional embedded_map substitutes numeric
--- tokens only in arguments that were not replaced wholesale.
--- @param argv string[]
--- @param map table<string,string>
--- @return string[]
function M.substitute(argv, map, embedded_map)
    local out = {}
    for i, a in ipairs(argv) do
        local v = map[a]
        if v ~= nil then
            out[i] = v
        else
            local expanded = a
            for token, value in pairs(embedded_map or {}) do
                -- Plain find avoids giving token text a Lua-pattern meaning.
                local parts, pos = {}, 1
                while true do
                    local first, last = expanded:find(token, pos, true)
                    if not first then
                        parts[#parts + 1] = expanded:sub(pos)
                        break
                    end
                    parts[#parts + 1] = expanded:sub(pos, first - 1)
                    parts[#parts + 1] = value
                    pos = last + 1
                end
                expanded = table.concat(parts)
            end
            out[i] = expanded
        end
    end
    return out
end

--- True when some element of argv IS the token.
--- @param argv string[]
--- @param token string
--- @return boolean
function M.has_token(argv, token, embedded)
    for _, a in ipairs(argv) do
        if a == token or (embedded and type(a) == "string" and a:find(token, 1, true)) then
            return true
        end
    end
    return false
end

--- Pick a recipe. A configured argv list wins verbatim when it carries every
--- required token; otherwise the first candidate whose tool is executable.
--- `words` carries the caller's vocabulary so its messages stay its own:
---   { config_key, tokens = { "{out}", … }, purpose, none, advice(id) }
--- @param config_cmd string[]|nil
--- @param candidates table[]  ordered { tool, argv, dependency }
--- @param executable fun(tool: string): boolean
--- @param words table
--- @return table|nil recipe, string|nil err, "config"|"missing"|nil kind, string|nil capability
function M.select(config_cmd, candidates, executable, words)
    if type(config_cmd) == "table" and #config_cmd > 0 then
        for _, token in ipairs(words.tokens) do
            if not M.has_token(config_cmd, token) then
                return nil, words.config_key .. " must contain the " .. token
                    .. " token (as its own argument) " .. words.purpose, "config"
            end
        end
        for _, token in ipairs(words.embedded_tokens or {}) do
            if not M.has_token(config_cmd, token, true) then
                return nil, words.config_key .. " must contain the " .. token
                    .. " token (may be embedded in an argument) " .. words.purpose, "config"
            end
        end
        return { tool = config_cmd[1], argv = config_cmd }
    end
    local hints, ids, seen = {}, {}, {}
    for _, recipe in ipairs(candidates) do
        if executable(recipe.tool) then
            return recipe
        end
        local id = recipe.dependency
        if not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
            hints[#hints + 1] = words.advice(id)
        end
    end
    return nil, words.none .. ": " .. table.concat(hints, " or "), "missing", table.concat(ids, "|")
end

return M
