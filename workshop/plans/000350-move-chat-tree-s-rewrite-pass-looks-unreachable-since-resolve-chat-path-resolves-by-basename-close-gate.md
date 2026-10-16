---
gate: boundary-review
issue: 350
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 29502d70-c5ef-4d25-b95a-b17dbaf1a20f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000350"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/4c10926903f58929
            reviewed_head: 0ea8a86dadf6adbbc84a21d8c285677a449aa751
            slot: parley.nvim:4
            requested_at: "2026-10-16T12:16:28.762426Z"
          phase: finished
          pid: 32442
          started_at: "2026-10-16T12:16:29.004664Z"
          finished_at: "2026-10-16T12:17:43.256096Z"
          session_id: 258d1fab-9a9f-41ee-b126-97be4263151d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 0ea8a86dadf6adbbc84a21d8c285677a449aa751
        tracker_head: 8f3b85c32b319eaa3dca0ce54e39d004336b0123
        branch_point: ec786c0c1e2f281ab88ac1e3acc4942b316c3abd
        since: "2026-10-16T04:13:22-07:00"
        until: "2026-10-16T05:11:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T04:13:22-07:00"
              end: "2026-10-16T04:13:29-07:00"
              began: "2026-10-16T04:13:22-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            - start: "2026-10-16T05:08:19-07:00"
              end: "2026-10-16T05:11:48-07:00"
              began: "2026-10-16T05:08:19-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: dac869ff2f3a38a5bbb128a1001f4bc8b1023ec58b0be0c811134372a6136ea1
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 8379596
              windows:
                - start: "2026-10-16T04:13:22-07:00"
                  end: "2026-10-16T04:13:29-07:00"
                - start: "2026-10-16T05:08:19-07:00"
                  end: "2026-10-16T05:11:48-07:00"
      "n": 1
      timestamp: "2026-10-16T05:17:46-07:00"
      dispatched: "2026-10-16T05:16:28-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: chat-move rewrite tests cover only the open-buffer path; the closed-file writefile branch is unpinned
          detail: All three new specs rewrite through an open buffer, so the non-live write branch at init.lua:3971 is never reached by them. Add a case where a moved, unopened child holds an absolute reference to a grandchild with no timestamp, and assert the file on disk after the move.
          family: branch-output-untested
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The ~ and ../ reference forms named in the atlas and code comment have no test
          detail: lifecycle.md and init.lua:3938 list absolute, ~, ../ and sub/ as the shapes the rewrite fires for; only absolute and sub/ are pinned in chat_move_spec.
          family: doc-claim-untested
          round: 1
      recipe: milestone-review
      isolation: checkout
      reviewed: 0ea8a86dadf6adbbc84a21d8c285677a449aa751
      blocked: false
---

# Gate ledger — parley.nvim#350 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T05:17:46-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `branch-output-untested` (kind: defect) chat-move rewrite tests cover only the open-buffer path; the closed-file writefile branch is unpinned
  All three new specs rewrite through an open buffer, so the non-live write branch at init.lua:3971 is never reached by them. Add a case where a moved, unopened child holds an absolute reference to a grandchild with no timestamp, and assert the file on disk after the move.
- **BR-2** [Minor] `doc-claim-untested` (kind: defect) The ~ and ../ reference forms named in the atlas and code comment have no test
  lifecycle.md and init.lua:3938 list absolute, ~, ../ and sub/ as the shapes the rewrite fires for; only absolute and sub/ are pinned in chat_move_spec.

## Open findings

- **BR-1** [Minor] `branch-output-untested` (kind: defect) chat-move rewrite tests cover only the open-buffer path; the closed-file writefile branch is unpinned
- **BR-2** [Minor] `doc-claim-untested` (kind: defect) The ~ and ../ reference forms named in the atlas and code comment have no test
