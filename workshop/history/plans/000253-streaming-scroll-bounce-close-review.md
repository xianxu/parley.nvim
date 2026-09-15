# Boundary Review — parley.nvim#253 (whole-issue close)

| field | value |
|-------|-------|
| issue | 253 — Streaming fold updates bounce the viewport during scrolling |
| repo | parley.nvim |
| issue file | workshop/issues/000253-streaming-scroll-bounce.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2cc212167fccdee8dec42fde284e2c0c174dedb7..64b80bd8bf7684aacbdc88aff450c5b846698f81 |
| command | sdlc close --issue 253 |
| reviewer | codex |
| timestamp | 2026-09-14T13:50:59-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned diff matches the issue’s Spec and revised Plan. Fold clearing preserves each window’s view without undoing intentional follow movement, and streaming and completion share byte-column positioning. No blocking findings.

1. **Strengths**
   - View and `foldenable` restoration precede error propagation (`lua/parley/tool_folds.lua:104`).
   - Shared endpoint projection removes duplicated completion logic (`lua/parley/stream_position.lua:5`).
   - Attached-UI regressions exercise split views, wrapped lines, native wheel input, and exception cleanup.
   - Atlas documentation and test mappings cover the changed behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - All 15 spec files mapped to `chat/exchange_model` passed.
   - Lint passed: 451 files, zero warnings or errors.
   - Pinned-range `git diff --check` passed.
   - Full-suite and starter-smoke claims were not independently rerun. Repository files remained unchanged.

6. **Architecture**
   - **ARCH-DRY — Pass:** streaming and completion consume one endpoint projection.
   - **ARCH-PURE — Pass:** projection is directly unit-tested without IO; editor operations remain in integration code.
   - **ARCH-PURPOSE — Pass:** covers maintenance bounce and wrapped-tip following, including completion.
   - **ARCH-MOCK — Pass:** actual isolated Neovim supplies the relevant stateful UI behavior.
   - **ARCH-CONSTRAINTS — Pass:** adds constant-size view bookkeeping and endpoint calculation; retains fold-count work bounds.
   - **ARCH-SECURE — Pass:** test children inherit isolated storage; no new credential or external-input boundary.
   - **ARCH-ORDER — Pass:** maintenance restoration has explicit scope; asynchronous tests wait for observable completion and redraw.
   - **ARCH-FUNERAL — Pass:** no new persistent runtime artifacts; test children are stopped and reaped.

7. **Plan revision recommendations:** None. Existing revisions explain the final shared projection and Lua cleanup approach.

```findings
{}
```
