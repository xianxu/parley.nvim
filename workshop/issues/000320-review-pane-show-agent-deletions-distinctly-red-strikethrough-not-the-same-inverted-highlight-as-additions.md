---
id: 000320
status: open
deps: []
github_issue:
created: 2026-10-13
updated: 2026-10-13
estimate_hours:
card_mirror: 'd4fa5cd048ccbd9091eac1d469d40f7181466289' # card fields mirrored from issue-cards; edit via sdlc
---

# Review pane: show agent deletions distinctly (red / strikethrough), not the same inverted highlight as additions

## Problem

In the review pane, the agent's proposed additions and deletions both render as the same inverted highlight, so the operator can't tell at a glance which text the agent wants to add and which it wants to remove. Seen 2026-10-13 reviewing ops' slot-continuity target (rounds with 🤖~old~{new} proposals).

## Spec

Render deletion references (`🤖~X~`, the struck text) in a distinct style: red background and/or strikethrough (the operator expected strikethrough), while additions (`{…}` agent text) keep their current highlight. Check `lua/parley/highlighter.lua` and `lua/parley/comment/view.lua` for the marker highlight groups; define a separate group for deletions, linked to a sensible default and themable.

## Done when

- `🤖~X~` text renders visibly different from `{…}` additions (separate highlight group, strikethrough or red by default).
- A highlighter test covers both groups on one line (`🤖~old~{new}`).

## Plan

- [ ]

## Log

### 2026-10-13
