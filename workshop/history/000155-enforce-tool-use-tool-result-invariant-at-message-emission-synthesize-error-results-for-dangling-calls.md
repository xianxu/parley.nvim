---
id: 000155
status: done
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 1.0
started: 2026-07-01T00:17:43-07:00
actual_hours: 0.39
---

# enforce tool_use→tool_result invariant at message-emission (synthesize error results for dangling calls)

## Problem

A **dangling tool_use** (a `🔧:` block with no following `📎:` result) in an
exchange can reach the Anthropic API as an **invalid payload** — an assistant
`tool_use` with no matching user `tool_result` → HTTP 400. Today the only
safeguard is `tool_loop.repair_unmatched_tool_blocks`, which is narrow on two
axes: it runs **only on the stop path** (`chat_respond.lua:315`) and fixes
**only the last answered exchange** (`tool_loop.lua:106-114`). So a dangling call
in a genuinely *past* exchange — a crash / kill mid-loop, a buffer reload that
never hit stop, or a hand-edited buffer with a deleted `📎:` — sails into an
invalid request. Message-payload validity depends on a buffer-repair that may not
have run, instead of being guaranteed at the point that builds the payload.

The two emitters that turn buffer blocks into the Anthropic payload —
`_emit_content_blocks_as_messages` (`chat_respond.lua:465`, the parse/history
path) and the inline emitter inside `build_messages_from_model`
(`chat_respond.lua:382-425`, the live/recursion path) — **both** emit a
`tool_use` with no synthesized result if the following `tool_result` is absent.
They also duplicate the same assistant/user interleaving logic (**ARCH-DRY**
smell) and diverge on a detail: the model path coerces empty tool input to
`vim.empty_dict()` (so it serializes as JSON `{}`, not `[]`) while the parse path
does not — a latent second bug the consolidation fixes.

We never *re-execute* a history tool_use (execution only fires for the live
model's freshly-streamed calls), so the fix is not about preventing
re-execution — it is about **payload validity**. And per the earlier design
discussion: don't *drop* a dangling call (that loses the record of what the model
attempted and can orphan trailing text) — **supply an error result**, which keeps
the wire valid and truthfully tells the model "that call didn't complete" so it
naturally re-proposes next turn if it still needs it.

## Spec

Make valid interleaving a property of message-emission **by construction**, in
both build paths, and consolidate the duplicated interleaving into one pure
emitter.

**1. Single pure emitter with the invariant baked in.**
`_emit_content_blocks_as_messages(content_blocks) → messages` becomes the single
choke point (ARCH-PURE: pure function, content_blocks → messages, no IO — unit
tested directly). It enforces: **every `tool_use` in an assistant batch is
answered by a `tool_result` (real or synthetic) in the immediately following
user batch.** Algorithm (tracks pending ids so parallel calls are handled, not
just the single-dangling case):

- Maintain `pending` = ordered list of `{id, name}` for tool_uses accumulated in
  the current assistant batch that a real `tool_result` has not yet resolved.
- On a `tool_use` block: append to the assistant batch **and** to `pending`.
- On a `tool_result` block: `flush_assistant()`, remove its `tool_use_id` from
  `pending`, append the real result to the current user batch.
- On a `text`/`tool_use` block arriving **while a user batch is open** (i.e. we
  are transitioning out of a tool_result run into a new assistant run): for each
  id still in `pending`, append a synthetic error `tool_result` to the user batch,
  clear `pending`, then `flush_user()` and begin the new assistant batch.
- At end: `flush_assistant()`; if `pending` is non-empty, open a user batch and
  append a synthetic error result for each; `flush_user()`.
- Empty tool input coerces to `vim.empty_dict()` here (fixes the parse-path
  divergence noted above).

Synthetic result shape: `{ type = "tool_result", tool_use_id = id,
content = "(tool call did not complete — no result recorded)", is_error = true }`.
The text is **reason-agnostic** — a build-time fallback doesn't know *why*
(crash / timeout / manual edit). The stop-time repair keeps its specific
`"(cancelled by user)"` because at that point it genuinely knows the reason.

**2. Consolidate `build_messages_from_model` onto the shared emitter (ARCH-DRY).**
Per exchange it keeps emitting the question as a user message, then **normalizes**
its answer blocks (read text + `serialize.parse_call` / `serialize.parse_result`,
skipping `agent_header`/`spinner`, degrading malformed blocks to text exactly as
today) into a `content_blocks` list, and extends `messages` with
`_emit_content_blocks_as_messages(answer_content_blocks)`. The interleaving +
invariant then live in exactly one place.

**3. The stop-time buffer repair stays** as a UX nicety (so the user *sees* the
cancelled result rendered in the buffer), but it is no longer load-bearing for
payload correctness.

ARCH notes: **ARCH-DRY** — one emitter, not two parallel ones. **ARCH-PURE** —
the emitter is a pure fn tested without a buffer; IO (buffer reads / parse) stays
in the thin `build_messages_from_model` normalization seam. **ARCH-PURPOSE** —
enforce in **both** paths (parse + model), not just the cheap parse path, and
close the empty-dict divergence rather than leaving it as a follow-up.

## Done when

- Both build paths route tool interleaving through the single
  `_emit_content_blocks_as_messages`; the inline emitter in
  `build_messages_from_model` is gone (ARCH-DRY shadow-sweep: no second copy).
- A dangling `tool_use` (no following `tool_result`) in any exchange emits a
  synthetic `is_error=true` result → the payload has no unanswered tool_use.
- Matched pairs, multi-round loops, and text-only answers are **byte-unchanged**
  (vanilla-chat flat-string invariant preserved).
- Partial parallel resolution (2 calls, 1 resolved / 1 dangling) synthesizes a
  result for only the dangling one.
- Empty tool input serializes as `{}` (`vim.empty_dict()`) on **both** paths.
- Unit tests cover: single dangling; dangling-then-text; partial-parallel;
  matched single round (unchanged); text-only (flat, unchanged); empty-input dict.

## Plan

- [x] Rewrite `M._emit_content_blocks_as_messages` (`chat_respond.lua`) with the
      `pending`-id invariant + `vim.empty_dict()` empty-input coercion.
- [x] Refactor `M.build_messages_from_model` to normalize answer blocks →
      content_blocks and reuse the shared emitter; delete the inline emission.
- [x] Add unit tests in `tests/unit/build_messages_spec.lua` (direct
      `_emit_content_blocks_as_messages` tests + one parse-path integration) for
      the six cases in Done-when.
- [x] Run the full suite; confirm no regression in existing tool round-trip tests.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
design-buffer: 0.15
item: lua-neovim        design=0.4 impl=0.4
item: milestone-review  design=0.0 impl=0.15
total: 1.0
```

Method A (v2/v2.1 primitive table), v3.1 impl scaling:

- **`lua-neovim` (single, focused)** — one pure-fn rewrite + one refactor to
  reuse it. Design 1–3 hr × 0.2 spec-quality discount (this spec pre-resolves the
  algorithm + all six test cases) → ~0.4 design. Impl 0.5–1.5 (v2) × 0.4 (v3.1) →
  ~0.4 impl.
- **`milestone-review`** — single-pass boundary review at close: impl 0.2–0.5 (v2)
  × 0.4 → ~0.15.
- **+15% design buffer** (thorough plan) on the ~0.4 design subtotal → +~0.06.

Range ≈ 0.5–1.5 hr, midpoint ≈ **1.0 hr** → `estimate_hours: 1.0`.

> *Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-01
- 2026-07-01: closed — 7 new unit tests (6 pure-emitter: single-dangling, dangling-then-text, partial-parallel, matched-unchanged, text-only, empty-input-dict; +1 parse-path _build_messages integration) pass; full build_messages_spec 44/44; make lint clean (0/0, 237 files). Existing tool round-trip + vanilla-chat flat-string tests unchanged (no regression). Pre-existing config_tools_spec.lua 5-fail verified unrelated via git stash (@readonly→@all default-config drift, needs its own issue).; review verdict: FIX-THEN-SHIP

Filed + claimed from the tool-transcript design discussion (this session). Root
cause: payload validity depended on the narrow stop-time
`repair_unmatched_tool_blocks` rather than being guaranteed at message-emission.
Fix = enforce the tool_use→tool_result invariant in the single shared emitter and
consolidate the two duplicated emitters. Design (the `pending`-id interleaving
algorithm + neutral synthetic text + empty-dict consolidation) settled in the
discussion above; captured here rather than in a separate durable plan (≈1 hr,
single source file + tests).

**Implemented.** `chat_respond.lua`: `_emit_content_blocks_as_messages` rewritten
with the `pending`-id invariant + `M.DANGLING_TOOL_RESULT_TEXT` neutral synthetic
+ empty-input `vim.empty_dict()` coercion (single source, fixes the parse-path
`[]` divergence); `build_messages_from_model` normalizes its answer blocks →
content_blocks and routes through that single emitter (inline duplicate deleted,
ARCH-DRY). Plan-quality's two INFO notes honored: end-flush reuses the open user
batch (partial-parallel synthetics land in the same user message), and the
`[tool_use, text]` same-run dangling case is covered.

**Tests:** 7 new in `build_messages_spec.lua` (6 direct pure-emitter cases: single
dangling, dangling-then-text, partial-parallel, matched-unchanged, text-only,
empty-input-dict; + 1 parse-path `_build_messages` integration). Full spec file
44/44 pass, incl. all pre-existing tool round-trip tests. `make lint` clean
(0 warnings/errors, 237 files).

**Pre-existing unrelated failure (NOT #155):** `config_tools_spec.lua` fails 5
tests — verified identical failures with my changes `git stash`ed, and my diff
touches only message emission. Cause: `config.lua:222,246` intentionally swapped
the default `ToolSonnet`/`ToolSonnet*` from `@readonly` → `@all` ("to also allow
edit/write") but never refit `config_tools_spec.lua` (still asserts `@readonly` +
that `edit_file`/`write_file` are absent). Needs its own issue + a product
decision on whether the default tool agent should ship `@all`; out of scope here.

**Close review: FIX-THEN-SHIP (confidence high) — zero Critical, one Important,
resolved.** The Important finding: the live path (`build_messages_from_model`)
had no end-to-end coverage for a dangling call (its freshly-rewritten
normalization seam — buffer read + `parse_call`/`parse_result` + malformed
degrade — was untested). Added an 8th test
(`build_messages_from_model: dangling tool_use synthesized on the live path`)
that builds a real buffer + `exchange_model` (positions driven by the model's own
`block_start`) with a dangling 🔧: and asserts the synthetic `is_error`
`tool_result` follows the assistant `tool_use`. Full spec now **45/45**, lint
clean. Minor findings noted as non-blocking: (a) `pending` stores id-only (only
`tool_use_id` is needed for the synthetic) — a deliberate simplification, so the
Spec §algorithm text saying `{id, name}` is now slightly stale; (b) the symmetric
**orphan `tool_result`** gap (a `📎:` with no preceding `🔧:` → 400) is
pre-existing and out of scope — the natural next hardening, worth a future issue.
