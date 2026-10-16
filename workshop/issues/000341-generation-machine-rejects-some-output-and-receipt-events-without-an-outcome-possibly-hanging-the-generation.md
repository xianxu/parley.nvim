---
id: 000341
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'ba78beab37e5a2d8f05b3ab607b79cdf1725f4f0' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T19:13:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
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
| `generation` | PURE | modified | `lua/parley/generation.lua` | A request resolved without completing is a provider failure; an inconsistent receipt for the inflight write stops `uncertain`. |
| `generation_runner` | INTEGRATION | modified | `lua/parley/generation_runner.lua` | A write whose blob is gone reports an `uncertain` receipt instead of returning silently. |

## Plan

Measurement (2026-10-15, :3), red tests on the production machine and runner:
- Rejected output (case 1). Any refused `cb.output` makes the adapter go inactive and stop its transport (`response_provider.lua:93-98`). On exit, `completed()` sees it inactive and reports neither completion nor failure; `resolve()` then sends only `operation_resolved`. If the machine was already stopping (overflow, revoke), that ends it. But when the machine itself rejected the output (a seq mismatch), nothing ends it. Runner test: phase stays `requesting` forever after the request resolves. Machine test: `operation_resolved` for an incomplete current attempt is accepted and changes nothing. Production never passes a seq, so the trigger is unreached today; the class is "a request resolves without completing", and that is reachable by any adapter path that goes inactive while the machine still waits.
- Output after completion: the adapter emits only while alive, and completion makes it inactive. Unreachable from the provider adapter. The machine's `reject('operation')` stays as an ignorable reject.
- Short or inconsistent receipt (case 2): `D.append` is all-or-nothing on bytes, but returns `applied` with 0 accepted when the native edit is not observed as the write (`prepared.accepted` unset). The machine rejects that receipt before clearing `inflight`, so no further write is pumped. Machine test: rejected, still inflight. A receipt for a write that is not inflight (a duplicate) is a genuinely ignorable reject.
- Missing blob: the inflight item's blob is released only after its receipt, so `write()` finding none (`generation_runner.lua:421`) is an internal invariant violation that today returns without a receipt.

- [ ] Machine: `operation_resolved` for the current request attempt that has not completed, outside stopping, acts as `provider_failed`. Staged bytes drain first, then stop `provider_failed`. Red: machine and runner tests above.
- [ ] Machine: a `write_result` naming the inflight write but inconsistent (status, byte counts) clears inflight, accounts committed bytes and stops `uncertain`. A receipt for any other write is still rejected without effect. Red: machine test above.
- [ ] Runner: a write whose blob is gone dispatches an `uncertain` receipt (attempted = the effect's bytes, committed 0) rather than returning silently.
- [ ] Atlas (chat/document stream accounting): the two outcomes and the ignorable rejects.
- [ ] Verify: generation unit + sequences + stream_integrity, then the full suite.


## Log

### 2026-10-15
