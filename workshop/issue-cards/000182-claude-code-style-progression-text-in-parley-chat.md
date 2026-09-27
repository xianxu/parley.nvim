---
id: '000182'
status: done
started: 2026-07-12T21:56:40-07:00
created: 2026-07-10
updated: 2026-07-13
estimate_hours: 8.94
actual_hours: N/A
---

# claude code style progression text in parley chat

## Problem

Agentic chat responses can remain silent long enough that users cannot tell
whether Parley is still working. The existing in-buffer progress indicator is
limited to web-search mode, mutates buffer text, and does not provide one
consistent waiting cue for every LLM response that will become chat content.

Inline definition has the same feedback gap at a smaller spatial scale: it
currently uses the detached luabar even though the selected term is the clear
place to show pending work.
