# Isolated Starter Configuration Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3; use superpowers-executing-plans for integration work and bounded subagents where context is independently capturable. Steps use checkboxes.

**Goal:** A new user opens an isolated, readable chat profile and can connect a provider without editing configuration or typing API keys.

**Architecture:** A single editable starter entry delegates profile paths and first-use UI to versioned runtime modules. Existing Parley APIs own chats, login, images and model selection. One narrow product option keeps live-model selection/restoration consistent with the starter's tool policy.

**Tech Stack:** Lua, Neovim, lazy.nvim v11.17.5, Moonfly, Plenary/Telescope; existing process and provider fixtures.

**State:** Design prepared for operator approval; no implementation yet.

## Scope and decisions

Use `packaging/starter-config/` as a standalone configuration. Require
`NVIM_APPNAME=parley` before loading plugins or writing profile state. Use standard
XDG config/data/state/cache roots; derive every writable path from `stdpath`.
An existing nvim profile is never sourced or merged. Derive selected editor
settings from the operator configuration; do not import its Lua modules.

Retain Moonfly, wrapped prose, linebreak/breakindent, a quoted showbreak marker,
true colors, system clipboard and Space leader. Normal-mode j/k and arrows move
by display line; numbered motions retain ordinary Neovim behavior. Keep attachment
alt labels readable after Parley attaches its chat buffer. No extra Markdown
renderer, development plugin distribution, repo hooks or automatic file writer.

The alternative of copying the complete personal config imports unrelated paths
and plugins; a full editor distribution adds another settings/upgrade layer.
The small profile is the recommended boundary (ARCH-PURPOSE).

Set explicit profile chat/export/state/log/auth paths and empty supplementary
roots. Disable inherited non-proxy providers individually, replace API-key sources,
disable the inherited ToolOpus* agent, and supply a learner agent with no local
model tools. Preserve direct clipboard image attachment and deletion confirmation.
Turn server-side web search off initially; the existing toggle remains available.
Use a compact explicit keymap set with product defaults disabled.

Preserve managed CLIProxyAPI first-use download and updates. Use loopback port
8318, distinct from the product default, and a separate profile-owned client key;
a listener collision or mismatched key is an error, never grounds to reap a peer.
OAuth credentials live inside the profile data root. Existing managed version
selection/download behavior remains unchanged.

First empty launch creates one timestamped welcome chat via `new_chat`, with
short hints for respond, image paste, outline, login/model selection and quit.
Later empty launches reopen that welcome chat while it exists; explicit file
arguments open those files without an unsolicited chat. The hint is local UI
content, not an automatically submitted model question. `ParleyConnect` selects
Claude/Codex/Gemini login, calls `ensure_running`, then the existing Proxy login
command; this handles a missing binary before login. The native model picker
chooses from the account's live catalog; no claim that an account has a fixed model.

The starter uses a released Parley plugin (`version='*'`, never a dev path), plus
pinned dependency revisions. #247 may supply an installed release directory via
`PARLEY_RUNTIME`, so its formula and running plugin use the same release. Pin
lazy.nvim to v11.17.5 and verify the dependency commits used by the artifact.
Do not use the old v2.1.0 tag for acceptance: it predates this packaging surface.
Publish a reviewed #246 release before the final remote-bootstrap acceptance;
release failure or acceptance failure prevents declaring this issue shipped.

## Core concepts

| Name | Lives in | Kind | Status |
|---|---|---|---|
| Starter dependency pins and plugin specification | `packaging/starter-config/init.lua` | PURE | new |
| `options` — profile-derived Parley settings | `lua/parley/starter_config.lua` | PURE | new |
| `build_agent` — explicit live-agent tool policy | `lua/parley/cliproxy_catalog.lua` | PURE | modified |
| `live_agent_options` — shared picker/restoration policy projection | `lua/parley/init.lua` | PURE | new |

| Name | Lives in | Kind | Status | Wraps |
|---|---|---|---|---|
| Bootstrap entry | `packaging/starter-config/init.lua` | INTEGRATION | new | app-name check, bounded git bootstrap, lazy setup |
| `client_key` | `lua/parley/starter_profile.lua` | INTEGRATION | new | exclusive 0600 creation and bounded validated read |
| `start`, `connect` | `lua/parley/starter.lua` | INTEGRATION | new | editor startup, welcome chat, existing managed login |
| Picker and persisted live-agent restoration | `lua/parley/init.lua`, `lua/parley/config.lua` | INTEGRATION | modified | shared configured tools policy |
| Starter artifact scanner and bootstrap harness | `tests/packaging/`, `tests/integration/starter_config_spec.lua` | INTEGRATION | new | temporary profiles and real local git repositories |

The profile key is separate from the proxy management credential. Read exactly a
bounded validated hex token; malformed/truncated state fails with a path-only
repair message. Create directories privately and the key with exclusive creation;
a concurrent creator reads the winner, never overwrites it (ARCH-SECURE/ORDER).
Bootstrap clones into temporary profile-local staging, validates success and
publishes atomically; an interrupted clone cannot masquerade as installed Lazy.

Existing behavior evidence: provider inheritance lives in `dispatcher.lua:39–53`;
API-key replacement and named-agent merging in `init.lua:585–644`;
`cliproxy_catalog.lua:220–238` hardcodes live-agent `@all`, with selection and
restoration callers in `init.lua:4915` and `init.lua:1523`.
`cliproxy.ensure_running` at `cliproxy.lua:749` already downloads on first use;
`init.lua:478`'s raw login path requires a binary first. Reuse these owners.

## Chunk 1: One starter profile and its required policy seam

- [ ] Add optional live-model tools policy, preserving current behavior when absent; thread it through both selection and restart restoration.
- [ ] Implement pure starter configuration/spec data, bounded bootstrap and profile key lifecycle; add the welcome/connect UI using existing chat/login APIs.
- [ ] Add hermetic startup, artifact scanning and policy integration checks to `make test`; map all new exports and specs in atlas/traceability.
- [ ] Add the concise standalone install/login guide to README and `packaging/starter-config/README.md`; update the packaging project.
- [ ] Run full verification and SDLC close review, publish the reviewed release, run remote-bootstrap acceptance, then merge and archive #246. Re-close if live acceptance requires code changes.

## Function test strategies

| Function/surface | Adversarial class → mechanical guard |
|---|---|
| `options` and plugin specification | Hostile inherited defaults and mixed profile roots → pure decision assertions plus effective setup inspection forbid personal/provider/tool leakage. |
| `build_agent`, `live_agent_options` | Explicit empty policy versus omitted policy across selection/restart → shared builder assertions and persisted-state integration enforce identical tools. |
| `client_key` | Concurrent creators, truncation and restrictive permissions → real temporary filesystem/process tests assert one winner, bounded reads and no overwrite. |
| Bootstrap entry | Failed/interrupted git and preexisting partial state → real local git fixtures exercise staging/retry; stateful git fixture records attempts and completion; live GitHub bootstrap checks conformance. |
| `start` | Repeated startup, missing welcome record and explicit file args → independent headless processes assert durable chat identity and preserved requested buffers. |
| `connect` | Absent binary, download failure and logged-out service → existing release/proxy fakes exercise ensure-running→login ordering and visible failure. |
| Artifact scanner | Personal path/identity markers planted in generated config → negative fixture mutation must fail; runtime profile containment complements the text scan. |

Verification: focused specs through the existing hermetic runner, `make test`,
`git diff --check`, and a fresh HOME/XDG remote-bootstrap run with a decoy nvim
profile hashed before/after. Inspect a real chat's attachment display and effective
provider/agent settings. No production credentials are needed for #246's startup
and login-prompt tests; authenticated chat acceptance belongs to #247.

## Operating envelope and lifecycle

One startup bootstrap at a time per profile. Bound git operations to 120 seconds
and overall first installation to 5 minutes; failures show an actionable retry
message and do not enter a success state. Subsequent launch uses installed pins;
no update polling on every launch. One welcome chat per profile, no background
LLM call. Ordinary user chats remain user-owned files (ARCH-CONSTRAINTS).

Bootstrap staging is cleaned on failure or the next guarded bootstrap. Lazy
checkouts/lockfile, client key, welcome record, proxy credentials, logs and caches
remain only under the four profile roots; documented profile removal owns their
end. Use existing log/cache bounds; add no per-launch append-only ledger.
The existing managed proxy is explicitly stopped for uninstall; no automatic
peer reaping or new proxy watcher (ARCH-FUNERAL).

## Revisions

### 2026-09-13 — independent packaging profile

Operator requested #246 then #247 after #245 shipped. Replace broad #209/#211
blocking dependencies with the shipped dependency foundation. Starter-local
overrides plus the narrow live-agent policy seam satisfy this issue; the broader
product-default and consent audits remain separate. Exact plan approval is pending.

Sources: [Lazy installation](https://lazy.folke.io/installation),
[Lazy configuration](https://lazy.folke.io/configuration),
[Lazy v11.17.5](https://github.com/folke/lazy.nvim/releases/tag/v11.17.5).

### 2026-09-13 — atomic configuration upgrade boundary

Keep the editable starter as one `init.lua`; runtime helper modules ship with the
plugin release instead of being copied into user configuration. This lets #247
publish a complete initial config atomically and maintain one bounded `init.lua.new`
candidate, avoiding partial multi-file config upgrades. Product helpers are
loaded only by the starter and preserve ordinary plugin setup behavior.

### 2026-09-13T14:46:00-07:00 — plan review accepted

Fresh-context review approved after dependency and live-authentication corrections.
Operator implementation approval remains pending.
