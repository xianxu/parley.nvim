---
id: 000299
status: working
deps: []
github_issue:
created: 2026-09-28
updated: 2026-09-28
estimate_hours:
card_mirror: '746d5429b867baa70efa0440ab67bc1142c9a4ad' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T22:21:06-07:00
flow: {kind: quick, provenance: inferred, spec: "9c52c5bd", done: "3652fdef"}
---

# Ignore floating overlays during chat navigation

## Problem

In `./parley_app --demo`, returning from a branch to the root via Option+O
appears to fail. Screenkey adds a nonfocusable float; the two-window preference
opens the root inside it. Outline root selection then focuses that same float.
Reproduced in an isolated Neovim instance with a parent link and overlay.

## Spec

Chat navigation destinations are ordinary editing windows, not floating or
external windows. Share a window eligibility predicate in `helper.lua` across
the link opener's existing-buffer lookup, other-split preference, and outline
destination lookup (ARCH-DRY). Keep exactly-two-editing-window preference even
when overlays are present, and keep ChatFinder's current-window behavior.
An existing root shown only in a float must still open in the editing window.
No new navigation policy, async work, persistent state, or IO is introduced;
existing file/path resolution is unchanged (ARCH-PURE, ARCH-ORDER,
ARCH-CONSTRAINTS, ARCH-FUNERAL, ARCH-SECURE). Fix the window classification at
all affected consumers rather than disabling Screenkey (ARCH-PURPOSE).

## Done when

- Option+O follows a parent link in the editing window with a Screenkey-like
  float present; the overlay keeps its original buffer and focus stays out of it.
- Two ordinary splits still prefer the other split with floating overlays.
- Outline root selection ignores a root buffer displayed only in a float.
- Reference and outline suites plus lint pass.

## Plan

- [x] Add failing regression coverage for link and outline destinations.
- [x] Share the ordinary-window predicate and apply it to both navigation paths.
- [x] Verify tests, lint, and update atlas.

## Log

### 2026-09-28
- 2026-09-28: closed — Five regressions failed on wrong destination windows before the fix; actual Option+O mappings and outline root callbacks now preserve overlays and select editing windows. 101 reference tests and 226 outline tests pass, lint 669 files clean, git diff --check clean; isolated parent-link probe now opens root in main window.; review verdict: SHIP

- Root paths resolve correctly. A headless root-link probe opened the parent
  inside the nonfocusable float while leaving the child in the main window.
  Independent outline investigation reproduced root selection focusing that float.
- Separate discovery: cold child-question outline selection can reject a row
  before its document index is repaired. This is outside the clarified root-file
  failure and is not part of this window-target fix.
- Red: three actual Option+O mapping cases chose the wrong window (single
  editing window, two real splits, and destination already in float); two
  outline root-selection cases focused a discovered/captured float.
- Green: `make test-spec SPEC=context/file_references` passed 101 tests in
  7 specs; `make test-spec SPEC=ui/outline` passed 226 tests in 6 specs.
  `make lint` passed 669 files without warnings/errors; `git diff --check` passed.
  The isolated demo-shape probe now opens root in the main window and preserves
  the overlay's scratch buffer. Existing split and ChatFinder tests remain green.
- Operator confirmed the demo navigation is fixed and authorized closing and landing.
