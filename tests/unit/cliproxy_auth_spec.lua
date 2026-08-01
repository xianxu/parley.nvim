-- Unit tests for lua/parley/cliproxy_auth.lua (issue #197).
--
-- Pure module: no IO, no mocks. Bodies below are the REAL ones cliproxyapi
-- 7.1.71 emitted during the 2026-08-01 outage (captured from
-- ~/.cli-proxy-api/logs/), not invented shapes.

local ca = require("parley.cliproxy_auth")

-- The exact 215-byte body from issue #197, served with HTTP 503.
local NO_AUTH = '{"type":"error","error":{"type":"api_error","message":"auth_unavailable: '
    .. 'no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key '
    .. 'session and cooldown state via /v0/management/auth-files"}}'

-- The 2026-07-27 body, served with HTTP 401. Carries neither provider nor model.
local EXPIRED = '{"type":"error","error":{"type":"authentication_error","message":'
    .. '"OAuth access token has expired. Re-authenticate to continue."}}'

local LEGACY = '{"error":{"message":"unknown provider for model claude-opus-4-8",'
    .. '"type":"server_error"}}'

describe("classify_response", function()
    it("PROPERTY: never classifies a 2xx, whatever the body says", function()
        -- Assistant prose quoting every trigger word — i.e. a chat about this
        -- very issue. The status gate is the only thing preventing a login
        -- dialog mid-conversation; this is the regression guard for it.
        local prose = "The proxy returned authentication_error and 401 unauthorized, "
            .. "then payment_required; the model unavailable path is auth_unavailable: "
            .. "no auth available (providers=claude, model=claude-opus-4-8)."
        for _, body in ipairs({ prose, NO_AUTH, EXPIRED, LEGACY, "", "data: [DONE]" }) do
            for _, status in ipairs({ 200, 201, 204, 299 }) do
                assert.is_nil(ca.classify_response(status, body),
                    ("classified a %d as a failure: %s"):format(status, body:sub(1, 40)))
            end
        end
    end)

    it("classifies auth_unavailable with provider and model", function()
        local v = ca.classify_response(503, NO_AUTH)
        assert.equals("no_auth", v.kind)
        assert.equals("claude", v.provider)
        assert.equals("claude-opus-4-8", v.model)
        assert.matches("auth_unavailable", v.message)
    end)

    it("backfills the request model when the body carries none", function()
        local v = ca.classify_response(401, EXPIRED, "claude-opus-4-8")
        assert.equals("expired", v.kind)
        assert.equals("claude-opus-4-8", v.model)
    end)

    it("leaves model nil when neither body nor request supplies one", function()
        local v = ca.classify_response(401, EXPIRED)
        assert.equals("expired", v.kind)
        assert.is_nil(v.model)
    end)

    it("prefers the body's model over the request's", function()
        local v = ca.classify_response(503, NO_AUTH, "some-other-model")
        assert.equals("claude-opus-4-8", v.model)
    end)

    it("still classifies the legacy unknown-provider form", function()
        local v = ca.classify_response(500, LEGACY)
        assert.equals("unknown_provider", v.kind)
        assert.equals("claude-opus-4-8", v.model)
    end)

    it("separates quota from auth", function()
        assert.equals("quota", ca.classify_response(402, '{"error":{"message":"payment_required"}}').kind)
    end)

    it("returns nil for a non-auth 5xx", function()
        assert.is_nil(ca.classify_response(500, '{"error":{"message":"dial tcp: no such host"}}'))
    end)

    it("keeps a message containing escaped quotes whole", function()
        -- cliproxy wraps Go errors with %q, so its messages routinely contain
        -- escaped quotes. A naive `"(.-)"` capture stops at the first one and
        -- leaves the operator with the fragment `Post \\`.
        local body = '{"error":{"message":"Post \\"https://api.anthropic.com/v1/messages\\": '
            .. 'dial tcp: no such host","type":"api_error"},"code":"auth_unavailable"}'
        local v = ca.classify_response(503, body)
        assert.equals("no_auth", v.kind)
        assert.matches("api%.anthropic%.com", v.message)
        assert.matches("no such host", v.message)
    end)

    it("tolerates a nil body and a nil status", function()
        assert.is_nil(ca.classify_response(503, nil))
        -- No status ⇒ cannot place it ⇒ not a failure. Never classify what you
        -- cannot situate.
        assert.is_nil(ca.classify_response(nil, NO_AUTH))
    end)
end)

-- One record of /v0/management/auth-files, shaped exactly as cliproxyapi 7.1.71
-- returns it (captured from the real binary against a fabricated credential).
local function rec(over)
    return vim.tbl_extend("force", {
        provider = "claude",
        type = "claude",
        account = "me@example.com",
        email = "me@example.com",
        account_type = "oauth",
        status = "active",
        status_message = "",
        unavailable = false,
        disabled = false,
        failed = 0,
        success = 3,
        modtime = "2026-08-01T00:34:46-07:00",
    }, over or {})
end

describe("classify_auth_files", function()
    it("reports healthy for an active record", function()
        local h = ca.classify_auth_files({ rec() }, "claude")
        assert.equals("healthy", h.state)
        assert.equals("me@example.com", h.account)
    end)

    it("reports missing when the channel has no record", function()
        assert.equals("missing", ca.classify_auth_files({ rec({ provider = "codex", type = "codex" }) }, "claude").state)
    end)

    it("reports missing for an empty list", function()
        assert.equals("missing", ca.classify_auth_files({}, "claude").state)
    end)

    it("reports missing for a nil list", function()
        assert.equals("missing", ca.classify_auth_files(nil, "claude").state)
    end)

    it("carries status_message and failed through on error", function()
        local h = ca.classify_auth_files({ rec({
            status = "error",
            failed = 4,
            status_message = "OAuth access token has expired. Re-authenticate to continue.",
        }) }, "claude")
        assert.equals("error", h.state)
        assert.equals(4, h.failed)
        assert.matches("expired", h.message)
    end)

    it("ranks unavailable and disabled above a non-active status", function()
        assert.equals("unavailable", ca.classify_auth_files({ rec({ unavailable = true }) }, "claude").state)
        assert.equals("disabled", ca.classify_auth_files({ rec({ disabled = true }) }, "claude").state)
        -- disabled outranks unavailable when both are set
        assert.equals("disabled",
            ca.classify_auth_files({ rec({ disabled = true, unavailable = true }) }, "claude").state)
    end)

    it("picks the healthiest credential when several exist, and reports ITS account", function()
        local h = ca.classify_auth_files({
            rec({ account = "dead@example.com", email = "dead@example.com", unavailable = true }),
            rec({ account = "live@example.com", email = "live@example.com" }),
        }, "claude")
        assert.equals("healthy", h.state)
        assert.equals("live@example.com", h.account)
    end)

    it("is order-independent when picking the healthiest", function()
        local h = ca.classify_auth_files({
            rec({ account = "live@example.com", email = "live@example.com" }),
            rec({ account = "dead@example.com", email = "dead@example.com", disabled = true }),
        }, "claude")
        assert.equals("healthy", h.state)
        assert.equals("live@example.com", h.account)
    end)

    it("matches on `type` when `provider` is absent", function()
        local r = rec()
        r.provider = nil
        assert.equals("healthy", ca.classify_auth_files({ r }, "claude").state)
    end)

    it("generates a message when status_message is empty", function()
        local h = ca.classify_auth_files({ rec({ unavailable = true }) }, "claude")
        assert.matches("unavailable", h.message)
    end)

    -- Ties the hand-written rec() helper above to a payload the REAL binary
    -- produced. If cliproxy renames a field, rec() would happily keep passing
    -- on its own; this one would not.
    it("classifies the captured 7.1.71 payload", function()
        local path = vim.fn.getcwd() .. "/tests/fixtures/cliproxy_auth_files.json"
        local decoded = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
        local h = ca.classify_auth_files(decoded.files, "claude")
        assert.equals("error", h.state)
        assert.equals("probe@example.com", h.account)
        assert.equals(1, h.failed)
        assert.matches("api%.anthropic%.com", h.message)
    end)
end)

describe("diagnosis", function()
    -- Message text is API here: workshop/lessons.md records that specs across
    -- this repo assert on wording, so these pin the contract deliberately.
    local function verdict(over)
        return vim.tbl_extend("force",
            { kind = "no_auth", model = "claude-opus-4-8", provider = "claude",
              message = "auth_unavailable: no auth available" }, over or {})
    end

    it("names the account and the proxy's own reason for a dead credential", function()
        local msg = ca.diagnosis(verdict(), {
            state = "unavailable", account = "me@example.com", failed = 6,
            message = "OAuth access token has expired. Re-authenticate to continue.",
        })
        assert.matches("me@example.com", msg)
        assert.matches("expired", msg)
    end)

    it("says a credential is missing rather than blaming the model", function()
        local msg = ca.diagnosis(verdict(), { state = "missing", message = "no credential for claude" })
        assert.matches("no.*credential", msg)
        assert.matches("log in", msg)
    end)

    it("reports failure counts when the proxy tracked them", function()
        local msg = ca.diagnosis(verdict(), {
            state = "error", account = "me@example.com", failed = 4, message = "upstream 401",
        })
        assert.matches("4", msg)
    end)

    it("distinguishes quota from a login problem", function()
        local msg = ca.diagnosis(verdict({ kind = "quota", message = "payment_required" }),
            { state = "healthy", account = "me@example.com" })
        assert.matches("quota", msg)
        assert.is_nil(msg:lower():find("log in"))
    end)

    it("says so when credential state could not be read", function()
        local msg = ca.diagnosis(verdict(), { state = "unknown", reason = "unreachable",
            message = "proxy unreachable" })
        assert.matches("unreachable", msg)
    end)

    it("flags a healthy credential as a transient failure, not an auth problem", function()
        local msg = ca.diagnosis(verdict(), { state = "healthy", account = "me@example.com" })
        assert.matches("healthy", msg)
    end)

    it("always names the model when the verdict carries one", function()
        for _, state in ipairs({ "missing", "disabled", "unavailable", "error", "healthy", "unknown" }) do
            local msg = ca.diagnosis(verdict(), { state = state, message = "x", account = "a@b.c" })
            assert.matches("claude%-opus%-4%-8", msg, nil, "state " .. state .. " dropped the model")
        end
    end)

    it("never returns an empty string", function()
        assert.is_true(#ca.diagnosis(verdict({ model = nil, message = nil }), { state = "missing" }) > 0)
    end)
end)

describe("decide", function()
    -- The recovery policy as a table. Each row below is a test; the anti-loop
    -- property at the end covers the whole space at attempt >= 1.
    local function v(over)
        return vim.tbl_extend("force",
            { kind = "no_auth", model = "claude-opus-4-8", provider = "claude",
              message = "auth_unavailable" }, over or {})
    end
    local function h(over)
        return vim.tbl_extend("force", { state = "healthy", account = "me@example.com" }, over or {})
    end
    local UP = { running = true }
    local DOWN = { running = false }

    it("starts a proxy that isn't running", function()
        assert.equals("start", ca.decide(v(), h(), DOWN, 0).action)
    end)

    it("prompts for a missing, disabled, or unavailable credential", function()
        for _, state in ipairs({ "missing", "disabled", "unavailable" }) do
            local d = ca.decide(v(), h({ state = state }), UP, 0, "claude")
            assert.equals("prompt_login", d.action, "state " .. state)
        end
    end)

    it("prompts when the proxy's error message is itself an auth error", function()
        local d = ca.decide(v(), h({ state = "error",
            message = "OAuth access token has expired. Re-authenticate to continue." }), UP, 0, "claude")
        assert.equals("prompt_login", d.action)
    end)

    it("reports — does not prompt — when the error is not auth-shaped", function()
        local d = ca.decide(v(), h({ state = "error",
            message = "dial tcp: lookup api.anthropic.com: no such host" }), UP, 0)
        assert.equals("report", d.action)
    end)

    it("retries once when the credential looks healthy (transient failure)", function()
        assert.equals("retry", ca.decide(v(), h(), UP, 0).action)
    end)

    it("restarts when the file changed AFTER the proxy loaded it", function()
        -- Both operands come from the SAME record: modtime is the file's mtime,
        -- updated_at is when the proxy loaded it into memory. The three earlier
        -- versions of this compared modtime against the file's mtime read
        -- separately — the same quantity — so the rung was dead code.
        local d = ca.decide(v(), h({
            updated_at = "2026-08-01T00:34:46.994488305-07:00",
            modtime = "2026-08-01T01:34:46.994488305-07:00",
        }), { running = true }, 0)
        assert.equals("restart", d.action)
    end)

    it("retries when the proxy loaded the file at or after its mtime", function()
        local same = "2026-08-01T00:34:46.994488305-07:00"
        assert.equals("retry", ca.decide(v(), h({ modtime = same, updated_at = same }),
            { running = true }, 0).action)
        -- reloaded after the write: definitively not stale
        assert.equals("retry", ca.decide(v(), h({
            modtime = "2026-08-01T00:34:46-07:00",
            updated_at = "2026-08-01T00:40:00-07:00",
        }), { running = true }, 0).action)
    end)

    it("PROPERTY: the SAME instant is never stale, in any representation", function()
        -- The bug this replaces compared a UTC "…Z" string against cliproxy's
        -- local-offset string, so the answer depended on the operator's
        -- timezone: always-stale west of UTC, never-stale east of it. Same
        -- degenerate-fixture trap workshop/lessons.md records from M1 C1 — which
        -- the first version of THIS test walked straight into by using -07:00 on
        -- both sides.
        for _, reported in ipairs({
            "2026-08-01T18:35:01Z",
            "2026-08-01T11:35:01-07:00",
            "2026-08-01T20:35:01+02:00",
            "2026-08-01T11:35:01.994488305-07:00", -- the real binary's form
        }) do
            assert.is_not_nil(ca.rfc3339_sec(reported), "failed to parse " .. reported)
            -- Same instant expressed differently on each side must never be
            -- stale: the answer must not depend on the operator's timezone.
            local d = ca.decide(v(), h({ modtime = reported, updated_at = "2026-08-01T18:35:01Z" }),
                { running = true }, 0)
            assert.equals("retry", d.action,
                ("same instant read as stale for %s"):format(reported))
        end
    end)

    it("parses to ABSOLUTE epochs, checked against an external oracle", function()
        -- Values from Python's datetime, not from this parser. Comparing the
        -- parser to itself is what let a whole-day leap-year error ship green:
        -- a systematic offset cancels on both sides of every relative test.
        assert.equals(1785609301, ca.rfc3339_sec("2026-08-01T18:35:01Z"))
        assert.equals(0, ca.rfc3339_sec("1970-01-01T00:00:00Z"))
        assert.equals(1577836800, ca.rfc3339_sec("2020-01-01T00:00:00Z"))
        -- Leap-year dates: these were all +86400 before the fix.
        assert.equals(1709164800, ca.rfc3339_sec("2024-02-29T00:00:00Z"))
        assert.equals(1709251200, ca.rfc3339_sec("2024-03-01T00:00:00Z"))
        assert.equals(1844683200, ca.rfc3339_sec("2028-06-15T12:00:00Z"))
        assert.equals(951868800, ca.rfc3339_sec("2000-03-01T00:00:00Z")) -- 400-year rule
    end)

    it("agrees across representations of one instant", function()
        local utc = ca.rfc3339_sec("2026-08-01T18:35:01Z")
        assert.equals(utc, ca.rfc3339_sec("2026-08-01T11:35:01-07:00"))
        assert.equals(utc, ca.rfc3339_sec("2026-08-01T20:35:01+02:00"))
        assert.equals(utc, ca.rfc3339_sec("2026-08-01T11:35:01.994488305-07:00"))
    end)

    it("is TOTAL — nil for anything unparseable, never a throw", function()
        -- It runs inside an async callback, outside the dispatcher's
        -- synchronous claim guard, so a throw settles nothing and the operator
        -- waits out the backstop instead of seeing the diagnosis.
        for _, bad in ipairs({ "not a timestamp", "2026-13-01T00:00:00Z",
                               "2026-00-01T00:00:00Z", "2026-02-00T00:00:00Z",
                               "2026-01-32T00:00:00Z", "", "2026-08-01" }) do
            local ok, res = pcall(ca.rfc3339_sec, bad)
            assert.is_true(ok, "raised on " .. bad)
            assert.is_nil(res, "parsed nonsense: " .. bad)
        end
        assert.is_nil(ca.rfc3339_sec(nil))
    end)

    it("decide survives a malformed modtime from the proxy", function()
        local ok, d = pcall(ca.decide, v(), h({ modtime = "2026-13-45T99:99:99Z",
            updated_at = "2020-01-01T00:00:00Z" }), { running = true }, 0)
        assert.is_true(ok, "decide raised on proxy-supplied garbage")
        assert.equals("retry", d.action)
    end)

    it("does not call a file stale when either timestamp is missing", function()
        assert.equals("retry", ca.decide(v(), h({ modtime = nil, updated_at = "2026-08-01T00:00:00Z" }),
            { running = true }, 0).action)
        assert.equals("retry", ca.decide(v(), h({ modtime = "2026-08-01T00:00:00Z", updated_at = nil }),
            { running = true }, 0).action)
    end)

    it("tolerates sub-second skew between the file mtime and the load stamp", function()
        assert.equals("retry", ca.decide(v(), h({
            modtime = "2026-08-01T11:35:02-07:00",
            updated_at = "2026-08-01T11:35:01-07:00",
        }), { running = true }, 0).action)
    end)

    it("prompts on an expired verdict unless the proxy says the credential is fine", function()
        assert.equals("prompt_login",
            ca.decide(v({ kind = "expired" }), h({ state = "error",
                message = "OAuth access token has expired." }), UP, 0, "claude").action)
        -- healthy + expired is contradictory; believe the credential reading
        assert.equals("retry", ca.decide(v({ kind = "expired" }), h(), UP, 0).action)
    end)

    it("never treats quota or model-unavailable as a login problem", function()
        for _, kind in ipairs({ "quota", "model_unavailable" }) do
            local d = ca.decide(v({ kind = kind }), h({ state = "missing" }), UP, 0)
            assert.equals("report", d.action, "kind " .. kind)
        end
    end)

    it("reports when credential state could not be read at all", function()
        for _, reason in ipairs({ "unreachable", "unknown_channel", "management_key_mismatch" }) do
            local d = ca.decide(v(), { state = "unknown", reason = reason }, UP, 0)
            assert.equals("report", d.action, "reason " .. reason)
        end
    end)

    it("carries a login provider on every prompt_login", function()
        local d = ca.decide(v(), h({ state = "missing" }), UP, 0, "claude")
        assert.equals("claude", d.login_provider)
    end)

    it("reports instead of prompting when no login provider is resolvable", function()
        local d = ca.decide(v(), h({ state = "missing" }), UP, 0, nil)
        assert.equals("report", d.action)
    end)

    it("PROPERTY: attempt >= 1 never returns a repair action", function()
        local kinds = { "no_auth", "unknown_provider", "expired", "quota", "model_unavailable" }
        local states = { "healthy", "error", "unavailable", "disabled", "missing", "unknown" }
        for _, kind in ipairs(kinds) do
            for _, state in ipairs(states) do
                for _, running in ipairs({ true, false }) do
                    local d = ca.decide(v({ kind = kind }), h({ state = state }),
                        { running = running }, 1, "claude")
                    assert.is_true(d.action == "prompt_login" or d.action == "report",
                        ("%s/%s/running=%s at attempt 1 returned %s"):format(
                            kind, state, tostring(running), d.action))
                end
            end
        end
    end)

    it("always returns a message", function()
        assert.is_true(#ca.decide(v(), h(), UP, 0).message > 0)
    end)
end)

describe("parse_peers", function()
    local PS = table.concat(vim.fn.readfile(vim.fn.getcwd() .. "/tests/fixtures/ps_cliproxy_peers.txt"), "\n")

    it("finds proxies parley did not spawn and does not hold the managed port", function()
        local peers = ca.parse_peers(PS, { 32610 }, { 32610 })
        local pids = vim.tbl_map(function(p) return p.pid end, peers)
        table.sort(pids)
        assert.same({ 25546, 31789, 42688, 44488, 47373 }, pids)
    end)

    it("NEVER matches a shell whose command line merely mentions the binary", function()
        -- Captured from a real `ps`: a zsh -c wrapper containing the proxy path
        -- inside an eval. Substring matching here would SIGTERM the operator's
        -- shell. The executable is the first token, not any token.
        local peers = ca.parse_peers(PS, {}, {})
        for _, p in ipairs(peers) do
            assert.are_not.equal(25544, p.pid, "matched a shell wrapper")
            assert.are_not.equal(50001, p.pid, "matched a grep")
        end
    end)

    it("matches both binary names", function()
        -- brew installs `cliproxyapi`; the release tarball ships `cli-proxy-api`.
        -- An earlier survey of this very machine undercounted because it grepped
        -- only one of them.
        local peers = ca.parse_peers(PS, {}, {})
        local names = {}
        for _, p in ipairs(peers) do
            names[p.command:match("([^/%s]+)%s")] = true
        end
        assert.is_true(names["cli-proxy-api"])
        assert.is_true(names["cliproxyapi"])
    end)

    it("excludes parley's own spawned pids and the managed port holder", function()
        assert.same({}, ca.parse_peers(PS, { 25546, 31789, 42688, 44488, 47373 }, { 32610 }))
    end)

    it("carries the start time so the operator can judge staleness", function()
        local peers = ca.parse_peers(PS, {}, { 32610 })
        for _, p in ipairs(peers) do
            if p.pid == 44488 then
                assert.matches("Jun 12", p.started)
            end
        end
    end)

    it("returns an empty list for empty or malformed input", function()
        assert.same({}, ca.parse_peers("", {}, {}))
        assert.same({}, ca.parse_peers(nil, {}, {}))
        assert.same({}, ca.parse_peers("garbage\nlines\n", {}, {}))
    end)
end)
