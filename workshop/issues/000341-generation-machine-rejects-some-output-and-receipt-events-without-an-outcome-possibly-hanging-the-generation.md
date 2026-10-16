---
id: 000341
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '5ace8194b3f58b0449e442dd569577213f28b494' # card fields mirrored from issue-cards; edit via sdlc
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

## Plan

- [ ]

## Log

### 2026-10-15
