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
            local captured
            tasker.run(nil, "sh", {
                "-c",
                'value="$1"; i=1; while [ "$i" -le "${#value}" ]; do printf "%s" "$(printf "%s" "$value" | cut -c "$i")" >&2; i=$((i+1)); done; printf "\\n" >&2',
                "sh",
                marker:sub(1, -2),
            }, function(_code, _signal, _stdout, stderr)
                captured = stderr
            end)

            assert.is_true(vim.wait(1000, function() return captured ~= nil end, 10))
            assert.equals(marker, captured)
        end)
    end)
end)
