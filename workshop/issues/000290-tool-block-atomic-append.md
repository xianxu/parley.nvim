---
id: 000290
status: open
deps: [000264]
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
---

# Write each tool block in one append during streaming, folded as written

## Problem

The runner writes at most 4096 bytes per scheduler turn
(`generation_runner.lua:418`). A tool result over 4 KB (100 KB by default, up
to 512 KB) therefore lands in several writes, and its closing fence arrives
in a later one. That switches the result's section kind
(`document/grammar.lua:120`, the `tool_body` lookahead) and forces another
fold repair of the whole exchange, so each large result flickers the
exchange's folds twice or more instead of once (#281 Findings 1). In
between, the buffer also holds an unterminated block, which every parser
consumer then has to tolerate.

## Spec

- `response_tools.adapter.insert_tool` (`response_tools.lua:136-149`) already
  builds the whole block as one string. The document write path should accept
  a tool block as a single append, rather than slicing it at 4096 bytes like
  streamed prose.
- The size is already bounded at the source: results are capped by the byte
  budget in `lua/parley/tools/dispatcher.lua:261-266` (100 KB default, 512 KB max) and calls at
  64 KB. Record that bound as the reason a single write is safe
  (ARCH-CONSTRAINTS), and measure the time of one 512 KB append on a large
  chat.
- Prose streaming keeps its 4096-byte slicing; only tool-block effects change.
- This is independent of #264: with both done, a tool block causes no visible
  flicker; with this alone, it drops from ≥2 fold repairs per block to 1.
- **Fold as written (operator, 2026-09-27).** Even with one write, a new tool block
  appears unfolded for a few scheduler turns until the parse catches up and fold repair
  creates its fold. The writer already knows the block is foldable (`🔧`/`📎`). So in the
  **same scheduler turn** as the write, it creates the closed fold over exactly the rows it
  wrote (`N,Mfold` in each window showing the buffer, respecting each window's
  `foldenable`). Don't create the fold first and insert into it: appending after a fold's
  last row doesn't grow it.
- The writer is a **fast path, not the authority** (the #193/#200 lesson: writer-maintained
  folds used to drift). It must produce exactly the range the confirmed projection will,
  so #264's diff reconcile sees an exact match and leaves it untouched; any disagreement is
  corrected by the reconcile. Depends on #264 M1 (the diff reconcile).

## Done when

- A result over 4 KB reaches the buffer in one write: a test observes one
  document edit carrying both the opening and closing fence.
- A streamed tool call and result are folded closed in the same turn as their write:
  probing `foldclosed` right after the write (before any fold repair step) reads closed;
  and after settling, #264's reconcile reports `removed==0`/`created==0` for them (the
  writer's fold matched the projection exactly).
- Streamed prose still writes in 4096-byte slices (regression test).
- A timing of a 512 KB result append is recorded in the Log.
- Existing streaming, stop-generation and tool-fold suites stay green.

## Plan

- [ ] Find where tool-block effects inherit the 4096-byte slice, and give them a whole-block write
- [ ] Tests: one write per block over 4 KB; prose still sliced
- [ ] Writer creates the closed fold in the same turn; tests for immediate closure and zero reconcile work
- [ ] Measure a 512 KB append; log it

## Log

### 2026-09-27
- Filed from #281 (design decision A).

