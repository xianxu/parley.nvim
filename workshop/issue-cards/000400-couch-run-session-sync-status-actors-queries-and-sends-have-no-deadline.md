---
id: 000400
status: open
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
severity: low
---

# couch.run: session-sync status/actors queries and sends have no deadline

## Problem

Some `parley.couch.run` callers give the child no deadline. `session_sync.probe` runs `couch --session-sync status --json` and `couch --actors --json` through `couch.query` with no `timeout`, and `couch.send` has none either. If `couch` hangs (a wedged supervisor, a blocked socket), the child and its two stdio pipes stay open for as long as it hangs. The probe's `s.probing` flag also stays set, so probing stops for that buffer. `document_registry` (deadline per operation, #382) and `attention` (`PROBE_TIMEOUT_MS`) already bound theirs. Found during #399 (no leak was measured on this path; this is the unbounded-lifetime gap, not the #399 root cause).
