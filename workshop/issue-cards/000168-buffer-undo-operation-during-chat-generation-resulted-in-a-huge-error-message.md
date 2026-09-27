---
id: '000168'
status: done
started: 2026-07-13T20:23:23-07:00
created: 2026-07-08
updated: 2026-07-14
estimate_hours: 4.01
actual_hours: 7.21
---

# buffer undo operation during chat generation resulted in a huge error message

## Problem

Undoing or redoing chat history while Parley is waiting for an agent can remove
the response shell that owns the in-flight request. Parley already detects that
structural change and prevents stale callbacks from writing into the transcript,
but the standard history keys mutate first and cancel afterward. The user gets
no choice before losing the request, and the resulting technical warning does
not explain the relationship between history manipulation and cancellation.
