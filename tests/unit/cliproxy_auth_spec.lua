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
