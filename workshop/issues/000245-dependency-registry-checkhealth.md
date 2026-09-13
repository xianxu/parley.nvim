---
id: 000245
status: codecomplete
deps: []
github_issue:
created: 2026-09-13
updated: 2026-09-13
estimate_hours: 1.76
started: 2026-09-13T13:20:58-07:00
actual_hours: 0.77
---

# Dependency registry and honest install advice: managed cliproxyapi, platform tools, brew one-liners in checkhealth

## Problem

parley depends on external binaries in three different ways and reports none
of them coherently. cliproxyapi is downloaded and managed by parley itself
(#131, #237) because its configuration is complex; `osascript` and `sips`
ship with macOS; ripgrep, ImageMagick, `wl-clipboard`/`xclip` are ordinary
package installs. A new user discovers a missing tool only when a feature
fails at runtime, and `:checkhealth parley` cannot tell them what to run.
Part of the `parley-packaging` project.

## Spec

- **One dependency registry** (pure data, `lua/parley/deps.lua`): each entry
  names the binary, its tier, how to detect it (`executable`, or the managed
  install record for cliproxyapi), which feature needs it, and the install
  advice. Tiers, decided by the operator 2026-09-13:
  - `managed` — cliproxyapi only: parley installs and updates it (existing
    `cliproxy` machinery), because its configuration is complex and its
    version matters for model access.
  - `platform` — `osascript`, `sips`: present on every Mac; detect and report.
  - `advisory` — ripgrep, ImageMagick/ffmpeg (#244's shrink recipes),
    `wl-clipboard`/`xclip` on Linux: detect, and print the exact one-line
    install command for the host (`brew install …`, `apt install …`). Parley
    never runs a package manager itself. No upgrade management: these tools
    are stable enough that a user not upgrading is not a problem.
- **`:checkhealth parley`** derives its dependency section from the registry
  (#213 makes checkhealth honest; this issue gives it the single source):
  OK / missing with the install line / managed with the installed version.
  Optional features degrade with a one-time notice naming the registry
  entry, not a stack trace (the #231 and #244 recipes already do this; they
  should read their advice from the registry, `ARCH-DRY`).
- The Homebrew formula (#247) lists the advisory tools as formula
  dependencies, so a brew user never sees the advice at all; this registry is
  the truth the formula's dependency list is checked against by a test.

## Done when

- `:checkhealth parley` shows every registry entry with its tier and status,
  and a missing advisory tool shows the exact install command for the host.
- The clipboard and shrink recipes take their install advice from the
  registry (no second copy of an install string anywhere in `lua/parley`).
- A test asserts the formula's dependency list (#247) equals the registry's
  advisory tier for macOS.
- No code path runs `brew`, `apt` or any package manager.

## Plan

- [x] Registry as data with a decision-table test over tiers × detection
- [x] checkhealth section derived independently (approved revision below)
- [x] Recipes (#231 clipboard, #244 shrink) read advice from the registry
- [x] Formula package projection verified; formula-vs-registry parity handed to #247 (approved scope revision)

## Log

### 2026-09-13
- 2026-09-13: closed — make test: 236 spec files pass, lint 407 files clean; git diff --check clean; live sips resize and metadata conformance pass; optional converters absent; clipboard live check skipped before mutation by preservation guard. Registry projection verified; actual formula parity is the approved #247 handoff.; review verdict: SHIP

- Plan-quality PQ-1 resolved after compressing test instructions and correcting
  function names; change-code passed on the approved design. Estimate-quality
  was informational: allocation may be optimistic; tests are included in each
  implementation primitive and measured actuals will be adopted at close.
- Registry and read-only dependency health implemented (ARCH-DRY, ARCH-PURE).
  TDD reproduced directory creation during absent managed discovery, then moved
  that write into download. Probe tests cover changing executable state,
  source precedence and managed-only version attribution; health forbids process
  launches and preserves the absent data directory without setup.
- Targeted checks so far: deps 8, probe 4, health 3, managed download 6 and export
  16 tests pass; lint reports 407 files without warnings. Runtime recipe advice
  and clipboard notice integration remain in progress.
- Live conformance: sips resized both fixture sizes and passed metadata removal.
  ImageMagick/ffmpeg/vips checks skipped because those optional tools are absent.
  Live clipboard check skipped before mutation because the clipboard held
  non-text content that the preservation guard could not safely restore;
  all three stateful preservation-policy checks passed.
- Package names checked against Homebrew Formulae and Debian trixie package
  pages; notably Homebrew `vips` corresponds to Debian `libvips-tools`.

- Final implementation: all current advice consumers derive from the registry;
  clipboard notices are bounded by dependency ids and reset by setup, with
  fresh executable probes on each paste. Shrink retains lazy cached resolution,
  including before setup. Package advice aliases deduplicate without changing
  executable precedence. The architecture guard enforces registry ownership.
- Final verification: `make test` exited 0: 236 spec files passed; its lint
  phase checked 407 files with zero warnings/errors. Full-suite findings were
  resolved: registry import shadowing and missing exported names in the Core
  concepts table. `git diff --check` is clean. Logs are in
  `/tmp/parley245-full-test.log`, `/tmp/parley245-shrink-live.log`, and
  `/tmp/parley245-clipboard-live.log`.
- #247 handoff: use `deps.packages({sysname='Darwin', manager='brew'}, 'default')`
  for the additional formula dependency set, currently `{ 'ripgrep' }`; Neovim
  is the host runtime, CLIProxyAPI is managed, other image backends/pandoc optional.
  No formula exists in #245; #247 must enforce the actual formula parity test.

- Close review round 1: SHIP, no Critical/Important findings. BR-1 (Minor)
  addressed by explicit PURE/INTEGRATION classifications in every Core concepts
  row. Reviewer independently passed 129 focused tests and lint; its sandbox
  could not bind the download fixture socket. The authoring environment's
  download six-test run and complete 236-file suite passed without that restriction.

## Revisions

### 2026-09-13 — independent packaging dependency section; design pending approval

**Reason.** The operator confirmed project order #208 → #245 → #246 → #247.
The existing health entry point accepts a dependency section without #213's
credential/provider diagnostics or Copilot removal. Those remain v1-release work.

**Delta.** Removed the blocking dependency on #213. The original Plan row saying
“after #213” is superseded by the independent section designed in
`workshop/plans/000245-dependency-registry-plan.md`. Centralization includes the
existing pandoc install message and cliproxy advice; it does not expand into
#213's broad external-tool or credential audit. Discovery must not create folders.

**Approval pending.** #245's all-advisory formula parity conflicts with #247's
“ImageMagick only if needed beyond sips.” Recommend a registry-marked default
macOS package subset (ripgrep), with alternative converters and optional pandoc
remaining advisory. The operator must approve this delta before implementation;
until then the original all-advisory requirement has not been silently waived.
The formula parity test still lands with #247, against whichever policy is approved.

**Design checkpoint.** Claimed in isolated `/tmp/parley245-plan`, then ran
`sdlc start-plan --issue 245`. No runtime changes or estimate made. Read-only
code evidence: `cliproxy.managed_binary()` currently creates its directory;
clipboard missing-tool notices currently repeat, while shrink notices already
reset once per configure. The durable plan specifies tests for both findings.

Fresh-context design review: Approved; no important correctness gaps. Formula
policy remains explicitly pending operator approval before implementation.

### 2026-09-13 — approved implementation

Operator said “go ahead with #245” after reviewing the optional-backend
recommendation. This approves registry-selected default formula dependencies
(ripgrep), with ImageMagick/ffmpeg/vips/pandoc optional. The prior all-advisory
wording is superseded; #247 owns formula parity against the selected projection.
The core project spine is #245, #246, #247, ending in a first-time user trial by
the operator's high-school daughter. No broader v1-release scope is implied.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

Approved plan resolves the design: apply ×0.2 design discount, ×0.40 implementation
scale, familiar Lua/Neovim ×1.0, and 15% design buffer. No novel stack or new
service: use existing Neovim filesystem/health APIs, recipe selector and release
fake, so no additional library-discovery primitive applies.

| Work | Primitive | Base design / impl | Scaled design / impl |
|---|---|---|---|
| Registry, observations and health | lua-neovim | 1.5 / 1.0 | 0.30 / 0.40 |
| Recipe advice and clipboard notice lifecycle | lua-neovim | 1.0 / 0.75 | 0.20 / 0.30 |
| Remaining advice consumers and architecture guard | cross-cutting-refactor | 0.4 / 0.3 | 0.08 / 0.12 |
| User guidance and atlas | atlas-docs | 0.15 / 0.15 | 0.03 / 0.06 |
| Single close review and verification | milestone-review | 0.1 / 0.4 | 0.02 / 0.16 |

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.30 impl=0.40
item: lua-neovim design=0.20 impl=0.30
item: cross-cutting-refactor design=0.08 impl=0.12
item: atlas-docs design=0.03 impl=0.06
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 1.76
```

Design 0.63 × 1.15 + implementation 1.04 = 1.7645 hours.

### 2026-09-13 — primary-checkout bookkeeping correction

The close invocation used temporary checkout name `parley245-plan`, so its
project sweep missed `parley.nvim#245` and its telemetry omitted the main
session. After the reviewed close commit, moved publication to the primary
checkout and re-ran `sdlc actual --issue 245`: measured 0.77h, adopted here
without guessing. The engine reports shared-window mention-fallback attribution;
this remains a measured estimate, not stopwatch precision. Updated the project
row/detail manually because close cannot override its basename-derived repo
identity. The original temporary-checkout calibration ledger was skipped; no
fabricated calibration row was written. Runtime code is unchanged after review.
