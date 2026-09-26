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

- The launcher uses the checkout starter from any cwd and an isolated demo profile.
- Packaged startup shows the mode prominently and keeps the status bar simple.
- Tests assert actual launch arguments/cwd/environment and statusline rendering.
- Statusline stays readable under all packaged theme variants.

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
