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

    it("renders the management secret-key when given", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123" })
        assert.equals("abc123", cfg["remote-management"]["secret-key"])
    end)

    it("defaults the control panel off — parley needs only the JSON route", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123" })
        assert.is_true(cfg["remote-management"]["disable-control-panel"])
    end)

    it("lets an operator re-enable the control panel", function()
        local cfg = cc.render({
            host = "127.0.0.1", port = 8317, management_key = "abc123",
            config = { ["remote-management"] = { ["disable-control-panel"] = false } },
        })
        assert.is_false(cfg["remote-management"]["disable-control-panel"])
        assert.equals("abc123", cfg["remote-management"]["secret-key"])
    end)

    it("merges into an operator's remote-management block without clobbering it", function()
        local cfg = cc.render({
            host = "127.0.0.1", port = 8317, management_key = "abc123",
            config = { ["remote-management"] = { ["some-future-key"] = "kept" } },
        })
        assert.equals("kept", cfg["remote-management"]["some-future-key"])
        assert.equals("abc123", cfg["remote-management"]["secret-key"])
    end)

    it("never enables allow-remote on its own — the surface stays loopback-only", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123" })
        assert.is_nil(cfg["remote-management"]["allow-remote"])
    end)

    it("omits remote-management entirely without a key", function()
        -- Pins that operators who never enable this see a byte-identical config.
        assert.is_nil(cc.render({ host = "127.0.0.1", port = 8317 })["remote-management"])
        assert.is_nil(cc.render({ host = "127.0.0.1", port = 8317, management_key = "" })["remote-management"])
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
-- M3: login-provider resolution
--
-- detect_auth_failure lived here until #197 replaced it with
-- cliproxy_auth.classify_response (status-gated, multi-pattern); its cases moved
-- to tests/unit/cliproxy_auth_spec.lua.
--------------------------------------------------------------------------------


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

-- #197 C1: channel and login provider are DIFFERENT axes. They coincide for
-- claude, which is why every test in M1 missed the confusion.
-- The CHANNEL vs LOGIN axis distinction (#197). `resolve_login_provider` used to
-- express it, but had no production callers, so it was deleted in #205 M4 and
-- the invariant is asserted the way `recover` actually derives it:
-- channel_login(resolve_channels(...)[1]).
local function login_for(model, alias, models)
    return cc.channel_login(cc.resolve_channels(model, alias, models)[1])
end

describe("resolve_channel vs the login it implies", function()
    local alias = {
        claude = { { name = "claude-opus-4-8", alias = "claude-opus-4-8" } },
        ["gemini-cli"] = { { name = "gemini-2.5-pro", alias = "gemini-2.5-pro" } },
        aistudio = { { name = "gemini-3-pro-preview", alias = "gemini-3-pro-preview" } },
    }

    it("returns the CHANNEL, which is what auth-files reports", function()
        assert.equals("gemini-cli", cc.resolve_channel("gemini-2.5-pro", alias))
        assert.equals("aistudio", cc.resolve_channel("gemini-3-pro-preview", alias))
        assert.equals("claude", cc.resolve_channel("claude-opus-4-8", alias))
    end)

    it("collapses several channels onto one login provider", function()
        assert.equals("google", login_for("gemini-2.5-pro", alias))
        assert.equals("google", login_for("gemini-3-pro-preview", alias))
        -- and the two axes differ for exactly those models
        assert.are_not.equals(cc.resolve_channel("gemini-2.5-pro", alias),
            login_for("gemini-2.5-pro", alias))
    end)

    it("coincides only for claude — the case that hid the bug", function()
        assert.equals(cc.resolve_channel("claude-opus-4-8", alias),
            login_for("claude-opus-4-8", alias))
    end)

    it("returns nil for an unknown model rather than guessing", function()
        assert.is_nil(cc.resolve_channel("no-such-model", alias))
        assert.is_nil(login_for("no-such-model", alias))
    end)
end)


-- #197 M3 I1: LOGIN_FLAGS and CHANNEL_LOGIN are two hand-maintained sets on the
-- same axis. This is the correspondence nothing enforced, and codex-device is
-- what the drift produced.
describe("every login provider resolves to at least one channel", function()
    local cliproxy = require("parley.cliproxy")

    it("has no login provider without channels", function()
        local orphans = {}
        for _, provider in ipairs(cliproxy.login_providers()) do
            if #cc.channels_for_login(provider) == 0 then
                orphans[#orphans + 1] = provider
            end
        end
        assert.same({}, orphans,
            "a login with no channel silently disables the credential-watch filter "
                .. "and drops the account from the success notice")
    end)

    it("maps the device-code flow onto the channel it logs into", function()
        assert.same({ "codex" }, cc.channels_for_login("codex-device"))
    end)
end)

--------------------------------------------------------------------------------
-- channels_for_owner / resolve_channels (issue #205 M4)
--------------------------------------------------------------------------------
describe("channels_for_owner", function()
    it("narrows a catalog owner to the channels that can serve it, NATIVE first", function()
        -- Plural on purpose: antigravity re-serves other vendors' models
        -- alongside the native channel, so an owner never implies one channel.
        -- Order is PREFERENCE, not alphabetical — callers read [1] as "the
        -- channel" when only one can be probed, so a sorted list pointed the
        -- operator at antigravity before any credential had been read.
        assert.same({ "claude", "antigravity" }, cc.channels_for_owner("anthropic"))
        assert.same({ "codex", "antigravity" }, cc.channels_for_owner("openai"))
    end)

    it("keeps every google channel, because they share one login", function()
        assert.same({ "gemini-cli", "gemini", "aistudio", "antigravity" },
            cc.channels_for_owner("google"))
    end)

    it("returns empty for an owner it does not know", function()
        assert.same({}, cc.channels_for_owner("who-knows"))
    end)

    it("is NOT derived from PROVIDER_OWNED_BY, whose keys are logins", function()
        -- The axis error this exists to avoid: CHANNEL_LOGIN has no `google`
        -- key — that login is three channels — so inverting the login-shaped
        -- map would yield a name that is not a channel at all.
        assert.is_nil(cc.channel_login("google"))
        -- Every candidate is a real CHANNEL, i.e. it has a login.
        for _, ch in ipairs(cc.channels_for_owner("google")) do
            assert.is_not_nil(cc.channel_login(ch), ch .. " is not a channel")
        end
        -- The native ones log in via google; antigravity is a cross-vendor
        -- server that appears as a candidate for several owners and logs in as
        -- itself — which is exactly why the owner→channel relation cannot be an
        -- inversion of anything.
        assert.equals("google", cc.channel_login("gemini-cli"))
        assert.equals("antigravity", cc.channel_login("antigravity"))
        assert.is_true(vim.tbl_contains(cc.channels_for_owner("anthropic"), "antigravity"))
        assert.is_true(vim.tbl_contains(cc.channels_for_owner("google"), "antigravity"))
    end)
end)

describe("resolve_channels", function()
    local CATALOG = {
        { id = "claude-opus-5", owner = "anthropic" },
        { id = "gemini-3-flash", owner = "antigravity" },
    }

    it("returns the operator's explicit pin alone", function()
        -- The alias block stays an override: it is the only way to say "serve
        -- this id from THAT channel" when several could.
        local alias = { codex = { { name = "claude-opus-5", alias = "claude-opus-5" } } }
        assert.same({ "codex" }, cc.resolve_channels("claude-opus-5", alias, CATALOG))
    end)

    it("falls back to the catalog owner's candidates", function()
        assert.same({ "claude", "antigravity" },
            cc.resolve_channels("claude-opus-5", {}, CATALOG))
    end)

    it("returns a single candidate when the owner has only one", function()
        assert.same({ "antigravity" }, cc.resolve_channels("gemini-3-flash", {}, CATALOG))
    end)

    it("returns empty when neither the alias block nor the catalog knows it", function()
        assert.same({}, cc.resolve_channels("who-knows-1", {}, CATALOG))
    end)

    it("tolerates a nil catalog", function()
        assert.same({}, cc.resolve_channels("claude-opus-5", {}, nil))
    end)
end)


describe("channels_for_owner preference order", function()
    it("puts the native channel ahead of the cross-vendor one, for every owner", function()
        -- The bug: these lists were alphabetical, and callers read [1] as "the
        -- channel" — `recover` derives its pre-flight login from it — so
        -- `antigravity` outranked the native channel for every owner it
        -- re-serves and the operator was pointed at a channel they may never
        -- have used before any credential was read.
        for owner, native in pairs({ anthropic = "claude", openai = "codex",
                                     google = "gemini-cli" }) do
            local channels = cc.channels_for_owner(owner)
            assert.equals(native, channels[1],
                owner .. " must prefer its native channel")
            assert.equals("antigravity", channels[#channels],
                owner .. " must keep the cross-vendor fallback last")
        end
    end)
end)

describe("bound_candidates", function()
    it("keeps the native channel and the cross-vendor re-server", function()
        -- The cap must keep what its rationale promises. Trimming from the tail
        -- kept {gemini-cli, gemini} for google and dropped antigravity — the
        -- fallback the comment claimed was always retained.
        assert.same({ "gemini-cli", "antigravity" },
            cc.bound_candidates({ "gemini-cli", "gemini", "aistudio", "antigravity" }, 2))
    end)

    it("is a no-op when the list already fits", function()
        assert.same({ "claude", "antigravity" },
            cc.bound_candidates({ "claude", "antigravity" }, 2))
        assert.same({ "kimi" }, cc.bound_candidates({ "kimi" }, 2))
    end)

    it("does not mutate the caller's list", function()
        local input = { "gemini-cli", "gemini", "aistudio", "antigravity" }
        cc.bound_candidates(input, 2)
        assert.equals(4, #input)
    end)

    it("bounds every owner to the native channel plus the re-server", function()
        for _, owner in ipairs({ "anthropic", "openai", "google" }) do
            local bounded = cc.bound_candidates(cc.channels_for_owner(owner), 2)
            assert.equals(cc.channels_for_owner(owner)[1], bounded[1], owner)
            assert.equals("antigravity", bounded[#bounded], owner)
        end
    end)
end)
