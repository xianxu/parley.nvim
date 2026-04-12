---
id: 000040
status: open
deps: []
created: 2026-03-30
updated: 2026-03-30
---

# nagging behavior

check previous issue at ../history/000037-rethink-of-claude-hook.md. One issue I noticed is that when in nagging mode, we keep nagging on each hook trigger. there should be backing off behavior like wait till things grow another X%. essentially we need to keep track how many times we nagged. 

think through this for me

1. when is state file generated.
2. how's the sha in state file determined, note there could be some commit on current git that are not in master, e.g. current top may not be what we want to compare to.

first describe what's current behavior, on a fresh start, without any state file. then think through the several workflows 1/ worktree; 2/ work on main. both may have multiple commits over the cause of a feature.

## Done when

-

## Plan

- [ ]

## Log

### 2026-03-30
f
