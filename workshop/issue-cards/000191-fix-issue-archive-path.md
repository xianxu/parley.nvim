---
id: '000191'
status: done
started: 2026-07-16T12:19:56-07:00
created: 2026-07-16
updated: 2026-07-16
estimate_hours: 0.7
actual_hours: 0.58
---

# Fix issue finder archive path

## Problem

The SDLC archive layout now stores completed issue records in
`workshop/history/issues/`, but Parley's default `history_dir` still points at
the parent `workshop/history/`. Issue Finder's history view therefore scans a
directory containing only subdirectories and returns no archived issues.
