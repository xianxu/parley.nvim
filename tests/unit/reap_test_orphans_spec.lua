-- #220: the census that makes the leak visible. Driven with --ps-from, which
-- injects a process table and signals nothing.
local SCRIPT = vim.fn.getcwd() .. "/scripts/reap-test-orphans.py"
local TABLE = vim.fn.getcwd() .. "/tests/fixtures/ps_test_orphans.txt"
local ROOT = "/Users/x/workspace/parley.nvim"

local function run(root, phase, extra)
    local argv = { "python3", SCRIPT, "--root", root, "--phase", phase,
        "--ps-from", TABLE, "--self-pid", "99998" }
    return vim.system(vim.list_extend(argv, extra or {}), { text = true }):wait(10000)
end

describe("#220 orphan census", function()
    it("selects exactly this checkout's leaked harness processes", function()
        local out = run(ROOT, "after", { "--grace", "0" })
        assert.equals(1, out.code, "survivors must fail the run")
        assert.is_truthy(out.stdout:find("2 test process(es)", 1, true), out.stdout)
        assert.is_truthy(out.stdout:find("7458", 1, true), "the fixture orphan")
        assert.is_truthy(out.stdout:find("27095", 1, true), "the spec-child orphan")
    end)

    it("leaves another checkout's processes alone", function()
        assert.is_falsy(run(ROOT, "after", { "--grace", "0" }).stdout:find("31000", 1, true))
    end)

    it("leaves an editor open on a spec file alone", function()
        assert.is_falsy(run(ROOT, "after", { "--grace", "0" }).stdout:find("31001", 1, true))
    end)

    it("never selects itself or the recipe that invoked it", function()
        local out = run(ROOT, "after", { "--grace", "0" })
        assert.is_falsy(out.stdout:find("99999", 1, true), "the invoking recipe")
        assert.is_falsy(out.stdout:find("99998", 1, true), "the census itself")
    end)

    it("passes when the table holds none of this checkout's processes", function()
        assert.equals(0, run("/Users/x/workspace/elsewhere", "after", { "--grace", "0" }).code)
    end)

    it("reports but never fails the run in the before phase", function()
        local out = run(ROOT, "before", { "--grace", "0" })
        assert.equals(0, out.code)
        assert.is_truthy(out.stdout:find("earlier run", 1, true))
        assert.is_truthy(out.stdout:find("7458", 1, true), out.stdout)
    end)

    it("fails loudly when ps ran but its columns cannot be read", function()
        local garbage = vim.fn.tempname()
        vim.fn.writefile({ "USER PID %CPU COMMAND", "xianxu 1 0.0 /sbin/launchd" }, garbage)
        local out = vim.system({ "python3", SCRIPT, "--root", ROOT, "--phase", "after",
            "--ps-from", garbage, "--self-pid", "99998" }, { text = true }):wait(10000)
        vim.fn.delete(garbage)
        assert.equals(1, out.code)
        assert.is_truthy(out.stdout:find("BROKEN", 1, true), out.stdout)
    end)

    it("skips visibly, and passes, where ps is refused", function()
        local out = vim.system({ "python3", SCRIPT, "--root", vim.fn.getcwd(),
            "--phase", "after", "--ps-command", "/nonexistent/ps" },
            { text = true }):wait(10000)
        assert.equals(0, out.code)
        assert.is_truthy(out.stdout:lower():find("skipped", 1, true))
    end)
end)
