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

## Done when

- The launcher uses the checkout starter from any cwd and an isolated demo profile.
- Packaged startup shows the mode prominently and keeps the status bar simple.
- Tests assert actual launch arguments/cwd/environment and statusline rendering.
- Statusline stays readable under all packaged theme variants.

## Plan

- [ ] Add launcher and regression test for cwd/absolute-path isolation.
- [ ] Add pinned Lualine defaults and production compatibility checks.
- [ ] Document local testing and verify the focused suites.

## Log

### 2026-09-25

- User requested a one-command local app demo, then a simple prominent mode bar.
- Theme-picker v2.6.0 was published separately before this follow-up.
