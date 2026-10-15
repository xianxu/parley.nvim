---
gate: boundary-review
issue: 333
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 96704f14-39bb-4ea7-83e2-c164f6d3f35b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000333"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/fdc98f8373abd1cc
            reviewed_head: c69e6f8535d395c8c6043eae6fb3cd58c97cc69e
            slot: parley.nvim:1
            requested_at: "2026-10-15T19:25:58.347364Z"
          phase: finished
          pid: 6551
          started_at: "2026-10-15T19:25:58.77694Z"
          finished_at: "2026-10-15T19:27:46.094897Z"
          session_id: 01a14107-4ae5-7462-b4ac-9dfd55c83169
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c69e6f8535d395c8c6043eae6fb3cd58c97cc69e
        tracker_head: cddaddf731f5058bd7f46997a979ac6b89bfd29e
        branch_point: 538372be03b75c9350e346f923b85366ceff809e
        since: "2026-10-15T11:08:10-07:00"
        until: "2026-10-15T12:25:26-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T11:08:10-07:00"
              end: "2026-10-15T12:25:26-07:00"
              began: "2026-10-15T11:08:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 14db5165413a896bb84b376744afeb0b7701658183059766b7c81256ad9d39a8
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 6340338
              windows:
                - start: "2026-10-15T11:08:10-07:00"
                  end: "2026-10-15T12:25:26-07:00"
            - harness: codex
              id: 01a140c7-b360-74a2-b53b-19f2e38725a4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 2e34aab979b89cc5c581afac308816270fb8d1678e2e51616dacc10745989ddd
              started: "2026-10-15T18:16:32.03Z"
              spawned: true
              bytes: 366658
              windows:
                - start: "2026-10-15T18:16:32.03Z"
                  end: "2026-10-15T12:25:26-07:00"
      "n": 1
      timestamp: "2026-10-15T12:27:47-07:00"
      dispatched: "2026-10-15T12:25:58-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Splits targeting an unfocused parent inherit the focused window's history
          detail: 'lua/parley/file_history.lua:38-44 copies histories[source_window], but source_window tracks focus rather than the parent supplied to nvim_open_win. Reproduced on Neovim 0.11.7: create parent A with sessionA → answerA, focus window B with sessionB → answerB, then create an inactive split displaying A''s buffer with {split="right", win=parentA}. The child starts on answerA, but its first Back reaches answerB instead of sessionA. This violates the documented parent-inheritance contract (ARCH-PURPOSE, ARCH-ORDER). Derive inheritance from the actual source parent and add regression coverage with distinct focused and parent windows.'
          family: split-parent-history
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#333 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T12:27:47-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `split-parent-history` (kind: defect) Splits targeting an unfocused parent inherit the focused window's history
  lua/parley/file_history.lua:38-44 copies histories[source_window], but source_window tracks focus rather than the parent supplied to nvim_open_win. Reproduced on Neovim 0.11.7: create parent A with sessionA → answerA, focus window B with sessionB → answerB, then create an inactive split displaying A's buffer with {split="right", win=parentA}. The child starts on answerA, but its first Back reaches answerB instead of sessionA. This violates the documented parent-inheritance contract (ARCH-PURPOSE, ARCH-ORDER). Derive inheritance from the actual source parent and add regression coverage with distinct focused and parent windows.

## Open findings

- **BR-1** [Critical] `split-parent-history` (kind: defect) Splits targeting an unfocused parent inherit the focused window's history
