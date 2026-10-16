---
id: 000357
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
---

# Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed

## Problem

Alt+Return times out under load. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.
- `document_registry` requests default to `timeout_ms` 2500, and `agentic_document`'s `bounded_request` blocks the editor in `vim.wait(2600)`.
- On a busy machine the couch CLI alone can take longer than that. The submit then fails as "Couch deadline exceeded", although it may still land.
