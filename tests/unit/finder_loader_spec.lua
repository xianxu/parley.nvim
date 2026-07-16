local finder_loader = require("parley.finder_loader")
local finder_scan = require("parley.finder_scan")

local function snapshot()
    return finder_scan.snapshot({
        kind = "test",
        roots = { { path = "/repo", label = "repo", primary = true } },
        recursion = true,
        max_depth = 2,
        pattern = "*.md",
        backend = {},
    })
end

local function success(records)
    return {
        kind = "success",
        records = records or {},
        successful_root_count = 1,
        skipped_root_count = 0,
        failed_root_count = 0,
        failed_record_count = 0,
        diagnostics = {},
        omitted_diagnostic_count = 0,
    }
end

describe("finder loading session", function()
    it("schedules terminal delivery before subscriber callbacks touch UI", function()
        local pending = {}
        local settle
        local delivered = 0
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            schedule = function(callback) pending[#pending + 1] = callback end,
            producer_factory = function(callback)
                settle = callback
                return { cancel = function() end }
            end,
        })
        session:subscribe(function() delivered = delivered + 1 end)
        session:start()

        settle(success())
        assert.equals(0, delivered)
        assert.is_false(session:is_settled())
        assert.equals(1, #pending)

        pending[1]()
        assert.equals(1, delivered)
        assert.is_true(session:is_settled())
    end)

    it("starts lazily, delivers a settlement turn once, and retires", function()
        local factory_count = 0
        local settle
        local events = {}
        local session
        session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            producer_factory = function(callback)
                factory_count = factory_count + 1
                settle = callback
                return { cancel = function() events[#events + 1] = "producer-cancel" end }
            end,
            on_terminal = function(_, had_subscribers)
                events[#events + 1] = "terminal:" .. tostring(had_subscribers)
            end,
            on_retire = function() events[#events + 1] = "retire" end,
        })
        session:subscribe(function(outcome)
            events[#events + 1] = "first:" .. outcome.records[1].id
            session:subscribe(function(replayed)
                events[#events + 1] = "during:" .. replayed.records[1].id
            end)
        end)

        assert.equals(0, factory_count)
        assert.is_false(session:is_settled())
        session:start()
        session:start()
        assert.equals(1, factory_count)
        settle(success({ { id = "record" } }))
        settle(success({ { id = "late" } }))

        assert.same({ "first:record", "during:record", "terminal:true", "retire" }, events)
        assert.is_true(session:is_settled())
        assert.is_true(session:is_retired())
        assert.equals(0, session:subscriber_count())
        local called = false
        local refused = session:subscribe(function() called = true end)
        assert.is_false(called)
        assert.is_true(refused:is_cancelled())
    end)

    it("exposes only defensive snapshot copies and a stable fingerprint", function()
        local scan_snapshot = snapshot()
        local session = finder_loader.new_session({
            snapshot = scan_snapshot,
            ownership = "picker",
            producer_factory = function() return { cancel = function() end } end,
        })
        local fingerprint = session:fingerprint()
        local copy = session:snapshot_copy()
        copy.roots[1].path = "/mutated"

        assert.equals(fingerprint, session:fingerprint())
        assert.equals("/repo", session:snapshot_copy().roots[1].path)
    end)

    it("cancels picker-owned work when its last subscriber leaves", function()
        local cancel_count = 0
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            producer_factory = function()
                return { cancel = function() cancel_count = cancel_count + 1 end }
            end,
        })
        local first = session:subscribe(function() end)
        local second = session:subscribe(function() end)
        session:start()

        first:cancel()
        assert.equals(0, cancel_count)
        second:cancel()
        second:cancel()

        assert.equals(1, cancel_count)
        assert.is_true(session:is_retired())
    end)

    it("keeps retained work alive without subscribers until owner cancellation", function()
        local cancel_count = 0
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "retained",
            producer_factory = function()
                return { cancel = function() cancel_count = cancel_count + 1 end }
            end,
        })
        local subscription = session:subscribe(function() end)
        session:start()
        subscription:cancel()
        assert.equals(0, cancel_count)
        assert.is_false(session:is_retired())

        session:cancel_owner()
        session:cancel_owner()
        assert.equals(1, cancel_count)
        assert.is_true(session:is_retired())
    end)

    it("isolates factory, subscriber, terminal, and retire exceptions", function()
        local diagnostics = {}
        local delivered = 0
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            producer_factory = function() error({ secret = "factory" }) end,
            on_terminal = function() error({ secret = "terminal" }) end,
            on_retire = function() error({ secret = "retire" }) end,
            diagnostic = function(kind) diagnostics[#diagnostics + 1] = kind end,
        })
        session:subscribe(function() error({ secret = "subscriber" }) end)
        session:subscribe(function(outcome)
            delivered = delivered + 1
            assert.equals("failure", outcome.kind)
        end)

        session:start()

        assert.equals(1, delivered)
        assert.is_true(session:is_retired())
        assert.same({
            finder_scan.FAILURE_KIND.producer_factory_exception,
            finder_scan.FAILURE_KIND.subscriber_exception,
            finder_scan.FAILURE_KIND.terminal_hook_exception,
            finder_scan.FAILURE_KIND.retire_hook_exception,
        }, diagnostics)
    end)
end)

describe("finder picker bridge", function()
    local function picker_fake()
        local state = { updates = {}, statuses = {}, query = "live query", closed = false }
        local picker = {
            update = function(items, tags)
                state.updates[#state.updates + 1] = { items = items, tags = tags }
            end,
            set_status = function(status) state.statuses[#state.statuses + 1] = status end,
            current_query = function() return state.query end,
            close = function() state.closed = true end,
            is_closed = function() return state.closed end,
        }
        return picker, state
    end

    it("opens and subscribes before the caller starts IO", function()
        local factory_count = 0
        local settle
        local picker, picker_state = picker_fake()
        local opened_options
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            producer_factory = function(callback)
                factory_count = factory_count + 1
                settle = callback
                return { cancel = function() end }
            end,
        })

        local binding = finder_loader.open_picker({
            session = session,
            picker_open = function(options)
                opened_options = options
                return picker
            end,
            picker_options = { title = "Finder", initial_query = "old" },
            materialize = function(outcome, query)
                assert.equals("live query", query)
                return { items = outcome.records, tags = { { label = "repo", enabled = true } } }
            end,
        })

        assert.equals(0, factory_count)
        assert.same({}, opened_options.items)
        assert.equals("scanning…", opened_options.status.message)
        assert.is_table(binding.subscription)
        session:start()
        settle(success({ { display = "record", value = 1 } }))

        assert.equals(1, factory_count)
        assert.same({ { display = "record", value = 1 } }, picker_state.updates[1].items)
        assert.equals("repo", picker_state.updates[1].tags[1].label)
    end)

    it("lets two subscribers materialize one retained outcome with distinct opener policy", function()
        local settle
        local recent_picker, recent_state = picker_fake()
        local all_picker, all_state = picker_fake()
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "retained",
            producer_factory = function(callback)
                settle = callback
                return { cancel = function() end }
            end,
        })
        local function bind(picker, cutoff)
            finder_loader.open_picker({
                session = session,
                picker_open = function() return picker end,
                picker_options = {},
                materialize = function(outcome)
                    local items = {}
                    for _, record in ipairs(outcome.records) do
                        if cutoff == nil or record.timestamp >= cutoff then
                            items[#items + 1] = record
                        end
                    end
                    return { items = items }
                end,
            })
        end
        bind(recent_picker, 50)
        bind(all_picker, nil)

        session:start()
        settle(success({
            { display = "recent", value = 1, timestamp = 100 },
            { display = "old", value = 2, timestamp = 10 },
        }))

        assert.same({ 1 }, vim.tbl_map(function(item) return item.value end, recent_state.updates[1].items))
        assert.same({ 1, 2 }, vim.tbl_map(function(item) return item.value end, all_state.updates[1].items))
    end)

    it("shows partial warnings and total errors without closing the picker", function()
        local settle
        local warning_count = 0
        local picker, picker_state = picker_fake()
        local session = finder_loader.new_session({
            snapshot = snapshot(),
            ownership = "picker",
            producer_factory = function(callback)
                settle = callback
                return { cancel = function() end }
            end,
        })
        finder_loader.open_picker({
            session = session,
            picker_open = function() return picker end,
            picker_options = { title = "Finder" },
            materialize = function(outcome) return { items = outcome.records } end,
            warning = function() warning_count = warning_count + 1 end,
        })
        session:start()
        settle({
            kind = "partial", records = {}, successful_root_count = 1,
            skipped_root_count = 0, failed_root_count = 1, failed_record_count = 2,
            diagnostics = {}, omitted_diagnostic_count = 0,
        })

        assert.equals(1, warning_count)
        assert.same({}, picker_state.updates[1].items)
        assert.is_false(picker_state.closed)

        local failure_settle
        local failure_picker, failure_state = picker_fake()
        local failure_session = finder_loader.new_session({
            snapshot = snapshot(), ownership = "picker",
            producer_factory = function(callback)
                failure_settle = callback
                return { cancel = function() end }
            end,
        })
        finder_loader.open_picker({
            session = failure_session,
            picker_open = function() return failure_picker end,
            picker_options = { title = "Finder" },
            materialize = function() error("must not materialize failure") end,
        })
        failure_session:start()
        failure_settle({ kind = "failure", failed_root_count = 1, failed_record_count = 0 })
		assert.equals("Finder: scan failed (roots: 1, files: 0)", failure_state.statuses[1].message)
        assert.is_false(failure_state.closed)
    end)

    it("contains a materializer exception to its picker binding", function()
        local settle
        local diagnostics = {}
        local first, first_state = picker_fake()
        local second, second_state = picker_fake()
        local session = finder_loader.new_session({
            snapshot = snapshot(), ownership = "retained",
            producer_factory = function(callback)
                settle = callback
                return { cancel = function() end }
            end,
            diagnostic = function(kind) diagnostics[#diagnostics + 1] = kind end,
        })
        finder_loader.open_picker({
            session = session,
            picker_open = function() return first end,
            picker_options = {},
            materialize = function() error({ secret = "materializer" }) end,
        })
        finder_loader.open_picker({
            session = session,
            picker_open = function() return second end,
            picker_options = {},
            materialize = function(outcome) return { items = outcome.records } end,
        })
        session:start()
        settle(success({ { display = "ok", value = 1 } }))

		assert.equals("Finder: scan failed (roots: 0, files: 0)", first_state.statuses[1].message)
        assert.same({ { display = "ok", value = 1 } }, second_state.updates[1].items)
        assert.same({ finder_scan.FAILURE_KIND.materializer_exception }, diagnostics)
    end)
end)
