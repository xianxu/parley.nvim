---
id: 000408
status: codecomplete
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '514b65925ed6f10422e8ccf132156f03e4a070c9' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-21T12:06:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 5.48
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
- [x] Producer conformance, both runtimes, guards/lint/recorded suite and docs. SDLC owns the following close review and landing gates.


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

### 2026-10-21 — both mapped runtimes green; replace superseded queued check

The final 0.11.7 mapping also passes all 29 files, 743 cases, zero failures/errors
(408-mapped-final-011.log); preferred runtime has the same 743/0/0 result. Both
include 126 native cases. No actual product-code changes followed that evidence.
The lost-ack fake test now waits for the complete holder/time/document/token
payload before terminating the fake, rather than only waiting for a newly
created filename. Its 8 direct executable contract cases pass after the readiness
correction. Cancelled only this checkout's superseded queued suite with
sdlc local-check cancel --run lease-3037014451 (confirmed cancelled on 661a70b6).
Push this settled test head and enqueue its replacement once; do not restart or
duplicate it while waiting for producer deployment. No live stage has occurred.

### 2026-10-21 — restart recovery: recorded suite and CI green

Recovered the original replacement runner after Couch restarts and the DNS
outage. Lease-3837696730 completed successfully on
5d2d9768b6b580d2702c91e2ec4ce46018b85e40: exit 0 in 5m30s, log SHA-256 prefix
bf02d640336e, recorded sdlc-local/suite success. All PR #329 server checks also
pass. No suite was restarted or duplicated; no flake resume was needed.

Pair main now contains #752 at 5fafe0f807a9076039a934f4f1d31c45fee637ae,
but #777 implementation has not landed yet. Pair:0's current clean binary
reports revision f2cd7108abcad8788ee062ab94c95b4f09b66393, which therefore is
not the producer deployment needed for this check. Hold :0 staging until #777
lands and the hub confirms its rebuild/deployment. Then run isolated real
conformance on the merge pin, the authorized disposable live check/cleanup,
and close/landing. Hub outcome report a8d34338-7bf2-433b-a4d8-73147ed5e902.

### 2026-10-22 — producer conformance and staged real-profile acceptance
- 2026-10-22: closed — R1 BR-1/BR-2 resolved by private six-phase operator_admission owner and witnessed IO dispatcher; BR-3 operator_lock marked new. Preferred mapping 772 and operator 0.11 mapping 774 pass; final native retry/BR-1 15, pure owner 14, ownership guards 2 and legacy IO/pure 15 on both versions pass; lint 0 warnings/0 errors in 822 files; producer conformance at pair#777 d16d027bd passed. Recorded final-code suite a209c5b5 lease-728916138 is queued; current tl-worker permits review overlap, green required before landing. TL 767f4323 orders repeated isolated real-profile stage/clear after approval, before landing. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-22: flow upgraded quick → full — 524 added lines in code files (limit 100); an earlier round of this close already ran the full review

Producer #777 landed as pair PR #533, landing pin
d16d027bd5d85b392fceedbf3025503d296707e7. Built Couch from a Git archive at that
exact pin in disposable scratch space (runtimebundle-generate, then go build).
The existing isolated production-client conformance command passes against that
binary: registration, rename/replay/conflicts/null/round, operator acquire,
exact same-token retry, foreign-token refusal, owned and absent release. Fake
conformance and its corrupted-fake negative control also pass. No daemon or
live registry was used.

TL approvals be38ac81 and 3bdecd71 authorize the fresh binary via per-process
PATH and a brief Parley :0 stage at 4c650bfd. The real-profile fixture copies the
operator's authored Neovim configuration, reuses installed plugin checkouts,
starts a fresh installed 0.11.7, and confines HOME/config/data/state/cache,
Couch authority and documents to disposable roots. It never touches the running
editor. The first two setup attempts exposed fixture issues (plugin data-path
symlink and non-serializable autocmd callbacks); a third driver run exceeded
its outer deadline. All stages were immediately cleared. Off-:0 tracing then
identified the probe's invalid undo assumption: one native undo includes the
external reload plus typing. Restore only the fixture's own X instead of asking
undo to stop at an assumed boundary. The controller's JIT is disabled only in
its test process; the real-profile child retains Parley's normal runtime rule.
No product code changed for these fixture corrections.

The final brief :0 stage at 4c650bfd2c7db9514735034711d0a0e24a8908ee passes for
both registered session.md and session.side/discussion.md: InsertCharPre sees
the fresh snapshot and document/turn proof before the first queued character;
no clobbered copy; changed Escape/Ctrl-C and explicit save retain ownership;
restoring the fresh baseline and unchanged Escape/Ctrl-C release; the actual
Alt+Return mapping saves and releases. Delivery is intentionally unavailable in
the isolated store, so this is release acceptance, not a new live-send claim.
Both registrations were forgotten and the final Registrations list is empty;
all disposable profile documents/state were removed. Final profile evidence is
live_profile-final.log under parley-408-producer.XQtnmQ in this slot's scratch.

Clear completed using sdlc f6a8db3a (contains ariadne#537): Parley :0 is clean
on main, HEAD and origin/main both
7d4e9adb37d9ba16c29dad1180fdc2eceb9368fd, zero ahead/behind. Report
 a142665c-c8d7-4de7-89fd-8cbe3621b42f sent to hub. Proceed to close review and
landing from this slot; no stage is held. Recorded suite on 5d2d9768 still covers
all code/tests, with subsequent changes limited to documentation.

### 2026-10-22 — close round 1 REWORK; state-owner revision proposed

The gate's independent review reproduced premature release after unavailable
acquire, edit/save, refused retry, then confirmed retry. refresh clears the
baseline when admission is refused and sidecar absent, losing outstanding edit
history. Review also requires the admission lifecycle to have one pure explicit
transition owner, and corrects operator_lock's plan-table status to new. The
review independently reran all mapped cases, 126 native cases and 19 Couch
unit cases on both versions, plus fake conformance; existing tests omit that
failure sequence. Gate sidecars record BR-1/2/3; issue remains working.

Sent the proposed state-owner sweep to hub for approval before production edits.
Plan Revision enumerates phases/events/history invariants, all existing field
writers, move/journal bridge, unchanged UX, and sequence/native regression proof.
No stage is held. Prior suite remains evidence for the old code, not a future
correction. A fresh suite and review will be required after implementing it.

### 2026-10-22 — state-owner approval and regression work

TL 767f4323 approved the six-phase pure operator_admission owner, sole writer
for baseline/proof/token/admission history, with an IO dispatcher and unchanged
failure UX. Native full-sequence red is in progress through the executable fake;
a bounded subagent owns only that native spec. Main owns the pure model and
integration sweep. Approval requires repeating the brief isolated profile check
only after the revised close review approves, then clear before landing.

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

### 2026-10-22 — R1 native red and recovery approval

BR-1 native controls pass; refusal cases fail E21 before retry InsertEnter on
both runtimes (2 pass/2 fail/0 errors). Scratch explicit-event isolation confirms
independent baseline loss. Log: /Volumes/TestScratch/parley-408-br1-wqyesjzj/red-bounded.log.
TL b5c63266 approved refused-only local i/a/o/I/A/O retry maps and
:ParleySessionRetry through the shared dispatcher, with the buffer blocked
until admission succeeds or the approved unavailable outcome. Plan Revision
records the recovery delta. Pure state owner and tests delegated; IO integration
remains in this session. No live stage is held.

### 2026-10-22 — R1 implementation and targeted evidence

The private operator_admission owner now owns baseline/proof/token/outcome
transitions; session_sync dispatches its IO effects and feeds witnessed outcomes.
All direct history writes are removed, including observed edits and move
restore/rebase. Refused-only native entry maps and :ParleySessionRetry share
that dispatcher, restore displaced mappings, and keep the buffer blocked until
admitted. A retained journal may restore only its exact validated witness
before replaying a previously completed release.

Native BR-1/control and retry matrix: 13 pass/0 fail/0 errors. Pure tests initially
12 pass on both runtimes; expanded to 14 with explicit stale/duplicate outcome
acceptance, including a reentrant acquire superseding a release. The shell now
rejects an ignored outcome instead of reporting stale release success. Added
native stale-release and queued retry freshness cases for the next pass.
Preferred mapped session-sync pass is green (all-final.log; includes replay
restoration correction); 0.11 mapped pass is running on current code. Lint was
0 warnings/0 errors over 822 files before the outcome refinement; rerunning.
Logs: /Volumes/TestScratch/parley-408-owner-fs58vfkw/. No stage held.

### 2026-10-22 — R1 targeted verification complete

Preferred mapped pass: 772 cases, 0 failures/errors. Current 0.11 mapped pass:
774 cases, 0 failures/errors, including the queued retry-freshness and stale
release-reply native cases. Final focused preferred pass: 15 native BR-1/retry
cases, 14 pure owner cases and 2 ownership guards, all green. Lint: 0 warnings /
0 errors in 822 files; diff-check clean.

The sole-writer sweep also preserved tokenless legacy policy: explicit submit
may adopt its exact legacy disk witness even when observation already established
history, and a successful new legacy write may replace opaque proof without
replacing the original baseline. One IO and one pure regression were red, then
15 focused cases passed (legacy-green.log). A registered token cannot enter the
legacy writer. No new watcher, journal, workflow or local-gates path changed.
The current code now proceeds to the recorded suite and R2 close; the new
real-profile refusal/retry check remains after review approval, as ordered.

### 2026-10-22 — R2 review and suite checkpoint

Pushed a209c5b5 through sdlc pr (PR #329). Recorded suite queued normally,
lease-728916138, attempt 27d86c85dcd7c03705a173153cfaeaf6; FIFO position 1
behind ariadne's weight-two run. Log lives under .git/sdlc/test-stats/inflight/
27d86c85dcd7c03705a173153cfaeaf6/run.log. No stage is held.
The final legacy IO/pure regression pass also succeeded on 0.11.7.
Per current tl-worker's explicit permission, R2 close review may overlap this
queued suite; green final-code recorded evidence remains mandatory for landing.
The revised live-profile probe, including foreign-lock refusal followed by i
retry and silent freshening, runs only after review approval and is cleared
straight after.

### 2026-10-22 — clean reload row approved; R2 superseded

Scratch native unavailable/no-edit -> watcher clean reload -> confirmed
unchanged exit fails because the foreign reload becomes operator work:
/Volumes/TestScratch/parley-408-reload-probe-fre1qr6r/red.log, 1 expected
failure/0 errors, census clean. TL d2810569 approved an atomic reload event
with exact before/after/clean facts, baseline translation only without prior
operator work, and unchanged history/token/phase. R2 on 3a8c4552 is superseded;
its verdict cannot authorize landing. Own queued suite lease-728916138 was
confirmed cancelled through sdlc; no other runner touched and no stage held.
The durable plan records the completed reload row.
