---
id: '000155'
status: done
started: 2026-07-01T00:17:43-07:00
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 1.0
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
