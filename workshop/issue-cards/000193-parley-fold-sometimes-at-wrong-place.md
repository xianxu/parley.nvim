---
id: '000193'
status: done
started: 2026-07-16T22:54:13-07:00
created: 2026-07-16
updated: 2026-07-17
estimate_hours: 2.2
actual_hours: 2.23
---

# parley fold sometimes at wrong place

## Problem

Parley folds are less accurate during streaming than after finalization. The
steady-state path reconstructs exchange structure from the whole document,
while the streaming path eventually relies on that corrective reconstruction
instead of maintaining folds from the live exchange model.

The canonical exchange structure consists of `question`, `agent_header`,
ordinary answer `text`, `thinking`, `summary`, `tool_use`, and `tool_result`.
`stream_placeholder` is transient lifecycle state. Folding should hide the
auxiliary answer entities—thinking, summary, tool calls, and tool results—while
leaving the conversational spine visible.
