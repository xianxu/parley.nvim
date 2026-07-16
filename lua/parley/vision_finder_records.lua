local finder_scan = require("parley.finder_scan")
local vision = require("parley.vision")

local M = {}
local INVALID = finder_scan.FAILURE_KIND.invalid_adapter_result

local function failure(kind)
    return { kind = "failure", failure_kind = kind or INVALID }
end

local function valid_input(input)
    if type(input) ~= "table"
        or type(input.path) ~= "string"
        or type(input.name) ~= "string"
        or type(input.lines) ~= "table"
        or (input.repo_name ~= nil and type(input.repo_name) ~= "string")
        or type(input.identity) ~= "table"
        or type(input.identity.key) ~= "string"
        or type(input.identity.source) ~= "table" then
        return false
    end
    for _, line in ipairs(input.lines) do
        if type(line) ~= "string" then
            return false
        end
    end
    return true
end

local function copy_value(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[key] = copy_value(item)
    end
    return result
end

M.adapt = function(input)
    if not valid_input(input) then
        return failure()
    end
    local namespace = input.name:match("^(.+)%.yaml$")
    if not namespace then
        return { kind = "skip" }
    end

    local ok, parsed = pcall(vision.parse_vision_yaml, input.lines)
    if not ok or type(parsed) ~= "table" then
        return failure(finder_scan.FAILURE_KIND.parse)
    end
    local initiatives = {}
    for ordinal, raw in ipairs(parsed) do
        if type(raw) ~= "table" then
            return failure(finder_scan.FAILURE_KIND.parse)
        end
        local initiative = copy_value(raw)
        initiative._namespace = namespace
        initiative._file = input.path
        initiative._repo_name = input.repo_name
        initiative._parser_ordinal = ordinal
        initiatives[#initiatives + 1] = initiative
    end

    return {
        kind = "record",
        value = {
            identity = input.identity,
            source = {
                path = input.path,
                name = input.name,
                namespace = namespace,
                repo_name = input.repo_name,
            },
            initiatives = initiatives,
        },
    }
end

local function initiative_key(identity, ordinal)
    return tostring(#identity) .. ":" .. identity .. ":" .. tostring(ordinal)
end

M.materialize_records = function(records)
    local bundles = finder_scan.sort(finder_scan.deduplicate(records or {}), function(left, right)
        return left.source.path < right.source.path
    end)
    local items = {}
    for _, bundle in ipairs(bundles) do
        for _, initiative in ipairs(bundle.initiatives) do
            if type(initiative.project) == "string" and initiative.project ~= "" then
                local clean_name = vision.parse_priority(initiative.project)
                local namespace = initiative._namespace or ""
                local repo_prefix = initiative._repo_name
                    and ("{" .. initiative._repo_name .. "} ") or ""
                local size = initiative.size and ("[" .. initiative.size .. "]") or ""
                local initiative_type = initiative.type or ""
                local need_by = type(initiative.need_by) == "string" and initiative.need_by or ""
                local dependencies = initiative.depends_on or {}
                if type(dependencies) == "table" then
                    dependencies = table.concat(dependencies, " ")
                end
                items[#items + 1] = {
                    key = initiative_key(bundle.identity.key, initiative._parser_ordinal),
                    project = clean_name,
                    display = string.format(
                        "%s%s  %s  %s  %s  %s",
                        repo_prefix,
                        namespace,
                        clean_name,
                        size,
                        initiative_type,
                        need_by
                    ),
                    search_text = string.format(
                        "%s%s %s %s %s %s %s",
                        repo_prefix,
                        namespace,
                        clean_name,
                        initiative.type or "",
                        initiative.size or "",
                        need_by,
                        dependencies
                    ),
                    value = initiative._file,
                    line = initiative._line,
                }
            end
        end
    end
    return items
end

return M
