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
