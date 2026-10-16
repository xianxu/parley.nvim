---
id: 000334
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-16
estimate_hours:
card_mirror: '04cc6bb3de9dfb94959a3754e3a6aba16a20fa89' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T15:03:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "7ce01dc5", done: "a33349a6"}
---

# Leaving a buffer while holding the operator lock flashes the red winbar three times (submit reminder)

## Problem

The operator holds the session-sync lock (red winbar "your turn, Alt+Return to submit") and navigates to another
buffer, e.g. via Alt+o into an answer, then forgets the lock: the agent can't write the file until they come back and
submit. The operator (2026-10-15): when leaving a buffer while holding the operator lock, stop them to submit first,
e.g. flash the winbar three times.

## Spec

- On leaving an agentic/session-sync buffer's window or switching that window to another buffer (BufLeave / WinLeave)
  while the operator holds its lock with unsubmitted edits, **flash the red winbar three times** (a short, visible
  pulse) and show a one-line message: "unsubmitted: Alt+Return to submit" naming the file. Navigation is not blocked.
- No flash when the lock is held only because of an edit that was undone back to the baseline (#330), or when there
  are no edits since the last submit.
- Optional: a setting to make it a hard confirm ("submit / leave anyway") instead of a flash; default is the flash.
- Applies to agentic documents too (universal-agent-input-interface S1).

## Done when

- Headless tests: leaving with a held lock triggers exactly three winbar flashes and the message; leaving without a
  lock, or after an undo back to the baseline, triggers nothing.
- README documents it.

## Plan

- [ ] Add a pure unsubmitted-turn predicate in session_sync.lua; reuse the
  existing lock reader and acquisition baseline, including the undo-to-baseline
  exclusion and auto-saved edits. Connect BufLeave/WinLeave in its shared
  attachment so registered and legacy documents use the same path.
- [ ] Extend document_band.lua with a bounded per-window temporary pulse through
  its existing owner/layer renderer; no second winbar writer. Coalesce duplicate
  leave events, emit three red pulses, preserve live underlying views, and retire
  on completion, superseding leave, window close, buffer replacement, source
  detach/submit/undo or user option override. Own one pulse timer per window.
- [ ] Add headless regressions for exact pulse count/message, free/submitted/
  undone turns, saved-but-unsubmitted turns, duplicate events, split isolation,
  navigation during a pulse and safe restoration. Map through modes/session_sync.
- [ ] Document, run targeted and recorded full tests, coordinate a staged live
  check, close through SDLC and land on SHIP.


## Log

### 2026-10-15

### 2026-10-16 — initial design (pending hub approval)

The issue is claimed and start-plan passed from fresh main after #319 landed.
The own-slot Ariadne refresh was blocked by weave-generated review discovery
ignore entries/links; preserved those in two narrow stashes, then refreshed.
Upstream contains the ignore entries and weave recreated the links; both trees
are clean. No production code or tests changed for #334 yet.

Proposed visible behavior: flash the physical window being left. On WinLeave
its source document remains visible there; on a same-window buffer switch the
reminder overlays the destination's bar and names the source file, so the pulse
remains visible without delaying navigation. Three bright red pulses, initially
150ms on / 150ms off (under one second), then restore the current underlying
bar rather than a stale snapshot. Emit one message per leave transition:
"unsubmitted: Alt+Return to submit — PATH". No optional hard-confirm setting.

ARCH-DRY: turn/baseline knowledge stays in session_sync and all winbar writes
stay in document_band. ARCH-PURE: the unsubmitted predicate receives turn,
baseline and current hash directly; table-driven tests exercise held/free and
baseline equality without IO. ARCH-ORDER/FUNERAL: one pulse lease/timer per
window, replaced/cancelled explicitly; queued ticks prove that lease still
owns its window and source before any UI effect. Temporary pulse priority must
survive underlying poll renders and restore their latest view. Existing owner
proofs protect changed options. Tests control tick scheduling and exercise
actual native leave/buffer events as well as cancelled/late ticks.

Target the quick shell (at most 100 added production lines); pause and re-plan
before implementation if the renderer extension cannot stay bounded there.
The destination-window interpretation and transient renderer mechanism are
being sent to the hub for approval before change-code.

## Revisions

### 2026-10-16 — approved window pulse

Hub approved the window interpretation and one cancellable document_band pulse
per window in delivery a60ed2ea-1a52-48e5-b74e-2f0bcc33c58d. Keep the quick
shell; report green without staging, since the hub sequences live acceptance.
No navigation blocking or confirm setting.
