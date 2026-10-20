---
gate: boundary-review
issue: 398
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 746ea4df-bebc-4d33-abc2-e180fa852ac6
            repository: github.com/xianxu/parley.nvim
            issue_id: "000398"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/f69f9f9b9964edb8
            reviewed_head: 8488538679a6e9759c229979cbd85bc59460961f
            slot: parley.nvim:2
            requested_at: "2026-10-20T05:15:25.013144Z"
          phase: finished
          pid: 2741
          started_at: "2026-10-20T05:15:25.27134Z"
          finished_at: "2026-10-20T05:17:10.425979Z"
          session_id: 01a157bc-6178-7d93-a54c-ccf82a3c06c0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8488538679a6e9759c229979cbd85bc59460961f
        tracker_head: 12a9548fb7ca1a9b3ef88c4526d83b21e9b3bd64
        branch_point: d292a18656c5659e4fb8991cc10511ecc32048b2
        since: "2026-10-19T21:32:47-07:00"
        until: "2026-10-19T22:14:48-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T21:32:47-07:00"
              end: "2026-10-19T22:14:48-07:00"
              began: "2026-10-19T21:32:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 3e3a828ddee5566c1c07974826db89c5caa7285b6b9affce8cbe9658918d204a
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 62837857
              windows:
                - start: "2026-10-19T21:32:47-07:00"
                  end: "2026-10-19T22:14:48-07:00"
        queue_waits:
            - attempt_id: 0293e2d95ffdc19d1ec8cc6989c23d4d
              slot: parley.nvim:2
              record_digest: 59a3110b9ade85fc0dfbcaa82d2921e8e5054e63d5cfd0ec3ce753a375eab194
              start: "2026-10-20T04:37:31.671011Z"
              end: "2026-10-20T05:08:41.863247Z"
              queue_seconds: 1870.192236
              raw_seconds: 1870.192236
              exact: true
      "n": 1
      timestamp: "2026-10-19T22:17:11-07:00"
      dispatched: "2026-10-19T22:15:25-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: README and atlas updates are missing for the compiler-pin surface
          detail: .sdlc/weave-compiler-ref:1 and .github/workflows/merge-check.yml:23 introduce consumer-owned compiler configuration and a new acquisition/build flow, but this range changes neither README.md nor atlas/. Document the pin location, format, bump/recovery procedure and operator verification in README's contributor guidance, and add an indexed repository-owned atlas entry linking the upstream contract. The inherited, ignored atlas/workflow projection does not provide the same-range atlas update required by this review's docs gate.
          family: surface-documentation
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8f15ebb9-55c8-4d9f-a6f2-cd13d671240f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000398"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/c2cf284fc7281b86
            reviewed_head: 79b7328ce077d82d381dd838beaae10ce514774f
            slot: parley.nvim:2
            requested_at: "2026-10-20T05:57:05.648329Z"
          phase: finished
          pid: 20939
          started_at: "2026-10-20T05:57:06.042072Z"
          finished_at: "2026-10-20T05:58:30.944807Z"
          session_id: 01a157e2-8a40-7380-9206-6973682c626c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 79b7328ce077d82d381dd838beaae10ce514774f
        tracker_head: 07ec813f12bb8646826c6029ee7cc2be4ca20047
        branch_point: d292a18656c5659e4fb8991cc10511ecc32048b2
        since: "2026-10-19T21:32:47-07:00"
        until: "2026-10-19T22:56:38-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T21:32:47-07:00"
              end: "2026-10-19T22:56:38-07:00"
              began: "2026-10-19T21:32:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 58f5c55c53188f9fc567a62ec285925ccea538d5f56807003933056e01ed0613
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 63022384
              windows:
                - start: "2026-10-19T21:32:47-07:00"
                  end: "2026-10-19T22:56:38-07:00"
        queue_waits:
            - attempt_id: 0293e2d95ffdc19d1ec8cc6989c23d4d
              slot: parley.nvim:2
              record_digest: 59a3110b9ade85fc0dfbcaa82d2921e8e5054e63d5cfd0ec3ce753a375eab194
              start: "2026-10-20T04:37:31.671011Z"
              end: "2026-10-20T05:08:41.863247Z"
              queue_seconds: 1870.192236
              raw_seconds: 1870.192236
              exact: true
        cuts:
            - dispatched: "2026-10-19T22:15:25-07:00"
              finalized: "2026-10-19T22:17:11-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T22:59:09-07:00"
      dispatched: "2026-10-19T22:57:05-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:190–193 documents the authored pin, format and operator approval; atlas/infra/ci_compiler.md:3–26 explains ownership, verification, updates and recovery, indexed at atlas/index.md:87 and linking the inherited contract at line 28. These passages agree with the workflow’s validation, build and PATH ordering and the manifest’s exclusion of the pin. This is a prose-only correction; no executable regression test is required.
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 79b7328ce077d82d381dd838beaae10ce514774f
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5973844c-31e9-4dda-8e15-2be3bfb54330
            repository: github.com/xianxu/parley.nvim
            issue_id: "000398"
            recipe: fix-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/9140259d91cb3567
            reviewed_head: 1c11c82768b3a0b8aae34ba504ec62f39ede8c71
            slot: parley.nvim:2
            requested_at: "2026-10-20T17:58:31.616538Z"
          phase: finished
          pid: 43349
          started_at: "2026-10-20T17:58:31.823977Z"
          finished_at: "2026-10-20T17:59:33.855145Z"
          session_id: 01a15a77-0603-7393-9dc9-cad9f3964ecd
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 1c11c82768b3a0b8aae34ba504ec62f39ede8c71
        tracker_head: addca9f29e857733c86e7cc24a2ba214a4419ad1
        branch_point: 11b39d8d610dd0976e6c7cc3d35434157b4fe068
        since: "2026-10-19T21:32:47-07:00"
        until: "2026-10-20T10:41:09-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T21:32:47-07:00"
              end: "2026-10-20T10:41:09-07:00"
              began: "2026-10-19T21:32:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 90e8be824e4be2ffb9d6a29a33b710344ade4503744a4fbd93962e646d555d9f
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 63599523
              windows:
                - start: "2026-10-19T21:32:47-07:00"
                  end: "2026-10-20T10:41:09-07:00"
        queue_waits:
            - attempt_id: 0293e2d95ffdc19d1ec8cc6989c23d4d
              slot: parley.nvim:2
              record_digest: 59a3110b9ade85fc0dfbcaa82d2921e8e5054e63d5cfd0ec3ce753a375eab194
              start: "2026-10-20T04:37:31.671011Z"
              end: "2026-10-20T05:08:41.863247Z"
              queue_seconds: 1870.192236
              raw_seconds: 1870.192236
              exact: true
            - attempt_id: 02f09f36d41cb56e9ca7f01170a0045c
              slot: parley.nvim:2
              record_digest: 3a47ecb4135b1976b8cc4018c54e502ac6b432590e509fe4f91ad95de30accfe
              start: "2026-10-20T14:52:31.123865Z"
              end: "2026-10-20T15:15:16.224192Z"
              queue_seconds: 1365.100327
              raw_seconds: 1365.100327
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 58.79061666666667
        cuts:
            - dispatched: "2026-10-19T22:15:25-07:00"
              finalized: "2026-10-19T22:17:11-07:00"
              finalizing: false
            - dispatched: "2026-10-19T22:57:05-07:00"
              finalized: "2026-10-19T22:59:09-07:00"
              finalizing: true
      "n": 3
      timestamp: "2026-10-20T10:59:34-07:00"
      dispatched: "2026-10-20T10:58:31-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:190–193 and indexed atlas/infra/ci_compiler.md retain the compiler configuration guidance. The corrected link at atlas/infra/ci_compiler.md:28 targets atlas/workflow/ci-merge-check.md, verified through git show at approved Ariadne commit 63d6bfd86509d97649e10d7a5dd1e9a06db17d21. This is a prose-only correction.
          round: 3
      recipe: fix-review
      isolation: fenced
      reviewed: 1c11c82768b3a0b8aae34ba504ec62f39ede8c71
      blocked: false
---

# Gate ledger — parley.nvim#398 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T22:17:11-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `surface-documentation` (kind: defect) README and atlas updates are missing for the compiler-pin surface
  .sdlc/weave-compiler-ref:1 and .github/workflows/merge-check.yml:23 introduce consumer-owned compiler configuration and a new acquisition/build flow, but this range changes neither README.md nor atlas/. Document the pin location, format, bump/recovery procedure and operator verification in README's contributor guidance, and add an indexed repository-owned atlas entry linking the upstream contract. The inherited, ignored atlas/workflow projection does not provide the same-range atlas update required by this review's docs gate.

## Round 2 — 2026-10-19T22:59:09-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — README.md:190–193 documents the authored pin, format and operator approval; atlas/infra/ci_compiler.md:3–26 explains ownership, verification, updates and recovery, indexed at atlas/index.md:87 and linking the inherited contract at line 28. These passages agree with the workflow’s validation, build and PATH ordering and the manifest’s exclusion of the pin. This is a prose-only correction; no executable regression test is required.

## Round 3 — 2026-10-20T10:59:34-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — README.md:190–193 and indexed atlas/infra/ci_compiler.md retain the compiler configuration guidance. The corrected link at atlas/infra/ci_compiler.md:28 targets atlas/workflow/ci-merge-check.md, verified through git show at approved Ariadne commit 63d6bfd86509d97649e10d7a5dd1e9a06db17d21. This is a prose-only correction.

## Open findings

(none — every finding has been disposed)
