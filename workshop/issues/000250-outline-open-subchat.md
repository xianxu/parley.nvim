---
id: 000250
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours:
started: 2026-09-14T10:28:16-07:00
---

# Open sub-chat when selecting an outline branch

## Problem

Selecting a chat branch in the chat outline currently lands on the branch reference in the parent transcript. The operator expects selecting the branch to navigate into that sub-chat.

## Spec

Activating a branch entry in the chat outline opens its referenced sub-chat file at the start of that file. Apply this consistently to standalone and inline branch references, including branches displayed within an expanded chat tree. Other outline entries retain their existing destinations.

Reuse the existing resolved child path and chat-file navigation machinery where possible (ARCH-DRY). Keep branch expansion/collapse distinct from activating a navigation entry. Handle missing child files visibly without creating an empty chat accidentally.

## Done when

- Selecting a branch opens the referenced sub-chat at the start of the file, rather than landing on its reference in the parent.
- Standalone, inline, and nested branch entries follow the same rule.
- Non-branch outline navigation and branch expansion/collapse continue working.
- Regression coverage checks destination file and cursor position, including a missing child file.

## Plan

- [ ] Trace outline branch activation and reuse its resolved child path to open the sub-chat at its start.
- [ ] Add navigation regressions covering branch forms, non-branch entries, and missing children; verify in the app launcher.

## Log

### 2026-09-14

- Filed at the operator's request; implementation has not started.
- Inspection: lua/parley/outline.lua already records `child_path` alongside the parent `file` and branch `lnum` for tree outline entries. Follow the activation path before choosing the implementation seam.
