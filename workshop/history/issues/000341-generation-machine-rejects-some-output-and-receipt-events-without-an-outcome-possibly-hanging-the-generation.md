---
id: 000341
status: done
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '4566dc9d5ee0c93172a7042f91e7aaf1bd2028c6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T19:13:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "e95c79f0", done: "bd766b2f"}
actual_hours: 0.20
---

# Generation machine rejects some output and receipt events without an outcome, possibly hanging the generation

## Problem

Found while measuring #229's stream discard paths (2026-10-15). There are two places where the generation machine rejects an event without recording an outcome. Neither drops text silently while streaming continues, but either may leave a generation hung: no terminal state, nothing shown to the operator.

1. **Rejected output.** `lua/parley/generation.lua:314-319`: an `output` event whose `seq` does not match `owner.next_seq`, or that arrives after the request is complete or resolved, returns `reject('output')` / `reject('operation')`. The runner treats a refused output as fatal to the provider: `response_provider.lua:93-98` sets `r.active=false` and calls `tasker.stop_owner`. Nothing records an issue or outcome. When the operation later resolves, `operation_resolved` (`generation.lua` ~430) does not stop the generation. Suspected result: the generation stays non-terminal. Unverified.
2. **Short or invalid write receipt.** `lua/parley/generation.lua:344-350`: a receipt whose `committed_bytes` differs from `attempted` while its status is `applied`, or that carries any other inconsistency, returns `reject('receipt')` before `s.inflight=nil`. So `s.inflight` stays set and no further write is pumped. Also `generation_runner.lua:420-421`: `write()` returns false when the blob is missing. What the step loop then does is unverified. Suspected result: a stalled generation with no outcome. Whether either case is reachable from real editor receipts is unverified.

## Spec

Measure first, as #229 did. For each path, drive the production transition function with the offending event sequence (a seq gap, output after completion, a short applied receipt, a missing blob) and observe whether the generation reaches a terminal state. Where it does not, the machine should end it with a named outcome and an issue the operator sees, rather than reject and wait. Keep `reject` for events that are genuinely ignorable, and say which ones those are.

## Done when

- Sequence tests through the production machine cover a seq gap, output after completion, a short `applied` receipt and a missing blob. Each either reaches a terminal outcome with a stated reason, or is shown to be unreachable, with the reason recorded.
- No rejected output or receipt leaves a generation non-terminal with nothing recorded.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `generation` | PURE | modified | `lua/parley/generation.lua` | An inconsistent receipt for the inflight write stops `uncertain`. |
| `response_provider` | INTEGRATION | modified | `lua/parley/response_provider.lua` | Refusing output reports `provider_failed` before stopping the transport. |
| `generation_runner` | INTEGRATION | modified | `lua/parley/generation_runner.lua` | A write whose blob is gone reports an `uncertain` receipt instead of returning silently. |

## Plan

Measurement (2026-10-15, :3), red tests on the production machine and runner:
- Rejected output (case 1). Any refused `cb.output` makes the adapter go inactive and stop its transport (`response_provider.lua:93-98`). On exit, `completed()` sees it inactive and reports neither completion nor failure; `resolve()` then sends only `operation_resolved`. If the machine was already stopping (overflow, revoke), that ends it. But when the machine itself rejected the output (a seq mismatch), nothing ends it. Runner test: phase stays `requesting` forever after the request resolves. Machine test: `operation_resolved` for an incomplete current attempt is accepted and changes nothing. Production never passes a seq, so the trigger is unreached today; the class is "a request resolves without completing", and that is reachable by any adapter path that goes inactive while the machine still waits.
- Output after completion: the adapter emits only while alive, and completion makes it inactive. Unreachable from the provider adapter. The machine's `reject('operation')` stays as an ignorable reject.
- Short or inconsistent receipt (case 2): `D.append` is all-or-nothing on bytes, but returns `applied` with 0 accepted when the native edit is not observed as the write (`prepared.accepted` unset). The machine rejects that receipt before clearing `inflight`, so no further write is pumped. Machine test: rejected, still inflight. A receipt for a write that is not inflight (a duplicate) is a genuinely ignorable reject.
- Missing blob: the inflight item's blob is released only after its receipt, so `write()` finding none (`generation_runner.lua:421`) is an internal invariant violation that today returns without a receipt.

- [x] ~~Machine: `operation_resolved` for an incomplete attempt acts as `provider_failed`.~~ Revised (see Revisions): the adapter reports the failure instead. Red: `response_provider_spec` "reports failure when the host refuses output" saw output, refused, resolved with no failed; now failed precedes resolved. The runner sequence test pins refused output → failed → resolved → terminal `provider_failed`, with the landed bytes kept.
- [x] Machine: a `write_result` naming the inflight write but inconsistent (status, byte counts) clears inflight, accounts committed bytes and stops `uncertain`. A receipt for any other write is still rejected without effect. Red: machine test above.
- [x] Runner: a write whose blob is gone dispatches an `uncertain` receipt (attempted = the effect's bytes, committed 0) rather than returning silently.
- [x] Atlas (chat/document stream accounting): the two outcomes and the ignorable rejects.
- [x] Verify: generation unit + sequences + stream_integrity, then the full suite.


## Log

### 2026-10-15
- 2026-10-15: closed — Prior evidence stands (red-measured stalls fixed; full suite exit 0 on b8a98818). Advisory (a): receipt validity computed once, same behavior (machine 70/0, sequences 33/0, provider 11/0, lint clean). (b) left as recorded per TL. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-15: closed — Measured with red tests: runner stayed requesting forever after a refused output; machine rejected a short receipt leaving the write inflight. Fix: response_provider reports provider_failed before stopping the transport (red: output,refused,resolved with no failed; now failed precedes resolved), runner ends terminal provider_failed keeping landed bytes; inflight inconsistent receipt settles uncertain crediting only vouched bytes (machine 70/0); missing blob shown unreachable, branch reports uncertain. Machine resolution-before-completion contract kept (permutation test). Full make -k test exit 0 on b8a98818, lint clean. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

### 2026-10-15 (:3)

- Machine rule for resolved-without-completing reverted: the pinned permutation test ("accepts every completion, receipt and transport-resolution ordering") makes resolution before completion legal, so resolution alone cannot mean failure (ARCH-ORDER). The authority is the adapter, which knows it refused the output.
- Receipt rule: red machine test (rejected, still inflight); now settles `uncertain`. Committed bytes are credited only when within a valid attempted count; an impossible count credits none. Two existing tests pinned the old reject-and-stall contract and were updated to the new one: "impossible receipts" and "a smaller applied editor slice" (its 11-of-10 case).
- Missing blob: unreachable by construction. The inflight item's blob is released only on its receipt, and stop releases queued items, never the inflight one. The runner exposes no seam into its blobs. The branch now reports an `uncertain` receipt instead of returning silently, so a future broken invariant ends with an outcome.
- Output after completion: unreachable from the adapter (it emits only while alive); the machine's reject stays ignorable.
- Focused: generation unit 70/0, sequences 33/0, provider 11/0, and 17 generation/response/chat spec files all pass; lint clean.
- Full suite on b8a98818: exit 0, lint clean (736 files).
- Close advisory (a), folded in at the TL's SHIP: the receipt's attempted/committed validity is computed once (`counted`), used for both the uncertain decision and the credit. Same behavior: machine 70/0, sequences 33/0, provider 11/0, lint clean. (b), the untested missing-blob branch, stays as recorded: a seam only for an unreachable branch is worse than the gap (TL agreed).

## Revisions

- 2026-10-15: plan item 1 moved from the machine to the provider adapter. The machine allows resolution before completion (a pinned contract), so the class "a request resolves without completing or failing" is closed where the request's fate is known: the adapter reports `provider_failed` when it refuses output, before stopping the transport.
