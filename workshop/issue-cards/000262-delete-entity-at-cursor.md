---
id: '000262'
status: done
started: 2026-09-16T12:23:08-07:00
created: 2026-09-16
updated: 2026-09-16
estimate_hours: 2.57
actual_hours: 4.84
---

# Delete entity at cursor — markdown section, paragraph, or chat question

## Problem

Editing chat transcripts and markdown notes requires frequent deletion of
larger-than-line units: a whole markdown section under a heading, a blank-line
delimited paragraph, or an entire chat question (💬: block plus its answer).
The stock Vim `dap` (delete a paragraph) works for blank-line paragraphs but
is not discoverable for light Vim users, does not handle markdown section
ranges, and does not know about Parley's question/answer structure. There is
no single quick command that does the right thing based on where the cursor
is.
