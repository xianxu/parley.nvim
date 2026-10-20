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
---

# Gate ledger — parley.nvim#398 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T22:17:11-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `surface-documentation` (kind: defect) README and atlas updates are missing for the compiler-pin surface
  .sdlc/weave-compiler-ref:1 and .github/workflows/merge-check.yml:23 introduce consumer-owned compiler configuration and a new acquisition/build flow, but this range changes neither README.md nor atlas/. Document the pin location, format, bump/recovery procedure and operator verification in README's contributor guidance, and add an indexed repository-owned atlas entry linking the upstream contract. The inherited, ignored atlas/workflow projection does not provide the same-range atlas update required by this review's docs gate.

## Open findings

- **BR-1** [Important] `surface-documentation` (kind: defect) README and atlas updates are missing for the compiler-pin surface
