# Correct Incremental Parley Folds Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep auxiliary answer entities folded during streaming by parsing only the live response segment and updating its exchange-model blocks.

**Architecture:** One pure answer-structure reducer owns semantic section grammar for both saved-chat parsing and streaming. Initial loading reduces the whole transcript once; an ordinary stream write reduces only the current insertion block, while a late explicit terminator reduces only its recorded provisional opener-through-terminator span. Because Neovim invalidates a manual fold's range when its streaming tail is replaced, the thin UI shell recreates only the changed foldable range after that write and never touches folds outside it.

**Tech Stack:** Lua, Neovim buffer/manual-fold APIs, Plenary/Busted.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `AnswerStructure` reducer | `lua/parley/answer_structure.lua` | new |
| Semantic answer section | `lua/parley/chat_parser.lua` | modified |
| Exchange replacement span | `lua/parley/exchange_model.lua` | modified |

- **`AnswerStructure` reducer** — maps an ordered answer-line slice to exact
  `text`, `thinking`, `summary`, `tool_use`, and `tool_result` spans.
  - **Relationships:** one answer/response leg owns 1:N ordered sections; both
    `chat_parser` and streaming invoke the same reducer (`ARCH-DRY`).
  - **Contract:** `reduce(lines, patterns, opts) -> {sections, work}`; sections
    carry kind and slice-relative inclusive spans, and `work.rows_visited` must
    be bounded by `#lines`. `opts.streaming=true` treats a blank after `🧠:` as
    a provisional legacy boundary until a later `🧠:[END]` in this same slice
    supplies lookahead; on that later reduction the reducer widens/reclassifies
    exactly the recorded provisional opener-through-insertion span. This
    bounded reconciliation is unavoidable
    because the legacy grammar is future-dependent; it prefers temporarily
    showing text over incorrectly hiding a legacy final answer.
  - **Future extensions:** new semantic answer entities widen this one reducer.
- **Semantic answer section** — one reducer span plus parsed payload metadata.
  - **Relationships:** the parser enriches reducer spans 1:1 with text/tool
    payloads while retaining existing flat answer/reasoning/summary fields.
  - **DRY rationale:** folding no longer owns marker grammar.
  - **Future extensions:** payload parsers remain per kind.
- **Exchange replacement span** — normally the one insertion block; only a late
  `🧠:[END]` widens it to the recorded provisional thinking opener through the
  terminator-containing insertion block.
  - **Relationships:** one live response owns one insertion block and at most
    one provisional opener; no earlier block is readable or replaceable.
  - **DRY rationale:** model positions remain the only fold ranges.
  - **Future extensions:** per-leg presentation metadata can live here.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Insertion write event | `lua/parley/dispatcher.lua` | modified | streamed buffer writes |
| Insertion-span reconciler | `lua/parley/chat_respond.lua` | modified | bounded buffer reads |
| Active fold refresher | `lua/parley/tool_folds.lua` | modified | Neovim manual folds |
| Live tool-loop state | `lua/parley/tool_loop.lua` | modified | cancellation repair |

- **Insertion write event** reports the current last row, completed-line delta,
  and tail replacement after every write. Existing
  delta-only consumers remain compatible.
- **Insertion-span reconciler** normally reads exactly
  `[model:block_start(active), last_written]`. If that slice contains a late
  `🧠:[END]`, it reads exactly `[model:block_start(provisional_opener),
  last_written]`. It invokes `AnswerStructure`, replaces only that span, and
  offers changed/new foldable blocks to the fold shell (`ARCH-PURE`,
  `ARCH-PURPOSE`).
- **Active fold refresher** recreates the one changed foldable model range after
  Neovim's tail replacement has shrunk its old manual fold. It never issues
  `zE`, `zd`, or `zD`, and it is never called for non-foldable blocks. Folds
  outside the rewritten range—including unrelated user folds—remain untouched;
  folds overlapping the rewritten range cannot survive the Neovim write itself.
- **Live tool-loop state** retains the model and active exchange while a tool
  round is pending, allowing cancellation repair to inspect live blocks and
  read only an unmatched tool block rather than reparsing the chat.

## Streaming invariant table

| Event | Model before → after | Buffer range read | Fold action | Whole-chat parses |
|------|-----------------------|-------------------|-------------|-------------------|
| plain tail replacement | insertion block → same kind/new size | insertion block only | none for `text`; recreate active fold for foldable kind | 0 |
| completed marker line | insertion block → reducer sections | insertion block only | create changed foldable ranges | 0 |
| `🧠:[END]` after provisional blank | provisional span → widened thinking + following sections | recorded opener through insertion block | recreate changed thinking fold | 0 |
| tool call/result append | append known model block | rendered block only | fold new known block immediately | 0 |
| success/failure/cancel | finalize or remove empty insertion block | insertion block, provisional span, or unmatched tool block only | recreate final changed fold; delete nothing | 0 |
| initial buffer setup | parsed transcript → complete model | whole transcript once | create every foldable model range | 1 |

## Chunk 1: Feasibility and canonical semantic structure

### Task 1: Pin Neovim tail-replacement fold behavior

**Files:**
- Create: `tests/integration/tool_folds_spec.lua`
- Modify: `lua/parley/tool_folds.lua`

- [x] **Step 1: Write failing integration tests for the active-fold API**

Require `_apply_block_fold(buf, win, model, exchange_index, block_index)` and
pin the observed Neovim fact that replacing a folded streaming tail shrinks
that fold. Then assert calling the API after the write recreates the exact grown
model range, non-foldable kinds invoke no `:fold` command, and user folds wholly
outside the rewritten range survive byte-for-byte fold queries.

- [x] **Step 2: Run the exact spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`

Expected: FAIL because `_apply_block_fold` does not exist.

- [x] **Step 3: Implement the minimum active-fold refresher**

Create the exact model range inside `nvim_win_call`; never clear/delete a fold
and return before Neovim mutation for non-foldable kinds. Invoke this API only
after a foldable write has invalidated the previous active fold, or once for a
new completed/initial block, so duplicate nesting is not introduced.

- [x] **Step 4: Re-run the exact spec and verify GREEN**

Expected: PASS for observed fold invalidation, exact active-range recreation,
non-foldable no-op, and unrelated user-fold preservation.

### Task 2: Extract one shared answer-structure reducer

**Files:**
- Create: `lua/parley/answer_structure.lua`
- Create: `tests/unit/answer_structure_spec.lua`
- Modify: `lua/parley/chat_parser.lua`
- Modify: `tests/unit/parse_chat_spec.lua`
- Modify: `lua/parley/exchange_model.lua`
- Modify: `tests/unit/exchange_model_spec.lua`

- [x] **Step 1: Write reducer RED tests**

Assert exact kinds/spans for plain text, legacy thinking, explicit thinking with
blank paragraphs, summaries, tool fences, marker-like prose, multiple rounds,
and an explicit terminator arriving after a provisional blank. Assert
`work.rows_visited <= #lines` and no Neovim API use.

- [x] **Step 2: Run the exact reducer spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/answer_structure_spec.lua" -c "qa!"`

Expected: FAIL because `parley.answer_structure` does not exist.

- [x] **Step 3: Implement the pure reducer using canonical classification**

Use `highlight_structure.classify` plus one state machine for text, reasoning
mode/lookahead, summary, and fenced tool spans. Keep trimming and termination in
this module; callers must not reproduce them.

- [x] **Step 4: Write parser/model RED assertions**

Assert `answer.sections` and `from_parsed_chat` expose ordered first-class
`thinking` and `summary` blocks with exact buffer positions while legacy flat
fields and tool payloads remain unchanged.

- [x] **Step 5: Run parser/model specs and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/parse_chat_spec.lua" -c "qa!"`

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/exchange_model_spec.lua" -c "qa!"`

Expected: named first-class-kind assertions FAIL against absorbed `text` blocks.

- [x] **Step 6: Route parser section construction through the reducer**

Enrich reducer spans with existing tool deserialization and compatibility
fields. Map all reducer sections generically into model blocks. Delete parallel
reasoning/summary section-boundary logic only after parity tests cover it.

- [x] **Step 7: Run all three exact specs and verify GREEN**

Run the explicit reducer command from Step 2 and both explicit commands from
Step 5.

Expected: PASS with one grammar owner and exact parser/model positions.

- [x] **Step 8: Commit Chunk 1**

Commit the verified feasibility, reducer, parser, and model changes with a
`#193:` subject and model co-author trailer.

## Chunk 2: Bounded streaming and tool lifecycle

### Task 3: Replace only the insertion span after each write

**Files:**
- Modify: `lua/parley/exchange_model.lua`
- Modify: `tests/unit/exchange_model_spec.lua`
- Modify: `lua/parley/dispatcher.lua`
- Modify: `tests/integration/create_handler_spec.lua`
- Modify: `lua/parley/chat_respond.lua`
- Modify: `tests/integration/chat_respond_spec.lua`

- [x] **Step 1: Write model-span replacement RED tests**

Define `replace_span(exchange_index, first_block, old_count, sections)` and
assert it preserves every block outside the requested insertion/provisional
span, maintains exact total size/positions, rejects invalid indices/sizes, and
returns changed block indices.

- [x] **Step 2: Run exact model spec and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/exchange_model_spec.lua" -c "qa!"`

Expected: FAIL in the named insertion-span isolation/validation cases because
`replace_span` does not exist.

- [x] **Step 3: Implement minimal pure span replacement**

Preserve earlier blocks and return only new/changed indices for fold dispatch.

- [x] **Step 4: Write dispatcher/respond RED tests**

Assert `after_write` reports the last row even when a chunk only replaces the
unfinished tail (`delta == 0`) and when a marker is split across chunks. In a
real response, instrument `nvim_buf_get_lines` and `chat_parser.parse_chat`:
ordinary writes begin exactly at the insertion block start; a late terminator
begins exactly at the recorded provisional opener; neither reads an earlier
line; all call `parse_chat` zero times. Non-foldable text causes zero fold calls,
while each foldable write recreates exactly its changed model range.

- [x] **Step 5: Run exact integration specs and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/create_handler_spec.lua" -c "qa!"`

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua" -c "qa!"`

Expected: callback-shape and zero-parse assertions FAIL.

- [x] **Step 6: Expose write bounds and reconcile the insertion span**

Extend `after_write` compatibly. In `chat_respond`, derive the normal read start
from the current insertion block; record a provisional thinking opener when a
blank splits it; widen the start only when the insertion slice contains a late
terminator. Reduce and replace that exact span, call `_apply_block_fold` only
for returned foldable indices, and remove final whole-buffer `apply_folds`.

- [x] **Step 7: Run exact model/dispatcher/respond specs and verify GREEN**

Run the three explicit commands from Steps 2 and 5.

Expected: PASS in named `delta == 0`, split-marker, insertion-only read,
provisional-span read, no-earlier-line, and zero-streaming-parse cases.

### Task 4: Fold tool blocks immediately and remove cancellation reparsing

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Modify: `tests/integration/chat_respond_spec.lua`
- Modify: `tests/unit/tool_loop_spec.lua`

- [x] **Step 1: Write terminal/tool RED tests**

Cover transport failure before content, cancellation with unmatched tool use,
failure during a recursive leg, empty output after completed tool blocks, and
normal multi-round completion. Assert each `_append_section_to_answer` folds its
known `tool_use`/`tool_result` index immediately; cancellation reads only the
unmatched block via the registered live model; completed folds and user folds
wholly outside the actively rewritten range survive; and `parse_chat` is never
called.

- [x] **Step 2: Run exact tool/respond specs and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/tool_loop_spec.lua" -c "qa!"`

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/chat_respond_spec.lua" -c "qa!"`

Expected: immediate-fold and zero-cancellation-parse assertions FAIL.

- [x] **Step 3: Register live tool-loop model state**

Extend `state_by_buf` with model/exchange ownership while preserving iteration
state. Repair unmatched tools from live blocks and bounded block reads; reset
all state on terminal completion.

- [x] **Step 4: Fold each rendered tool block at append time**

After `_append_section_to_answer` obtains the new block index, call the
incremental fold API directly. Remove `close_tool_folds` and its whole-document
reconstruction.

- [x] **Step 5: Route every terminal shape through one leg finalizer**

Finalize non-empty semantic sections, remove empty transient model blocks, and
recreate only the final changed foldable range. Do not parse the document or
touch unrelated folds.

- [x] **Step 6: Assert final-state parity**

For plain, explicit/legacy thinking, structured, and multi-round tool
transcripts, compare the incremental model kinds/sizes and desired fold ranges
to `parse_chat → from_parsed_chat` on a fresh buffer after completion.

- [x] **Step 7: Run exact tool/respond specs and verify GREEN**

Run the two explicit commands from Step 2.

Expected: PASS in named pre-content failure, unmatched-tool cancellation,
recursive failure, empty-after-tools, normal multi-round, and fresh-load exact
fold parity cases.

- [x] **Step 8: Commit Chunk 2**

Commit the verified bounded streaming, incremental folds, and cancellation
changes with a `#193:` subject and model co-author trailer.

## Chunk 3: Initial loading, documentation, and verification

### Task 5: Make initial folds model-only and non-destructive

**Files:**
- Modify: `lua/parley/tool_folds.lua`
- Modify: `tests/integration/tool_folds_spec.lua`
- Modify: `tests/unit/tool_folds_spec.lua`

- [x] **Step 1: Write initial-load RED tests**

Spy on parsing and assert setup performs exactly one whole-document parse,
enumerates only model blocks, folds exactly thinking/summary/tool-use/tool-result,
does not call the deleted raw-marker scanner, and preserves pre-existing user
folds outside those model ranges without `zE`/`zd`/`zD`.

- [x] **Step 2: Run exact fold specs and verify RED**

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/tool_folds_spec.lua" -c "qa!"`

Run:
`nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/tool_folds_spec.lua" -c "qa!"`

Expected: model-only/non-destructive assertions FAIL against current `zE` and
marker scanning.

- [x] **Step 3: Implement one-parse model enumeration**

Build the model once and create every foldable model range through the same
thin fold API.
Delete `STRUCTURAL_TERMINATORS`, `compute_marker_ranges`, compatibility aliases,
and `close_tool_folds`. Keep non-foldable enumeration free of fold commands.

- [x] **Step 4: Run exact fold specs and verify GREEN**

Run the two explicit commands from Step 2.

Expected: PASS in named one-initial-parse, exact-foldable-kind, no-raw-scanner,
and unrelated user-fold preservation cases.

### Task 6: Reconcile atlas, performance, and repository gates

**Files:**
- Modify: `atlas/chat/exchange_model.md`
- Modify: `atlas/chat/parsing.md`
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000193-parley-fold-sometimes-at-wrong-place.md`

- [x] **Step 1: Update atlas and traceability before mapped tests**

Document the canonical reducer, provisional legacy reasoning rule, ordinary
insertion-block read, exceptional recorded provisional-span read, active-fold
recreation, tool/cancellation state, terminal parity, and exact foldable
kinds. Map `answer_structure`, `tool_folds`, dispatcher,
respond, tool-loop, and every new test under `chat/parsing`,
`chat/exchange_model`, and `chat/lifecycle` as appropriate.

- [x] **Step 2: Run focused mapped verification**

Run: `make test-spec SPEC=chat/parsing`

Run: `make test-spec SPEC=chat/exchange_model`

Run: `make test-spec SPEC=chat/lifecycle`

Expected: every mapped file runs and all pass.

- [x] **Step 3: Add and run integrated streaming bounded-work verification**

Extend `tests/integration/perf_chat_typing_spec.lua` and the `make perf` report
with a streaming response-leg scenario at 100, 1,000, and 5,000 document lines.
Record `lines_requested`, `full_buffer_reads`, and insertion/provisional rows
processed. Ordinary scenarios keep insertion size fixed while completed earlier
response blocks and total document size grow; assert constant work. Separate
late-terminator scenarios assert work is proportional only to the fixed
provisional opener-to-terminator span, independent of earlier history.

Run: `make perf`

Expected: exit 0; new streaming scenarios report zero full-buffer reads,
constant insertion work as history grows, and provisional work bounded only by
the opener-to-terminator span; existing typing scenarios remain valid.

- [x] **Step 4: Run full repository verification**

Run: `make test`

Run: `make test-changed`

Run: `git diff --check`

Expected: exit 0 with no failures or warnings (`make test` includes lint).

- [x] **Step 5: Reconcile the issue contract**

Match every Done-when row to an assertion, tick every issue/plan checkbox, and
append exact commands and observed results to `## Log`.

- [x] **Step 6: Commit Chunk 3**

Commit atlas, traceability, verification evidence, and completed plan state with
a `#193:` subject and model co-author trailer.

## Revisions

### 2026-07-17 — initial approved design plan

Translated the approved incremental-fold design into TDD tasks around a pure
incremental tracker and thin fold shell.

### 2026-07-17 — plan review feasibility correction

Replaced the underspecified chunk tracker with one shared response-slice reducer;
made future-dependent thinking grammar a bounded provisional reconciliation;
specified dispatcher tail replacement, active-leg replacement, append-only fold
ownership, immediate tool folding, live-model cancellation repair, terminal
parity, exact test commands, performance verification, and per-chunk commits.

### 2026-07-17 — second review precision pass

Spelled out every previously indirect Plenary command and named terminal cases;
replaced the unrelated typing-only performance claim with a real streaming
scenario at three document sizes; aligned parity with observable outer folds.

### 2026-07-17 — insertion-span bound correction

Tightened ordinary streaming from active-leg rescans to insertion-block-only
reads/replacements. Kept the sole bounded exception for a late explicit
terminator, starting exactly at its recorded provisional opener, and changed
performance assertions to hold insertion size constant while history grows.

### 2026-07-17 — manual-fold feasibility revision

The first real Neovim test showed that streaming tail replacement shrinks its
containing manual fold. With operator approval, replaced append-only growth and
overlap preservation with exact active-range recreation after foldable writes;
folds wholly outside the rewritten range remain untouched.

### 2026-07-17 — bounded-work verification refinement

Superseded Task 6 Step 3's proposed typing-perf extension with a production
streaming integration probe. The probe grows completed transcript history to
1,000 rows, rejects any streaming `parse_chat` call, and observes exactly the
two-row insertion tail on both writes. This measures the response path directly
without coupling it to the unrelated interactive typing benchmark; the full
performance suite still runs through `make test`.
