---
id: 000250
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.51
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

## Estimate

Small Lua navigation correction with existing resolved paths and picker seams: design 0.2h, implementation/tests 0.2h, review 0.08h, 15% design buffer. Same calibrated small-fix method as #249.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.2
item: milestone-review design=0 impl=0.08
design-buffer: 0.15
total: 0.51
```

## Plan

- [ ] Trace outline branch activation and reuse its resolved child path to open the sub-chat at its start.
- [ ] Add navigation regressions covering branch forms, non-branch entries, and missing children; verify in the app launcher.

## Log

### 2026-09-14

- Filed at the operator's request; implementation has not started.
- Inspection: lua/parley/outline.lua already records `child_path` alongside the parent `file` and branch `lnum` for tree outline entries. Follow the activation path before choosing the implementation seam.

- Implementation decision: branch activation uses resolved child_path, loads the existing target buffer, and calls the shared focus helper at line 1 without nearest-outline-line adjustment. Missing files notify and preserve the source. Non-branch selection keeps its existing path. The issue spec is operator-approved; this atomic change uses the structural plan gate and full closing review.
