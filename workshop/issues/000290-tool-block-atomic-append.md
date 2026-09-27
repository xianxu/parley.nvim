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
- A streamed tool call is folded in the write turn even when prose precedes it, for the
  first call of every round (revised 2026-09-27, BR-1).
- A streamed summary is folded closed from the turn its `📝:` prefix lands (probe
  `foldclosed` on that row after the write, before any repair step), including when the
  prefix arrives split across two writes, and stays closed while the rest of the line
  streams. After settling, the writer's summary folds equal the parser oracle's and the
  reconcile removes and creates nothing (revised 2026-09-27: the parser folds only the
  marker row, and folds a `📝:` row inside a code fence too; see Revisions).
- Streamed prose still writes in 4096-byte slices (regression test).
- A timing of a 512 KB result append is recorded in the Log.
- Existing streaming, stop-generation and tool-fold suites stay green.

## Core concepts

| Entity | Status | Where | Role |
|---|---|---|---|
| `BLOCK_LIMIT` | new | `document/init.lua` | ceiling of a whole-block append (1 MiB, the runner's staging limit) |
| `block` | new | `D.append` intent | a tool block written in one edit; lifts the 4096-byte/255-row slice limits |
| `first_row` | new | runner `written` receipt | the row an appended write's first byte landed on |
| `first_col` | new | runner `written` receipt | that byte's column: 0 means the write began the row, more means it continued one |
| `written_ranges` | new | `tool_folds.lua` | pure: the rows a written receipt should fold, from each row's lexed kind |
| `fold_written` | new | `tool_folds.lua` | writer fast path: folds a written tool block / summary row in the write's turn |

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

- [x] `manual_append` writes the whole block: runner, `D.append` (`block` intent, 1 MiB),
      editor patch limit per plan, whole-line lexing in `Append.prepare`
- [x] Tests: one edit carries both fences for a >4 KiB result; prose still sliced at 4096;
      rewrite the "multi-slice result" response_tools test to "never partial"
- [x] `written` receipt gains `from`; `tool_folds.fold_written`; wired in `chat_respond`
- [x] E2E (chat_respond + fixture provider, real window): tool call/result closed at the
      write, before any reconcile; settled reconcile `removed==0`/`created==0`
- [x] Summary folding: split prefix, stays closed while streaming, multi-line reshape,
      `📝:` inside a code fence folded then removed
- [x] Measure a 512 KiB append on a large chat; log it
- [x] Existing streaming, stop-generation and tool-fold suites green (24 files in isolation; `make test` failures are environmental, see Log)

## Revisions

### 2026-09-27 — close review round 1 (BR-1, BR-2)
- **Reason:** the parser, the authority, disagrees with two Spec predictions (see Log), and
  the close review found the writer missed a round's first call after prose.
- **Delta, Spec (Summaries):** "A summary can continue onto later lines … the reconcile
  grows the fold" is replaced by: the parser folds only a summary's marker row, so the
  writer's one-row fold is already exact. "A `📝:` the model writes inside a code block
  would be folded by mistake; the reconcile removes it" is replaced by: the parser also
  folds that row, so writer and parse agree and nothing is removed. "Text appended to a
  line inside a fold keeps it folded" is wrong: appending deletes the fold, so the writer
  re-folds the row it is still streaming, in the same turn.
- **Delta, Done when:** clause 3's "reshapes (not reopens) a multi-line one" and clause 4
  ("folded by the writer and then removed by the reconcile") are replaced by: after
  settling, the writer's summary folds equal the parser oracle's and the reconcile removes
  and creates nothing.
- **Delta, Plan:** the receipt field is `first_row` plus `first_col` (the plan said
  `from`). An appended block counts its first row only when the write began it
  (`first_col` 0): a round's first call continues the answer's prose row (BR-1). The range
  computation is the pure `written_ranges`.

## Log

### 2026-09-27
- Filed from #281 (design decision A).
- 2026-09-27: scope extended to streamed summaries (operator); `🧠:` excluded, since the
  default prompt no longer requests thinking blocks.
- 2026-09-27: the slice was enforced in three places (runner, `D.append` 4096 B/255
  newlines, editor 64 KiB patch), plus the runner's `slice` 255-row cap; `Append.prepare`
  lexed each line with a 4096-byte budget (a longer line would mis-lex). All lifted for
  `block` appends only.
- 2026-09-27: **spec premise corrected.** `nvim_buf_set_text` into a row inside a manual
  fold deletes that fold (probed in headless nvim: foldlevel 1 → 0 after a same-line
  append). So a streamed summary row is re-folded by the writer on every write that
  continues it, in the same turn — never visible open.
- 2026-09-27: the parser folds only a summary's marker row (the following line is answer
  text), and also folds a `📝:` row inside a code fence; the writer agrees in both, so the
  reconcile has nothing to reshape or remove. Tests assert agreement with the settled
  parse (oracle) rather than the spec's predicted reshape/removal.
- 2026-09-27: arch guard #254 bars raw buffer reads in `tool_folds`; `fold_written`
  classifies rows from the tokens `Append.prepare` already put in the index (opaque rows
  get no fast fold).
- 2026-09-27: **timing** (headless, `tests/minimal_init.vim`, 512 KiB result = 6553 rows,
  one block): the write turn is one ~114 ms step on a 483-row chat and ~151 ms on a
  2403-row chat (sliced baseline: max step ~25 ms). Time until the block is written and
  repair is idle: 10.5 s whole vs 16.7 s sliced (483-row chat) — whole is faster overall;
  the ~10–14 s document repair of 6.5k new rows is pre-existing and runs in scheduled
  slices (max repair step ~22–26 ms). At the 100 KiB default the write turn scales to
  ~25–30 ms. Follow-up candidate: the per-byte Lua lexer in `Append.prepare` dominates
  the write turn.
- 2026-09-27: verification. 24 streaming/stop/fold/response/generation spec files green
  in isolation. `make test` failures are environmental: (a) `single_source_sweeps` names
  #264's exports because local `main` is 51 commits behind `origin/main` (against the
  `origin/main` branch point the added exports are `BLOCK_LIMIT` and `fold_written`, both
  tabled); (b) one random spec per run dies at plenary's 50 s deadline under 8-way load
  (`highlight_typing`, `response_tools`: 5–10 s alone). The base commit a26cd3bc shows the
  same thing (`document_semantic_spec`).
- 2026-09-27: close review round 1 → REWORK. BR-1 (Critical): with prose before a round's
  first call, the append began mid-row and the anchor was the prose row, so no fold. Fixed
  via `first_col`; e2e test covers the first call of two consecutive rounds after prose
  (red without the fix), with unit cases for `written_ranges`. BR-2: Revisions entry above.
  Minor (pure core): done, `written_ranges`. Minor (shared window wrapper): not done here;
  the duplicate lives in #264's reconcile `apply`, and merging them means restructuring that
  code, which would be a separate change.

