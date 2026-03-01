-- Unit tests for tasker module in lua/parley/tasker.lua
--
-- Covers pure-logic functions not tested in integration tests:
-- - M.once: wraps function to fire only once
-- - M.cleanup_old_queries: prunes old query entries
-- - M.set_query / M.get_query: query storage
-- - M.set_cache_metrics / M.get_cache_metrics: metrics storage

local tasker = require("parley.tasker")

describe("tasker", function()
    describe("Group A: M.once", function()
        it("A1: wrapped function called first time returns result", function()
            local fn = tasker.once(function(x)
                return x * 2
            end)
            -- Note: once wraps with no return, so we track via side effects
            local called = 0
            local fn2 = tasker.once(function()
                called = called + 1
            end)
            fn2()
            assert.equals(1, called)
        end)

        it("A2: wrapped function called second time does nothing", function()
            local called = 0
            local fn = tasker.once(function()
                called = called + 1
            end)
            fn()
            fn()
            fn()
            assert.equals(1, called)
        end)

        it("A3: arguments are passed through on first call", function()
            local received_args = {}
            local fn = tasker.once(function(a, b, c)
                received_args = { a, b, c }
            end)
            fn("x", "y", "z")
            assert.same({ "x", "y", "z" }, received_args)
        end)
    end)

    describe("Group B: cleanup_old_queries", function()
        before_each(function()
            -- Clear queries
            tasker._queries = {}
        end)

        it("B1: does nothing when query count <= N", function()
            tasker._queries = {
                q1 = { timestamp = os.time(), payload = {} },
                q2 = { timestamp = os.time(), payload = {} },
            }
            tasker.cleanup_old_queries(5, 60)
            -- Both queries should still exist
            assert.is_not_nil(tasker._queries.q1)
            assert.is_not_nil(tasker._queries.q2)
        end)

        it("B2: removes queries older than age seconds", function()
            local now = os.time()
            tasker._queries = {
                old = { timestamp = now - 120, payload = {} },
                new = { timestamp = now, payload = {} },
            }
            tasker.cleanup_old_queries(0, 60) -- N=0 forces cleanup, age=60s
            assert.is_nil(tasker._queries.old)
            assert.is_not_nil(tasker._queries.new)
        end)

        it("B3: keeps queries newer than age seconds", function()
            local now = os.time()
            tasker._queries = {
                recent = { timestamp = now - 10, payload = {} },
            }
            tasker.cleanup_old_queries(0, 60)
            assert.is_not_nil(tasker._queries.recent)
        end)

        it("B4: handles empty _queries table", function()
            tasker._queries = {}
            -- Should not error
            local ok = pcall(tasker.cleanup_old_queries, 10, 60)
            assert.is_true(ok)
        end)
    end)

    describe("Group C: set_query + get_query", function()
        before_each(function()
            tasker._queries = {}
        end)

        it("C1: set_query stores payload with timestamp", function()
            tasker.set_query("test-qid", { model = "gpt-4" })
            local entry = tasker._queries["test-qid"]
            assert.is_not_nil(entry)
            assert.is_not_nil(entry.timestamp)
            assert.equals("gpt-4", entry.model)
        end)

        it("C2: get_query retrieves stored payload", function()
            tasker.set_query("test-qid", { model = "gpt-4" })
            local result = tasker.get_query("test-qid")
            assert.is_not_nil(result)
            assert.equals("gpt-4", result.model)
        end)

        it("C3: get_query returns nil for non-existent qid", function()
            local result = tasker.get_query("nonexistent")
            assert.is_nil(result)
        end)
    end)

    describe("Group D: set_cache_metrics + get_cache_metrics", function()
        it("D1: set_cache_metrics updates all three fields", function()
            tasker.set_cache_metrics({ input = 100, creation = 50, read = 25 })
            local metrics = tasker.get_cache_metrics()
            assert.equals(100, metrics.input)
            assert.equals(50, metrics.creation)
            assert.equals(25, metrics.read)
        end)

        it("D2: get_cache_metrics returns copy, not reference", function()
            tasker.set_cache_metrics({ input = 100, creation = 50, read = 25 })
            local m1 = tasker.get_cache_metrics()
            local m2 = tasker.get_cache_metrics()
            m1.input = 999
            assert.equals(100, m2.input) -- m2 should be unaffected
        end)

        it("D3: setting nil values clears fields", function()
            tasker.set_cache_metrics({ input = 100, creation = 50, read = 25 })
            tasker.set_cache_metrics({ input = nil, creation = nil, read = nil })
            local metrics = tasker.get_cache_metrics()
            assert.is_nil(metrics.input)
            assert.is_nil(metrics.creation)
            assert.is_nil(metrics.read)
        end)
    end)
end)
