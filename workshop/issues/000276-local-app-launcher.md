---
id: 000276
status: codecomplete
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T22:30:00-07:00
flow: {kind: quick, provenance: inferred, spec: "b24e62e0", done: "59419578"}
actual_hours: 0.69
---

# Add local app onboarding launcher

## Problem

Local onboarding testing currently needs a fragile environment command. Repo cwd
and literal tilde paths caused misleading launches. New users also need a clear mode display.

## Spec

Add root executable `./parley_app` that resolves this checkout absolutely, launches
the real packaged starter outside repo mode, and isolates HOME plus all XDG roots.
Keep the launcher a thin shell wrapper (ARCH-DRY). Package pinned Lualine with
a prominent mode block, chat name, existing Parley activity/model indicator and
cursor position. Use automatic theme adaptation and no font-dependent separators.
The default demo profile is reused under the caller cache directory. An explicit
PARLEY_DEMO_DIR selects another profile; no user data is silently removed.

## Done when

- The launcher uses the checkout starter from any cwd and a reusable isolated demo
  profile. Its canonical default is outside the repo; PARLEY_DEMO_DIR selects an
  alternate profile. Preserve demo data between launches and reject in-repo paths.
- Packaged startup shows the mode prominently and keeps the status bar simple.
- Tests assert actual launch arguments/cwd/environment and statusline rendering.
- Statusline stays readable under all packaged theme variants. The app reserves
  its sign column so diagnostic appearance/disappearance never shifts chat text.
- --tutorials opens and edits the source tutorial directory directly with state
  remaining in the demo; marked ancestors cannot enable repo mode.
- --nuke deletes only an owned demo profile and exits; the next launch is fresh,
  preserving source tutorials and the normal installed profile.

## Plan

- [x] Add launcher and regression test for cwd/absolute-path isolation.
- [x] Add pinned Lualine defaults and production compatibility checks.
- [x] Document local testing and verify the focused suites.

## Log

### 2026-09-25
- 2026-09-25: closed — Six launcher tests pass; 182 starter assertions pass; 119 theme assertions pass; all19 real Lualine/theme checks pass including stable gutter text offsets with diagnostics added/removed. Scoped reset, direct source edits and marker ancestry covered by red-green tests. Previous review deliberately interrupted for user gutter request; full correction now ready. Lint/syntax/artifact checks pass.; review verdict: SHIP

- User requested a one-command local app demo, then a simple prominent mode bar.
- Theme-picker v2.6.0 was published separately before this follow-up.

- Implemented root launcher with canonical paths, reusable isolated demo roots,
  and explicit override. Tests cover spaces, caller cwd, all environment roots,
  argument forwarding, retained state and rejecting an in-checkout profile.
- Packaged Lualine uses plain separators, mode/name/location and existing Parley
  model/activity integration. Production options rendered all 19 themes in
  NORMAL/INSERT/VISUAL with contrasting mode blocks. Dependency/config tests
  failed before the implementation.
- Verification: launcher Python tests 2 pass; focused ui/themes 119 pass;
  real statusline compatibility 19 pass; shell syntax, starter artifact,
  changed Lua lint and git diff --check pass.

## Revisions

### 2026-09-25 — direct tutorial editing, reset and repo isolation

User requested `--tutorials` for editing packaged source chats directly, then
`--nuke` to clear the demo for the next first-run test. These extend the thin
launcher. The starter accepts explicit PARLEY_CHAT_DIR and PARLEY_REPO_MODE=0.
BR-1 also established that merely leaving the checkout does not prevent markers
in other ancestors. Explicitly disabling repo mode is the shared invariant
(ARCH-PURPOSE). Launcher tests cross real starter detection for marked/unmarked
default and alternate roots; a source-edit test writes directly to the chosen
chat root while preserving isolated state.

### 2026-09-25 — verification of extensions

- BR-1: launcher exports PARLEY_REPO_MODE=0 and real starter honors it. Four
  marked-ancestry regressions failed before the fix; all six default/alternate
  marked/unmarked cases now pass.
- Direct source-chat test failed before PARLEY_CHAT_DIR support, then verified
  opening and writing the selected source while state remains isolated.
- --nuke uses an ownership marker, refuses a live recorded editor, and removes
  only the selected demo root. Tests cover all five demo roots, absent reset,
  fresh relaunch, unknown ownership, live pid, symlink roots/targets and checkout
  ancestors. Six Python test cases pass.
- Starter integration matrix: 182 pass; theme suite: 119 pass; Lualine real
  compatibility: all 19 themes pass three mode labels and display checks.
  Shell syntax, starter artifact and changed Lua lint pass.
- The operator is editing packaging/tutorials/welcome.md concurrently; that
  content is kept outside these implementation commits.

### 2026-09-25 — stable gutter

User observed footnote diagnostic signs disappearing during typing and shifting
text. Set the app starter's signcolumn to yes; picker floats retain their own
explicit no-gutter setting. The real-rendering regression failed before the
setting and now verifies identical text offsets before/after diagnostic placement
and removal. All 19 theme/statusline checks still pass.

The in-progress review was deliberately interrupted to include this new request;
its unknown verdict is an interruption, not a completed review or new finding.
Re-run close on the complete change after the focused starter checks finish.

- 2026-09-26: #280 full boundary review found stale PID observations across competing launcher operations. Serialize launch/reset ownership checks and effects; add deterministic competing-launch and launch/reset tests (ARCH-ORDER).
