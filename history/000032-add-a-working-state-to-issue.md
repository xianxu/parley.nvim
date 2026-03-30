---
id: 000032
status: done
deps: []
created: 2026-03-29
updated: 2026-03-30
---

# add a "working" state to issue

so we have open|working|blocked|done|wontfix

default issue finder search filter:

1/ everything in issues/
2/ everything in issues/ and history/

## Done when

- [x] Status cycle: open → working → blocked → done → wontfix → open
- [x] Finder mode 0 shows active (open+working+blocked), hides done+wontfix
- [x] Sort priority includes all five statuses
- [x] Tests cover new statuses
- [x] Spec updated

## Plan

- [x] Update `cycle_status_value()` in issues.lua
- [x] Update `topo_sort()` priority map in issues.lua
- [x] Update issue_finder.lua filter (mode 0 excludes done+wontfix)
- [x] Update issue_finder.lua view labels
- [x] Add unit tests for working and wontfix
- [x] Update spec in specs/issues/issue-management.md

## Log

### 2026-03-29

### 2026-03-30

Implemented five-status cycle. `next_runnable()` still only picks `open` issues (working ones are already claimed). Finder mode 0 label changed from "open+blocked" to "active".
