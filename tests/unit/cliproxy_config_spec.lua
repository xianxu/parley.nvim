-- Unit tests for lua/parley/cliproxy_config.lua (issue #131).
-- Pure config core: no IO, no mocks.

local cc = require("parley.cliproxy_config")

--------------------------------------------------------------------------------
-- parse_endpoint
--------------------------------------------------------------------------------
describe("parse_endpoint", function()
    it("extracts host and numeric port from a standard endpoint", function()
        local host, port = cc.parse_endpoint("http://127.0.0.1:8317/v1/chat/completions")
        assert.equals("127.0.0.1", host)
        assert.equals(8317, port)
    end)

    it("handles https and a hostname", function()
        local host, port = cc.parse_endpoint("https://localhost:9000/v1/chat/completions")
        assert.equals("localhost", host)
        assert.equals(9000, port)
    end)

    it("defaults the port when none is given", function()
        local host, port = cc.parse_endpoint("http://localhost/v1/chat/completions")
        assert.equals("localhost", host)
        assert.equals(80, port)
    end)

    it("defaults https to 443 when port-less", function()
        local host, port = cc.parse_endpoint("https://example.com/v1/chat/completions")
        assert.equals("example.com", host)
        assert.equals(443, port)
    end)

    it("returns nil for an unparseable endpoint", function()
        local host, port = cc.parse_endpoint("not-a-url")
        assert.is_nil(host)
        assert.is_nil(port)
    end)

    it("returns nil for a non-string", function()
        local host, port = cc.parse_endpoint(nil)
        assert.is_nil(host)
        assert.is_nil(port)
    end)
end)

--------------------------------------------------------------------------------
-- render
--------------------------------------------------------------------------------
describe("render", function()
    it("overlays wiring fields and injects the resolved secret", function()
        local cfg = cc.render({
            host = "127.0.0.1", port = 8317,
            auth_dir = "~/.cli-proxy-api",
            secret = "sk-local-123",
            config = { ["some-provider"] = { model = "x" } },
        })
        assert.equals("127.0.0.1", cfg.host)
        assert.equals(8317, cfg.port)
        assert.equals("~/.cli-proxy-api", cfg["auth-dir"])
        assert.equals("number", type(cfg.port))
        assert.same({ "sk-local-123" }, cfg["api-keys"])
        assert.same({ model = "x" }, cfg["some-provider"]) -- passthrough preserved
    end)

    it("binds to the dialed host (loopback), not 0.0.0.0", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, secret = "s", config = {} })
        assert.equals("127.0.0.1", cfg.host)
    end)

    it("does not mutate the input config table", function()
        local raw = { port = 1 }
        cc.render({ host = "h", port = 8317, secret = "s", config = raw })
        assert.equals(1, raw.port) -- original untouched
    end)

    it("reports overridden raw-config keys for the caller to warn on", function()
        local _, overrides = cc.render({
            host = "127.0.0.1", port = 8317, secret = "s",
            config = { host = "0.0.0.0", port = 9999 },
        })
        table.sort(overrides)
        assert.same({ "host", "port" }, overrides)
    end)

    it("omits api-keys entirely when no secret is present", function()
        -- vim.json.encode({}) is `{}` (object), not `[]` (array); omit instead.
        local cfg = cc.render({ host = "h", port = 8317, config = {} })
        assert.is_nil(cfg["api-keys"])
    end)

    it("omits api-keys when the secret is an empty string", function()
        local cfg = cc.render({ host = "h", port = 8317, secret = "", config = {} })
        assert.is_nil(cfg["api-keys"])
    end)
end)

--------------------------------------------------------------------------------
-- encode
--------------------------------------------------------------------------------
describe("encode", function()
    it("emits JSON that round-trips and keeps api-keys a JSON array", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, secret = "s", config = {} })
        local str = cc.encode(cfg)
        assert.is_truthy(str:find('"api%-keys":%s*%["s"%]')) -- wire format: array, not {}
        local back = vim.json.decode(str)
        assert.equals(8317, back.port)
        assert.same({ "s" }, back["api-keys"])
    end)
end)
