-- Integration tests for #237: resolving, installing and switching to a
-- CLIProxyAPI release, against tests/fixtures/fake_github_releases (a stateful
-- fake of GitHub's release endpoints) and tests/fixtures/fake_cliproxy.

local cliproxy = require("parley.cliproxy")
local fake_releases = require("tests.helpers.fake_releases")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname()) -- never the real ~/.local/share/nvim
local server = fake_releases.start()
cliproxy._set_releases_url(server.url)

-- Run an async fn(done) and block until it calls done(result); return result.
-- 25 s: above UPDATE_RESTART_DEADLINE_MS (20 s), so a wait never gives up while
-- the leg it waits on is still bound to answer (PQ-5).
local function await(fn, ms)
    local result, got = nil, false
    fn(function(r)
        result = r
        got = true
    end)
    vim.wait(ms or 25000, function()
        return got
    end, 20)
    assert(got, "async call timed out")
    return result
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

    it("reads the version a management-enabled proxy stamps, without a credential", function()
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
