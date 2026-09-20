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

    it("the fake_cliproxy fixture does", function()
        local port = require("tests.helpers.ready_port").free_port()
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_cliproxy",
            "--port", tostring(port) })
        dies_within(pid, 6000, "an orphaned fake_cliproxy")
    end)

    it("the fake_github_releases fixture does", function()
        local port = require("tests.helpers.ready_port").free_port()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_github_releases",
            "--port", tostring(port), "--root", root })
        dies_within(pid, 6000, "an orphaned fake_github_releases")
    end)

    it("the fake_sse_server fixture does, even with no request to answer", function()
        -- Its whole body is one blocking handle_request(); a spec that dies before
        -- making its request used to leave it waiting forever.
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_sse_server",
            "normal", vim.fn.tempname() })
        dies_within(pid, 6000, "an orphaned fake_sse_server")
    end)

    it("the fake_cliproxy login path does, though it never binds a port", function()
        -- `hangs` sleeps 300s and returns before any bind, so LoopbackHTTPServer
        -- cannot cover it: run_login calls the watchdog itself.
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_cliproxy", "-claude-login" },
            { PARLEY_FAKE_LOGIN_MODE = "hangs" })
        dies_within(pid, 6000, "an orphaned fake_cliproxy login")
    end)

    it("the fake_sips slow mode does, though it never binds a port", function()
        local pid = orphan({ ROOT .. "/tests/fixtures/fake_sips",
            "--out", vim.fn.tempname() }, { PARLEY_FAKE_SIPS = "slow" })
        dies_within(pid, 6000, "an orphaned fake_sips")
    end)
end)

describe("#220 census conformance, against the real ps", function()
    -- ARCH-MOCK: the recorded process table is the seam's state, but a recording
    -- cannot notice the day the real ps changes shape. This is the live half.
    local SCRIPT = ROOT .. "/scripts/reap-test-orphans.py"

    it("reads a real ps, or says why it cannot", function()
        if vim.fn.executable("ps") == 0 then
            return pending("ps is not executable here")
        end
        -- --root points at a tempname so nothing can match; --grace 0 because
        -- nothing is expected to be found.
        local out = vim.system({ "python3", SCRIPT, "--root", vim.fn.tempname(),
            "--phase", "after", "--grace", "0" }, { text = true }):wait(30000)
        assert.equals(0, out.code, out.stdout)
        if out.stdout:find("skipped", 1, true) then
            return pending("ps is refused here (an agent sandbox); census not exercised")
        end
        assert.is_falsy(out.stdout:find("BROKEN", 1, true),
            "the real ps produced columns parse_ps cannot read:\n" .. out.stdout)
    end)
end)

describe("#220 the fixture seam owns every process it starts", function()
    local fixture_process = require("tests.helpers.fixture_process")
    local ready_port = require("tests.helpers.ready_port")

    -- Each case starts from an empty registry, so the absolute live() assertions
    -- below do not depend on the case before them having reaped.
    before_each(function() fixture_process.reap() end)

    local function start()
        local port = ready_port.free_port()
        local handle, _, err, pid = fixture_process.spawn(
            ROOT .. "/tests/fixtures/fake_cliproxy", { "--port", tostring(port) })
        assert.is_truthy(handle, tostring(err))
        assert.is_true(ready_port.wait_listening(port), "the fake never came up")
        return pid
    end

    it("reap() kills what spawn() started, and forgets it", function()
        local pid = start()
        assert.equals(1, fixture_process.live())

        fixture_process.reap()
        assert.equals(0, fixture_process.live())
        assert.is_true(vim.wait(5000, function() return gone(pid) end, 50),
            "reap() left pid " .. tostring(pid) .. " alive")
    end)

    it("reap({since = mark}) spares what was started before the mark", function()
        -- The case two specs actually need: cliproxy_update_spec and
        -- cliproxy_download_spec each start a release server at FILE scope and
        -- point every case at it. A blanket reap in after_each kills it and
        -- breaks every case after the first.
        local kept = start()
        local mark = fixture_process.mark()
        local transient = start()

        fixture_process.reap({ since = mark })
        assert.is_true(vim.wait(5000, function() return gone(transient) end, 50),
            "the marked reap left pid " .. tostring(transient) .. " alive")
        assert.is_false(gone(kept), "the marked reap killed a file-scope fixture")
        assert.equals(1, fixture_process.live())

        fixture_process.reap()
        assert.is_true(vim.wait(5000, function() return gone(kept) end, 50))
    end)

    it("forgets a process that exited on its own, so live() cannot over-count", function()
        -- `crash` mode exits(1) at startup. Without pruning on exit, live() would
        -- keep counting it and a spec asserting "I left nothing behind" would
        -- fail for a process that is already gone.
        local handle, exited = fixture_process.spawn(
            ROOT .. "/tests/fixtures/fake_cliproxy", { "--port", "1", "--mode", "crash" })
        assert.is_truthy(handle)
        assert.is_true(vim.wait(5000, exited, 50), "the crash-mode fake never exited")
        assert.equals(0, fixture_process.live())
    end)

    it("reaps with the signal the caller asks for", function()
        -- cliproxy_update_spec's restart-race cases need SIGTERM: fake_cliproxy
        -- models graceful shutdown under PARLEY_FAKE_EXIT_DELAY_MS, and SIGKILL
        -- would make that window unobservable.
        local pid = start()
        fixture_process.reap({ signal = "sigterm" })
        assert.is_true(vim.wait(5000, function() return gone(pid) end, 50),
            "sigterm did not stop pid " .. tostring(pid))
    end)
end)
