-- #220: a harness process whose parent is gone must exit on its own. Every
-- assertion here orphans a REAL process and waits for it to die; liveness is
-- probed with uv.kill(pid, 0), never `ps`, which an agent sandbox refuses.
local uv = vim.uv or vim.loop
local ROOT = vim.fn.getcwd()
local ORPHAN = ROOT .. "/tests/fixtures/orphan_me.sh"

--- True once `pid` no longer exists. Signal 0 checks for existence only, and
--- ESRCH is the answer that means "no such process" — EPERM would mean it lives
--- and is merely unsignallable. Same form as
--- tests/integration/process_group_conformance_spec.lua:9.
local function gone(pid)
    local _, _, name = uv.kill(pid, 0)
    return name == "ESRCH"
end

--- Start `argv` orphaned; return its pid.
local function orphan(argv, env)
    local pidfile = vim.fn.tempname()
    -- :wait(ms) always returns a table — on timeout it kills and reports 124 —
    -- so the exit code is the only thing worth asserting on.
    local done = vim.system(vim.list_extend({ ORPHAN, pidfile }, argv),
        env and { env = env } or {}):wait(5000)
    assert.equals(0, done.code, "orphan_me.sh failed: " .. tostring(done.stderr))
    assert.is_true(vim.wait(3000, function() return vim.fn.filereadable(pidfile) == 1 end, 20),
        "no pid was published")
    local pid = tonumber(vim.trim(table.concat(vim.fn.readfile(pidfile), "")))
    assert.is_truthy(pid, "unreadable pid")
    return pid
end

--- Fail unless `pid` exits within `ms`; always reap it, so a FAILING assertion
--- here cannot itself leak the process it is complaining about.
local function dies_within(pid, ms, what)
    local died = vim.wait(ms, function() return gone(pid) end, 100)
    pcall(function() uv.kill(pid, "sigkill") end)
    assert.is_true(died, what .. " (pid " .. pid .. ") outlived its parent by " .. ms .. "ms")
end

describe("#220 a harness process exits when its parent is gone", function()
    it("a spec-child Neovim does", function()
        local pid = orphan({ "nvim", "-n", "--headless", "--noplugin",
            "-u", ROOT .. "/tests/minimal_init.vim",
            "-c", "lua vim.wait(60000, function() return false end, 100)" })
        dies_within(pid, 6000, "an orphaned harness Neovim")
    end)
end)
