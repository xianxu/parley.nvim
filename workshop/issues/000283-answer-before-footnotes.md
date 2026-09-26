---
id: 000283
status: open
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
---

# Keep generated answers before trailing footnotes

## Problem

When the final question is immediately above a footnote section, generated
answer content can be inserted after the footnote instead of remaining attached
to that question. This produces the wrong transcript order and makes the answer
look unrelated to the question that prompted it.

## Spec

Trace question and footnote parsing plus the answer insertion anchor. Preserve
the document's footnote placement while inserting the generated answer directly
after its question. Define behavior for multiple footnotes, an answer already
present, streaming chunks, cancellation and malformed or incomplete footnote
markers. Keep unrelated document content in its existing order.

## Done when

- A generated answer for a question immediately before footnotes is inserted
  before the footnote section and remains attached to that question.
- Streaming, cancellation and retry paths preserve the same ordering.
- Regression tests cover trailing footnotes and existing answer/document cases.

## Plan

- [ ] Reproduce the misplaced insertion with a question followed by footnotes;
  trace the parser and insertion anchor.
- [ ] Fix the answer placement at the correct question boundary.
- [ ] Add regression coverage for streaming and neighboring footnote layouts.

## Log

### 2026-09-26
