---
id: 000373
status: codecomplete
created: 2026-10-17
updated: 2026-10-17
estimate_hours: 5.53
github_issue:
started: 2026-10-17T06:40:08-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: N/A
tracker:
    version: 1
    completion:
        token: close-ba06e873f187
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2af674c93083b7e2253ba0fd6d45991a07a87e3a
        evidence_commit: 404bc5d055051367661997e4b8d8dad0862c69b3
---

# side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures

## Problem

The S3 design for side docs (ops `teams/devinfra/projects/universal-agent-input-interface/design.side/07-s3-side-docs.md`, final at ops cf0f0ebf, section 6; decisions by the operator, 10-16) needs parley's document mover (parley.nvim#332, `document_move_plan.lua`) to finish what a rename does. Today the mover moves `<name>.side/` with the file, rewrites each side doc's `parent:` and backlinks, and renames Couch's registry entry. A name change (`design.md` → `spec.md`) leaves the parent's own links into `design.side/…` and its `discussions:` index entries pointing at the old folder.
