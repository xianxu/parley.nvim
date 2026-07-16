local finder_scan = require("parley.finder_scan")

local M = {}
local FAILURE_KIND = finder_scan.FAILURE_KIND

local function total_failure(root_count, kind)
    return {
        kind = "failure",
        successful_root_count = 0,
        skipped_root_count = 0,
        failed_root_count = root_count,
        failed_record_count = 0,
        diagnostics = { { kind = kind, message = kind } },
        omitted_diagnostic_count = 0,
    }
end

local function cancel_producer(handle)
    if type(handle) == "function" then
        pcall(handle)
    elseif type(handle) == "table" and type(handle.cancel) == "function" then
        pcall(handle.cancel, handle)
    end
end

M.new_session = function(options)
    assert(type(options) == "table", "session options must be a table")
    assert(options.ownership == "picker" or options.ownership == "retained", "invalid session ownership")
    assert(type(options.snapshot) == "table", "session snapshot is required")
    assert(type(options.producer_factory) == "function", "producer factory is required")

    local subscribers = {}
    local subscriber_order = {}
    local next_subscriber_id = 0
    local subscriber_count = 0
    local started = false
    local settled = false
    local retired = false
    local outcome
    local producer_handle
    local producer_cancelled = false
    local session = {}

    local function report(kind)
        if options.diagnostic then
            pcall(options.diagnostic, kind)
        end
    end

    local function retire()
        if retired then
            return
        end
        outcome = nil
        retired = true
        if options.on_retire then
            local ok = pcall(options.on_retire)
            if not ok then
                report(FAILURE_KIND.retire_hook_exception)
            end
        end
    end

    local function cancel_owned_producer()
        if producer_cancelled then
            return
        end
        producer_cancelled = true
        cancel_producer(producer_handle)
    end

    local function cancel_and_retire()
        if retired then
            return
        end
        cancel_owned_producer()
        for id in pairs(subscribers) do
            subscribers[id] = nil
        end
        subscriber_count = 0
        retire()
    end

    local function settle(next_outcome)
        if retired or settled then
            return
        end
        settled = true
        outcome = next_outcome
        local had_subscribers = subscriber_count > 0
        local index = 1
        while index <= #subscriber_order do
            local id = subscriber_order[index]
            local callback = subscribers[id]
            if callback then
                subscribers[id] = nil
                subscriber_count = subscriber_count - 1
                local ok = pcall(callback, outcome)
                if not ok then
                    report(FAILURE_KIND.subscriber_exception)
                end
            end
            index = index + 1
        end
        if options.on_terminal then
            local ok = pcall(options.on_terminal, outcome, had_subscribers)
            if not ok then
                report(FAILURE_KIND.terminal_hook_exception)
            end
        end
        retire()
    end

    session.subscribe = function(_, callback)
        assert(type(callback) == "function", "subscriber callback is required")
        if retired then
            return {
                cancel = function() end,
                is_cancelled = function() return true end,
            }
        end

        next_subscriber_id = next_subscriber_id + 1
        local id = next_subscriber_id
        local cancelled = false
        subscribers[id] = callback
        subscriber_order[#subscriber_order + 1] = id
        subscriber_count = subscriber_count + 1

        local subscription = {}
        subscription.cancel = function()
            if cancelled then
                return
            end
            cancelled = true
            if subscribers[id] then
                subscribers[id] = nil
                subscriber_count = subscriber_count - 1
            end
            if not settled and options.ownership == "picker" and subscriber_count == 0 then
                cancel_and_retire()
            end
        end
        subscription.is_cancelled = function()
            return cancelled or retired
        end

        return subscription
    end

    session.start = function()
        if started or retired then
            return
        end
        started = true
        local ok, result = pcall(options.producer_factory, settle)
        if ok then
            producer_handle = result
            if producer_cancelled then
                cancel_producer(producer_handle)
            end
        else
            report(FAILURE_KIND.producer_factory_exception)
            settle(total_failure(#(options.snapshot:copy().roots or {}), FAILURE_KIND.producer_factory_exception))
        end
    end

    session.cancel_owner = function()
        cancel_and_retire()
    end
    session.fingerprint = function()
        return options.snapshot:fingerprint()
    end
    session.snapshot_copy = function()
        return options.snapshot:copy()
    end
    session.is_settled = function()
        return settled
    end
    session.is_retired = function()
        return retired
    end
    session.subscriber_count = function()
        return subscriber_count
    end
    session._report = report
    return session
end

local function picker_failure_status()
    return { message = "scan failed", animated = false }
end

M.open_picker = function(options)
    assert(type(options) == "table", "picker bridge options must be a table")
    assert(type(options.session) == "table", "picker bridge session is required")
    assert(type(options.picker_open) == "function", "picker opener is required")
    assert(type(options.materialize) == "function", "picker materializer is required")

    local picker_options = {}
    for key, value in pairs(options.picker_options or {}) do
        picker_options[key] = value
    end
    picker_options.items = {}
    picker_options.status = { message = "scanning…", animated = true }

    local subscription
    local caller_cancel = picker_options.on_cancel
    picker_options.on_cancel = function()
        if subscription then
            subscription:cancel()
        end
        if caller_cancel then
            caller_cancel()
        end
    end

    local picker = options.picker_open(picker_options)
    assert(type(picker) == "table", "picker opener must return a picker")
    subscription = options.session:subscribe(function(outcome)
        if picker.is_closed and picker.is_closed() then
            return
        end
        if outcome.kind == "failure" then
            picker.set_status(picker_failure_status())
            return
        end
        if outcome.kind == "partial" and options.warning then
            pcall(options.warning, outcome.failed_root_count, outcome.failed_record_count)
        end

        local query = picker.current_query and picker.current_query() or ""
        local ok, result = pcall(options.materialize, outcome, query)
        if not ok or type(result) ~= "table" or type(result.items) ~= "table" then
            options.session._report(FAILURE_KIND.materializer_exception)
            picker.set_status(picker_failure_status())
            return
        end
        picker.update(result.items, result.tags)
    end)

    return { picker = picker, subscription = subscription }
end

return M
