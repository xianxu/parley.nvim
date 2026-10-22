---
id: 000414
status: open
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
github_issue:
---

# Investigate registered-saveas timing flake under load

## Problem

The existing registered native saveas test intermittently exceeds its fixed elapsed-time assertion under load. The same code failed in the full session-sync mapping and passed in one isolated rerun during #410 close review. Related class: #412 (fixed-budget native timing under load); this is a separate test and must not silently inherit that case's exception.
