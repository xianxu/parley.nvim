---
id: 000275
status: codecomplete
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T18:16:29-07:00
flow: {kind: full, provenance: inferred}
actual_hours: 5.02
---

# Add a packaged Parley theme picker with live preview

## Problem

## Revisions

### 2026-09-25 — expand packaged choices at user request

Add every style from navarasu/onedark.nvim and every variant from
EdenEast/nightfox.nvim, preserving existing choices. Pinned source inspection
found seven OneDark styles and seven fox variants. All 14 loaded in isolated
Neovim with correct colorscheme/background, OneDark style, and resolved Normal,
Comment, String, Identifier, Title, NormalFloat, FloatBorder, StatusLine and
ParleyQuestion highlights. Theme registry unit tests pass (6).

## Spec

Parley should expose `:ParleyTheme`, a compact floating picker that selects
among four packaged full Neovim colorschemes and restores the startup scheme.
The initial choices are Catppuccin Mocha (dark/colorful), Tokyo Night Storm
(dark/subdued), Catppuccin Latte (light/colorful), and Solarized Light
(light/subdued); Moonfly remains the packaged startup default. The picker
reuses the existing agent-picker/`float_picker` surface, supports cursor
navigation and mouse selection, and applies the highlighted candidate on every
selection change so the open chat and picker visibly preview the result.

The theme registry is the single source for ids, labels, colorscheme names,
contrast descriptions, and packaged dependency metadata (ARCH-DRY and
ARCH-PURPOSE). Applying a preview runs through one boundary that records the
active scheme and reapplies Parley's semantic highlight groups, but does not
write state. Opening the picker snapshots both the current scheme and saved
theme id; Escape or cancellation restores both snapshots, while Enter or mouse
selection commits and persists the current candidate. A fifth `Restore startup
theme` item applies the startup snapshot and commits the default/sentinel value.
A malformed or missing persisted id falls back to Moonfly without blocking startup
(ARCH-SECURE). Theme application is synchronous and bounded to the local
Neovim process; it creates no background work or durable artifacts beyond the
one state value (ARCH-CONSTRAINTS and ARCH-FUNERAL).

The packaged starter registers pinned theme plugins alongside Moonfly and
chooses the persisted theme before starting Parley. Normal plugin use can
invoke the same command and registry without the starter. Compatibility tests
load every packaged colorscheme, verify the expected `vim.g.colors_name`, and
verify Parley's question, thinking, annotation, picker, float, and statusline
groups remain defined after each switch. Picker tests cover preview on move,
commit on selection, cancellation restore, persistence, invalid state, and
keyboard/mouse entry through the production command.

## Done when

- `:ParleyTheme` opens the existing floating-picker style with 18 packaged
  variants plus a startup-theme restore action (19 entries total).
- Moving the cursor or selecting with the mouse applies the highlighted full
  colorscheme immediately to the surrounding Neovim UI and Parley buffer.
- Preview movement never persists. Enter/mouse selection persists the theme;
  Escape/cancel restores both the scheme and saved id active when the picker
  opened, including its OneDark variant and background mode. Choosing startup
  restore commits the sentinel and uses the launch snapshot before preferences.
- A fresh packaged launch restores the saved selection and invalid state falls
  back safely to Moonfly.
- Every packaged option is tested with Parley's semantic highlight groups,
  representative syntax groups (`Normal`, `Comment`, `String`, `Identifier`,
  and `Title`), float groups, and statusline surfaces.
- User documentation names the startup theme and `:ParleyTheme` command,
  all seven OneDark styles and all seven Nightfox variants, and the upgrade
  step for an existing copied starter configuration.
- Failed scheme loads roll back appearance; filtering changes preview by
  item identity even when the row index stays the same.

## Plan

- Durable implementation plan: `workshop/plans/000275-packaged-theme-picker-plan.md`.
- [x] Add the pure theme registry and persistence/apply seam with unit coverage.
- [x] Add packaged theme dependencies and startup restoration.
- [x] Add the `:ParleyTheme` picker with live preview, commit, and cancel restore.
- [x] Add compatibility/integration tests and user documentation.
- [x] Run the focused suite and full required verification; log evidence.

## Log

### 2026-09-25
- 2026-09-25: closed — 119 mapped theme tests pass including fresh and cached standalone bootstrap without PARLEY_RUNTIME, safe old-cache refusal, and staging cleanup; red-green proof recorded. All 19 pinned themes verified, preview terminal outcomes and production persistence tested. Starter artifact check, lint and diff checks pass. User approved ship.; review verdict: SHIP
- 2026-09-25: flow upgraded quick → full — 337 added lines in code files (limit 100); an earlier round of this close already ran the full review

- Filed and claimed as #275. Approved design: full colorscheme switching with
  live preview in the existing floating picker; four packaged dark/light,
  colorful/subdued options; startup restoration and cancel rollback.
- ARCH decisions: one registry owns theme metadata (ARCH-DRY/PURPOSE), invalid
  persisted ids degrade to the default (ARCH-SECURE), local synchronous apply
  has a bounded lifecycle (ARCH-CONSTRAINTS/FUNERAL).
- Spec review: preview and persistence are now separate; cancellation restores
  both the visual scheme and saved id, startup restore is an explicit fifth
  item, and compatibility acceptance names representative syntax groups.
- Implemented the registry, persisted preference, generic selection-change
  callback, picker command, starter dependencies, startup restoration, atlas
  map, and packaging documentation.
- Focused verification passed: theme registry (5), float picker (81), and
  production `:ParleyTheme` integration (1); `make lint PLENARY=/tmp/plenary.nvim`
  passed with 0 warnings and 0 errors.
- Loaded each pinned external colorscheme in a clean Neovim process and
  reapplied Parley highlights: Catppuccin Mocha, Tokyo Night Storm, Catppuccin
  Latte, and Solarized Light all passed representative `ParleyQuestion` and
  `NormalFloat` checks.
- Broader unit verification passed with no surviving test processes. The
  parallel integration fan-out had unrelated environment-sensitive failures
  (proxy/network, fresh-clone, starter bootstrap, and killed parity workers);
  changed-path packaging, picker, sidecar, traceability, and single-source
  checks passed when run serially.

### 2026-09-25 — release verification

- User exercised expanded picker and explicitly approved shipping.
- Final regression suite: 11 production picker cases, 7 real starter-bootstrap
  fixture cases, 81 float-picker cases, 6 registry cases, and 4 sidecar checks.
- Real pinned-plugin compatibility: all 19 entries passed syntax, Parley,
  statusline, float, background and OneDark-variant checks.
- Corrected earlier assertion that starter-bootstrap failure was unrelated: the
  registry require and changed plugin ordering needed fixture updates; the
  actual starter list assembly also had a parenthesis error, now fixed and
  exercised through Lazy's setup contract. Earlier broad-suite claims are not
  release evidence; the named focused checks above are.
- BR-1 selection identity now has one notification owner; BR-2 registry pins
  reach the starter and are asserted; BR-3 startup captured before preferences;
  BR-4 committed production and real compatibility tests; BR-5 read-failure
  regression; BR-6 README; BR-7 explicit mode; BR-8 snapshot rollback on failure.

### 2026-09-25 — BR-4 final acceptance evidence

- Review identified that earlier restart coverage called helpers, and the earlier
  real compatibility script did not assert OneDark style despite the log claim.
- Fresh production starter subprocesses now verify saved dayfox, saved OneDark
  warmer, absent and malformed preferences, and the captured startup sentinel.
  Removing the starter restoration line makes both saved-choice tests fail.
- Real pinned compatibility now asserts exact scheme and OneDark style for every
  entry; removing variant assignment fails at onedark-darker.
- Failed/missing scheme previews now enter through :ParleyTheme and preserve
  the appearance and preference. Focused suite passes 113 tests; real-plugin
  matrix passes all 19; changed test lint and git diff --check pass.

### 2026-09-25 — BR-9 terminal preview resolution

- Review disposed BR-4 and reproduced empty-confirmation preview retention.
- Enumerated all theme exit paths. Empty confirmation now dismisses/restores;
  confirming an unavailable scheme or failed save restores the opening snapshot.
- Three production-command regressions failed before the fix; mapped suite now
  passes 116 tests (14 theme command tests), with lint and diff checks clean.

- 2026-09-25 BR-10: restored documented copied-starter startup without
  `PARLEY_RUNTIME`. Under the existing initializer lock/deadline, bootstrap the
  latest stable release into Lazy's cache before reading its canonical theme
  registry; reuse compatible caches and preserve older caches with an actionable
  update error. Local Git fixtures cover fresh/cached startup, ignore prerelease
  tags, and prove incomplete-release staging/lock cleanup. New standalone tests
  failed against the previous starter (`parley.theme` unavailable), then passed.
  `make test-spec SPEC=ui/themes PLENARY=/tmp/plenary.nvim
  TEST_ENV_ROOT=/tmp/parley-br10-final JOBS=1` passed all 119 cases;
  `/tmp/parley-br10-final.log` holds evidence. Luacheck of starter and both bootstrap
  fixtures reports zero warnings/errors; `git diff --check` passes.
