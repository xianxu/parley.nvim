# cliproxy Auth Self-Healing Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a cliproxyapi query fails for credential reasons, parley diagnoses the real cause from the proxy's own management API, repairs what it can without asking, and prompts only when a human must sit at a browser.

**Architecture:** A new pure module (`cliproxy_auth.lua`) owns the whole decision: it classifies the failure response, classifies credential health from `/v0/management/auth-files`, and returns the *action* to take. `cliproxy.lua` stays a thin IO shell that executes that action. **One seam owns auth failure**: a provider-agnostic `recover_query` hook in the dispatcher's terminal closure — the only place where HTTP status, response body, and the request's model are all in scope. The existing `check_auth_failure` call in `finish_stdout` is deleted, not kept beside it.

**Tech Stack:** Lua / Neovim (`vim.system`, `vim.uv`), plenary.busted, the Python process-level fake at `tests/fixtures/fake_cliproxy`, real `cli-proxy-api` 7.1.71 for conformance.

**Test commands** (this repo does NOT use `make test SPEC=<path>`):
- One spec key: `make test-spec SPEC=providers/cliproxy-managed`
- Everything: `make test` (lint + unit + integration) · Lint alone: `make lint`
- Every new spec file and `lua/parley/cliproxy_auth.lua` must be registered under
  `providers/cliproxy-managed` in `atlas/traceability.yaml`, or `make test-changed`
  silently skips them.

---

## Context an implementer needs

Read `workshop/issues/000197-cliproxy-auth-self-healing.md` first — it holds the verified failure analysis. The facts below were captured from the real binary and are the contract this plan codes against.

**The two failure bodies that must be recognized** (both observed in `~/.cli-proxy-api/logs/`):

```json
{"type":"error","error":{"type":"api_error","message":"auth_unavailable: no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key session and cooldown state via /v0/management/auth-files"}}
{"type":"error","error":{"type":"authentication_error","message":"OAuth access token has expired. Re-authenticate to continue."}}
```

The first arrived with HTTP 503, the second with HTTP 401.

**Message templates in the 7.1.71 binary** (`strings` on the binary; the pattern table matches their rendered form): `%s (providers=%s, model=%s)`, `no auth available`, `auth_unavailable`, `unknown provider for model %s`, `401 unauthorized`, `payment_required`, `model unavailable`, `auth_not_found`.

**`GET /v0/management/auth-files` response** (captured from 7.1.71 against a fabricated credential):

```json
{"files":[{"provider":"claude","type":"claude","account":"probe@example.com","email":"probe@example.com",
  "account_type":"oauth","id":"claude-probe@example.com.json","name":"claude-probe@example.com.json",
  "path":"/…/claude-probe@example.com.json","auth_index":"75f85694b61808ba","label":"probe@example.com",
  "status":"active","status_message":"","unavailable":false,"disabled":false,"runtime_only":false,
  "failed":0,"success":0,"size":395,"source":"file",
  "created_at":"…","updated_at":"…","modtime":"…","recent_requests":[{"time":"21:20-21:30","success":0,"failed":0}, …]}]}
```

After forcing one upstream failure the record became `"status":"error"` with the upstream error verbatim in `status_message` and `"failed":1`. **Authentication:** the route accepts only the `remote-management.secret-key` bearer — the normal `api-keys` bearer gets 401. **Absent key:** with no `secret-key` rendered the route **404s** (the router never registers it). That 404 is load-bearing in this design — see Task 5.

**Two behaviors that shape the design:**
- The proxy hot-reloads auth files (fsnotify → `watcher.AuthUpdate`), so a fresh login needs no restart. Restart is a fallback.
- Every proxy runs `core auth auto-refresh (interval=15m0s)` and attempts a refresh at startup. N proxies over one auth-dir means N refresh loops over one rotating refresh token — the cause of the original expiry.

### Three traps in the existing code (each cost a Critical/Important at the plan gate)

1. **`ensure_running` rewrites the config before it probes** (`cliproxy.lua:295`). Any `config_drift()` check inside the `health_probe` callback compares the file to itself and is always false, and it would never observe what the *running* proxy actually loaded. Detect the stale-config condition from the running proxy instead — the `no_management_route` 404.
2. **`finish_stdout` runs on every completed response** (`dispatcher.lua:266-314`), success included. Anything classified there sees ordinary assistant prose. A chat *about this issue* contains the strings `authentication_error` and `401 unauthorized`. Classification must be gated on a non-2xx HTTP status — and `http_status` does not exist in that closure at all; it is computed in the terminal closure at `dispatcher.lua:388-401`.
3. **The failure table carries no model** (`dispatcher.lua:403-409`). The 401 body has neither provider nor model, and `resolve_login_provider` needs a model to find the channel. The model must be threaded from `payload.model`, which *is* in scope in `query()`.
4. **`on_error` is terminal and irreversible.** It runs `pending_session:failure` → `chat_presentation`'s `failure` event → `finish(state)` + `surface_failure` → `teardown_chat_leg` (`chat_respond.lua:1751-1765`), which latches `leg_teardown_done` and clears the lease. Recovery is *async* (the health lookup is a curl subprocess), so "call `recover_query` before `on_error`" is not enough — `on_error` would still win the race, and the retry's fresh `qid` would stream into a dead session. Recovery must **claim** the failure synchronously.
5. **`retry` cannot reach the query entry point.** `query` is `local query = function` (`dispatcher.lua:163`) — not self-referencable — and `start_query` is a local inside `D.query` (`dispatcher.lua:452`), invisible to the terminal closure nested in `query`. The entry point has to be threaded in as a parameter.

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status | Milestone |
|------|----------|--------|-----------|
| `AuthVerdict` / `classify_response` | `lua/parley/cliproxy_auth.lua` | new | M1 |
| `CredentialHealth` / `classify_auth_files` | `lua/parley/cliproxy_auth.lua` | new | M1 |
| `diagnosis` | `lua/parley/cliproxy_auth.lua` | new | M1 |
| `resolve_channel` | `lua/parley/cliproxy_config.lua` | new | M1 |
| `render` (management-key field) | `lua/parley/cliproxy_config.lua` | modified | M1 |
| `detect_auth_failure` | `lua/parley/cliproxy_config.lua` | deleted | M1 |
| `_failure_notice` | `lua/parley/chat_respond.lua` | new | M1 |
| `RecoveryAction` / `decide` | `lua/parley/cliproxy_auth.lua` | new | M2 |
| `parse_peers` | `lua/parley/cliproxy_auth.lua` | new | M3 |

- **AuthVerdict / `classify_response(http_status, body, request_model)`** — what the proxy said went wrong, as one typed value: `{kind, provider, model, message}` where `kind ∈ {no_auth, unknown_provider, expired, quota, model_unavailable}`, or `nil` for "not an auth failure".
  - **Invariant (PQ-2):** returns `nil` for **every** 2xx status regardless of body. The status gate comes first; the pattern table is only consulted on a non-2xx. This is a property, not a list of cases — see the property test in Task 1.
  - `request_model` backfills `model` when the body carries none (the 401 form), so every verdict can resolve a channel (PQ-3).
  - **Relationships:** 1:1 with a *failed* query response. Consumed by `decide` — and, deliberately, by `cliproxy.recover` in the IO shell, which calls it synchronously to decide the claim (Task 6's contract needs the claim to be cheap and immediate).
  - **DRY rationale:** Replaces `detect_auth_failure`'s single hardcoded pattern and becomes the one place any future cliproxy error string is added.
  - **Future extensions:** New cliproxy versions add message forms — one row in the table, no caller changes.

- **CredentialHealth / `classify_auth_files(files, channel)`** — reduces the management API's record list to that channel's credential state: `{state, message, account, failed, modtime}` with `state ∈ {healthy, error, unavailable, disabled, missing}`.
  - **Relationships:** N records in → 1 health out; the healthiest wins, since the proxy routes to any usable credential.
  - **DRY rationale:** the single interpreter of the management schema — a field rename in cliproxy lands in one function.
  - **Future extensions:** `recent_requests` is already in the payload; an error-trend signal widens here.

- **RecoveryAction / `decide(verdict, health, proxy_state, attempt)`** — the recovery policy as a pure function returning `{action, message, login_provider}` with `action ∈ {start, restart, retry, prompt_login, report}`. `attempt` makes retry exhaustion explicit rather than stateful.
  - **DRY rationale:** keeps the ladder out of callbacks, and collapses the *second* hand-rolled login prompt at `init.lua:412-419` onto the same policy (Task 12 — PQ-5).
  - **Future extensions:** an auto-relogin action is one more enum value; the operator chose prompt-only for this issue.

- **`diagnosis(verdict, health)`** — renders the human sentence from the same inputs. Pure, so wording is unit-tested. Per `workshop/lessons.md`, error text is API here: specs assert on it.

- **`parse_peers(ps_output, own_pids, managed_port_pids)`** — pure parse of `ps` output into the list of foreign `cli-proxy-api` processes.

- **`render` (modified)** — gains `remote-management.secret-key` from an injected `management_key`, and defaults `disable-control-panel: true` when parley supplies the key (PQ-7: parley needs only the JSON route; leaving the control panel registered widens the new loopback surface for nothing). An operator-set value still wins.

- **`detect_auth_failure` (deleted)** — superseded by `classify_response`. `resolve_login_provider` stays and is called with `verdict.model`.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps | Milestone |
|------|----------|--------|-------|-----------|
| `management_key` | `lua/parley/cliproxy.lua` | new | filesystem (`<data_root>/management.key`) | M1 |
| `auth_files` | `lua/parley/cliproxy.lua` | new | `GET /v0/management/auth-files` | M1 |
| `credential_health` | `lua/parley/cliproxy.lua` | new | `auth_files` + the one unattended restart | M1 |
| `api_argv` | `lua/parley/cliproxy.lua` | modified | `curl` (generalized from `models_argv`) | M1 |
| `split_status` | `lua/parley/cliproxy.lua` | new | curl's `-w` status suffix | M1 |
| `recover` | `lua/parley/cliproxy.lua` | new | executes a RecoveryAction | M1 |
| `recover_query` seam | `lua/parley/dispatcher.lua` | new | the adapter contract | M1 |
| `check_auth_failure` | `lua/parley/cliproxy.lua` | deleted | (absorbed by `recover`) | M1 |
| management + auth states | `tests/fixtures/fake_cliproxy` | modified | the real binary's routes | M1 |
| chat-completions error modes | `tests/fixtures/fake_cliproxy` | modified | the real binary's error bodies | **M2** |
| `peers` / `reap` | `lua/parley/cliproxy.lua` | new | `ps` / `lsof` / `uv.kill` | M3 |
| `login` (hardened) | `lua/parley/cliproxy.lua` | modified | `cli-proxy-api -claude-login` | M3 |
| login modes | `tests/fixtures/fake_cliproxy` | modified | the real binary's `-claude-login` | M3 |

- **`management_key()`** — read-or-create a 32-hex-char key at `<data_root>/management.key`, mode 0600, beside the rendered config. Not the vault: the vault is in-memory and populated from `setup{}`, and this key must survive restarts without landing in the operator's dotfiles.
- **`auth_files(cb, channel)`** — GET the management route, decode, hand the records to `classify_auth_files`. Returns `{state="unknown", reason="no_management_route"}` on 404, distinct from 401 / transport failure, because that 404 is the *repairable* "running proxy predates the key" state (PQ-1).
- **`api_argv(host, port, secret, route)`** — `models_argv` generalized to any route so the health probe, the stop-time identity check, `list_models`, and `auth_files` share one request shape (ARCH-DRY; the comment at `cliproxy.lua:117` already claims this role — this keeps the claim true).
- **`recover(failure, retry)`** — the single owner of auth-failure reaction: classify → gather health → `decide` → execute. Replaces `check_auth_failure` outright (PQ-4).
- **`peers()` / `reap()`** — enumerate `cli-proxy-api` processes parley did not spawn; `reap` SIGTERMs them after an identity probe. Warn-once state is module-local with a `_reset` test seam (lessons.md: module-local one-shot flags leak across `it` blocks).
- **`recover_query(failure, retry, give_up)` seam** — optional adapter hook in the **terminal closure** (`dispatcher.lua:383-425`), the only scope holding `http_status`, the body, and (once Task 6 threads it) the request's model. Mirrors `pre_query`'s optional/backward-compatible shape; adapters without it behave exactly as today. **It claims the failure synchronously** — see "The claim contract" below, which is the only thing standing between an async recovery and a torn-down chat leg.
- **`fake_cliproxy` (modified)** — the existing process-level fake grows:
  - **management route + credential store**: a folder of auth JSON files plus a `state.json` overlay (`{"claude": {"status": "error", "status_message": "…", "unavailable": true}}`) so tests mutate credential state *between* calls and the double stays stateful (ARCH-MOCK). Serves 401 on a wrong bearer and **404 when the config has no `remote-management.secret-key`**.
  - **error modes** on `/v1/chat/completions`: `no_auth` (the real 503 body), `expired` (the real 401 body), `quota`, and `ok`.
  - **login modes** (PQ-6), selected by `--login-mode`: `success` — print the `https://claude.ai/oauth/authorize?…` line on stdout and write a credential into the auth-dir after a short delay; `port_taken` — bind the callback port and idle; `dies_early` — print the URL then exit non-zero; `hangs` — print the URL and never write a credential (timeout case).

---

## Chunk 1: M1 — Diagnose

Outcome: tonight's 503 produces a real diagnosis through the single owning seam. Recovery actions arrive in M2; M1's `decide` stand-in only ever reports or prompts.

### Task 1: `classify_response` — the failure vocabulary, status-gated

**Files:**
- Create: `lua/parley/cliproxy_auth.lua`
- Create: `tests/unit/cliproxy_auth_spec.lua`

- [ ] **Step 1: Write the failing tests** — the property first, because it is the invariant that keeps this off the success path:

```lua
local ca = require("parley.cliproxy_auth")

-- The exact body from issue #197 (215 bytes, HTTP 503).
local NO_AUTH = '{"type":"error","error":{"type":"api_error","message":"auth_unavailable: '
    .. 'no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key '
    .. 'session and cooldown state via /v0/management/auth-files"}}'
local EXPIRED = '{"type":"error","error":{"type":"authentication_error","message":'
    .. '"OAuth access token has expired. Re-authenticate to continue."}}'

describe("classify_response", function()
    it("PROPERTY: never classifies a 2xx, whatever the body says", function()
        -- Assistant prose that quotes every trigger word — e.g. a chat about
        -- this very issue. Regression guard for the gate's PQ-2.
        local prose = "The proxy returned authentication_error and 401 unauthorized, "
            .. "then payment_required; the model unavailable path is auth_unavailable: "
            .. "no auth available (providers=claude, model=claude-opus-4-8)."
        for _, body in ipairs({ prose, NO_AUTH, EXPIRED, "", "data: [DONE]" }) do
            for _, status in ipairs({ 200, 201, 204, 299 }) do
                assert.is_nil(ca.classify_response(status, body),
                    ("classified a %d as a failure: %s"):format(status, body:sub(1, 40)))
            end
        end
    end)

    -- Remaining cases, one `it` each:
    --   503 + NO_AUTH            → kind=no_auth, provider=claude, model=claude-opus-4-8
    --   401 + EXPIRED + model    → kind=expired, model backfilled from request_model
    --   401 + EXPIRED, no model  → model stays nil (no guessing)
    --   500 + legacy body        → kind=unknown_provider, model from the body
    --   402 + payment_required   → kind=quota (NOT an auth prompt)
    --   500 + "dial tcp: …"      → nil (a non-auth 5xx is not our business)
    --   nil body / nil status    → nil (no status ⇒ cannot judge)
end)
```

- [ ] **Step 2: Run and watch it fail** — `make test-spec SPEC=providers/cliproxy-managed`. Expected: module not found. (Register the new files in `atlas/traceability.yaml` first, or the runner will not see the spec at all.)

- [ ] **Step 3: Implement**

```lua
--------------------------------------------------------------------------------
-- Pure auth-failure reasoning for the managed cliproxyapi instance (issue #197).
--
-- No IO, no clock, no vim.* state (ARCH-PURE): every function is a
-- deterministic transform, unit-tested without mocks. The IO shell
-- (parley/cliproxy.lua) gathers the inputs and executes the action decided here.
--------------------------------------------------------------------------------

local M = {}

-- cliproxyapi's failure vocabulary, most specific first. Verified against the
-- 7.1.71 binary's format strings (see the plan's "Context an implementer
-- needs"). Adding support for a new cliproxy error is one row here and nothing
-- else (ARCH-DRY).
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

return M
```

`classify_response(http_status, body, request_model)` then: **status gate first** — return nil unless `http_status` is a number outside 200–299 (this is the whole safety story; the patterns are broad enough to match ordinary assistant prose and the caller sees successful bodies too), nil on an empty body, then first-match wins over `FAILURES`, filling the row's named captures and falling back to `request_model` for `model`. A `_message` helper pulls `"message":"…"` out of cliproxy's error envelope for the human sentence.

Two constraints the tests pin, both easy to break silently:
- The `(providers=…, model=…)` row must precede the bare `auth_unavailable` row, or the captures are lost.
- An unknown/nil status is treated as *not* a failure, not as a failure — never classify what you cannot place.

- [ ] **Step 4: Run tests** — expect PASS (8 examples).
- [ ] **Step 5: Register in `atlas/traceability.yaml`** — add `lua/parley/cliproxy_auth.lua` to `providers/cliproxy-managed`'s `code:` and `tests/unit/cliproxy_auth_spec.lua` to its `tests:`.
- [ ] **Step 6: Commit** — `cliproxy: #197 M1: classify auth failures by vocabulary, gated on non-2xx`

### Task 2: `classify_auth_files` — credential health from the management record

**Files:**
- Modify: `lua/parley/cliproxy_auth.lua`, `tests/unit/cliproxy_auth_spec.lua`
- Create: `tests/fixtures/cliproxy_auth_files.json` (the captured 7.1.71 payload, shared with Task 7's conformance check)

- [ ] **Step 1: Write the failing tests** — with a record helper so each test states only what it cares about:

```lua
local function rec(over)
    return vim.tbl_extend("force", {
        provider = "claude", type = "claude", account = "me@example.com", email = "me@example.com",
        status = "active", status_message = "", unavailable = false, disabled = false,
        failed = 0, success = 3, modtime = "2026-08-01T00:34:46-07:00",
    }, over or {})
end
```

Cases: active → `healthy` (carries `account`); no record for the channel → `missing`; empty list → `missing`; `status="error"` → `error` carrying `status_message` and `failed`; `unavailable` and `disabled` each outrank `status`; several credentials → healthiest wins and its account is reported; a record with `provider` absent matches on `type`.

- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement** — filter records by `(f.provider or f.type) == channel`, map each to a state in precedence order `disabled > unavailable > status ~= "active" > healthy`, and keep the best by an explicit rank table:

```lua
-- Worst-to-best so "healthiest wins" is a simple max: the proxy routes to any
-- usable credential, so one healthy record makes the channel usable regardless
-- of how many dead ones sit beside it.
local HEALTH_RANK = { missing = 0, disabled = 1, unavailable = 2, error = 3, healthy = 4 }
```

  The returned health carries `state`, `message` (the record's `status_message` when non-empty, else a generated `"credential is <state>"`), `account` (`account` or `email`), `failed`, and `modtime`. Default when nothing matches: `{state = "missing"}`. The risky part is the rank collision across multi-record lists — that is what the "healthiest wins and reports *its* account" test pins.

- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M1: derive credential health from the management record`

### Task 3: render the management key

**Files:** Modify `lua/parley/cliproxy_config.lua:45-67` (`render`), `tests/unit/cliproxy_config_spec.lua`

- [ ] **Step 1: Write the failing tests** — key present → `remote-management["secret-key"]`; parley defaults `disable-control-panel = true` (PQ-7); an operator-set `disable-control-panel = false` still wins; `allow-remote` never set; **no key → no `remote-management` block at all** (pins that operators who never enable this see a byte-identical config).
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement** — after the `api-keys` block:

```lua
    if opts.management_key ~= nil and opts.management_key ~= "" then
        -- Merge, never replace: the operator's raw `remote-management` block
        -- passes through. `allow-remote` is deliberately never set (loopback
        -- only), and the control panel is off unless the operator asked for it —
        -- parley needs only the JSON route.
        local rm = type(cfg["remote-management"]) == "table" and cfg["remote-management"] or {}
        rm["secret-key"] = opts.management_key
        if rm["disable-control-panel"] == nil then
            rm["disable-control-panel"] = true
        end
        cfg["remote-management"] = rm
    end
```

- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M1: render a loopback-only management secret-key`

### Task 4: `management_key()` + `auth_files()` + argv generalization

**Files:** Modify `lua/parley/cliproxy.lua`, `tests/integration/cliproxy_lifecycle_spec.lua`, `tests/fixtures/fake_cliproxy`

- [ ] **Step 1: Extend the fake** — management route + credential store + the 404-without-key behavior, per the integration-points table above. Store on disk so state mutates between calls.
- [ ] **Step 2: Write the failing integration tests** — healthy store → `state == "healthy"`; store with `state.json` marking claude `unavailable` → `state == "unavailable"` with the message; fake started from a **key-less** config → `{state="unknown", reason="no_management_route"}`; wrong bearer → `reason` distinguishes 401 from 404; `management_key()` is stable across calls, 32 chars, file mode 0600.
- [ ] **Step 3: Implement** — `api_argv(host, port, secret, route)` (parameterize `models_argv`'s trailing path, default `/v1/models`; update its three callers). `management_key()` reads-or-creates `<data_root>/management.key` from `vim.uv.random(16)`, 0600. `render_opts()` gains `management_key = M.management_key()`. Then:

```lua
--- Fetch credential health for `channel`. Distinguishes the repairable "route
--- not registered" 404 from real failures: a 404 means the RUNNING proxy
--- predates the management key and must be restarted into the freshly rendered
--- config — the only reliable signal of that, since ensure_running rewrites the
--- config file before it probes (so a file-vs-render drift check is always
--- false there).
---@param cb fun(health: table)
---@param channel string
function M.auth_files(cb, channel)
    local opts = render_opts()
    vim.system(api_argv(opts.host, opts.port, M.management_key(), "/v0/management/auth-files"),
        { text = true }, function(obj)
            local body, http = (obj.stdout or ""):match("^(.*)\n(%d+)%s*$")
            vim.schedule(function()
                if obj.code ~= 0 then
                    return cb({ state = "unknown", reason = "unreachable", message = obj.stderr })
                end
                http = tonumber(http)
                if http == 404 then
                    return cb({ state = "unknown", reason = "no_management_route" })
                elseif http == 401 then
                    return cb({ state = "unknown", reason = "management_key_mismatch" })
                elseif http ~= 200 then
                    return cb({ state = "unknown", reason = "http_" .. tostring(http) })
                end
                local ok, decoded = pcall(vim.json.decode, body or "")
                if not ok or type(decoded) ~= "table" then
                    return cb({ state = "unknown", reason = "undecodable" })
                end
                cb(ca.classify_auth_files(decoded.files, channel))
            end)
        end)
end
```

- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M1: read credential health over the management API`

### Task 5: restart a proxy that predates the management key

**Files:** Modify `lua/parley/cliproxy.lua` (`recover`'s entry path), `tests/integration/cliproxy_lifecycle_spec.lua`

Replaces the config-drift idea the gate killed (PQ-1): `ensure_running` writes the rendered config *before* probing (`cliproxy.lua:295`), so a file-vs-render comparison there is always false and never reflects what the running proxy loaded. The `no_management_route` 404 is the honest signal — it comes from the running process.

- [ ] **Step 1: Write the failing test** — start the fake from a key-less config; call the health lookup; assert parley restarts the proxy (old pid gone, new one answering) and the second lookup succeeds. Assert the **negative** too: when the route already answers 200, no restart happens (reuse-if-healthy must not regress into restart-per-query).
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement** — a `_management_restart_done` one-shot guard (module-local, with `_reset` for tests) so a proxy that 404s for any other reason cannot cause a restart loop: on the first `no_management_route`, `stop()` + `ensure_running` + re-query; on a second, report.
- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M1: restart a proxy that predates the management route`

### Task 6: the single owning seam — `recover_query`, and delete `check_auth_failure`

**Files:** Modify `lua/parley/dispatcher.lua` (terminal closure `383-425`, `query()` signature area, `finish_stdout` `304-314`), `lua/parley/cliproxy.lua` (`recover`, delete `check_auth_failure`), `lua/parley/providers.lua`, `lua/parley/cliproxy_config.lua` (delete `detect_auth_failure`); tests: `tests/unit/dispatcher_query_spec.lua`, `tests/unit/cliproxy_config_spec.lua:167-177`, `tests/integration/cliproxy_auth_login_spec.lua`

This is the task that resolves PQ-2/PQ-3/PQ-4/PQ-8 together. **One seam**, in the terminal closure — the only scope with `http_status`, the body, and the model.

#### The claim contract (PQ-8)

`on_error` is terminal (trap 4 above) and recovery is async, so the seam cannot merely run "before `on_error`" — it must decide *synchronously* whether it owns this failure:

```
adapter.recover_query(failure, retry, give_up) -> boolean claimed
```

- **Returns falsy** → the dispatcher calls `on_error` immediately, exactly as today. Adapters without the hook take this path by definition, so nothing about existing providers changes.
- **Returns truthy** → the dispatcher does **not** call `on_error`. The adapter now owes exactly one of `retry()` or `give_up(msg)`.
  - `retry()` re-enters the query at `attempt + 1`.
  - `give_up(msg)` runs the original `on_error` path, with `msg` replacing the raw body in the notice.
  - Both are wrapped in **one shared** `tasker.once`, so the first to land wins and nothing can double-fire.
  - The dispatcher arms a bounded timer (15s, `vim.defer_fn`) that calls `give_up("cliproxy: recovery timed out")`. A hung recovery therefore degrades to today's behavior instead of stranding the chat leg forever.

The claim is cheap and deterministic because the decision input — `classify_response` — is pure and synchronous. cliproxy claims iff **all** of: a non-nil verdict, `attempt == 0`, and `failure.streamed == false`. That last one is the retry precondition: `handler` has already written any streamed content into the buffer, so re-running would duplicate it. Each `query()` mints a fresh `qid` with clean `raw_response`/`response` (`dispatcher.lua:175-188`), so a retry from a non-streamed failure is otherwise clean state.

- [ ] **Step 1: Write the failing tests**
  - `finish_stdout` no longer classifies anything: a **successful** response whose text quotes `authentication_error` produces no prompt and no diagnosis (the PQ-2 regression).
  - The failure table carries `model` (from `payload.model`) and `streamed` (from `qt.response ~= ""`).
  - An adapter with no `recover_query` behaves exactly as today — the existing failure specs must pass untouched.
  - **Claim semantics:** an adapter returning false ⇒ `on_error` fires once, immediately. Returning true ⇒ `on_error` has *not* fired; then `give_up("x")` ⇒ `on_error` fires once with `"x"`; and `retry()` ⇒ the query re-issues once with an identical payload and `on_error` never fires.
  - **Anti-double-fire:** an adapter that calls `retry()` then `give_up()` (or either one twice) still produces exactly one outcome.
  - **Timeout:** an adapter that claims and then does nothing ⇒ `on_error` fires once, after the timer, with the timeout message. Drive the clock rather than sleeping 15s in a spec.
  - **Streamed guard:** a failure after partial content ⇒ cliproxy declines the claim ⇒ no duplicate text in the buffer.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement**
  - `dispatcher.lua`: thread the entry point in (PQ-8 part 2) — `query` gains trailing `restart, attempt` parameters, and `D.query` builds `local function start_query(n) query(…, start_query, n or 0) end` (declared with `local function` so it can pass itself down). Add `model = payload.model` and `streamed = qt.response ~= ""` to the `failure` table. In the `failed` branch, implement the claim contract above. Document it beside `pre_query`'s doc block (`dispatcher.lua:437-443`).
  - Delete the `check_auth_failure` call at `dispatcher.lua:311-313` and the function itself. Delete `detect_auth_failure`.
  - `providers.lua`: register `cliproxyapi.recover_query`, delegating to `cliproxy.recover`.
  - `cliproxy.recover(failure, retry, give_up)` for M1: classify synchronously and return the claim; if claimed, resolve the channel via `resolve_login_provider(verdict.model, oauth-model-alias)` → `auth_files(_, channel)` → `diagnosis` → notify or prompt, then **always** call `give_up(diagnosis)`. M1 never calls `retry` — M2 adds the actions that do.
- [ ] **Step 4: Run the full suite** — `make test`, 0 failures, luacheck clean.
- [ ] **Step 5: Grep for leftovers** — `detect_auth_failure`, `check_auth_failure`, and the literal `unknown provider for model` across `lua/ tests/ atlas/` (lessons.md: grep for the behavior, not just the symbol).
- [ ] **Step 6: Commit** — `cliproxy: #197 M1: own auth-failure reaction in one status-aware seam`

### Task 7: live conformance check

**Files:** Create `tests/integration/cliproxy_conformance_spec.lua`

- [ ] **Step 1: Write the test** — skip (loudly) unless `cliproxy.discover_binary()` finds a real binary, so CI without one stays green rather than silently passing. Boot the real binary on a free port with a temp auth-dir holding a **fabricated** credential (`sk-ant-oat01-` + filler, `expired` in the past) and a rendered management key; GET `/v0/management/auth-files`; assert every field `classify_auth_files` reads still exists (`provider`/`type`, `status`, `status_message`, `unavailable`, `disabled`, `failed`, `modtime`). Tear down in `after_each`.

  **Never point this at the operator's real auth-dir.** The binary attempts a token refresh at startup and every 15m; a fabricated credential makes that harmless, a real one would rotate the operator's live refresh token. `_set_data_dir` is the established guard for the same class of mistake.

- [ ] **Step 2: Run it. Step 3: Commit** — `cliproxy: #197 M1: pin the management-API contract against the real binary`

### Task 8: close M1

- [ ] Update `atlas/` for the auth-diagnosis surface; link from `atlas/index.md`; confirm every new file is in `atlas/traceability.yaml`.
- [ ] `sdlc milestone-close --issue 197 --milestone M1`; fix Critical/Important before crossing; log the verdict in `## Log`.

---

## Chunk 2: M2 — Recover

Outcome: recoverable failures repair themselves and the query retries; only a dead credential prompts.

### Task 9: `decide` — the recovery policy, pure

**Files:** Modify `lua/parley/cliproxy_auth.lua`, `tests/unit/cliproxy_auth_spec.lua`

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
| any | – | – | ≥1 | never `retry`/`restart`/`start` |

- [x] **Step 1: One test per row**, plus the anti-loop property: loop every `kind` × every `health.state` at `attempt = 1` and assert the action is always in `{prompt_login, report}`.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** — `proxy_state` is `{running, auth_file_modtime, record_modtime}`; the staleness comparison is a string compare on RFC3339 timestamps only when both are present, else treat as not-stale (never guess).
- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M2: decide recovery as a pure policy`

### Task 10: execute the ladder

**Files:** Modify `lua/parley/cliproxy.lua` (`recover` gains the action switch), `tests/integration/cliproxy_lifecycle_spec.lua`

- [ ] **Step 1: Write the failing integration tests**, one per executable action against the fake: proxy down → started and retried; healthy credential + transient failure → retried, **no prompt**; `unavailable` → prompt, no retry; `quota` → neither. The "no prompt appears" assertions are the operator-visible promise of this issue — assert them explicitly, not by omission.
- [ ] **Step 2: Run and watch them fail.**
- [ ] **Step 3: Implement** the switch over `decide`'s action, passing `attempt` through from the seam. Every branch terminates the claim exactly once (Task 6's contract): `retry`/`restart`/`start` end in `retry()`, `prompt_login`/`report` end in `give_up(message)`. A branch that falls through without calling either would hang the chat leg until the 15s timer — add a spec that exercises **every** action value and asserts an outcome landed, so a future action added to the enum cannot silently skip this.
- [ ] **Step 4: Run tests. Step 5: Commit** — `cliproxy: #197 M2: execute the recovery ladder on query failure`

### Task 11: end-to-end through a real chat

**Files:** Create `tests/integration/cliproxy_recovery_e2e_spec.lua`

- [ ] Drive `chat_respond` against the fake serving the #197 503: assert the buffer shows the diagnosis and the spinner/lease tears down cleanly (`chat_respond.lua:2046-2065`). Then a self-repair case: assert the answer completes with no operator interaction. Register the spec in `atlas/traceability.yaml`. Commit.

### Task 12: collapse the second login prompt (PQ-5)

**Files:** Modify `lua/parley/init.lua:403-422`, `tests/integration/cliproxy_command_spec.lua`

`:ParleyProxy models <provider>` hand-rolls its own "not authenticated → log in?" prompt from an empty model list. That is a second, weaker copy of this issue's policy — and empty-list is exactly the inference this issue proved unreliable.

- [ ] Route it through `auth_files` + `decide` so both paths give the same diagnosis and the same prompt. Test that an empty list with a *healthy* credential no longer claims "not authenticated". Commit.

### Task 13: close M2

- [ ] Update `atlas/`; `sdlc milestone-close --issue 197 --milestone M2`.

---

## Chunk 3: M3 — Prevent

Outcome: the conditions that created this failure stop recurring.

### Task 14: peer-proxy detection and reaping

**Files:** Modify `lua/parley/cliproxy.lua` (`peers`, `reap`, `stop`), `lua/parley/cliproxy_auth.lua` (`parse_peers`), `lua/parley/init.lua` (`:ParleyProxy reap` + completer); tests in `tests/unit/cliproxy_auth_spec.lua` + `tests/integration/cliproxy_lifecycle_spec.lua`

- [ ] **Step 1** — pure first: `parse_peers(ps_output, own_pids, managed_port_pids)` unit-tested against a captured `ps` fixture, including the real one from this issue (four June daemons, configs deleted, ports 8327/8331/8333/8335).
- [ ] **Step 2** — `ensure_running` warns **once per session** when peers exist, naming the mechanism: each proxy runs a 15-minute auth auto-refresh over the shared auth-dir and Claude's refresh tokens rotate, so peers invalidate each other's credential. The message must name `:ParleyProxy reap`.
- [ ] **Step 3** — `:ParleyProxy reap` SIGTERMs peers **after an identity probe** (reuse `port_holds_cliproxy`'s discipline — never kill a process merely because its name matches).
- [ ] **Step 4** — fix `stop()` to also reap parley-spawned proxies on non-managed ports; add the regression test.
- [ ] **Step 5** — tests, commit: `cliproxy: #197 M3: detect and reap peer proxies racing the auth-dir`

### Task 15: login-flow robustness

**Files:** Modify `lua/parley/cliproxy.lua` (`login_argv` → a `login()` owning the flow), `lua/parley/init.lua:423-432`, `tests/integration/cliproxy_auth_login_spec.lua`, `tests/fixtures/fake_cliproxy` (login modes)

- [ ] **Step 1: Preflight the callback port** — claude's redirect is `http://localhost:54545/callback` (confirmed from the binary and an isolated run). If held, refuse with the exact remedy including `-oauth-callback-port`. Test against the fake's `port_taken` mode.
- [ ] **Step 2: Own the URL** — run with `-no-browser`, capture stdout, extract the `https://claude.ai/oauth/authorize?…` line, `vim.ui.open()` it, and surface it copyably so a failed auto-open is still recoverable. The job no longer depends on a closable terminal buffer — the exact failure from this issue.
- [ ] **Step 3: Detect the outcome** — watch the auth-dir for the credential (and/or poll `auth_files` until `healthy`) with a bounded timeout. Success → notify with the account, then retry the pending query. Process exits without a credential → report exit code and stderr instead of dying silently. Test against `success`, `dies_early`, and `hangs`.
- [ ] **Step 4** — tests, commit: `cliproxy: #197 M3: make the OAuth login observable and resumable`

### Task 16: close the issue

- [ ] Update `atlas/`; verify `atlas/index.md` and `atlas/traceability.yaml` cover every new file.
- [ ] Full `make test` + `make lint`, both clean.
- [ ] Re-verify the original failure end to end: with a deliberately broken credential the diagnosis names the real cause; with a healthy one, normal dispatch is unchanged.
- [ ] `sdlc close --issue 197 --verified '<evidence>'` (let it measure `--actual`).

---

## Revisions

### 2026-08-01 — after the M1 boundary review (REWORK → rework applied)

Reason: the M1 review found one Critical regression and six Important items; the
plan needed three corrections so later milestones aren't planned against a
description that no longer matches the code.

1. **Integration-points table was incomplete for what M1 shipped.**
   `credential_health` — a new public function carrying the whole 404-repair
   policy — appeared only as Task 5 prose. Added, along with `split_status`.
2. **The fake's `/v1/chat/completions` error modes did NOT ship in M1.** The
   integration-points table listed them under the same `fake_cliproxy` bullet as
   the management route, so the table claimed a capability that does not exist.
   Only the management route + credential store + 404 behavior landed in M1;
   the `no_auth`/`expired`/`quota`/`ok` modes move explicitly into **M2 Task 10**,
   which needs them anyway to stop hand-building failure tables.
3. **Core-concepts rows now carry a milestone column.** `decide` and
   `parse_peers` were listed as "new" with no milestone, so an M1 reviewer
   cross-checking the table against the filesystem found entities that do not
   exist yet. Added `_failure_notice` (M1), extracted during the rework so the
   user-visible last mile is testable.

Carried into M2 from the review's architectural notes:

- `recover`'s `needs_human` predicate is decision logic currently living in the
  IO shell. It must move inside `decide` when Task 9 lands, or M2 ships with two
  policy owners.
- Task 11's e2e spec should drive `dispatcher.query` → `recover_query` →
  `on_error` → the chat notice against the fake's new `no_auth` mode. M1 covered
  those three links individually but never as one path.
- Task 12 (collapsing `:ParleyProxy models`' empty-list inference onto `decide`)
  is the last hand-maintained "empty list ⇒ not authenticated" claim in the
  codebase — the exact inference this issue disproved. It must not survive M2.

### 2026-08-01 — after M1 boundary review round 2 (REWORK → applied)

Round 2 found two more Criticals. Both were invisible to round 1's tests, and
the plan needed corrections so M2 isn't built on the same assumptions.

1. **Name the channel axis explicitly (C1).** The plan said "channel" throughout
   but only ever named `resolve_login_provider` as the resolver — a *different*
   namespace. `gemini`/`gemini-cli`/`aistudio` all collapse to the login provider
   `google`, while `/v0/management/auth-files` reports the channel, so health
   lookups for those three silently found nothing and prompted a spurious login.
   `resolve_channel` is now the single model→channel source (added to the
   Core-concepts table, M1) and `resolve_login_provider` derives from it. When no
   channel resolves, parley reports `unknown_channel` — it does **not** default
   to `claude`, which would confidently report another account's health.
2. **The repair has a managed-mode precondition (C2).** Task 5's restart is only
   legitimate under `is_managed()`: `stop()` reaps the port holder from any
   session and `ensure_running` does not spawn when unmanaged, so the repair
   would kill an operator's own proxy and leave it dead.
3. **The retry re-issues from a per-attempt payload snapshot.** `format_headers`
   consumes payload fields (`_parley_route`, `model`), so M2 Task 10's ladder
   would otherwise retry a materially different request than the one that failed.
4. **Integration-points table now carries a milestone column**, matching
   Core-concepts, and records that the fake's chat-completions error modes are
   **M2**, not M1.
5. **Corrected a stale claim**: `classify_response` is consumed by the IO shell
   too — `recover` calls it synchronously to make the claim decision cheap.

### 2026-08-01 — after M2 boundary review (REWORK → applied)

1. **Staleness is a normalization, not a string compare.** The plan instructed
   "a string compare on RFC3339 timestamps only when both are present" — valid
   only if both sides carry the same offset, which the shell cannot guarantee.
   Both timestamps are now normalized to epoch seconds at the IO seam
   (`uv.fs_stat().mtime.sec` on disk; `cliproxy_auth.rfc3339_sec` parses the
   proxy's offset-bearing, fractional-second form), and `proxy_state` carries
   `auth_file_modtime` compared against `health.modtime` — the plan's
   `record_modtime` field never existed.
2. **A third axis exists.** M1 round 2 named channel vs login provider;
   `:ParleyProxy models` revealed a third — the model-owning provider set
   (`providers()`), which coincides with the channel for five of six values and
   not for `google`. `channels_for_login` derives the inverse from
   `CHANNEL_LOGIN`, and `credential_health_for_login` reads every channel a login
   serves, keeping the healthiest.
3. **Task 12 shares policy via `credential_action`,** not via `decide` (which
   needs a verdict the command has no way to produce). Both consumers now agree
   on what `error` means.
4. **The repair budget covers the whole claimed path** — including `recover`'s
   pre-flight liveness probe and the `start`/`restart` rung, neither of which
   existed when Task 5 itemized it — and is asserted by `cliproxy_budget_spec`
   rather than restated in a comment that says "re-check the other".
5. **Task 10's exhaustive-action spec is delivered**, driving every `decide`
   action through `recover` and asserting exactly one settle each.

### 2026-08-01 — what actually shipped (M2 review rounds 3–5)

The plan had drifted from the code on five counts. Recording the shipped shape:

1. **Staleness compares `modtime` vs `updated_at`, both from the management
   record** — not a file mtime against a reported one. Those were the *same
   quantity*, which is why three successive fixes to the comparison left the
   `restart` rung dead. The check is pure; there is no `fs_stat` term.
2. **`credential_health` reports whether it restarted**, and `recover` latches
   that per claim. Module state cannot serve: the repair clears its own flag
   before the decision that consults it.
3. **The peer scan latches on the scan, not on finding peers.** The zero-peer
   case is the one the operator lives in after using `reap`, and it was paying a
   ~150ms blocking `ps`+`lsof` per dispatch.
4. **`run_login` does not take over the browser flow.** No `-no-browser`, no URL
   matching: each provider's flow differs, and intercepting a claude-shaped URL
   broke every other provider. Parley surfaces the binary's output (debounced)
   and reports the outcome once.
5. **`login_argv` validates the flag against `<binary> -h`.** The flag set is
   version-dependent — 7.2.110 dropped `-login` that 7.1.71 has — so a static
   table silently mis-reports what the installed binary can do.

**Descoped, with reason:** resuming the triggering query after a successful
login (Task 15 Step 3). A login takes minutes; the recovery claim is bounded by
`recovery_timeout_ms`. Holding the chat leg open across it would guarantee the
timeout the backstop exists to prevent. The claim settles with the diagnosis and
the operator re-sends.

**Boundary bookkeeping:** M3's commits landed inside M2's review window, because
the M2 rounds outlasted the M2 work. M3's code was reviewed — rounds 3–5 found
and fixed defects in `reap`, `peers`, and the login flow — but under M2's
boundary. M3's own close covers the remaining delta and records this.

## Notes for the implementer

- **Don't reintroduce guessing.** `classify` (`cliproxy.lua:91`) stays the *liveness* probe and must not grow auth opinions — that is `auth_files`' job. If you find yourself adding an auth case to `classify`, or inferring auth from an empty model list, the design has drifted. Both inferences are what failed on 2026-08-01.
- **The status gate is not optional.** `classify_response` is called on responses parley has already decided are failures, but the patterns are broad and the cost of a false positive is an unprompted login dialog mid-conversation. Keep the 2xx property test green.
- **A claim is a debt.** Once `recover_query` returns truthy, the chat leg is held open and *only* `retry()` or `give_up()` releases it. Every path out of `recover` — including early returns on a decode failure or an unreachable proxy — must end in one of them. The 15s timer is a backstop against a bug, not a design element to lean on.
- **One retry, ever.** The `attempt` parameter is the whole anti-loop mechanism. Never track retries in module-local state — lessons.md documents module-local one-shot flags leaking across `it` blocks, and this one would leak across *queries*.
- **Error text is API here.** Specs assert on wording; change a message deliberately, with its spec — don't loosen the assertion.
- **The fake is the deliverable, not scaffolding.** If you reach for a function-call mock of `vim.system` to test recovery, stop: the seam exists and the fake speaks HTTP.
