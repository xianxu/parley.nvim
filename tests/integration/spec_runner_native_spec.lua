local Runner = require("tests.helpers.spec_runner")

describe("owned headless spec execution", function()
    local root
    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
    end)
    after_each(function() vim.fn.delete(root, "rf") end)

    local function run(lines, options)
        local path = root .. "/fixture.lua"
        vim.fn.writefile(lines, path)
        local output = {}
        options = vim.tbl_extend("force", { load1 = 0, ncpu = 12 }, options or {}, {
            output = function(stream, text) output[#output + 1] = stream .. ":" .. text end,
        })
        assert.is_function(Runner.execute)
        local result = Runner.execute(path, options)
        return result, table.concat(output)
    end

    it("executes real Plenary assertions and preserves ordinary output", function()
        local result, output = run({
            'describe("real child", function()',
            'it("passes", function() print("ordinary output"); assert.equals(2, 1 + 1) end)',
            'end)',
        })
        assert.equals(0, result.code)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("ordinary output", output, 1, true)
        assert.matches("Success", output, 1, true)
        assert.is_nil(output:find("PARLEY_CASE_", 1, true))
    end)

    it("retains an actual failed assertion and nonzero exit", function()
        local result, output = run({
            'describe("real child", function()',
            'it("fails", function() assert.equals("expected", "actual") end)',
            'end)',
        })
        assert.is_true(result.code ~= 0)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("actual", output, 1, true)
        assert.matches("Fail", output, 1, true)
    end)

    it("kills and reaps a stalled case after completed work", function()
        local result = run({
            'describe("real child", function()',
            'it("first", function() assert.is_true(true) end)',
            'it("stalled", function() vim.wait(15000, function() return false end, 10) end)',
            'end)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(1, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    it("enforces the absolute ceiling even while cases keep completing", function()
        local result = run({
            'describe("real child", function()',
            'for i = 1, 200 do it("progress " .. i, function() vim.wait(50, function() return false end, 10) end) end',
            'end)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("absolute-expired", result.reason)
        assert.is_true(result.completed > 1)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    it("does not let arbitrary bootstrap output keep a child alive", function()
        local result, output = run({
            'local timer = vim.uv.new_timer()',
            'timer:start(0, 50, function() io.stdout:write("Success || arbitrary output\\n"); io.stdout:flush() end)',
            'vim.wait(15000, function() return false end, 10)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("arbitrary output", output, 1, true)
    end)

    it("gives the absolute deadline precedence at controlled capped load", function()
        local result = run({
            'vim.wait(15000, function() return false end, 10)',
        }, { base_ms = 250, load1 = 100000, ncpu = 12 })
        assert.equals(124, result.code)
        assert.equals("absolute-expired", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
    end)

    it("includes after_each teardown in a case's progress boundary", function()
        local result, output = run({
            'describe("real child", function()',
            'after_each(function() vim.wait(15000, function() return false end, 10) end)',
            'it("body", function() io.stdout:write("BODY COMPLETED\\n"); io.stdout:flush() end)',
            'end)',
        }, { base_ms = 1000 })
        assert.equals(124, result.code)
        assert.equals("stalled", result.reason)
        assert.equals(0, result.completed)
        assert.is_true(result.reaped)
        local _, _, gone = vim.uv.kill(result.pid, 0)
        assert.equals("ESRCH", gone)
        assert.matches("BODY COMPLETED", output, 1, true)
    end)
end)
