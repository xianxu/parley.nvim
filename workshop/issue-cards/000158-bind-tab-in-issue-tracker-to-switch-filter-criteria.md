---
id: '000158'
status: done
started: 2026-07-01T09:45:31-07:00
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.8
actual_hours: 0.20
---

# bind TAB in issue tracker to switch filter criteria

## Problem

The IssueFinder float picker cycles a **tri-state** `view_mode` on `<C-a>`
(`toggle_done`): `all → active → all+history` (`% 3`, added in #152). Two asks:

1. **`<Tab>` is the more natural key** to cycle the view — bind it to the same
   action as `<C-a>` (keep `<C-a>` too; additive, non-breaking).
2. **Collapse the 3 states to 2**: just **`issues`** (everything in
   `workshop/issues/`) and **`history`** (the archived items in
   `workshop/history/`). Drop the intermediate `active` filter (#152's
   "hide done" step) — done items simply show in the `issues` view.
