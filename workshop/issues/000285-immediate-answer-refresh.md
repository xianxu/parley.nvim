---
id: 000285
status: working
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
started: 2026-09-26T16:44:58-07:00
---

# remove stale answer immediately on re-ask

## Problem

## Spec

When re-asking an exchange, remove its visible answer as soon as the submit
command is accepted. Preserve the captured answer in the document's previous-
answer memory so concurrent requests can use it while the replacement is
waiting on readiness or streaming. Pending snapshots must be adopted by the
owning generation and cleared on rejection or completion (ARCH-ORDER,
ARCH-FUNERAL).

## Done when

- Re-asking clears the old answer before remote/readiness work begins.
- A concurrent request still receives the captured old answer from memory.
- Cancellation or failed admission does not leave an orphaned snapshot.

## Plan

- [ ] Add a pending previous-answer lifecycle to document memory and clear it on all terminal paths.
- [ ] Delete the old answer before response preparation, rebuild current geometry, and add regression coverage for immediate removal plus concurrent context.

## Log

### 2026-09-26

- Root cause: response preparation currently waits for remote input before replacing the old answer (#266 boundary).
