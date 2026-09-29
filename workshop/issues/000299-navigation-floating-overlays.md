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

- [ ] Add failing regression coverage for link and outline destinations.
- [ ] Share the ordinary-window predicate and apply it to both navigation paths.
- [ ] Verify tests, lint, and update atlas.

## Log

### 2026-09-28

- Root paths resolve correctly. A headless root-link probe opened the parent
  inside the nonfocusable float while leaving the child in the main window.
  Independent outline investigation reproduced root selection focusing that float.
- Separate discovery: cold child-question outline selection can reject a row
  before its document index is repaired. This is outside the clarified root-file
  failure and is not part of this window-target fix.
