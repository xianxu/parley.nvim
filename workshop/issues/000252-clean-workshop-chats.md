---
id: 000252
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.615
started: 2026-09-14T12:05:18-07:00
---

# Clean workshop chat corpus

## Problem

Workshop contains 55 chat transcripts: 29 personal research, 15 test leftovers, 7 product/workflow discussions and 4 explicitly retained demonstrations. Personal material is not needed by the operator. A literal ./~ contains one fake login credential; hidden raw logs and test images also remain.

## Spec

Operator approved backup, deletion of personal/test material (no move to private library), and retention of seven product chats plus welcome/basics/advanced/refractive demos. Preserve all original bytes in a verified private backup outside the checkout before deletion. Remove test images/raw logs and only the confirmed literal tilde fixture directory. Make retained links local and remove references to discarded conversations. Decouple folding tests from workshop transcripts using purpose-built test fixtures. Preserve unrelated staged README and other local changes.

## Done when

- Exactly eleven approved chats remain; removed material is recoverable from a checksum-verified external backup.
- Retained branch targets resolve locally, fixture-based fold checks pass, and tests no longer depend on personal workshop content.
- Literal tilde debris is absent; no home-directory deletion or unrelated edits.



## Plan

- [ ] Verify external backup and manifest, then apply exact keep/remove inventory.
- [ ] Repair retained references and use a dedicated synthetic folding corpus.
- [ ] Run scoped tests, inspect staged scope, close through fresh review.

## Log

### 2026-09-14


## Estimate

After plan-quality approval: familiar Lua test harness and small filesystem cleanup. Resolved design 0.5h ×0.2 =0.1h; implementation/verification 1h ×0.4 =0.4h; single fresh review0.25h ×0.4 =0.1h; 15% design buffer0.015h.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.1 impl=0.4
item: milestone-review design=0 impl=0.1
design-buffer: 0.15
total: 0.615
```
