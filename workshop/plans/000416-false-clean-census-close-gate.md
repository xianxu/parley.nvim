---
gate: boundary-review
issue: 416
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e1c7fb82-1315-418e-8fae-37974686dfad
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/1b0508c8bbc76e8d
            reviewed_head: 3cffa5e844a392b8e0299d823262e6e09c913fdb
            slot: parley.nvim:3
            requested_at: "2026-10-23T00:03:45.256108Z"
          phase: finished
          pid: 23091
          started_at: "2026-10-23T00:03:45.41282Z"
          finished_at: "2026-10-23T00:07:59.865664Z"
          session_id: 01a16612-1e7a-7f61-a615-d30fec32f83c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3cffa5e844a392b8e0299d823262e6e09c913fdb
        tracker_head: 9e66cffb8b1729bf8f889b146dd99a752b8e3103
        branch_point: 1752271061691fd0780994a45b93d46463c8c747
        since: "2026-10-22T16:14:29-07:00"
        until: "2026-10-22T17:03:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T16:14:29-07:00"
              end: "2026-10-22T17:03:21-07:00"
              began: "2026-10-22T16:14:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d43302d0777677026f331d42f809845c8c2997456b5f08e40acba73b2a24feaf
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 9760396
              windows:
                - start: "2026-10-22T16:14:29-07:00"
                  end: "2026-10-22T17:03:21-07:00"
            - harness: codex
              id: 01a165e9-7944-7bf0-a615-1ffaba584dd0
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d6f8e5a09f33eb611d6289ffcdcbed98f52c5bdb4be81dbc539a7338272f7766
              started: "2026-10-22T23:19:23.106Z"
              spawned: false
              bytes: 617194
              windows:
                - start: "2026-10-22T23:19:23.106Z"
                  end: "2026-10-22T17:03:21-07:00"
            - harness: codex
              id: 01a165eb-9540-75d0-8d38-10b11d67edd1
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 561f3cb3852b0645f02607dd0d4afbde3e39cf8d3840b4cdf36125ca541926ba
              started: "2026-10-22T23:21:40.848Z"
              spawned: false
              bytes: 500977
              windows:
                - start: "2026-10-22T23:21:40.848Z"
                  end: "2026-10-22T17:03:21-07:00"
            - harness: codex
              id: 01a165ec-83eb-71f1-ba11-6c087e76b404
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 741c368cec0dfa98a537a1fbf87540a1c8503f67d19ada0f19414109598bb872
              started: "2026-10-22T23:22:41.875Z"
              spawned: false
              bytes: 450161
              windows:
                - start: "2026-10-22T23:22:41.875Z"
                  end: "2026-10-22T17:03:21-07:00"
            - harness: codex
              id: 01a165ec-e7d1-7b71-a305-93fb695efdaf
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 4041fe919424ad69568f55115592d08794f1ae6e550d6ced9f065a9f77b38a3d
              started: "2026-10-22T23:23:07.433Z"
              spawned: false
              bytes: 379419
              windows:
                - start: "2026-10-22T23:23:07.433Z"
                  end: "2026-10-22T17:03:21-07:00"
            - harness: codex
              id: 01a165ed-7d8d-7312-8f92-c9b2853a593f
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: 63f540fa8a9cbc9f607104928390b902a007b6141394ab2547ad0e1397f35b15
              started: "2026-10-22T23:23:45.497Z"
              spawned: true
              bytes: 824585
              windows:
                - start: "2026-10-22T23:23:45.497Z"
                  end: "2026-10-22T17:03:21-07:00"
      "n": 1
      timestamp: "2026-10-22T17:08:01-07:00"
      dispatched: "2026-10-22T17:03:45-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Birth publication silently changes unknown JSON numbers
          detail: tests/helpers/test_processes.lua:111 re-encodes unknown fields through Lua numbers, violating ARCH-EVOLVE and the plan's preservation contract. Calling prepare(), writing a pending record containing future.number=9007199254740993, then complete() produces future.number=9007199254740992. Preserve unknown numeric tokens losslessly, including nested values, and add a regression whose oracle does not use the same lossy decoder.
          family: persisted-unknown-value-preservation
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Concurrent scope allocation exceeds the census's accepted capacity
          detail: tests/helpers/test_processes.lua:242 checks the scope count separately from fs_mkdtemp(). With 63 existing scopes and two callers synchronized after enumeration, both allocations succeed, producing 65 scopes against the default limit of 64. The terminal verifier then exits 2 with "registry entry limit reached" before reconciling records. Make capacity reservation atomic across parallel runners and add a controlled concurrent-admission regression (ARCH-CONSTRAINTS, ARCH-ORDER).
          family: atomic-capacity-admission
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b0ae51fe-05cf-4bd9-b6d6-c97d4f499528
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/a5a3b318e5c94607
            reviewed_head: fee0af023b597fded78c36facb08c559085aaf5b
            slot: parley.nvim:3
            requested_at: "2026-10-23T00:12:30.056533Z"
          phase: finished
          pid: 59533
          started_at: "2026-10-23T00:12:30.216475Z"
          finished_at: "2026-10-23T00:16:08.418423Z"
          session_id: 01a1661a-2022-7700-b88e-50d198b40adb
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: fee0af023b597fded78c36facb08c559085aaf5b
        tracker_head: 9e66cffb8b1729bf8f889b146dd99a752b8e3103
        branch_point: 1752271061691fd0780994a45b93d46463c8c747
        since: "2026-10-22T16:14:29-07:00"
        until: "2026-10-22T17:11:54-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T16:14:29-07:00"
              end: "2026-10-22T17:11:54-07:00"
              began: "2026-10-22T16:14:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a6ba95f98080086609ff475d69c191dcf362df85e6acff1fb2d0e4a577160916
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 10372633
              windows:
                - start: "2026-10-22T16:14:29-07:00"
                  end: "2026-10-22T17:11:54-07:00"
            - harness: codex
              id: 01a165e9-7944-7bf0-a615-1ffaba584dd0
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d6f8e5a09f33eb611d6289ffcdcbed98f52c5bdb4be81dbc539a7338272f7766
              started: "2026-10-22T23:19:23.106Z"
              spawned: false
              bytes: 617194
              windows:
                - start: "2026-10-22T23:19:23.106Z"
                  end: "2026-10-22T17:11:54-07:00"
            - harness: codex
              id: 01a165eb-9540-75d0-8d38-10b11d67edd1
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 561f3cb3852b0645f02607dd0d4afbde3e39cf8d3840b4cdf36125ca541926ba
              started: "2026-10-22T23:21:40.848Z"
              spawned: false
              bytes: 500977
              windows:
                - start: "2026-10-22T23:21:40.848Z"
                  end: "2026-10-22T17:11:54-07:00"
            - harness: codex
              id: 01a165ec-83eb-71f1-ba11-6c087e76b404
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 741c368cec0dfa98a537a1fbf87540a1c8503f67d19ada0f19414109598bb872
              started: "2026-10-22T23:22:41.875Z"
              spawned: false
              bytes: 450161
              windows:
                - start: "2026-10-22T23:22:41.875Z"
                  end: "2026-10-22T17:11:54-07:00"
            - harness: codex
              id: 01a165ec-e7d1-7b71-a305-93fb695efdaf
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 4041fe919424ad69568f55115592d08794f1ae6e550d6ced9f065a9f77b38a3d
              started: "2026-10-22T23:23:07.433Z"
              spawned: false
              bytes: 379419
              windows:
                - start: "2026-10-22T23:23:07.433Z"
                  end: "2026-10-22T17:11:54-07:00"
            - harness: codex
              id: 01a165ed-7d8d-7312-8f92-c9b2853a593f
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: fd2af9187728f0e77096ab0a74c93feb2012f6d157dd7b18af0f2a19d9f7a027
              started: "2026-10-22T23:23:45.497Z"
              spawned: true
              bytes: 1006247
              windows:
                - start: "2026-10-22T23:23:45.497Z"
                  end: "2026-10-22T17:11:54-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0748
        cuts:
            - dispatched: "2026-10-22T17:03:45-07:00"
              finalized: "2026-10-22T17:08:01-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-22T17:16:09-07:00"
      dispatched: "2026-10-22T17:12:30-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Publication preserves validated raw unknown-member slices. The numeric-text regression passes at head and fails with the preceding module, exposing 9007199254740993 becoming 9007199254740992.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Atomic mkdir reserves canonical bounded slots. The controlled two-allocator regression passes at head and fails with the preceding module because both callers are admitted.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Important
          title: Concurrent scope retirement incorrectly rejects healthy admission
          detail: 'tests/helpers/test_processes.lua:273-277 treats every failed lstat of an enumerated scope as invalid evidence. Reproduced on both runtimes: pause allocation after fs_scandir, prune an existing empty spec-1, then resume; scope() returns nil with "unknown or legacy registry scope" despite available capacity. spec_runner.lua:66 consequently returns code 125 before launching the spec; parallel suite workers routinely allocate while siblings retire. This is the 2nd finding in family atomic-capacity-admission. State and enforce the admission rule across allocation/allocation, allocation/retirement and retirement/reuse interleavings: explicit ENOENT from concurrent retirement must permit continued atomic reservation, while unreadable or invalid existing evidence must still refuse. Add controlled regressions covering that enumeration.'
          family: atomic-capacity-admission
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 6f3ed058-4759-4ec0-9b2e-cc5a5c1287df
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/78387e119bab7542
            reviewed_head: 1496bc76b22612512de5a0ec69ade29d97f862e2
            slot: parley.nvim:3
            requested_at: "2026-10-23T00:20:02.050227Z"
          phase: finished
          pid: 6630
          started_at: "2026-10-23T00:20:02.222364Z"
          finished_at: "2026-10-23T00:23:21.862488Z"
          session_id: 01a16621-05a4-7ce1-b558-1be0c347b56c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1496bc76b22612512de5a0ec69ade29d97f862e2
        tracker_head: 9e66cffb8b1729bf8f889b146dd99a752b8e3103
        branch_point: 1752271061691fd0780994a45b93d46463c8c747
        since: "2026-10-22T16:14:29-07:00"
        until: "2026-10-22T17:19:34-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T16:14:29-07:00"
              end: "2026-10-22T17:19:34-07:00"
              began: "2026-10-22T16:14:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 6f9856d8b60ed878077928927458035a7a75dd47bbd595033bf7ea5b598e1da7
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 10758172
              windows:
                - start: "2026-10-22T16:14:29-07:00"
                  end: "2026-10-22T17:19:34-07:00"
            - harness: codex
              id: 01a165e9-7944-7bf0-a615-1ffaba584dd0
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d6f8e5a09f33eb611d6289ffcdcbed98f52c5bdb4be81dbc539a7338272f7766
              started: "2026-10-22T23:19:23.106Z"
              spawned: false
              bytes: 617194
              windows:
                - start: "2026-10-22T23:19:23.106Z"
                  end: "2026-10-22T17:19:34-07:00"
            - harness: codex
              id: 01a165eb-9540-75d0-8d38-10b11d67edd1
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 561f3cb3852b0645f02607dd0d4afbde3e39cf8d3840b4cdf36125ca541926ba
              started: "2026-10-22T23:21:40.848Z"
              spawned: false
              bytes: 500977
              windows:
                - start: "2026-10-22T23:21:40.848Z"
                  end: "2026-10-22T17:19:34-07:00"
            - harness: codex
              id: 01a165ec-83eb-71f1-ba11-6c087e76b404
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 741c368cec0dfa98a537a1fbf87540a1c8503f67d19ada0f19414109598bb872
              started: "2026-10-22T23:22:41.875Z"
              spawned: false
              bytes: 450161
              windows:
                - start: "2026-10-22T23:22:41.875Z"
                  end: "2026-10-22T17:19:34-07:00"
            - harness: codex
              id: 01a165ec-e7d1-7b71-a305-93fb695efdaf
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 4041fe919424ad69568f55115592d08794f1ae6e550d6ced9f065a9f77b38a3d
              started: "2026-10-22T23:23:07.433Z"
              spawned: false
              bytes: 379419
              windows:
                - start: "2026-10-22T23:23:07.433Z"
                  end: "2026-10-22T17:19:34-07:00"
            - harness: codex
              id: 01a165ed-7d8d-7312-8f92-c9b2853a593f
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: c0c78c175ef436e0a42b848649a937448060e601414d014d8f4dd51653f59245
              started: "2026-10-22T23:23:45.497Z"
              spawned: true
              bytes: 1150579
              windows:
                - start: "2026-10-22T23:23:45.497Z"
                  end: "2026-10-22T17:19:34-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0748
        cuts:
            - dispatched: "2026-10-22T17:03:45-07:00"
              finalized: "2026-10-22T17:08:01-07:00"
              finalizing: false
            - dispatched: "2026-10-22T17:12:30-07:00"
              finalized: "2026-10-22T17:16:09-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-22T17:23:22-07:00"
      dispatched: "2026-10-22T17:20:02-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Raw unknown-member preservation remains intact; numeric-token and nested-value regressions pass on both runtimes.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Atomic mkdir reserves canonical bounded slots; simultaneous final-slot admission tests pass on both runtimes.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Explicit ENOENT permits reservation while unreadable metadata refuses. All nine scope tests pass on both runtimes; restoring the pre-fix helper makes both retirement regressions fail on each runtime.
          round: 3
      findings:
        - kind: defect
          id: BR-4
          severity: Important
          title: New lease regressions fail when scratch uses a symlinked path
          detail: 'tests/unit/test_run_lease.py:172,186,230,304 compare or inject unresolved fixture paths, while registry_base resolves paths. On macOS, TMPDIR=/tmp makes all four newly added context/ownership tests fail: returned paths use /private/tmp, the valid inherited context is rejected, and the ownership fake misses its target. ARCH-MOCK: the fake and production code must identify the same fixture. Reproduced with TMPDIR=/tmp python3 -B tests/unit/test_run_lease.py; the mapped infra/test_harness run also fails. Canonicalize the shared fixture base at line 29 and cover aliased scratch paths. In a disposable pinned-head copy, adding resolve() there makes all 26 lease tests pass under TMPDIR=/tmp.'
          family: fixture-path-identity
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 7e1d058c-1028-440f-a110-b97f36d1b27b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/2d7132c9889e5802
            reviewed_head: 8548f3b68b79592f013367172bc4340d66cfd6b7
            slot: parley.nvim:3
            requested_at: "2026-10-23T00:26:52.014579Z"
          phase: finished
          pid: 14375
          started_at: "2026-10-23T00:26:52.124904Z"
          finished_at: "2026-10-23T00:30:25.376961Z"
          session_id: 01a16627-469e-7a42-a4fc-ea0a0c63c5e6
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8548f3b68b79592f013367172bc4340d66cfd6b7
        tracker_head: 9e66cffb8b1729bf8f889b146dd99a752b8e3103
        branch_point: 1752271061691fd0780994a45b93d46463c8c747
        since: "2026-10-22T16:14:29-07:00"
        until: "2026-10-22T17:26:16-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-22T16:14:29-07:00"
              end: "2026-10-22T17:26:16-07:00"
              began: "2026-10-22T16:14:29-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: codex
              id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: cb60a0999a2c3608b6349c61d327aeb92f3c43ab1e403673b32ae053721c7220
              started: "2026-10-20T18:04:41.786Z"
              spawned: false
              bytes: 11132545
              windows:
                - start: "2026-10-22T16:14:29-07:00"
                  end: "2026-10-22T17:26:16-07:00"
            - harness: codex
              id: 01a165e9-7944-7bf0-a615-1ffaba584dd0
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d6f8e5a09f33eb611d6289ffcdcbed98f52c5bdb4be81dbc539a7338272f7766
              started: "2026-10-22T23:19:23.106Z"
              spawned: false
              bytes: 617194
              windows:
                - start: "2026-10-22T23:19:23.106Z"
                  end: "2026-10-22T17:26:16-07:00"
            - harness: codex
              id: 01a165eb-9540-75d0-8d38-10b11d67edd1
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 561f3cb3852b0645f02607dd0d4afbde3e39cf8d3840b4cdf36125ca541926ba
              started: "2026-10-22T23:21:40.848Z"
              spawned: false
              bytes: 500977
              windows:
                - start: "2026-10-22T23:21:40.848Z"
                  end: "2026-10-22T17:26:16-07:00"
            - harness: codex
              id: 01a165ec-83eb-71f1-ba11-6c087e76b404
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 741c368cec0dfa98a537a1fbf87540a1c8503f67d19ada0f19414109598bb872
              started: "2026-10-22T23:22:41.875Z"
              spawned: false
              bytes: 450161
              windows:
                - start: "2026-10-22T23:22:41.875Z"
                  end: "2026-10-22T17:26:16-07:00"
            - harness: codex
              id: 01a165ec-e7d1-7b71-a305-93fb695efdaf
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 4041fe919424ad69568f55115592d08794f1ae6e550d6ced9f065a9f77b38a3d
              started: "2026-10-22T23:23:07.433Z"
              spawned: false
              bytes: 379419
              windows:
                - start: "2026-10-22T23:23:07.433Z"
                  end: "2026-10-22T17:26:16-07:00"
            - harness: codex
              id: 01a165ed-7d8d-7312-8f92-c9b2853a593f
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              parent_id: 01a15a7c-a7ef-7492-9684-887d55dc4a8d
              digest: c0c78c175ef436e0a42b848649a937448060e601414d014d8f4dd51653f59245
              started: "2026-10-22T23:23:45.497Z"
              spawned: true
              bytes: 1150579
              windows:
                - start: "2026-10-22T23:23:45.497Z"
                  end: "2026-10-22T17:26:16-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 15.0748
        cuts:
            - dispatched: "2026-10-22T17:03:45-07:00"
              finalized: "2026-10-22T17:08:01-07:00"
              finalizing: false
            - dispatched: "2026-10-22T17:12:30-07:00"
              finalized: "2026-10-22T17:16:09-07:00"
              finalizing: false
            - dispatched: "2026-10-22T17:20:02-07:00"
              finalized: "2026-10-22T17:23:22-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-22T17:30:26-07:00"
      dispatched: "2026-10-22T17:26:52-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Publication preserves raw unknown JSON member bytes; numeric-token and nested-value regressions pass at the pinned head.
          round: 4
        - id: BR-2
          disposition: addressed
          note: Atomic mkdir reserves finite canonical scope slots; the controlled two-allocator regression passes on both runtimes.
          round: 4
        - id: BR-3
          disposition: addressed
          note: Explicit ENOENT permits admission after retirement; controlled retirement, reuse, contention and unreadable-entry tests pass on both runtimes.
          round: 4
        - id: BR-4
          disposition: addressed
          note: tests/unit/test_run_lease.py:29 canonicalizes shared fixture identity. The explicit symlink regression at line 513 passes; removing only resolve() in a disposable pinned-head copy makes it fail with six underlying assertions. All 27 lease tests pass with TMPDIR=/tmp; the disposable copy was removed.
          round: 4
      recipe: milestone-review
      isolation: fenced
      reviewed: 8548f3b68b79592f013367172bc4340d66cfd6b7
      blocked: false
---

# Gate ledger — parley.nvim#416 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T17:08:01-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `persisted-unknown-value-preservation` (kind: defect) Birth publication silently changes unknown JSON numbers
  tests/helpers/test_processes.lua:111 re-encodes unknown fields through Lua numbers, violating ARCH-EVOLVE and the plan's preservation contract. Calling prepare(), writing a pending record containing future.number=9007199254740993, then complete() produces future.number=9007199254740992. Preserve unknown numeric tokens losslessly, including nested values, and add a regression whose oracle does not use the same lossy decoder.
- **BR-2** [Important] `atomic-capacity-admission` (kind: defect) Concurrent scope allocation exceeds the census's accepted capacity
  tests/helpers/test_processes.lua:242 checks the scope count separately from fs_mkdtemp(). With 63 existing scopes and two callers synchronized after enumeration, both allocations succeed, producing 65 scopes against the default limit of 64. The terminal verifier then exits 2 with "registry entry limit reached" before reconciling records. Make capacity reservation atomic across parallel runners and add a controlled concurrent-admission regression (ARCH-CONSTRAINTS, ARCH-ORDER).

## Round 2 — 2026-10-22T17:16:09-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Publication preserves validated raw unknown-member slices. The numeric-text regression passes at head and fails with the preceding module, exposing 9007199254740993 becoming 9007199254740992.
- BR-2 — addressed — Atomic mkdir reserves canonical bounded slots. The controlled two-allocator regression passes at head and fails with the preceding module because both callers are admitted.

### Raised

- **BR-3** [Important] `atomic-capacity-admission` (kind: defect) Concurrent scope retirement incorrectly rejects healthy admission
  tests/helpers/test_processes.lua:273-277 treats every failed lstat of an enumerated scope as invalid evidence. Reproduced on both runtimes: pause allocation after fs_scandir, prune an existing empty spec-1, then resume; scope() returns nil with "unknown or legacy registry scope" despite available capacity. spec_runner.lua:66 consequently returns code 125 before launching the spec; parallel suite workers routinely allocate while siblings retire. This is the 2nd finding in family atomic-capacity-admission. State and enforce the admission rule across allocation/allocation, allocation/retirement and retirement/reuse interleavings: explicit ENOENT from concurrent retirement must permit continued atomic reservation, while unreadable or invalid existing evidence must still refuse. Add controlled regressions covering that enumeration.

## Round 3 — 2026-10-22T17:23:22-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Raw unknown-member preservation remains intact; numeric-token and nested-value regressions pass on both runtimes.
- BR-2 — addressed — Atomic mkdir reserves canonical bounded slots; simultaneous final-slot admission tests pass on both runtimes.
- BR-3 — addressed — Explicit ENOENT permits reservation while unreadable metadata refuses. All nine scope tests pass on both runtimes; restoring the pre-fix helper makes both retirement regressions fail on each runtime.

### Raised

- **BR-4** [Important] `fixture-path-identity` (kind: defect) New lease regressions fail when scratch uses a symlinked path
  tests/unit/test_run_lease.py:172,186,230,304 compare or inject unresolved fixture paths, while registry_base resolves paths. On macOS, TMPDIR=/tmp makes all four newly added context/ownership tests fail: returned paths use /private/tmp, the valid inherited context is rejected, and the ownership fake misses its target. ARCH-MOCK: the fake and production code must identify the same fixture. Reproduced with TMPDIR=/tmp python3 -B tests/unit/test_run_lease.py; the mapped infra/test_harness run also fails. Canonicalize the shared fixture base at line 29 and cover aliased scratch paths. In a disposable pinned-head copy, adding resolve() there makes all 26 lease tests pass under TMPDIR=/tmp.

## Round 4 — 2026-10-22T17:30:26-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Publication preserves raw unknown JSON member bytes; numeric-token and nested-value regressions pass at the pinned head.
- BR-2 — addressed — Atomic mkdir reserves finite canonical scope slots; the controlled two-allocator regression passes on both runtimes.
- BR-3 — addressed — Explicit ENOENT permits admission after retirement; controlled retirement, reuse, contention and unreadable-entry tests pass on both runtimes.
- BR-4 — addressed — tests/unit/test_run_lease.py:29 canonicalizes shared fixture identity. The explicit symlink regression at line 513 passes; removing only resolve() in a disposable pinned-head copy makes it fail with six underlying assertions. All 27 lease tests pass with TMPDIR=/tmp; the disposable copy was removed.

## Open findings

(none — every finding has been disposed)
