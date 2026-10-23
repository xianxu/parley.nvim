---
id: 000425
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '95b3b6ca4bc4b81b83338ad765dc25cde0d642e5' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+o with no link under the cursor flashes the winbar instead of a raw gf error

## Problem

## Spec

**Alt+o on text with no link shows a raw Lua error (operator, 10-23).** Alt+o's fallback (lua/parley/init.lua:5151,
called from :5196) runs `normal gf` on the word under the cursor; when that word isn't a file (e.g. "error"), Vim
raises E447 "Can't find file in path", and it surfaces as an E5108 stack trace with "Press ENTER". Screenshot:
ops `assets/session/2026-10-23.11-27-34.920.jpg`.

Fix: when there's nothing to open under the cursor (no link, no resolvable path), do nothing except a brief visual
cue: **flash the winbar**. If the buffer has no winbar (not Alt+Returned, so not tracked by Couch), show a transient
winbar just for the flash and remove it. No error, no message prompt. A real failure to open an existing link still
reports clearly.

## Done when

- Alt+o on plain text produces no error or prompt and flashes the winbar, with or without an existing winbar (test).
- Alt+o on a valid link or path still opens it (existing tests pass).

## Plan

- [ ]

## Log

### 2026-10-23
