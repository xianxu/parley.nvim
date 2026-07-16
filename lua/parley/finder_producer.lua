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

M.run = function(options, settle_once)
    assert(type(options) == "table" and type(options.roots) == "table", "producer roots are required")
    assert(type(options.acquire) == "function", "producer acquisition is required")
    assert(type(options.adapter) == "function", "producer adapter is required")
    assert(type(options.finalize) == "function", "producer finalizer is required")
    assert(type(options.batch) == "table", "producer batch options are required")
    assert(type(settle_once) == "function", "producer settlement callback is required")

    local accumulator = finder_scan.new_accumulator(#options.roots)
    local root_seen = {}
    local seen_root_count = 0
    local pending_batches = 0
    local acquisition_complete = false
    local acquisition_handle
    local batch_handles = {}
    local cancelled = false
    local settled = false
    local handle = {}

    local function emit_diagnostic(kind)
        if options.diagnostic then
            pcall(options.diagnostic, kind)
        end
    end

    local function deliver(outcome)
        if cancelled or settled then
            return
        end
        settled = true
        pcall(settle_once, outcome)
    end

    local function maybe_settle()
        if cancelled or settled or not acquisition_complete
            or seen_root_count ~= #options.roots or pending_batches ~= 0 then
            return
        end

        local outcome = finder_scan.outcome(accumulator)
        if outcome.kind == "failure" then
            deliver(outcome)
            return
        end

        local ok, records = pcall(options.finalize, outcome.records)
        if not ok or type(records) ~= "table" then
            deliver(total_failure(#options.roots, FAILURE_KIND.producer_finalize_exception))
            return
        end
        outcome.records = records
        deliver(outcome)
    end

    local function record_failure(kind, diagnostic)
        finder_scan.record_failed(accumulator, kind, diagnostic)
    end

    local function successful_root(event)
        pending_batches = pending_batches + 1
        for _, failure in ipairs(event.failures or {}) do
            record_failure(failure.kind, failure.diagnostic)
        end

        local records = {}
        local seen_keys = {}
        local batcher = finder_scan.new_batcher(options.batch)
        local batch_handle = batcher:run(event.candidates or {}, options.adapter, function(result)
            if result.kind == "record" then
                local record = result.value
                records[#records + 1] = record
                if record.identity and type(record.identity.key) == "string" then
                    seen_keys[#seen_keys + 1] = record.identity.key
                end
                if options.on_record then
                    local ok = pcall(options.on_record, record)
                    if not ok then
                        record_failure(FAILURE_KIND.producer_cache_hook_exception)
                        emit_diagnostic(FAILURE_KIND.producer_cache_hook_exception)
                    end
                end
            elseif result.kind == "failure" then
                record_failure(result.failure_kind)
            end
        end, function()
            table.sort(seen_keys)
            if options.on_root_success then
                local ok = pcall(options.on_root_success, event.root_ordinal, seen_keys)
                if not ok then
                    record_failure(FAILURE_KIND.producer_cache_hook_exception)
                    emit_diagnostic(FAILURE_KIND.producer_cache_hook_exception)
                end
            end
            finder_scan.root_succeeded(accumulator, event.root_ordinal, records)
            pending_batches = pending_batches - 1
            maybe_settle()
        end)
        batch_handles[#batch_handles + 1] = batch_handle
    end

    local function on_root(event)
        if cancelled or settled or type(event) ~= "table" then
            return
        end
        local ordinal = event.root_ordinal
        if type(ordinal) ~= "number" or ordinal < 1 or ordinal > #options.roots or root_seen[ordinal] then
            return
        end
        root_seen[ordinal] = true
        seen_root_count = seen_root_count + 1

        if event.status == "success" then
            successful_root(event)
        elseif event.status == "skipped" then
            finder_scan.root_skipped(accumulator, ordinal)
        elseif event.status == "failed" and type(event.failure) == "table" then
            finder_scan.root_failed(accumulator, ordinal, event.failure.kind, event.failure.diagnostic)
        else
            finder_scan.root_failed(accumulator, ordinal, FAILURE_KIND.root_enumeration)
        end
        maybe_settle()
    end

    local function on_complete()
        if not cancelled and not settled then
            acquisition_complete = true
            maybe_settle()
        end
    end

    handle.cancel = function()
        if cancelled or settled then
            return
        end
        cancelled = true
        if acquisition_handle and type(acquisition_handle.cancel) == "function" then
            pcall(acquisition_handle.cancel, acquisition_handle)
        end
        for _, batch_handle in ipairs(batch_handles) do
            pcall(batch_handle.cancel, batch_handle)
        end
    end
    handle.is_cancelled = function()
        return cancelled
    end

    local ok, result = pcall(options.acquire, on_root, on_complete)
    if ok then
        acquisition_handle = result
    else
        deliver(total_failure(#options.roots, FAILURE_KIND.producer_acquire_exception))
    end
    return handle
end

return M
