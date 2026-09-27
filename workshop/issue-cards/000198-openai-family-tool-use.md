---
id: '000198'
status: done
started: 2026-08-15T10:03:41-07:00
created: 2026-08-15
updated: 2026-08-15
estimate_hours: 5.6
actual_hours: 1.73
---

# Native OpenAI-family tool-use support

## Problem

Client-side tool use only works against Anthropic-shaped wires. Selecting a
tool-enabled agent on any OpenAI-family model raises at
`lua/parley/providers.lua:1374`:

```
tools not supported for this provider yet — cliproxyapi requires an
anthropic-family model (see #81 follow-up)
```

The stubs it belongs to — `openai_encode_tools`, `googleai_encode_tools`,
`ollama_encode_tools` (`providers.lua:1348-1362`) — are the #81 M1 deferral.
The concrete trigger is a `ToolSol*` agent (`gpt-5.6-sol` on cliproxyapi's
codex channel), but the same wall blocks the `openai` provider itself plus
copilot, azure, and ollama.

Three things are missing, not one:

1. **Encode** — no OpenAI `{type:"function", function:{…}}` tool encoder.
2. **Decode** — no reader for OpenAI's streamed `delta.tool_calls[]`.
3. **Message translation** — `chat_respond._emit_content_blocks_as_messages`
   (`chat_respond.lua:576-700`) emits Anthropic content-block messages
   (`assistant[text,tool_use]` / `user[tool_result]`). OpenAI needs
   `assistant.tool_calls[]` plus a separate `{role:"tool", tool_call_id}`
   message per result. Nothing translates between them.

Plus three hardcoded decode sites that assume the Anthropic wire:
`tool_loop.lua:193`, `skill_invoke.lua:252`, and the `empty_response`
predicate at `dispatcher.lua:326` (`'"type":"tool_use"'`).

### Why not route everything over cliproxy's Anthropic translation endpoint

cliproxyapi *does* translate an Anthropic-format tool request to a codex
backend — verified live against 7.2.110: `tool_use` out, `tool_result`
round-trip closes. That would have been a ~100-line fix.

It was rejected because **server-side `web_search` / `web_fetch` are silently
inert on that cross-family path**. An Anthropic-shaped request carrying
parley's `web_search_20260209` / `web_fetch_20260209` to a codex model produced
no `server_tool_use` blocks at all — the model just answered from memory.
(Same tools on the `claude` channel
work fine, because that channel passes through to a real Anthropic endpoint;
the loss is specific to cross-family translation.) Routing `ToolSol*` that way
would have traded away search to gain tools.

The OpenAI route has no such trade: `{type:"web_search"}` and function tools
coexist in one `tools` array and both fire. Verified — see Log.
