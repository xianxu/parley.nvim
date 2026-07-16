local M = {}

local function registered_kinds(failure_kind)
    local registered = {}
    for _, kind in pairs(failure_kind) do
        registered[kind] = true
    end
    return registered
end

local function normalize_adapter_result(ok, result, failure_kind, registered)
    if not ok then
        return { kind = "failure", failure_kind = failure_kind.adapter_exception }
    end
    if type(result) == "table" then
        if result.kind == "record" then
            return { kind = "record", value = result.value }
        end
        if result.kind == "skip" then
            return { kind = "skip" }
        end
        if result.kind == "failure" and registered[result.failure_kind] then
            return { kind = "failure", failure_kind = result.failure_kind }
        end
    end
    return { kind = "failure", failure_kind = failure_kind.invalid_adapter_result }
end

M.new = function(options, failure_kind)
    assert(type(options) == "table", "batch options must be a table")
    assert(type(options.item_budget) == "number" and options.item_budget >= 1, "item budget must be positive")
    assert(type(options.time_budget_ms) == "number" and options.time_budget_ms >= 0, "time budget must be non-negative")
    assert(type(options.now) == "function", "batch clock is required")
    assert(type(options.schedule) == "function", "batch scheduler is required")
    local registered = registered_kinds(failure_kind)

    local batcher = {}
    batcher.run = function(_, items, adapter, on_result, on_complete)
        assert(type(items) == "table", "batch items must be a table")
        assert(type(adapter) == "function", "batch adapter is required")
        assert(type(on_result) == "function", "batch result callback is required")
        assert(type(on_complete) == "function", "batch completion callback is required")

        local cancelled = false
        local completed = false
        local index = 1
        local handle = {
            cancel = function() cancelled = true end,
            is_cancelled = function() return cancelled end,
        }

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
                on_result(normalize_adapter_result(ok, result, failure_kind, registered), item, index - 1)
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
