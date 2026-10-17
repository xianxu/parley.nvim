---
id: 000371
status: open
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
---

# Declare the shipped issue vocabulary to weave (ariadne#422): manifest ship row, committed digest sidecar

## Problem

parley ships `construct/generated/vocabulary/issue.json` in git on purpose (#208): users install the plugin from GitHub through a plugin manager and never run weave, so the plugin reads its issue vocabulary from the installed tree. A fresh CI checkout has no weave ownership inventory (`construct/generated/weave/` is gitignored), so after any ariadne vocabulary change weave refuses the committed copy as "something weave did not write" and parley's main merge-check goes red (#321, #326, PR 285 after ariadne#415).
