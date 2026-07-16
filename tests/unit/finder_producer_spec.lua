local finder_producer = require("parley.finder_producer")
local finder_scan = require("parley.finder_scan")

local function acquisition(events)
    local cancel_count = 0
    return function(on_root, on_complete)
        for _, event in ipairs(events) do
            on_root(event)
        end
        on_complete()
        return {
            cancel = function() cancel_count = cancel_count + 1 end,
            is_cancelled = function() return cancel_count > 0 end,
        }
    end, function() return cancel_count end
end

local function immediate_batch()
    return {
        item_budget = 25,
        time_budget_ms = 5,
        now = function() return 0 end,
        schedule = function(callback) callback() end,
    }
end

describe("finder producer", function()
    it("orchestrates out-of-order root outcomes through one final settlement", function()
        local acquire = acquisition({
            {
                root_ordinal = 3,
                status = "success",
                candidates = { { id = "third", identity = { key = "/third" } } },
                failures = {},
            },
            { root_ordinal = 1, status = "skipped", reason = "absent_optional" },
            {
                root_ordinal = 2,
                status = "failed",
                failure = { kind = finder_scan.FAILURE_KIND.root_enumeration, diagnostic = "denied" },
            },
        })
        local records = {}
        local successful_roots = {}
        local settlements = {}

        finder_producer.run({
            roots = { {}, {}, {} },
            acquire = acquire,
            adapter = function(candidate)
                return { kind = "record", value = candidate }
            end,
            finalize = function(values)
                table.sort(values, function(left, right) return left.id < right.id end)
                return values
            end,
            batch = immediate_batch(),
            on_record = function(record) records[#records + 1] = record.id end,
            on_root_success = function(ordinal, seen_keys)
                successful_roots[ordinal] = seen_keys
            end,
            diagnostic = function() end,
        }, function(outcome)
            settlements[#settlements + 1] = outcome
        end)

        assert.equals(1, #settlements)
        assert.equals("partial", settlements[1].kind)
        assert.same({ { id = "third", identity = { key = "/third" } } }, settlements[1].records)
        assert.equals(1, settlements[1].failed_root_count)
        assert.same({ "third" }, records)
        assert.same({ "/third" }, successful_roots[3])
    end)

    it("waits for scheduled adapter slices before finalizing", function()
        local acquire = acquisition({
            {
                root_ordinal = 1,
                status = "success",
                candidates = { { id = 1 }, { id = 2 } },
                failures = {},
            },
        })
        local pending = {}
        local finalized = 0
        local settled = 0

        finder_producer.run({
            roots = { {} },
            acquire = acquire,
            adapter = function(candidate) return { kind = "record", value = candidate } end,
            finalize = function(records)
                finalized = finalized + 1
                return records
            end,
            batch = {
                item_budget = 1,
                time_budget_ms = 5,
                now = function() return 0 end,
                schedule = function(callback) pending[#pending + 1] = callback end,
            },
        }, function() settled = settled + 1 end)

        assert.equals(0, finalized)
        assert.equals(0, settled)
        pending[1]()
        assert.equals(1, finalized)
        assert.equals(1, settled)
    end)

    it("contains producer and cache-hook exceptions as static kinds", function()
        local acquire = acquisition({
            {
                root_ordinal = 1,
                status = "success",
                candidates = { { id = 1 }, { id = 2 } },
                failures = {},
            },
        })
        local diagnostics = {}
        local outcome

        finder_producer.run({
            roots = { {} },
            acquire = acquire,
            adapter = function(candidate)
                if candidate.id == 1 then
                    error({ secret = string.rep("x", 1000) })
                end
                return { kind = "record", value = candidate }
            end,
            finalize = function(records) return records end,
            batch = immediate_batch(),
            on_record = function() error({ secret = "cache" }) end,
            on_root_success = function() error({ secret = "prune" }) end,
            diagnostic = function(kind) diagnostics[#diagnostics + 1] = kind end,
        }, function(value) outcome = value end)

        assert.equals("partial", outcome.kind)
        assert.equals(3, outcome.failed_record_count)
        assert.same({ finder_scan.FAILURE_KIND.producer_cache_hook_exception,
            finder_scan.FAILURE_KIND.producer_cache_hook_exception }, diagnostics)
        assert.same({ { id = 2 } }, outcome.records)
    end)

    it("turns acquisition and finalizer throws into bounded total failures", function()
        local outcomes = {}
        finder_producer.run({
            roots = { {}, {} },
            acquire = function() error({ secret = "acquire" }) end,
            adapter = function() end,
            finalize = function() end,
            batch = immediate_batch(),
        }, function(outcome) outcomes[#outcomes + 1] = outcome end)

        local acquire = acquisition({
            { root_ordinal = 1, status = "success", candidates = {}, failures = {} },
        })
        finder_producer.run({
            roots = { {} },
            acquire = acquire,
            adapter = function() end,
            finalize = function() error({ secret = "finalize" }) end,
            batch = immediate_batch(),
        }, function(outcome) outcomes[#outcomes + 1] = outcome end)

        assert.equals("failure", outcomes[1].kind)
        assert.equals(finder_scan.FAILURE_KIND.producer_acquire_exception, outcomes[1].diagnostics[1].kind)
        assert.equals("failure", outcomes[2].kind)
        assert.equals(finder_scan.FAILURE_KIND.producer_finalize_exception, outcomes[2].diagnostics[1].kind)
    end)

    it("cancels acquisition and pending batches once without settlement", function()
        local on_root
        local acquisition_cancel_count = 0
        local settle_count = 0
        local handle = finder_producer.run({
            roots = { {} },
            acquire = function(root_callback)
                on_root = root_callback
                return { cancel = function() acquisition_cancel_count = acquisition_cancel_count + 1 end }
            end,
            adapter = function(candidate) return { kind = "record", value = candidate } end,
            finalize = function(records) return records end,
            batch = immediate_batch(),
        }, function() settle_count = settle_count + 1 end)

        handle:cancel()
        handle:cancel()
        on_root({ root_ordinal = 1, status = "success", candidates = { {} }, failures = {} })

        assert.is_true(handle:is_cancelled())
        assert.equals(1, acquisition_cancel_count)
        assert.equals(0, settle_count)
    end)
end)
