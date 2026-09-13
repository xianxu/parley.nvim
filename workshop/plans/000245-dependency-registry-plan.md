# Dependency Registry Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy); use superpowers-subagent-driven-development for bounded independent tasks or superpowers-executing-plans for warm-context work. Steps use checkboxes.

**Goal:** Explain missing dependencies and their installation from one registry, without installing packages or probing services during health checks.

**Architecture:** Pure dependency data and advice feed existing recipes and a thin read-only health section. CLIProxyAPI retains its existing discovery precedence and installation machinery. #213 retains credentials, provider validation, vocabulary diagnostics and Copilot removal.

**Tech Stack:** Lua, Neovim health API, Plenary/Busted; existing clipboard/shrink and release fixtures.

**State:** Reviewed proposal awaiting approval; no implementation or estimate yet.

## Scope and approval

Recommended: land this dependency section independently, then let #213 reuse it.
Waiting for #213 couples packaging to unrelated release work; copying discovery
into health would create competing precedence rules. Neither is needed.

One decision remains: #245 requires every macOS advisory package in the formula,
while #247 says ImageMagick only if needed beyond sips. Recommend registry data
`formula_default = true` for ripgrep only; ImageMagick, ffmpeg, vips and pandoc
stay optional advice, since sips already supplies the default shrink path.
Neovim is the formula's host runtime, outside external-tool registry parity.
Alternative: retain literal all-advisory parity and install all those packages.
**Approve the optional-backend recommendation or choose the all-advisory policy
before code.** Formula generation and parity tests land with #247, not this issue.

## Core concepts

| Name | Lives in | Status |
|---|---|---|
| Dependency entry | `lua/parley/deps.lua` | new |
| Host-specific advice and package projection | `lua/parley/deps.lua` | new |
| Recipe advice reference | `lua/parley/clipboard_image.lua`, `lua/parley/image_shrink.lua` | modified |

Entries are pure data: stable id, executable alternatives, tier, applicable hosts,
feature, package names per supported manager, managed guidance and proposed formula
selection. One entry owns ImageMagick's `magick`/`convert` alternatives; recipe
order still belongs to its feature. Each recipe references one dependency id.
`deps.advice(id, host)` and `deps.packages(host, selection)` are deterministic;
packages deduplicate aliases. Registry functions never require vim or other modules.
Future tools add rows, not health branches (ARCH-DRY, ARCH-PURE).

Initial entries: cliproxyapi; osascript; sips; ripgrep; ImageMagick; ffmpeg;
libvips (`vipsthumbnail`); wl-clipboard (`wl-paste`); xclip; pandoc; curl.
Curl keeps the existing required health check's severity; no duplicate curl row.
Pandoc is included because exporter already prints package-manager advice.
Other optional tools and managed-install prerequisites remain #213's audit.
Darwin system tools get platform guidance. Linux apt advice is selected only for
an apt host; unsupported OS/package-manager combinations report unavailability
of tested advice, never invent an apt command. Verify package names during implementation.

| Name | Lives in | Status | Wraps |
|---|---|---|---|
| Dependency observation | `lua/parley/deps_probe.lua` | new | executable/platform and managed-record reads |
| Dependency health section | `lua/parley/health.lua` | modified | vim.health reporting |
| Managed binary paths | `lua/parley/cliproxy.lua` | modified | existing local binary/version record |
| Clipboard missing notice | `lua/parley/paste_image.lua` | modified | existing notification callback |
| Export installation advice | `lua/parley/exporter.lua` | modified | existing missing-pandoc error |

`deps_probe.host()` reads uname and package-manager executability only;
`deps_probe.observe(entry, host)` returns applicability, presence, source and
recorded version. Health renders every row, using info for not-applicable tools,
warning for absent optional capabilities, error for absent curl. Each diagnostic
names the feature, tier and applicable install advice. Non-macOS system-tool
absence must not warn about unavailable macOS-only clipboard recipes.
CLIProxyAPI uses `discover_binary()` and `installed_version()`; custom/PATH sources
report their source and unknown version rather than borrowing the managed record.
Missing managed tool names `:ParleyProxy update`; detection never calls `status`,
`resolve_target`, `download`, version subprocesses or password managers.

## Chunk 1: One source, read-only observations, existing consumers

### Task 1 — registry and installation advice

Files: create `lua/parley/deps.lua`, `tests/unit/deps_spec.lua`.

- [ ] Write direct tests for `deps.advice` and `deps.packages`: tiers × host × manager; aliases deduplicate; unsupported advice is honest; macOS selection matches the approved policy.
- [ ] Run the new spec and observe the missing-module failure, then implement the data and pure projections. No production IO in this module.
- [ ] Rerun until green and commit `#245: Centralize dependency data and host advice`.

### Task 2 — managed discovery and health

Files: modify `lua/parley/cliproxy.lua`, `lua/parley/health.lua`; create
`lua/parley/deps_probe.lua`, `tests/unit/deps_probe_spec.lua`,
`tests/integration/health_dependencies_spec.lua`; extend
`tests/integration/cliproxy_download_spec.lua`.

- [ ] First reproduce that `discover_binary`/`installed_version` create an absent data directory. Test explicit, managed, PATH and missing source precedence; malformed/missing version record means unknown.
- [ ] Make `bin_dir()` compute only a path; ensure the directory at `download()`'s write boundary. Existing managed installation tests must still pass.
- [ ] Test `observe` using a stateful temp filesystem: executable stubs appear/disappear and version records change, without executing those stubs. Assert custom/PATH versions are not attributed from a managed record.
- [ ] Test `health.check()` output for present, missing and non-applicable rows, including no-setup. Snapshot the data directory and fail on subprocess/network/package-manager execution; preserve existing require/setup/lualine checks.
- [ ] Implement the probe adapter and dependency section; rerun these tests and existing download specs; commit `#245: Report dependencies without discovery writes`.

### Task 3 — every existing install-advice consumer

Files: modify `lua/parley/clipboard_image.lua`, `lua/parley/image_shrink.lua`,
`lua/parley/argv_recipe.lua` only if required by the advice seam,
`lua/parley/paste_image.lua`, `lua/parley/exporter.lua`, `lua/parley/cliproxy.lua`,
`lua/parley/config.lua`, `lua/parley/init.lua`; extend
`tests/unit/{clipboard_image,image_shrink,argv_recipe}_spec.lua`,
`tests/integration/paste_image_spec.lua`, `tests/integration/export_spec.lua`.

- [ ] Pin missing-tool advice for clipboard and shrink on Darwin and apt Linux, preserving candidate order and configured argv behavior. Recipes resolve advice from dependency ids at selection, not module-load host snapshots.
- [ ] Pin repeated missing clipboard attempts: one notice per missing capability per setup generation, still probing so an installed tool works immediately. Reset notice state from the existing setup path; repeated invalid custom configuration keeps its actionable validation behavior.
- [ ] Implement registry advice use, retaining shrink's existing resolution cache. Reuse shared recipe selection; add no second executable selection policy.
- [ ] Centralize pandoc's missing message and cliproxy's shared NO_BINARY guidance; replace literal install commands in config comments with pointers to checkhealth. Sweep all `lua/parley` package-manager advice so only registry data contains commands.
- [ ] Run targeted specs and existing live clipboard/shrink conformance tests; commit `#245: Derive runtime installation advice from registry`.

### Task 4 — verification, map and single close boundary

- [ ] Create `tests/arch/dependency_registry_spec.lua` rejecting package-install command literals outside `deps.lua`; assert every builtin clipboard/shrink recipe's dependency id exists. Missing advisory tools degrade gracefully; no package manager may execute.
- [ ] Update `atlas/infra/test_harness.md` only if commands change; document the registry and health in the relevant existing atlas page, linking any new page from `atlas/index.md`.
- [ ] Run targeted specs, `make lint`, then `make test`; inspect `git diff --check`. Test commands for individual specs: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile <spec>' -c 'qa!'`; use the existing hermetic environment from Makefile.parley.
- [ ] Log evidence and formula policy handoff to #247, tick issue/plan tasks, then use `sdlc close --issue 245 --verified '<actual commands and results>'`. One atomic issue, no artificial milestone tags; close owns the fresh-context review.

## Constraints and lifecycle

ARCH-PURPOSE: every current package-advice consumer derives; formula parity is
explicitly #247's implementation, not a fabricated test against no formula.
ARCH-SECURE: advice is display text, never executable input; configured argv
continues through existing token validation. Health reads no credentials.
ARCH-CONSTRAINTS: finite registry and bounded existing version-record read;
no network, new subprocess, asynchronous work or background process.
ARCH-ORDER: dependency observations are fresh per health call; clipboard notices
are bounded by registry ids and reset at setup; installation between attempts
must recover without restarting. Shrink's configure-owned cache is unchanged.
ARCH-FUNERAL: no new durable runtime files; test temp files are removed by fixture
teardown, and in-memory notice state dies with setup generation/session.
ARCH-MOCK: reuse existing stateful release fixture for download regression and
actual temporary executable/version files for observation, not canned service
responses. Clipboard and shrink keep their current fake/live process boundaries.

## Revisions

### 2026-09-13 — ready against shipped #208

Integrated origin/main after #208 shipped and archived (`da6f6db`). Preserved
#245’s independent dependency section and reviewed proposal; refreshed the state
label. Implementation remains gated on design and formula-policy approval.
