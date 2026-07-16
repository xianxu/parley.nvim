local finder_scan = require("parley.finder_scan")

describe("finder scan policy", function()
    describe("snapshot", function()
        local function options()
            return {
                kind = "markdown",
                roots = {
                    { path = "/repo-a", label = "alpha", primary = true },
                    { path = "/repo-b", label = "beta", primary = false },
                },
                recursion = true,
                max_depth = 6,
                pattern = "*.md",
                backend = { executable = "git", include_untracked = true },
            }
        end

        it("deep-copies construction input and every returned copy", function()
            local input = options()
            local snapshot = finder_scan.snapshot(input)

            input.roots[1].path = "/mutated-input"
            input.backend.executable = "other"
            local first = snapshot:copy()
            first.roots[2].label = "mutated-copy"
            first.backend.include_untracked = false

            assert.same(options(), snapshot:copy())
        end)

        it("rejects assignment without changing its fingerprint", function()
            local snapshot = finder_scan.snapshot(options())
            local fingerprint = snapshot:fingerprint()

            assert.has_error(function()
                snapshot.kind = "chat"
            end)
            assert.equals(fingerprint, snapshot:fingerprint())
            assert.equals(fingerprint, finder_scan.fingerprint(snapshot))
        end)

        it("includes every discovery field with ordered roots", function()
            local baseline = options()
            local fingerprint = finder_scan.snapshot(baseline):fingerprint()

            local mutations = {
                function(value) value.kind = "chat" end,
                function(value) value.roots[1].path = "/other" end,
                function(value) value.roots[1].label = "other" end,
                function(value) value.roots[1].primary = false end,
                function(value) value.roots[1], value.roots[2] = value.roots[2], value.roots[1] end,
                function(value) value.recursion = false end,
                function(value) value.max_depth = 5 end,
                function(value) value.pattern = "*.yaml" end,
                function(value) value.backend.executable = "other" end,
                function(value) value.backend.include_untracked = false end,
            }

            for _, mutate in ipairs(mutations) do
                local changed = options()
                mutate(changed)
                assert.are_not.equal(fingerprint, finder_scan.snapshot(changed):fingerprint())
            end
        end)

        it("uses length framing so values cannot collide at boundaries", function()
            local left = options()
            left.roots = { { path = "/a", label = "bc", primary = true } }
            local right = options()
            right.roots = { { path = "/ab", label = "c", primary = true } }

            assert.are_not.equal(
                finder_scan.snapshot(left):fingerprint(),
                finder_scan.snapshot(right):fingerprint()
            )
        end)
    end)

    describe("path identity", function()
        it("normalizes separators and lexical components without filesystem IO", function()
            assert.same({
                key = "/repo/docs/a.md",
                source = { root_ordinal = 2, unresolved = "/repo/docs/a.md" },
            }, finder_scan.path_identity({
                unresolved_absolute = "/repo/tmp/../docs\\a.md",
                root_ordinal = 2,
            }))
        end)

        it("prefers a supplied resolved path and falls back when absent", function()
            assert.equals("/real/a.md", finder_scan.path_identity({
                unresolved_absolute = "/alias/a.md",
                resolved_absolute = "/real/./a.md",
                root_ordinal = 1,
            }).key)
            assert.equals("/alias/a.md", finder_scan.path_identity({
                unresolved_absolute = "/alias/a.md",
                root_ordinal = 1,
            }).key)
        end)

        it("rejects relative or missing unresolved paths", function()
            assert.has_error(function()
                finder_scan.path_identity({ unresolved_absolute = "relative.md", root_ordinal = 1 })
            end)
            assert.has_error(function()
                finder_scan.path_identity({ root_ordinal = 1 })
            end)
        end)
    end)

    describe("deduplication and sorting", function()
        local function record(key, root_ordinal, unresolved, rank, name)
            return {
                identity = {
                    key = key,
                    source = { root_ordinal = root_ordinal, unresolved = unresolved },
                },
                rank = rank,
                name = name,
            }
        end

        it("chooses the minimum source tuple independent of arrival order", function()
            local later_root = record("/real/a.md", 2, "/z/a.md", 1, "later")
            local lexical_later = record("/real/a.md", 1, "/z/a.md", 1, "lexical-later")
            local winner = record("/real/a.md", 1, "/a/a.md", 1, "winner")

            assert.same({ winner }, finder_scan.deduplicate({ later_root, winner, lexical_later }))
            assert.same({ winner }, finder_scan.deduplicate({ lexical_later, later_root, winner }))
        end)

        it("sorts by primary policy and then bytewise identity key", function()
            local beta = record("/repo/b.md", 1, "/repo/b.md", 1, "beta")
            local alpha = record("/repo/a.md", 1, "/repo/a.md", 1, "alpha")
            local first = record("/repo/z.md", 1, "/repo/z.md", 0, "first")

            local sorted = finder_scan.sort({ beta, first, alpha }, function(left, right)
                return left.rank < right.rank
            end)

            assert.same({ first, alpha, beta }, sorted)
        end)

        it("does not mutate inputs", function()
            local one = record("/repo/a.md", 1, "/repo/a.md", 1, "one")
            local two = record("/repo/b.md", 1, "/repo/b.md", 0, "two")
            local input = { one, two }

            finder_scan.deduplicate(input)
            finder_scan.sort(input, function(left, right) return left.rank < right.rank end)

            assert.same({ one, two }, input)
        end)
    end)

    describe("scan outcomes", function()
        it("treats all absent optional roots as successful empty discovery", function()
            local acc = finder_scan.new_accumulator(2)
            finder_scan.root_skipped(acc, 1)
            finder_scan.root_skipped(acc, 2)

            assert.same({
                kind = "success",
                records = {},
                successful_root_count = 0,
                skipped_root_count = 2,
                failed_root_count = 0,
                failed_record_count = 0,
                diagnostics = {},
                omitted_diagnostic_count = 0,
            }, finder_scan.outcome(acc))
        end)

        it("returns partial records when some roots fail", function()
            local acc = finder_scan.new_accumulator(2)
            finder_scan.root_succeeded(acc, 2, { { id = "kept" } })
            finder_scan.root_failed(acc, 1, "root_enumeration", "denied")

            local outcome = finder_scan.outcome(acc)
            assert.equals("partial", outcome.kind)
            assert.same({ { id = "kept" } }, outcome.records)
            assert.equals(1, outcome.successful_root_count)
            assert.equals(1, outcome.failed_root_count)
            assert.equals(0, outcome.failed_record_count)
        end)

        it("returns partial empty records when an enumerated root loses records", function()
            local acc = finder_scan.new_accumulator(1)
            finder_scan.root_succeeded(acc, 1, {})
            finder_scan.record_failed(acc, "read", "unreadable")

            local outcome = finder_scan.outcome(acc)
            assert.equals("partial", outcome.kind)
            assert.same({}, outcome.records)
            assert.equals(0, outcome.failed_root_count)
            assert.equals(1, outcome.failed_record_count)
        end)

        it("returns failure only when every attempted root fails", function()
            local acc = finder_scan.new_accumulator(3)
            finder_scan.root_skipped(acc, 1)
            finder_scan.root_failed(acc, 2, "root_enumeration", "denied")
            finder_scan.root_failed(acc, 3, "root_enumeration", "missing backend")

            local outcome = finder_scan.outcome(acc)
            assert.equals("failure", outcome.kind)
            assert.is_nil(outcome.records)
            assert.equals(2, outcome.failed_root_count)
            assert.equals(1, outcome.skipped_root_count)
        end)

        it("rejects repeated root settlement", function()
            local acc = finder_scan.new_accumulator(1)
            finder_scan.root_succeeded(acc, 1, {})
            assert.has_error(function()
                finder_scan.root_failed(acc, 1, "root_enumeration", "late")
            end)
        end)
    end)

    describe("diagnostics", function()
        it("exports the one registered failure vocabulary", function()
            assert.same({
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
            }, finder_scan.FAILURE_KIND)
        end)

        it("replaces control characters and truncates at a UTF-8 boundary", function()
            assert.equals("one two three ", finder_scan.sanitize_diagnostic("one\ntwo\tthree\127"))
            assert.equals(string.rep("a", 511), finder_scan.sanitize_diagnostic(
                string.rep("a", 511) .. "😀tail",
                512
            ))
            assert.equals(string.rep("a", 510) .. "é", finder_scan.sanitize_diagnostic(
                string.rep("a", 510) .. "étail",
                512
            ))
        end)

        it("caps retained diagnostics and reports the omitted count", function()
            local acc = finder_scan.new_accumulator(1)
            finder_scan.root_succeeded(acc, 1, {})
            for index = 1, 12 do
                finder_scan.record_failed(acc, finder_scan.FAILURE_KIND.read, "failure " .. index)
            end

            local outcome = finder_scan.outcome(acc)
            assert.equals(10, #outcome.diagnostics)
            assert.equals(2, outcome.omitted_diagnostic_count)
            assert.equals("failure 1", outcome.diagnostics[1].message)
            assert.equals("failure 10", outcome.diagnostics[10].message)
        end)

        it("rejects unregistered failure kinds", function()
            local acc = finder_scan.new_accumulator(1)
            assert.has_error(function()
                finder_scan.record_failed(acc, "raw thrown value", "details")
            end)
        end)
    end)

    describe("slice batcher", function()
        local function scheduler()
            local pending = {}
            return pending, function(callback)
                pending[#pending + 1] = callback
            end
        end

        it("yields after the item budget and resumes without loss", function()
            local pending, schedule = scheduler()
            local results = {}
            local completed = 0
            local batcher = finder_scan.new_batcher({
                item_budget = 2,
                time_budget_ms = 100,
                now = function() return 0 end,
                schedule = schedule,
            })

            batcher:run({ 1, 2, 3, 4, 5 }, function(item)
                return { kind = "record", value = item * 10 }
            end, function(result)
                results[#results + 1] = result.value
            end, function()
                completed = completed + 1
            end)

            assert.same({ 10, 20 }, results)
            assert.equals(0, completed)
            pending[1]()
            assert.same({ 10, 20, 30, 40 }, results)
            assert.equals(0, completed)
            pending[2]()
            assert.same({ 10, 20, 30, 40, 50 }, results)
            assert.equals(1, completed)
        end)

        it("yields before the next record after the time budget", function()
            local pending, schedule = scheduler()
            local clock = 0
            local seen = {}
            local batcher = finder_scan.new_batcher({
                item_budget = 25,
                time_budget_ms = 5,
                now = function() return clock end,
                schedule = schedule,
            })

            batcher:run({ "first", "second" }, function(item)
                seen[#seen + 1] = item
                clock = clock + 5
                return { kind = "skip" }
            end, function() end, function() end)

            assert.same({ "first" }, seen)
            pending[1]()
            assert.same({ "first", "second" }, seen)
        end)

        it("contains adapter throws and invalid results as static failures", function()
            local results = {}
            local batcher = finder_scan.new_batcher({
                item_budget = 25,
                time_budget_ms = 5,
                now = function() return 0 end,
                schedule = function(callback) callback() end,
            })
            local thrown = { secret = string.rep("x", 1000) }

            batcher:run({ 1, 2, 3, 4 }, function(item)
                if item == 1 then
                    return { kind = "record", value = "ok" }
                elseif item == 2 then
                    return { kind = "failure", failure_kind = finder_scan.FAILURE_KIND.parse }
                elseif item == 3 then
                    return { kind = "failure", failure_kind = "unregistered" }
                end
                error(thrown)
            end, function(result)
                results[#results + 1] = result
            end, function() end)

            assert.same({
                { kind = "record", value = "ok" },
                { kind = "failure", failure_kind = "parse" },
                { kind = "failure", failure_kind = "invalid_adapter_result" },
                { kind = "failure", failure_kind = "adapter_exception" },
            }, results)
            for _, result in ipairs(results) do
                assert.is_nil(result.diagnostic)
            end
        end)

        it("cancels pending slices idempotently and suppresses completion", function()
            local pending, schedule = scheduler()
            local seen = {}
            local completed = 0
            local batcher = finder_scan.new_batcher({
                item_budget = 1,
                time_budget_ms = 5,
                now = function() return 0 end,
                schedule = schedule,
            })

            local handle = batcher:run({ 1, 2 }, function(item)
                return { kind = "record", value = item }
            end, function(result)
                seen[#seen + 1] = result.value
            end, function()
                completed = completed + 1
            end)
            handle:cancel()
            handle:cancel()
            pending[1]()

            assert.same({ 1 }, seen)
            assert.equals(0, completed)
            assert.is_true(handle:is_cancelled())
        end)
    end)
end)
