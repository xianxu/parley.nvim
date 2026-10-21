---
id: 000408
status: working
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'ff2b59d3e0cdbf9eaa90fc0e5fb22e508f9f57ff' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-21T12:06:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# session-sync: fence insert admission and reload after lock acquisition

## Problem

Follow-up to #404, requested by the operator through the hub (Couch 61805ff7-ac98-4fcf-9a32-9a8215d5b878). #404 takes a local sidecar lock on InsertEnter, but samples mtime before acquisition and defers reconciliation; the current native race test expects a clobbered copy and preserves the old buffer. A queued first edit can therefore apply before freshness is reconciled.

## Spec

On InsertEnter for a registered session file or side doc, operator protection must be effective before the first edit applies. Once acquisition is confirmed, run an unconditional freshness check; if the file changed while the buffer is still unmodified, reload silently before admitting edits. Preserve modified-buffer conflict safety, existing ownership checks and unchanged-exit/submit lifecycle. No two-phase protocol. Check Couch's writer for atomic exclusion against acquisition at write time; coordinate any producer fix rather than asserting a local sidecar write excludes an in-flight writer.

Held-lock refusal or malformed/mismatched acknowledgment blocks edits visibly; pending keys are not applied and the notice says so. Namespace/store unavailability or a bounded 500 ms timeout permits editing with "not locked: Couch unreachable; edits may conflict"; concurrent disk changes use the existing clobber-copy path. Unknown ownership never authorizes unlock. This approved exception refines the confirmed-acquisition guarantee above (Revision below).

## Done when

- Deterministic native races cover an external write during InsertEnter acquisition, queued first input and silent reload of an unmodified buffer; parent/side docs and both supported Neovim versions agree.
- Replace the old clobber expectation at session_sync_native_spec.lua's insert-entry race where the new contract applies; modified-buffer and genuine post-acquisition violations remain safe.
- Named 500 ms acquisition bound is measured; unreachable/timeout applies queued edits with warning and preserves concurrent copies, while held refusal/invalid ack blocks edits without guessing ownership.
- Producer write-side exclusion and acknowledgment semantics are documented and tested, or a blocking producer issue is linked before claiming the end-to-end guarantee.

## Plan

- [ ] Pin pair#777 acquire/ack ownership and failure contract through the hub; approve admission/failure design in [the durable plan](../plans/000408-insert-admission-freshness-plan.md).
- [ ] Red/green native queued-input races, shared bounded acquisition and completed freshness before editing; retain existing ownership/exit/move safety and counted 4/8-turn bounds.
- [ ] Producer conformance, both runtimes, guards/lint/recorded suite, docs, close review and landing.


## Log

#404 landed as PR #327, merge c5089a7235b8d27a593a973be077649e7d0e56a9. Initial producer audit: pair cmd/internal/sessionsync/sync.go checks f.guard at write entry, later calls replaceShared, then checks the lock after the write only to emit a warning. The source explicitly states guard/write are not one step because Parley takes no shared flock. A second observation alone cannot prove atomic exclusion.

### 2026-10-21 — producer dependency and native ordering probes

Filed pair#777 unclaimed for the writer-side check-then-write gap. The hub
confirmed it is dispatched to pair:2 after #768 and instructed #408 to target an
acquire acknowledgment under the existing registry transaction; exact shape is
to be agreed through the hub (Couch e87b8b2c-1724-4e9d-ae1a-004a8ce7fd2e).
Planning only; do not start implementation on an assumed protocol.

Disposable headless probes on both installed runtimes queued iX after an
InsertEnter external write: checktime returned with old text, then native reload
preceded X. A guarded native edit! reread completed inside the callback on both.
These are feasibility observations, not the regression proof: plan requires
first-edit ordering with stateful fake acquire, clean/dirty cases and native
read-completion evidence. Probe files live only under the existing scratch root.

## Revisions

### 2026-10-21 — editable unavailable mode approved

The hub approved #408's design with one failure-policy correction (Couch
ba2623c0-aa38-4941-81ed-66909e97aef2, verified submitted): refusal of a held lock
and invalid ack blocks edits, but unreachable Couch or timeout must not lock the
operator out. Use the exact unconfirmed warning, allow editing, preserve
concurrent changes through the existing clobber-copy path, and use a named,
measured 500 ms wait. Updated Spec/Done when and the durable plan's state table
and tests; no producer assumptions or code changes. Await pair#777's pinned
contract through the hub.

### 2026-10-21 — acquire/release proposal and remaining pins

The hub proposed operator-acquire/operator-release with ID, canonical path and
a stable 32-hex turn token, registry-transaction serialization, exact lock-text
ownership evidence and idempotent same-token retries. Agreed in principle,
requesting machine-coded unavailable-store errors, recoverable move token and
exact release success shape through the hub before code. Both commands run
in-process: a stopped supervisor does not trigger editable degraded mode; only
namespace/store unavailable or the 500 ms timeout does. Updated the durable
plan's active table/seams/cost and appended its contract Revision.
