---
id: 000334
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '2d13d568d9c722e8c2ac9b303ba9052818f33398' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-15
