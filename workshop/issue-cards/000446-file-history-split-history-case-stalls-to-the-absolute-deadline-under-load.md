---
id: 000446
status: open
created: 2026-10-25
updated: 2026-10-25
estimate_hours:
github_issue:
---

# file_history split-history case stalls to the absolute deadline under load

## Problem

tests/integration/file_history_spec.lua hit the spec runner's 200 s absolute deadline under load. Its 24th case, 'per-window file Back (#333) copies the parent's history into a split and keeps later cursors and visits independent', made no progress for 138 s after 23 cases completed. The case is fully synchronous: edit, vsplit, set the cursor, FileBack. It has no waits and no child process. The spec normally takes about 67 s.

This is the class ariadne#622 swept in ariadne: a wall-clock bound that fails under machine load rather than on a defect.
