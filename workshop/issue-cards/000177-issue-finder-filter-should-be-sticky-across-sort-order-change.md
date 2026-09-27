---
id: '000177'
status: done
started: 2026-07-10T01:19:44-07:00
created: 2026-07-08
updated: 2026-07-10
estimate_hours: 0.98
actual_hours: 1.04
---

# issue finder filter should be sticky across sort order change

## Problem

Issue Finder loses the user's prompt query whenever it closes and opens again. This
includes the repaint triggered by changing between the `issues` and `history` views,
so the visible result set unexpectedly becomes unfiltered after a sort/view change.
