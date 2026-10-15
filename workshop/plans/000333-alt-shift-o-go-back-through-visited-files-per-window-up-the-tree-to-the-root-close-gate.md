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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6841a1ac-b886-4bbf-ac3d-84de2197bed4
            repository: github.com/xianxu/parley.nvim
            issue_id: "000333"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/acf40c2f32160616
            reviewed_head: 55b784e5a4a3c8f09b000b40b453feb943207e8a
            slot: parley.nvim:1
            requested_at: "2026-10-15T19:49:22.733163Z"
          phase: finished
          pid: 82767
          started_at: "2026-10-15T19:49:22.983163Z"
          finished_at: "2026-10-15T19:51:20.599604Z"
          session_id: 01a1411c-b70a-7b32-99f5-5724e6ccb8ce
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 55b784e5a4a3c8f09b000b40b453feb943207e8a
        tracker_head: cddaddf731f5058bd7f46997a979ac6b89bfd29e
        branch_point: 538372be03b75c9350e346f923b85366ceff809e
        since: "2026-10-15T11:08:10-07:00"
        until: "2026-10-15T12:49:03-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T11:08:10-07:00"
              end: "2026-10-15T12:49:03-07:00"
              began: "2026-10-15T11:08:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 59e594603417867c383d61218bb04f18dc64fd070cbdd41820e6a1771b1f11d3
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 7234299
              windows:
                - start: "2026-10-15T11:08:10-07:00"
                  end: "2026-10-15T12:49:03-07:00"
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
                  end: "2026-10-15T12:49:03-07:00"
            - harness: codex
              id: 01a14109-80d9-7521-89d5-3a43a59d0b36
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: f1d200dfd9f33ecf5738b1f55496788850249c7858c4db638bb4c7aa7d4424d7
              started: "2026-10-15T19:28:24.383Z"
              spawned: true
              bytes: 390916
              windows:
                - start: "2026-10-15T19:28:24.383Z"
                  end: "2026-10-15T12:49:03-07:00"
        cuts:
            - dispatched: "2026-10-15T12:25:58-07:00"
              finalized: "2026-10-15T12:27:47-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T12:51:24-07:00"
      dispatched: "2026-10-15T12:49:22-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: The revised issue/plan explicitly limits inheritance to native command splits. All eight unfocused-parent direction/activation assertions pass at head and fail with the pre-fix adapter loaded in memory; native split/tab inheritance also passes.
          round: 2
      findings:
        - kind: defect
          id: BR-2
          severity: Critical
          title: Deferred API initialization drops legitimate file visits
          detail: 'lua/parley/file_history.lua:19 suppresses every observation while pending_windows is set at lines 47–55. On Neovim 0.11.7, create an active API split displaying B, then synchronously edit C and D before yielding: after initialization runs, both Back calls return false at D. Yielding immediately after creation instead produces the required D → C → B traversal. This violates any-method visit recording and the documented first-file root (ARCH-PURPOSE, ARCH-ORDER). Distinguish temporary creation observations from subsequent real visits, preserve those visits through initialization, and add deterministic tests without a yield between creation and navigation.'
          family: initialization-preserves-visits
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 2e3a4d2c-a8f7-40ee-8928-8022a0a920cb
            repository: github.com/xianxu/parley.nvim
            issue_id: "000333"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/24ad1d95687239e5
            reviewed_head: 8ce10d02789b1a5c8d487220a5c8eeefbcb899e9
            slot: parley.nvim:1
            requested_at: "2026-10-15T20:07:02.082609Z"
          phase: finished
          pid: 46099
          started_at: "2026-10-15T20:07:02.184639Z"
          finished_at: "2026-10-15T20:08:37.929112Z"
          session_id: 01a1412c-e001-7441-bafa-e68f63deed74
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8ce10d02789b1a5c8d487220a5c8eeefbcb899e9
        tracker_head: cddaddf731f5058bd7f46997a979ac6b89bfd29e
        branch_point: 538372be03b75c9350e346f923b85366ceff809e
        since: "2026-10-15T11:08:10-07:00"
        until: "2026-10-15T13:06:49-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T11:08:10-07:00"
              end: "2026-10-15T13:06:49-07:00"
              began: "2026-10-15T11:08:10-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 9e1b076f61b5546e659f71c05cea44fc7dee4c58e8c8114dbb3643cd509d499f
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 7851407
              windows:
                - start: "2026-10-15T11:08:10-07:00"
                  end: "2026-10-15T13:06:49-07:00"
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
                  end: "2026-10-15T13:06:49-07:00"
            - harness: codex
              id: 01a14109-80d9-7521-89d5-3a43a59d0b36
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: f1d200dfd9f33ecf5738b1f55496788850249c7858c4db638bb4c7aa7d4424d7
              started: "2026-10-15T19:28:24.383Z"
              spawned: true
              bytes: 390916
              windows:
                - start: "2026-10-15T19:28:24.383Z"
                  end: "2026-10-15T13:06:49-07:00"
        cuts:
            - dispatched: "2026-10-15T12:25:58-07:00"
              finalized: "2026-10-15T12:27:47-07:00"
              finalizing: false
            - dispatched: "2026-10-15T12:49:22-07:00"
              finalized: "2026-10-15T12:51:24-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-15T13:08:38-07:00"
      dispatched: "2026-10-15T13:07:02-07:00"
      agent: codex
      dispose:
        - id: BR-2
          disposition: addressed
          note: The regression at tests/integration/file_history_spec.lua:193 fails at line 201 with the pre-fix adapter restored in a disposable checkout (27 pass, 1 fail). The pinned adapter passes all 28 cases. BufEnter observations now record synchronously without pending-window suppression.
          round: 3
        - id: BR-1
          disposition: addressed
          note: 'Remains addressed under the revised contract: API windows inherit no parent history. The eight direction/activation cases and native split/tab inheritance cases pass; README and atlas document this distinction.'
          round: 3
      recipe: milestone-review
      isolation: fenced
      reviewed: 8ce10d02789b1a5c8d487220a5c8eeefbcb899e9
      blocked: false
---

# Gate ledger — parley.nvim#333 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T12:27:47-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `split-parent-history` (kind: defect) Splits targeting an unfocused parent inherit the focused window's history
  lua/parley/file_history.lua:38-44 copies histories[source_window], but source_window tracks focus rather than the parent supplied to nvim_open_win. Reproduced on Neovim 0.11.7: create parent A with sessionA → answerA, focus window B with sessionB → answerB, then create an inactive split displaying A's buffer with {split="right", win=parentA}. The child starts on answerA, but its first Back reaches answerB instead of sessionA. This violates the documented parent-inheritance contract (ARCH-PURPOSE, ARCH-ORDER). Derive inheritance from the actual source parent and add regression coverage with distinct focused and parent windows.

## Round 2 — 2026-10-15T12:51:24-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — The revised issue/plan explicitly limits inheritance to native command splits. All eight unfocused-parent direction/activation assertions pass at head and fail with the pre-fix adapter loaded in memory; native split/tab inheritance also passes.

### Raised

- **BR-2** [Critical] `initialization-preserves-visits` (kind: defect) Deferred API initialization drops legitimate file visits
  lua/parley/file_history.lua:19 suppresses every observation while pending_windows is set at lines 47–55. On Neovim 0.11.7, create an active API split displaying B, then synchronously edit C and D before yielding: after initialization runs, both Back calls return false at D. Yielding immediately after creation instead produces the required D → C → B traversal. This violates any-method visit recording and the documented first-file root (ARCH-PURPOSE, ARCH-ORDER). Distinguish temporary creation observations from subsequent real visits, preserve those visits through initialization, and add deterministic tests without a yield between creation and navigation.

## Round 3 — 2026-10-15T13:08:38-07:00 (codex) — passed

### Disposed

- BR-2 — addressed — The regression at tests/integration/file_history_spec.lua:193 fails at line 201 with the pre-fix adapter restored in a disposable checkout (27 pass, 1 fail). The pinned adapter passes all 28 cases. BufEnter observations now record synchronously without pending-window suppression.
- BR-1 — addressed — Remains addressed under the revised contract: API windows inherit no parent history. The eight direction/activation cases and native split/tab inheritance cases pass; README and atlas document this distinction.

## Open findings

(none — every finding has been disposed)
