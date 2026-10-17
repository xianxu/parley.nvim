---
id: 000367
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '5d51b1c181d04d772b2eeeafe6c6c59a06451852' # card fields mirrored from issue-cards; edit via sdlc
---

# Attention finder: an agent rewrite of a seen or retired side doc brings it back as answered

## Problem

#354's attention finder lists side docs the agent wrote as "answered, not yet seen" until the operator looks. Once seen, or once swept and retired, a side doc stays gone even when the agent writes to it again. Operator decision (TL, on #354): an agent write to a side doc after the operator last saw it brings it back as answered, the same as any other entry the agent answers. The operator's own edits do not. A retired entry stays retired only until the next agent write.

## Spec

- Tell an agent write apart from the operator's own save. For example, record the mtime of each save the operator makes in this editor (BufWritePost) and count only a newer mtime that this editor did not write. Finding the agent's write signal is part of the design.
- A seen side doc whose agent-write time is later than its `seen_at` goes back to answered. This is a pure model event in `attention_model`, alongside `viewed`.
- A retired side doc with a newer agent write is rediscovered, and leaves `retired`.
- `attention.discover` today skips existing entries and retired paths. It, or a sibling, would emit the new event.

## Done when

- Model specs: an agent rewrite after seen makes the entry answered; an operator save does not; a rewrite before seen changes nothing; a retired doc with a newer agent write comes back.
- An integration spec through `attention.open` covers one rewrite.
- atlas/ui/attention_finder.md describes the rule.

## Plan

- [ ]

## Log

### 2026-10-16
