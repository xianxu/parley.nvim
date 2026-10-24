-- Version 4 editing briefs are named task context. Manifest order is preserved;
-- no behavior flags, defaults, or editorial sequence are inferred.
local M = {}

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end

local function safe_name(name)
    return type(name) == "string" and name:match("^[a-z0-9][a-z0-9%-]*$")
        and not name:find("%-%-") and name:sub(-1) ~= "-"
end

--- List exported brief names in manifest order. dir is the skill root.
--- @return table|nil names, string|nil err
function M.list(dir)
    local text = type(dir) == "string" and read_file(dir .. "/export.json")
    local ok, manifest = pcall(vim.json.decode, text or "")
    if not ok or type(manifest) ~= "table" or manifest.schema ~= "ariadne/universal-review-export"
        or manifest.version ~= 4 or type(manifest.members) ~= "table" then
        return nil, "brief: invalid version 4 export manifest"
    end
    local names, seen = {}, {}
    for _, member in ipairs(manifest.members) do
        if type(member) ~= "table" then
            return nil, "brief: invalid manifest member"
        end
        if member.role == "brief" then
            local name = member.name
            if not safe_name(name) or seen[name] or member.path ~= "briefs/" .. name .. ".md" then
                return nil, "brief: invalid or duplicate manifest brief"
            end
            for _, key in ipairs({ "scope", "frontier", "deletions", "order" }) do
                if member[key] ~= nil then
                    return nil, "brief: retired metadata " .. key
                end
            end
            names[#names + 1], seen[name] = name, true
        end
    end
    if #names == 0 then
        return nil, "brief: export has no briefs"
    end
    return names
end

--- Load an exported brief as {name, body}. dir is the skill root.
--- @return table|nil brief, string|nil err
function M.load(dir, name)
    if not safe_name(name) then
        return nil, "brief: invalid name"
    end
    local names, err = M.list(dir)
    if not names then
        return nil, err
    end
    local found = false
    for _, exported in ipairs(names) do
        found = found or exported == name
    end
    if not found then
        return nil, "brief: unknown name '" .. name .. "'"
    end
    local text = read_file(dir .. "/briefs/" .. name .. ".md")
    if not text then
        return nil, "brief: no file for '" .. name .. "'"
    end
    local header = "---\nname: " .. name .. "\n---\n"
    if text:sub(1, #header) ~= header then
        return nil, "brief: frontmatter must contain only matching name"
    end
    return { name = name, body = text:sub(#header + 1):gsub("%s+$", "") }
end

--- Assemble all named brief bodies as task context, in manifest order.
--- @return string|nil context, string|nil err
function M.context(dir)
    local names, err = M.list(dir)
    if not names then
        return nil, err
    end
    local parts = {}
    for _, name in ipairs(names) do
        local value, load_err = M.load(dir, name)
        if not value then
            return nil, load_err
        end
        parts[#parts + 1] = "## " .. name .. "\n" .. value.body
    end
    return table.concat(parts, "\n\n")
end

return M
