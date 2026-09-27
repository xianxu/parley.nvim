---
id: '000154'
status: done
started: 2026-06-29T18:30:05-07:00
created: 2026-06-29
updated: 2026-06-29
estimate_hours: 0.5
actual_hours: 0.27
---

# raise max_tool_iterations default to 42

## Problem

The default `max_tool_iterations` (tool-loop rounds per chat response) should be
raised from 20 to 42. While mapping the current value, the "default" turned out
to be **three inconsistent literals** for the same concept:

- `init.lua:689` — `agent.max_tool_iterations or 20` (the canonical setup-time
  default applied to tool-enabled agents; this is what actually governs).
- `tool_loop.lua:233` — `agent_info.max_tool_iterations or 20` (defensive fallback).
- `chat_respond.lua:1693` — `agent_info.max_tool_iterations or 10` (defensive
  fallback — a **stale 10**, inconsistent with the real default).

The atlas also disagrees with itself: `providers/agents.md` says "default 20",
`providers/tool_use.md` says "default 10".
