---
id: '000156'
status: done
started: 2026-07-01T11:28:08-07:00
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.58
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
