---
gate: boundary-review
issue: 404
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d733bcbf-bfe1-44ab-87f1-c961a6b49e2f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000404"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/b87dea22024c53c7
            reviewed_head: 6f837cf5c11ed37ae18b8940245ee2a7c1f10d20
            slot: parley.nvim:1
            requested_at: "2026-10-21T15:53:59.385215Z"
          phase: finished
          pid: 54459
          started_at: "2026-10-21T15:53:59.490842Z"
          finished_at: "2026-10-21T15:59:29.096538Z"
          session_id: 01a15f2b-5cce-7df3-998f-71ff6010df13
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 6f837cf5c11ed37ae18b8940245ee2a7c1f10d20
        tracker_head: 0b8dd81ccf217c9f13791cdd1f8b089e2b57d928
        branch_point: 0fdc27987dd8174c82f7486b9ec8620c87cb5b83
        since: "2026-10-21T01:17:07-07:00"
        until: "2026-10-21T08:53:36-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T01:17:07-07:00"
              end: "2026-10-21T08:53:36-07:00"
              began: "2026-10-21T01:17:07-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 99b1942355222390f2a9df32414aab5ad1002dd29da6f15d903ec059bab57036
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 73078882
              windows:
                - start: "2026-10-21T01:17:07-07:00"
                  end: "2026-10-21T08:53:36-07:00"
      "n": 1
      timestamp: "2026-10-21T08:59:30-07:00"
      dispatched: "2026-10-21T08:53:59-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Ctrl-C exit strands the operator lock and disables baseline release
          detail: 'lua/parley/session_sync.lua:609 clears s.inserting only on InsertLeave, which Neovim skips for Ctrl-C. On pinned head with Neovim 0.11.7, native i<C-c> leaves mode n with unchanged content and the lock present; release_if_baseline returns false because of the new guard at line 838. Native iX<C-c>u likewise restores baseline content without releasing. Reproduced both scenarios for registered session files and side docs, with auto-save off and on (eight combinations). The family includes both acquisition entry points—InsertEnter at line 608 and late attachment at line 740—and both release paths: unchanged exit and subsequent baseline undo. Track actual mode departure, including exits that skip InsertLeave, while preserving deferred reconciliation and ownership/epoch guards. Add native regression cases for this matrix. ARCH-PURPOSE: the current implementation leaves the forgotten-turn problem unresolved for this exit.'
          family: insert-intent-must-follow-mode
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b3c2581e-3ee8-4c00-8b76-9c37643865f1
            repository: github.com/xianxu/parley.nvim
            issue_id: "000404"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/c4011392ea6befbc
            reviewed_head: 27c43e6abd779c5416890256793e33524c379bb5
            slot: parley.nvim:1
            requested_at: "2026-10-21T16:11:13.956803Z"
          phase: finished
          pid: 73591
          started_at: "2026-10-21T16:11:14.13063Z"
          finished_at: "2026-10-21T16:16:09.216848Z"
          session_id: 01a15f3b-26c9-7df1-ad4d-b561bdc21f99
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 27c43e6abd779c5416890256793e33524c379bb5
        tracker_head: 0b8dd81ccf217c9f13791cdd1f8b089e2b57d928
        branch_point: 0fdc27987dd8174c82f7486b9ec8620c87cb5b83
        since: "2026-10-21T01:17:07-07:00"
        until: "2026-10-21T09:10:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T01:17:07-07:00"
              end: "2026-10-21T09:10:30-07:00"
              began: "2026-10-21T01:17:07-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 5e38a0ef560600803edf4300b6689a44a2520d06c81a12f83e5df72b11c06e5b
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 74291757
              windows:
                - start: "2026-10-21T01:17:07-07:00"
                  end: "2026-10-21T09:10:30-07:00"
        cuts:
            - dispatched: "2026-10-21T08:53:59-07:00"
              finalized: "2026-10-21T08:59:30-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-21T09:16:10-07:00"
      dispatched: "2026-10-21T09:11:13-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: The shared ModeChanged/InsertLeave handler fixes actual departure. All 16 native Ctrl-C combinations pass on head; loading the pre-fix module makes all 16 fail. The additional move-intent regression also fails without the fix.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Critical
          title: Replayed move finalization removes protection during live insert intent
          detail: 'lua/parley/session_sync.lua:1121 checks insert intent when creating a snapshot, but prepare_move_finalization at lines 1142-1160 does not recheck it before deleting NEW''s lock. Reproduced on pinned head with Neovim 0.11.7: capture an unchanged release snapshot outside insert, retain its protection-stage intent, detach, enter native insert mode, restore_move with that intent, then prepare_move_finalization and retire_move. Before replay: mode=i, destination lock present. After replay: success=true, mode=i, destination lock absent. Production recovery reaches this path through lua/parley/agentic_document.lua:878. This is the 2nd finding in family insert-intent-must-follow-mode. Earlier rounds fixed instances; state and enforce the rule that persisted automatic-release permission cannot override current insert intent. The complete automatic-release enumeration is release_if_baseline (guarded), move_finalization_snapshot (guarded), and persisted cleanup through prepare_move_finalization (unguarded), including restore_move recovery. Apply the shared policy at the destructive boundary and add native recovery regressions, including interrupted cleanup, while preserving journal replay and ownership checks. ARCH-PURPOSE.'
          family: insert-intent-must-follow-mode
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#404 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-21T08:59:30-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `insert-intent-must-follow-mode` (kind: defect) Ctrl-C exit strands the operator lock and disables baseline release
  lua/parley/session_sync.lua:609 clears s.inserting only on InsertLeave, which Neovim skips for Ctrl-C. On pinned head with Neovim 0.11.7, native i<C-c> leaves mode n with unchanged content and the lock present; release_if_baseline returns false because of the new guard at line 838. Native iX<C-c>u likewise restores baseline content without releasing. Reproduced both scenarios for registered session files and side docs, with auto-save off and on (eight combinations). The family includes both acquisition entry points—InsertEnter at line 608 and late attachment at line 740—and both release paths: unchanged exit and subsequent baseline undo. Track actual mode departure, including exits that skip InsertLeave, while preserving deferred reconciliation and ownership/epoch guards. Add native regression cases for this matrix. ARCH-PURPOSE: the current implementation leaves the forgotten-turn problem unresolved for this exit.

## Round 2 — 2026-10-21T09:16:10-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — The shared ModeChanged/InsertLeave handler fixes actual departure. All 16 native Ctrl-C combinations pass on head; loading the pre-fix module makes all 16 fail. The additional move-intent regression also fails without the fix.

### Raised

- **BR-2** [Critical] `insert-intent-must-follow-mode` (kind: defect) Replayed move finalization removes protection during live insert intent
  lua/parley/session_sync.lua:1121 checks insert intent when creating a snapshot, but prepare_move_finalization at lines 1142-1160 does not recheck it before deleting NEW's lock. Reproduced on pinned head with Neovim 0.11.7: capture an unchanged release snapshot outside insert, retain its protection-stage intent, detach, enter native insert mode, restore_move with that intent, then prepare_move_finalization and retire_move. Before replay: mode=i, destination lock present. After replay: success=true, mode=i, destination lock absent. Production recovery reaches this path through lua/parley/agentic_document.lua:878. This is the 2nd finding in family insert-intent-must-follow-mode. Earlier rounds fixed instances; state and enforce the rule that persisted automatic-release permission cannot override current insert intent. The complete automatic-release enumeration is release_if_baseline (guarded), move_finalization_snapshot (guarded), and persisted cleanup through prepare_move_finalization (unguarded), including restore_move recovery. Apply the shared policy at the destructive boundary and add native recovery regressions, including interrupted cleanup, while preserving journal replay and ownership checks. ARCH-PURPOSE.

## Open findings

- **BR-2** [Critical] `insert-intent-must-follow-mode` (kind: defect) Replayed move finalization removes protection during live insert intent
