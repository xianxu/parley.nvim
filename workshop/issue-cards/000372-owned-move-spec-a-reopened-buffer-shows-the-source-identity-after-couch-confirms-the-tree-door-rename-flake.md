---
id: 000372
status: done
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T05:19:56-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.32
tracker:
    version: 1
    completion:
        token: close-a9ae085e09bd
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 88acb8bd3ffde461022b14314f9dda8e0f9ccac2
        evidence_commit: 51004a5fe3f48b46e862071f354b60eb831aa77a
        landed_commit: 1b9b9d553bbf368d12708125baabd804a6c68bde
kind: bug
---

# owned-move spec: a reopened buffer shows the source identity after Couch confirms the tree-door rename (flake)

## Problem

In `tests/integration/agentic_document_owned_move_spec.lua`, the case "moves an unloaded registered ordinary file through the public tree door" fails intermittently at line 224 (`assert.equals(new_path, document.identity(reopened).File)`). The reopened buffer's identity still names the source path (`…/source/ordinary.md`), even though the case has just awaited Couch's registry reporting the document registered at the new path.

- First seen during #359's build: one failure, then 9 consecutive passes and green suites. Seen again on 2026-10-17 during #361's full suite on d59f6407024926a27b621aa36ef55d16773fde3: 15 of 16 cases passed; #361 touches nothing on the move path.
- Retained log: `/Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8ea1c8ed7dcdf4dd7b71ee92f8b6d396.log`.

Likely mechanism (unverified): the case waits on the registry (`lookup(new_path)`), but the loaded buffer adopts the new `File` only when the rename reply's reconcile effect runs on the main loop. A registry that already answers "registered at NEW" is earlier evidence than the buffer having adopted it. Either the spec awaits the wrong observable, or #359's adoption path has an ordering gap where a reopen reads the old identity.
