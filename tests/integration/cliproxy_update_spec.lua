-- Integration tests for #237: resolving, installing and switching to a
-- CLIProxyAPI release, against tests/fixtures/fake_github_releases (a stateful
-- fake of GitHub's release endpoints) and tests/fixtures/fake_cliproxy.

local cliproxy = require("parley.cliproxy")
local fake_releases = require("tests.helpers.fake_releases")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")
local waits = require("tests.helpers.await")

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname()) -- never the real ~/.local/share/nvim
local server = fake_releases.start()
cliproxy._set_releases_url(server.url)

-- Run an async fn(done) and block until it calls done(result); return result.
-- 25 s: above UPDATE_RESTART_DEADLINE_MS (20 s), so a wait never gives up while
-- the leg it waits on is still bound to answer (PQ-5).
local function await(fn, ms)
    return waits.await(fn, ms or 25000)
end

local function dead_url()
    return ("http://127.0.0.1:%d/router-for-me/CLIProxyAPI/releases"):format(ready_port.free_port())
end

-- Every process a case starts is registered here and reaped in after_each, so a
-- failing assertion cannot orphan it (PQ-1, #220). The fixtures also exit when
-- this nvim does (fixture_watchdog.py), which covers a crashed or killed run.
local spawned, servers = {}, {}

local function spawn_fake(args, env)
    local handle, _, err = fixture_process.spawn(FAKE, args,
        vim.tbl_extend("force", { PARLEY_FAKE_EXIT_WITH_PARENT = "1" }, env or {}))
    assert(handle, "failed to spawn fake_cliproxy: " .. tostring(err))
    spawned[#spawned + 1] = handle
    return handle
end

local function reap()
    for _, h in ipairs(spawned) do
        pcall(function()
            if not h:is_closing() then
                h:kill("sigterm")
            end
        end)
    end
    for _, s in ipairs(servers) do
        fake_releases.stop(s)
    end
    spawned, servers = {}, {}
end

describe("harness", function()
    it("keeps every spec off GitHub", function()
        -- A harness flag is only evidence once a spec has seen it (#227).
        assert.equals("http://127.0.0.1:9/router-for-me/CLIProxyAPI/releases",
            vim.env.PARLEY_CLIPROXY_RELEASES_URL)
    end)

    it("reads that variable only under the harness's PARLEY_TEST_MODE", function()
        cliproxy._set_releases_url(nil)
        local inside = cliproxy._releases_url()
        local saved = vim.env.PARLEY_TEST_MODE
        vim.env.PARLEY_TEST_MODE = nil
        local outside = cliproxy._releases_url()
        vim.env.PARLEY_TEST_MODE = saved
        cliproxy._set_releases_url(server.url)
        assert.equals(vim.env.PARLEY_CLIPROXY_RELEASES_URL, inside)
        assert.equals("https://github.com/router-for-me/CLIProxyAPI/releases", outside)
    end)
end)

describe("latest_release", function()
    after_each(function()
        cliproxy._set_releases_url(server.url)
    end)

    it("follows the releases/latest redirect to the newest tag", function()
        fake_releases.publish(server, "9.9.1")
        assert.same({ "9.9.1" }, { cliproxy.latest_release() })
    end)

    it("reports a missing latest pointer instead of inventing a version", function()
        vim.fn.delete(server.root .. "/latest")
        assert.same({ nil, "no release in the redirect (HTTP 404)" }, { cliproxy.latest_release() })
    end)

    it("reports an unreachable GitHub", function()
        cliproxy._set_releases_url(dead_url())
        local v, err = cliproxy.latest_release()
        assert.is_nil(v)
        assert.is_truthy(err:find("^unreachable: "))
    end)

    it("answers asynchronously when given a callback", function()
        fake_releases.publish(server, "9.9.2")
        local got = await(function(done)
            cliproxy.latest_release(function(v, e)
                done({ v = v, e = e })
            end)
        end)
        assert.equals("9.9.2", got.v)
    end)
end)

describe("resolve_target", function()
    local parley = require("parley")
    local saved
    before_each(function()
        saved = parley.config
    end)
    after_each(function()
        parley.config = saved
    end)

    it("uses download_version without asking GitHub", function()
        parley.config = { cliproxy = { manage = true, download_version = "v9.9.1" } }
        fake_releases.clear_requests(server)
        assert.same({ "9.9.1", nil, true }, { cliproxy.resolve_target() })
        assert.same({}, fake_releases.requests(server))
    end)

    it("rejects a download_version that is not a release version", function()
        parley.config = { cliproxy = { manage = true, download_version = "latest" } }
        assert.same({ nil, 'cliproxy.download_version "latest" is not a release version (expected e.g. 7.2.158)', true },
            { cliproxy.resolve_target() })
    end)

    it("falls back to the latest release when unpinned", function()
        parley.config = { cliproxy = { manage = true } }
        fake_releases.publish(server, "9.9.3")
        assert.same({ "9.9.3", nil, false }, { cliproxy.resolve_target() })
    end)
end)

describe("version_probe", function()
    after_each(reap)

    it("reads the version off a rejected key, from a proxy parley did not configure", function()
        local port = ready_port.free_port()
        spawn_fake({ "--port", tostring(port), "--management-key", "k" }, { PARLEY_FAKE_CPA_VERSION = "9.9.9" })
        ready_port.wait_listening(port)
        assert.same({ "9.9.9" }, { cliproxy.version_probe("127.0.0.1", port) })
    end)

    it("says no_header when the proxy answers without one", function()
        local port = ready_port.free_port()
        spawn_fake({ "--port", tostring(port) })
        ready_port.wait_listening(port)
        assert.same({ nil, "no_header" }, { cliproxy.version_probe("127.0.0.1", port) })
    end)

    it("says down when nothing listens", function()
        assert.same({ nil, "down" }, { cliproxy.version_probe("127.0.0.1", ready_port.free_port()) })
    end)
end)

-- Shared by the update, status and first-run describes (lifted to file scope so
-- there is one copy).
local parley = require("parley")
local proxy_port

local function set_endpoint(port)
    parley.dispatcher = parley.dispatcher or {}
    parley.dispatcher.providers = parley.dispatcher.providers or {}
    parley.dispatcher.providers.cliproxyapi = {
        endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
    }
    require("parley.vault").add_secret("cliproxyapi", "testkey")
end

local function wipe_install()
    local mb = cliproxy.managed_binary()
    if mb then
        vim.fn.delete(mb)
        vim.fn.delete(mb .. ".version")
    end
end

local function update()
    return await(function(done)
        cliproxy.update(function(ok, msg, warn)
            done({ ok = ok, msg = msg, warn = warn })
        end)
    end)
end

-- parley launches its managed binary (a published fake release) on the port
local function start_managed(version)
    fake_releases.publish(server, version, { latest = false })
    assert.is_truthy(cliproxy.download({ version = version }))
    local result = await(function(done)
        cliproxy.ensure_running(function()
            done(true)
        end, function(msg)
            done(msg)
        end)
    end)
    assert.is_true(result == true, tostring(result))
    assert.same({ version }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
end

-- Telling parley's own proxy from another one reads `ps`, which an agent
-- sandbox can refuse (EPERM); production then says it could not tell and never
-- restarts. So the identity cases do not depend on the shell they run in: where
-- ps is refused, tests/fixtures/fake_ps prints the rows a real ps would, and
-- where it works they read the real table.
local PS_OK = (function()
    local ok, res = pcall(function()
        return vim.system({ "ps", "-p", tostring(vim.fn.getpid()) }, { text = true }):wait()
    end)
    return ok and res ~= nil and res.code == 0
end)()
local FAKE_PS = vim.fn.getcwd() .. "/tests/fixtures/fake_ps"

-- One row as `ps ax -o pid,lstart,command` prints it.
local function ps_row(pid, command)
    return ("%d Sat Sep 12 12:00:00 2026 %s"):format(pid, command)
end

-- Let identity read `rows` where the real ps is refused. `lsof` optionally
-- names the lsof executable, for the cases where it cannot run.
local function ps_sees(rows, lsof)
    local ps = "ps"
    if not PS_OK then
        vim.env.PARLEY_FAKE_PS_ROWS = table.concat(rows, "\n")
        ps = FAKE_PS
    end
    cliproxy._set_process_tools({ ps = ps, lsof = lsof })
end

-- The row parley's own managed proxy shows: its binary with the rendered config.
local function ours_row()
    local info = await(function(done)
        cliproxy.status(done)
    end)
    return ps_row(cliproxy.spawned_pids()[1], cliproxy.managed_binary() .. " -config " .. info.config_path)
end

describe(":ParleyProxy update", function()
    local uv = vim.uv or vim.loop
    local saved_config, saved_path

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        parley.config = { cliproxy = { manage = true } }
        cliproxy._set_releases_url(server.url)
        fake_releases.clear_requests(server)
    end)

    -- Owns every process a case starts (Process ownership, PQ-1).
    after_each(function()
        reap()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_update_restart_deadline_ms(nil)
        cliproxy._set_process_tools(nil)
        vim.env.PARLEY_FAKE_PS_ROWS = nil
        vim.env.PARLEY_FAKE_EXIT_DELAY_MS = nil
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    it("installs the latest release into an empty managed dir", function()
        wipe_install()
        fake_releases.publish(server, "9.9.1")
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.equals("installed 9.9.1", r.msg)
        assert.equals("9.9.1", cliproxy.installed_version())
    end)

    it("updates to a newer release and reports old → new", function()
        wipe_install()
        fake_releases.publish(server, "9.9.1", { latest = false })
        cliproxy.download({ version = "9.9.1" })
        fake_releases.publish(server, "9.9.2")
        local r = update()
        assert.equals("updated 9.9.1 → 9.9.2", r.msg)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("downloads nothing when already at the latest", function()
        fake_releases.publish(server, "9.9.2")
        cliproxy.download({ version = "9.9.2" })
        fake_releases.clear_requests(server)
        assert.equals("already at 9.9.2", update().msg)
        for _, line in ipairs(fake_releases.requests(server)) do
            assert.is_nil(line:find("/download/", 1, true), "fetched " .. line)
        end
    end)

    it("installs exactly the pinned version without asking for the latest", function()
        fake_releases.publish(server, "9.9.1", { latest = false })
        fake_releases.publish(server, "9.9.2")
        cliproxy.download({ version = "9.9.2" })
        parley.config = { cliproxy = { manage = true, download_version = "9.9.1" } }
        fake_releases.clear_requests(server)
        assert.equals("updated 9.9.2 → 9.9.1 (pinned by cliproxy.download_version)", update().msg)
        for _, line in ipairs(fake_releases.requests(server)) do
            assert.is_nil(line:find("/latest", 1, true), "asked for the latest despite the pin")
        end
    end)

    it("changes nothing when GitHub cannot be reached", function()
        fake_releases.publish(server, "9.9.2")
        local bin = cliproxy.download({ version = "9.9.2" })
        local before = uv.fs_stat(bin).ino
        cliproxy._set_releases_url(dead_url())
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("could not find the latest cliproxyapi release", 1, true))
        assert.equals(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("changes nothing when the new release fails its checksum", function()
        fake_releases.publish(server, "9.9.2")
        local bin = cliproxy.download({ version = "9.9.2" })
        local before = uv.fs_stat(bin).ino
        fake_releases.publish(server, "9.9.3", { sha = ("0"):rep(64) })
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("checksum mismatch", 1, true))
        assert.equals(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("refuses when binary_path is set, before asking GitHub", function()
        parley.config = { cliproxy = { manage = true, binary_path = "/usr/local/bin/cliproxyapi" } }
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("binary_path is set", 1, true))
        assert.same({}, fake_releases.requests(server))
    end)

    it("refuses when parley does not manage the proxy, before asking GitHub", function()
        parley.config = { cliproxy = { manage = false } }
        assert.is_truthy(update().msg:find("cliproxy.manage is off", 1, true))
        assert.same({}, fake_releases.requests(server))
    end)

    it("restarts parley's own proxy onto the new release", function()
        start_managed("9.9.4")
        ps_sees({ ours_row() })
        fake_releases.publish(server, "9.9.5")
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.equals("updated 9.9.4 → 9.9.5 — restarting the proxy; now serving 9.9.5", r.msg)
        assert.is_nil(r.warn)
        assert.same({ "9.9.5" }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
    end)

    it("leaves a proxy parley did not start running, and says how to replace it", function()
        wipe_install()
        fake_releases.publish(server, "9.9.4", { latest = false })
        cliproxy.download({ version = "9.9.4" })
        fake_releases.publish(server, "9.9.6")
        -- a cliproxy parley did not launch holds the port (think brew services)
        local holder = spawn_fake({ "--port", tostring(proxy_port), "--management-key", "k" },
            { PARLEY_FAKE_CPA_VERSION = "1.0.0" })
        ready_port.wait_listening(proxy_port)
        ps_sees({ ps_row(holder:get_pid(), "python3 " .. FAKE .. " --port " .. proxy_port) })
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.is_truthy(r.msg:find("updated 9.9.4 → 9.9.6", 1, true))
        assert.is_truthy(r.msg:find("was not started by parley", 1, true))
        assert.is_truthy(r.msg:find("still runs 1.0.0", 1, true))
        assert.is_true(r.warn, "the old version still serves, so this is a warning")
        assert.same({ "1.0.0" }, { cliproxy.version_probe("127.0.0.1", proxy_port) }) -- untouched
    end)

    it("does not take a port holder that reports no version for a cliproxyapi", function()
        wipe_install()
        fake_releases.publish(server, "9.9.4", { latest = false })
        cliproxy.download({ version = "9.9.4" })
        fake_releases.publish(server, "9.9.6")
        -- No management key, so no X-Cpa-Version: to parley this is any server.
        spawn_fake({ "--port", tostring(proxy_port) })
        ready_port.wait_listening(proxy_port)
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.is_true(r.warn)
        assert.is_truthy(r.msg:find("reports no cliproxyapi version", 1, true))
        assert.is_nil(r.msg:find("brew", 1, true))
    end)

    it("leaves a proxy it cannot identify running, and says it could not tell", function()
        wipe_install()
        fake_releases.publish(server, "9.9.4", { latest = false })
        cliproxy.download({ version = "9.9.4" })
        fake_releases.publish(server, "9.9.6")
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", "k" }, { PARLEY_FAKE_CPA_VERSION = "1.0.0" })
        ready_port.wait_listening(proxy_port)
        cliproxy._set_process_tools({ ps = "parley-test-no-such-ps" }) -- a machine without ps
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.is_true(r.warn)
        assert.equals("updated 9.9.4 → 9.9.6 — could not tell whether parley started the proxy on port "
            .. proxy_port .. " (ps unavailable), so it was left running (it still runs 1.0.0); if parley "
            .. "started it, :ParleyProxy restart replaces it", r.msg)
        assert.same({ "1.0.0" }, { cliproxy.version_probe("127.0.0.1", proxy_port) }) -- untouched
    end)

    it("says why, and does not raise, when lsof cannot run", function()
        -- An executable whose interpreter is missing: executable() passes and
        -- vim.system raises (ENOENT), as it does for a refused lsof.
        local broken = vim.fn.tempname()
        vim.fn.writefile({ "#!/nonexistent/parley-test-interpreter" }, broken)
        vim.fn.setfperm(broken, "rwx------")
        wipe_install()
        fake_releases.publish(server, "9.9.4", { latest = false })
        cliproxy.download({ version = "9.9.4" })
        fake_releases.publish(server, "9.9.6")
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", "k" }, { PARLEY_FAKE_CPA_VERSION = "1.0.0" })
        ready_port.wait_listening(proxy_port)
        ps_sees({}, broken) -- ps readable, so the identity read reaches lsof
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.is_truthy(r.msg:find("(lsof unreadable)", 1, true), r.msg)
        assert.is_true(pcall(cliproxy.stop), "stop() raised on an lsof that cannot run")
    end)

    it("refuses a second update while the first is still restarting", function()
        start_managed("9.9.4")
        ps_sees({ ours_row() })
        fake_releases.publish(server, "9.9.7")
        local first, second
        cliproxy.update(function(ok, msg)
            first = { ok = ok, msg = msg }
        end)
        cliproxy.update(function(ok, msg)
            second = { ok = ok, msg = msg }
        end)
        -- Wait for the first update's restart BEFORE any assertion: returning
        -- early would leave its spawn in flight past after_each (PQ-5).
        vim.wait(25000, function()
            return first ~= nil
        end, 20)
        assert.same({ ok = false, msg = "an update is already running" }, second)
        assert.is_true(first and first.ok, first and first.msg)
    end)

    it("answers, and releases the guard, when the restart never does", function()
        start_managed("9.9.4")
        ps_sees({ ours_row() })
        fake_releases.publish(server, "9.9.8")
        cliproxy._set_update_restart_deadline_ms(300)
        local saved = cliproxy.restart_managed
        -- An async leg that raised and never answered. Stubbed for the WHOLE
        -- body, so nothing this case starts can spawn after after_each (PQ-5).
        cliproxy.restart_managed = function() end
        local r = update()
        local again = update()
        cliproxy.restart_managed = saved
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("the restart did not answer", 1, true))
        assert.are_not.equal("an update is already running", again.msg)
    end)

    it("reports a restart that fails, and releases the guard", function()
        start_managed("9.9.4")
        ps_sees({ ours_row() })
        fake_releases.publish(server, "9.9.10")
        local saved = cliproxy.restart_managed
        -- Fails at once, so nothing this case starts can spawn after after_each.
        cliproxy.restart_managed = function(_, on_error)
            on_error("the old proxy never released the port")
        end
        local r = update()
        local again = update()
        cliproxy.restart_managed = saved
        assert.is_false(r.ok)
        assert.equals("updated 9.9.4 → 9.9.10 — restarting the proxy; the restart failed — "
            .. "the old proxy never released the port", r.msg)
        assert.are_not.equal("an update is already running", again.msg)
    end)

    it("does not reuse an old proxy that outlives the restart, and says so", function()
        -- The real binary shuts down gracefully; this fake keeps serving 4 s
        -- after SIGTERM, past restart_managed's 2 s wait for the port.
        vim.env.PARLEY_FAKE_EXIT_DELAY_MS = "4000"
        start_managed("9.9.4")
        vim.env.PARLEY_FAKE_EXIT_DELAY_MS = nil
        ps_sees({ ours_row() })
        fake_releases.publish(server, "9.9.11")
        local r = update()
        assert.is_false(r.ok, r.msg)
        assert.is_truthy(r.msg:find("the restart failed — the old proxy on port " .. proxy_port
            .. " still answers 2 s after it was told to stop", 1, true), r.msg)
        assert.equals("9.9.11", cliproxy.installed_version()) -- installed; the next restart serves it
        assert.same({ "9.9.4" }, { cliproxy.version_probe("127.0.0.1", proxy_port) }) -- never taken for new
    end)

    it("no longer offers the restart that skips the port wait", function()
        assert.is_nil(cliproxy.restart)
    end)
end)

describe("first-run auto_download", function()
    local saved_config, saved_path

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        wipe_install()
        parley.config = { cliproxy = { manage = true, auto_download = true } }
        cliproxy._set_releases_url(server.url)
    end)

    -- Owns every process a case starts (Process ownership, PQ-1).
    after_each(function()
        reap()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_releases_url(server.url)
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    local function ensure()
        return await(function(done)
            cliproxy.ensure_running(function()
                done({ ok = true })
            end, function(msg)
                done({ ok = false, msg = msg })
            end)
        end)
    end

    it("installs the latest release, not a version baked into parley", function()
        fake_releases.publish(server, "9.9.8")
        local r = ensure()
        assert.is_true(r.ok, r.msg)
        assert.equals("9.9.8", cliproxy.installed_version())
        assert.same({ "9.9.8" }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
    end)

    it("fails clearly when no release can be chosen", function()
        cliproxy._set_releases_url(dead_url())
        local r = ensure()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("auto_download could not choose a release", 1, true))
    end)
end)

describe("status version", function()
    local saved_config, saved_path

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        parley.config = { cliproxy = { manage = true } }
        cliproxy._set_releases_url(server.url)
        fake_releases.clear_requests(server)
    end)

    -- Owns every process a case starts (Process ownership, PQ-1).
    after_each(function()
        reap()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_releases_url(server.url)
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    local function status()
        return await(function(done)
            cliproxy.status(done)
        end)
    end

    it("reports the running version against the latest", function()
        start_managed("9.9.4")
        fake_releases.publish(server, "9.9.5")
        local info = status()
        assert.equals("9.9.4", info.version.running)
        assert.equals("9.9.5", info.version.latest)
        assert.equals("9.9.4", info.version.installed)
        assert.equals("managed", info.binary_source)
    end)

    it("answers once, after the slowest read, whatever the order", function()
        local slow = fake_releases.start("slow") -- /latest answers after 1.5 s
        servers[#servers + 1] = slow
        fake_releases.publish(slow, "9.9.5")
        cliproxy._set_releases_url(slow.url)
        local calls, info = 0, nil
        cliproxy.status(function(i)
            calls = calls + 1
            info = i
        end)
        vim.wait(8000, function()
            return info ~= nil
        end, 20)
        vim.wait(300, function()
            return false
        end) -- a second callback would land here
        assert.equals(1, calls)
        assert.equals("9.9.5", info.version.latest)
    end)

    it("answers once when the proxy legs land last", function()
        -- Every GET on this proxy waits 700 ms, so health and version finish
        -- after the latest release (single-threaded: 1.4 s, inside curl's 2 s).
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", "k" },
            { PARLEY_FAKE_CPA_VERSION = "9.9.4", PARLEY_FAKE_GET_DELAY_MS = "700" })
        ready_port.wait_listening(proxy_port)
        fake_releases.publish(server, "9.9.5")
        local calls, info = 0, nil
        cliproxy.status(function(i)
            calls = calls + 1
            info = i
        end)
        vim.wait(8000, function()
            return info ~= nil
        end, 20)
        vim.wait(300, function()
            return false
        end) -- a second callback would land here
        assert.equals(1, calls)
        assert.equals("9.9.4", info.version.running)
        assert.equals("9.9.5", info.version.latest)
        assert.is_not_nil(info.health)
    end)

    it("says the proxy is not running rather than guessing", function()
        local info = status()
        assert.is_nil(info.version.running)
        assert.equals("down", info.version.running_err)
    end)

    it("does not contact GitHub when parley does not manage the proxy", function()
        parley.config = { cliproxy = { manage = false } }
        local info = status()
        assert.is_nil(info.version.latest)
        assert.equals("not checked: cliproxy.manage is off", info.version.latest_err)
        assert.same({}, fake_releases.requests(server))
    end)

    it("carries the pin, normalised, for the version line", function()
        parley.config = { cliproxy = { manage = true, download_version = "v9.9.4" } }
        assert.equals("9.9.4", status().version.pinned)
    end)
end)

describe("management lockout (7.2.x)", function()
    local saved_config, saved_path

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        parley.config = { cliproxy = { manage = true } }
    end)

    after_each(function()
        reap()
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    local function unauthenticated_attempt()
        return vim.system({ "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "2",
            ("http://127.0.0.1:%d/v0/management/latest-version"):format(proxy_port) }, { text = true }):wait().stdout
    end

    local function auth_files()
        return await(function(done)
            cliproxy.auth_files(done)
        end)
    end

    it("never spends a failed attempt on parley's own proxy, however often it probes", function()
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", cliproxy.management_key() },
            { PARLEY_FAKE_CPA_VERSION = "9.9.9" })
        ready_port.wait_listening(proxy_port)
        for _ = 1, 8 do
            assert.same({ "9.9.9" }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
        end
        assert.are_not.equal("http_403", auth_files().reason)
    end)

    it("says the proxy banned parley once five attempts have failed, as 7.2.x does", function()
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", cliproxy.management_key() },
            { PARLEY_FAKE_CPA_VERSION = "9.9.9" })
        ready_port.wait_listening(proxy_port)
        for i = 1, 5 do
            assert.equals("401", unauthenticated_attempt(), "attempt " .. i)
        end
        local r = auth_files()
        assert.equals("http_403", r.reason)
        assert.equals("management API returned HTTP 403: IP banned due to too many failed attempts. "
            .. "Try again in 30m0s", r.message)
        -- the version still rides on the ban, as it does on the real binary
        assert.same({ "9.9.9" }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
    end)
end)
