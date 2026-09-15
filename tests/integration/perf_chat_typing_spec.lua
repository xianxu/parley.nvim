local chat_typing = require("tests.perf.chat_typing")

local function work(values)
    local result = {}
    for _, field in ipairs(require("tests.perf.harness").WORK_FIELDS) do result[field] = 0 end
    return vim.tbl_extend("force", result, values)
end

describe("chat typing performance scenario", function()
    it("builds the exact deterministic fixture shape", function()
        for _, n in ipairs({ 100, 1000, 5000 }) do
            local lines, target = chat_typing.build_fixture(n)
            assert.equals(n, #lines)
            assert.equals("# topic: perf", lines[1])
            assert.equals("- file: perf.md", lines[2])
            assert.equals("---", lines[3])
            assert.equals("", lines[4])
            assert.equals("💬: benchmark", lines[5])
            assert.equals("", lines[6])
            assert.equals("🤖: [Perf]", lines[7])
            assert.equals(math.floor(n * 0.8), target)
            assert.matches("benchmark prose row 31", lines[target], 1, true)
            assert.equals(lines[8], lines[68])
        end
    end)

    it("measures diagnostic publication and retains suffixes after structural repairs", function()
        local scenario = chat_typing.open_fixture(100)
        local phases = chat_typing.isolated_phases(scenario)
        local reader = require("parley.line_reader")
        local ok, err = pcall(function()
            for _, phase in ipairs({ "timezone_refresh", "footnote_refresh" }) do
                require("parley.diagnostic_refresh").clear(scenario.buf)
                local events = {}
                local token = reader.set_observer(scenario.buf, function(event)
                    events[#events + 1] = event
                end)
                phases[phase]()
                reader.clear_observer(scenario.buf, token)
                local rows = 0
                for _, event in ipairs(events) do rows = rows + (event.native_diagnostic_sets or 0) end
                assert.is_true(rows > 0, phase .. " did not measure completed diagnostic work")
            end
            for _ = 1, 3 do phases.structure_repair(); phases.structure_splice() end
        end)
        scenario:close()
        assert.is_true(ok, tostring(err))
    end)

    it("aggregates observer work component-wise and resets every sample", function()
        local counter = chat_typing.new_counter()
        counter:observe({ phase = "edit_total", operation = "lines", lines_requested = 8,
            full_buffer = true, structure_rows_processed = 2, structure_entries_copied = 3 })
        counter:observe({ phase = "edit_total", operation = "line", lines_requested = 1,
            full_buffer = false, structure_rows_processed = 4 })
        assert.same(work({ line_read_calls = 2, lines_requested = 9, full_buffer_reads = 1,
            structure_rows_processed = 6, structure_entries_copied = 3 }), counter:snapshot())
        counter:reset()
        assert.same(work({ line_read_calls = 0, lines_requested = 0, full_buffer_reads = 0,
            structure_rows_processed = 0, structure_entries_copied = 0 }), counter:snapshot())

        assert.same(work({ line_read_calls = 4, lines_requested = 20, full_buffer_reads = 2,
            structure_rows_processed = 7, structure_entries_copied = 9 }), chat_typing.max_work({
            work({ line_read_calls = 4, lines_requested = 2, full_buffer_reads = 2, structure_rows_processed = 1,
                structure_entries_copied = 9 }),
            work({ line_read_calls = 1, lines_requested = 20, full_buffer_reads = 0, structure_rows_processed = 7,
                structure_entries_copied = 0 }),
        }))
    end)

    it("sums each structural counter through the existing work observer", function()
        local reader = require("parley.line_reader")
        local counter = chat_typing.new_counter()
        local token = reader.set_observer(998877, function(e) counter:observe(e) end)
        local fields = { "bytes_read", "index_nodes_visited", "dependency_nodes_visited",
            "anchors_resolved", "fold_groups_visited", "native_fold_ops", "index_entries_visited",
            "metadata_values_copied", "summary_values_copied" }
        for _, field in ipairs(fields) do
            reader.record_work(998877, { [field] = 2 })
            reader.record_work(998877, { [field] = 3 })
        end
        reader.clear_buffer(998877)
        assert.is_table(token)
        for _, field in ipairs(fields) do assert.equals(5, counter:snapshot()[field]) end
    end)

    it("rejects invalid work samples before max aggregation", function()
        local invalid = {
            { line_read_calls = -1, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 },
            { line_read_calls = 1.5, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 },
            { line_read_calls = 1, lines_requested = 0, full_buffer_reads = 2, structure_rows_processed = 0 },
            { line_read_calls = 1, lines_requested = 0, full_buffer_reads = 0 },
            -- #227: the copy count is a required field, not an optional extra.
            { line_read_calls = 1, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 },
        }
        for _, sample in ipairs(invalid) do
            local ok, err = pcall(chat_typing.max_work, { sample })
            assert.is_false(ok)
            assert.matches("work sample", err)
        end
    end)

    it("excludes warmups from measured sample indexes", function()
        assert.is_nil(chat_typing.measured_index(1, 5))
        assert.is_nil(chat_typing.measured_index(5, 5))
        assert.equals(1, chat_typing.measured_index(6, 5))
        assert.equals(20, chat_typing.measured_index(25, 5))
    end)

    it("uses fresh LineReader observer tokens and phase attribution", function()
        local line_reader = require("parley.line_reader")
        local buf = 987654
        local events = {}
        local stale = line_reader.set_observer(buf, function(event) events[#events + 1] = event end)
        local current = line_reader.set_observer(buf, function(event) events[#events + 1] = event end)
        assert.is_false(line_reader.clear_observer(buf, stale))
        line_reader.with_phase(buf, "spell_typeahead", function()
            line_reader.record_work(buf, { operation = "probe", lines_requested = 1 })
        end)
        assert.equals("spell_typeahead", events[1].phase)
        assert.is_true(line_reader.clear_observer(buf, current))
        line_reader.record_work(buf, { operation = "after_clear" })
        assert.equals(1, #events)
        line_reader.clear_buffer(buf)
    end)

    it("keeps capture logic out of the default timed observer", function()
        local capture_factory_called = false
        local default = function() end
        local observer, captured = chat_typing.select_edit_observer(false, function()
            capture_factory_called = true
            error("default observer reached capture logic")
        end, function()
            return default, nil
        end)
        assert.is_false(capture_factory_called)
        assert.equals(default, observer)
        assert.is_nil(captured)
    end)

    it("rejects missing observer conditions with useful timeout diagnostics", function()
        local ok, err = pcall(chat_typing.assert_edit_observed, {
            changedtick = false, text_changed_i = 0, insert_mode = false, decoration_redraw = false,
        })
        assert.is_false(ok)
        assert.matches("changedtick", err)
        assert.matches("TextChangedI", err)
        assert.matches("insert mode", err)
        assert.matches("decoration_redraw", err)
    end)

    it("keeps inclusive and isolated JSON attribution explicit", function()
        local report = chat_typing.new_report({ os = "test", nvim = "test", commit = "test" })
        chat_typing.add_result(report, "edit_total", "inclusive", 100, { 1, 2 }, work({
            line_read_calls = 1, lines_requested = 2, full_buffer_reads = 0, structure_rows_processed = 0,
            structure_entries_copied = 0,
        }))
        chat_typing.add_result(report, "timezone_refresh", "isolated", 100, { 3, 4 }, work({
            line_read_calls = 1, lines_requested = 100, full_buffer_reads = 1, structure_rows_processed = 0,
            structure_entries_copied = 0,
        }))
        local decoded = vim.json.decode(require("tests.perf.harness").encode(report))
        assert.equals(4, decoded.schema_version)
        assert.equals("milliseconds", decoded.timing_unit)
        assert.equals("inclusive", decoded.scenarios[1].attribution)
        assert.equals("isolated", decoded.scenarios[2].attribution)
        assert.equals(2, decoded.scenarios[1].iteration_count)
    end)

    it("creates arbitrary PERF_OUTPUT parents", function()
        local root = vim.fn.tempname() .. "/nested/report"
        local path = root .. "/perf.json"
        chat_typing.write_report(path, "{}")
        assert.equals(1, vim.fn.filereadable(path))
        vim.fn.delete(vim.fn.fnamemodify(root, ":h:h"), "rf")
    end)

    it("enforces immutable full-read, scaling, and structure gates", function()
        local function valid_report()
            local report = chat_typing.new_report({ os = "test", nvim = "test", commit = "test" })
            for _, n in ipairs({ 1000, 5000 }) do
                chat_typing.add_result(report, "edit_total", "inclusive", n, { 1 }, work({
                    line_read_calls = 2, lines_requested = 88, full_buffer_reads = 0,
                    structure_rows_processed = 1, structure_entries_copied = 128, index_nodes_visited = 80,
                }))
                chat_typing.add_result(report, "decoration_redraw", "isolated", n, { 1 }, work({
                    line_read_calls = 1, lines_requested = 61, full_buffer_reads = 0,
                    structure_rows_processed = 0, structure_entries_copied = 0,
                }))
                chat_typing.add_result(report, "enter_join_total", "inclusive", n, { 1 }, work({
                    line_read_calls = 10, lines_requested = 178, full_buffer_reads = 0,
                    structure_rows_processed = 3, structure_entries_copied = 512, index_nodes_visited = 400,
                }))
                chat_typing.add_result(report, "structure_splice", "isolated", n, { 1 }, work({
                    line_read_calls = 2, lines_requested = 3, full_buffer_reads = 0,
                    structure_rows_processed = 6, structure_entries_copied = 512, index_nodes_visited = 400,
                }))
            end
            return report
        end
        local function scenario_of(report, phase, n)
            for _, scenario in ipairs(report.scenarios) do
                if scenario.phase == phase and scenario.line_count == n then return scenario end
            end
            error("no scenario " .. phase .. ":" .. n)
        end
        assert.has_no.errors(function() chat_typing.assert_hard_gates(valid_report()) end)

        local full_read = valid_report()
        full_read.scenarios[1].work.full_buffer_reads = 1
        local ok, err = pcall(chat_typing.assert_hard_gates, full_read)
        assert.is_false(ok)
        assert.matches("zero full%-buffer reads", err)

        local wrong_structure = valid_report()
        wrong_structure.scenarios[1].work.structure_rows_processed = 2
        ok, err = pcall(chat_typing.assert_hard_gates, wrong_structure)
        assert.is_false(ok)
        assert.matches("exactly one structure row", err)

        local unequal = valid_report()
        scenario_of(unequal, "edit_total", 5000).work.lines_requested = 89
        ok, err = pcall(chat_typing.assert_hard_gates, unequal)
        assert.is_false(ok)
        assert.matches("lines_requested must match", err)

        -- Local leaf-copy limits are gated, not merely reported.
        local copied = valid_report()
        scenario_of(copied, "edit_total", 1000).work.structure_entries_copied = 257
        ok, err = pcall(chat_typing.assert_hard_gates, copied)
        assert.is_false(ok)
        assert.matches("edit_total exceeds bounded structure copies", err)

        local splice_read = valid_report()
        scenario_of(splice_read, "structure_splice", 5000).work.full_buffer_reads = 1
        ok, err = pcall(chat_typing.assert_hard_gates, splice_read)
        assert.is_false(ok)
        assert.matches("structure_splice must perform zero full%-buffer reads", err)

        for _, copies in ipairs({ 2049, 0 }) do
            -- Over: unbounded work. Zero: actual splice copies disappeared
            -- from the observer.
            local miscounted = valid_report()
            scenario_of(miscounted, "structure_splice", 5000).work.structure_entries_copied = copies
            ok, err = pcall(chat_typing.assert_hard_gates, miscounted)
            assert.is_false(ok, tostring(copies))
            assert.matches("structure_splice must report bounded nonzero structure copies", err)
        end

        local viewport = valid_report()
        scenario_of(viewport, "enter_join_total", 5000).work.lines_requested = 513
        ok, err = pcall(chat_typing.assert_hard_gates, viewport)
        assert.is_false(ok)
        assert.matches("enter_join_total exceeds bounded viewport reads", err)

        local scaling = valid_report()
        scenario_of(scaling, "structure_splice", 5000).work.structure_rows_processed = 7
        ok, err = pcall(chat_typing.assert_hard_gates, scaling)
        assert.is_false(ok)
        assert.matches("structure_splice structure_rows_processed must match", err)

        for _, missing in ipairs({
            { phase = "edit_total", lines = 1000 },
            { phase = "edit_total", lines = 5000 },
            { phase = "decoration_redraw", lines = 1000 },
            { phase = "decoration_redraw", lines = 5000 },
            { phase = "structure_splice", lines = 1000 },
            { phase = "structure_splice", lines = 5000 },
            { phase = "enter_join_total", lines = 1000 },
            { phase = "enter_join_total", lines = 5000 },
        }) do
            local incomplete = chat_typing.new_report({ os = "test", nvim = "test", commit = "test" })
            for _, scenario in ipairs(valid_report().scenarios) do
                if scenario.phase ~= missing.phase or scenario.line_count ~= missing.lines then
                    chat_typing.add_result(incomplete, scenario.phase, scenario.attribution,
                        scenario.line_count, { 1 }, scenario.work)
                end
            end
            ok, err = pcall(chat_typing.assert_hard_gates, incomplete)
            assert.is_false(ok, missing.phase .. ":" .. missing.lines)
            assert.matches("requires " .. missing.phase .. " at " .. missing.lines .. " lines", err)
        end
    end)

    it("asserts direct range bounds for the measured TextChangedI", function()
        local output = vim.fn.tempname() .. ".json"
        local command = { "nvim", "-n", "--headless", "--noplugin", "-u", "tests/minimal_init.vim",
            "-c", "lua require('tests.perf.chat_typing').run_probe(" .. vim.fn.string(output) .. ")" }
        local raw = vim.fn.system(command)
        assert.equals(0, vim.v.shell_error, raw)
        local sample = vim.json.decode(table.concat(vim.fn.readfile(output), "\n"))
        local structure_events = {}
        local edit_reads = {}
        for _, event in ipairs(sample.read_events) do
            if (event.structure_rows_processed or 0) > 0 then structure_events[#structure_events + 1] = event end
            if event.phase == nil and (event.operation == "line" or event.operation == "lines") then
                edit_reads[#edit_reads + 1] = event
            end
            assert.is_false(event.full_buffer)
            if event.requested then
                assert.is_false(event.requested.start_row == 0 and event.requested.end_row == -1,
                    "managed-footer discovery must not issue a full-span read")
            end
        end
        assert.equals(1, #structure_events)
        assert.equals(1, structure_events[1].structure_rows_processed)
        assert.is_true(structure_events[1].index_nodes_visited > 0)
        assert.equals(2, #edit_reads)
        assert.same({ start_row = 79, end_row = 80, strict = false }, edit_reads[1].requested)
        assert.same({ row = 79 }, edit_reads[2].requested)
        assert.equals(1, edit_reads[1].lines_requested)
        assert.equals(1, edit_reads[2].lines_requested)
        vim.fn.delete(output)
    end)

    it("uses real input and production attachment for an edit sample", function()
        local output = vim.fn.tempname() .. ".json"
        local command = { "nvim", "-n", "--headless", "--noplugin", "-u", "tests/minimal_init.vim",
            "-c", "lua require('tests.perf.chat_typing').run_probe(" .. vim.fn.string(output) .. ")" }
        local raw = vim.fn.system(command)
        assert.equals(0, vim.v.shell_error, raw)
        local sample = vim.json.decode(table.concat(vim.fn.readfile(output), "\n"))
        assert.is_true(sample.attached)
        assert.is_true(sample.elapsed_ms >= 0)
        assert.equals(1, sample.text_changed_i)
        assert.is_true(sample.changedtick)
        assert.is_true(sample.decoration_redraw)
        assert.is_true(sample.insert_mode)
        assert.is_true(sample.restored)
        assert.equals(0, sample.work.full_buffer_reads)
        assert.equals(1, sample.work.structure_rows_processed)
        assert.is_true(sample.work.structure_entries_copied > 0 and sample.work.structure_entries_copied <= 256)
        assert.is_true(sample.work.index_nodes_visited > 0)
        vim.fn.delete(output)
    end)

    it("bounds real UI Enter and join at one and five thousand rows", function()
        for _, n in ipairs({1000,5000}) do
            local output=vim.fn.tempname()..".json"
            local code="require('tests.perf.chat_typing').run_probe("..vim.fn.string(output)
                ..",{line_count="..n..",enter_join=true})"
            local raw=vim.fn.system({"nvim","-n","--headless","--noplugin","-u","tests/minimal_init.vim","-c","lua "..code})
            assert.equals(0,vim.v.shell_error,raw)
            local sample=vim.json.decode(table.concat(vim.fn.readfile(output),"\n"))
            assert.equals(2,sample.text_changed_i)
            assert.is_true(sample.restored)
            assert.equals(n,sample.final_line_count)
            assert.equals(0,sample.work.full_buffer_reads)
            assert.is_true(sample.work.structure_entries_copied>0 and sample.work.structure_entries_copied<=2048)
            assert.is_true(sample.work.index_nodes_visited>0 and sample.work.index_nodes_visited<=8192)
            assert.is_true(sample.work.structure_rows_processed <= 8)
            vim.fn.delete(output)
        end
    end)

    it("terminates a failed async benchmark promptly with nonzero status", function()
        local lua = [[require('tests.perf.chat_typing').start({
            sizes={100}, warmups=0, iterations=1,
            measure_edit=function(_, _, done) done(nil, 'forced async failure') end,
        })]]
        local job = vim.fn.jobstart({ "nvim", "-n", "--headless", "--noplugin", "-u",
            "tests/minimal_init.vim", "-c", "lua " .. lua }, { stdout_buffered = true, stderr_buffered = true })
        assert.is_true(job > 0)
        local status = vim.fn.jobwait({ job }, 3000)[1]
        if status == -1 then vim.fn.jobstop(job) end
        assert.is_not.equals(-1, status, "failed benchmark hung instead of exiting")
        assert.is_not.equals(0, status, "failed benchmark exited successfully")
    end)
end)
