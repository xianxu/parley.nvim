---
id: '000183'
status: done
started: 2026-07-13T13:44:15-07:00
created: 2026-07-13
updated: 2026-07-13
estimate_hours: 2.02
actual_hours: N/A
---

# Keep response progress at current generation tip

## Problem

The response-progress extmark introduced by #182 is anchored to the agent-header
line for an entire LLM leg. That is correct only before a fresh answer emits any
content. During streaming it leaves reasoning or remote-tool status behind at
`🤖:`, and during a recursive tool loop it starts below `🤖:` instead of after
the already-generated answer and tool/result blocks. The indicator therefore
describes current work at a stale spatial location.
