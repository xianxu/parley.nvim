local M = {}

M.FAILURE_KIND = {
    root_enumeration = "root_enumeration",
    stat = "stat",
    open = "open",
    read = "read",
    parse = "parse",
    invalid_adapter_result = "invalid_adapter_result",
    adapter_exception = "adapter_exception",
    process_spawn = "process_spawn",
    process_stream = "process_stream",
    process_exit = "process_exit",
    path_fragment_too_long = "path_fragment_too_long",
    invalid_path = "invalid_path",
    invalid_read_policy = "invalid_read_policy",
    read_policy_exception = "read_policy_exception",
    producer_acquire_exception = "producer_acquire_exception",
    producer_finalize_exception = "producer_finalize_exception",
    producer_cache_hook_exception = "producer_cache_hook_exception",
    producer_factory_exception = "producer_factory_exception",
    subscriber_exception = "subscriber_exception",
    materializer_exception = "materializer_exception",
    terminal_hook_exception = "terminal_hook_exception",
    retire_hook_exception = "retire_hook_exception",
}

local REGISTERED_FAILURE_KIND = {}
for _, kind in pairs(M.FAILURE_KIND) do
    REGISTERED_FAILURE_KIND[kind] = true
end

local SNAPSHOT_FIELDS = {
    "kind",
    "roots",
    "recursion",
    "max_depth",
    "pattern",
    "backend",
}

local function deep_copy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        error("finder scan snapshots cannot contain cycles")
    end

    seen[value] = true
    local copy = {}
    for key, item in pairs(value) do
        copy[deep_copy(key, seen)] = deep_copy(item, seen)
    end
    seen[value] = nil
    return copy
end

local function frame(value)
    return tostring(#value) .. ":" .. value
end

local function encode(value, seen)
    local value_type = type(value)
    if value_type == "nil" then
        return "n"
    end
    if value_type == "boolean" then
        return value and "b1" or "b0"
    end
    if value_type == "number" then
        return "d" .. frame(string.format("%.17g", value))
    end
    if value_type == "string" then
        return "s" .. frame(value)
    end
    if value_type ~= "table" then
        error("unsupported snapshot value type: " .. value_type)
    end

    seen = seen or {}
    if seen[value] then
        error("finder scan snapshots cannot contain cycles")
    end
    seen[value] = true

    local encoded = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        encoded[count] = { key = encode(key, seen), value = encode(item, seen) }
    end
    table.sort(encoded, function(left, right)
        return left.key < right.key
    end)

    local parts = { "t", frame(tostring(count)) }
    for _, item in ipairs(encoded) do
        parts[#parts + 1] = frame(item.key)
        parts[#parts + 1] = frame(item.value)
    end
    seen[value] = nil
    return table.concat(parts)
end

local function snapshot_data(options)
    local data = {}
    for _, field in ipairs(SNAPSHOT_FIELDS) do
        data[field] = deep_copy(options[field])
    end
    return data
end

M.snapshot = function(options)
    assert(type(options) == "table", "snapshot options must be a table")
    local data = snapshot_data(options)
    local fingerprint = encode(data)

    local methods = {}
    methods.copy = function()
        return deep_copy(data)
    end
    methods.fingerprint = function()
        return fingerprint
    end

    return setmetatable({}, {
        __index = methods,
        __newindex = function()
            error("finder scan snapshots are immutable", 2)
        end,
        __metatable = false,
    })
end

M.fingerprint = function(snapshot)
    assert(type(snapshot) == "table" and type(snapshot.fingerprint) == "function", "invalid scan snapshot")
    return snapshot:fingerprint()
end

local function normalize_absolute(path)
    assert(type(path) == "string" and path:sub(1, 1) == "/", "path must be absolute")
    path = path:gsub("\\", "/")

    local components = {}
    for component in path:gmatch("[^/]+") do
        if component == ".." then
            if #components > 0 then
                components[#components] = nil
            end
        elseif component ~= "." and component ~= "" then
            components[#components + 1] = component
        end
    end
    return "/" .. table.concat(components, "/")
end

M.path_identity = function(options)
    assert(type(options) == "table", "path identity options must be a table")
    assert(type(options.root_ordinal) == "number", "root ordinal must be a number")

    local unresolved = normalize_absolute(options.unresolved_absolute)
    local key = unresolved
    if options.resolved_absolute ~= nil then
        key = normalize_absolute(options.resolved_absolute)
    end

    return {
        key = key,
        source = {
            root_ordinal = options.root_ordinal,
            unresolved = unresolved,
        },
    }
end

local function source_less(left, right)
    if left.root_ordinal ~= right.root_ordinal then
        return left.root_ordinal < right.root_ordinal
    end
    return left.unresolved < right.unresolved
end

local function utf8_prefix(value, byte_cap)
    if #value <= byte_cap then
        return value
    end
    if byte_cap == 0 then
        return ""
    end

    local last = byte_cap
    local start = last
    while start > 1 do
        local byte = value:byte(start)
        if byte < 128 or byte >= 192 then
            break
        end
        start = start - 1
    end

    local lead = value:byte(start)
    local expected = 1
    if lead >= 240 then
        expected = 4
    elseif lead >= 224 then
        expected = 3
    elseif lead >= 192 then
        expected = 2
    end
    if start + expected - 1 > last then
        last = start - 1
    end
    return value:sub(1, last)
end

M.sanitize_diagnostic = function(value, byte_cap)
    assert(type(value) == "string", "diagnostic must be a string")
    byte_cap = byte_cap or 512
    assert(type(byte_cap) == "number" and byte_cap >= 0 and byte_cap % 1 == 0, "byte cap must be non-negative")
    return utf8_prefix(value:gsub("[%z\1-\31\127]", " "), byte_cap)
end

M.deduplicate = function(records)
    local winners = {}
    for _, record in ipairs(records) do
        local identity = assert(record.identity, "record identity is required")
        local current = winners[identity.key]
        if current == nil or source_less(identity.source, current.identity.source) then
            winners[identity.key] = record
        end
    end

    local keys = {}
    for key in pairs(winners) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local result = {}
    for _, key in ipairs(keys) do
        result[#result + 1] = winners[key]
    end
    return result
end

M.sort = function(records, primary_less)
    assert(type(primary_less) == "function", "primary comparator is required")
    local result = {}
    for index, record in ipairs(records) do
        result[index] = record
    end

    table.sort(result, function(left, right)
        if primary_less(left, right) then
            return true
        end
        if primary_less(right, left) then
            return false
        end
        if left.identity.key ~= right.identity.key then
            return left.identity.key < right.identity.key
        end
        return source_less(left.identity.source, right.identity.source)
    end)
    return result
end

local function assert_root(accumulator, ordinal)
    assert(type(ordinal) == "number" and ordinal % 1 == 0, "root ordinal must be an integer")
    assert(ordinal >= 1 and ordinal <= accumulator.root_count, "root ordinal is out of range")
    assert(accumulator.root_states[ordinal] == nil, "root already settled")
end

local function add_diagnostic(accumulator, kind, diagnostic)
    assert(REGISTERED_FAILURE_KIND[kind] == true, "unregistered failure kind")
    if diagnostic ~= nil then
        assert(type(diagnostic) == "string", "diagnostic must be a string")
        if #accumulator.diagnostics < 10 then
            accumulator.diagnostics[#accumulator.diagnostics + 1] = {
                kind = kind,
                message = M.sanitize_diagnostic(diagnostic),
            }
        else
            accumulator.omitted_diagnostic_count = accumulator.omitted_diagnostic_count + 1
        end
    end
end

M.new_accumulator = function(root_count)
    assert(type(root_count) == "number" and root_count >= 0 and root_count % 1 == 0, "root count must be non-negative")
    return {
        root_count = root_count,
        root_states = {},
        root_records = {},
        successful_root_count = 0,
        skipped_root_count = 0,
        failed_root_count = 0,
        failed_record_count = 0,
        diagnostics = {},
        omitted_diagnostic_count = 0,
    }
end

M.root_skipped = function(accumulator, ordinal)
    assert_root(accumulator, ordinal)
    accumulator.root_states[ordinal] = "skipped"
    accumulator.skipped_root_count = accumulator.skipped_root_count + 1
end

M.root_succeeded = function(accumulator, ordinal, records)
    assert_root(accumulator, ordinal)
    assert(type(records) == "table", "root records must be a table")
    accumulator.root_states[ordinal] = "success"
    accumulator.root_records[ordinal] = records
    accumulator.successful_root_count = accumulator.successful_root_count + 1
end

M.root_failed = function(accumulator, ordinal, kind, diagnostic)
    assert_root(accumulator, ordinal)
    accumulator.root_states[ordinal] = "failed"
    accumulator.failed_root_count = accumulator.failed_root_count + 1
    add_diagnostic(accumulator, kind, diagnostic)
end

M.record_failed = function(accumulator, kind, diagnostic)
    accumulator.failed_record_count = accumulator.failed_record_count + 1
    add_diagnostic(accumulator, kind, diagnostic)
end

M.outcome = function(accumulator)
    local settled_root_count = accumulator.successful_root_count
        + accumulator.skipped_root_count
        + accumulator.failed_root_count
    assert(settled_root_count == accumulator.root_count, "cannot produce outcome before every root settles")

    local records = {}
    for ordinal = 1, accumulator.root_count do
        for _, record in ipairs(accumulator.root_records[ordinal] or {}) do
            records[#records + 1] = record
        end
    end

    local kind = "success"
    if accumulator.successful_root_count == 0 and accumulator.failed_root_count > 0 then
        kind = "failure"
    elseif accumulator.failed_root_count > 0 or accumulator.failed_record_count > 0 then
        kind = "partial"
    end

    local outcome = {
        kind = kind,
        successful_root_count = accumulator.successful_root_count,
        skipped_root_count = accumulator.skipped_root_count,
        failed_root_count = accumulator.failed_root_count,
        failed_record_count = accumulator.failed_record_count,
        diagnostics = deep_copy(accumulator.diagnostics),
        omitted_diagnostic_count = accumulator.omitted_diagnostic_count,
    }
    if kind ~= "failure" then
        outcome.records = records
    end
    return outcome
end

local function normalize_adapter_result(ok, result)
    if not ok then
        return {
            kind = "failure",
            failure_kind = M.FAILURE_KIND.adapter_exception,
        }
    end
    if type(result) ~= "table" then
        return {
            kind = "failure",
            failure_kind = M.FAILURE_KIND.invalid_adapter_result,
        }
    end
    if result.kind == "record" then
        return { kind = "record", value = result.value }
    end
    if result.kind == "skip" then
        return { kind = "skip" }
    end
    if result.kind == "failure" and REGISTERED_FAILURE_KIND[result.failure_kind] then
        return { kind = "failure", failure_kind = result.failure_kind }
    end
    return {
        kind = "failure",
        failure_kind = M.FAILURE_KIND.invalid_adapter_result,
    }
end

M.new_batcher = function(options)
    assert(type(options) == "table", "batch options must be a table")
    assert(type(options.item_budget) == "number" and options.item_budget >= 1, "item budget must be positive")
    assert(type(options.time_budget_ms) == "number" and options.time_budget_ms >= 0, "time budget must be non-negative")
    assert(type(options.now) == "function", "batch clock is required")
    assert(type(options.schedule) == "function", "batch scheduler is required")

    local batcher = {}
    batcher.run = function(_, items, adapter, on_result, on_complete)
        assert(type(items) == "table", "batch items must be a table")
        assert(type(adapter) == "function", "batch adapter is required")
        assert(type(on_result) == "function", "batch result callback is required")
        assert(type(on_complete) == "function", "batch completion callback is required")

        local cancelled = false
        local completed = false
        local index = 1
        local handle = {}

        handle.cancel = function()
            cancelled = true
        end
        handle.is_cancelled = function()
            return cancelled
        end

        local run_slice
        run_slice = function()
            if cancelled or completed then
                return
            end

            local started_at = options.now()
            local processed = 0
            while index <= #items do
                local item = items[index]
                index = index + 1
                processed = processed + 1

                local ok, result = pcall(adapter, item)
                on_result(normalize_adapter_result(ok, result), item, index - 1)
                if cancelled then
                    return
                end

                local exhausted_items = processed >= options.item_budget
                local exhausted_time = options.now() - started_at >= options.time_budget_ms
                if index <= #items and (exhausted_items or exhausted_time) then
                    options.schedule(run_slice)
                    return
                end
            end

            completed = true
            on_complete()
        end

        run_slice()
        return handle
    end

    return batcher
end

return M
