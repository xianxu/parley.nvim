---
id: 000356
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '130bd154a3c14ed9fc17a8bd2606c98e4b2ee7f3' # card fields mirrored from issue-cards; edit via sdlc
---

# Keep the cursor and view in place when the agent rewrites an open document

## Problem

When the agent writes a document the operator has open, the reload makes the cursor jump. That covers the session file, QA files and any agentic document. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.

## Spec

On a reload caused by an external write, map each window's cursor and top line from the old text to the new one with a line diff (`vim.diff`, hunk indices):
- A line outside every changed hunk shifts by the net line offset of the hunks above it.
- A line inside a changed hunk goes to that hunk's new start. It is refined by searching the new hunk for the text around the old cursor, about 50 characters, exact match first.
- The column is kept when the cursor's line is unchanged.
- Each window showing the buffer is mapped on its own.
- This never applies to the operator's own edits: only to reloads of text written outside the buffer.

## Done when

- Tests cover: an edit above the cursor, at it, and below it; two windows on the same buffer, each mapped; and a top line that stays stable.
- After that, the operator's live check on the session file.

## Plan

- [ ]

## Log

### 2026-10-16
