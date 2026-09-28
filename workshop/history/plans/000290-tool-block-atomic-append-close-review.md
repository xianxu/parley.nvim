# Boundary Review — parley.nvim#290 (whole-issue close)

| field | value |
|-------|-------|
| issue | 290 — Write each tool block in one append during streaming; fold tool blocks and summaries as written |
| repo | parley.nvim |
| issue file | workshop/issues/000290-tool-block-atomic-append.md |
| boundary | whole-issue close |
| milestone | — |
| window | a26cd3bc4789183e8120c043fbf5d344f4ab5888..8075a0322d35751e33a44f57077453b509123c58 |
| command | sdlc close --issue 290 |
| reviewer | claude |
| timestamp | 2026-09-27T16:47:46-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The whole-block append works. A tool result over 4 KiB lands in one edit, and streamed prose is still sliced at 4096 bytes. Both are tested directly (`response_tools_spec.lua`), and the three places that enforced the old limit (runner, `D.append`, editor) are each raised only when the `block` flag is set. The summary fast path also works, including a prefix split across two writes. What blocks SHIP is the writer's tool-block fold: it does not fire in the most common case. When the model writes any prose before its first tool call, that call is not folded in its write turn. I confirmed this with a scratch copy of `writer_folds_spec.lua` (in `$TMPDIR`) that streams `output(first,'Let me check.')` before the tool call. It then emits one `written` fold instead of two, fails "one written fold per block", and only the result block gets folded. The shipped test passes because its answer has no prose, so the call's first byte lands on an empty row.

**Strengths**
- `generation_runner.lua:418-425`: the block path is simply `effect.type=='manual_append'`, which has one caller (`insert_tool`). Streamed prose (`write`) is untouched, and a regression test proves it (`still writes streamed prose in 4096-byte slices`).
- `document/init.lua:13-18`: `BLOCK_LIMIT` is set equal to the runner's 1 MiB staging ceiling, and the comment explains why. So the document can never refuse a block the runner already accepted.
- `tool_folds.fold_written` classifies rows from the tokens the append already put in the index (it respects the #254 rule against re-reading the buffer). It restores `foldenable` and the view using the same counter as the reconcile.
- The tests check against a settled parser oracle (`oracle()`) and the reconcile's `removed`/`created` counts, not against mocks. `record_edits` wraps the real editor driver's `set_text`, so it sees every edit exactly as the buffer does.
- The log records honestly that `nvim_buf_set_text` deletes a manual fold on the row it writes, and why that leads to re-folding the summary row on every write.

**Critical**
1. **`tool_folds.lua:460-464`: the first tool call of a round is not folded when prose comes before it.** `insert_tool` puts `'\n\n'` in front of call #1 (`response_tools.lua:146`). So the call's first byte lands at the end of the prose row, and `first_row` (`generation_runner.lua:403`) points at that prose row. The blank-trim loop only skips `blank` rows, so the anchor becomes the prose row's kind, not `tool_use`, and nothing is folded.
   - This breaks the Done-when clause "a streamed tool call … folded closed in the same turn as their write" in the default case: every tool round's first call whenever the model says something before calling a tool.
   - The family, all in this window:
     - (a) the anchor logic in `fold_written`'s append branch
     - (b) `first_row`, which counts the row the first byte lands on even when that is the end of a row already written
     - (c) `writer_folds_spec.lua`, whose only tool test has no prose before the call
     - (d) the atlas claim in `atlas/chat/document.md:139-142` ("folds … an appended tool block (marker to last non-blank row)")
   - Fix sketch: start the range at the first row that begins inside the write. For example, have the receipt carry the first byte's column (the plan's `from`), and skip `first_row` when that column is greater than 0. Alternatively, skip a leading row whose first written byte is `\n` and which lies before the block. Then add a test that streams prose before the call and asserts two `written` folds, each closed.

**Important**
1. **The Done-when section still promises behaviour the tests no longer check, and there is no `## Revisions` entry.** Two clauses were dropped:
   - "a `📝:` inside a fenced code block is folded by the writer and then removed by the reconcile"
   - "reshapes (not reopens) a multi-line one"

   The Log explains why: the parser folds a fenced `📝:` row, and it folds only a summary's marker row. The tests were changed to assert agreement with the parse instead. Per AGENTS §1, a mid-stream change to a plan artifact needs a `## Revisions` entry that updates those clauses. Otherwise `## Done when` and `## Spec` (the "Summaries too" bullets) contradict the code.

**Minor**
- The plan bullet says the receipt gains `from`, but the code and the Core concepts table say `first_row`. Fold this into the Revisions entry.
- `fold_written` repeats the pattern `setting_foldenable+1 / pcall(nvim_win_call) / restore_window / -1` that also appears at `tool_folds.lua:233-322`. A small `with_window(buf,win,fn)` helper in `fold_native` would remove the copy (ARCH-DRY, low cost).
- `fold_written` filters windows by `foldmethod=='manual'` alone. The reconcile also skips windows it has suspended (`foldenable` turned off during large uncertainty). A writer fold created in a suspended window is harmless, since `foldenable` is restored, but it is created during a phase the reconcile deliberately avoids.
- The `seen` high-water row goes stale if a human deletes lines above the answer while it streams. A later summary above the stale value is then skipped, and the reconcile fixes it. This is acceptable, but the comment's "Rows are monotonic" claim is only true for this generation's own writes.
- A 512 KiB write turn takes about 114–151 ms, which is a visible single-turn stall. It is recorded honestly; the follow-up (the per-byte lexer in `Append.prepare`) is worth filing.

**Test coverage notes**
- There is no tool test with prose before the call. This is the gap that let the Critical finding ship.
- There is no test of a second tool round (a continuation's first call), which has the same `'\n\n'` prefix.
- I checked a mid-document answer (with a later exchange after it) in a scratch copy: the tail range ends correctly on the closing fence. Adding it as a fixture would be cheap.

**Architectural notes**
- **ARCH-DRY: flag, Minor.** The window/foldenable wrapper is duplicated, as noted above. No other duplication in the diff.
- **ARCH-PURE: pass.** The range computation (trim, anchor, summary scan) is mixed with window IO inside `fold_written`. Splitting it into a pure `written_ranges(kinds, receipt, seen)` would let the Critical case be unit-tested without a real window. This is recommended but not required.
- **ARCH-PURPOSE: flag.** The issue's purpose is that a block is never shown open. The fast path delivers that only for tool rounds with no prose, which is the easy subset. See the Critical finding.

**Plan revision recommendations**
- Add `## Revisions`, dated 2026-09-27:
  - Done-when: replace "folded by the writer and then removed by the reconcile" with "agrees with the settled parse (the parser folds a fenced `📝:` row)".
  - Done-when: replace "reshapes (not reopens) a multi-line one" with "the parser folds only the marker row; the writer's one-row fold matches".
  - Spec: the receipt field is `first_row`, not `from`. If the fix adds a column, name it here.

```findings
findings:
  - id: new
    severity: Critical
    family: writer-fold-range-from-written-bytes
    title: |
      fold_written misses the first tool call of a round when prose precedes it
    detail: |
      insert_tool prefixes call 1 with two newlines (response_tools.lua:146), so the receipt's first_row (generation_runner.lua:403) is the prose row the first byte lands on. The append branch (tool_folds.lua:460-464) trims only blank rows, takes the prose row as the anchor and folds nothing. Reproduced: a scratch copy of writer_folds_spec that streams 'Let me check.' before the call emits 1 written fold instead of 2. Family: the anchor logic, the first_row semantics, the spec's missing prose-before-call case (and a second-round first call), and the atlas claim at atlas/chat/document.md:139-142. Fix: begin at the first row that starts inside the write (carry the first byte's column in the receipt and skip first_row when col>0), and add the test.
  - id: new
    severity: Important
    family: plan-revision-on-spec-divergence
    title: |
      Done-when and Spec still claim fenced-summary removal and multi-line reshape, with no Revisions entry
    detail: |
      The Log records that the parser folds a fenced summary row and only a summary's marker row, and the tests were changed to assert agreement with the parse. Done-when clauses 3-4 and the Spec's Summaries bullets still promise removal/reshape. Append a ## Revisions entry updating them, and record the receipt field name first_row (the plan says from).
  - id: new
    severity: Minor
    family: shared-window-fold-wrapper
    title: |
      fold_written duplicates the setting_foldenable / nvim_win_call / restore_window wrapper
    detail: |
      The same wrapper pattern is at tool_folds.lua:233-322 and in the new fold_written; a with_window helper in fold_native would consolidate it (ARCH-DRY).
  - id: new
    severity: Minor
    family: writer-fold-pure-core
    title: |
      fold_written's range computation is not separable from window IO
    detail: |
      Extracting a pure written_ranges(kind, receipt, seen) would let the prose-before-call and split-prefix cases be unit-tested without a real window (ARCH-PURE).
```

---

## Re-review — 2026-09-27T16:53:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 290 — Write each tool block in one append during streaming; fold tool blocks and summaries as written |
| repo | parley.nvim |
| issue file | workshop/issues/000290-tool-block-atomic-append.md |
| boundary | whole-issue close |
| milestone | — |
| window | a26cd3bc4789183e8120c043fbf5d344f4ab5888..3e1560e54a2c26e542d60d99b41d1a09955efcc5 |
| command | sdlc close --issue 290 |
| reviewer | claude |
| timestamp | 2026-09-27T16:53:25-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

Both blocking findings from round 1 are fixed and I checked each one myself rather than relying on the commit messages. For BR-1, the append branch of `written_ranges` now skips the first row when `first_col>0` (`lua/parley/tool_folds.lua:455`), and the integration test "folds the first call of each round when prose precedes it" covers the first call of two consecutive rounds. I extracted HEAD into a scratch copy and removed that one line: the test **fails**. With the fix in place, all 5 integration cases and all 8 unit cases pass. For BR-2, a dated `## Revisions` entry now records the parser-driven changes to the Spec, Done-when and Plan, and Done-when itself has been restated. BR-4 is fixed: the range logic is now the pure `written_ranges`, unit-tested without a window. BR-3 is still open. It is Minor and doesn't block. What remains is one new Minor: a hardcoded constant that repeats a value defined elsewhere.

**1. Strengths**
- **Separating pure logic from window IO (ARCH-PURE):** `written_ranges(receipt, seen, kind)` is pure and gets its row kinds through an injected function. `tests/unit/tool_folds_spec.lua:48-81` covers:
  - prose before the call;
  - a column the index can't place yet;
  - an appended row that isn't a tool marker;
  - a summary prefix split across writes;
  - the high-water row.
- **The fast path isn't the authority:** the tests check the result against the settled parser (the `oracle()` helper), and after settling the reconcile removes and creates nothing (`removed==0`/`created==0`). The fold the writer makes is exactly the fold the parser wants.
- **Folds are observed in the write's own turn:** the `_observer` in `writer_folds_spec` reads the folds inside the `written` event, before any repair step can run. That really proves "closed in the same turn".
- **Size limits are lifted only for `block` appends,** in all three places that enforce them (runner, `D.append`, editor). Prose keeps its 4096-byte slices and 255-row limit (`document/init.lua:579-585`).
- **A wrong spec assumption was caught by testing it** (writing into a row deletes a manual fold) and recorded in the Log and `workshop/lessons.md`.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **Duplicated constant (ARCH-DRY):** `D.BLOCK_LIMIT=1048576` (`lua/parley/document/init.lua:18`) repeats the runner's staging ceiling, which is a separate literal at `lua/parley/generation.lua:242-243`. The comment says the two are the same limit, but nothing keeps them in sync. Fix: define the value once (for example, export it from `generation` or make `generation` use `D.BLOCK_LIMIT`).
- **Duplicated window wrapper (BR-3, carried over):** `fold_written` still repeats the foldenable-counter / `nvim_win_call` / `restore_window` wrapper.

**5. Test coverage notes**
- The integration tests cover:
  - a block over 4 KiB landing whole (both fences in one write);
  - prose before the first call in two rounds;
  - a summary prefix split across writes;
  - a summary folded again while its row keeps streaming;
  - a summary followed by more text;
  - a `📝:` inside a code fence.
- There is no case for a `manual_append` the document accepts only partly, which would take the path where `first_col` is `nil`. The unit test covers the `nil` column itself, so this is acceptable.

**6. Architectural notes**
- **ARCH-DRY:** flag (Minor), for the duplicated constant and BR-3 above.
- **ARCH-PURE:** pass.
- **ARCH-PURPOSE:** pass. Every Done-when clause is delivered, including the revised ones, and the Revisions entry explains the parts the parser made unnecessary.
- **ARCH-MOCK:** pass. The tests run against the stateful `respond_fixture` transport.
- **ARCH-CONSTRAINTS:** pass. The bound is written down, and the Log records timings: about 114–151 ms for one 512 KiB write, and about 25–30 ms at the 100 KiB default. The per-byte lexer is noted as a follow-up.
- **ARCH-SECURE:** not applicable; the change handles no untrusted input or secrets beyond what the existing size limits already cover.
- **ARCH-ORDER:** pass. The only state is the `summary_row` high-water mark, which lives in the generation's closure and only moves forward. The reconcile corrects any disagreement.
- **ARCH-FUNERAL:** pass. The change leaves nothing durable behind; native folds are display state that the reconcile owns.

**7. Plan revision recommendations**
- None required, since the Revisions entry covers the differences. As a cosmetic fix, the ticked Plan row still says "multi-line reshape … folded then removed" and could point to the Revisions entry.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      first_col skip at tool_folds.lua:455; e2e two-round test goes red when the line is reverted in a scratch copy
  - id: BR-2
    disposition: addressed
    note: |
      Revisions entry dated 2026-09-27 records the Spec, Done-when and Plan changes, including first_row/first_col; Done-when restated
  - id: BR-3
    disposition: not-addressed
    note: |
      wrapper still duplicated in fold_written; implementer deferred it because the other copy is #264's reconcile apply; Minor, non-blocking
  - id: BR-4
    disposition: addressed
    note: |
      pure written_ranges extracted and unit-tested in tests/unit/tool_folds_spec.lua
findings:
  - id: new
    severity: Minor
    family: single-source-limit-constants
    title: |
      BLOCK_LIMIT restates the runner staging ceiling as a separate 1048576 literal
    detail: |
      document/init.lua:18 hardcodes 1048576 and says it is generation.lua:242-243's staged_bytes limit; nothing ties the two, so changing one silently breaks the claim that a block the runner admitted is never refused. Define the value in one place and derive the other from it.
```
