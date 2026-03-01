-- Unit tests for logger module in lua/parley/logger.lua
--
-- The logger provides timestamped logging with:
-- - Log levels: error, warning, info, debug, trace
-- - Sensitive data redaction
-- - _log_history ring buffer (max 20 entries, excludes sensitive)
-- - Log file truncation at 20K lines
--
-- Strategy: Use unique tmp log file paths per test.
-- Reset module state via package.loaded removal between tests.

describe("logger", function()
    local logger
    local tmpdir
    local log_file

    before_each(function()
        -- Reset module state
        package.loaded["parley.logger"] = nil
        logger = require("parley.logger")

        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-logger-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
        log_file = tmpdir .. "/test.log"
    end)

    after_each(function()
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
    end)

    describe("Group A: M.now() timestamp format", function()
        it("A1: returns a string", function()
            local result = logger.now()
            assert.is_string(result)
        end)

        it("A2: matches expected pattern YYYY-MM-DD.HH-MM-SS.mmm", function()
            local result = logger.now()
            -- Pattern: 4digits-2digits-2digits.2digits-2digits-2digits.3digits
            assert.is_truthy(result:match("^%d%d%d%d%-%d%d%-%d%d%.%d%d%-%d%d%-%d%d%.%d%d%d$"))
        end)

        it("A3: millisecond portion is exactly 3 digits", function()
            local result = logger.now()
            local ms = result:match("%.(%d+)$")
            assert.equals(3, #ms)
        end)
    end)

    describe("Group B: log level functions write to file", function()
        before_each(function()
            logger.setup(log_file, false)
        end)

        it("B1: debug writes to log file with DEBUG level", function()
            logger.debug("test debug message")
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("DEBUG"))
            assert.is_truthy(content:find("test debug message"))
        end)

        it("B2: error writes to log file with ERROR level", function()
            logger.error("test error message")
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("ERROR"))
            assert.is_truthy(content:find("test error message"))
        end)

        it("B3: warning writes with WARNING level", function()
            logger.warning("test warning")
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("WARNING"))
        end)

        it("B4: info writes with INFO level", function()
            logger.info("test info")
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("INFO"))
        end)

        it("B5: trace writes with TRACE level", function()
            logger.trace("test trace")
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("TRACE"))
        end)
    end)

    describe("Group C: _log_history ring buffer", function()
        before_each(function()
            logger.setup(log_file, false)
        end)

        it("C1: non-sensitive messages are added to _log_history", function()
            logger.debug("history test")
            assert.is_true(#logger._log_history > 0)
            local found = false
            for _, entry in ipairs(logger._log_history) do
                if entry:find("history test") then
                    found = true
                    break
                end
            end
            assert.is_true(found)
        end)

        it("C2: _log_history is capped at 20 entries", function()
            for i = 1, 30 do
                logger.debug("msg " .. i)
            end
            assert.is_true(#logger._log_history <= 20)
        end)

        it("C3: sensitive messages are NOT added to _log_history", function()
            local before_count = #logger._log_history
            logger.debug("secret data", true)
            -- History should not grow for sensitive messages
            assert.equals(before_count, #logger._log_history)
        end)
    end)

    describe("Group D: sensitive data handling", function()
        it("D1: when store_sensitive=false, sensitive log contains REDACTED", function()
            logger.setup(log_file, false)
            logger.debug("my-api-key-12345", true)
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("REDACTED"))
            -- Should NOT contain the actual secret
            assert.is_falsy(content:find("my%-api%-key%-12345"))
        end)

        it("D2: when store_sensitive=true, sensitive log contains original message", function()
            logger.setup(log_file, true)
            logger.debug("my-api-key-12345", true)
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("my%-api%-key%-12345"))
        end)

        it("D3: sensitive messages are prefixed with [SENSITIVE DATA]", function()
            logger.setup(log_file, true)
            logger.debug("secret stuff", true)
            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("%[SENSITIVE DATA%]"))
        end)
    end)

    describe("Group E: setup", function()
        it("E1: creates log directory if it does not exist", function()
            local deep_dir = tmpdir .. "/deep/nested"
            local deep_log = deep_dir .. "/test.log"
            logger.setup(deep_log, false)
            assert.equals(1, vim.fn.isdirectory(deep_dir))
        end)

        it("E2: flushes _log_history to log file on setup", function()
            -- Log some messages before setup (they go to _log_history)
            package.loaded["parley.logger"] = nil
            logger = require("parley.logger")
            logger.debug("pre-setup message")

            -- Now setup with a real file
            logger.setup(log_file, false)

            local content = table.concat(vim.fn.readfile(log_file), "\n")
            assert.is_truthy(content:find("pre%-setup message"))
        end)

        it("E3: truncates log file when over 20K lines", function()
            -- Write a file with > 20K lines
            local f = io.open(log_file, "w")
            for i = 1, 25000 do
                f:write("line " .. i .. "\n")
            end
            f:close()

            -- Setup should truncate
            logger.setup(log_file, false)

            local lines = vim.fn.readfile(log_file)
            -- Should be roughly 10K lines (last 10K) plus the setup log messages
            assert.is_true(#lines < 15000)
            assert.is_true(#lines > 5000)
        end)
    end)
end)
