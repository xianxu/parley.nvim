-- Integration tests for tasker.run
--
-- tasker.run is the core subprocess execution function powering all LLM queries.
-- It spawns processes via uv.spawn, tracks PIDs, pipes stdout/stderr, and invokes callbacks.
--
-- Strategy: Use real shell commands (echo, printf) to test subprocess execution
-- without mocking uv.spawn. This verifies the actual libuv integration.

local tasker = require("parley.tasker")

describe("tasker.run integration", function()
    before_each(function()
        -- Clean up any stale handles before each test
        tasker._handles = {}
        tasker._queries = {}
    end)

    after_each(function()
        -- Stop any running processes
        tasker.stop()
        tasker._handles = {}
        tasker._uv = nil
    end)

    describe("Group A: Basic subprocess execution", function()
        it("A1: spawns process and captures stdout", function()
            local stdout_captured = nil
            local exit_called = false

            tasker.run(
                nil, -- buf
                "echo", -- cmd
                {"hello world"}, -- args
                function(code, signal, stdout_data, stderr_data) -- callback
                    exit_called = true
                    stdout_captured = stdout_data
                end,
                nil, -- out_reader
                nil  -- err_reader
            )

            -- Wait for process to complete
            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(exit_called, "Exit callback should be called")
            assert.is_true(stdout_captured:find("hello world") ~= nil,
                "Stdout should contain 'hello world', got: " .. tostring(stdout_captured))
        end)

        it("A2: spawns process and captures stderr", function()
            local stderr_captured = nil
            local exit_called = false

            -- Use a command that writes to stderr
            -- sh -c 'echo error >&2' redirects to stderr
            tasker.run(
                nil,
                "sh",
                {"-c", "echo error >&2"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                    stderr_captured = stderr_data
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(exit_called)
            assert.is_true(stderr_captured:find("error") ~= nil,
                "Stderr should contain 'error', got: " .. tostring(stderr_captured))
        end)

        it("A3: exit callback receives exit code", function()
            local exit_code = nil
            local exit_called = false

            -- Use 'false' command which exits with code 1
            tasker.run(
                nil,
                "sh",
                {"-c", "exit 42"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                    exit_code = code
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(exit_called)
            assert.equals(42, exit_code)
        end)
    end)

    describe("Group B: Stream readers (out_reader, err_reader)", function()
        it("B1: out_reader is called with stdout chunks", function()
            local chunks = {}
            local exit_called = false

            tasker.run(
                nil,
                "echo",
                {"test output"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                function(err, data) -- out_reader
                    if data then
                        table.insert(chunks, data)
                    end
                end,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(#chunks > 0, "out_reader should receive at least one chunk")
            local combined = table.concat(chunks, "")
            assert.is_true(combined:find("test output") ~= nil,
                "Combined chunks should contain 'test output', got: " .. combined)
        end)

        it("B2: err_reader is called with stderr chunks", function()
            local err_chunks = {}
            local exit_called = false

            tasker.run(
                nil,
                "sh",
                {"-c", "echo 'stderr test' >&2"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                nil,
                function(err, data) -- err_reader
                    if data then
                        table.insert(err_chunks, data)
                    end
                end
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(#err_chunks > 0, "err_reader should receive chunks")
            local combined = table.concat(err_chunks, "")
            assert.is_true(combined:find("stderr test") ~= nil)
        end)

        it("B3: out_reader receives nil on EOF", function()
            local got_nil = false
            local exit_called = false

            tasker.run(
                nil,
                "echo",
                {"test"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                function(err, data)
                    if data == nil then
                        got_nil = true
                    end
                end,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(got_nil, "out_reader should receive nil on EOF")
        end)
    end)

    describe("Group C: PID tracking and handle management", function()
        it("C1: adds handle with PID to _handles table", function()
            local initial_count = #tasker._handles
            local exit_called = false

            tasker.run(
                nil,
                "sleep",
                {"0.1"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                nil,
                nil
            )

            -- Check that handle was added (before process exits)
            vim.wait(100, function()
                return #tasker._handles > initial_count
            end, 10)

            assert.is_true(#tasker._handles > initial_count,
                "Handle should be added to _handles")

            -- Wait for completion
            vim.wait(1000, function()
                return exit_called
            end, 10)
        end)

        it("C2: removes handle from _handles on exit", function()
            local exit_called = false

            tasker.run(
                nil,
                "echo",
                {"quick"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                nil,
                nil
            )

            -- Wait for process to complete
            vim.wait(1000, function()
                return exit_called
            end, 10)

            -- Handle should be removed after exit
            assert.equals(0, #tasker._handles,
                "Handle should be removed from _handles after exit")
        end)

        it("C3: tracks buffer association in handle", function()
            local test_buf = vim.api.nvim_create_buf(false, true)
            local exit_called = false

            tasker.run(
                test_buf,
                "echo",
                {"test"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                nil,
                nil
            )

            -- Check handle has correct buffer
            vim.wait(100, function()
                for _, h in ipairs(tasker._handles) do
                    if h.buf == test_buf then
                        return true
                    end
                end
                return false
            end, 10)

            local found_buf = false
            for _, h in ipairs(tasker._handles) do
                if h.buf == test_buf then
                    found_buf = true
                    break
                end
            end

            assert.is_true(found_buf, "Handle should track buffer number")

            -- Wait for cleanup
            vim.wait(1000, function()
                return exit_called
            end, 10)

            vim.api.nvim_buf_delete(test_buf, {force = true})
        end)
    end)

    describe("Group D: Busy state prevention", function()
        it("D1: prevents multiple runs for same buffer", function()
            local test_buf = vim.api.nvim_create_buf(false, true)
            local first_exit = false
            local second_started = false

            -- Start first process (long-running)
            tasker.run(
                test_buf,
                "sleep",
                {"0.5"},
                function(code, signal, stdout_data, stderr_data)
                    first_exit = true
                end,
                nil,
                nil
            )

            -- Wait a bit to ensure first process started
            vim.wait(100, function() return false end, 10)

            -- Try to start second process for same buffer
            tasker.run(
                test_buf,
                "echo",
                {"should not run"},
                function(code, signal, stdout_data, stderr_data)
                    second_started = true
                end,
                nil,
                nil
            )

            -- Second process should not start
            assert.is_false(second_started,
                "Second process should not start when buffer is busy")

            -- Wait for first process to complete
            vim.wait(2000, function()
                return first_exit
            end, 10)

            vim.api.nvim_buf_delete(test_buf, {force = true})
        end)

        it("D2: allows run after previous process exits", function()
            local test_buf = vim.api.nvim_create_buf(false, true)
            local first_exit = false
            local second_exit = false

            -- Start and wait for first process
            tasker.run(
                test_buf,
                "echo",
                {"first"},
                function(code, signal, stdout_data, stderr_data)
                    first_exit = true
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return first_exit
            end, 10)

            assert.is_true(first_exit, "First process should complete")

            -- Now start second process
            tasker.run(
                test_buf,
                "echo",
                {"second"},
                function(code, signal, stdout_data, stderr_data)
                    second_exit = true
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return second_exit
            end, 10)

            assert.is_true(second_exit,
                "Second process should run after first completes")

            vim.api.nvim_buf_delete(test_buf, {force = true})
        end)
    end)

    describe("Group E: Data accumulation", function()
        it("E1: accumulates stdout data across multiple chunks", function()
            local stdout_data = nil
            local exit_called = false

            -- Output multiple lines to generate multiple chunks
            tasker.run(
                nil,
                "sh",
                {"-c", "echo line1; echo line2; echo line3"},
                function(code, signal, stdout, stderr)
                    exit_called = true
                    stdout_data = stdout
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(stdout_data:find("line1") ~= nil)
            assert.is_true(stdout_data:find("line2") ~= nil)
            assert.is_true(stdout_data:find("line3") ~= nil)
        end)

        it("E2: accumulates stderr data independently from stdout", function()
            local stdout_data = nil
            local stderr_data = nil
            local exit_called = false

            -- Write to both stdout and stderr
            tasker.run(
                nil,
                "sh",
                {"-c", "echo 'to stdout'; echo 'to stderr' >&2"},
                function(code, signal, stdout, stderr)
                    exit_called = true
                    stdout_data = stdout
                    stderr_data = stderr
                end,
                nil,
                nil
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(stdout_data:find("to stdout") ~= nil)
            assert.is_true(stderr_data:find("to stderr") ~= nil)
            -- Ensure separation
            assert.is_true(stdout_data:find("to stderr") == nil)
            assert.is_true(stderr_data:find("to stdout") == nil)
        end)
    end)

    describe("Group F: Cleanup and edge cases", function()
        it("F1: cleans up stale handles before spawning", function()
            -- This is tested implicitly by cleanup_stale_handles being called
            -- Just verify the function doesn't error
            local success = pcall(function()
                tasker.run(
                    nil,
                    "echo",
                    {"test"},
                    nil,
                    nil,
                    nil
                )
            end)

            assert.is_true(success, "Should not error during cleanup")

            -- Wait for process to complete
            vim.wait(1000, function()
                return #tasker._handles == 0
            end, 10)
        end)

        it("F2: handles nil callback gracefully", function()
            local completed = false

            -- No callback provided
            tasker.run(
                nil,
                "echo",
                {"no callback"},
                nil, -- nil callback
                nil,
                nil
            )

            -- Wait for process to complete (we can't check callback, but handles should clear)
            vim.wait(1000, function()
                return #tasker._handles == 0
            end, 10)

            -- If we get here without error, test passes
            completed = true
            assert.is_true(completed)
        end)

        it("F3: handles nil out_reader and err_reader gracefully", function()
            local exit_called = false

            tasker.run(
                nil,
                "echo",
                {"test"},
                function(code, signal, stdout_data, stderr_data)
                    exit_called = true
                end,
                nil, -- nil out_reader
                nil  -- nil err_reader
            )

            vim.wait(1000, function()
                return exit_called
            end, 10)

            assert.is_true(exit_called, "Should complete without out_reader/err_reader")
        end)
    end)

    describe("Group G: drain-safe terminal", function()
        local function fake_uv(opts)
            opts = opts or {}
            local state = { pipes = {}, spawn_calls = 0 }
            local runtime = {}
            runtime.new_pipe = function()
                local pipe = { closing = false, close_calls = 0 }
                pipe.read_stop = function() end
                pipe.is_closing = function(self) return self.closing end
                pipe.close = function(self)
                    self.closing = true
                    self.close_calls = self.close_calls + 1
                end
                table.insert(state.pipes, pipe)
                return pipe
            end
            runtime.spawn = function(_cmd, _spawn_opts, on_exit)
                state.spawn_calls = state.spawn_calls + 1
                state.on_exit = on_exit
                if opts.spawn_error then return nil, opts.spawn_error end
                local handle = { closing = false }
                handle.is_closing = function(self) return self.closing end
                handle.close = function(self) self.closing = true end
                state.handle = handle
                return handle, 4242
            end
            runtime.read_start = function(pipe, reader) pipe.reader = reader end
            return runtime, state
        end

        for _, case in ipairs({
            { name = "exit before both EOFs", exit_first = true },
            { name = "both EOFs before exit", exit_first = false },
        }) do
            it("coordinates " .. case.name .. " and schedules terminal once", function()
                local runtime, state = fake_uv()
                tasker._uv = runtime
                local events = {}
                local terminal
                tasker.run(nil, "fake", {}, function(code, signal, stdout, stderr, io_error)
                    table.insert(events, "terminal")
                    terminal = { code, signal, stdout, stderr, io_error }
                end, function(err, data)
                    table.insert(events, { stream = "stdout", err = err, data = data })
                end, function(err, data)
                    table.insert(events, { stream = "stderr", err = err, data = data })
                end)

                if case.exit_first then state.on_exit(0, 0) end
                state.pipes[1].reader(nil, "out")
                state.pipes[1].reader(nil, nil)
                assert.is_nil(terminal)
                state.pipes[2].reader(nil, "err")
                state.pipes[2].reader(nil, nil)
                if not case.exit_first then
                    assert.is_nil(terminal)
                    state.on_exit(0, 0)
                end
                assert.is_nil(terminal, "terminal must remain scheduled off the fast callback")
                assert.is_true(vim.wait(100, function() return terminal ~= nil end, 5))
                assert.same({ 0, 0, "out", "err" }, { terminal[1], terminal[2], terminal[3], terminal[4] })
                assert.is_nil(terminal[5])
                assert.equals("terminal", events[#events])
                assert.equals(1, vim.tbl_count(vim.tbl_filter(function(value)
                    return value == "terminal"
                end, events)))
                local final_by_stream = {}
                for _, event in ipairs(events) do
                    if type(event) == "table" then final_by_stream[event.stream] = event end
                end
                assert.is_nil(final_by_stream.stdout.err)
                assert.is_nil(final_by_stream.stdout.data)
                assert.is_nil(final_by_stream.stderr.err)
                assert.is_nil(final_by_stream.stderr.data)
            end)
        end

        it("forwards a read error then one final nil before the terminal", function()
            local runtime, state = fake_uv()
            tasker._uv = runtime
            local stdout_events = {}
            local terminal
            tasker.run(nil, "fake", {}, function(_code, _signal, stdout, _stderr, io_error)
                terminal = { stdout = stdout, io_error = io_error }
            end, function(err, data)
                table.insert(stdout_events, { err = err, data = data })
            end)

            state.pipes[1].reader(nil, "unterminated")
            state.pipes[1].reader("read boom", nil)
            state.pipes[1].reader(nil, nil) -- defensive late libuv delivery is ignored
            state.pipes[2].reader(nil, nil)
            state.on_exit(9, 0)
            assert.is_true(vim.wait(100, function() return terminal ~= nil end, 5))
            assert.equals(3, #stdout_events)
            assert.equals("read boom", stdout_events[2].err)
            assert.is_nil(stdout_events[2].data)
            assert.is_nil(stdout_events[3].err)
            assert.is_nil(stdout_events[3].data)
            assert.equals("unterminated", terminal.stdout)
            assert.is_truthy(terminal.io_error)
        end)

        it("rejects busy work before allocating pipes", function()
            local runtime, state = fake_uv()
            tasker._uv = runtime
            local original_is_busy = tasker.is_busy
            tasker.is_busy = function() return true end
            local starts = 0
            local terminals = 0
            tasker.run(9, "fake", {}, function() terminals = terminals + 1 end,
                nil, nil, function() starts = starts + 1 end)
            tasker.is_busy = original_is_busy
            assert.is_true(vim.wait(100, function() return starts == 1 end, 5))
            assert.equals(0, #state.pipes)
            assert.equals(0, state.spawn_calls)
            assert.equals(0, #tasker._handles)
            assert.equals(0, terminals)
        end)

        it("closes both pipes and reports one spawn rejection without a terminal", function()
            local runtime, state = fake_uv({ spawn_error = "ENOENT" })
            tasker._uv = runtime
            local starts = 0
            local terminals = 0
            tasker.run(nil, "fake", {}, function() terminals = terminals + 1 end,
                nil, nil, function() starts = starts + 1 end)
            assert.is_true(vim.wait(100, function() return starts == 1 end, 5))
            assert.equals(2, #state.pipes)
            assert.equals(1, state.pipes[1].close_calls)
            assert.equals(1, state.pipes[2].close_calls)
            assert.equals(0, #tasker._handles)
            assert.equals(0, terminals)
        end)

        it("G1: waits for both readers and preserves their final nil before terminal", function()
            local events = {}
            local stdout
            local stderr

            tasker.run(nil, "sh", { "-c", "printf out; printf err >&2" },
                function(code, signal, stdout_data, stderr_data, io_error)
                    table.insert(events, "terminal")
                    stdout = stdout_data
                    stderr = stderr_data
                    assert.equals(0, code)
                    assert.equals(0, signal)
                    assert.is_nil(io_error)
                end,
                function(err, data)
                    assert.is_nil(err)
                    table.insert(events, data and "stdout" or "stdout_eof")
                end,
                function(err, data)
                    assert.is_nil(err)
                    table.insert(events, data and "stderr" or "stderr_eof")
                end)

            assert.is_true(vim.wait(1000, function()
                return events[#events] == "terminal"
            end, 10))
            assert.equals("out", stdout)
            assert.equals("err", stderr)
            local before_terminal = { events[#events - 2], events[#events - 1] }
            table.sort(before_terminal)
            assert.same({ "stderr_eof", "stdout_eof" }, before_terminal)
        end)

        it("G2: schedules spawn rejection once and never calls terminal", function()
            local start_errors = 0
            local terminals = 0
            tasker.run(nil, "parley-command-that-does-not-exist", {}, function()
                terminals = terminals + 1
            end, nil, nil, function(message)
                start_errors = start_errors + 1
                assert.is_truthy(tostring(message):find("start", 1, true))
            end)

            assert.is_true(vim.wait(1000, function() return start_errors == 1 end, 10))
            assert.equals(0, terminals)
            assert.equals(0, #tasker._handles)
        end)

        it("G3: reconstructs a stderr trailer split at every byte", function()
            local marker = "__PARLEY_HTTP_split__503\n"
            for split = 0, #marker do
                local runtime, state = fake_uv()
                tasker._uv = runtime
                local captured
                tasker.run(nil, "fake", {}, function(_code, _signal, _stdout, stderr)
                    captured = stderr
                end)
                state.pipes[1].reader(nil, nil)
                if split > 0 then state.pipes[2].reader(nil, marker:sub(1, split)) end
                if split < #marker then state.pipes[2].reader(nil, marker:sub(split + 1)) end
                state.pipes[2].reader(nil, nil)
                state.on_exit(0, 0)
                assert.is_true(vim.wait(100, function() return captured ~= nil end, 5))
                assert.equals(marker, captured, "split boundary " .. split)
            end
        end)
    end)
end)
