-- Unit tests for lua/parley/cliproxy_release.lua (#237). Pure: no IO, no mocks.
local rel = require("parley.cliproxy_release")

describe("parse_version", function()
    it("accepts X.Y.Z with or without a leading v, trimming whitespace", function()
        assert.equals("7.2.158", rel.parse_version("7.2.158"))
        assert.equals("7.2.158", rel.parse_version("v7.2.158"))
        assert.equals("7.2.158", rel.parse_version(" v7.2.158\n"))
    end)

    it("keeps the digits exactly as published — they name the release tag", function()
        assert.equals("7.01.1", rel.parse_version("v7.01.1"))
    end)

    it("rejects everything that is not three numeric components", function()
        for _, s in ipairs({ "", "v", "7.2", "7.2.158-rc1", "7.2.x", "1.2.3.4", "latest", "v 7.2.158" }) do
            assert.is_nil(rel.parse_version(s), ("accepted %q"):format(s))
        end
        assert.is_nil(rel.parse_version(nil))
        assert.is_nil(rel.parse_version(7))
        assert.is_nil(rel.parse_version({}))
    end)
end)

describe("compare_versions", function()
    it("compares numerically, not as strings", function()
        assert.equals(1, rel.compare_versions("7.2.10", "7.2.9"))
        assert.equals(1, rel.compare_versions("7.10.0", "7.9.99"))
        assert.equals(-1, rel.compare_versions("7.1.71", "7.2.158"))
        assert.equals(0, rel.compare_versions("7.2.158", "7.2.158"))
    end)

    it("raises on a value that was never parsed", function()
        assert.has_error(function()
            rel.compare_versions("latest", "7.2.158")
        end)
    end)
end)

describe("parse_latest_response", function()
    it("reads the version from GitHub's redirect", function()
        local v, err = rel.parse_latest_response({ code = 0,
            stdout = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.158\n302" })
        assert.equals("7.2.158", v)
        assert.is_nil(err)
    end)

    it("reports the HTTP status when there is no redirect", function()
        local v, err = rel.parse_latest_response({ code = 0, stdout = "\n404" })
        assert.is_nil(v)
        assert.equals("no release in the redirect (HTTP 404)", err)
    end)

    it("rejects a redirect that is not to a release tag", function()
        assert.is_nil((rel.parse_latest_response({ code = 0, stdout = "https://github.com/login\n302" })))
        assert.is_nil((rel.parse_latest_response({ code = 0,
            stdout = "https://github.com/x/y/releases/tag/nightly\n302" })))
    end)

    it("reports curl's own error when the request failed", function()
        local v, err = rel.parse_latest_response({ code = 7, stdout = "",
            stderr = "curl: (7) Failed to connect to github.com port 443\n" })
        assert.is_nil(v)
        assert.equals("unreachable: curl: (7) Failed to connect to github.com port 443", err)
    end)
end)

describe("parse_version_probe", function()
    -- The shape captured from a live 7.1.71 on 2026-09-11:
    -- curl -s -w "\n%{http_code}" -D - -o /dev/null …/v0/management/latest-version
    -- with no credential.
    local CAPTURED = table.concat({
        "HTTP/1.1 401 Unauthorized",
        "Content-Type: application/json; charset=utf-8",
        "X-Cpa-Build-Date: 2026-06-12T19:59:09Z",
        "X-Cpa-Commit: b6c22f2d",
        "X-Cpa-Support-Plugin: 1",
        "X-Cpa-Version: 7.1.71",
        "Content-Length: 34",
        "",
        "",
    }, "\r\n") .. "\n401"

    it("reads X-Cpa-Version from an unauthenticated request's headers", function()
        local v, reason = rel.parse_version_probe({ code = 0, stdout = CAPTURED })
        assert.equals("7.1.71", v)
        assert.is_nil(reason)
    end)

    it("matches the header name case-insensitively", function()
        local v = rel.parse_version_probe({ code = 0,
            stdout = "HTTP/1.1 200 OK\r\nx-cpa-version: 7.2.158\r\n\r\n\n200" })
        assert.equals("7.2.158", v)
    end)

    it("says no_header when the proxy answered without a usable version", function()
        assert.same({ nil, "no_header" },
            { rel.parse_version_probe({ code = 0, stdout = "HTTP/1.1 404 Not Found\r\n\r\n\n404" }) })
        assert.same({ nil, "no_header" },
            { rel.parse_version_probe({ code = 0, stdout = "HTTP/1.1 200 OK\r\nX-Cpa-Version: dev\r\n\r\n\n200" }) })
    end)

    it("says down when curl could not connect", function()
        assert.same({ nil, "down" }, { rel.parse_version_probe({ code = 7, stdout = "" }) })
    end)
end)

describe("running_identity", function()
    local CFG = "/Users/me/.local/share/nvim/parley/cliproxy/config.yaml"
    local function row(pid, command)
        return { pid = pid, command = command, exe = command:match("^(%S+)") }
    end

    it("is nil when nothing holds the port", function()
        assert.is_nil(rel.running_identity({ row(1, "/b/cli-proxy-api -config " .. CFG) }, {}, CFG))
    end)

    it("is ours when the listener was launched with parley's rendered config", function()
        local id = rel.running_identity({ row(7, "/x/bin/cli-proxy-api -config " .. CFG) }, { 7 }, CFG)
        assert.same({ ours = true, exe = "/x/bin/cli-proxy-api" }, id)
    end)

    it("counts any binary parley launched, including one found on PATH", function()
        local id = rel.running_identity({ row(7, "/opt/homebrew/bin/cliproxyapi -config " .. CFG) }, { 7 }, CFG)
        assert.is_true(id.ours)
    end)

    it("is not ours when the listener runs another config (a brew service)", function()
        local id = rel.running_identity(
            { row(7, "/opt/homebrew/bin/cliproxyapi -config /opt/homebrew/etc/cliproxyapi.conf") }, { 7 }, CFG)
        assert.same({ ours = false, exe = "/opt/homebrew/bin/cliproxyapi" }, id)
    end)

    it("matches a config path containing a space", function()
        local spaced = "/Users/my name/.local/share/nvim/parley/cliproxy/config.yaml"
        assert.is_true(rel.running_identity({ row(7, "/b/cli-proxy-api -config " .. spaced) }, { 7 }, spaced).ours)
    end)

    it("requires the whole path, not a prefix of it", function()
        assert.is_false(rel.running_identity(
            { row(7, "/b/cli-proxy-api -config " .. CFG .. ".bak") }, { 7 }, CFG).ours)
    end)

    it("only looks at processes holding the port", function()
        local id = rel.running_identity(
            { row(3, "/b/cli-proxy-api -config " .. CFG), row(7, "/opt/homebrew/bin/cliproxyapi") }, { 7 }, CFG)
        assert.is_false(id.ours)
    end)

    it("is not ours when the process table could not be read", function()
        assert.same({ ours = false }, rel.running_identity({}, { 7 }, CFG))
    end)
end)

describe("update_refusal", function()
    it("refuses when parley does not manage the proxy", function()
        assert.is_truthy(rel.update_refusal({ managed = false }):find("cliproxy.manage is off", 1, true))
    end)

    it("refuses when binary_path points parley at another binary", function()
        local msg = rel.update_refusal({ managed = true, binary_path = "/usr/local/bin/cliproxyapi" })
        assert.is_truthy(msg:find("binary_path is set", 1, true))
        assert.is_truthy(msg:find("/usr/local/bin/cliproxyapi", 1, true))
    end)

    it("allows a managed proxy with no binary_path", function()
        assert.is_nil(rel.update_refusal({ managed = true }))
        assert.is_nil(rel.update_refusal({ managed = true, binary_path = "" }))
    end)
end)

describe("plan_update", function()
    local T = "7.2.158"

    it("fails with the pin's own error when download_version is invalid", function()
        local p = rel.plan_update({ pinned = true,
            target_err = 'cliproxy.download_version "latest" is not a release version (expected e.g. 7.2.158)' })
        assert.is_false(p.ok)
        assert.is_truthy(p.message:find('"latest" is not a release version', 1, true))
        assert.is_nil(p.message:find("set cliproxy.download_version", 1, true))
    end)

    it("points at download_version when the latest cannot be found", function()
        local p = rel.plan_update({ pinned = false, target_err = "unreachable: curl: (6) Could not resolve host" })
        assert.is_false(p.ok)
        assert.is_truthy(p.message:find("could not find the latest cliproxyapi release", 1, true))
        assert.is_truthy(p.message:find("Could not resolve host", 1, true))
        assert.is_truthy(p.message:find("set cliproxy.download_version", 1, true))
    end)

    it("installs into an empty managed dir and leaves nothing to restart", function()
        assert.same({ ok = true, install = T, target = T, message = "installed 7.2.158" },
            rel.plan_update({ target = T }))
    end)

    it("upgrades and restarts parley's own proxy", function()
        local p = rel.plan_update({ target = T, installed = "7.1.71",
            running = { version = "7.1.71", ours = true, port = 8317 } })
        assert.equals(T, p.install)
        assert.equals("managed", p.restart)
        assert.equals("updated 7.1.71 → 7.2.158 — restarting the proxy", p.message)
        assert.is_nil(p.warn)
    end)

    it("upgrades but leaves a proxy parley did not launch running, and says how to replace it", function()
        local p = rel.plan_update({ target = T, installed = "7.1.71",
            running = { version = "7.1.71", ours = false, exe = "/opt/homebrew/bin/cliproxyapi", port = 8317 } })
        assert.equals("manual", p.restart)
        assert.is_true(p.warn)
        assert.is_truthy(p.message:find("/opt/homebrew/bin/cliproxyapi", 1, true))
        assert.is_truthy(p.message:find("was not started by parley", 1, true))
        assert.is_truthy(p.message:find("still runs 7.1.71", 1, true))
        assert.is_truthy(p.message:find("brew services stop cliproxyapi", 1, true))
    end)

    it("says only what it knows of a port holder that reports no version", function()
        local p = rel.plan_update({ target = T, installed = "7.1.71",
            running = { ours = false, exe = "/usr/bin/python3", port = 8317 } })
        assert.equals("manual", p.restart)
        assert.is_true(p.warn)
        assert.equals("updated 7.1.71 → 7.2.158 — port 8317 is held by a process parley did not start "
            .. "(/usr/bin/python3), and it reports no cliproxyapi version; stop it so parley can start "
            .. "7.2.158", p.message)
        local unnamed = rel.plan_update({ target = T, installed = "7.1.71", running = { ours = false, port = 8317 } })
        assert.is_truthy(unnamed.message:find("held by a process parley did not start, and it", 1, true))
    end)

    it("does nothing when the installed and running versions are current", function()
        assert.same({ ok = true, target = T, message = "already at 7.2.158" },
            rel.plan_update({ target = T, installed = T, running = { version = T, ours = true, port = 8317 } }))
    end)

    it("restarts a proxy still running the old version after an earlier install", function()
        local p = rel.plan_update({ target = T, installed = T,
            running = { version = "7.1.71", ours = true, port = 8317 } })
        assert.is_nil(p.install)
        assert.equals("managed", p.restart)
        assert.equals("already at 7.2.158 — restarting the proxy", p.message)
    end)

    it("honours a pin older than the latest, and says it is pinned", function()
        local p = rel.plan_update({ target = "7.1.71", pinned = true, installed = T })
        assert.equals("7.1.71", p.install)
        assert.equals("updated 7.2.158 → 7.1.71 (pinned by cliproxy.download_version)", p.message)
    end)

    it("does not restart when the running version is unknown and nothing was installed", function()
        assert.is_nil(rel.plan_update({ target = T, installed = T,
            running = { ours = true, port = 8317 } }).restart)
    end)

    it("restarts after an install even when the running version is unknown", function()
        assert.equals("managed", rel.plan_update({ target = T, installed = "7.1.71",
            running = { ours = true, port = 8317 } }).restart)
    end)
end)

describe("version_summary", function()
    local CMD = ":ParleyProxy update"

    it("marks a current proxy", function()
        assert.equals("7.2.158 (latest)", rel.version_summary({ running = "7.2.158", latest = "7.2.158" }, CMD))
    end)

    it("tells the user how to catch up", function()
        assert.equals("7.1.71 (latest 7.2.158 — run :ParleyProxy update)",
            rel.version_summary({ running = "7.1.71", latest = "7.2.158" }, CMD))
    end)

    it("does not nag when a pin is what holds the version back", function()
        assert.equals("7.1.71 (pinned to 7.1.71; latest 7.2.158)",
            rel.version_summary({ running = "7.1.71", latest = "7.2.158", pinned = "7.1.71" }, CMD))
    end)

    it("points at update when the running version is not the pin", function()
        assert.equals("7.2.158 (pinned to 7.1.71 — run :ParleyProxy update; latest 7.2.158)",
            rel.version_summary({ running = "7.2.158", latest = "7.2.158", pinned = "7.1.71" }, CMD))
    end)

    it("does not call a build newer than the latest stale", function()
        assert.equals("7.3.0 (latest 7.2.158)",
            rel.version_summary({ running = "7.3.0", latest = "7.2.158" }, CMD))
    end)

    it("says why the latest is unknown", function()
        assert.equals("7.1.71 (latest unknown: unreachable: curl: (7) x)",
            rel.version_summary({ running = "7.1.71", latest_err = "unreachable: curl: (7) x" }, CMD))
    end)

    it("reports a stopped proxy with the installed version, never a guess", function()
        assert.equals("not running (installed 7.2.158; latest 7.2.158)",
            rel.version_summary({ running_err = "down", installed = "7.2.158", latest = "7.2.158" }, CMD))
        assert.equals("not running (latest 7.2.158)",
            rel.version_summary({ running_err = "down", latest = "7.2.158" }, CMD))
    end)

    it("says when a running proxy reports no version", function()
        assert.equals("unknown — the proxy sent no version header (latest 7.2.158)",
            rel.version_summary({ running_err = "no_header", latest = "7.2.158" }, CMD))
    end)
end)
