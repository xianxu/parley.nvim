local chat_typing = require("tests.perf.chat_typing")

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

    it("aggregates observer work component-wise and resets every sample", function()
        local counter = chat_typing.new_counter()
        counter:observe({ phase = "edit_total", operation = "lines", lines_requested = 8,
            full_buffer = true, structure_rows_processed = 2 })
        counter:observe({ phase = "edit_total", operation = "line", lines_requested = 1,
            full_buffer = false, structure_rows_processed = 4 })
        assert.same({ line_read_calls = 2, lines_requested = 9, full_buffer_reads = 1,
            structure_rows_processed = 6 }, counter:snapshot())
        counter:reset()
        assert.same({ line_read_calls = 0, lines_requested = 0, full_buffer_reads = 0,
            structure_rows_processed = 0 }, counter:snapshot())

        assert.same({ line_read_calls = 4, lines_requested = 20, full_buffer_reads = 2,
            structure_rows_processed = 7 }, chat_typing.max_work({
            { line_read_calls = 4, lines_requested = 2, full_buffer_reads = 2, structure_rows_processed = 1 },
            { line_read_calls = 1, lines_requested = 20, full_buffer_reads = 0, structure_rows_processed = 7 },
        }))
    end)

    it("rejects invalid work samples before max aggregation", function()
        local invalid = {
            { line_read_calls = -1, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 },
            { line_read_calls = 1.5, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 },
            { line_read_calls = 1, lines_requested = 0, full_buffer_reads = 2, structure_rows_processed = 0 },
            { line_read_calls = 1, lines_requested = 0, full_buffer_reads = 0 },
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
        chat_typing.add_result(report, "edit_total", "inclusive", 100, { 1, 2 }, {
            line_read_calls = 1, lines_requested = 2, full_buffer_reads = 0, structure_rows_processed = 0,
        })
        chat_typing.add_result(report, "timezone_refresh", "isolated", 100, { 3, 4 }, {
            line_read_calls = 1, lines_requested = 100, full_buffer_reads = 1, structure_rows_processed = 0,
        })
        local decoded = vim.json.decode(require("tests.perf.harness").encode(report))
        assert.equals(1, decoded.schema_version)
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
        local report = chat_typing.new_report({ os = "test", nvim = "test", commit = "test" })
        for _, n in ipairs({ 1000, 5000 }) do
            chat_typing.add_result(report, "edit_total", "inclusive", n, { 1 }, {
                line_read_calls = 2, lines_requested = 88, full_buffer_reads = 0,
                structure_rows_processed = 1,
            })
            chat_typing.add_result(report, "decoration_redraw", "isolated", n, { 1 }, {
                line_read_calls = 1, lines_requested = 61, full_buffer_reads = 0,
                structure_rows_processed = 0,
            })
        end
        assert.has_no.errors(function() chat_typing.assert_hard_gates(report) end)
        report.scenarios[1].work.full_buffer_reads = 1
        local ok, err = pcall(chat_typing.assert_hard_gates, report)
        assert.is_false(ok)
        assert.matches("zero full%-buffer reads", err)
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
            if event.operation == "structure_replace" then structure_events[#structure_events + 1] = event end
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
        vim.fn.delete(output)
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
