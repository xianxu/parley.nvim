---
id: '000166'
status: done
started: 2026-07-08T08:45:50-07:00
created: 2026-07-08
updated: 2026-07-08
estimate_hours: 2.29
actual_hours: 0.39
---

# move visual selection definition system to be based on durable footnote

## Problem

Inline visual definitions currently write only an ephemeral diagnostic and a
minimal `[term]` text anchor. The definition itself disappears from the chat
file, so the lookup cannot be preserved or reloaded as durable transcript state.
Persisting the definition in ordinary markdown footnotes solves that, but the
managed footnote block must not become part of the next LLM prompt.
