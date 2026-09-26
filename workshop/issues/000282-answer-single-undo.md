---
id: 000282
status: open
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
---

# Make each answer one undo history entry

## Problem

Streaming an assistant answer currently records many incremental buffer edits.
Undo can therefore remove individual chunks instead of reverting the answer as
one user-visible action.

## Spec

Treat one submitted answer as one undo transaction from the user's perspective,
while preserving streaming, cancellation, partial-answer recovery and unrelated
edits made before or after the answer. Trace the existing response and buffer
mutation paths, then choose the smallest integration boundary that groups all
chunks belonging to one answer without merging separate answers or tool turns.
Cover answer replacement, errors, stop/cancel, reload and concurrent chats.

## Done when

- A completed streamed answer can be undone in one action.
- Separate answers and unrelated user edits retain independent undo history.
- Cancellation, errors, partial responses and reload do not corrupt undo state.
- Regression tests exercise chunked streaming and the answer lifecycle paths.

## Plan

- [ ] Trace response streaming and buffer undo boundaries; reproduce chunk-by-chunk undo.
- [ ] Design and implement one undo transaction per answer.
- [ ] Add lifecycle regression coverage and verify separate answers remain separate.

## Log

### 2026-09-26
