---
id: '000161'
status: done
started: 2026-07-06T17:53:46-07:00
created: 2026-07-06
updated: 2026-07-07
estimate_hours: 2.85
actual_hours: 6.42
---

# Inline term definition on visual selection

## Problem

While reading a parley chat, the user hits jargon they don't know (e.g. "ASIN"
in an ad-tech reply). Getting a definition today means either breaking flow to
search elsewhere, or the two existing in-chat moves — both of which are
heavier than the need:

- **Branch ref** (`<C-g>i`, `init.lua:1899`) spawns a *child chat file* whose
  topic is `what is "<phrase>"`. Answers in a separate buffer — a full detour.
- **Drill-in** (`<M-q>`, `init.lua:1537`) wraps the selection as `🤖<T>[]` and
  gathers it into the **next full turn** on respond — a whole conversational
  turn, not a scoped lookup.

There is no lightweight "define this phrase, inline, right here" gesture. The
want is: select a phrase → one keystroke → a concise definition appears
attached to the phrase, without touching the transcript or spending a turn.
