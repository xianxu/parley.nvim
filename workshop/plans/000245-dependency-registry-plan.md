# Dependency Registry Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy); use superpowers-subagent-driven-development for bounded independent tasks or superpowers-executing-plans for warm-context work. Steps use checkboxes.

**Goal:** Explain missing dependencies and their installation from one registry, without installing packages or probing services during health checks.

**Architecture:** Pure dependency data and advice feed existing recipes and a thin read-only health section. CLIProxyAPI retains its existing discovery precedence and installation machinery. #213 retains credentials, provider validation, vocabulary diagnostics and Copilot removal.

**Tech Stack:** Lua, Neovim health API, Plenary/Busted; existing clipboard/shrink and release fixtures.

**State:** Operator approved; entering implementation gates.

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

- [x] Add the pure registry and its advice/package projections with unit coverage.

### Task 2 — managed discovery and health

Files: `lua/parley/{cliproxy,deps_probe,health}.lua`,
`tests/unit/deps_probe_spec.lua`,
`tests/integration/{health_dependencies,cliproxy_download}_spec.lua`.

- [x] Separate discovery from directory creation at the download write boundary; add the read-only observation adapter and dependency health section.

### Task 3 — every existing install-advice consumer

Files: `lua/parley/{clipboard_image,image_shrink,argv_recipe,paste_image,exporter,cliproxy,config,init}.lua`,
`tests/unit/{clipboard_image,image_shrink,argv_recipe}_spec.lua`,
`tests/integration/{paste_image,export}_spec.lua`.

- [ ] Route recipe, exporter and managed-binary advice through the registry; preserve recipe selection and custom argv validation.
- [ ] Bound missing clipboard notices by capability and setup generation while retaining fresh probes; preserve shrink's configure-owned cache.

### Function test strategies

| Function | Adversarial input class → mechanical guard |
|---|---|
| `deps.advice` | Unsupported host/manager and inapplicable dependency combinations → table-driven pure assertions forbid misleading commands. |
| `deps.packages` | Overlapping executable alternatives and selection tiers → set equality and uniqueness assertions enforce approved projection. |
| `cliproxy.discover_binary`, `cliproxy.installed_version` | Absent/conflicting binary sources and malformed records → real temporary filesystem precedence assertions plus unchanged-directory snapshots. |
| `cliproxy.download` | Absent install directory and rejected release artifacts → existing stateful release fake verifies successful installation and failure atomicity. |
| `deps_probe.host`, `deps_probe.observe` | Changing executable files and misleading managed records → stateful filesystem fixtures verify fresh source attribution with executable stubs that fail if run. |
| `health.check` | Missing setup, tools and unsupported hosts → captured health reports verify severity/applicability; filesystem snapshots and forbidden-process guards enforce read-only behavior. |
| `clipboard_image.select`, `image_shrink.resolve`, `argv_recipe.select` | Unavailable candidates and malformed custom argv → pure selection assertions preserve precedence, token validation and host-correct advice. |
| `paste_image.paste`, proposed `paste_image.reset_notices`, `parley.setup` | Repeated absence, later installation and repeated setup → stateful attempts assert bounded notices and recovery without restart. |
| `exporter.pandoc_export_html`, `cliproxy.login_argv`, `cliproxy.ensure_running` | Missing executable on unsupported hosts → existing integration entry points assert registry-derived guidance. |

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

### 2026-09-13 — operator approval and project spine

Operator approved #245 and the recommended formula policy: ripgrep is the
additional default macOS tool; alternate converters and pandoc stay optional.
#245 → #246 → #247 is the core project spine, delivering a setup the operator's
high-school daughter can try. Keep installation advice understandable to a new
user and preserve that sequence; broader v1-release work is separate.

### 2026-09-13 — plan-quality PQ-1

Compressed procedural test inventories into named function strategies with an
adversarial input class and mechanical guard for each risky surface. Approved
behavior, scope and implementation sequence are unchanged.

PQ-1 follow-through: named existing `image_shrink.resolve` and public runtime entry points; explicitly named the proposed clipboard notice-reset function.
