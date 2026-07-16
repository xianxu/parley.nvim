local finder_scan = require("parley.finder_scan")

local M = {}
local INVALID = finder_scan.FAILURE_KIND.invalid_adapter_result

local function failure()
    return { kind = "failure", failure_kind = INVALID }
end

local function path_parts(path)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function classify(relative)
    local parts = path_parts(relative)
    local first = parts[1]
    if not first or first == "templates" then
        return {
            is_template = first == "templates",
            relative_path = relative,
        }
    end
    local base_folder
    if not first:match("^%d%d%d%d$") then
        base_folder = first
    end
    return {
        is_template = false,
        relative_path = relative,
        base_folder = base_folder,
    }
end

local function infer_time(relative)
    local parts = path_parts(relative)
    local year = tonumber(parts[1] and parts[1]:match("^(%d%d%d%d)$"))
    local month = tonumber(parts[2] and parts[2]:match("^(%d%d)$"))
    local filename = parts[#parts] or ""
    local day = tonumber(filename:match("^(%d%d)%-"))
    if year and month and day then
        return os.time({ year = year, month = month, day = day, hour = 23, min = 59, sec = 59 })
    end
    if year and month then
        return os.time({ year = year, month = month + 1, day = 0, hour = 23, min = 59, sec = 59 })
    end
    if year then
        return os.time({ year = year, month = 12, day = 31, hour = 23, min = 59, sec = 59 })
    end
end

local function copy_classification(value)
    if type(value) ~= "table"
        or type(value.relative_path) ~= "string"
        or (value.base_folder ~= nil and type(value.base_folder) ~= "string") then
        return nil
    end
    return {
        is_template = value.is_template == true,
        relative_path = value.relative_path,
        base_folder = value.base_folder,
    }
end

M.read_decision = function(cache, candidate)
    local identity = type(candidate) == "table" and candidate.identity or nil
    local mtime = type(candidate) == "table" and candidate.stat
        and candidate.stat.mtime and candidate.stat.mtime.sec or nil
    local cached = type(cache) == "table" and identity and cache[identity.key] or nil
    if type(cached) == "table" and type(mtime) == "number" and cached.mtime == mtime then
        return { kind = "ready", value = cached }
    end
    return { kind = "none" }
end

M.adapt = function(candidate)
    if type(candidate) ~= "table"
        or type(candidate.relative) ~= "string"
        or type(candidate.unresolved_absolute) ~= "string"
        or type(candidate.identity) ~= "table"
        or type(candidate.identity.key) ~= "string"
        or type(candidate.stat) ~= "table"
        or type(candidate.stat.mtime) ~= "table"
        or type(candidate.stat.mtime.sec) ~= "number"
        or type(candidate.root) ~= "table" then
        return failure()
    end

    local classification
    local inferred_time
    if candidate.precomputed ~= nil then
        classification = copy_classification(candidate.precomputed.classification)
        inferred_time = candidate.precomputed.inferred_time
        if not classification or (inferred_time ~= nil and type(inferred_time) ~= "number") then
            return failure()
        end
    else
        classification = classify(candidate.relative)
        inferred_time = infer_time(candidate.relative)
    end
    if classification.is_template then
        return { kind = "skip" }
    end

    local modified_time = candidate.stat.mtime.sec
    return {
        kind = "record",
        value = {
            path = candidate.unresolved_absolute,
            relative = candidate.relative,
            identity = candidate.identity,
            stat = candidate.stat,
            root = candidate.root,
            mtime = modified_time,
            modified_time = modified_time,
            inferred_time = inferred_time,
            timestamp = inferred_time or modified_time,
            classification = classification,
            base_folder = classification.base_folder,
        },
    }
end

M.cache_entry = function(record)
    return {
        mtime = record.mtime,
        classification = copy_classification(record.classification),
        inferred_time = record.inferred_time,
    }
end

local function filename(path)
    return path:match("([^/\\]+)$") or path
end

M.materialize = function(records, options)
    options = options or {}
    local unique = finder_scan.deduplicate(records or {})
    local sorted = finder_scan.sort(unique, function(left, right)
        if left.timestamp ~= right.timestamp then
            return left.timestamp > right.timestamp
        end
        if left.modified_time ~= right.modified_time then
            return left.modified_time > right.modified_time
        end
        return false
    end)

    local entries = {}
    for _, record in ipairs(sorted) do
        local special = record.base_folder ~= nil
        if special or options.cutoff_time == nil or record.timestamp >= options.cutoff_time then
            local primary = record.root.is_primary == true
            local label = type(record.root.label) == "string" and record.root.label or ""
            local root_prefix = not primary and label ~= "" and ("{" .. label .. "} ") or ""
            local display
            local search
            if special then
                display = string.format(
                    "%s{%s} %s [%s]",
                    root_prefix,
                    record.base_folder,
                    filename(record.path),
                    os.date("%Y-%m-%d", record.timestamp)
                )
                search = string.format(
                    "{%s} %s %s",
                    record.base_folder,
                    filename(record.path),
                    record.relative:gsub("%-", " ")
                )
            else
                display = root_prefix .. record.relative .. " [" .. os.date("%Y-%m-%d", record.timestamp) .. "]"
                search = "{} " .. record.relative:gsub("%-", " ")
            end
            if not primary and label ~= "" then
                search = "{" .. label .. "} " .. search
            end
            entries[#entries + 1] = {
                value = record.path,
                display = display,
                ordinal = search,
                timestamp = record.timestamp,
                modified_time = record.modified_time,
                base_folder = record.base_folder,
                identity = record.identity,
            }
        end
    end
    return entries
end

return M
