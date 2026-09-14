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

- [x] Verify external backup and manifest, then apply exact keep/remove inventory.
- [x] Repair retained references and use a dedicated synthetic folding corpus.
- [x] Run scoped tests, inspect staged scope, close through fresh review.

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


### 2026-09-14 — Cleanup and verification

Verified private backup: `/Users/xianxu/.local/share/parley/cleanup-backups/20260914-120628-workshop` (59 original files, SHA256 manifest, exact inventory, operation journal, one-shot executor and recovery copies). Removed44chat transcripts+3PNG+1hidden raw log; retained11approved chats. Literal checkout tilde directory disappeared before backup execution; confirmed absent, did not delete an alternate target. Backup original hashes rechecked after cleanup. No private research moved to another active library.

Six retained branch targets resolve locally after correcting timestamp-renamed paths and anchoring refractive-index to workshop Basics with a forward link. The cross-category WWII link was an incoming backlink from the removed chat, so retained product prose did not need deletion. Seven temporary executor tests cover unsafe paths, source changes, incomplete/corrupt backups, extra source files, symlinks and exact deletion/retry.

Fold corpus no longer queries Git/workshop or retains an obsolete missing-file exemption. Four existing adversarial fixtures plus a synthetic multi-exchange fixture exercise unchanged model/raw-text fold oracles; all fixtures must exist and have headers. RED: with workshop discovery empty, old suite failed corpus minimum. GREEN: six cases pass with no workshop discovery, and again from an isolated directory without workshop. Mapped chat/exchange_model suite and lint pass. No runtime API changes. Unrelated staged README, .gitignore, bootstrap and untracked merge helper preserved.
