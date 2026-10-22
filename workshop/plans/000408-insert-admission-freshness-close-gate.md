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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4bd5859c-b143-442e-8d75-0480f6ec28df
            repository: github.com/xianxu/parley.nvim
            issue_id: "000408"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/b936ef8f4f9f6565
            reviewed_head: 4805170dcbd53e6d71529c75ac2a2881f76e2416
            slot: parley.nvim:1
            requested_at: "2026-10-22T09:44:06.968586Z"
          phase: finished
          pid: 48334
          started_at: "2026-10-22T09:44:07.135625Z"
          finished_at: "2026-10-22T09:49:34.004179Z"
          session_id: 01a162ff-1852-7323-88fc-c28fcfef002d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 4805170dcbd53e6d71529c75ac2a2881f76e2416
        tracker_head: 98e63aef11e40d9544be31ee6d397172c8b18a76
        branch_point: ec4dcf71361ed40c78c76044928d4bea23e5caa3
        since: "2026-10-21T12:06:42-07:00"
        until: "2026-10-22T02:42:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T12:06:42-07:00"
              end: "2026-10-22T02:42:59-07:00"
              began: "2026-10-21T12:06:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 88c84d55435094a39081c62f9176ca676f6404d71c06ae427ff77eadecaba4f9
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 85471509
              windows:
                - start: "2026-10-21T12:06:42-07:00"
                  end: "2026-10-22T02:42:59-07:00"
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
                  end: "2026-10-22T02:42:59-07:00"
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
                  end: "2026-10-22T02:42:59-07:00"
            - harness: codex
              id: 01a1628b-7e9f-71c3-8466-9f8a6f21229a
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 7663e7f02b4076d292ff4ed2e251030f9249593e0b26c320cb7603edd7f195d7
              started: "2026-10-22T07:37:51.6Z"
              spawned: true
              bytes: 1100982
              windows:
                - start: "2026-10-22T07:37:51.6Z"
                  end: "2026-10-22T02:42:59-07:00"
            - harness: codex
              id: 01a16296-4bc5-7260-a6b3-83ba61e4c590
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 7c8a492ff6531114234c255c4b7b22f02417a388e5ecee81fd007f666fbf4b90
              started: "2026-10-22T07:49:39.482Z"
              spawned: true
              bytes: 923064
              windows:
                - start: "2026-10-22T07:49:39.482Z"
                  end: "2026-10-22T02:42:59-07:00"
            - harness: codex
              id: 01a162f7-67e1-7a50-85ba-8daa8c35ef7c
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 303270a801d3eabddd06c2ac8f0f335304ef7efbce8b09464a782ed41ef79170
              started: "2026-10-22T09:35:44.09Z"
              spawned: false
              bytes: 684365
              windows:
                - start: "2026-10-22T09:35:44.09Z"
                  end: "2026-10-22T02:42:59-07:00"
            - harness: codex
              id: 01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 91961784f1d11357580eeabce53ebce7105a81491f26295a31c3befcb8027803
              started: "2026-10-22T09:40:48.113Z"
              spawned: false
              bytes: 543557
              windows:
                - start: "2026-10-22T09:40:48.113Z"
                  end: "2026-10-22T02:42:59-07:00"
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
            - dispatched: "2026-10-22T02:26:35-07:00"
              finalized: "2026-10-22T02:32:45-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-22T02:49:34-07:00"
      dispatched: "2026-10-22T02:44:06-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: operator_admission.lua:41–60 preserves the original baseline across retries. The native regression at session_sync_native_spec.lua:301 passes on both runtimes; removing baseline preservation in a disposable checkout caused four pure regression failures.
          round: 3
        - id: BR-2
          disposition: addressed
          note: operator_admission.lua owns private transition state; session_sync.lua dispatches witnessed effects and outcomes. Pure sequence tests and the ownership guard pass, including stale completion rejection and negative bypass fixtures.
          round: 3
        - id: BR-3
          disposition: addressed
          note: The plan's Core concepts table at line 30 correctly marks operator_lock as new. Inspection confirms the function is absent at base and added in couch.lua within the pinned range.
          round: 3
      recipe: milestone-review
      isolation: fenced
      reviewed: 4805170dcbd53e6d71529c75ac2a2881f76e2416
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b3c36491-5539-436b-80f2-849aa15c042e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000408"
            recipe: fix-review
            round: 4
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/3dfcf8ac46f67d27
            reviewed_head: 25674936013026ee64bbb2a366eb197658db07e3
            slot: parley.nvim:1
            requested_at: "2026-10-22T10:11:30.280095Z"
          phase: finished
          pid: 59797
          started_at: "2026-10-22T10:11:30.380226Z"
          finished_at: "2026-10-22T10:12:47.924789Z"
          session_id: 01a16318-2af8-79c0-b79e-edec0f20c505
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 25674936013026ee64bbb2a366eb197658db07e3
        tracker_head: 69aa19fbd6ce27b385a4762368e3e3fdac200259
        branch_point: ec4dcf71361ed40c78c76044928d4bea23e5caa3
        since: "2026-10-21T12:06:42-07:00"
        until: "2026-10-22T03:10:54-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T12:06:42-07:00"
              end: "2026-10-22T03:10:54-07:00"
              began: "2026-10-21T12:06:42-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 0f564b359dafb9a5b34a4da621a4d119b288781b45e4b882e97927087668778c
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 86328568
              windows:
                - start: "2026-10-21T12:06:42-07:00"
                  end: "2026-10-22T03:10:54-07:00"
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
                  end: "2026-10-22T03:10:54-07:00"
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
                  end: "2026-10-22T03:10:54-07:00"
            - harness: codex
              id: 01a1628b-7e9f-71c3-8466-9f8a6f21229a
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 7663e7f02b4076d292ff4ed2e251030f9249593e0b26c320cb7603edd7f195d7
              started: "2026-10-22T07:37:51.6Z"
              spawned: true
              bytes: 1100982
              windows:
                - start: "2026-10-22T07:37:51.6Z"
                  end: "2026-10-22T03:10:54-07:00"
            - harness: codex
              id: 01a16296-4bc5-7260-a6b3-83ba61e4c590
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 7c8a492ff6531114234c255c4b7b22f02417a388e5ecee81fd007f666fbf4b90
              started: "2026-10-22T07:49:39.482Z"
              spawned: true
              bytes: 923064
              windows:
                - start: "2026-10-22T07:49:39.482Z"
                  end: "2026-10-22T03:10:54-07:00"
            - harness: codex
              id: 01a162f7-67e1-7a50-85ba-8daa8c35ef7c
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 303270a801d3eabddd06c2ac8f0f335304ef7efbce8b09464a782ed41ef79170
              started: "2026-10-22T09:35:44.09Z"
              spawned: false
              bytes: 684365
              windows:
                - start: "2026-10-22T09:35:44.09Z"
                  end: "2026-10-22T03:10:54-07:00"
            - harness: codex
              id: 01a162fc-0ab8-72c0-b6ba-cc4baa5e466b
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 91961784f1d11357580eeabce53ebce7105a81491f26295a31c3befcb8027803
              started: "2026-10-22T09:40:48.113Z"
              spawned: false
              bytes: 543557
              windows:
                - start: "2026-10-22T09:40:48.113Z"
                  end: "2026-10-22T03:10:54-07:00"
        queue_waits:
            - attempt_id: 536b1e6d7e8843d2abd371937cd1b455
              slot: parley.nvim:1
              record_digest: 05b3f8752374a99480876847eec2febb8992d5742bf21f5957f44f227fdbc6de
              start: "2026-10-21T22:35:27.370846Z"
              end: "2026-10-21T23:49:00.808914Z"
              queue_seconds: 4413.438068
              raw_seconds: 4413.438068
              exact: true
            - attempt_id: 8d867a863ed97c8b6d9f205529c5a326
              slot: parley.nvim:1
              record_digest: a9e8f6aee5000826c6487874c01d2fb53f8e003e9c94d43145315155cff8fcec
              start: "2026-10-22T09:43:45.25915Z"
              end: "2026-10-22T10:01:41.372072Z"
              queue_seconds: 1076.112922
              raw_seconds: 1076.112922
              exact: true
        cuts:
            - dispatched: "2026-10-22T00:24:44-07:00"
              finalized: "2026-10-22T00:31:59-07:00"
              finalizing: false
            - dispatched: "2026-10-22T02:26:35-07:00"
              finalized: "2026-10-22T02:32:45-07:00"
              finalizing: true
            - dispatched: "2026-10-22T02:44:06-07:00"
              finalized: "2026-10-22T02:49:34-07:00"
              finalizing: true
      "n": 4
      timestamp: "2026-10-22T03:12:48-07:00"
      dispatched: "2026-10-22T03:11:30-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      recipe: fix-review
      isolation: fenced
      reviewed: 25674936013026ee64bbb2a366eb197658db07e3
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

## Round 3 — 2026-10-22T02:49:34-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — operator_admission.lua:41–60 preserves the original baseline across retries. The native regression at session_sync_native_spec.lua:301 passes on both runtimes; removing baseline preservation in a disposable checkout caused four pure regression failures.
- BR-2 — addressed — operator_admission.lua owns private transition state; session_sync.lua dispatches witnessed effects and outcomes. Pure sequence tests and the ownership guard pass, including stale completion rejection and negative bypass fixtures.
- BR-3 — addressed — The plan's Core concepts table at line 30 correctly marks operator_lock as new. Inspection confirms the function is absent at base and added in couch.lua within the pinned range.

## Round 4 — 2026-10-22T03:12:48-07:00 (codex) — passed

## Open findings

(none — every finding has been disposed)
