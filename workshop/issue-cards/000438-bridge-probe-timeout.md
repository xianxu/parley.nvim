---
id: 000438
status: open
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
github_issue:
---

# Couch bridge timeout test reads a probe marker before startup is established

## Problem

Main's diagnostic baseline suite failed the Couch bridge subprocess timeout test while landing #425. This is separate from that branch's agentic-document lifetime failure; no shared root cause is established.
