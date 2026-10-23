---
id: 000432
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: [lua:tests/integration/session_sync_native_spec.lua#session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408)]
---

# Native eight-turn clean release intermittently retains its lock

## Problem

One compatibility full-suite occurrence of session-sync native edits bounds operator calls and full reads across 8 confirmed turns (#408) failed at session_sync_native_spec.lua:642: clean acquisition-baseline release was not observed within the existing arrival wait. The failure is not reproduced by the bounded qualification below; its root cause remains unknown.
