---
gate: boundary-review
issue: 346
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 3117e5c5-cdf3-495e-816e-54a6923560cb
            repository: github.com/xianxu/parley.nvim
            issue_id: "000346"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/ee0779d02f604bdf
            reviewed_head: c22db1af4f86c379beb39948aa8eeb2f1e46c3e0
            slot: parley.nvim:3
            requested_at: "2026-10-16T08:49:27.952314Z"
          phase: finished
          pid: 58425
          started_at: "2026-10-16T08:49:28.108235Z"
          finished_at: "2026-10-16T08:53:28.811008Z"
          session_id: a5d0fadc-042f-4a98-81a2-14312b5b7ff5
          outcome: returned
        - version: 1
          intent:
            disposable_root: true
            id: 0421706e-dbd4-4e98-909b-8ca3c463cea3
            repository: github.com/xianxu/parley.nvim
            issue_id: "000346"
            recipe: small-diff-review
            round: 1
            attempt: 2
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/ee0779d02f604bdf
            reviewed_head: c22db1af4f86c379beb39948aa8eeb2f1e46c3e0
            slot: parley.nvim:3
            requested_at: "2026-10-16T08:53:43.152556Z"
          phase: finished
          pid: 6577
          started_at: "2026-10-16T08:53:43.409728Z"
          finished_at: "2026-10-16T09:00:00.154047Z"
          session_id: 0c454ac8-bf37-4a67-847a-c9dde4afb8ee
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c22db1af4f86c379beb39948aa8eeb2f1e46c3e0
        tracker_head: def113a7ccaf518635e1dce0705cd174f3b04694
        branch_point: 96d8a99f336f3a79c74df98cdd98f9ff927a67b7
        since: "2026-10-16T01:21:45-07:00"
        until: "2026-10-16T01:48:57-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T01:21:45-07:00"
              end: "2026-10-16T01:21:55-07:00"
              began: "2026-10-16T01:21:45-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            - start: "2026-10-16T01:47:00-07:00"
              end: "2026-10-16T01:48:57-07:00"
              began: "2026-10-16T01:47:00-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ff58f446c44e693b890f8bb89cf7ca1c0126950d69e74b892c9a3b7b3a94b783
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 8170789
              windows:
                - start: "2026-10-16T01:21:45-07:00"
                  end: "2026-10-16T01:21:55-07:00"
                - start: "2026-10-16T01:47:00-07:00"
                  end: "2026-10-16T01:48:57-07:00"
      "n": 1
      timestamp: "2026-10-16T02:00:03-07:00"
      dispatched: "2026-10-16T01:49:27-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: await_ready accepts any parseable prefix of the pid line, not a confirmed-complete record
          detail: 'At tests/integration/packaging_launcher_spec.lua:63, a torn read like "12" of "12345" would parse and return the wrong pid. That is unlikely because a single small write() is effectively atomic on local filesystems. Fix: have the barrier write a temp file and rename it, or require the pid to be the same on two polls. This is the only instance in the window.'
          family: barrier-record-read-before-complete
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: c22db1af4f86c379beb39948aa8eeb2f1e46c3e0
      blocked: false
---

# Gate ledger — parley.nvim#346 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T02:00:03-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `barrier-record-read-before-complete` (kind: defect) await_ready accepts any parseable prefix of the pid line, not a confirmed-complete record
  At tests/integration/packaging_launcher_spec.lua:63, a torn read like "12" of "12345" would parse and return the wrong pid. That is unlikely because a single small write() is effectively atomic on local filesystems. Fix: have the barrier write a temp file and rename it, or require the pid to be the same on two polls. This is the only instance in the window.

## Open findings

- **BR-1** [Minor] `barrier-record-read-before-complete` (kind: defect) await_ready accepts any parseable prefix of the pid line, not a confirmed-complete record
