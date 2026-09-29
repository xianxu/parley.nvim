---
id: 000303
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: 'ef577b2bd953d7e6033e7c275eca1ba5f9a43021' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T11:59:53-07:00
flow: {kind: quick, provenance: inferred, spec: "31dc5753", done: "6d1a5da3"}
---

# Use familiar keys for app completion

## Problem

App completion lacks the familiar selection and acceptance keys the user expects.

## Spec

Use Blink insert mappings: Tab/Down select next, Up selects previous, Return selects and accepts the current item (first item if unselected), Esc dismisses the visible menu while staying in Insert mode. All keys fall back to native behavior with no menu; existing Ctrl shortcuts and command-line policy remain. ARCH-DRY: use Blink built-ins in starter policy, no new mapping implementation/state or dependencies. ARCH-PURPOSE: exercise real pinned Blink and actual prepared app chat, including no-menu fallbacks.

## Done when

- Real Blink tests cover Tab/Down/Up selection, Return acceptance selected/unselected, Esc dismissal preserving text/Insert mode and no-menu native fallbacks.
- Existing Ctrl shortcuts, app pairing and command-line completion still work; current user docs match.

## Plan

- [x] Update keyboard regression, configure mappings, refresh docs and verify.

## Log

### 2026-09-29

User specified the mapping directly. Use existing packaged Blink commands with fallback; keep current-buffer source and selection policy.

Verification: existing policy failed the revised real-Blink regression at Tab selection (step 7). With the five mappings, all 35 keyboard steps pass, including prepared app chat, selected/unselected acceptance, Escape dismissal, native fallbacks, legacy Ctrl shortcuts and pairing. infra/starter passes; Lua lint and diff checks clean. Logs: /tmp/parley-303-red.log, /tmp/parley-303-final-blink.log, /tmp/parley-303-starter.log.
