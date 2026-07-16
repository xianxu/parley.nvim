local finder_scan = require("parley.finder_scan")
local chat_parser = require("parley.chat_parser")

local M = {}
local INVALID = finder_scan.FAILURE_KIND.invalid_adapter_result

local function failure()
    return { kind = "failure", failure_kind = INVALID }
end

local function copy_tags(tags)
    if type(tags) ~= "table" then
        return nil
    end
    local result = {}
    for _, tag in ipairs(tags) do
        if type(tag) ~= "string" then
            return nil
        end
        result[#result + 1] = tag
    end
    return result
end

local function valid_base(input)
    return type(input) == "table"
        and type(input.path) == "string"
        and type(input.identity) == "table"
        and type(input.identity.key) == "string"
        and type(input.stat) == "table"
        and type(input.stat.mtime) == "table"
        and type(input.stat.mtime.sec) == "number"
        and type(input.root) == "table"
end

local function timestamp(path, fallback)
    local filename = path:match("([^/\\]+)$") or path
    local year, month, day, hour, minute, second =
        filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
    if not year then
        return fallback
    end
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(minute),
        sec = tonumber(second),
    }) or fallback
end

M.read_decision = function(cache, stat_record)
    local identity = type(stat_record) == "table" and stat_record.identity or nil
    local mtime = type(stat_record) == "table" and stat_record.stat
        and stat_record.stat.mtime and stat_record.stat.mtime.sec or nil
    local cached = type(cache) == "table" and identity and cache[identity.key] or nil
    if type(cached) == "table" and type(mtime) == "number" and cached.mtime == mtime then
        return { kind = "ready", value = cached }
    end
    return { kind = "read", mode = { head_lines = 10 } }
end

M.adapt = function(input)
    if not valid_base(input) then
        return failure()
    end

    local topic
    local tags
    if input.kind == "cached" and type(input.metadata) == "table" then
        topic = input.metadata.topic
        tags = copy_tags(input.metadata.tags)
    elseif input.kind == "lines" and type(input.first_lines) == "table" then
        for _, line in ipairs(input.first_lines) do
            if type(line) ~= "string" then
                return failure()
            end
        end
        local headers = chat_parser.parse_header_metadata(
            input.first_lines,
            chat_parser.find_header_end(input.first_lines)
        )
        topic = headers.topic or ""
        tags = copy_tags(headers.tags or {})
    else
        return failure()
    end
    if type(topic) ~= "string" or tags == nil then
        return failure()
    end

    local mtime = input.stat.mtime.sec
    return {
        kind = "record",
        value = {
            path = input.path,
            identity = input.identity,
            stat = input.stat,
            root = input.root,
            mtime = mtime,
            timestamp = timestamp(input.path, mtime),
            topic = topic,
            tags = tags,
        },
    }
end

M.cache_entry = function(record)
    return {
        mtime = record.mtime,
        topic = record.topic,
        tags = copy_tags(record.tags),
    }
end

local function filename(path)
    return path:match("([^/\\]+)$") or path
end

M.materialize = function(records, options)
    options = options or {}
    local unique = finder_scan.deduplicate(records or {})
    local sorted = finder_scan.sort(unique, function(left, right)
        return left.timestamp > right.timestamp
    end)
    local entries = {}
    for _, record in ipairs(sorted) do
        if options.cutoff_time == nil or record.timestamp >= options.cutoff_time then
            local tags_display = ""
            if #record.tags > 0 then
                local parts = {}
                for _, tag in ipairs(record.tags) do
                    parts[#parts + 1] = "[" .. tag .. "]"
                end
                tags_display = table.concat(parts, " ") .. " "
            end
            local tags_searchable = #record.tags > 0
                and (" [" .. table.concat(record.tags, "] [") .. "]") or " []"
            local is_primary = record.root.is_primary == true
            local label = type(record.root.label) == "string" and record.root.label or ""
            local root_prefix = not is_primary and label ~= "" and ("{" .. label .. "} ") or ""
            local root_searchable = is_primary and " {}" or (" {" .. label .. "}")
            local display_filename = filename(record.path)
            local dotted = display_filename:match("^(%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d%d%d)")
            if dotted then
                display_filename = dotted .. ".md"
            end
            entries[#entries + 1] = {
                value = record.path,
                display = display_filename .. " - " .. root_prefix .. tags_display
                    .. record.topic .. " [" .. os.date("%Y-%m-%d", record.timestamp) .. "]",
                ordinal = display_filename .. root_searchable .. " " .. tags_searchable
                    .. " " .. record.topic,
                timestamp = record.timestamp,
                tags = copy_tags(record.tags),
                identity = record.identity,
            }
        end
    end
    return entries
end

return M
