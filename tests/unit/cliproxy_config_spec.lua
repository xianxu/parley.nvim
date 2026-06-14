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

    it("preserves a nested map+list passthrough (oauth-model-alias) through encode", function()
        -- the structure cliproxyapi needs to route claude-opus-4-8 → Claude OAuth;
        -- guards the JSON-as-YAML emission of nested maps containing lists of maps.
        local raw = {
            ["oauth-model-alias"] = {
                ["claude-opus"] = { { name = "claude-opus-4-8", alias = "claude-opus-4-8", fork = true } },
            },
        }
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, secret = "s", config = raw })
        local back = vim.json.decode(cc.encode(cfg))
        assert.same(raw["oauth-model-alias"], back["oauth-model-alias"])
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

--------------------------------------------------------------------------------
-- M2: release asset resolution
--------------------------------------------------------------------------------
describe("platform", function()
    it("maps darwin/arm64 → darwin/aarch64", function()
        assert.same({ os = "darwin", arch = "aarch64" },
            cc.platform({ sysname = "Darwin", machine = "arm64" }))
    end)
    it("maps linux/x86_64 → linux/amd64", function()
        assert.same({ os = "linux", arch = "amd64" },
            cc.platform({ sysname = "Linux", machine = "x86_64" }))
    end)
    it("maps linux/aarch64 and freebsd/amd64 and windows/x86_64", function()
        assert.same({ os = "linux", arch = "aarch64" }, cc.platform({ sysname = "Linux", machine = "aarch64" }))
        assert.same({ os = "freebsd", arch = "amd64" }, cc.platform({ sysname = "FreeBSD", machine = "amd64" }))
        assert.same({ os = "windows", arch = "amd64" }, cc.platform({ sysname = "Windows_NT", machine = "x86_64" }))
    end)
    it("returns nil for an unsupported os or arch", function()
        assert.is_nil(cc.platform({ sysname = "Plan9", machine = "x86_64" }))
        assert.is_nil(cc.platform({ sysname = "Linux", machine = "mips" }))
    end)
    it("works on the real host (returns a valid table)", function()
        local p = cc.platform()
        assert.is_truthy(p.os)
        assert.is_truthy(p.arch)
    end)
end)

describe("asset_name", function()
    it("builds the tar.gz asset for unix", function()
        assert.equals("CLIProxyAPI_7.1.71_darwin_aarch64.tar.gz",
            cc.asset_name("7.1.71", { os = "darwin", arch = "aarch64" }))
    end)
    it("uses .zip on windows", function()
        assert.equals("CLIProxyAPI_7.1.71_windows_amd64.zip",
            cc.asset_name("7.1.71", { os = "windows", arch = "amd64" }))
    end)
end)

--------------------------------------------------------------------------------
-- M3: auth-failure detection + login-provider resolution
--------------------------------------------------------------------------------
describe("detect_auth_failure", function()
    it("extracts the model from cliproxy's 'unknown provider' error", function()
        local r = '{"error":{"message":"unknown provider for model claude-opus-4-8","type":"server_error"}}'
        assert.equals("claude-opus-4-8", cc.detect_auth_failure(r))
    end)
    it("returns nil for a normal streamed response", function()
        assert.is_nil(cc.detect_auth_failure('data: {"choices":[{"delta":{"content":"hi"}}]}'))
    end)
    it("returns nil for a non-string", function()
        assert.is_nil(cc.detect_auth_failure(nil))
    end)
end)

describe("resolve_login_provider", function()
    local alias = {
        claude = {
            { name = "claude-opus-4-8", alias = "claude-opus-4-8", fork = true },
            { name = "claude-sonnet-4-6", alias = "claude-sonnet-4-6", fork = true },
        },
        codex = { { name = "gpt-5-codex", alias = "gpt-5-codex", fork = true } },
    }
    it("resolves a claude-channel model → claude login", function()
        assert.equals("claude", cc.resolve_login_provider("claude-opus-4-8", alias))
    end)
    it("resolves a codex-channel model → codex login", function()
        assert.equals("codex", cc.resolve_login_provider("gpt-5-codex", alias))
    end)
    it("matches by alias when it differs from the name", function()
        local a = { claude = { { name = "claude-opus-4-8", alias = "opus", fork = true } } }
        assert.equals("claude", cc.resolve_login_provider("opus", a))
    end)
    it("maps the gemini-cli channel → google login", function()
        local a = { ["gemini-cli"] = { { name = "gemini-2.5-pro", alias = "g", fork = true } } }
        assert.equals("google", cc.resolve_login_provider("gemini-2.5-pro", a))
    end)
    it("returns nil for a model not in any channel", function()
        assert.is_nil(cc.resolve_login_provider("mystery-model", alias))
    end)
    it("returns nil for a channel with no OAuth login (vertex)", function()
        local a = { vertex = { { name = "gemini-2.5-pro", alias = "g", fork = true } } }
        assert.is_nil(cc.resolve_login_provider("gemini-2.5-pro", a))
    end)
end)

describe("providers / provider_owned_by", function()
    it("lists the supported model-owning providers, sorted", function()
        local ps = cc.providers()
        assert.same({ "antigravity", "claude", "codex", "google", "kimi", "xai" }, ps)
    end)
    it("maps each provider → its /v1/models owned_by", function()
        assert.equals("anthropic", cc.provider_owned_by("claude"))
        assert.equals("openai", cc.provider_owned_by("codex"))
        assert.equals("google", cc.provider_owned_by("google"))
        assert.equals("xai", cc.provider_owned_by("xai"))
        assert.equals("moonshot", cc.provider_owned_by("kimi"))
        assert.equals("antigravity", cc.provider_owned_by("antigravity"))
    end)
    it("returns nil for an unknown provider", function()
        assert.is_nil(cc.provider_owned_by("bogus"))
    end)
end)

describe("filter_models_by_owner", function()
    local mixed = vim.json.encode({ data = {
        { id = "claude-sonnet-4-6", owned_by = "anthropic" },
        { id = "claude-opus-4-8", owned_by = "anthropic" },
        { id = "gpt-5-codex", owned_by = "openai" },
    } })
    it("returns only the matching owner's ids, sorted", function()
        assert.same({ "claude-opus-4-8", "claude-sonnet-4-6" },
            cc.filter_models_by_owner(mixed, "anthropic"))
    end)
    it("returns empty when the owner is absent but others are present", function()
        -- per-provider auth detection: openai is loaded, anthropic is not
        local only_openai = vim.json.encode({ data = { { id = "gpt-5-codex", owned_by = "openai" } } })
        assert.same({}, cc.filter_models_by_owner(only_openai, "anthropic"))
    end)
    it("returns empty for an empty data array", function()
        assert.same({}, cc.filter_models_by_owner(vim.json.encode({ data = {} }), "anthropic"))
    end)
    it("returns empty for malformed / non-JSON / nil input", function()
        assert.same({}, cc.filter_models_by_owner("not json", "anthropic"))
        assert.same({}, cc.filter_models_by_owner("{}", "anthropic"))
        assert.same({}, cc.filter_models_by_owner(nil, "anthropic"))
    end)
end)

describe("parse_checksums", function()
    local sample = table.concat({
        "bce9c508c15b205ceb8c6a26adf8eb3c20fbbdd5cba167debe6fd8d6983a46b3  CLIProxyAPI_7.1.71_darwin_aarch64.tar.gz",
        "638d1791cced198c24509b4934951462999cab6ea39300c7ea67a8efb4d4b774  CLIProxyAPI_7.1.71_darwin_amd64.tar.gz",
    }, "\n")
    it("returns the sha for a known asset", function()
        assert.equals("bce9c508c15b205ceb8c6a26adf8eb3c20fbbdd5cba167debe6fd8d6983a46b3",
            cc.parse_checksums(sample, "CLIProxyAPI_7.1.71_darwin_aarch64.tar.gz"))
    end)
    it("returns nil for an asset not listed", function()
        assert.is_nil(cc.parse_checksums(sample, "CLIProxyAPI_7.1.71_linux_amd64.tar.gz"))
    end)
end)
