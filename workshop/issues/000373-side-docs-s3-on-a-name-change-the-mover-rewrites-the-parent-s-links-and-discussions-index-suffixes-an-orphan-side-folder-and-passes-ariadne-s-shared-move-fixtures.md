---
id: 000373
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '10208fa45231aa1fe35527a994a607992f2aa3bd' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-17
