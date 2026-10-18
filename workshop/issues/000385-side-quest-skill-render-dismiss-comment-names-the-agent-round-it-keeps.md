---
id: 000385
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'fa4bea4bac04a6ca2e5f9eee3771be3e8620e423' # card fields mirrored from issue-cards; edit via sdlc
---

# side-quest: skill_render dismiss comment names the agent round it keeps

## Problem

## Spec

#383 made the agent's round its own diagnostic kind, cleared only by a confirmed submit, by design (the hub, 2026-10-18). `skill_render.clear_decorations` keeps it, and so does `M.dismiss`, its alias. But the dismiss doc comment still says it dismisses "the live round decorations", which now reads as if it also clears the agent's round. Fix the comment only: dismiss clears the review skill's decorations, and the agent's round stays until the confirmed submit.

## Done when

- The `M.dismiss` doc comment in `lua/parley/skill_render.lua` says it clears the review skill's decorations, and that the agent's round (#383) stays until the next confirmed submit.

## Plan

- [ ]

## Log

### 2026-10-18
