---
gate: boundary-review
issue: 410
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 008812c4-feb7-4fd2-9bf7-47e5b2a1a62a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/eb5b13688580f6b8
            reviewed_head: adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6
            slot: parley.nvim:4
            requested_at: "2026-10-22T19:16:34.97545Z"
          phase: finished
          pid: 96134
          started_at: "2026-10-22T19:16:35.074286Z"
          finished_at: "2026-10-22T19:22:16.753209Z"
          session_id: 01a1650b-338a-7fe3-b6b7-d627a5de240d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: adf97f9c0ceed3c0085a9857acd3d2a430dc2aa6
        tracker_head: d6b0e05f6a0105af4993ad21ab2460c82b69e5f3
        branch_point: 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c
        since: "2026-10-22T11:48:38-07:00"
        until: "2026-10-22T12:16:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T11:48:38-07:00"
              end: "2026-10-22T12:16:18-07:00"
              began: "2026-10-22T11:48:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: codex
              id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 173538876ca11b601c31fb0966f96c2d149ac17c4244924bd0cf16c734582568
              started: "2026-10-20T15:57:08.221Z"
              spawned: false
              bytes: 3235289
              windows:
                - start: "2026-10-22T11:48:38-07:00"
                  end: "2026-10-22T12:16:18-07:00"
            - harness: codex
              id: 01a164f5-8f4c-7591-9e73-29818193c394
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              parent_id: 01a15a07-a72c-7c20-a8f8-814afe085bbe
              digest: 0aaf2a7cb03a256a17dbace202bfda1f8b7fae2b6c11bc1024ae08abc3c36fa3
              started: "2026-10-22T18:52:57.249Z"
              spawned: true
              bytes: 1166238
              windows:
                - start: "2026-10-22T18:52:57.249Z"
                  end: "2026-10-22T12:16:18-07:00"
      "n": 1
      timestamp: "2026-10-22T12:22:24-07:00"
      dispatched: "2026-10-22T12:16:34-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Existing session-sync controllers bypass pending-lookup admission
          detail: 'lua/parley/session_sync.lua:726 updates an existing controller''s identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper''s detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.'
          family: admission-handoff-covers-existing-controllers
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#410 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T12:22:24-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `admission-handoff-covers-existing-controllers` (kind: defect) Existing session-sync controllers bypass pending-lookup admission
  lua/parley/session_sync.lua:726 updates an existing controller's identity and returns without consuming input_scope or admitting its insert intent. Production setup at lua/parley/init.lua:3190 attaches session-sync before S1, so typed session files reach this branch. The legacy InsertEnter handler can already have created tokenless protection. Both instances of this family are affected: adoption without observed edits, and adoption with outstanding edits, where acquire_observed skips acquisition because the legacy turn reads as operator. Re-running the parent freshness test with session_sync.attach(0) immediately after the helper's detach reproduced confirmed identity, zero acquire calls, and stale first-character text on Neovim 0.12.5 and 0.11.7; the saved-edit case also reported zero acquisitions. ARCH-PURPOSE: handle both existing and newly created controllers, coordinate legacy InsertEnter ordering, and require confirmed acquisition/freshness or refusal within the original deadline. Add production-order regressions for both edit states; the current helper at tests/integration/session_sync_native_spec.lua:147 masks this path by detaching the controller.

## Open findings

- **BR-1** [Critical] `admission-handoff-covers-existing-controllers` (kind: defect) Existing session-sync controllers bypass pending-lookup admission
