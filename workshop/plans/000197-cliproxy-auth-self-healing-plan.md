# cliproxy Auth Self-Healing Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a cliproxyapi query fails for credential reasons, parley diagnoses the real cause from the proxy's own management API, repairs what it can without asking, and prompts only when a human must sit at a browser.

**Architecture:** A new pure module (`cliproxy_auth.lua`) owns the whole decision: it classifies the failure response, classifies credential health from `/v0/management/auth-files`, and returns the *action* to take. `cliproxy.lua` stays a thin IO shell that executes that action; `dispatcher.lua` gains one provider-agnostic `recover_query` seam so the retry mechanism is shared and the policy is not. Prevention (leaked-proxy reaping, login-flow robustness) closes the loop that created the failure.

**Tech Stack:** Lua / Neovim (`vim.system`, `vim.uv`), plenary.busted, the Python process-level fake at `tests/fixtures/fake_cliproxy`, real `cli-proxy-api` 7.1.71 for conformance.

---

## Context an implementer needs

Read `workshop/issues/000197-cliproxy-auth-self-healing.md` first — it holds the verified failure analysis. The facts below were captured from the real binary and are the contract this plan codes against.

**The two failure bodies that must be recognized** (both observed in `~/.cli-proxy-api/logs/`):

```json
{"type":"error","error":{"type":"api_error","message":"auth_unavailable: no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key session and cooldown state via /v0/management/auth-files"}}
{"type":"error","error":{"type":"authentication_error","message":"OAuth access token has expired. Re-authenticate to continue."}}
```

**Message templates in the 7.1.71 binary** (`strings` on the binary; these are the format strings, so the pattern table below must match their rendered form): `%s (providers=%s, model=%s)`, `no auth available`, `auth_unavailable`, `unknown provider for model %s`, `401 unauthorized`, `payment_required`, `model unavailable`, `auth_not_found`.

**`GET /v0/management/auth-files` response** (captured from 7.1.71 against a fabricated credential):

```json
{"files":[{"provider":"claude","type":"claude","account":"probe@example.com","email":"probe@example.com",
  "account_type":"oauth","id":"claude-probe@example.com.json","name":"claude-probe@example.com.json",
  "path":"/…/claude-probe@example.com.json","auth_index":"75f85694b61808ba","label":"probe@example.com",
  "status":"active","status_message":"","unavailable":false,"disabled":false,"runtime_only":false,
  "failed":0,"success":0,"size":395,"source":"file",
  "created_at":"…","updated_at":"…","modtime":"…","recent_requests":[{"time":"21:20-21:30","success":0,"failed":0}, …]}]}
```

After forcing one upstream failure, the same record became `"status":"error"` with the upstream error verbatim in `status_message` and `"failed":1`. **Authentication:** the route accepts only the `remote-management.secret-key` bearer — the normal `api-keys` bearer gets 401. **Absent key:** with no `secret-key` rendered, the route 404s (the router does not register it).

**Two behaviors that shape the design:**
- The proxy hot-reloads auth files (fsnotify → `watcher.AuthUpdate`), so a fresh login needs no restart. Restart is a fallback for when the watcher demonstrably did not pick a file up.
- Every proxy runs `core auth auto-refresh (interval=15m0s)` and attempts a refresh at startup. N proxies over one auth-dir means N refresh loops over one rotating refresh token — the cause of the original expiry.

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `AuthVerdict` / `classify_response` | `lua/parley/cliproxy_auth.lua` | new |
| `CredentialHealth` / `classify_auth_files` | `lua/parley/cliproxy_auth.lua` | new |
| `RecoveryAction` / `decide` | `lua/parley/cliproxy_auth.lua` | new |
| `diagnosis` | `lua/parley/cliproxy_auth.lua` | new |
| `render` (management-key field) | `lua/parley/cliproxy_config.lua` | modified |
| `detect_auth_failure` | `lua/parley/cliproxy_config.lua` | deleted |

- **AuthVerdict / `classify_response(http_status, body)`** — what the proxy said went wrong, as one typed value: `{kind, provider, model, message}` where `kind ∈ {no_auth, unknown_provider, expired, quota, model_unavailable}` or `nil` for "not an auth failure".
  - **Relationships:** 1:1 with a failed query response. Consumed by `decide`; never by the IO shell directly.
  - **DRY rationale:** Replaces `detect_auth_failure`'s single hardcoded pattern *and* becomes the one place any future cliproxy error string is added. Today the same knowledge is smeared across `detect_auth_failure` and `classify`'s `/v1/models` heuristic (ARCH-DRY).
  - **Future extensions:** New cliproxy versions add message forms — one row in the pattern table, no caller changes.

- **CredentialHealth / `classify_auth_files(files, provider)`** — reduces the management API's record list to this provider's credential state: `{state, message, account, failed, modtime}` with `state ∈ {healthy, error, unavailable, disabled, missing}`.
  - **Relationships:** N records in → 1 health out (a provider may hold several credentials; the healthiest wins, since the proxy will route to any usable one).
  - **DRY rationale:** First occurrence — but it is the single interpreter of the management schema, so a field rename in cliproxy lands in one function.
  - **Future extensions:** `recent_requests` buckets are already in the payload; a rate/error-trend signal widens here without touching callers.

- **RecoveryAction / `decide(verdict, health, proxy_state, attempt)`** — the whole recovery policy as a pure function returning `{action, message, login_provider}` with `action ∈ {start, restart, retry, prompt_login, report}`. `attempt` makes retry exhaustion explicit rather than stateful.
  - **Relationships:** consumes one AuthVerdict + one CredentialHealth + a `proxy_state` snapshot; produces exactly one action.
  - **DRY rationale:** Keeps the ladder out of callbacks. Without it the same branching would be duplicated between the dispatch-failure path and the `:ParleyProxy models` empty-list path, which already hand-rolls its own login prompt (`init.lua:408-419`) — that call site collapses onto `decide` too (ARCH-PURPOSE: every consumer derives from one vocabulary).
  - **Future extensions:** an auto-relogin action is one more enum value; the operator chose prompt-only for this issue, and the shape does not have to change to revisit that.

- **`diagnosis(verdict, health)`** — renders the human sentence ("claude credential expired 2026-07-25 20:06; refresh rejected — log in again") from the same inputs. Pure so message wording is unit-tested, not eyeballed. Per `workshop/lessons.md`, error text here is API: specs assert on it.

- **`render` (modified)** — gains `remote-management.secret-key` from an injected `management_key` opt, same passthrough discipline as `api-keys`: set when non-empty, omitted (never `{}`) otherwise. Does **not** set `allow-remote`, so the management surface stays loopback-only.

- **`detect_auth_failure` (deleted)** — superseded by `classify_response`. Its caller (`cliproxy.check_auth_failure`) and its tests migrate; `resolve_login_provider` stays as-is and is called with `verdict.model`.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `management_key` | `lua/parley/cliproxy.lua` | new | filesystem (`<data_root>/management.key`) |
| `auth_files` | `lua/parley/cliproxy.lua` | new | `GET /v0/management/auth-files` |
| `api_argv` | `lua/parley/cliproxy.lua` | modified | `curl` (generalized from `models_argv`) |
| `recover` | `lua/parley/cliproxy.lua` | new | executes a RecoveryAction |
| `peers` / `reap` | `lua/parley/cliproxy.lua` | new | `ps` / `lsof` / `uv.kill` |
| `login` (hardened) | `lua/parley/cliproxy.lua` | modified | `cli-proxy-api -claude-login` |
| `recover_query` seam | `lua/parley/dispatcher.lua` | new | the adapter contract |
| management + auth states | `tests/fixtures/fake_cliproxy` | modified | the real binary's routes |

- **`management_key()`** — read-or-create a 32-hex-char key at `<data_root>/management.key`, mode 0600, beside the rendered config. Not the vault: the vault is in-memory and populated from `setup{}`, and this key must survive restarts without appearing in the operator's dotfiles.
  - **Injected into:** `render_opts()` → `cc.render`, and `auth_files`'s bearer.
- **`auth_files(cb)`** — GET the management route, decode, hand the record list to `classify_auth_files`. Distinguishes 404 (key not rendered yet / proxy predates it) from 401 and transport failure, because 404 is a *repairable* state (re-render + restart), not an error to report.
  - **Injected into:** `recover`, and `:ParleyProxy status`.
- **`api_argv(host, port, secret, route)`** — `models_argv` generalized to any route so the health probe, the stop-time identity check, `list_models`, and `auth_files` share one request shape (ARCH-DRY; the existing comment at `cliproxy.lua:117` already claims this single-source role — this keeps the claim true).
- **`recover(failure, provider, retry, attempt)`** — gathers `proxy_state` + health, calls `decide`, executes the returned action. The only place recovery touches the world.
- **`peers()` / `reap()`** — enumerate `cli-proxy-api` processes parley did not spawn (`ps -axo pid,lstart,command`, cross-checked with `lsof` for the managed port); `reap` SIGTERMs them. Warn-once state is module-local and reset by `_reset` test seams, per the lessons.md rule about one-shot flags persisting across `it` blocks.
- **`recover_query(failure, retry)` seam** — optional adapter hook, mirroring `pre_query`'s shape and backward-compatibility discipline (`dispatcher.lua:437-443`). Adapters without it behave exactly as today.
- **`fake_cliproxy` (modified)** — the existing process-level fake grows the management route and a **portable credential store**: a folder of auth JSON files plus a `state.json` the test writes to select per-credential `status`/`unavailable`/`disabled`/`failed`. New modes serve the real 503/401 bodies on `/v1/chat/completions`. Integration tests run the real dispatch path against it; a live conformance check boots the real binary against a fabricated credential in a temp auth-dir and asserts the fields the fake models still exist (ARCH-MOCK).

---

## Chunk 1: M1 — Diagnose

Outcome: tonight's 503 produces a real diagnosis. No behavior change to recovery yet.

### Task 1: `classify_response` — the failure vocabulary

**Files:**
- Create: `lua/parley/cliproxy_auth.lua`
- Create: `tests/unit/cliproxy_auth_spec.lua`

- [ ] **Step 1: Write the failing tests**

```lua
local ca = require("parley.cliproxy_auth")

describe("classify_response", function()
    -- The exact body from issue #197 (215 bytes, HTTP 503).
    local NO_AUTH = '{"type":"error","error":{"type":"api_error","message":"auth_unavailable: '
        .. 'no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key '
        .. 'session and cooldown state via /v0/management/auth-files"}}'

    it("classifies auth_unavailable with provider and model", function()
        local v = ca.classify_response(503, NO_AUTH)
        assert.equals("no_auth", v.kind)
        assert.equals("claude", v.provider)
        assert.equals("claude-opus-4-8", v.model)
    end)

    it("classifies the expired-token 401 (no model in the message)", function()
        local v = ca.classify_response(401,
            '{"type":"error","error":{"type":"authentication_error","message":'
            .. '"OAuth access token has expired. Re-authenticate to continue."}}')
        assert.equals("expired", v.kind)
        assert.is_nil(v.model)
    end)

    it("still classifies the legacy unknown-provider form", function()
        local v = ca.classify_response(500,
            '{"error":{"message":"unknown provider for model claude-opus-4-8","type":"server_error"}}')
        assert.equals("unknown_provider", v.kind)
        assert.equals("claude-opus-4-8", v.model)
    end)

    it("separates quota from auth", function()
        assert.equals("quota", ca.classify_response(402, '{"error":{"message":"payment_required"}}').kind)
    end)

    it("returns nil for a normal SSE body", function()
        assert.is_nil(ca.classify_response(200, 'data: {"choices":[{"delta":{"content":"hi"}}]}'))
    end)

    it("returns nil for a non-auth 500", function()
        assert.is_nil(ca.classify_response(500, '{"error":{"message":"dial tcp: no such host"}}'))
    end)

    it("tolerates a nil body", function()
        assert.is_nil(ca.classify_response(503, nil))
    end)
end)
```

- [ ] **Step 2: Run and watch it fail**

Run: `make test SPEC=tests/unit/cliproxy_auth_spec.lua`
Expected: FAIL — module `parley.cliproxy_auth` not found.

- [ ] **Step 3: Implement**

```lua
--------------------------------------------------------------------------------
-- Pure auth-failure reasoning for the managed cliproxyapi instance (issue #197).
--
-- No IO, no clock, no vim.* state (ARCH-PURE): every function is a
-- deterministic transform, unit-tested without mocks. The IO shell
-- (parley/cliproxy.lua) gathers the inputs and executes the action this
-- module decides on.
--------------------------------------------------------------------------------

local M = {}

-- cliproxyapi's failure vocabulary, most specific first. Each row's `pattern`
-- runs against the raw response body; `captures` names what the pattern's
-- captures mean. Verified against the 7.1.71 binary's format strings (see the
-- plan's "Context an implementer needs"). Adding support for a new cliproxy
-- error means adding a row here and nothing else (ARCH-DRY).
local FAILURES = {
    {
        kind = "no_auth",
        pattern = "no auth available %(providers=([%w%-_.]+), model=([%w%-_.]+)%)",
        captures = { "provider", "model" },
    },
    { kind = "no_auth", pattern = "auth_unavailable", captures = {} },
    { kind = "unknown_provider", pattern = "unknown provider for model%s+([%w%-%._]+)", captures = { "model" } },
    { kind = "expired", pattern = "OAuth access token has expired", captures = {} },
    { kind = "expired", pattern = "authentication_error", captures = {} },
    { kind = "expired", pattern = "401 unauthorized", captures = {} },
    { kind = "expired", pattern = "auth_not_found", captures = {} },
    { kind = "quota", pattern = "payment_required", captures = {} },
    { kind = "quota", pattern = "quota%-exceeded", captures = {} },
    { kind = "model_unavailable", pattern = "model unavailable", captures = {} },
}

--- Classify a failed cliproxy response. Returns nil when the body carries no
--- recognized auth/credential failure — including for successful bodies, so
--- callers can run this unconditionally.
---@param http_status number|nil
---@param body string|nil
---@return table|nil # { kind, provider?, model?, message }
function M.classify_response(http_status, body)
    if type(body) ~= "string" or body == "" then
        return nil
    end
    for _, row in ipairs(FAILURES) do
        local a, b = body:match(row.pattern)
        if a ~= nil then
            local v = { kind = row.kind, message = M._message(body) }
            local caps = { a, b }
            for i, name in ipairs(row.captures) do
                v[name] = caps[i]
            end
            return v
        end
    end
    return nil
end

-- Pull the human message out of either error envelope cliproxy uses
-- ({error:{message}} for OpenAI-shaped, {error:{message}} nested under type
-- for Anthropic-shaped — both land on the same key).
function M._message(body)
    return body:match('"message"%s*:%s*"(.-)"') or body
end

return M
```

- [ ] **Step 4: Run tests**

Run: `make test SPEC=tests/unit/cliproxy_auth_spec.lua`
Expected: PASS (7 examples).

Note the ordering constraint the tests pin: the `(providers=…, model=…)` row must precede the bare `auth_unavailable` row, or the specific capture is lost. If a body matches both, the first row wins by construction.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_auth.lua tests/unit/cliproxy_auth_spec.lua
git commit -m "cliproxy: #197 M1: classify cliproxy auth failures by vocabulary, not one pattern"
```

### Task 2: `classify_auth_files` — credential health from the management record

**Files:**
- Modify: `lua/parley/cliproxy_auth.lua`
- Modify: `tests/unit/cliproxy_auth_spec.lua`
- Create: `tests/fixtures/cliproxy_auth_files.json` (the captured 7.1.71 payload, used by both this spec and the conformance check)

- [ ] **Step 1: Write the failing tests**

Build records with a helper so each test states only the fields it cares about:

```lua
local function rec(over)
    return vim.tbl_extend("force", {
        provider = "claude", type = "claude", account = "me@example.com", email = "me@example.com",
        status = "active", status_message = "", unavailable = false, disabled = false,
        failed = 0, success = 3, modtime = "2026-08-01T00:34:46-07:00",
    }, over or {})
end

describe("classify_auth_files", function()
    it("reports healthy for an active record", function()
        local h = ca.classify_auth_files({ rec() }, "claude")
        assert.equals("healthy", h.state)
        assert.equals("me@example.com", h.account)
    end)

    it("reports missing when the provider has no record", function()
        assert.equals("missing", ca.classify_auth_files({ rec({ provider = "codex" }) }, "claude").state)
    end)

    it("reports missing for an empty list", function()
        assert.equals("missing", ca.classify_auth_files({}, "claude").state)
    end)

    it("carries status_message through on error", function()
        local h = ca.classify_auth_files({ rec({ status = "error", failed = 4,
            status_message = "OAuth access token has expired." }) }, "claude")
        assert.equals("error", h.state)
        assert.equals(4, h.failed)
        assert.matches("expired", h.message)
    end)

    it("ranks unavailable and disabled above status", function()
        assert.equals("unavailable", ca.classify_auth_files({ rec({ unavailable = true }) }, "claude").state)
        assert.equals("disabled", ca.classify_auth_files({ rec({ disabled = true }) }, "claude").state)
    end)

    it("picks the healthiest credential when several exist", function()
        local h = ca.classify_auth_files({
            rec({ account = "dead@example.com", unavailable = true }),
            rec({ account = "live@example.com" }),
        }, "claude")
        assert.equals("healthy", h.state)
        assert.equals("live@example.com", h.account)
    end)

    it("matches on `type` when `provider` is absent", function()
        local r = rec(); r.provider = nil
        assert.equals("healthy", ca.classify_auth_files({ r }, "claude").state)
    end)
end)
```

- [ ] **Step 2: Run and watch it fail**

Run: `make test SPEC=tests/unit/cliproxy_auth_spec.lua`
Expected: FAIL — `classify_auth_files` is nil.

- [ ] **Step 3: Implement**

```lua
-- Worst-to-best so "healthiest wins" is a simple max: the proxy will route to
-- any usable credential, so one healthy record makes the provider usable
-- regardless of how many dead ones sit beside it.
local HEALTH_RANK = { missing = 0, disabled = 1, unavailable = 2, error = 3, healthy = 4 }

--- Reduce the management API's record list to this provider's credential state.
---@param files table[] # the `files` array from /v0/management/auth-files
---@param provider string # cliproxy channel, e.g. "claude"
---@return table # { state, message, account, failed, modtime }
function M.classify_auth_files(files, provider)
    local best = { state = "missing", message = "no credential for " .. tostring(provider) }
    for _, f in ipairs(type(files) == "table" and files or {}) do
        if (f.provider or f.type) == provider then
            local state
            if f.disabled then
                state = "disabled"
            elseif f.unavailable then
                state = "unavailable"
            elseif f.status ~= nil and f.status ~= "active" then
                state = "error"
            else
                state = "healthy"
            end
            if HEALTH_RANK[state] > HEALTH_RANK[best.state] then
                best = {
                    state = state,
                    message = (f.status_message ~= nil and f.status_message ~= "")
                        and f.status_message or ("credential is " .. state),
                    account = f.account or f.email,
                    failed = f.failed,
                    modtime = f.modtime,
                }
            end
        end
    end
    return best
end
```

- [ ] **Step 4: Run tests** — `make test SPEC=tests/unit/cliproxy_auth_spec.lua`, expect PASS.
- [ ] **Step 5: Commit** — `cliproxy: #197 M1: derive credential health from the management record`

### Task 3: render the management key

**Files:**
- Modify: `lua/parley/cliproxy_config.lua:45-67` (`render`)
- Modify: `tests/unit/cliproxy_config_spec.lua`

- [ ] **Step 1: Write the failing tests**

```lua
it("renders the management secret-key when given", function()
    local out = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123" })
    assert.equals("abc123", out["remote-management"]["secret-key"])
end)

it("preserves other remote-management keys the operator set", function()
    local out = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123",
        config = { ["remote-management"] = { ["disable-control-panel"] = true } } })
    assert.is_true(out["remote-management"]["disable-control-panel"])
    assert.equals("abc123", out["remote-management"]["secret-key"])
end)

it("never enables allow-remote on its own", function()
    local out = cc.render({ host = "127.0.0.1", port = 8317, management_key = "abc123" })
    assert.is_nil(out["remote-management"]["allow-remote"])
end)

it("omits remote-management entirely without a key", function()
    local out = cc.render({ host = "127.0.0.1", port = 8317 })
    assert.is_nil(out["remote-management"])
end)
```

- [ ] **Step 2: Run and watch it fail** — `make test SPEC=tests/unit/cliproxy_config_spec.lua`.

- [ ] **Step 3: Implement** — in `render`, after the `api-keys` block:

```lua
    if opts.management_key ~= nil and opts.management_key ~= "" then
        -- Merge, never replace: the operator's raw `remote-management` block
        -- (e.g. disable-control-panel) passes through untouched. `allow-remote`
        -- is deliberately not set — the management surface stays loopback-only.
        local rm = cfg["remote-management"]
        if type(rm) ~= "table" then
            rm = {}
        end
        rm["secret-key"] = opts.management_key
        cfg["remote-management"] = rm
    end
```

- [ ] **Step 4: Run tests** — expect PASS, including the existing render specs (the last test above pins that a key-less render is byte-identical to today, so no operator sees a config change until this feature turns on).
- [ ] **Step 5: Commit** — `cliproxy: #197 M1: render a loopback-only management secret-key`

### Task 4: `management_key()` + `auth_files()` + argv generalization

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`models_argv` → `api_argv`, `render_opts`, new `management_key`, `auth_files`)
- Modify: `tests/integration/cliproxy_lifecycle_spec.lua`
- Modify: `tests/fixtures/fake_cliproxy`

- [ ] **Step 1: Extend the fake first** (the test needs a server to talk to)

Add to `fake_cliproxy`: a `--auth-store <dir>` argument pointing at a folder of credential JSON files plus an optional `state.json` overlay (`{"claude": {"status": "error", "status_message": "…", "unavailable": true}}`). Serve `GET /v0/management/auth-files` → `{"files": [...]}` built from that folder, honoring the overlay; require the `Authorization: Bearer <secret-key from -config>` header, 401 on mismatch, **404 when the config carries no `remote-management.secret-key`** — that 404 is a state parley must distinguish, so the fake has to model it. Keep the store on disk, not in memory, so tests can mutate credential state between calls and the fake stays a *stateful* double (ARCH-MOCK).

- [ ] **Step 2: Write the failing integration tests**

```lua
it("reads credential health from the management API", function()
    local port = free_port()
    -- store with one healthy claude credential
    local dir = write_auth_store({ claude = { account = "me@example.com" } })
    start_fake_with_store(port, dir, { secret_key = "mgmt" })
    wait_listening(port)
    local health = await(function(done) cliproxy.auth_files(done) end)
    assert.equals("healthy", health.state)
end)

it("reports a distinguishable 404 when no management key is rendered", function()
    -- fake started from a config WITHOUT remote-management.secret-key
    local res = await(function(done) cliproxy.auth_files(done) end)
    assert.equals("no_management_route", res.reason)
end)

it("generates the management key once and reuses it", function()
    local a = cliproxy.management_key()
    local b = cliproxy.management_key()
    assert.equals(a, b)
    assert.equals(32, #a)
    assert.equals("600", vim.fn.printf("%o", require("bit").band(
        (vim.uv or vim.loop).fs_stat(cliproxy._management_key_path()).mode, tonumber("777", 8))))
end)
```

- [ ] **Step 3: Implement**

`api_argv(host, port, secret, route)` — take `models_argv` verbatim and parameterize the trailing URL path, defaulting to `/v1/models`; update its three existing callers. `management_key()` — read `<data_root>/management.key` if present, else generate 32 hex chars from `vim.uv.random(16)`, write 0600, return it. `render_opts()` gains `management_key = M.management_key()`. `auth_files(cb)` — `api_argv(..., management_key(), "/v0/management/auth-files")`, then classify:

```lua
--- Fetch credential health for `provider` (default: the channel this endpoint
--- serves). Distinguishes the repairable "route not registered" 404 from real
--- failures, because a 404 means the running proxy predates the management key
--- and should be restarted, not reported.
---@param cb fun(health: table)
function M.auth_files(cb, provider)
    local opts = render_opts()
    vim.system(api_argv(opts.host, opts.port, M.management_key(), "/v0/management/auth-files"),
        { text = true }, function(obj)
            local body, http = (obj.stdout or ""):match("^(.*)\n(%d+)%s*$")
            vim.schedule(function()
                if obj.code ~= 0 then
                    return cb({ state = "unknown", reason = "unreachable", message = obj.stderr })
                end
                if tonumber(http) == 404 then
                    return cb({ state = "unknown", reason = "no_management_route" })
                end
                if tonumber(http) ~= 200 then
                    return cb({ state = "unknown", reason = "http_" .. tostring(http) })
                end
                local ok, decoded = pcall(vim.json.decode, body or "")
                if not ok or type(decoded) ~= "table" then
                    return cb({ state = "unknown", reason = "undecodable" })
                end
                cb(ca.classify_auth_files(decoded.files, provider or "claude"))
            end)
        end)
end
```

- [ ] **Step 4: Run tests** — `make test SPEC=tests/integration/cliproxy_lifecycle_spec.lua`, expect PASS.
- [ ] **Step 5: Commit** — `cliproxy: #197 M1: read credential health over the management API`

### Task 5: restart a proxy whose rendered config drifted

**Files:**
- Modify: `lua/parley/cliproxy.lua:284-332` (`ensure_running`), `config_drift` (line 396)
- Modify: `tests/integration/cliproxy_lifecycle_spec.lua`

`config_drift()` exists but only `status()` reads it. An operator upgrading into this feature has a proxy running from a key-less config; without this the management route 404s forever.

- [ ] **Step 1: Write the failing test** — start the fake from a rendered config, mutate the Lua config so a fresh render differs, call `ensure_running`, assert the old pid is gone and a new proxy answers. Also assert the *negative*: no drift ⇒ same pid (reuse-if-healthy must not regress into restart-every-query).
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement** — in `ensure_running`, when the probe says `healthy`/`needs_login` **and** `config_drift()` is true **and** the port holds a parley-spawned proxy, `stop()` then spawn; otherwise reuse as today. Log at INFO with the reason so the restart is never mysterious.
- [ ] **Step 4: Run tests.**
- [ ] **Step 5: Commit** — `cliproxy: #197 M1: restart a proxy running a drifted config`

### Task 6: rewire diagnosis onto the new vocabulary

**Files:**
- Modify: `lua/parley/cliproxy.lua:496-533` (`check_auth_failure`)
- Modify: `lua/parley/cliproxy_config.lua` (delete `detect_auth_failure`)
- Modify: `tests/unit/cliproxy_config_spec.lua:167-177`, `tests/integration/cliproxy_auth_login_spec.lua`
- Modify: `lua/parley/dispatcher.lua:311-313` (pass the HTTP status through)

- [ ] **Step 1: Write the failing tests** — extend `cliproxy_auth_login_spec.lua` so the **exact 503 body from #197** reaches the prompt path, and assert the prompt text names the credential state, not just the model. Per lessons.md, assert the message contract explicitly. Delete the `detect_auth_failure` unit tests, re-expressing each case against `classify_response` (already done in Task 1) — do not leave both.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** — `check_auth_failure(provider, raw_response, http_status)` calls `ca.classify_response`, then `auth_files` for health, then `ca.diagnosis(...)` for the sentence, keeping the existing `_login_prompt_active` guard and `resolve_login_provider` mapping. Write `diagnosis` in `cliproxy_auth.lua` with its own unit tests (pure). Delete `detect_auth_failure`. Grep for its name and for the string `unknown provider for model` across `lua/ tests/ atlas/` before declaring done — lessons.md's rule about grepping for the *behavior*, not just the symbol.
- [ ] **Step 4: Run the full suite** — `make test`, expect 0 failures, luacheck clean.
- [ ] **Step 5: Commit** — `cliproxy: #197 M1: diagnose auth failures from real credential state`

### Task 7: live conformance check

**Files:**
- Create: `tests/integration/cliproxy_conformance_spec.lua`

- [ ] **Step 1: Write the test** — skip unless a real binary is discoverable (`cliproxy.discover_binary()`) so CI without one stays green, and log the skip loudly rather than silently passing. Boot the real binary on a free port with a temp auth-dir holding a **fabricated** credential (`sk-ant-oat01-` + filler, `expired` in the past) and a rendered management key; GET `/v0/management/auth-files`; assert every field `classify_auth_files` reads still exists (`provider`/`type`, `status`, `status_message`, `unavailable`, `disabled`, `failed`, `modtime`). Tear the proxy down in `after_each`.

  **Never point this at the operator's real auth-dir.** The binary attempts a token refresh at startup and every 15m; a fabricated credential makes that attempt harmless, a real one would rotate the operator's live refresh token. `_set_data_dir` is already the established guard for the same class of mistake.

- [ ] **Step 2: Run it** — `make test SPEC=tests/integration/cliproxy_conformance_spec.lua`, expect PASS against 7.1.71.
- [ ] **Step 3: Commit** — `cliproxy: #197 M1: pin the management-API contract against the real binary`

### Task 8: close M1

- [ ] Update `atlas/` for the new auth-diagnosis surface and link it from `atlas/index.md`.
- [ ] `sdlc milestone-close --issue 197 --milestone M1` — fix Critical/Important findings before crossing, log the verdict in `## Log`.

---

## Chunk 2: M2 — Recover

Outcome: recoverable failures repair themselves and the query retries; only a dead credential prompts.

### Task 9: `decide` — the recovery policy, pure

**Files:**
- Modify: `lua/parley/cliproxy_auth.lua`
- Modify: `tests/unit/cliproxy_auth_spec.lua`

The policy as a table (each row is a test):

| verdict.kind | proxy running | health.state | attempt | action |
|---|---|---|---|---|
| any | false | – | 0 | `start` |
| `no_auth` / `unknown_provider` | true | `missing` | any | `prompt_login` |
| `no_auth` / `unknown_provider` | true | `disabled` / `unavailable` | any | `prompt_login` |
| `no_auth` | true | `error`, message looks like auth | any | `prompt_login` |
| `no_auth` | true | `error`, message not auth-ish | any | `report` |
| `no_auth` | true | `healthy`, auth file newer than record | 0 | `restart` |
| `no_auth` | true | `healthy` | 0 | `retry` |
| `expired` | true | any | any | `prompt_login` |
| `quota` / `model_unavailable` | – | – | – | `report` |
| any | – | – | ≥1 | never `retry`/`restart`/`start` — escalate to `prompt_login` or `report` |

- [ ] **Step 1: Write one test per row**, plus: `attempt >= 1` must never return a repair action (the anti-loop invariant — assert it by looping every verdict kind × health state at `attempt = 1` and asserting the action is in `{prompt_login, report}`).
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** `decide(verdict, health, proxy_state, attempt)`. `proxy_state` is `{running, auth_file_modtime, record_modtime}`; the staleness comparison is string-compare on RFC3339 timestamps only if both are present, else treat as not-stale (never guess).
- [ ] **Step 4: Run tests.**
- [ ] **Step 5: Commit** — `cliproxy: #197 M2: decide recovery as a pure policy`

### Task 10: `recover_query` seam in the dispatcher

**Files:**
- Modify: `lua/parley/dispatcher.lua:383-427`
- Modify: `tests/unit/dispatcher_query_spec.lua`

- [ ] **Step 1: Write the failing tests** — (a) an adapter with no `recover_query` behaves exactly as today (the existing failure specs must pass untouched); (b) an adapter whose `recover_query` calls `retry()` re-issues the query once with the identical payload; (c) an adapter that calls `retry()` twice only re-issues once (`tasker.once`-style guard); (d) the retried query's failure does **not** re-enter recovery.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** — in the `failed` branch, before `on_error`, if `adapter.recover_query` exists and this is attempt 0, call it with `(failure, retry)` where `retry` re-invokes the query path with `attempt = 1`. If it declines (returns falsy / never calls retry), fall through to the existing `on_error` path unchanged. Document the hook next to `pre_query`'s doc block, matching its backward-compatibility note.
- [ ] **Step 4: Run tests** — `make test SPEC=tests/unit/dispatcher_query_spec.lua`.
- [ ] **Step 5: Commit** — `cliproxy: #197 M2: add a provider-agnostic recover_query seam`

### Task 11: wire cliproxy's recovery ladder

**Files:**
- Modify: `lua/parley/cliproxy.lua` (new `recover`), `lua/parley/providers.lua` (register `cliproxyapi.recover_query`)
- Modify: `tests/integration/cliproxy_lifecycle_spec.lua`

- [ ] **Step 1: Write the failing integration tests** against the fake, one per executable action: proxy down → started and retried; healthy credential + transient failure → retried without a prompt; `unavailable` credential → prompt, no retry; `quota` → neither, just a report. Assert *no prompt appears* in the self-repair cases — that is the operator-visible promise of this issue.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** `recover(failure, provider, retry, attempt)`: classify → gather `proxy_state` + `auth_files` health → `decide` → execute. `no_management_route` health short-circuits to a re-render + restart (Task 5's drift path), then retry.
- [ ] **Step 4: Run tests.**
- [ ] **Step 5: Commit** — `cliproxy: #197 M2: execute the recovery ladder on query failure`

### Task 12: end-to-end through a real chat

**Files:**
- Modify: `tests/integration/chat_respond_spec.lua` (or a new `cliproxy_recovery_e2e_spec.lua`)

- [ ] **Step 1** — drive `chat_respond` against the fake serving the #197 503, assert the buffer shows the diagnosis and the spinner/lease tears down cleanly (the failure path at `chat_respond.lua:2046-2065`); then assert a self-repair case completes the answer with no operator interaction.
- [ ] **Step 2** — run, commit.

### Task 13: close M2

- [ ] Update `atlas/`, then `sdlc milestone-close --issue 197 --milestone M2`.

---

## Chunk 3: M3 — Prevent

Outcome: the conditions that created this failure stop recurring.

### Task 14: peer-proxy detection and reaping

**Files:**
- Modify: `lua/parley/cliproxy.lua` (new `peers`, `reap`; fix `stop`), `lua/parley/init.lua` (`:ParleyProxy reap` + completer)
- Modify: `tests/integration/cliproxy_lifecycle_spec.lua`, `tests/unit/` for the pure parsing

- [ ] **Step 1** — split the pure part out first: `cliproxy_auth.parse_peers(ps_output, managed_pid, managed_port_pids)` → the list of foreign proxies, unit-tested against a captured `ps` fixture (including the real one from this issue: four June daemons with deleted configs). Then the IO wrapper runs `ps`.
- [ ] **Step 2** — `ensure_running` warns **once per session** when peers exist, naming the reason: each proxy runs a 15-minute auth auto-refresh over the shared auth-dir, and Claude's refresh tokens rotate, so peers can invalidate each other's credential. Message must name `:ParleyProxy reap`.
- [ ] **Step 3** — `:ParleyProxy reap` SIGTERMs peers after an identity probe (reuse `port_holds_cliproxy`'s discipline — never kill a process merely because it matches a name).
- [ ] **Step 4** — fix `stop()` to reap parley-spawned proxies on non-managed ports too; add the regression test.
- [ ] **Step 5** — tests, commit: `cliproxy: #197 M3: detect and reap peer proxies racing the auth-dir`

### Task 15: login-flow robustness

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`login_argv` → a `login()` that owns the flow), `lua/parley/init.lua:423-432`
- Modify: `tests/integration/cliproxy_auth_login_spec.lua`

- [ ] **Step 1: Preflight the callback port** — claude's redirect is `http://localhost:54545/callback` (confirmed from the binary and from an isolated run). If the port is held, refuse with the exact remedy, including `-oauth-callback-port` as the escape hatch. Test with a socket the spec binds itself.
- [ ] **Step 2: Own the URL** — run the login with `-no-browser`, capture stdout, extract the `https://claude.ai/oauth/authorize?…` line, `vim.ui.open()` it, and show it in a copyable notification so a failed auto-open is still recoverable. The job is no longer tied to a closable terminal buffer — the failure mode from this issue.
- [ ] **Step 3: Detect the outcome** — watch the auth-dir for the written credential (and/or poll `auth_files` until `healthy`), with a bounded timeout. On success: notify with the account, then retry the pending query. On process exit without a credential: report the exit code and stderr instead of dying silently.
- [ ] **Step 4** — tests against the fake (success, callback-port-taken, process-dies-early, timeout), commit: `cliproxy: #197 M3: make the OAuth login observable and resumable`

### Task 16: close the issue

- [ ] Update `atlas/` for the lifecycle/prevention surface; verify `atlas/index.md` links it.
- [ ] Full `make test` + luacheck, both clean.
- [ ] Re-verify the original failure end-to-end: with a deliberately broken credential, confirm the diagnosis names the real cause; with a healthy one, confirm no regression in normal dispatch.
- [ ] `sdlc close --issue 197 --verified '<evidence>'` (let it measure `--actual`).

---

## Notes for the implementer

- **Don't reintroduce guessing.** `classify` (`cliproxy.lua:91`) stays as the *liveness* probe. It must not grow auth opinions — that is `auth_files`' job now. If you find yourself adding an auth case to `classify`, the design has drifted.
- **One retry, ever.** The `attempt` parameter is the whole anti-loop mechanism. Never track retries in module-local state — lessons.md documents module-local one-shot flags leaking across `it` blocks, and this one would leak across *queries*.
- **Error text is API here.** Specs assert on message wording; when you change a message, change its spec deliberately rather than loosening the assertion.
- **The fake is the deliverable, not scaffolding.** If you find yourself reaching for a function-call mock of `vim.system` to test recovery, stop: the seam already exists and the fake already speaks HTTP.
