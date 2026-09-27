---
id: '000135'
status: done
started: 2026-06-25T12:27:54-07:00
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 4.0
actual_hours: 0.31
---

# Consume the generated issue vocabulary (issue.json) — drive issue-creation status + frontmatter typeahead from the model, not a hardcoded Lua enum

## Problem

parley.nvim hardcodes its own status enum + status-cycle in Lua (parley#32) and handles
issue frontmatter with its own knowledge of the fields — a **shadow** of the issue model,
the exact duplication ariadne#122's vocabulary layer exists to delete. #122 ships the
generated `issue.json` (the Go side already derives from it; JSON is the cross-language
lingua franca), but parley still hardcodes — so for parley, `issue.cue` is just-documentation
it doesn't derive from. This is the **second consumer** of #122's per-language binding
model (Lua, the *runtime-read* form): parley reads `issue.json` and derives its status set,
typeahead, and cycle from it.
