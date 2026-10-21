---
collaboration-mode: discussion
---

# #408 Insert admission freshness implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). Execute this tightly coupled native-input change in the main session using superpowers-executing-plans; SDLC owns the fresh review at close.

**Goal:** No first insert edit reaches an unconfirmed operator turn or a stale clean snapshot.

**Architecture:** Couch's existing registry transaction serializes acquire with registered writer commits (pair#777). Parley's InsertEnter waits for that single acquire acknowledgment, then unconditionally checks freshness and completes any required native clean reread before admitting edits. Existing session-sync ownership/baseline/submit/recovery remains the lifetime owner; no second watcher, two-phase protocol or journal.

**Tech Stack:** Lua, Neovim 0.11.7/0.12.5 native input, couch binary, existing embedded-nvim and fake-couch helpers.

## Core concepts

### Pure entities

| Name | Lives in | Status |
| --- | --- | --- |
| Acquire acknowledgment | `lua/parley/couch.lua` | new |

A decoded result must prove the requested registration identity, canonical file and effective operator protection; missing/mismatched fields, nonzero exit and timeout do not admit input. Exact command/fields and ownership evidence are pinned through the hub with pair:2 before implementation, not invented by the consumer. Validation is pure and unit-tested with malformed/mismatched acknowledgments. There is one acknowledgment per newly admitted turn, not per character. Unknown fields remain tolerated; no persisted schema is introduced.

### Integration points

| Name | Lives in | Status | Wraps |
| --- | --- | --- | --- |
| Couch process seam | `lua/parley/couch.lua` | modified | bounded synchronous acquire using the existing process owner/deadline |
| Insert admission | `lua/parley/session_sync.lua` | modified | InsertEnter and late attachment, existing owned lock/baseline state |
| Native freshness | `lua/parley/session_sync.lua` | modified | checktime, FileChangedShell/native reread and window-view restoration |
| Stateful fake Couch | `tests/helpers/fake_couch.lua` | modified | delayed acquire, ack success/refusal/timeout, external write before ack |

The process seam must remain the one Couch spawn owner (ARCH-DRY). It returns before InsertEnter finishes; queued input cannot run during acquisition. The existing submit timeout owner supplies a finite budget; no new timer/retry daemon. A known owned turn can re-enter without spawning or resetting its baseline. Pre-existing/foreign protection is never claimed as newly acquired or silently released.

## Producer contract and alternatives

- **Chosen:** single acquire/ack under the existing registry transaction. Earlier writers finish before acknowledgment; subsequent writers see held protection. pair#777 supplies the executable contract; Parley must not advertise this guarantee against an old binary.
- **Rejected:** write sidecar and sample mtime again. An in-flight writer can already have passed its guard; another observation provides no exclusion resource.
- **Rejected:** async acknowledgment with editable buffer. Queued first input can land before confirmation/freshness. Async gating/replay adds an avoidable input queue and cancellation protocol.

The acquire response must distinguish newly obtained protection from an existing unrelated turn, and provide the exact ownership evidence the current release path needs. It must be idempotent for a lost response, or explicitly preserve unknown ownership until a later acquire confirms it. Pin these properties with pair:2 through the hub before code. Existing writer CAS and lock/recovery checks remain authoritative.

## User state and recovery

Actions: enter insert, leave insert, retry by leaving and entering insert again, edit, undo, submit, reopen interrupted move.

| Internal state / failure | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| Acquire pending | Briefly waiting on insert; no edits apply | Wait for the bounded call | None; queued input is not replayed by custom code |
| Confirmed + clean; disk changed during acquire | Native clean reload, then normal operator band and insertion | Edit | No unsaved bytes replaced |
| Confirmed + clean; unchanged disk | Normal insert and operator band | Edit | None |
| Existing changed operator turn | Existing operator band; no baseline reset/reload | Submit | None |
| Refused, malformed ack, unavailable or timed out | Visible acquisition failure; buffer non-modifiable | Leave insert and retry insert | Typed characters while refused are not applied or saved; state this in notice |
| Timeout may have acquired protection | Same visible failure; keep witnessed protection, never delete on guess | Leave insert and retry insert | No silent unlock or overwrite |
| Genuine dirty-buffer foreign write | Existing violation handling | Submit through existing reconciliation | Existing clobbered-copy policy retained |
| Move/recovery in progress | Existing interrupted-move state | Reopen to finish move | No new automatic release rule |

Failure gating owns only the temporary modifiable setting it installed: restore only if still owned, after successful admission or detach. Do not turn queued text into Normal-mode commands by forcing stopinsert. No automatic retry. Proposed refusal UX requires TL approval before implementation.

## Freshness and baseline rule

After successful acquire, call checktime regardless of any pre-acquire mtime sample. A clean buffer may accept the write that completed before acknowledgment: this is acquisition freshness, not a lock violation. Preserve ordinary violation behavior outside this narrow admission scope. Baseline/content/loaded witnesses are established from the completed fresh snapshot, so unchanged Escape/Ctrl-C releases that turn and a later real edit stays held through save.

Native checktime inside InsertEnter can defer the actual reload. Do not equate command return with read completion or release input on a scheduled callback alone. If needed, complete a guarded native clean reread synchronously (with existing view restoration) before returning from admission. Never force-reread a dirty buffer. Native tests must prove the first on_lines edit sees the fresh snapshot, not only eventual final contents. Keep prior input/autocmd stall regression covered.

## Cost and lifecycle

For N new turns and B bytes per file: at most one bounded acquire child and a constant number of full-buffer/disk reads per turn, O(N*B); zero new processes per character, zero scans of other buffers. Count children and full reads at 4/8 turns. Existing-owned-turn reentry is O(1) ownership work without an acquire child. Existing per-attachment state owns the gate/receipt and discards them on detach; creates no new durable artifact family or growing queue (ARCH-BOUNDED).

## Tasks (single close boundary)

### 1. Pin producer and write red native/fake cases

Files: `tests/helpers/fake_couch.lua`, `tests/integration/session_sync_native_spec.lua`, `tests/integration/session_sync_spec.lua`, `tests/unit/couch_spec.lua`.

- [ ] Obtain pair#777 merge/command/ack contract and record it below before implementation.
- [ ] Replace the old insert-entry clobber expectation where the buffer is clean. Fake acquire pauses, writes the external snapshot, then confirms. Queue `iX` together; assert first native edit sees the fresh text and exact lock proof before applying X, with no .clobbered/violation.
- [ ] Parent/side × both runtimes; unchanged exit, saved/changed reentry, dirty entry, early/late attach, foreign/pre-existing protection; Escape and Ctrl-C.
- [ ] Refusal, timeout after possible acquisition, malformed/mismatched ack and retry: queued input cannot mutate, unrelated modifiable settings survive cleanup, no ownership guessed.
- [ ] Retain genuine post-acquisition/dirty conflict tests and prior checktime/autocmd stall regression.
- [ ] Run focused red tests against main and record expected failures before production edits.

### 2. Implement minimal shared admission

Files: `lua/parley/couch.lua`, `lua/parley/session_sync.lua`.

- [ ] Add bounded synchronous acquire through the shared process seam; pure ack validation has independent unit cases.
- [ ] Share one admission lifecycle across InsertEnter/late attach; known owned turn reentry preserves baseline. Failure gates changes visibly until explicit retry/detach, restoring only its own option state.
- [ ] Run unconditional post-ack native freshness; permit only clean acquisition reload; establish baseline after read completion before input admission.
- [ ] Run focused native/fake/ownership tests green, including 4/8 counted turns; inspect trace order acquire ack -> read completion -> first edit.
- [ ] Commit the implementation and evidence; no changes to old #404 review artifacts.

### 3. Verify, document, close and land

Files: `README.md`, `atlas/modes/session_sync.md`, this plan and issue Log.

- [ ] Document acquire/freshness/failure retry semantics and producer minimum capability; preserve existing lock lifecycle description.
- [ ] Run `make test-spec SPEC=modes/session_sync` on preferred runtime and with `PARLEY_TEST_NVIM=/opt/homebrew/bin/nvim`; run Couch unit, architecture/docs guards and lint. Expected all green, bounded child/read counts.
- [ ] Verify real producer conformance using disposable registered files after pair#777 lands; ask the hub before staging on live :0. No live store/document mutations without its authorization.
- [ ] Push via sdlc pr, run the recorded suite, close through SDLC's one boundary review, resolve findings, land on SHIP and report the exact merge/PR to the hub.

## Open pins before code

- pair#777 acquire argv and acknowledgment fields/ownership/idempotence semantics, through the hub.
- TL approval of refusal UX and bounded synchronous wait under the existing configured deadline.
- Confirm actual diff fits quick shell at change-code; if not, use this durable plan for the full flow and derive the estimate only after plan-quality.
