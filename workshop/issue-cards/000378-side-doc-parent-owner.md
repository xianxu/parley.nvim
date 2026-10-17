---
id: 000378
status: open
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
---

# Side documents inherit parent ownership

## Problem

Alt+o opens a side document from a registered parent but does not register the child with the parent's effective owner. The navigation therefore loses the ownership relationship; a later submit can instead select the current pane's actor.

Found during #373's required registration audit, independently of moving files.
