-- #197: live conformance check for cliproxyapi's management API.
--
-- The stateful fake (tests/fixtures/fake_cliproxy) models
-- /v0/management/auth-files from a captured payload. This spec boots the REAL
-- binary and asserts the fields classify_auth_files reads still exist, so drift
-- in cliproxy is caught here rather than in production (AGENTS.md external-service
-- rule: fakes plus live conformance checks).
--
-- SAFETY — read before editing:
--   The credential written below is FABRICATED and lives in a throwaway
--   auth-dir. Never point this spec at the operator's real ~/.cli-proxy-api.
--   cliproxyapi attempts a token refresh at startup and every 15 minutes, and
--   Claude's OAuth refresh tokens ROTATE on use — pointing a second proxy at a
--   live auth-dir is exactly the race that caused issue #197's outage. The
--   fabricated token makes that refresh a harmless 401.

local uv = vim.uv or vim.loop
local cliproxy = require("parley.cliproxy")
local ca = require("parley.cliproxy_auth")

cliproxy._set_data_dir(vim.fn.tempname())

-- Fields classify_auth_files depends on. If the real binary stops emitting one,
-- the fake is lying and the classifier needs revisiting.
local REQUIRED_FIELDS = {
    "provider", "type", "status", "status_message",
    "unavailable", "disabled", "failed", "account",
    -- The staleness pair: `modtime` is the credential file's mtime, `updated_at`
    -- is when the proxy last LOADED it. The restart rung reads the gap between
    -- them, so losing either upstream silently kills the missed-reload repair.
    "modtime", "updated_at",
}

local function free_port()
    local s = uv.new_tcp()
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

-- Resolved at load time: plenary's busted has no setup/teardown, only
-- before_each/after_each.
local BINARY = cliproxy.discover_binary()

describe("cliproxyapi management API conformance", function()
    local binary, proc, port, mgmt_key, auth_dir_path

    before_each(function()
        binary = BINARY
    end)

    after_each(function()
        -- Reap per test: a real proxy left running would keep a 15-minute
        -- refresh loop alive against the throwaway auth-dir.
        if proc then
            pcall(function() uv.kill(proc, "sigterm") end)
            proc = nil
        end
    end)

    -- Boot a real cliproxyapi against a THROWAWAY auth-dir holding a
    -- FABRICATED credential (see the safety note at the top). Returns
    -- port, mgmt_key.
    local function boot(omit_management)
        local auth_dir = vim.fn.tempname()
        auth_dir_path = auth_dir
        vim.fn.mkdir(auth_dir, "p")
        vim.fn.writefile({ vim.json.encode({
            access_token = "sk-ant-oat01-" .. string.rep("P", 80),
            refresh_token = "sk-ant-ort01-" .. string.rep("P", 80),
            id_token = "",
            email = "conformance@example.invalid",
            type = "claude",
            expired = "2020-01-01T00:00:00-00:00",
            last_refresh = "2020-01-01T00:00:00-00:00",
            disabled = false,
        }) }, auth_dir .. "/claude-conformance@example.invalid.json")

        port = free_port()
        mgmt_key = cliproxy.management_key()
        local cfg_path = vim.fn.tempname() .. ".yaml"
        local conf = {
            host = "127.0.0.1",
            port = port,
            ["auth-dir"] = auth_dir,
            ["api-keys"] = { "conformance" },
        }
        if not omit_management then
            conf["remote-management"] = { ["secret-key"] = mgmt_key, ["disable-control-panel"] = true }
        end
        vim.fn.writefile({ vim.json.encode(conf) }, cfg_path)

        local handle, pid = uv.spawn(binary, { args = { "-config", cfg_path } }, function() end)
        assert(handle, "failed to spawn the real cliproxyapi")
        proc = pid
        return port, mgmt_key
    end

    local function get(bearer)
        local body, code
        local ok = vim.wait(20000, function()
            local res = vim.system({
                "curl", "-s", "-w", "\n%{http_code}", "--max-time", "2",
                "-H", "Authorization: Bearer " .. bearer,
                ("http://127.0.0.1:%d/v0/management/auth-files"):format(port),
            }, { text = true }):wait()
            body, code = (res.stdout or ""):match("^(.*)\n(%d+)%s*$")
            return code ~= nil and code ~= "000"
        end, 250)
        return ok, body, code
    end

    it("serves the auth-file fields parley classifies", function()
        if not binary then
            -- Loud skip: a silent pass would let the contract rot unnoticed.
            print("SKIP: no cliproxyapi binary discoverable — conformance not verified")
            return
        end
        boot()
        local reached, body, code = get(mgmt_key)
        assert.is_true(reached, "real cliproxyapi never answered the management route")
        assert.equals("200", code)

        local decoded = vim.json.decode(body)
        assert.is_table(decoded.files)
        assert.is_true(#decoded.files > 0, "the fabricated credential was not loaded")

        local record = decoded.files[1]
        for _, field in ipairs(REQUIRED_FIELDS) do
            assert.is_not_nil(record[field],
                ("cliproxyapi no longer emits `%s` — fake and classifier are now lying"):format(field))
        end

        -- And the classifier must actually consume it end to end.
        local health = ca.classify_auth_files(decoded.files, "claude")
        assert.is_not_nil(health.state)
        assert.equals("conformance@example.invalid", health.account)
    end)

    it("404s the management route when no secret-key is configured", function()
        if not binary then
            print("SKIP: no cliproxyapi binary discoverable — conformance not verified")
            return
        end
        -- The ENTIRE unattended repair branches on this 404 meaning "the running
        -- proxy predates the key" (credential_health). The fake models it; if a
        -- future cliproxy registers the route unconditionally and 401s instead,
        -- every test would stay green while the repair silently never fires.
        boot(true) -- no remote-management block
        local reached, _body, code = get(mgmt_key)
        assert.is_true(reached)
        assert.equals("404", code)
    end)

    it("reports updated_at as a load stamp distinct from the file's modtime", function()
        if not binary then
            print("SKIP: no cliproxyapi binary discoverable — conformance not verified")
            return
        end
        -- The staleness rung branches on `modtime > updated_at`, so what must
        -- hold is that the two are INDEPENDENT quantities — modtime tracking the
        -- file, updated_at tracking the proxy's own load. Pinning that both
        -- fields merely exist is not enough: if a future cliproxy makes
        -- updated_at a copy of modtime, the fake keeps modelling a distinction
        -- the binary no longer makes and the rung silently dies — which is
        -- exactly how it died the first time.
        --
        -- NB what this does NOT assert: that a touch leaves updated_at frozen.
        -- fsnotify observes attribute changes, so the proxy usually DOES reload
        -- on a touch and advances updated_at — and that is correct: the rung
        -- fires only when the watcher genuinely missed a write, which cannot be
        -- forced deterministically from outside.
        boot()
        local cred = auth_dir_path .. "/claude-conformance@example.invalid.json"

        local _, body1 = get(mgmt_key)
        local r1 = vim.json.decode(body1).files[1]
        assert.is_string(r1.modtime)
        assert.is_string(r1.updated_at)
        -- On a never-reloaded credential the proxy stamps updated_at FROM the
        -- file's mtime, so they are equal here. That is the "not stale" state.
        assert.equals(r1.modtime, r1.updated_at)

        -- Move the file's mtime into the future. The proxy re-stats modtime; if
        -- it also reloads, updated_at takes the reload's own wall clock — a
        -- different value. Either way the two must not move as one mirror.
        local later = os.time() + 5
        vim.loop.fs_utime(cred, later, later)
        vim.wait(1500, function() return false end)
        local _, body2 = get(mgmt_key)
        local r2 = vim.json.decode(body2).files[1]

        assert.are_not.equal(r1.modtime, r2.modtime, "modtime did not track the file")
        assert.are_not.equal(r2.modtime, r2.updated_at,
            "updated_at mirrored modtime — the two are no longer independent "
                .. "quantities, so `modtime > updated_at` can never be true and "
                .. "cliproxy_auth.auth_file_is_stale must be revisited")
        -- and both remain parseable by the comparison the rung performs
        assert.is_not_nil(ca.rfc3339_sec(r2.modtime))
        assert.is_not_nil(ca.rfc3339_sec(r2.updated_at))
    end)

    it("declares the login flags parley claims it supports", function()
        if not binary then
            print("SKIP: no cliproxyapi binary discoverable — conformance not verified")
            return
        end
        -- LOGIN_FLAGS was the one dependency surface with no conformance check,
        -- and it was WRONG for the installed release: 7.2.110 dropped `-login`
        -- (google), which 7.1.71 has. This does not fail the build for a missing
        -- flag — the flag set is legitimately version-dependent — it reports the
        -- delta so the mapping is never silently stale.
        local usage = vim.system({ binary, "-h" }, { text = true }):wait()
        local help = (usage.stdout or "") .. (usage.stderr or "")
        assert.is_true(#help > 0, "the binary printed no usage at all")

        local missing = {}
        for _, provider in ipairs(cliproxy.login_providers()) do
            local argv, err = cliproxy.login_argv(provider)
            if not argv then
                missing[#missing + 1] = provider .. " (" .. tostring(err):sub(1, 60) .. ")"
            end
        end
        if #missing > 0 then
            print("NOTE: this cliproxy build does not support: " .. table.concat(missing, ", "))
        end
        -- claude is the channel this issue is about; it must work everywhere.
        assert.is_truthy(cliproxy.login_argv("claude"),
            "the installed binary has no -claude-login flag")
    end)

    it("rejects the api-key bearer on the management route", function()
        if not binary then
            print("SKIP: no cliproxyapi binary discoverable — conformance not verified")
            return
        end
        boot()
        -- Pins WHY parley renders a separate management key rather than reusing
        -- the client secret.
        local reached, _body, code = get("conformance")
        assert.is_true(reached)
        assert.equals("401", code)
    end)
end)
