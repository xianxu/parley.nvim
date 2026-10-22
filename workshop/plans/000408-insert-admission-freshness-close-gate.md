---
gate: boundary-review
issue: 408
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 7d712088-7f80-4894-9cec-657788ef0020
            repository: github.com/xianxu/parley.nvim
            issue_id: "000408"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/4671b59d88890d45
            reviewed_head: ed02d19c4306e0acec8b256c3666b7a527506aa4
            slot: parley.nvim:1
            requested_at: "2026-10-22T07:24:44.91298Z"
          phase: finished
          pid: 76584
          started_at: "2026-10-22T07:24:45.108244Z"
          finished_at: "2026-10-22T07:31:57.951594Z"
          session_id: 01a1627f-8097-7b72-a9f7-391b14bc0d94
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: ed02d19c4306e0acec8b256c3666b7a527506aa4
        tracker_head: 3821fadb4d0bfac2e58f74dead32cfc4d76e8856
        branch_point: ec4dcf71361ed40c78c76044928d4bea23e5caa3
        since: "2026-10-21T12:06:42-07:00"
        until: "2026-10-22T00:24:15-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T12:06:42-07:00"
              end: "2026-10-22T00:24:15-07:00"
              began: "2026-10-21T12:06:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 189ac1bb461db15e8cabd73563dfe80464fcf919e728d67c38a74b9d98cfafd2
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 81485305
              windows:
                - start: "2026-10-21T12:06:42-07:00"
                  end: "2026-10-22T00:24:15-07:00"
            - harness: codex
              id: 01a16071-4ff3-73f1-a85c-877dcce84e18
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: b3bc56eccd7a6e133b494338fb84d9e3bdfbaf6b41fac9084ff83a709c1be6c7
              started: "2026-10-21T21:50:01.255Z"
              spawned: true
              bytes: 737767
              windows:
                - start: "2026-10-21T21:50:01.255Z"
                  end: "2026-10-22T00:24:15-07:00"
            - harness: codex
              id: 01a16072-1e8a-7a31-9dbe-dfb1645ad626
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 39bf519351caceeecc6c2a2584290843f7295aca736b8bf32e273cd6f9ebe8ef
              started: "2026-10-21T21:50:54.15Z"
              spawned: true
              bytes: 684168
              windows:
                - start: "2026-10-21T21:50:54.15Z"
                  end: "2026-10-22T00:24:15-07:00"
        queue_waits:
            - attempt_id: 536b1e6d7e8843d2abd371937cd1b455
              slot: parley.nvim:1
              record_digest: 05b3f8752374a99480876847eec2febb8992d5742bf21f5957f44f227fdbc6de
              start: "2026-10-21T22:35:27.370846Z"
              end: "2026-10-21T23:49:00.808914Z"
              queue_seconds: 4413.438068
              raw_seconds: 4413.438068
              exact: true
      "n": 1
      timestamp: "2026-10-22T00:31:59-07:00"
      dispatched: "2026-10-22T00:24:44-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: BR-1
          severity: Critical
          title: A refused retry discards the baseline and permits release of an unsubmitted edit
          detail: 'lua/parley/session_sync.lua:532-533 clears baseline when protection is absent and admission changes from unavailable to refused; a subsequent successful acquire at lines 649-659 adopts the saved edited content as its baseline. Reproduced through the production Couch client and executable fake: unavailable acquire → edit and save → refused retry → confirmed retry → unchanged exit removes the lock, whereas the control without the refused retry retains it; preserve the original outstanding baseline across failures and add this regression sequence.'
          family: acquisition-baseline-preservation
          round: 1
        - id: BR-2
          severity: Critical
          title: Admission state changes bypass an explicit pure transition model
          detail: 'lua/parley/session_sync.lua:632-675 makes admission decisions inside the IO callback and directly mutates admission, acquire_token, owned_lock, baseline, and unconfirmed_edit; refresh, release_owned, and on_lines independently mutate the same authoritative state. ARCH-ORDER and ARCH-PURE require an encapsulated pure state/event transition component: extract the admission submodel, route its mutations through that component, and test failure/retry/save/release sequences against independent invariants.'
          family: admission-transition-ownership
          round: 1
        - id: BR-3
          severity: Critical
          title: The Core-concepts table marks the new operator_lock function as modified
          detail: workshop/plans/000408-insert-admission-freshness-plan.md:29 classifies operator_lock as modified, but the base contains no such function and the pinned diff adds its definition at lua/parley/couch.lua:103. Correct the status to new and record the correction under Revisions, as required by the Core-concepts cross-check; this correction needs source inspection, not a wording-presence test.
          family: core-concept-traceability
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 066496e4-8393-40b7-ad34-584e1fbabfff
            repository: github.com/xianxu/parley.nvim
            issue_id: "000408"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/6e7faea0d0a7ff61
            reviewed_head: 3a8c455256e0ff2b7629d578adee08ba30ee6264
            slot: parley.nvim:1
            requested_at: "2026-10-22T09:26:35.651774Z"
          phase: finished
          pid: 29422
          started_at: "2026-10-22T09:26:35.820119Z"
          finished_at: "2026-10-22T09:32:44.480482Z"
          session_id: 01a162ef-0dbc-7a73-8470-fca85d4edd33
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3a8c455256e0ff2b7629d578adee08ba30ee6264
        tracker_head: 3821fadb4d0bfac2e58f74dead32cfc4d76e8856
        branch_point: ec4dcf71361ed40c78c76044928d4bea23e5caa3
        since: "2026-10-21T12:06:42-07:00"
        until: "2026-10-22T02:26:10-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T12:06:42-07:00"
              end: "2026-10-22T02:26:10-07:00"
              began: "2026-10-21T12:06:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 1b99335eaa5827bc363ee95e25a035362bebbbd786b5e961c8facf74812f0f85
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 84621855
              windows:
                - start: "2026-10-21T12:06:42-07:00"
                  end: "2026-10-22T02:26:10-07:00"
            - harness: codex
              id: 01a16071-4ff3-73f1-a85c-877dcce84e18
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: b3bc56eccd7a6e133b494338fb84d9e3bdfbaf6b41fac9084ff83a709c1be6c7
              started: "2026-10-21T21:50:01.255Z"
              spawned: true
              bytes: 737767
              windows:
                - start: "2026-10-21T21:50:01.255Z"
                  end: "2026-10-22T02:26:10-07:00"
            - harness: codex
              id: 01a16072-1e8a-7a31-9dbe-dfb1645ad626
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 39bf519351caceeecc6c2a2584290843f7295aca736b8bf32e273cd6f9ebe8ef
              started: "2026-10-21T21:50:54.15Z"
              spawned: true
              bytes: 684168
              windows:
                - start: "2026-10-21T21:50:54.15Z"
                  end: "2026-10-22T02:26:10-07:00"
            - harness: codex
              id: 01a1628b-7e9f-71c3-8466-9f8a6f21229a
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: c15d8537c221cfe217815ee5845c8cc4c14834c97210d19fc7f85e5c94ea278d
              started: "2026-10-22T07:37:51.6Z"
              spawned: true
              bytes: 1012769
              windows:
                - start: "2026-10-22T07:37:51.6Z"
                  end: "2026-10-22T02:26:10-07:00"
            - harness: codex
              id: 01a16296-4bc5-7260-a6b3-83ba61e4c590
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 850a58572bf52bea093bc7725cb7b0f95eb7e6cf4540eea258c1b2e982fb728f
              started: "2026-10-22T07:49:39.482Z"
              spawned: true
              bytes: 851316
              windows:
                - start: "2026-10-22T07:49:39.482Z"
                  end: "2026-10-22T02:26:10-07:00"
        queue_waits:
            - attempt_id: 536b1e6d7e8843d2abd371937cd1b455
              slot: parley.nvim:1
              record_digest: 05b3f8752374a99480876847eec2febb8992d5742bf21f5957f44f227fdbc6de
              start: "2026-10-21T22:35:27.370846Z"
              end: "2026-10-21T23:49:00.808914Z"
              queue_seconds: 4413.438068
              raw_seconds: 4413.438068
              exact: true
        cuts:
            - dispatched: "2026-10-22T00:24:44-07:00"
              finalized: "2026-10-22T00:31:59-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T02:32:45-07:00"
      dispatched: "2026-10-22T02:26:35-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: operator_admission.lua:41-67 preserves the original baseline across retries. The native unavailable → edit/save → refused → confirmed → unchanged-exit regression passes on both runtimes. A disposable baseline-clearing mutation makes three pure tests fail, including the reported sequence.
          round: 2
        - id: BR-2
          disposition: addressed
          note: operator_admission.lua encapsulates authoritative history and witnessed transitions; session_sync.lua:426 executes effects and returns outcomes through that owner. Pure sequence tests, the ownership guard, and the native stale-release regression pass.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The plan's Core-concepts row at line 30 now marks operator_lock as new, and Revisions lines 235-241 records the correction. Base-source inspection confirms the function was absent; the pinned diff adds its definition.
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 3a8c455256e0ff2b7629d578adee08ba30ee6264
      blocked: false
---

# Gate ledger — parley.nvim#408 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T00:31:59-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `acquisition-baseline-preservation` A refused retry discards the baseline and permits release of an unsubmitted edit
  lua/parley/session_sync.lua:532-533 clears baseline when protection is absent and admission changes from unavailable to refused; a subsequent successful acquire at lines 649-659 adopts the saved edited content as its baseline. Reproduced through the production Couch client and executable fake: unavailable acquire → edit and save → refused retry → confirmed retry → unchanged exit removes the lock, whereas the control without the refused retry retains it; preserve the original outstanding baseline across failures and add this regression sequence.
- **BR-2** [Critical] `admission-transition-ownership` Admission state changes bypass an explicit pure transition model
  lua/parley/session_sync.lua:632-675 makes admission decisions inside the IO callback and directly mutates admission, acquire_token, owned_lock, baseline, and unconfirmed_edit; refresh, release_owned, and on_lines independently mutate the same authoritative state. ARCH-ORDER and ARCH-PURE require an encapsulated pure state/event transition component: extract the admission submodel, route its mutations through that component, and test failure/retry/save/release sequences against independent invariants.
- **BR-3** [Critical] `core-concept-traceability` The Core-concepts table marks the new operator_lock function as modified
  workshop/plans/000408-insert-admission-freshness-plan.md:29 classifies operator_lock as modified, but the base contains no such function and the pinned diff adds its definition at lua/parley/couch.lua:103. Correct the status to new and record the correction under Revisions, as required by the Core-concepts cross-check; this correction needs source inspection, not a wording-presence test.

## Round 2 — 2026-10-22T02:32:45-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — operator_admission.lua:41-67 preserves the original baseline across retries. The native unavailable → edit/save → refused → confirmed → unchanged-exit regression passes on both runtimes. A disposable baseline-clearing mutation makes three pure tests fail, including the reported sequence.
- BR-2 — addressed — operator_admission.lua encapsulates authoritative history and witnessed transitions; session_sync.lua:426 executes effects and returns outcomes through that owner. Pure sequence tests, the ownership guard, and the native stale-release regression pass.
- BR-3 — addressed — The plan's Core-concepts row at line 30 now marks operator_lock as new, and Revisions lines 235-241 records the correction. Base-source inspection confirms the function was absent; the pinned diff adds its definition.

## Open findings

(none — every finding has been disposed)
