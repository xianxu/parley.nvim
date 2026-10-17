---
id: 000373
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours: 5.53
collaboration-mode: collaboration
card_mirror: '708f77f1bf3631014542da823bc712872d66717a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T06:40:08-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures

## Problem

The S3 design for side docs (ops `teams/devinfra/projects/universal-agent-input-interface/design.side/07-s3-side-docs.md`, final at ops cf0f0ebf, section 6; decisions by the operator, 10-16) needs parley's document mover (parley.nvim#332, `document_move_plan.lua`) to finish what a rename does. Today the mover moves `<name>.side/` with the file, rewrites each side doc's `parent:` and backlinks, and renames Couch's registry entry. A name change (`design.md` → `spec.md`) leaves the parent's own links into `design.side/…` and its `discussions:` index entries pointing at the old folder.

## Spec

- **A name change rewrites the parent's own references.** When the file name changes, the folder becomes `spec.side/`, and the mover rewrites the parent's own links and its `discussions:` frontmatter entries from `design.side/…` to `spec.side/…`, in the same journal as the rest of the move.
- **A taken folder name suffixes the orphan.** When `spec.side/` already exists (an orphan: its document is gone, since a taken `spec.md` stops the move), the orphan is renamed `spec_1.side/` (then `_2`, …), and the moving document takes `spec.side/`, because every tool finds a document's side docs from its file name. The move names where the orphan went. (Operator decision, 07's thread 09.)
- **Shared fixtures.** One set of before/after move fixtures is shared with ariadne's `xx-universal-review` examples checker, carried in the skill's `export.json` (as #319 does), so the two writers can't drift. ariadne's side is ariadne#424.
- **Check:** a side doc opened with Alt+o from an agentic parent is registered with Couch too (design.md's S3 line); today's side docs usually aren't, which is why the agent writes them straight to disk (parley#367's finding).
- Links from other documents into the folder are not rewritten (operator: side docs are local references).

## Done when

- A parley rename that changes the file name keeps the parent's links and its `discussions:` index resolving, with a projection spec.
- A move into a taken `.side/` name suffixes the orphan and reports it, with a spec.
- The projection specs pass the shared fixtures from ariadne's `export.json`.
- Side docs opened with Alt+o from an agentic parent are registered, or the gap is filed with evidence.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.* Calibration is marked stale by sdlc; values are provisional.

The producer contract and approved state table resolve design decisions (×0.2 design discount). Implementation values below already apply v3.1's ×0.40 scale to v2 table values. Familiarity 1.0: this extends the existing Lua mover, Python exporter and persistent fake. Library check: existing frontmatter/reference parsers, filesystem no-replace adapter and lease implementation are reused; no novel platform/library integration is assumed.

- Export v2 snapshot: smaller module extension, base design 0.2 → 0.04; base implementation 0.5 → 0.20.
- Parent-reference projection: focused Lua feature, base design 2 → 0.40; base implementation 1.5 → 0.60.
- Pure transition model: greenfield single-concern module, base design 1 → 0.20; base implementation 0.8 → 0.32.
- Journal/recovery integration: focused Lua feature, base design 3 → 0.60; base implementation 1.5 → 0.60.
- Editor synchronization/registration audit: focused Lua feature, base design 2 → 0.40; base implementation 1.5 → 0.60.
- Shared fixture executor: smaller module extension, base design 0.2 → 0.04; base implementation 0.5 → 0.20.
- Two milestone reviews plus final close: 3 × base implementation 0.5 × 0.40 = 0.60.
- Atlas/docs: base design 0.2 × 0.2 = 0.04; base implementation 0.2 × 0.40 = 0.08.
- Issue/design integration: base design 1 × 0.2 = 0.20; base implementation 0.3 × 0.40 = 0.12.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: smaller-go-module design=0.04 impl=0.20
item: lua-neovim design=0.40 impl=0.60
item: greenfield-go-module design=0.20 impl=0.32
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.40 impl=0.60
item: smaller-go-module design=0.04 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: atlas-docs design=0.04 impl=0.08
item: issue-spec design=0.20 impl=0.12
design-buffer: 0.15
total: 5.53
```

Design 1.92 × 1.15 + implementation 3.32 = 5.528, rounded 5.53 focused ship-hours. Module slugs are the closed-vocabulary analogues for Python/Lua single-concern modules, not a planned Go port.

## Plan

- [ ] M1 — Export v2 fixture snapshot and pure move projection; review via milestone-close.
- [ ] M2 — Recoverable orphan/parent rewrite journal, editor handoff, shared integration fixtures and acceptance; review via milestone-close.

Durable plan: [000373-side-doc-moves-plan.md](../plans/000373-side-doc-moves-plan.md).

## Log

### 2026-10-17

Planning only, 2026-10-17: claimed and started from current main. Read S3 design section 6 and producer #424 at 5990bf04a5d7cebb58dcf279b19e142ae3f2fe5f; producer confirms unlanded/no PR, fixture role in export v2. Existing mover owns leases/no-replace renames, conservative byte rewrites and forward recovery; new parent rewrite must synchronize loaded buffer and NEW witness before later saves. Read-only explorer confirmed these seams. No implementation or generated snapshot changes; code waits for landed producer and approved full-flow plan.

TL approved the durable plan and policies (receipt 6d2d8e58-b402-4f59-af38-d945acb5c1af, submitted). Waiting for ariadne#424 landing; no code or tests changed.

Producer #424 landed as ariadne PR #284 at 5fa50f084f8062fafb493bec86b8207fc8f5617a, confirmed from Git and peer receipt 933d0b03-27a1-4866-9cc4-5ceec0f1d9a6. Relevant export/fixture/reference files match the planning pin. Proceeding to change-code on the approved plan.

Plan-quality round 1 raised PQ-1 (authoritative transition model) and PQ-2 (function-level strategies). Revised durable plan defines a pure v2 state reducer, one journal dispatcher, and compressed adversarial test contracts. TL approved revision and operator mapping: moving/done/interrupted, one reopen recovery, forward-only witness recovery or safe pre-effect abort; changed/unknown bytes never overwritten. Rerunning change-code, no implementation yet.

Plan-quality round 2 CLEAN: PQ-1/PQ-2 addressed, no new findings. Estimate derived after that approval; change-code will validate/admit it before code.
