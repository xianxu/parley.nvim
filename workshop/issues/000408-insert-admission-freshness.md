---
id: 000408
status: open
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: '3eb670eccfc8ea95e4c0f910a65acce3cebde491' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: fence insert admission and reload after lock acquisition

## Problem

Follow-up to #404, requested by the operator through the hub (Couch 61805ff7-ac98-4fcf-9a32-9a8215d5b878). #404 takes a local sidecar lock on InsertEnter, but samples mtime before acquisition and defers reconciliation; the current native race test expects a clobbered copy and preserves the old buffer. A queued first edit can therefore apply before freshness is reconciled.

## Spec

On InsertEnter for a registered session file or side doc, operator protection must be effective before the first edit applies. Once acquisition is confirmed, run an unconditional freshness check; if the file changed while the buffer is still unmodified, reload silently before admitting edits. Preserve modified-buffer conflict safety, existing ownership checks and unchanged-exit/submit lifecycle. No two-phase protocol. Check Couch's writer for atomic exclusion against acquisition at write time; coordinate any producer fix rather than asserting a local sidecar write excludes an in-flight writer.

## Done when

- Deterministic native races cover an external write during InsertEnter acquisition, queued first input and silent reload of an unmodified buffer; parent/side docs and both supported Neovim versions agree.
- Replace the old clobber expectation at session_sync_native_spec.lua's insert-entry race where the new contract applies; modified-buffer and genuine post-acquisition violations remain safe.
- Producer write-side exclusion and acknowledgment semantics are documented and tested, or a blocking producer issue is linked before claiming the end-to-end guarantee.

## Plan

- [ ]

## Log

#404 landed as PR #327, merge c5089a7235b8d27a593a973be077649e7d0e56a9. Initial producer audit: pair cmd/internal/sessionsync/sync.go checks f.guard at write entry, later calls replaceShared, then checks the lock after the write only to emit a warning. The source explicitly states guard/write are not one step because Parley takes no shared flock. A second observation alone cannot prove atomic exclusion.
