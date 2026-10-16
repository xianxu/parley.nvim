---
id: 000341
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
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
