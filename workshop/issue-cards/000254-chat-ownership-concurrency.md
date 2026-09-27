---
id: '000254'
status: done
started: 2026-09-14T22:05:59-07:00
created: 2026-09-14
updated: 2026-09-15
estimate_hours: 33.107
actual_hours: N/A
---

# Harden chat ownership and concurrency

## Problem

Chat response presentation has a useful pure state machine, but document mutation,
request ownership, transport lifetime, and tool outcomes do not form an enforced
end-to-end lifecycle. The September 14 audit reproduced destructive completion
cleanup, cross-chat cancellation, and retirement of unresolved process ownership.

The operator's experience explains the progression: directly computing buffer
locations was fragile; introducing exchanges improved the abstraction, but did not
make concurrent edits robust. The operator reports disabling buffer editing while
generation runs as the current workaround. Verify the exact deployed restriction
at implementation start; the audit's injected edits establish unsafe interleavings,
not that normal typing currently bypasses that restriction.

The central distinction is **identity versus location**. An exchange keeps its
identity when edits move its lines. An identity alone still does not establish
which revision a response consumed or what text it may overwrite.
