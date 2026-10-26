---
id: 000448
status: open
created: 2026-10-26
updated: 2026-10-26
estimate_hours:
github_issue:
---

# 42shots move: declare former name and refresh weave workflows

## Problem

parley.nvim moved to github.com/42shots/parley.nvim (the 42shots move, phase C). sdlc refuses to match records made before the move unless the repository declares its former name (ariadne#644). Separately, CI on weave pins older than ariadne#641 goes red (ariadne#646), so no landing can pass until the seeded workflows are refreshed.
