---
id: 000368
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '509882542390475667f563513acde0eb95c6284a' # card fields mirrored from issue-cards; edit via sdlc
---

# New parley chats declare collaboration-mode: collaboration (S2 M2 follow-up)

## Problem

## Spec

From ariadne#415 (S2 M2, the per-type collaboration-mode audit): every ariadne-managed document type now declares a default `collaboration-mode:` in its frontmatter. Parley's chat writer (`workshop/parley` chats) is parley's own document type and is outside ariadne's audit.

New parley chats should carry `collaboration-mode: collaboration` in their frontmatter: answers in place. That is ariadne:2's proposed default; the TL agreed.

Past chats are not migrated (operator decision for S2).

## Done when

- A newly created parley chat has `collaboration-mode: collaboration` in its frontmatter; a test covers the writer.
- Existing chats without the key still open and work unchanged.

## Plan

- [ ]

## Log

### 2026-10-16
