# Managed cliproxyapi Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let parley opt-in to *managing* a cliproxyapi instance — render its `config.yaml` from Lua `setup{}`, and lazily start/health-check/reuse the proxy on demand — so users stop hand-maintaining `/opt/homebrew` config and `brew services`.

**Architecture:** A **pure config core** (`cliproxy_config.lua`: parse host:port from the provider endpoint, merge the raw `config` passthrough with wiring fields, inject the resolved client secret, emit JSON-as-YAML) injected into a **thin IO shell** (`cliproxy.lua`: binary discovery, `vim.uv` detached spawn, identity-checked health probe, reuse-if-healthy, the `:ParleyProxy` commands). The shell is reached through the **existing `pre_query` adapter seam** (the one copilot already uses to prep before a query) — no new dispatcher branch. ARCH-PURE (pure core, thin IO) and ARCH-DRY (reuse `pre_query` + `vault`, don't re-model cliproxy's schema) shape the split.

**Tech Stack:** Lua (Neovim), `vim.uv` (libuv) for process spawn + TCP, `vim.json` for JSON-as-YAML emission, `curl` (already parley's transport) for the health probe, Plenary/busted for tests.

**Spec:** `workshop/issues/000131-managed-cliproxy.md` (`## Spec`).

---

## Core Concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_endpoint` | `lua/parley/cliproxy_config.lua` | new |
| `render` | `lua/parley/cliproxy_config.lua` | new |
| `encode` | `lua/parley/cliproxy_config.lua` | new |
| `asset_name` | `lua/parley/cliproxy_config.lua` | new (M2) |

- **parse_endpoint** — `"http://127.0.0.1:8317/v1/chat/completions"` → `host="127.0.0.1", port=8317`. The provider endpoint is the single source of truth for host:port (spec §"host:port — single source of truth"); everything downstream derives from it. ARCH-DRY: kills the "second port knob" drift.
  - **Relationships:** 1:1 with the resolved `D.providers.cliproxyapi.endpoint` string.
  - **Future extensions:** unix-socket endpoints; scheme-aware default ports.

- **render** — given `{ host, port, auth_dir, secret, config }`, returns the cliproxy config *table*: deep-copies the raw `config` passthrough, overlays the wiring fields (`host`, `port`, `auth-dir`), and injects the resolved `secret` as the sole `api-keys` entry. Returns `(config_table, overrides)` where `overrides` lists any raw-config keys it clobbered (so the IO caller can warn). PURE: takes the already-resolved secret as an argument — it does **not** touch the vault. ARCH-DRY: does not re-model cliproxy's schema; unknown keys pass through untouched.
  - **Relationships:** consumes `parse_endpoint` output + the `M.config.cliproxy` block + a resolved secret string.
  - **DRY rationale:** one place that knows the wiring-field names (`host`/`port`/`auth-dir`/`api-keys`); the rest of cliproxy's schema is the user's.
  - **Future extensions:** multiple `api-keys`; per-model routing helpers.

- **encode** — `config_table` → string via `vim.json.encode` (JSON is valid YAML 1.2, so cliproxy's YAML parser accepts it — the spec's gating bet). PURE (vim.json is deterministic, no IO).
  - **Future extensions:** a minimal nested+list YAML emitter fallback **iff** the gating task proves cliproxy rejects JSON (spec §Emission).

- **asset_name** *(M2)* — `{os, arch, version}` → `"CLIProxyAPI_<version>_<os>_<arch>.tar.gz"`. PURE. Lives with its only consumer (M2 download), not M1.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `Cliproxy.ensure_running` | `lua/parley/cliproxy.lua` | new | process + TCP + vault + fs |
| `Cliproxy.health_probe` | `lua/parley/cliproxy.lua` | new | `curl` subprocess |
| `Cliproxy.spawn` | `lua/parley/cliproxy.lua` | new | `vim.uv.spawn` |
| `Cliproxy.discover_binary` | `lua/parley/cliproxy.lua` | new | PATH / fs |
| `Cliproxy` commands | `lua/parley/cliproxy.lua` + `init.lua` | new | user commands |
| `cliproxyapi.pre_query` | `lua/parley/providers.lua` | modified | dispatcher seam |
| `fake_cliproxy` | `tests/fixtures/fake_cliproxy.lua` | new | process-level fake |

- **Cliproxy.ensure_running(callback, on_error)** — the heart. Reads `M.config.cliproxy` + the resolved endpoint, resolves the secret via `vault.get_secret("cliproxyapi")`, renders + writes `config.yaml` (`0600`), health-probes host:port; if healthy → `callback()`; if down → `discover_binary` → `spawn` → poll health (bounded ~5s) → `callback()`; on any failure → `on_error(msg)` so the dispatch path fails fast, never hangs.
  - **Injected into:** called from `cliproxyapi.pre_query`. The pure `render`/`encode`/`parse_endpoint` are injected here (this is the only place IO meets the pure core).
  - **Future extensions:** M2 `auto_download` slots into `discover_binary`'s fall-through.

- **Cliproxy.health_probe(host, port, secret, cb)** — `curl` GET to the cliproxy **identity route**, classifies: `healthy` (200, cliproxy-shaped) / `unauthenticated` (401 → login needed) / `foreign` (200 but not cliproxy-shaped) / `down` (connection refused). The identity route is confirmed during the M1 gating task (candidates `/v1/models`, `/health`).
  - **Injected into:** `ensure_running`, `status`.

- **Cliproxy.spawn(binary, config_path)** — `vim.uv.spawn` **detached** (`detached=true`, `uv.unref` the handle) so the daemon outlives nvim and is shared; records our PID so `stop` only kills a parley-spawned proxy.

- **Cliproxy.discover_binary()** — `cliproxy.binary_path` → (M2 managed dir) → `cli-proxy-api` on PATH. Returns path or nil.

- **Cliproxy commands** — `:ParleyProxy status|start|stop|restart|login`, registered in `init.lua` under `M.config.cmd_prefix`. `login` shells out to `cli-proxy-api login [--no-browser]`; `status` reports binary source, health/auth state, host:port, auth-dir, rendered-config path, and config-drift.

- **cliproxyapi.pre_query** — a 6-line adapter hook delegating to `require("parley.cliproxy").ensure_running`. ARCH-DRY: reuses the dispatcher's existing `pre_query` mechanism (dispatcher.lua:387) — copilot already proves the pattern. No-op (immediate callback) when `manage` is off.

- **fake_cliproxy** — a real subprocess (Lua via `nvim -l`, or a tiny TCP listener) used by integration tests. Modes: `healthy` (answers identity route 200), `foreign` (200 wrong shape), `unauth` (401), `slow` (never healthy), `crash` (exits immediately). Process-level per AGENTS.md external-service rule — function mocks would miss the reuse-vs-spawn and identity-classification bugs.

---

## Chunk 1: Pure config core

`## Chunk 1` — `lua/parley/cliproxy_config.lua` + `tests/unit/cliproxy_config_spec.lua`. No IO; tests run without mocks.

### Task 1.1: `parse_endpoint`

**Files:**
- Create: `lua/parley/cliproxy_config.lua`
- Test: `tests/unit/cliproxy_config_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 0: Register the traceability key** (so `make test-spec SPEC=…` resolves — `SPEC` is a key in `atlas/traceability.yaml`, *not* a filename; without this the runner prints "No tests mapped" and runs nothing). Add under `atlas:`:

```yaml
  providers/cliproxy-managed:
    code:
      - lua/parley/cliproxy_config.lua
      - lua/parley/cliproxy.lua
      - lua/parley/providers.lua
    tests:
      - tests/unit/cliproxy_config_spec.lua
      - tests/unit/providers_pre_query_spec.lua
      - tests/integration/cliproxy_lifecycle_spec.lua
      - tests/integration/cliproxy_dispatch_spec.lua
```

(Inner-loop alternative while iterating on one file: `make test-unit` auto-discovers every `tests/unit/*_spec.lua` and prints `PASS:`/`FAIL:` per file — grep for the new spec. `make test-spec SPEC=providers/cliproxy-managed` runs exactly this feature's mapped files.)

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/cliproxy_config_spec.lua
local cc = require("parley.cliproxy_config")

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

    it("returns nil for an unparseable endpoint", function()
        local host, port = cc.parse_endpoint("not-a-url")
        assert.is_nil(host)
        assert.is_nil(port)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: FAIL — `module 'parley.cliproxy_config' not found`.

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua/parley/cliproxy_config.lua
-- Pure config core for the managed cliproxyapi instance (issue #131).
-- No IO: every function here is deterministic and unit-tested without mocks
-- (ARCH-PURE). The IO shell lives in parley/cliproxy.lua.
local M = {}

--- Parse host:port out of a provider endpoint URL.
--- The provider endpoint is the single source of truth for host:port
--- (spec §"host:port — single source of truth").
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

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_config.lua tests/unit/cliproxy_config_spec.lua
git commit -m "#131 M1: cliproxy_config.parse_endpoint (pure host:port from endpoint)"
```

### Task 1.2: `render`

**Files:**
- Modify: `lua/parley/cliproxy_config.lua`
- Test: `tests/unit/cliproxy_config_spec.lua`

**Bind-vs-dial decision (spec §host:port M1 note):** for a *locally managed* proxy we bind to the **same host the client dials** (`127.0.0.1`) — loopback-only is the safe default (no `0.0.0.0` exposure). So `render` passes `opts.host` straight through as the proxy `host`; the test below pins that. (Revisit only if a future config dials a non-loopback host.)

- [ ] **Step 1: Write the failing test**

```lua
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
        assert.equals("number", type(cfg.port))  -- stays numeric for YAML/JSON
        assert.same({ "sk-local-123" }, cfg["api-keys"])
        assert.same({ model = "x" }, cfg["some-provider"])  -- passthrough preserved
    end)

    it("binds to the dialed host (loopback), not 0.0.0.0", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, secret = "s", config = {} })
        assert.equals("127.0.0.1", cfg.host)
    end)

    it("does not mutate the input config table", function()
        local raw = { port = 1 }
        cc.render({ host = "h", port = 8317, secret = "s", config = raw })
        assert.equals(1, raw.port)  -- original untouched
    end)

    it("reports overridden raw-config keys for the caller to warn on", function()
        local _, overrides = cc.render({
            host = "127.0.0.1", port = 8317, secret = "s",
            config = { host = "0.0.0.0", port = 9999 },
        })
        table.sort(overrides)
        assert.same({ "host", "port" }, overrides)
    end)

    it("emits an empty api-keys list when no secret is present", function()
        local cfg = cc.render({ host = "h", port = 8317, config = {} })
        assert.same({}, cfg["api-keys"])
    end)
end)
```

- [ ] **Step 2: Run** `make test-spec SPEC=providers/cliproxy-managed` → FAIL (`render` nil).

- [ ] **Step 3: Implement**

```lua
--- Merge the raw `config` passthrough with parley's wiring fields and the
--- resolved client secret. Pure — the secret is passed in already resolved;
--- this never touches the vault (ARCH-PURE). Unknown keys pass through
--- untouched (ARCH-DRY: we do not re-model cliproxy's schema).
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
        cfg["api-keys"] = { opts.secret }
    else
        cfg["api-keys"] = {}
    end
    return cfg, overrides
end
```

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `#131 M1: cliproxy_config.render (merge wiring + secret, passthrough)`

### Task 1.3: `encode` (JSON-as-YAML)

**Files:** Modify `lua/parley/cliproxy_config.lua`; Test same spec.

- [ ] **Step 1: Failing test**

```lua
describe("encode", function()
    it("emits JSON that round-trips and keeps api-keys a list", function()
        local cfg = cc.render({ host = "127.0.0.1", port = 8317, secret = "s", config = {} })
        local str = cc.encode(cfg)
        local back = vim.json.decode(str)
        assert.equals(8317, back.port)
        assert.same({ "s" }, back["api-keys"])  -- list, not object
    end)
end)
```

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**

```lua
--- Emit the config as a string cliproxy's --config can read. JSON is valid
--- YAML 1.2, so we emit JSON and skip a YAML emitter (spec §Emission; this is
--- the M1 gating bet, validated against a real cli-proxy-api in Task 2.0).
---@param config_table table
---@return string
function M.encode(config_table)
    return vim.json.encode(config_table)
end
```

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `#131 M1: cliproxy_config.encode (JSON-as-YAML)`

> **Chunk 1 review:** dispatch plan/code review of `cliproxy_config.lua` + spec before Chunk 2 (per AGENTS.md the milestone review runs at `sdlc milestone-close`; this is an optional mid-chunk sanity check).

---

## Chunk 2: IO lifecycle shell + process-level fake

`## Chunk 2` — `lua/parley/cliproxy.lua`, `tests/fixtures/fake_cliproxy.lua`, `tests/integration/cliproxy_lifecycle_spec.lua`.

### Task 2.0: Gating task — prove JSON-as-YAML boots a real proxy (GO/NO-GO)

**Manual, before writing lifecycle code. Spec §Emission makes this a hard gate.**

- [ ] **Step 1:** Install a real binary locally (`brew install cliproxyapi` or download a pinned release tarball for this machine). Record the version + identity route in `## Log`.
- [ ] **Step 2:** In a scratch nvim, build a minimal config via `cliproxy_config.render` + `encode`, write it to a temp `.yaml`, and run `cli-proxy-api --config <tmp>`.
- [ ] **Step 3:** Confirm it boots and answers an HTTP probe. **Decide the identity route** (`/health` vs `/v1/models`) and record it. Also confirm `auth-dir` `~` handling: the cliproxy docs say `auth-dir` "supports `~` for home directory", so `render` writes it **literally** (no `vim.fn.expand`) — verify the booted proxy resolves `~` itself; record the result.
- [ ] **GO:** proceed. **NO-GO** (parser rejects JSON): add a nested+list YAML emitter as Task 1.4 (its own sub-task — *not* a flat emitter; spec says flat is non-viable), then continue. Log the decision either way.

### Task 2.1: `discover_binary`

**Files:** Create `lua/parley/cliproxy.lua`; Test `tests/integration/cliproxy_lifecycle_spec.lua` (integration: touches fs/PATH).

- [ ] **Step 1: Failing test** — given an explicit `binary_path` that exists, returns it; given a bogus path + nothing on PATH, returns nil. (Use a temp file as a fake binary; set `M.config.cliproxy.binary_path`.)
- [ ] **Step 2: Run** `make test-spec SPEC=providers/cliproxy-managed` → FAIL.
- [ ] **Step 3: Implement** `discover_binary()`: check `cfg.binary_path` (fs exists + executable), else `vim.fn.exepath("cli-proxy-api")`, else nil. (M2 inserts the managed dir between the two.)
- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `#131 M1: cliproxy.discover_binary`

### Task 2.2: `health_probe` + identity classification

**Files:** Modify `lua/parley/cliproxy.lua`; new `tests/fixtures/fake_cliproxy.lua`; Test the lifecycle spec.

- [ ] **Step 1: Build the fake** — `tests/fixtures/fake_cliproxy.lua`: a `vim.uv` TCP server (run via `nvim -l`) that, by a `--mode` arg, answers the identity route with 200-cliproxy-shape / 200-foreign / 401 / never / exits immediately. It binds the port from `--port` and the identity route decided in Task 2.0.
- [ ] **Step 2: Failing test** — start `fake_cliproxy --mode healthy --port <p>`; assert `health_probe` classifies `healthy`. Repeat for `foreign`→`foreign`, `unauth`→`unauthenticated`, nothing-listening→`down`.
- [ ] **Step 3: Run** → FAIL.
- [ ] **Step 4: Implement** `health_probe(host, port, secret, cb)`: `curl -s -o - -w "%{http_code}"` (or `vim.uv`) GET to the identity route with the bearer; classify by status + body shape. Async, calls `cb(state)`.
- [ ] **Step 5: Run** → PASS. **Commit** `#131 M1: cliproxy.health_probe + fake_cliproxy (identity classification)`

### Task 2.3: `spawn` (detached) + PID tracking

- [ ] **Step 1: Failing test** — spawn `fake_cliproxy --mode healthy`; assert the process starts, a PID is recorded, and a subsequent `health_probe` goes `healthy`. Assert the recorded PID is parley-owned (so `stop` is scoped).
- [ ] **Step 2–4:** Implement `spawn(binary, config_path)` via `vim.uv.spawn` with `detached=true`, `uv.unref(handle)`, capture `pid` into module state. Return the handle/pid.
- [ ] **Step 5: Commit** `#131 M1: cliproxy.spawn (detached, PID-tracked)`

### Task 2.4: `ensure_running` — reuse / spawn / failure modes

This wires the pure core to IO. Cover **every** spec failure mode.

- [ ] **Step 1: Failing tests** (one `it` each):
  - reuse-if-healthy: a `healthy` fake already listening → `ensure_running` calls `callback`, **does not** spawn (assert PID unchanged / no new process).
  - cold start: nothing listening + a `healthy`-mode fake as the discovered binary → spawns, polls healthy, calls `callback`.
  - foreign port: a `foreign` fake listening → `on_error` with "non-cliproxy process", no spawn.
  - never-healthy: discovered binary is the `slow` fake → bounded ~5s wait → `on_error("timed out")`, dispatch not blocked past the bound.
  - spawn-fail: discovered binary is the `crash` fake → `on_error("exited")`.
  - unauthenticated: a `unauth` fake → `on_error` mentioning `:ParleyProxy login` (login not done).
- [ ] **Step 2: Run** → FAIL.
Also implement `M.is_managed()` → `M.config.cliproxy and M.config.cliproxy.manage == true` (the gate the `pre_query` seam in Task 3.1 calls). Add a one-line test.

- [ ] **Step 3: Implement** `ensure_running(callback, on_error)`:
  1. read `M.config.cliproxy`; if `manage` is not true → `callback()` immediately (no-op path).
  2. `host, port = cliproxy_config.parse_endpoint(D.providers.cliproxyapi.endpoint)`.
  3. `secret = vault.get_secret("cliproxyapi")`.
  4. `cfg, overrides = cliproxy_config.render{...}`; if `#overrides>0` log a warning naming them; write `encode(cfg)` to `stdpath('data')/parley/cliproxy/config.yaml` at `0600`.
  5. `health_probe` → `healthy`: `callback()`. `foreign`: `on_error`. `unauthenticated`: `on_error` (login). `down`: `discover_binary` (nil → `on_error` naming `brew install`/`auto_download`) → `spawn` → poll `health_probe` every ~250ms up to ~5s → healthy `callback()` / else `on_error("timed out")`. Crash mid-poll → `on_error("exited")`.
- [ ] **Step 4: Run** → all PASS.
- [ ] **Step 5: Commit** `#131 M1: cliproxy.ensure_running (reuse/spawn + all failure modes)`

### Task 2.5: commands — `status|start|stop|restart|login`

- [ ] **Step 1: Failing tests** — `status()` returns a table with binary source, health/auth state, host:port, auth-dir, config path, and a `config_drift` bool (rendered ≠ running). `stop()` only kills a parley-spawned PID (a reused/foreign daemon is left alone). `restart()` = stop-if-ours + ensure. `login()` builds the `cli-proxy-api login` argv.
- [ ] **Step 2–4:** Implement. Keep each a thin wrapper; `status` composes `discover_binary` + `health_probe` + a config-drift check (compare on-disk rendered file to a fresh `render`).
- [ ] **Step 5: Commit** `#131 M1: cliproxy commands (status/start/stop/restart/login)`

> **Chunk 2 review:** the process-level fake + `ensure_running` failure-mode matrix is the riskiest surface — sanity-review before wiring.

---

## Chunk 3: Dispatcher wiring + commands registration + activation

`## Chunk 3` — `lua/parley/providers.lua`, `lua/parley/init.lua`, `tests/unit/providers_pre_query_spec.lua`, `tests/integration/cliproxy_dispatch_spec.lua`.

### Task 3.1: `cliproxyapi.pre_query` adapter hook (the DRY seam)

**Files:** Modify `lua/parley/providers.lua` (cliproxyapi adapter, ~line 993); Test `tests/unit/providers_pre_query_spec.lua`.

- [ ] **Step 1: Failing test** — `cliproxyapi.pre_query` exists; with `manage=false` it calls its callback synchronously (no-op); with `manage=true` it delegates to an injected `ensure_running` (inject a stub via the module to avoid real IO).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**

```lua
-- providers.lua, cliproxyapi adapter:
cliproxyapi.pre_query = function(callback)
    local ok, cliproxy = pcall(require, "parley.cliproxy")
    if not ok or not cliproxy.is_managed() then
        return callback()  -- no-op: bring-your-own / not opted in
    end
    cliproxy.ensure_running(callback, function(msg)
        require("parley.logger").error("cliproxy: " .. msg)
        -- do NOT call callback → the query is aborted, surfaced via logger;
        -- the chat does not hang (dispatcher returns).
    end)
end
```

ARCH-DRY: reuses the dispatcher's existing `pre_query` path (dispatcher.lua:387) exactly as copilot does — no new provider branch in the dispatcher.

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `#131 M1: cliproxyapi.pre_query delegates to ensure_running`

### Task 3.2: register `:ParleyProxy` command

**Files:** Modify `lua/parley/init.lua` (near the command/hook registration, ~line 591).

- [ ] **Step 1: Failing test** (integration) — after `setup{ cliproxy = { manage = true, ... } }`, `vim.fn.exists(":ParleyProxy") == 2`; `:ParleyProxy status` runs without error and reports state.
- [ ] **Step 2–4:** Register `M.config.cmd_prefix .. "Proxy"` → dispatch on the subcommand arg to `cliproxy.status/start/stop/restart/login`. Provide completion for the subcommands.
- [ ] **Step 5: Commit** `#131 M1: :ParleyProxy command`

### Task 3.3: end-to-end dispatch integration (the Done-when proof)

**Files:** Test `tests/integration/cliproxy_dispatch_spec.lua`.

- [ ] **Step 1: Failing test** — configure a cliproxy agent whose endpoint points at a free port; no proxy running; the discovered "binary" is `fake_cliproxy --mode healthy`. Drive a dispatch (or call `D.query` for the cliproxy provider) and assert: config.yaml was rendered (with the secret in `api-keys`, `0600`), the fake was spawned, became healthy, and the query proceeded. Then a second dispatch **reuses** (no second spawn). Then `:ParleyProxy stop`; the next dispatch **re-spawns** (auto-revive — spec §"stop is transient").
- [ ] **Step 2: Run** → FAIL. **Step 3:** fix wiring until green. **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `#131 M1: e2e dispatch integration (render→spawn→reuse→revive)`

### Task 3.4: docs + README + atlas

- [ ] Add a `cliproxy = { manage = true, ... }` example to `README.md` (provider section ~line 141) and the config docstring in `lua/parley/config.lua`. State the one manual step (`:ParleyProxy login`) and that it's opt-in/off-by-default.
- [ ] Add `atlas/providers/cliproxy-managed.md` (the lifecycle + config-render flow) and link it from `atlas/index.md` (AGENTS.md §8).
- [ ] **Commit** `#131 M1: docs + atlas for managed cliproxy`

### Task 3.5: close M1

- [ ] `make test` green (unit + integration) on macOS; run the same on a Linux box/CI (spec platform scope).
- [ ] `sdlc milestone-close --issue 131 --milestone M1 ...` (boundary review auto-dispatches; fix Critical/Important before crossing). Tick the M1 row.

---

## Chunk 4 (M2, deferred): `auto_download`

`## Chunk 4` — implement only after M1 ships. Outline:

- **Task 4.1** `cliproxy_config.asset_name` (pure) + `platform()` detection (`vim.uv.os_uname` → `{os, arch}`), unit-tested (map every `darwin/linux/freebsd/windows × aarch64/amd64`).
- **Task 4.2** `download(version)` — fetch the pinned tarball + `checksums.txt` via `curl`, verify the sha256, extract into `stdpath('data')/parley/cliproxy/bin/`. Pinned version constant in the module (not "latest").
- **Task 4.3** insert the managed dir into `discover_binary`'s fall-through; add `:ParleyProxy update`.
- **Task 4.4** integration test with a local file:// or fixture tarball + a deliberately-wrong checksum (must refuse).
- **Task 4.5** `sdlc milestone-close --milestone M2`.

---

## Testing summary

- **Pure** (`cliproxy_config`): `tests/unit/cliproxy_config_spec.lua`, no mocks (ARCH-PURE boundary visible from outside).
- **IO** (`cliproxy`): `tests/integration/cliproxy_lifecycle_spec.lua` + `tests/fixtures/fake_cliproxy.lua` — a real subprocess speaking the identity route, exercising reuse/spawn/foreign/timeout/crash/unauth. No function-call mocks for the proxy.
- **Wiring**: `tests/unit/providers_pre_query_spec.lua` (no-op vs delegate) + `tests/integration/cliproxy_dispatch_spec.lua` (the Done-when e2e).
- Run: `make test-unit`, `make test-spec SPEC=<key>`, `make test` (full).
