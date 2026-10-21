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
flow: {kind: quick, provenance: inferred, spec: "c2b0ba90", done: "c3f2cd0b"}
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

- [x] Pin pair#777 acquire/ack ownership and failure contract through the hub; approve admission/failure design in [the durable plan](../plans/000408-insert-admission-freshness-plan.md).
- [x] Red/green native queued-input races, shared bounded acquisition and completed freshness before editing; retain existing ownership/exit/move safety and counted 4/8-turn bounds.
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

### 2026-10-21 — implementation checkpoint; preferred native green

Pinned protocol seam and stateful executable fake are implemented. The first
coordinated native red run reproduced seven expected failures (110 existing
cases passed): parent/side stale first edit, held/uncertain/malformed failures,
and unavailable/timeout warning. A separate Normal-edit then InsertEnter red
case exposed locally-created legacy protection; both paths now share confirmed
acquisition. Current preferred-runtime native run passes all 118 cases, including
editable unavailable/timeout, auto-save then competing write preserving both
copies, and existing move/replay/Ctrl-C protections.

Clean freshness requires nested InsertEnter autocmd dispatch so the narrowly
permitted FileChangedShell reload runs without a deferred W11 prompt. The test
observer must retain its own on_reload callback to witness the subsequent first
edit; without it Neovim correctly detaches the observer and its wait stalls.
Initial overlap between targeted make runs was stopped; all further checkout
make tests are serialized. Unit protocol seam red/green and fake executable
contract evidence are recorded by their bounded tasks; main will rerun the
combined focused map.

Not complete: remaining acquisition/release/recovery enumeration, counted 4/8
turn costs, guards and full lint, native 0.11.7, producer #777 real conformance,
recorded suite, live authorization/check, close and landing. No suite or :0
stage is active. Pair#777 must land first.

### 2026-10-21 — preferred native 125 green; release/recovery sweep complete

Preferred-runtime native matrix passes 125 cases. In addition to original race
red/green, independent reds covered observed registered acquisition, replacement
legacy release, warning priority before typing, and validated move restoration
without new acquisition. Known owned baseline and exact lock bytes survive
lost replies; 4/8 turns meet bounded full-read/child counts. New InsertCharPre
evidence proves acknowledgment and clean freshness before the first character.
Protocol unit/fake integration map passes (19 Couch unit cases plus executable
fake conformance). Full lint previously passed 819 files; repeat after final
delta. Neovim 0.11.7 passed the prior 124-case head; final 125-case rerun is
active. No full suite or stage yet; broader mapped cases/guards follow.

### 2026-10-21 — native matrix both versions; final protocol clarification

The final native matrix passes 125 cases on both preferred Neovim and operator
0.11.7 (408-native-125.log and 408-native-125-011.log). The clarified protocol
map passes all 19 Couch unit cases and both executable fake integration cases.
The fake's direct process contract now passes 8 cases, including producer agent
sidecars remaining free for acquisition and untouched by an absent release;
that new case first failed with exit 3 before correcting the fake.

Couch b50e6d36 clarified operator-invalid exit 1 before store IO and malformed
argv usage exit 2; only structured session-sync-unavailable exit 7 and the local
500 ms timeout permit degraded edits. Classifier cases explicitly cover those
refusals. Architecture guards found missing public symbol names in the plan's
Core-concepts table; table corrected, rerun pending. Broader mapped tests, final
lint, producer conformance, recorded suite, live check and close remain pending.
No full suite or stage is active.

The hub approved canonical-sidecar-only admission (36085421): pair#777 will
normalize same-token alias ownership and return the canonical LockPath. Keep
the consumer path and exact on-disk byte checks; no alias witness guessing.

### 2026-10-21 — architecture guards and disposable protocol probe

Corrected Core-concepts table now passes the complete architecture/unit/docs
guard map; lint passes with zero warnings/errors across 819 files. Extended the
existing isolated real/fake registry conformance runner, using a disposable PATH
for the synchronous production Couch seam. Its new operator case first failed
against the registry-only fake with usage refusal; routing operator verbs to the
shared operator fixture makes fake-only conformance pass, including its existing
corrupted-fake negative control. Real run awaits pair#777's landing pin. The
broader session-sync mapped tests are running, serialized in this checkout.

### 2026-10-21 — mapped sweep findings and unreadable-proof red/green

The 29-file mapped run completed. Its failures were the operator fake's live
red-phase edit (a duplicate holder field) and 14 lock-reminder cases whose
claimed registration was absent from their empty fake registry; all other
mapped files passed. The fixture now seeds its claimed registration. Settled
verification passes the fake integration (2), all lock-reminder cases (18),
and a new unreadable-protection case (1), with zero failures.

Release-sweep inspection found nil == nil could accept an unreadable sidecar
when a registered attachment had no owned witness. The real-permissions native
case first reproduced an accepted submit and removed protection; release now
requires a non-nil exact legacy witness, or confirmed token ownership through
the producer. Preferred-runtime red/green recorded in 408-unreadable-red.log
and 408-unreadable-green.log. This enforces the approved unknown-ownership
refusal, with no new state or recovery action. The operator-runtime rerun also passes the same 1/2/18 cases; the recorded
full suite will verify the entire final head on both
runtimes, superseding another duplicated mapped rerun.

Producer canonical-path correction confirmed via Couch ddd81167; its replacement
suite and close are running. Consumer canonical-only validation is unchanged.

### 2026-10-21 — recorded check queued; staging dependencies

PR #329 opened on 661a70b6cc7f56c2529d25c362eebc61e3743cdf. Recorded suite
lease-3037014451 is queued on that exact head (attempt
9a52095c6af5097ec263b663e518ebee); do not duplicate or restart it. The hub approved
a brief disposable stage only after green suite and deployment: pair#777 lands,
pair#752 lands, hub rebuilds pair:0 on main, then stage Parley. No :0 changes
have occurred. Hub will tell the operator to submit/release legacy held turns
before restarting onto the new protocol. Isolated real conformance can run on
#777's merge pin before that deployment.

### 2026-10-21 — final preferred mapping green

The settled preferred-runtime session-sync mapping passes all 29 files, 743
cases, zero failures/errors (408-mapped-final.log). This includes the new
126-case native file, corrected registry-backed reminder fixture, token fake
and existing registered move/lifetime/recovery coverage. The corresponding
0.11.7 mapped run is active (408-mapped-final-011.log). Recorded suite remains
queued under lease-3037014451 on code head 661a70b6; no duplicate runner, code
change or stage. Documentation after that code head records the hub-approved
identity/discovery boundary and #410 follow-up only.

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

### 2026-10-21 — protocol pinned, implementation authorized

Hub a44e4450-a411-4a17-8c39-7e730dae5715 confirmed error Codes/exits, recoverable
ID/turn fields in exact LockText and release acknowledgment shape. Recorded
these in the durable plan Revision. Proceed against the agreed contract;
pair#777 lands first, coordinated through the hub.

### 2026-10-21 — explicit discovery boundary approved; #410 follow-up

TL a15354ef approved the confirmed-identity boundary and a follow-up if composing
the pending lookup into the same 500 ms budget is not small. #410 is filed
unclaimed, depending on #408. S1 adoption itself calls late attachment and
synchronous acquire, so a plain wait could restart the deadline inside its
callback. #408 leaves unknown-period edits available and reconciled on
attachment; its first-edit exclusion/freshness guarantee starts when identity
is known, including cached identity. README and atlas explicitly state that
boundary. No new blocking registration lookup is introduced.
