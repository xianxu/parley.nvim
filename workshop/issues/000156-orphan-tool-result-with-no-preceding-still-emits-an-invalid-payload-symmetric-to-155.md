---
id: 000156
status: done
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.58
started: 2026-07-01T11:28:08-07:00
actual_hours: 0.26
---

# orphan tool_result (📎: with no preceding 🔧:) still emits an invalid payload — symmetric to #155

## Problem

#155 closed one half of the tool_use↔tool_result invariant: a dangling **tool_use**
(🔧: with no 📎:) now gets a synthesized `is_error` result at message-emission, so
the payload never carries an assistant `tool_use` without a matching user
`tool_result`. The **symmetric** case is still open: an **orphan tool_result** (a
📎: with no preceding 🔧:) is appended to the payload verbatim
(`_emit_content_blocks_as_messages` — the `tool_result` branch adds it to a user
message unconditionally, `resolve_pending` just no-ops when the id isn't pending).
Anthropic rejects a user `tool_result` whose `tool_use_id` has no matching
assistant `tool_use` in the preceding assistant turn → the same HTTP 400 class of
failure, from the other direction.

Pre-existing (the old emitter behaved identically) and surfaced as a minor finding
in #155's close review. How an orphan 📎: arises: a hand-edited buffer that deletes
the 🔧: but keeps the 📎:, a malformed 🔧: that `serialize.parse_call` drops (so
the block degrades to text) while its 📎: survives, or a corrupted/partial reload.

## Spec

Make emission drop or neutralize an orphan `tool_result` so it never reaches the
API unmatched. In the single emitter (`_emit_content_blocks_as_messages`, shared
by both build paths since #155), a `tool_result` whose `tool_use_id` does not
correspond to a `tool_use` present in the immediately-preceding assistant batch is
**orphan**. Options (decide at design time):

- **Drop it** — simplest; the orphan carries no assistant intent to preserve (there
  is no tool_use it answers). Risk: silently loses buffer content.
- **Degrade to a user text message** — preserves the visible text (mirrors the
  existing malformed-block degrade path) while removing the invalid `tool_result`
  shape. Likely the better fit — no content loss, valid payload.

Track which `tool_use` ids were actually emitted in the current assistant batch
(the inverse of the `pending` set #155 added) so the check is precise, not
positional. Keep it in the one emitter — do not reintroduce a second copy.

## Decision (drop, not degrade)

**Drop the orphan `tool_result`.** Rationale:

- An orphan is **corrupted/degenerate data** — a `tool_result` for a call not in
  the transcript. It only arises from a hand-edit, a corrupted reload, or a
  malformed 🔧: (and parley's own `serialize.render_call` output always parses, so
  this needs corruption, not normal operation). Reshaping invalid data into the
  conversation is the wrong instinct.
- **Degrade-to-user-text has real structural risk**: Anthropic constrains where
  `tool_result`/text blocks sit in a user turn, so folding an orphan's text into a
  tool_result batch (esp. an orphan *before* a real result, e.g.
  `[tu(A), tr(X_orphan), tr(A)]`) can produce an invalid block order; a separate
  user-text message risks consecutive same-role turns. Not worth the complexity
  for a rare degenerate state.
- **No true content loss**: the 📎: block stays visible in the buffer; only the
  wire excludes it (as it must — it's invalid). Dropping is the minimal,
  principled fix that satisfies every Done-when item.

**Mechanism (revised per plan-quality — reuse `pending`, no new set).** The
emitter already maintains `pending` (the current batch's unresolved tool_use ids),
which already answers "is this `tool_result` matched by a tool_use in the current
batch?" So instead of a parallel `batch_ids` set (finer-grained duplication inside
the one emitter), add an `is_pending(id)` helper next to `resolve_pending` and gate
the tool_result branch: **`if is_pending(block.id)` → matched** (`resolve_pending`
+ emit, as today); **else → orphan → drop**. Reusing `pending`:

- is **DRY** — one source of the batch's id state;
- avoids a **reset-timing trap**: a `batch_ids` reset in `flush_user` fires on
  *text* blocks too, so `[tu(A), text, tr(A)]` could wrongly drop a *matched*
  result; `pending`'s drain is already correctly gated on `current_user`;
- is **more correct on a duplicate** `tool_result` (same id twice): the first
  resolves `pending`, so the second is not-pending → dropped (a `batch_ids` set,
  never drained on resolve, would emit both → invalid payload).

All #155 cases (matched, dangling, partial-parallel, text-only, empty-dict) still
hit the matched path unchanged (ARCH-PURPOSE: symmetric completion of the #155
invariant; ARCH-DRY in the one shared pure emitter — ARCH-PURE).

## Done when

- An orphan `tool_result` (no matching preceding `tool_use`) never appears in the
  payload as an unmatched user `tool_result`.
- Matched pairs, dangling-tool_use (#155), and text-only paths are unchanged.
- Unit tests: orphan-only `[tool_result]`; orphan after an unrelated matched round;
  orphan interleaved with a real pair; a matched pair with **text between**
  (`[tu, text, tr]` — the result must survive, pins the reset-timing trap); a
  **duplicate** `tool_result` (the second is dropped); + regression that a plain
  matched pair and a dangling tool_use are untouched. Direct pure-emitter tests
  (ARCH-PURE).

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: lua-neovim       design=0.2 impl=0.25
item: milestone-review design=0.0 impl=0.1
total: 0.58
```

`lua-neovim` — one focused change to the single emitter (add a `batch_ids` set +
an orphan branch) + direct pure-emitter tests. Design 1–3 × 0.2 spec discount
(drop-vs-degrade + the batch_ids mechanism are pre-resolved here) → ~0.2; impl
0.5–1.5 (v2) × 0.4 → ~0.25. Single-pass `milestone-review` ~0.1. +15% design
buffer on ~0.2.

> *Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

## Plan

- [x] `chat_respond.lua` `_emit_content_blocks_as_messages`: `resolve_pending`
      now **returns** whether the id matched a still-pending tool_use (the max-DRY
      form of the reviewer's `is_pending` — one loop, not two); the tool_result
      branch emits on true, drops on false (orphan/duplicate). No new `batch_ids`.
- [x] Unit tests in `build_messages_spec.lua` (6 new, direct pure-emitter):
      orphan-only, orphan-after-matched, orphan-interleaved, `[tu, text, tr]`
      (result survives), duplicate-tool_result, dangling+orphan.
- [x] Full suite + lint green; atlas `providers/tool_use.md` extended to the
      symmetric invariant.

## Log

### 2026-07-01
- 2026-07-01: closed — build_messages_spec 51/51 (6 new #156 orphan/duplicate-drop pure-emitter tests: orphan-only, orphan-after-matched, orphan-interleaved, [tu,text,tr] result-survives, duplicate, dangling+orphan — plus all 45 pre-existing #155 emitter/build tests still green); full `make test` suite green; lint clean. resolve_pending now returns matched? → the tool_result branch drops orphan/duplicate (an unmatched user tool_result is an Anthropic 400). Reuses pending (no parallel batch_ids) per plan-quality FAILURE→revise. Atlas providers/tool_use.md extended to the symmetric invariant.; review verdict: SHIP

Filed from #155's close review (minor finding: the symmetric residual). #155
handled dangling tool_use; this is the orphan tool_result direction. Fix lives in
the same single emitter (`_emit_content_blocks_as_messages`, `chat_respond.lua`).
Together they make payload validity fully invariant-by-construction, closing the
dependency on the narrow stop-time `repair_unmatched_tool_blocks`.

**Plan-quality caught a better design (adopted).** My first plan added a parallel
`batch_ids` set; the gate (FAILURE) flagged it as ARCH-DRY duplication of `pending`,
with a reset-timing trap (a `batch_ids` reset in `flush_user` fires on *text* too,
so `[tu, text, tr]` could wrongly drop a matched result) and worse duplicate-result
handling. Revised to reuse `pending`; re-ran change-code → INFO. Implemented as the
maximally-DRY form: `resolve_pending` returns matched?, one loop.

**Implemented.** `_emit_content_blocks_as_messages`: `resolve_pending` returns
true when it removed a still-pending id (matched), false otherwise (orphan or
duplicate); the tool_result branch emits only on true, drops on false. 6 new
pure-emitter tests + all 45 pre-existing #155 emitter/build tests still green
(build_messages_spec 51/51); full suite green; lint clean. Atlas extended.

**Close review: SHIP (zero Critical/Important) + one Minor fixed.** The Minor:
`flush_assistant()` was unconditional at the top of the tool_result branch, so
dropping an orphan in `[text, orphan, text]` still flushed → two consecutive
assistant messages (the exact consecutive-same-role residual the Decision cited
*against* degrade). Fixed by moving `flush_assistant()` **inside the matched
branch** — a dropped orphan no longer flushes, so surrounding text stays in one
assistant message. Added a `[text, orphan, text]` test pinning the single merged
assistant message (build_messages_spec now 52/52). So drop now *fully* avoids the
consecutive-role issue, not just partially.
