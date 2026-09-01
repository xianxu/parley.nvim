--------------------------------------------------------------------------------
-- Pure config core for the managed cliproxyapi instance (issue #131).
--
-- No IO: every function here is deterministic and unit-tested without mocks
-- (ARCH-PURE). The IO shell — binary discovery, spawn, health probe, the
-- :ParleyProxy commands — lives in parley/cliproxy.lua and injects these.
--------------------------------------------------------------------------------

local M = {}

--- Parse host:port out of a provider endpoint URL.
--- The provider endpoint is the single source of truth for host:port
--- (spec §"host:port — single source of truth"); everything downstream
--- derives from it, so there is deliberately no separate `cliproxy.port` knob.
---
--- NB: a port-less endpoint resolves to 80/443 — it will NOT silently fall
--- back to cliproxy's 8317 default. The canonical endpoint carries `:8317`.
---@param endpoint string
---@return string|nil host, number|nil port
function M.parse_endpoint(endpoint)
    if type(endpoint) ~= "string" then
        return nil, nil
    end
    local host, port = endpoint:match("^https?://([^:/]+):(%d+)")
    if host and port then
        return host, tonumber(port)
    end
    local scheme, h = endpoint:match("^(https?)://([^:/]+)")
    if scheme and h then
        return h, scheme == "https" and 443 or 80
    end
    return nil, nil
end

--- Merge the raw `config` passthrough with parley's wiring fields and the
--- resolved client secret. Pure — the secret is passed in already resolved;
--- this never touches the vault (ARCH-PURE). Unknown keys pass through
--- untouched (ARCH-DRY: we do not re-model cliproxy's schema).
---
--- Returns the config table plus a list of any raw-config keys it clobbered,
--- so the IO caller can warn (keeping the *decision* pure and the *act* of
--- warning at the boundary).
---@param opts table # { host, port, auth_dir?, secret?, config? }
---@return table config_table, string[] overrides
function M.render(opts)
    local cfg = vim.deepcopy(opts.config or {})
    local overrides = {}
    if cfg.host ~= nil and cfg.host ~= opts.host then
        table.insert(overrides, "host")
    end
    if cfg.port ~= nil and cfg.port ~= opts.port then
        table.insert(overrides, "port")
    end
    cfg.host = opts.host
    cfg.port = opts.port
    if opts.auth_dir ~= nil then
        cfg["auth-dir"] = opts.auth_dir
    end
    if opts.secret ~= nil and opts.secret ~= "" then
        cfg["api-keys"] = { opts.secret } -- non-empty → encodes as a JSON array
    else
        -- Omit, never {} — vim.json.encode({}) emits `{}` (object), which
        -- cliproxy would read as a malformed api-keys.
        cfg["api-keys"] = nil
    end
    if opts.management_key ~= nil and opts.management_key ~= "" then
        -- The management API (/v0/management/auth-files) is parley's only honest
        -- source of credential health (#197) and it authenticates with THIS key
        -- — the api-keys bearer gets 401. Without the key rendered, cliproxy
        -- doesn't even register the route (404).
        --
        -- Merge, never replace: the operator's raw `remote-management` block
        -- passes through. `allow-remote` is deliberately never set, so the new
        -- surface stays loopback-only, and the control panel is off unless the
        -- operator asked for it — parley needs only the JSON route.
        local rm = type(cfg["remote-management"]) == "table" and cfg["remote-management"] or {}
        rm["secret-key"] = opts.management_key
        if rm["disable-control-panel"] == nil then
            rm["disable-control-panel"] = true
        end
        cfg["remote-management"] = rm
    end
    return cfg, overrides
end

--- Emit the config as a string cliproxy's --config can read. JSON is valid
--- YAML 1.2, so we emit JSON and skip a YAML emitter (spec §Emission; the
--- gating task in the plan validates a real cli-proxy-api accepts it).
---@param config_table table
---@return string
function M.encode(config_table)
    return vim.json.encode(config_table)
end

--------------------------------------------------------------------------------
-- M2: release asset resolution (pure; consumed by cliproxy.download)
--------------------------------------------------------------------------------

--- Map an os_uname() result to cliproxy's release {os, arch} naming, or nil
--- if this platform has no published release. `uname` is injectable for tests.
---@param uname table|nil # defaults to vim.uv.os_uname()
---@return table|nil # { os = "darwin|linux|freebsd|windows", arch = "aarch64|amd64" }
function M.platform(uname)
    uname = uname or (vim.uv or vim.loop).os_uname()
    local os_map = { Darwin = "darwin", Linux = "linux", FreeBSD = "freebsd", Windows_NT = "windows" }
    local os_name = os_map[uname.sysname]
    local arch
    local m = uname.machine
    if m == "arm64" or m == "aarch64" then
        arch = "aarch64"
    elseif m == "x86_64" or m == "amd64" then
        arch = "amd64"
    end
    if not os_name or not arch then
        return nil
    end
    return { os = os_name, arch = arch }
end

--- Release asset filename for a version + platform, e.g.
--- "CLIProxyAPI_7.1.71_darwin_aarch64.tar.gz" (".zip" on Windows).
--- NB: FreeBSD is best-effort — some releases ship freebsd/aarch64 only as a
--- `_no-plugin` variant, so this canonical name may 404 there (download() will
--- surface the curl error). darwin/linux are the supported targets.
---@param version string # e.g. "7.1.71" (no leading v)
---@param plat table # { os, arch } from platform()
---@return string
function M.asset_name(version, plat)
    local ext = plat.os == "windows" and "zip" or "tar.gz"
    return ("CLIProxyAPI_%s_%s_%s.%s"):format(version, plat.os, plat.arch, ext)
end

--------------------------------------------------------------------------------
-- M3: auth-failure detection + login-provider resolution
--------------------------------------------------------------------------------

-- cliproxyapi's fixed channel set → the :ParleyProxy login provider it needs.
-- The channel keys ARE the providers (cliproxyapi static catalog); vertex uses a
-- service account (no OAuth login) so it's intentionally absent.
local CHANNEL_LOGIN = {
    claude = "claude",
    codex = "codex",
    gemini = "google",
    ["gemini-cli"] = "google",
    aistudio = "google",
    kimi = "kimi",
    antigravity = "antigravity",
    xai = "xai",
}

--- Resolve which cliproxy CHANNEL serves a model, from parley's own
--- `oauth-model-alias` config (NOT a name heuristic).
---
--- The channel is the axis cliproxy itself uses: it is what
--- /v0/management/auth-files reports in `provider`/`type` (`gemini-cli`,
--- `aistudio`, …). It is NOT the login-provider axis — several channels share
--- one login (`gemini`/`gemini-cli`/`aistudio` all log in via `google`), so
--- querying credential health with a login provider silently finds nothing.
--- Keep the two apart; the login is derived via `channel_login` on a resolved channel.
---@param model string
---@param oauth_model_alias table # the rendered config's oauth-model-alias block
---@return string|nil channel
function M.resolve_channel(model, oauth_model_alias)
    if type(model) ~= "string" or type(oauth_model_alias) ~= "table" then
        return nil
    end
    for channel, entries in pairs(oauth_model_alias) do
        if type(entries) == "table" then
            for _, e in ipairs(entries) do
                if type(e) == "table" and (e.name == model or e.alias == model) then
                    return channel
                end
            end
        end
    end
    return nil
end

-- Which cliproxy CHANNELS can serve a model of a given catalog `owned_by`.
--
-- Candidates, deliberately PLURAL: antigravity re-serves anthropic-, openai- and
-- google-owned models alongside each native channel, so an owner never implies
-- one channel. Written out rather than inverted from PROVIDER_OWNED_BY, whose
-- keys are LOGIN-shaped (`google`) and therefore not channels at all —
-- CHANNEL_LOGIN has no `google` key, it has three channels that share that login.
-- PREFERENCE ORDER, not alphabetical. Callers read [1] as "the channel" when
-- only one can be probed, and `recover` derives its pre-flight login from it —
-- so a sorted list put `antigravity` ahead of the NATIVE channel for every owner
-- it re-serves, and the operator was pointed at a cross-vendor channel before
-- any credential had been read. Native channels first; antigravity last,
-- because it is the fallback that happens to also carry these models.
local OWNER_CHANNELS = {
    anthropic   = { "claude", "antigravity" },
    openai      = { "codex", "antigravity" },
    google      = { "gemini-cli", "gemini", "aistudio", "antigravity" },
    antigravity = { "antigravity" },
    moonshot    = { "kimi" },
    xai         = { "xai" },
}

--- Candidate channels for a catalog row's `owned_by`.
---@param owner string
---@return string[] # in PREFERENCE order (native channel first); empty when unknown
function M.channels_for_owner(owner)
    return vim.deepcopy(OWNER_CHANNELS[owner] or {})
end

--- Which channels could serve `model`: the operator's explicit pin if there is
--- one, else the candidates implied by the catalog, else nothing.
---
--- Plural because the honest answer often is. cliproxyapi exposes a channel's
--- models automatically once it has a credential, so parley no longer needs a
--- hand-written model list to ROUTE (verified against a live proxy: models absent
--- from `oauth-model-alias` answer normally). What it still needs is "which login
--- does this model need" when a credential dies — and where several channels
--- could serve one id, credential health decides between them rather than this
--- function guessing.
---@param model string
---@param oauth_model_alias table # the operator's pins; wins when it names the model
---@param models table[]|nil # the cached catalog
---@return string[]
function M.resolve_channels(model, oauth_model_alias, models)
    local pinned = M.resolve_channel(model, oauth_model_alias)
    if pinned then
        return { pinned }
    end
    for _, m in ipairs(models or {}) do
        if m.id == model then
            return M.channels_for_owner(m.owner)
        end
    end
    return {}
end

--- The login a channel needs, or nil for a channel with no OAuth login
--- (vertex uses a service account).
---@param channel string|nil
---@return string|nil login_provider
function M.channel_login(channel)
    return channel and CHANNEL_LOGIN[channel] or nil
end

-- A device-code flow logs into an EXISTING channel; it is a login METHOD, not a
-- channel of its own. Without this, channels_for_login("codex-device") is empty,
-- which silently disables the login watch's peer-refresh filter and makes the
-- success notice drop the account.
local LOGIN_ALIASES = { ["codex-device"] = "codex" }

--- Every cliproxy CHANNEL served by a login provider — the inverse of
--- `channel_login`, derived rather than hand-maintained (ARCH-DRY).
---
--- Needed because a third axis exists: `providers()` names login-provider-shaped
--- values (`google`), while credential health is keyed by channel
--- (`gemini`/`gemini-cli`/`aistudio`). Five of six coincide; `google` does not.
---@param login string
---@return string[] channels # sorted, empty when the login is unknown
function M.channels_for_login(login)
    login = LOGIN_ALIASES[login] or login
    local out = {}
    for channel, l in pairs(CHANNEL_LOGIN) do
        if l == login then
            out[#out + 1] = channel
        end
    end
    table.sort(out)
    return out
end


-- Provider → the `owned_by` value its models carry in /v1/models (verified
-- against the CLIProxyAPI catalog internal/registry/models/models.json). These
-- are the model-owning providers a user authenticates + queries. NB this is a
-- DIFFERENT axis from cliproxy.login_providers()/LOGIN_FLAGS (the login-method
-- set, which also has `codex-device` — a login flow, not a distinct provider).
local PROVIDER_OWNED_BY = {
    claude = "anthropic",
    codex = "openai",
    google = "google",
    xai = "xai",
    kimi = "moonshot",
    antigravity = "antigravity",
}

--- Sorted supported provider names (for `:ParleyProxy providers` + the `models`
--- completion). Model-owning providers — see the note above re: login methods.
---@return string[]
function M.providers()
    local out = {}
    for p in pairs(PROVIDER_OWNED_BY) do
        out[#out + 1] = p
    end
    table.sort(out)
    return out
end

--- The /v1/models `owned_by` value for a provider, or nil if unknown.
---@param provider string
---@return string|nil
function M.provider_owned_by(provider)
    return PROVIDER_OWNED_BY[provider]
end

--- Parse a /v1/models response body and return the sorted model ids whose
--- `owned_by` matches. Pure; empty for malformed input or no match. The
--- match-or-empty says which models a provider SERVES. It is NOT an auth signal:
--- #197 established that the registry keeps listing models with the credential
--- dead, so an empty list means "no models right now" and the caller must read
--- credential health to learn why.
---@param models_json string
---@param owned_by string
---@return string[]
function M.filter_models_by_owner(models_json, owned_by)
    local ok, decoded = pcall(vim.json.decode, models_json or "")
    if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return {}
    end
    local out = {}
    for _, m in ipairs(decoded.data) do
        if type(m) == "table" and m.owned_by == owned_by and type(m.id) == "string" then
            out[#out + 1] = m.id
        end
    end
    table.sort(out)
    return out
end

--- Is a cached catalog stale enough to be worth refetching? PURE arithmetic
--- over four values, so it is unit-testable without test seams, without a clock
--- and without spawning curl at a dead port — which is what pinning it cost
--- while it lived in the IO shell.
---
--- THREE inputs, because "stale" has three different answers:
---   * `forced`       an explicit invalidation (a completed login) outranks both
---                    clocks — the catalog demonstrably just changed;
---   * `cached_at`    a SUCCESSFUL fetch is good for `ttl`;
---   * `last_attempt` a FAILED one backs off for `backoff` only. Keying failures
---                    on `ttl` silences the picker while a proxy recovers;
---                    keying only on success re-polls a dead proxy on every open.
---@param o table # { now, cached_at?, last_attempt?, forced?, ttl, backoff }
---@return boolean
function M.catalog_stale(o)
    if o.forced then
        return true
    end
    if o.cached_at and (o.now - o.cached_at) <= o.ttl then
        return false
    end
    if o.last_attempt and (o.now - o.last_attempt) <= o.backoff then
        return false
    end
    return true
end

--- Pull the sha256 for `asset` out of a checksums.txt body
--- ("<sha256>  <filename>" per line). Returns nil if absent.
---@param text string
---@param asset string
---@return string|nil
function M.parse_checksums(text, asset)
    for line in (text or ""):gmatch("[^\n]+") do
        local sha, name = line:match("^(%x+)%s+%*?(%S+)$")
        if name == asset then
            return sha
        end
    end
    return nil
end

return M
