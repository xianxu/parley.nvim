---
id: 000156
status: open
deps: []
github_issue:
created: 2026-07-01
updated: 2026-07-01
estimate_hours:
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

## Done when

- An orphan `tool_result` (no matching preceding `tool_use`) never appears in the
  payload as an unmatched user `tool_result`.
- Matched pairs, dangling-tool_use (#155), and text-only paths are unchanged.
- Unit tests: orphan-only `[tool_result]`; orphan after an unrelated matched round;
  orphan interleaved with a real pair. Direct pure-emitter tests (ARCH-PURE).

## Plan

- [ ]

## Log

### 2026-07-01

Filed from #155's close review (minor finding: the symmetric residual). #155
handled dangling tool_use; this is the orphan tool_result direction. Fix lives in
the same single emitter (`_emit_content_blocks_as_messages`, `chat_respond.lua`).
Together they make payload validity fully invariant-by-construction, closing the
dependency on the narrow stop-time `repair_unmatched_tool_blocks`.
