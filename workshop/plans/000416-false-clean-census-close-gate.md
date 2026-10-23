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

## Open findings

- **BR-1** [Critical] `persisted-unknown-value-preservation` (kind: defect) Birth publication silently changes unknown JSON numbers
- **BR-2** [Important] `atomic-capacity-admission` (kind: defect) Concurrent scope allocation exceeds the census's accepted capacity
