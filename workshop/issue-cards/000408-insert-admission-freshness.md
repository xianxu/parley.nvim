---
id: 000408
status: open
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
github_issue:
---

# session-sync: fence insert admission and reload after lock acquisition

## Problem

Follow-up to #404, requested by the operator through the hub (Couch 61805ff7-ac98-4fcf-9a32-9a8215d5b878). #404 takes a local sidecar lock on InsertEnter, but samples mtime before acquisition and defers reconciliation; the current native race test expects a clobbered copy and preserves the old buffer. A queued first edit can therefore apply before freshness is reconciled.
