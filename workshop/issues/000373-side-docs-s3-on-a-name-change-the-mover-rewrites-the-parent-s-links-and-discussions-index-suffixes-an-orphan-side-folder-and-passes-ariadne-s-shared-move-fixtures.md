---
id: 000373
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '94b8c7993bc07ef5e7d0567ac555c2322a6e5453' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T06:40:08-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

## Plan

- [ ] M1 — Export v2 fixture snapshot and pure move projection; review via milestone-close.
- [ ] M2 — Recoverable orphan/parent rewrite journal, editor handoff, shared integration fixtures and acceptance; review via milestone-close.

Durable plan: [000373-side-doc-moves-plan.md](../plans/000373-side-doc-moves-plan.md).

## Log

### 2026-10-17

Planning only, 2026-10-17: claimed and started from current main. Read S3 design section 6 and producer #424 at 5990bf04a5d7cebb58dcf279b19e142ae3f2fe5f; producer confirms unlanded/no PR, fixture role in export v2. Existing mover owns leases/no-replace renames, conservative byte rewrites and forward recovery; new parent rewrite must synchronize loaded buffer and NEW witness before later saves. Read-only explorer confirmed these seams. No implementation or generated snapshot changes; code waits for landed producer and approved full-flow plan.
