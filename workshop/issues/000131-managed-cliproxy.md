---
id: 000131
status: open
deps: []
github_issue:
created: 2026-06-12
updated: 2026-06-12
estimate_hours:
---

# Manage cliproxyapi lifecycle + config

## Problem

Parley talks to `cliproxyapi` as a normal provider (`lua/parley/config.lua` →
`http://127.0.0.1:8317/v1/chat/completions`, dual OpenAI/Anthropic adapter in
`providers.lua`), but assumes the proxy is **already running and configured
out-of-band**. Today that means: `brew install`, `brew services start`, and
hand-editing config under `/opt/homebrew` — a path that can't live in the user's
version-controlled dotfiles (yadm). Setup friction + non-committable config +
manual lifecycle. Parley owns the client cleanly and owns *nothing* of the
proxy's binary / config / lifecycle. This issue closes that gap.

## Spec

Make parley able to **manage a cliproxyapi instance** — opt-in, off by default,
distributable to parley's general users (not just one machine).

### Decisions (brainstorm 2026-06-12)
- **Audience:** parley's general users → portable, no brew/Go assumption, no
  personal paths in core logic, **opt-in / off by default**.
- **Ownership:** orchestrator spine (config + lifecycle, bring-your-own-binary)
  as the M1 default; `auto_download` (parley fetches the binary) deferred to M2.
- **Config source of truth:** rendered from Lua `setup{}` — the generated
  `config.yaml` is a *derived, gitignored artifact*, so nothing hand-maintained
  ever lives in `/opt/homebrew` again. The committed Lua **is** the config.
- **Platforms:** macOS + Linux tested in v1; Windows written portably,
  best-effort, not gated on.

### Verified cliproxyapi facts (research 2026-06-12)
- `--config /path/to/config.yaml` flag → we can point it anywhere.
- Config holds `host`/`port` (default `8317`), `api-keys` (client tokens), and
  an `auth-dir` pointer (default `~/.cli-proxy-api`).
- **Clean secret split already exists:** static config in `config.yaml`
  (committable); OAuth subscription tokens are JSON files in `auth-dir`, written
  by `cli-proxy-api login`. Secrets never need to touch config or git.
- Prebuilt release tarballs for every platform:
  `CLIProxyAPI_<ver>_{darwin,linux,freebsd,windows}_{aarch64,amd64}.tar.gz` +
  `checksums.txt`. **Source builds are unnecessary** (kills brainstorm idea #1).
- `login` is interactive OAuth (`--no-browser` prints the URL) — the one
  unavoidable per-machine manual step.

### Activation & config model
Activated only when `setup{}` contains a `cliproxy = { manage = true, ... }`
block. Shape:
```lua
cliproxy = {
  manage = true,
  auth_dir = "~/.cli-proxy-api",  -- machine-local OAuth token dir
  binary_path = nil,              -- optional explicit path (else PATH lookup)
  config = { ... },               -- raw passthrough of cliproxy's own schema (ARCH-DRY: don't re-model it)
}
```
Parley merges its wiring fields **over** the raw `config` table, then writes the
result to a derived path *outside the user's dotfiles repo*
(`stdpath('data')/parley/cliproxy/config.yaml`, perms `0600`) on each
ensure-start, and spawns `cli-proxy-api --config <that path>`.

### host:port — single source of truth (resolves the double-source risk)
The existing `providers.cliproxyapi.endpoint` (`config.lua`,
`http://127.0.0.1:8317/v1/chat/completions`) already says *where the client
dials*. That endpoint is **the** source of truth: parley **parses host:port out
of the provider endpoint** and renders those into the proxy config's `host`/
`port` (and uses them for the health probe). There is deliberately **no
`cliproxy.port` field** — a second port knob is exactly the drift the reviewer
flagged. If the raw `config` passthrough also sets `host`/`port`, the
endpoint-derived values win and parley logs a warning naming both. Net: change
the port in one place (the provider endpoint) and client + proxy stay aligned.
*M1 note:* decide bind-vs-dial host explicitly — the client dials `127.0.0.1`
but the proxy may need `host: localhost`/`0.0.0.0` to bind; don't render the dial
host blindly as the bind host.

**Emission:** JSON is valid YAML 1.2 and parley already has `vim.json.encode`,
so it writes JSON-as-`.yaml` and needs no YAML emitter. **This bet is an early
gating task in M1** (write a render, feed it to a real `cli-proxy-api --config`,
confirm it boots) — go/no-go *before* the lifecycle work, so a failure can't
silently balloon M1. If it fails, the fallback emitter must handle **nested maps
+ lists** (the config has an `api-keys` list and nested sections) — a flat
emitter is not a viable fallback; budget it as its own M1 sub-task if triggered.

### Secret & auth-dir wiring (must NOT leak)
- **Client token:** the `cliproxyapi` secret can be a plaintext string, an env
  var, **or a command table** (`{ "cat", "/path" }`, keychain lookup, …) per
  `config.lua`. Parley resolves it through the **existing vault**
  (`vault.get_secret`, already populated at setup — ARCH-DRY, don't re-read
  `api_keys`) and injects the *resolved* value into the rendered config's
  `api-keys` list — single source; proxy and client can't drift.
- **Plaintext-on-disk, acknowledged:** the rendered `config.yaml` therefore
  contains the resolved client token in cleartext under `stdpath('data')`. That
  is why the file is written `0600`. This is a real (small) exposure the spec
  owns explicitly rather than hides. The *committed Lua* still holds zero
  secrets — the on-disk artifact is machine-local and unversioned.
- **OAuth tokens:** stay in `auth_dir` (machine-local JSON), never rendered into
  config, never committed.

### Binary discovery (M1, bring-your-own)
Order: `cliproxy.binary_path` → managed download dir (M2) → `cli-proxy-api` on
PATH. None found → actionable error naming `brew install …` / `auto_download`.

### Lifecycle
- **Lazy:** ensure-running fires on first dispatch to a cliproxy-provider agent,
  never on nvim launch.
- **Reuse-if-healthy:** probe the endpoint's host:port first; spawn only if
  nothing healthy answers (cooperative with an existing brew service / other
  nvim).
- **Detached & shared:** spawned via `vim.uv` detached so it outlives nvim and
  is shared across instances. Never auto-killed; stopped only explicitly.

### Health probe & failure modes (the dispatch path must never hang)
The probe must **identify cliproxy specifically**, not just accept any TCP
listener — hit a cliproxy-distinguishing HTTP route (e.g. its models endpoint),
so a foreign server squatting the port isn't mistaken for ours.
- **Spawn fails** (missing/!exec/wrong-arch binary, immediate exit): surface a
  clear error on the dispatch path and **fail the request** — never hang the
  chat — pointing at `:ParleyProxy status`.
- **Foreign process on the port:** probe fails the cliproxy-identity check →
  error "port N held by a non-cliproxy process" (don't spawn a doomed second
  instance, don't silently dial the stranger).
- **Spawned but never healthy:** bounded wait (~5s, a few retries); on timeout,
  abort with an error and leave the (logged) process for `:ParleyProxy status`
  to report — the dispatch does not block indefinitely.
- **Healthy but unauthenticated (login not done → 401 storm):** this is the
  *most likely* first-run state. Lifecycle is parley's job; OAuth is the manual
  step. `status` reports **auth state** (probe returns 401 / `auth_dir` empty),
  and the not-yet-logged-in error tells the user to run `:ParleyProxy login`.

### Module boundary (ARCH-PURE)
Two units, tested independently:
- `cliproxy_config.lua` — **pure**: merge raw `config` with wiring fields, parse
  host:port from the endpoint, inject the resolved secret, emit JSON-as-YAML,
  map platform→asset name (M2). No IO. Colocated unit tests.
- `cliproxy.lua` — **IO**: binary discovery, `vim.uv` spawn, health probe,
  reuse logic, the `:ParleyProxy` commands. Tested against a process-level fake
  proxy binary. Resolves the secret via the existing vault; writes the file.

### Commands
`:ParleyProxy status | start | stop | restart | login`. `login` wraps
`cli-proxy-api login [--no-browser]`. `status` reports binary source,
running/healthy, **auth state**, host:port, auth-dir, rendered-config path, and
flags **"running config differs from rendered"** so the user knows a `restart`
is needed after a Lua change. `stop`/`restart` are **best-effort by port/PID**;
since the daemon is shared, other nvim instances simply re-spawn lazily on their
next request. *M1 note:* `stop` should only stop a daemon **parley spawned**
(track our PID); a reused/foreign daemon (brew service) is left alone.

### M2 — auto_download (deferred)
`auto_download = true` → fetch the **pinned** (not "latest") release tarball for
detected os/arch, verify against `checksums.txt`, extract into the managed dir.
Adds `:ParleyProxy update`; binary-discovery falls through to the managed dir.

### Explicitly OUT (YAGNI)
Management-center/GUI integration; multi-proxy orchestration; auto-restart on
config change (Lua change needs explicit `:ParleyProxy restart`); managing the
OAuth flow beyond shelling out to `login`.

## Done when

Parley-verifiable (no manual login needed):
- `cliproxy = { manage = true, ... }` is opt-in; absent → zero behavior change,
  no spawn on nvim launch.
- A cliproxy-provider chat with no proxy running lazily renders config from Lua,
  starts the binary, the proxy becomes healthy, and the request reaches it.
- A healthy proxy already on the port (e.g. brew service) is reused, not
  re-spawned; a foreign process on the port produces the identity-check error,
  not a silent mis-dial.
- Spawn failure / never-healthy each surface an error on the dispatch path
  within the bounded timeout — the chat never hangs.
- Rendered `config.yaml` carries the *resolved* `cliproxyapi` secret in
  `api-keys` at perms `0600`; no secret appears in any committed file; the port
  in the rendered config matches the provider endpoint.
- `:ParleyProxy status` reports binary source, healthy/auth state, host:port,
  and config-drift accurately.

Requires manual one-time login (documented as such):
- Post-`:ParleyProxy login`, a real cliproxy-provider completion returns
  end-to-end.

Platform:
- The above pass on macOS + Linux.

## Plan

- [ ] M1 — orchestrator spine (macOS + Linux). Gating task FIRST: prove
      JSON-as-YAML boots a real `cli-proxy-api --config` (go/no-go before the
      rest). Then: pure `cliproxy_config.lua` (merge, parse host:port from
      endpoint, vault-resolved secret injection, JSON-as-YAML emit) +
      colocated unit tests; IO `cliproxy.lua` (binary discovery, `vim.uv`
      detached spawn, cliproxy-identifying health probe with bounded timeout,
      reuse-if-healthy, `:ParleyProxy status|start|stop|restart|login`) tested
      against a process-level fake proxy binary (per AGENTS.md external-service
      rule). Failure modes (spawn-fail, foreign-port, never-healthy, 401/auth)
      each covered.
- [ ] M2 — `auto_download`: platform→asset-name mapping (pure, with its
      consumer here — not M1), pinned cross-platform release fetch + checksum
      verify + extract; `:ParleyProxy update`; discovery falls through to managed
      dir.

## Log

### 2026-06-12
- Brainstormed via superpowers-brainstorming. Converged design captured in
  `## Spec`. Five decisions logged inline (audience, ownership, config source,
  auto_download deferral, platform scope). cliproxyapi CLI/release facts
  verified against help.router-for.me + GitHub releases API (latest v7.1.68).
- Idea "build cliproxyapi from source" rejected: prebuilt tarballs exist for all
  platforms; source build would force a Go toolchain on every machine for no
  gain.
- Fresh-eyes spec review (subagent) found 2 blockers + arch gap; spec revised:
  (1) **host:port single source of truth** — dropped `cliproxy.port`, parse it
  from the provider endpoint (kills the double-source drift). (2) **secret
  resolution** — resolve via existing vault (handles command-table/env forms),
  acknowledge plaintext-on-disk at `0600`. (3) **lifecycle failure modes** —
  added health-identity probe, spawn-fail / foreign-port / never-healthy bounded
  timeout / 401-auth handling; dispatch never hangs. (4) **module boundary** —
  pure `cliproxy_config.lua` vs IO `cliproxy.lua`. (5) JSON-as-YAML made an early
  M1 go/no-go gating task; platform→asset mapping moved to M2 (its consumer);
  Done-when split into parley-verifiable vs post-login.
