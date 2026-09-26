---
id: 000276
status: working
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T22:30:00-07:00
flow: {kind: quick, provenance: inferred, spec: "b24e62e0", done: "59419578"}
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
- Statusline stays readable under all packaged theme variants.
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
