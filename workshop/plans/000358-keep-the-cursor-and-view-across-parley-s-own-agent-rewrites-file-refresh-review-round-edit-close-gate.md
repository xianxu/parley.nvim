---
gate: boundary-review
issue: 358
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 051b08cc-a6a8-4f88-a3b3-44847de82784
            repository: github.com/xianxu/parley.nvim
            issue_id: "000358"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/6242c09c40a1aadf
            reviewed_head: 7ff97e390ce4d3f132cbcd87f118c8831f113a8b
            slot: parley.nvim:4
            requested_at: "2026-10-16T23:41:53.279748Z"
          phase: finished
          pid: 48031
          started_at: "2026-10-16T23:41:53.516472Z"
          finished_at: "2026-10-16T23:45:23.12301Z"
          session_id: 4d48a41c-a8a2-49f2-ac6f-ea7f0a6dadfb
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 7ff97e390ce4d3f132cbcd87f118c8831f113a8b
        tracker_head: fdfe230cf35082d7352f120e522389fff9af8b3a
        branch_point: 7caca2c80ada693f2e0830bed2879f19fd196713
        since: "2026-10-16T12:49:00-07:00"
        until: "2026-10-16T16:41:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T12:49:00-07:00"
              end: "2026-10-16T16:41:18-07:00"
              began: "2026-10-16T12:49:00-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 65230bbccf4707d80e07ea3ba98ed618042312edd79818f39bd32db0955a2c21
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 23158369
              windows:
                - start: "2026-10-16T12:49:00-07:00"
                  end: "2026-10-16T16:41:18-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 40.262566666666665
      "n": 1
      timestamp: "2026-10-16T16:45:24-07:00"
      dispatched: "2026-10-16T16:41:53-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Review-round path (skill_invoke source_completion) lacks the edit-below test that Done-when requires for each path
          detail: Done-when requires, for each path, an edit-above case and an edit-below case that leaves the cursor and top line exact. tool_file_refresh_spec has both; skill_invoke_spec.lua:409-430 has only the insert-above case. Add a propose_edits case that appends after line 60 and asserts the view stays at lnum 30, col 2, topline 25. That is the only missing instance in this window; the session_sync paths are covered by the 356 suites.
          family: done-when-clause-both-states
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Comments and issue text still say the review round reloads with :edit!, but it is skill_invoke's whole-buffer apply_user
          detail: lua/parley/skills/review/init.lua:632 and lua/parley/skills/review/projection.lua:19 describe the round's own :edit! reload. The issue's Problem section repeats it. Done-when also still says each test fails without the restore, which the Log shows is false for the edit-below cases. Reword all of these.
          family: stale-doc-claim
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: skill_invoke.lua requires parley.window_views inline twice; file_refresh hoists it to a local
          detail: skill_invoke.lua:540 and :543. Hoist it to a local, as file_refresh.lua:6 does.
          family: module-require-style
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: cefd60af-15dd-47cf-ae79-1e74a4478622
            repository: github.com/xianxu/parley.nvim
            issue_id: "000358"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f5313420c74d8a62
            reviewed_head: b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d
            slot: parley.nvim:4
            requested_at: "2026-10-16T23:47:22.971719Z"
          phase: finished
          pid: 1285
          started_at: "2026-10-16T23:47:23.21472Z"
          finished_at: "2026-10-16T23:48:36.38153Z"
          session_id: 4c700dac-2eba-40bb-bf40-3ab8769bca2b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d
        tracker_head: fdfe230cf35082d7352f120e522389fff9af8b3a
        branch_point: 7caca2c80ada693f2e0830bed2879f19fd196713
        since: "2026-10-16T12:49:00-07:00"
        until: "2026-10-16T16:46:42-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T12:49:00-07:00"
              end: "2026-10-16T16:46:42-07:00"
              began: "2026-10-16T12:49:00-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: f6270648ac6edbce82d76df1ad2eed5f67c4dd99f0c958e75c7927bc721a62cf
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 23297466
              windows:
                - start: "2026-10-16T12:49:00-07:00"
                  end: "2026-10-16T16:46:42-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 40.262566666666665
        cuts:
            - dispatched: "2026-10-16T16:41:53-07:00"
              finalized: "2026-10-16T16:45:24-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-16T16:48:37-07:00"
      dispatched: "2026-10-16T16:47:22-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: skill_invoke_spec "leaves the cursor and top line exact when the round appends below" added and passes at head; the mutation run shows the above case goes red without Views.restore.
          round: 2
        - id: BR-2
          disposition: addressed
          note: init.lua:632 and projection.lua:19 now name skill_invoke's whole-buffer apply_user; the Problem section is corrected; the Revisions entry scopes "fails without the restore" to the edit-above cases.
          round: 2
        - id: BR-3
          disposition: addressed
          note: skill_invoke.lua:32 hoists local Views=require('parley.window_views'), matching file_refresh.lua:6.
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: b31928c1200e7b0e3932dbbcf2d2c3f434a85c2d
      blocked: false
---

# Gate ledger — parley.nvim#358 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T16:45:24-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `done-when-clause-both-states` (kind: defect) Review-round path (skill_invoke source_completion) lacks the edit-below test that Done-when requires for each path
  Done-when requires, for each path, an edit-above case and an edit-below case that leaves the cursor and top line exact. tool_file_refresh_spec has both; skill_invoke_spec.lua:409-430 has only the insert-above case. Add a propose_edits case that appends after line 60 and asserts the view stays at lnum 30, col 2, topline 25. That is the only missing instance in this window; the session_sync paths are covered by the 356 suites.
- **BR-2** [Minor] `stale-doc-claim` (kind: defect) Comments and issue text still say the review round reloads with :edit!, but it is skill_invoke's whole-buffer apply_user
  lua/parley/skills/review/init.lua:632 and lua/parley/skills/review/projection.lua:19 describe the round's own :edit! reload. The issue's Problem section repeats it. Done-when also still says each test fails without the restore, which the Log shows is false for the edit-below cases. Reword all of these.
- **BR-3** [Minor] `module-require-style` (kind: defect) skill_invoke.lua requires parley.window_views inline twice; file_refresh hoists it to a local
  skill_invoke.lua:540 and :543. Hoist it to a local, as file_refresh.lua:6 does.

## Round 2 — 2026-10-16T16:48:37-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — skill_invoke_spec "leaves the cursor and top line exact when the round appends below" added and passes at head; the mutation run shows the above case goes red without Views.restore.
- BR-2 — addressed — init.lua:632 and projection.lua:19 now name skill_invoke's whole-buffer apply_user; the Problem section is corrected; the Revisions entry scopes "fails without the restore" to the edit-above cases.
- BR-3 — addressed — skill_invoke.lua:32 hoists local Views=require('parley.window_views'), matching file_refresh.lua:6.

## Open findings

(none — every finding has been disposed)
