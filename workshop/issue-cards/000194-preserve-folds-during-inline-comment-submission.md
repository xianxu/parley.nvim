---
id: '000194'
status: done
started: 2026-07-17T11:07:51-07:00
created: 2026-07-17
updated: 2026-07-17
estimate_hours: 2.5
actual_hours: 1.03
---

# Preserve folds during inline-comment submission

## Problem

Submitting a ready inline comment/drill-in rewrites the entire chat buffer via
`buffer_edit.replace_all_lines`. Neovim treats that operation as one replacement
covering every manual fold. Existing summary folds may disappear, while other
fold ranges can migrate into question text and leave incorrect gutter markers.

This regresses #193's invariant that fold updates and chat mutations must not
disturb unrelated completed semantic blocks or user-created folds.
