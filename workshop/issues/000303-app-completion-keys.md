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
flow: {kind: full, provenance: inferred}
---

# Use familiar keys for app completion

## Problem

App completion lacks the familiar selection and acceptance keys the user expects.

## Spec

Use Blink insert mappings: Tab/Down select next, Up selects previous, Return selects and accepts the current item (first item if unselected), Esc dismisses the visible menu while staying in Insert mode. All keys fall back to native behavior with no menu; existing Ctrl shortcuts and command-line policy remain. ARCH-DRY: use Blink built-ins in starter policy, no new mapping implementation/state or dependencies. ARCH-PURPOSE: exercise real pinned Blink and actual prepared app chat, including no-menu fallbacks.

## Done when

- Real Blink tests cover Tab/Down/Up selection, Return acceptance selected/unselected, Esc dismissal preserving text/Insert mode and no-menu native fallbacks.
- Existing Ctrl shortcuts, app pairing and command-line completion still work; current user docs match.
- The included demo viewer keeps the latest file selection, bounds retained drafts to 20, reports failed saves visibly, and has deterministic regressions plus atlas documentation.

## Plan

- [x] Update keyboard regression, configure mappings, refresh docs and verify.

## Log

### 2026-09-29
- 2026-09-29: closed — User confirmed app behavior; 35 real-Blink keyboard checks and 185 starter tests pass. Publication viewer corrections pass 8 production-script Node tests (all red before fixes), covering both file-read orders, failed storage, 20-draft retention and legacy migration. Atlas/docs updated; full-range whitespace clean; main conflicts were issue-template records only.; review verdict: SHIP
- 2026-09-29: closed — Real pinned Blink passed 35 keyboard checks in ordinary and prepared app chat buffers: Tab/Down/Up selection, Enter selected/unselected acceptance, Escape dismissal, native no-menu fallbacks, legacy Ctrl keys and pairing. Regression failed at Tab before change. infra/starter, Lua lint and diff checks pass.; review verdict: SHIP
- 2026-09-29: flow upgraded quick → full — 192 added lines in code files (limit 100)

User specified the mapping directly. Use existing packaged Blink commands with fallback; keep current-buffer source and selection policy.

Verification: existing policy failed the revised real-Blink regression at Tab selection (step 7). With the five mappings, all 35 keyboard steps pass, including prepared app chat, selected/unselected acceptance, Escape dismissal, native fallbacks, legacy Ctrl shortcuts and pairing. infra/starter passes; Lua lint and diff checks clean. Logs: /tmp/parley-303-red.log, /tmp/parley-303-final-blink.log, /tmp/parley-303-starter.log.

## Revisions

### 2026-09-29 — publication review includes demo viewer

The user committed the demo rehearsal/viewer before requesting close and push. The publish gate requires the resulting HEAD to be reviewed. The app mappings passed again; the viewer needs latest-selection ownership for asynchronous file reads, bounded browser-draft retention with visible failed saves, deterministic production-script regressions and an atlas entry. Include those corrections in this publication boundary. ARCH-ORDER: superseded reads cannot replace the selected recording. ARCH-FUNERAL/CONSTRAINTS: retain at most 20 recording drafts and surface storage failures without losing the live editable text.

Verification: all 8 viewer production-script tests failed before corrections and pass afterward; both file-read orders, current/stale errors, draft retention/eviction, read/quota errors, malformed storage, legacy migration and complete-text download are covered. The starter suite passes on rerun (/tmp/parley-303-publish-starter.log). Demo guide and atlas now describe the viewer lifecycle; full-range whitespace was swept.
