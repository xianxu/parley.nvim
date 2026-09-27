---
id: 000290
status: working
deps: [000264]
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: '682ed7ad110ba323ef797dfc4f705b6609e7ad6c' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-27T15:41:00-07:00
flow: {kind: quick, provenance: inferred, spec: "0f28dc1a", done: "721b50ab"}
---

# Write each tool block in one append during streaming; fold tool blocks and summaries as written

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
- **Summaries too (operator, 2026-09-27).** A streamed `📝:` summary likewise shows
  unfolded until the answer completes and repair runs (observed on `welcome.md`). Unlike a
  tool block, the summary is the model's own streamed prose, so the text writer detects it:
  when a write leaves the answer's current tail line **starting** with the configured
  `summary_prefix` (`config.lua:606`, `📝:`) at column 0, it folds that line in the same
  turn, before the rest of the summary text arrives. With `foldminlines=0` a one-line fold
  shows closed, and text appended to a line inside a fold keeps it folded, so the summary
  stays folded while it's written.
  - Check at line level, not per chunk: the prefix can be split across writes (`📝` then
    `:`). Fold once the tail line starts with the full prefix, and only once per line.
  - A summary can continue onto later lines (the parser extends it to the next `💬:`).
    The writer folds only the prefix line; #264's reconcile grows the fold to the
    projection's extent, reshaping it in one turn (no blink).
  - Scope: only lines the stream writer itself writes inside an answer. A `📝:` typed by a
    human is left to repair as today. A `📝:` the model writes inside a code block would
    be folded by mistake; the reconcile removes it once the parse is confirmed (the
    parse stays the authority).
  - Thinking blocks (`🧠:`) are out of scope: the default prompt no longer asks for them.

## Done when

- A result over 4 KB reaches the buffer in one write: a test observes one
  document edit carrying both the opening and closing fence.
- A streamed tool call and result are folded closed in the same turn as their write:
  probing `foldclosed` right after the write (before any fold repair step) reads closed;
  and after settling, #264's reconcile reports `removed==0`/`created==0` for them (the
  writer's fold matched the projection exactly).
- A streamed summary is folded closed from the turn its `📝:` prefix lands (probe
  `foldclosed` on that row after the write, before any repair step), including when the
  prefix arrives split across two writes, and stays closed while the rest of the line
  streams. After settling, the reconcile reports `removed==0` for a one-line summary and
  reshapes (not reopens) a multi-line one.
- A `📝:` inside a fenced code block in the answer is folded by the writer and then
  removed by the reconcile (the settled oracle has no fold there).
- Streamed prose still writes in 4096-byte slices (regression test).
- A timing of a 512 KB result append is recorded in the Log.
- Existing streaming, stop-generation and tool-fold suites stay green.

## Plan

Design notes (from reading the write path):
- The 4096-byte slice is enforced in three places, not one: the runner
  (`generation_runner.lua` `write`), `D.append` (`document/init.lua`: >4096 bytes or >255
  newlines is refused) and the editor (`document/editor.lua`: a patch >64 KiB is
  `chunkneeded`). A tool block needs all three to allow one bounded whole-block append.
  `ctx.append` (effect `manual_append`) has one user, `response_tools.insert_tool`, so
  `manual_append` *is* the block-append effect: the runner passes `block=true` and the
  whole blob; streamed prose (`write`) keeps its 4096-byte slices.
- Bound (ARCH-CONSTRAINTS): a block append is at most `D.BLOCK_LIMIT` = 1 MiB, the runner's
  staging ceiling (`generation.lua` `staged_bytes`), which already bounds every blob; in
  practice the call cap (64 KiB) and the result budget (≤512 KiB + header/fences) bound it.
  The row limit does not apply to a block; its bytes bound its rows.
- `Append.prepare` lexes each line with a 4096-byte budget; a longer line (a one-line JSON
  result) would be mis-lexed, so a line is lexed whole.
- Writer folds use the runner's existing `written` receipt, which gains `from` (the
  position of the first written byte). `chat_respond`'s `written` hook calls
  `tool_folds.fold_written(buf, receipt, state)`:
  - `append` receipt: the first non-blank written row, if it classifies as
    `tool_use`/`tool_result` (the parser's own line classifier), through the last non-blank
    written row — the projection's trim rule.
  - `output` receipt: each written row after the last folded row whose line classifies as
    `summary` (one-row fold; a split prefix is caught when the row is rechecked on the next
    write). Rows are monotonic, so "once per line" is a high-water row, not a set.
  - Created only in windows with `foldmethod=manual` where neither end row is already
    folded; `foldenable` is set for the `:fold` and restored (same guard counter as the
    reconcile), so the operator's setting is untouched.
- Creates nothing durable (ARCH-FUNERAL): native folds are presentation, reconciled by
  #264; the high-water row lives in the generation's closure.

- [ ] `manual_append` writes the whole block: runner, `D.append` (`block` intent, 1 MiB),
      editor patch limit per plan, whole-line lexing in `Append.prepare`
- [ ] Tests: one edit carries both fences for a >4 KiB result; prose still sliced at 4096;
      rewrite the "multi-slice result" response_tools test to "never partial"
- [ ] `written` receipt gains `from`; `tool_folds.fold_written`; wired in `chat_respond`
- [ ] E2E (chat_respond + fixture provider, real window): tool call/result closed at the
      write, before any reconcile; settled reconcile `removed==0`/`created==0`
- [ ] Summary folding: split prefix, stays closed while streaming, multi-line reshape,
      `📝:` inside a code fence folded then removed
- [ ] Measure a 512 KiB append on a large chat; log it
- [ ] Existing streaming, stop-generation and tool-fold suites green (`make test`)

## Log

### 2026-09-27
- Filed from #281 (design decision A).
- 2026-09-27: scope extended to streamed summaries (operator); `🧠:` excluded, since the
  default prompt no longer requests thinking blocks.

