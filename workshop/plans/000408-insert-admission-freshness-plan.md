---
collaboration-mode: discussion
---

# #408 Insert admission freshness implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). Execute this tightly coupled native-input change in the main session using superpowers-executing-plans; SDLC owns the fresh review at close.

**Goal:** Once registration identity is known, with Couch available, no first insert edit reaches an unconfirmed turn or stale clean snapshot; with Couch unreachable, keep editing available with explicit conflict risk.

**Architecture:** Couch's existing registry transaction serializes acquire with registered writer commits (pair#777). Parley's InsertEnter waits for that single acquire acknowledgment, then unconditionally checks freshness and completes any required native clean reread before admitting edits. Existing session-sync ownership/baseline/submit/recovery remains the lifetime owner; no second watcher, two-phase protocol or journal.

**Tech Stack:** Lua, Neovim 0.11.7/0.12.5 native input, couch binary, existing embedded-nvim and fake-couch helpers.

## Core concepts

### Pure entities

| Name | Lives in | Status |
| --- | --- | --- |
| `new` — encapsulated operator admission transitions (`dispatch`, `snapshot`) | `lua/parley/operator_admission.lua` | new |
| `operator_result`, `operator_proof` — acknowledgment and ownership validation | `lua/parley/couch.lua` | new |

A decoded result must prove the requested registration identity, canonical file and effective operator protection; missing/mismatched fields and explicit refusals do not admit input; structured unavailability and the bounded timeout use the approved editable-degraded state below. Exact command/fields and ownership evidence are pinned through the hub with pair:2 before implementation, not invented by the consumer. Validation is pure and unit-tested with malformed/mismatched acknowledgments. There is one acknowledgment per newly admitted turn, not per character. Unknown fields remain tolerated; no persisted schema is introduced.

### Integration points

| Name | Lives in | Status | Wraps |
| --- | --- | --- | --- |
| `operator_lock` — Couch process seam | `lua/parley/couch.lua` | new | bounded synchronous acquire using the existing process owner/deadline |
| Admission history and transitions | `lua/parley/operator_admission.lua` | new | pure six-phase owner, copied snapshots and witnessed IO effects |
| `attach` — insert admission and validated move restoration | `lua/parley/session_sync.lua` | modified | InsertEnter and late attachment, existing owned lock/baseline state |
| Native freshness | `lua/parley/session_sync.lua` | modified | checktime, FileChangedShell/native reread and window-view restoration |
| Stateful fake Couch | `tests/helpers/fake_couch.lua` | modified | delayed acquire, ack success/refusal/timeout, external write before ack |

Token-owned release uses the same process seam and producer operator-release command, rather than unlinking an acknowledged lock locally; legacy unowned protection keeps only its existing explicitly authorized handling. All automatic, explicit-submit and move-finalization releases are enumerated in tests. The process seam must remain the one Couch spawn owner (ARCH-DRY). It returns before InsertEnter finishes; queued input cannot run during acquisition. A named insert-acquire bound is exactly 500 ms, independent of the longer submit timeout; test the passed deadline and measured hung-child duration. No new timer/retry daemon. A known owned turn can re-enter without spawning or resetting its baseline. Pre-existing/foreign protection is never claimed as newly acquired or silently released.

## Producer contract and alternatives

- **Chosen:** single acquire/ack under the existing registry transaction. Earlier writers finish before acknowledgment; subsequent writers see held protection. pair#777 supplies the executable contract; Parley must not advertise this guarantee against an old binary.
- **Rejected:** write sidecar and sample mtime again. An in-flight writer can already have passed its guard; another observation provides no exclusion resource.
- **Rejected:** async acknowledgment with editable buffer. Queued first input can land before confirmation/freshness. Async gating/replay adds an avoidable input queue and cancellation protocol.

The acquire response must distinguish newly obtained protection from an existing unrelated turn, and provide the exact ownership evidence the current release path needs. It must be idempotent for a lost response, or explicitly preserve unknown ownership until a later acquire confirms it. Pin these properties with pair:2 through the hub before code. Existing writer CAS and lock/recovery checks remain authoritative.

## User state and recovery

Actions: enter insert, leave insert, retry with i/a/o/I/A/O while refused or :ParleySessionRetry, edit, undo, submit, reopen interrupted move.

| Internal state / failure | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| Acquire pending | Briefly waiting on insert; no edits apply | Wait for the 500 ms bounded call | None; queued input is not replayed by custom code |
| Confirmed + clean; disk changed during acquire | Native clean reload, then normal operator band and insertion | Edit | No unsaved bytes replaced |
| Confirmed + clean; unchanged disk | Normal insert and operator band | Edit | None |
| Existing changed operator turn | Existing operator band; no baseline reset/reload | Submit | None |
| Held-lock refusal, other explicit refusal, malformed or mismatched ack | Visible acquisition failure; buffer non-modifiable | Press i to retry, or :ParleySessionRetry | Typed characters while refused are not applied or saved; state this in notice |
| Namespace/store unavailable (not a stopped supervisor) | Editable, band: not locked: Couch unreachable; edits may conflict | Edit | Concurrent agent changes may conflict; existing clobber-copy handling preserves both copies |
| 500 ms timeout, including possible unacknowledged acquisition | Same editable warning; retain witnessed protection, never delete on guess | Edit | No guaranteed exclusion; conflicts use clobber-copy handling, no silent unlock |
| Genuine dirty-buffer foreign write | Existing violation handling | Submit through existing reconciliation | Existing clobbered-copy policy retained |
| Move/recovery in progress | Existing interrupted-move state | Reopen to finish move | No new automatic release rule |

Failure gating owns only the temporary modifiable setting it installed: restore only if still owned, after successful admission or detach. Do not turn queued text into Normal-mode commands by forcing stopinsert. No automatic retry. TL approved this split in Couch ba2623c0-aa38-4941-81ed-66909e97aef2. Unreachable/timeout must restore any admission-owned edit gate before returning to queued input; never normalize those outcomes to a held-lock refusal. Classify machine-coded namespace/store unavailability separately from successful-but-invalid JSON and explicit producer refusals. Acquire/release run in-process; a stopped Couch supervisor is not unavailable.

The editable degraded state remains visibly unconfirmed through ordinary saves and status refreshes until a real acquire acknowledgment establishes protection. Do not rely on sidecar existence to claim the turn is confirmed. Reuse the existing violation/clobber-copy effect when a concurrent disk change meets a degraded operator edit, including a buffer auto-save has made clean; the free-turn clean reload path must not discard the operator's copy. No extra watcher or ownership-by-guess fallback. Native tests retain both copies and the warning.

## Freshness and baseline rule

After successful acquire, call checktime regardless of any pre-acquire mtime sample. A clean buffer may accept the write that completed before acknowledgment: this is acquisition freshness, not a lock violation. Preserve ordinary violation behavior outside this narrow admission scope. Baseline/content/loaded witnesses are established from the completed fresh snapshot, so unchanged Escape/Ctrl-C releases that turn and a later real edit stays held through save.

Native checktime inside InsertEnter can defer the actual reload. Do not equate command return with read completion or release input on a scheduled callback alone. If needed, complete a guarded native clean reread synchronously (with existing view restoration) before returning from admission. Never force-reread a dirty buffer. Native tests must prove the first on_lines edit sees the fresh snapshot, not only eventual final contents. Keep prior input/autocmd stall regression covered.

## Cost and lifecycle

For N new turns and B bytes per file: at most one bounded acquire child and one matching release child, plus a constant number of full-buffer/disk reads per turn, O(N*B); zero new processes per character, zero scans of other buffers. Count children and full reads at 4/8 turns. Existing-owned-turn reentry is O(1) ownership work without an acquire child. Existing per-attachment state owns the gate/receipt and discards them on detach; creates no new durable artifact family or growing queue (ARCH-BOUNDED).

## Tasks (single close boundary)

### 1. Pin producer and write red native/fake cases

Files: `tests/helpers/fake_couch.lua`, `tests/integration/session_sync_native_spec.lua`, `tests/integration/session_sync_spec.lua`, `tests/unit/couch_spec.lua`.

- [x] Obtain pair#777 command/ack contract before implementation (confirmed in Revisions); record its merge pin at real conformance before landing.
- [x] Replace the old insert-entry clobber expectation where the buffer is clean. Fake acquire pauses, writes the external snapshot, then confirms. Queue `iX` together; assert first native edit sees the fresh text and exact lock proof before applying X, with no .clobbered/violation.
- [x] Parent/side × both runtimes; unchanged exit, saved/changed reentry, dirty entry, early/late attach, foreign/pre-existing protection; Escape and Ctrl-C.
- [x] Held refusal/malformed/mismatched ack: queued input cannot mutate and the notice says so. Unreachable/timeout: queued input applies after the bounded call, warning persists, concurrent disk write preserves both copies via the existing clobber effect, even after auto-save. Retry never guesses ownership; unrelated modifiable settings survive cleanup.
- [x] Pin the named 500 ms process option and measure a fake hung acquire finishing at the deadline with harness arrival slack; use a terminating fake process (no orphan sleep/stdio holder).
- [x] Retain genuine post-acquisition/dirty conflict tests and prior checktime/autocmd stall regression.
- [x] Run focused red tests against main and record expected failures before production edits.

### 2. Implement minimal shared admission

Files: `lua/parley/couch.lua`, `lua/parley/session_sync.lua`.

- [x] Add bounded synchronous acquire through the shared process seam; pure ack validation has independent unit cases.
- [x] Share one admission lifecycle across InsertEnter/late attach; known owned turn reentry preserves baseline. Explicit refusal/invalid ack gates changes until retry/detach; transport unavailability/500 ms timeout admits edits with the unconfirmed warning and existing conflict preservation. Restore only owned option state.
- [x] Run unconditional post-ack native freshness; permit only clean acquisition reload; establish baseline after read completion before input admission.
- [x] Run focused native/fake/ownership tests green, including 4/8 counted turns; inspect trace order acquire ack -> read completion -> first edit.
- [x] Commit the implementation and evidence; no changes to old #404 review artifacts.

### 3. Verify, document, close and land

Files: `README.md`, `atlas/modes/session_sync.md`, this plan and issue Log.

- [x] Document acquire/freshness/failure retry semantics and producer minimum capability; preserve existing lock lifecycle description.
- [x] Run `make test-spec SPEC=modes/session_sync` on preferred runtime and with `PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim`; run Couch unit, architecture/docs guards and lint. Expected all green, bounded child/read counts.
- [x] Verify real producer conformance using disposable registered files after pair#777 lands; ask the hub before staging on live :0. No live store/document mutations without its authorization.
- [x] Push via sdlc pr and run the recorded suite on the final code/test head.

After these acceptance checks, close through SDLC's one boundary review, resolve findings, land on SHIP and report the exact merge/PR to the hub. Those gate-owned actions are recorded as they happen in the issue Log.

## Protocol and implementation status

- Acquire/release argv and acknowledgment identity/ownership/idempotence/error semantics are pinned by the hub in Revisions below. pair#777 must land before consumer conformance/landing.
- TL approved refusal versus editable-unreachable split and a named 500 ms synchronous bound (Revision below). Producer failure taxonomy must support that distinction.
- Confirm actual diff fits quick shell at change-code; if not, use this durable plan for the full flow and derive the estimate only after plan-quality.

## Revisions

### 2026-10-21 — approved failure policy and fixed acquire bound

TL approval ba2623c0-aa38-4941-81ed-66909e97aef2 replaces the original blanket
fail-closed proposal and longer shared submit deadline. Held refusal and invalid
ack remain non-modifiable with explicit keys-not-applied notice. Couch
unreachable or a 500 ms timeout permits editing with "not locked: Couch
unreachable; edits may conflict". Preserve concurrent copies through the existing
clobber path, including auto-saved buffers; never infer ownership from a lost
reply. The active state table, task checks and deadline text above are updated
to the approved contract. No code starts before pair#777's argv/ack/ownership/
retry pin, agreed through the hub.

### 2026-10-21 — proposed acquire/release contract agreement

Hub delivery 2617a411-5543-4c85-8b9c-ebbaf9bcd339 proposes:

- `couch --session-sync operator-acquire FILE --id ID --turn TOKEN --json`;
  matching `operator-release` arguments; bare release remains retired.
- FILE resolves to current registered canonical path, ID pins registration.
- TOKEN is 32 lowercase hex, generated once per operator turn and retained
  across lost replies. Same-token retry preserves exact ownership/text/time.
- Success: `Code: ok`, `OperatorLock: {ID, File, Holder: operator, Turn,
  LockPath, LockText, State: acquired|already-held}`. Foreign/legacy protection
  refuses without mutation. Release checks ID/token under the same flock and
  returns released/already-released; stale/foreign protection refuses.
- These commands work without the supervisor. Degraded editable mode applies
  only to namespace/store unavailable or the consumer's 500 ms timeout.

Agreed in principle through the hub, with three remaining pins before code:
(1) machine-readable unavailable-store Code/exit, distinct from explicit
refusals; (2) token recoverable from LockText or an explicit recovery query,
with copied move protection releasable under NEW canonical path plus same
ID/token; (3) release success envelope, preferably OperatorLock with echoed
ID/File/Turn and State released|already-released, with absence recognized
without claiming another ownership. Existing journals retain opaque lock bytes
and registration ID, so no new persisted journal format is required if the
token is in those bytes. Report receipt ac7195e9-2fcc-4df9-bc76-09d4d20ecad1.

The active table/cost/seam text above is adjusted for the in-process producer
and matching release call. No implementation yet.

### 2026-10-21 — all producer pins confirmed; implementation authorized

Hub a44e4450-a411-4a17-8c39-7e730dae5715 confirmed all remaining pins:

- Namespace/store unavailable: Code `session-sync-unavailable`, exit 7 only.
  Held protection: `operator-lock`, exit 3. Identity/path/validation refusals:
  explicit Code, exit 1. Uncertain sidecar publication:
  `operator-lock-uncertain`, exit 1, blocking rather than editable-degraded.
- LockText includes strict single `document: ID` and `turn: TOKEN` fields.
  Rename copies those bytes unchanged; release on NEW canonical path with the
  same ID/token succeeds. Parse recovery evidence strictly, rejecting duplicates.
- Release uses the same OperatorLock envelope, State released|already-released,
  echoing ID/File/Turn. Absence means already-released without ownership claimed.

Implement against this contract now; pair#777 must land before #408. Exact
release/acquire traces, fault classifications and native races are the tests;
no speculative producer change is part of this consumer issue.

### 2026-10-21 — complete acquisition/release enumeration

Native red cases exposed two acquisition bypasses and one release bypass:
normal-mode first edits and observed unknown-period edits created local legacy
protection, then blocked their own later insert entry; registered submission
could unlink a replacement legacy lock without ownership. All registered fresh
turns now share the same acquisition function; token release uses the producer
command. Unrelated registered legacy protection refuses; existing legacy
journals retain only their exact previously owned witnesses.

A separate native red case showed validated move restoration attempting to
reacquire its already-owned turn during late attachment. Restore now passes an
internal attachment hint only after existing journal/path/lock validation,
retaining actual insert intent without an acquire request at OLD. It finalizes
while keeping protection, then normal departure performs the sole owned
release at NEW. No new journal fields or operator states.

The temporary native test observer must retain on_reload; InsertCharPre now
records confirmed acknowledgment and fresh text before the queued first
character, in addition to on_lines witnessing the resulting edit. A named
500 ms deadline is measured by the real hung-child seam test and native timeout
case. Counted 4/8 native turns cap full reads at eight per turn and require one
acquire/release pair. Lost-ack retry preserves exact bytes/time and baseline.
An old submit receipt cannot hide admission failure; a dedicated red case
checks warning priority before typing.

### 2026-10-21 — final verification uses the full two-runtime suite

The mapped preferred sweep completed; settled targeted reruns cover its two
fixture defects. Final verification uses the recorded full suite (which runs
both preferred Neovim and installed 0.11.7), a superset of repeating both mapped
sweeps. The native unreadable-protection red/green closes a missing-witness
equality hole in the already-approved release policy: a nil witness never
authorizes removal. No state, scope or recovery-policy change.

### 2026-10-21 — confirmed-identity boundary; pending discovery in #410

TL a15354ef approved preserving S1's editable unknown-identity period, with a
pending-lookup wait only if small. Investigation shows adoption calls attach,
which itself acquires when already inserting: a wait-only wrapper would nest
a new full acquire deadline after spending its lookup budget. Sharing one
deadline across that lifecycle is filed unclaimed as #410, depending on #408,
under the TL's explicit follow-up option. #408 starts its acquire/freshness
guarantee when identity is known, including late attachment; it introduces no
blocking registration lookup for every Markdown InsertEnter. README and atlas
state this boundary. Unknown-period edits retain existing reconciliation.

### 2026-10-22 — pre-close evidence complete

Real conformance passed at pair#777 landing pin d16d027bd, and the approved
brief stage passed in a disposable copy of the real 0.11.7 profile. Both
registered parent/side checks prove fresh first input and lock/departure/save/
Alt+Return release semantics; actual message delivery is unavailable by design
in the isolated store. Every stage was cleared; final :0 equals origin/main.
Pre-close acceptance checkboxes are complete. Separate future gate-owned review
and landing from those checkboxes so they do not claim an unperformed action.

### 2026-10-22 — close R1: preserve turns through an admission state owner (proposed)

Review REWORK (BR-1/2) exposes a legal-state omission: changing an unavailable
acquire to a refused retry lets refresh erase the original baseline, so a later
confirmed retry adopts saved edited bytes and unchanged exit releases an
unsubmitted turn. BR-3 corrects operator_lock's integration status to new; the
base has no such function. No wording-presence test is needed for that table.

Proposed replacement: one pure operator_admission component owns baseline,
acknowledged proof, turn token and admission result. Its encapsulated transition
function is their sole writer (ARCH-ORDER/ARCH-PURE). session_sync is the IO
dispatcher; consumers read snapshots, never write authoritative fields. Sweep
refresh, entry/edits, explicit and automatic release, observed edits, restored
move witnesses and move rebase. Existing watcher, document journal and visible
policy stay unchanged. Await TL approval before production edits.

| State/event | Next state / effect | History rule |
| --- | --- | --- |
| idle + acquisition intent | acquiring; bounded acquire effect | establish pre-edit baseline and one token |
| acquiring + confirmed, clean and no outstanding work | freshening; checktime/read effect | keep prior history until validated read completes |
| acquiring + confirmed with outstanding work | held | preserve original baseline |
| acquiring + unavailable or timeout | unconfirmed, editable warning | preserve token and baseline; absence not inferred |
| acquiring + explicit refusal/invalid ack | refused, block edits | preserve token and baseline |
| unconfirmed/refused + retry | acquiring | reuse same token and original baseline |
| freshening + clean validated snapshot | held | fresh snapshot may establish baseline only with no outstanding work |
| freshening + failed/changed snapshot | refused | preserve original history and any acquired proof |
| live turn + edit/save/status | same admission knowledge | update observed content; never retire original baseline |
| live turn + confirmed owned release | idle | sole ordinary retirement of token/proof/baseline |
| move restore/rebase | proof-restored/rebased live turn | adopt only validated journal witness; translate baseline only when equal to preimage |

Operator mapping remains waiting / protected / editable-not-locked / refused;
refused-only native retry mappings and the explicit retry/submit actions remain (recovery Revision below). Acquire is
synchronous and bounded; no child outlives return, so no late process callback
can apply a reply. Match outcome generation/turn against the active intent;
detach discards the instance, and observation/refresh cannot retire history.
Failed/unknown release retains ownership history until confirmed release or a
validated journal completion, never clears it by a failed observation.

Proof: add the complete native unavailable -> edit/save -> refused -> confirmed
-> unchanged-exit regression (and a no-refusal control) on both runtimes. Pure
sequence tests assert original-baseline preservation independently of phases
through repeated failures, retries, save/status, duplicate/stale outcomes,
release failure and journal rebase. Add a dependency guard rejecting bypasses.
Fresh recorded suite and close review follow the revised implementation.

### 2026-10-22 — state-owner revision approved

TL 767f4323 approved the proposed six-phase owner and sole-writer sweep. The
reviewer's full native failure sequence goes red before implementation. After
new state logic passes a fresh suite and close review, repeat the approved
isolated real-profile stage/clear before landing; earlier live evidence does
not substitute for the new implementation.

The component exposes only new() -> dispatch(event) / snapshot(); snapshot is a
copy, with compatibility-derived admission labels and unconfirmed-work flags.
Commands issue bounded acquire/freshness/release effects with private operation
witnesses. Outcomes must match their active witness; duplicate/stale outcomes
are ignored. Edit/save/observation never retire history. Confirmed owned release
is the only normal reset; validated journal restore/rebase are explicit events
and cannot overwrite outstanding history except the existing preimage-equality
translation. Existing unregistered legacy turns use the same owner with opaque
exact proof bytes; their established disk/submit policy is unchanged.

- [ ] Add native BR-1 red and no-refusal control; add independent pure sequence tests.
- [ ] Implement the encapsulated owner and dispatch effects; sweep every old history writer.
- [ ] Guard the ownership boundary structurally, verify both runtimes and run the fresh recorded suite.
- [ ] Close review approves; then repeat the authorized real-profile stage and clear before landing.

### 2026-10-22 — native refusal recovery revision approved

Native BR-1 red/control runs on both runtimes produced two passing controls and
two failures: after refusal makes the buffer non-modifiable, native i fails E21
before InsertEnter. A scratch-only explicit InsertEnter diagnostic separately
reproduced the original baseline loss. Evidence:
/Volumes/TestScratch/parley-408-br1-wqyesjzj/red-bounded.log.

TL b5c63266 approved one explicit :ParleySessionRetry action using the same
admission dispatcher, plus buffer-local Normal i/a/o/I/A/O maps only while
refused. Those maps retry first and enter insert only when admitted; remove
them on leaving refusal and restore displaced buffer-local mappings. Keep the
buffer non-modifiable throughout refusal: no automatic retry, writable gap or
input interception. The band names the holder/reason and says press i to retry;
notification also names the command and says refused keys were not applied.
This supersedes the earlier leave-and-reenter-only recovery rule.
