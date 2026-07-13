local harness = require("tests.perf.harness")

local M = {}

local WORK_FIELDS = {
    "line_read_calls", "lines_requested", "full_buffer_reads", "structure_rows_processed",
}

local function empty_work()
    return { line_read_calls = 0, lines_requested = 0, full_buffer_reads = 0, structure_rows_processed = 0 }
end

function M.build_fixture(n)
    assert(n >= 8, "fixture requires at least 8 lines")
    local lines = {
        "# topic: perf", "- file: perf.md", "---", "", "💬: benchmark", "", "🤖: [Perf]",
    }
    local target = math.floor(n * 0.8)
    for row = 8, n do
        local shape_row = ((row - target + 30) % 60) + 1
        lines[row] = string.format("benchmark prose row %02d near target %d", shape_row, target)
    end
    return lines, target
end

function M.new_counter()
    local values = empty_work()
    return {
        observe = function(_, event)
            values.line_read_calls = values.line_read_calls + 1
            values.lines_requested = values.lines_requested + (event.lines_requested or 0)
            values.full_buffer_reads = values.full_buffer_reads + (event.full_buffer and 1 or 0)
            values.structure_rows_processed = values.structure_rows_processed
                + (event.structure_rows_processed or 0)
        end,
        snapshot = function()
            return vim.deepcopy(values)
        end,
        reset = function()
            values = empty_work()
        end,
    }
end

function M.max_work(samples)
    local result = empty_work()
    for index, sample in ipairs(samples) do
        if type(sample) ~= "table" then
            error(string.format("work sample[%d] must be a table", index), 2)
        end
        for _, field in ipairs(WORK_FIELDS) do
            local value = sample[field]
            if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge
                or value < 0 or value % 1 ~= 0 then
                error(string.format("work sample[%d].%s must be a nonnegative integer", index, field), 2)
            end
            result[field] = math.max(result[field], value)
        end
        if sample.full_buffer_reads > sample.line_read_calls then
            error(string.format("work sample[%d].full_buffer_reads must not exceed line_read_calls", index), 2)
        end
    end
    return result
end

function M.measured_index(sequence_index, warmups)
    if sequence_index <= warmups then return nil end
    return sequence_index - warmups
end

function M.assert_edit_observed(observed)
    local missing = {}
    if not observed.changedtick then table.insert(missing, "changedtick") end
    if observed.text_changed_i ~= 1 then table.insert(missing, "exactly one TextChangedI") end
    if not observed.insert_mode then table.insert(missing, "insert mode") end
    if not observed.decoration_redraw then table.insert(missing, "decoration_redraw") end
    if #missing > 0 then
        error("timed edit missing condition(s): " .. table.concat(missing, ", "), 2)
    end
end

function M.new_report(environment)
    return harness.new_report(environment)
end

function M.add_result(report, phase, attribution, line_count, samples, work)
    local summary = harness.summarize(samples)
    harness.add_scenario(report, {
        name = "parley_chat_typing", phase = phase, attribution = attribution,
        line_count = line_count, iteration_count = #samples,
        elapsed_ms = { samples = samples, median = summary.median, p95 = summary.p95 },
        work = work,
    })
end

function M.write_report(path, encoded)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    local ok, err = pcall(vim.fn.writefile, { encoded }, path)
    if not ok then error("could not write performance report " .. path .. ": " .. tostring(err), 2) end
end

local setup_root
local function ensure_setup()
    if setup_root then return setup_root end
    setup_root = (os.getenv("TMPDIR") or "/tmp") .. "/parley-chat-typing-" .. vim.fn.getpid()
    vim.fn.mkdir(setup_root .. "/chats", "p")
    vim.fn.mkdir(setup_root .. "/state", "p")
    require("parley").setup({
        chat_dir = setup_root .. "/chats",
        state_dir = setup_root .. "/state",
        providers = {},
        api_keys = {},
        chat_spell = { enable = false, typeahead = true, min_word = 4, max_suggest = 9 },
    })
    return setup_root
end

function M.open_fixture(n)
    local root = ensure_setup()
    local lines, target = M.build_fixture(n)
    local path = string.format("%s/chats/2026-07-12-perf-%d.md", root, n)
    vim.fn.writefile(lines, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.bo.filetype = "markdown"
    vim.cmd("doautocmd BufEnter")
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.wait(1000, function() return require("parley")._parley_bufs[buf] == "chat" end, 1),
        "production chat handlers did not attach: " .. tostring(require("parley").not_chat(buf, path)))
    vim.api.nvim_win_set_cursor(0, { target, #lines[target] })
    local scenario = {
        buf = buf, path = path, line_count = n, target_line = target, original_line = lines[target],
    }
    function scenario:close()
        if vim.api.nvim_buf_is_valid(self.buf) then
            pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
        end
        pcall(vim.fn.delete, self.path)
    end
    return scenario
end

local function feed(keys, mode)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), mode or "xt", false)
end

function M.measure_edit_sample(scenario, opts, done)
    opts = opts or {}
    assert(type(done) == "function", "measure_edit_sample requires an async completion callback")
    local timeout_ms = opts.timeout_ms or 1000
    local buf = scenario.buf
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_win_set_cursor(0, { scenario.target_line, #scenario.original_line })
    vim.cmd("redraw")
    -- prep_chat deliberately queues an <Esc>; flush all production setup input
    -- before the sample so it cannot consume the measured insert transition.
    vim.api.nvim_feedkeys("", "x", false)
    vim.wait(20, function() return false end, 1)
    vim.api.nvim_feedkeys("", "x", false)
    local deadline = vim.uv.hrtime() + timeout_ms * 1000000
    local function poll(predicate, label, callback)
        if predicate() then return callback() end
        if vim.uv.hrtime() >= deadline then
            local detail = type(label) == "function" and label() or label
            return done(nil, "timed edit timeout: " .. detail)
        end
        vim.defer_fn(function() poll(predicate, label, callback) end, 1)
    end
    vim.schedule(function()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i", true, false, true), "t", false)
        poll(function() return vim.api.nvim_get_mode().mode:sub(1, 1) == "i" end, "insert mode", function()
            local initial_tick = vim.api.nvim_buf_get_changedtick(buf)
            local text_changed_i = 0
            local group = vim.api.nvim_create_augroup("ParleyPerfObserver_" .. buf, { clear = true })
            vim.api.nvim_create_autocmd("TextChangedI", { group = group, buffer = buf,
                callback = function() text_changed_i = text_changed_i + 1 end })
            local line_reader = require("parley.line_reader")
            local counter = M.new_counter()
            local decoration_redraw = false
            line_reader.clear_buffer(buf)
            local token = line_reader.set_observer(buf, function(event)
                counter:observe(event)
                if event.phase == "decoration_redraw" then decoration_redraw = true end
            end)
            local started = vim.uv.hrtime()
            feed("X", "t")
            poll(function()
                return vim.api.nvim_buf_get_changedtick(buf) ~= initial_tick and text_changed_i == 1
                    and vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
            end, function() return string.format(
                "changedtick + exactly one TextChangedI while in insert mode (tick=%d, event=%d, mode=%s)",
                vim.api.nvim_buf_get_changedtick(buf) - initial_tick, text_changed_i, vim.api.nvim_get_mode().mode)
            end, function()
                vim.cmd("redraw!")
                poll(function() return decoration_redraw end, "decoration_redraw", function()
                    local observed = { changedtick = true, text_changed_i = text_changed_i,
                        insert_mode = true, decoration_redraw = true,
                        elapsed_ms = (vim.uv.hrtime() - started) / 1000000, work = counter:snapshot() }
                    line_reader.clear_observer(buf, token)
                    vim.api.nvim_del_augroup_by_id(group)
                    local insert_leave = false
                    local leave_group = vim.api.nvim_create_augroup("ParleyPerfLeave_" .. buf, { clear = true })
                    vim.api.nvim_create_autocmd("InsertLeave", { group = leave_group, buffer = buf, once = true,
                        callback = function() insert_leave = true end })
                    feed("<Esc>", "t")
                    poll(function()
                        return insert_leave and vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i"
                    end, "normal mode + InsertLeave convergence", function()
                        vim.api.nvim_del_augroup_by_id(leave_group)
                        vim.api.nvim_buf_set_lines(buf, scenario.target_line - 1, scenario.target_line, false,
                            { scenario.original_line })
                        done(observed)
                    end)
                end)
            end)
        end)
    end)
end

function M.run_probe(output)
    local scenario = M.open_fixture(100)
    M.measure_edit_sample(scenario, { timeout_ms = 1000 }, function(sample, err)
        if not sample then
            vim.fn.writefile({ tostring(err) }, output)
            vim.cmd("cquit 1")
            return
        end
        sample.attached = require("parley")._parley_bufs[scenario.buf] == "chat"
        sample.restored = scenario.original_line == vim.api.nvim_buf_get_lines(scenario.buf,
            scenario.target_line - 1, scenario.target_line, false)[1]
        scenario:close()
        M.write_report(output, vim.json.encode(sample))
        vim.cmd("qa!")
    end)
end

local function measure_isolated(scenario, phase, fn)
    local line_reader = require("parley.line_reader")
    local counter = M.new_counter()
    line_reader.clear_buffer(scenario.buf)
    local token = line_reader.set_observer(scenario.buf, function(event) counter:observe(event) end)
    local started = vim.uv.hrtime()
    line_reader.with_phase(scenario.buf, phase, fn)
    local elapsed = (vim.uv.hrtime() - started) / 1000000
    line_reader.clear_observer(scenario.buf, token)
    return elapsed, counter:snapshot()
end

local function isolated_phases(scenario)
    local buf = scenario.buf
    local reader = require("parley.line_reader").for_buffer(buf)
    return {
        timezone_refresh = function() require("parley.timezone_diagnostics").refresh_buffer(buf, { reader = reader }) end,
        footnote_refresh = function() require("parley.skill_render").refresh_footnote_diagnostics(buf, { reader = reader }) end,
        decoration_redraw = function()
            local win = vim.api.nvim_get_current_win()
            local top = math.max(0, scenario.target_line - 20)
            require("parley.highlighter")._compute_window_decorations(win, buf, top, top + 40, reader)
        end,
        spell_typeahead = function() require("parley.spell").suggest({ reader = reader }) end,
    }
end

local function environment()
    local version = vim.version()
    return {
        os = (vim.uv.os_uname() or {}).sysname or "unknown",
        nvim = string.format("%d.%d.%d", version.major, version.minor, version.patch),
        commit = vim.fn.systemlist({ "git", "rev-parse", "HEAD" })[1] or "unknown",
    }
end

function M.start(opts)
    opts = opts or {}
    local warmups = opts.warmups or 5
    local iterations = opts.iterations or 20
    local report = M.new_report(environment())
    local sizes = opts.sizes or { 100, 1000, 5000 }
    local measure_edit = opts.measure_edit or M.measure_edit_sample
    local size_index = 0
    local active_scenario
    local failed = false
    local function fatal(err)
        if failed then return end
        failed = true
        local buf = active_scenario and active_scenario.buf
        if buf then
            require("parley.line_reader").clear_buffer(buf)
            pcall(vim.api.nvim_del_augroup_by_name, "ParleyPerfObserver_" .. buf)
            pcall(vim.api.nvim_del_augroup_by_name, "ParleyPerfLeave_" .. buf)
            require("parley")._parley_bufs[buf] = nil
        end
        pcall(vim.cmd, "stopinsert")
        if active_scenario then
            pcall(active_scenario.close, active_scenario)
            active_scenario = nil
        end
        vim.api.nvim_err_writeln("parley chat typing benchmark failed: " .. tostring(err))
        vim.cmd("cquit 1")
    end
    local function guarded(fn)
        vim.schedule(function()
            local ok, err = xpcall(fn, debug.traceback)
            if not ok then fatal(err) end
        end)
    end
    local function finish()
        local output = opts.output or os.getenv("PERF_OUTPUT") or ".test-tmp/perf/parley-chat-typing.json"
        M.write_report(output, harness.encode(report))
        print(harness.render_table(report))
        print("JSON: " .. output)
        if opts.on_done then opts.on_done(report) else vim.cmd("qa!") end
    end
    local function next_size()
        size_index = size_index + 1
        local n = sizes[size_index]
        if not n then return finish() end
        local scenario = M.open_fixture(n)
        active_scenario = scenario
        local samples, work = {}, {}
        local edit_index = 0
        local safe_edit_done
        local function edit_done(sample, err)
            if not sample then return fatal(err) end
            edit_index = edit_index + 1
            local measured = M.measured_index(edit_index, warmups)
            if measured then
                samples[measured], work[measured] = sample.elapsed_ms, sample.work
            end
            if edit_index < warmups + iterations then
                return measure_edit(scenario, nil, safe_edit_done)
            end
            M.add_result(report, "edit_total", "inclusive", n, samples, M.max_work(work))
            for phase, fn in pairs(isolated_phases(scenario)) do
                for _ = 1, warmups do measure_isolated(scenario, phase, fn) end
                local phase_samples, phase_work = {}, {}
                for index = 1, iterations do
                    phase_samples[index], phase_work[index] = measure_isolated(scenario, phase, fn)
                end
                M.add_result(report, phase, "isolated", n, phase_samples, M.max_work(phase_work))
            end
            scenario:close()
            active_scenario = nil
            guarded(next_size)
        end
        safe_edit_done = function(...)
            local args = { n = select("#", ...), ... }
            local ok, err = xpcall(function() edit_done(unpack(args, 1, args.n)) end, debug.traceback)
            if not ok then fatal(err) end
        end
        measure_edit(scenario, nil, safe_edit_done)
    end
    guarded(next_size)
end

return M
