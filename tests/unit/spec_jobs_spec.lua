-- #402: the runner signals a recorded job only while it is the same process.
local Jobs = require("tests.helpers.spec_jobs")
local identity = require("tests.helpers.process_identity")

describe("spec job registry", function()
    it("signals a job whose start time still matches, and skips a reused pid", function()
        local now = { [10] = "100.000001", [11] = "250.000000" }
        local targets, skipped = Jobs.targets({
            { pid = 10, start = "100.000001" }, -- the same process
            { pid = 11, start = "100.000002" }, -- the pid now belongs to another process
            { pid = 12, start = "100.000003" }, -- exited: nothing to do
        }, function(pid) return now[pid] end)
        assert.same({ 10 }, targets)
        assert.equals(1, #skipped)
        assert.equals(11, skipped[1].pid)
        assert.matches("pid reused", skipped[1].reason)
    end)

    it("reads only well-formed ledger lines", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        vim.fn.writefile({ "42 1792471551.495099", "garbage", "43", "-1 5.0", "44 7.000001 extra" }, dir .. "/jobs")
        local records = Jobs.read(dir)
        vim.fn.delete(dir, "rf")
        assert.same({ { pid = 42, start = "1792471551.495099" } }, records)
    end)

    it("knows this process's start time, and none for a missing pid", function()
        local own = vim.fn.getpid()
        assert.is_string(identity.start_time(own))
        assert.equals(identity.start_time(own), identity.start_time(own))
        assert.is_nil(identity.start_time(0))
        assert.is_nil(identity.start_time(2 ^ 30))
    end)
end)
