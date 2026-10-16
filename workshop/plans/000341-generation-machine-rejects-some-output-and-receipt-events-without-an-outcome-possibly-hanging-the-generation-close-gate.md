---
gate: boundary-review
issue: 341
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e7b841d1-62cb-49fb-b3a0-f74d88a12c50
            repository: github.com/xianxu/parley.nvim
            issue_id: "000341"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/97e549d7acb989f8
            reviewed_head: 9f9ef53e22c1459bada56338194af260814fb187
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:25:02.512223Z"
          phase: finished
          pid: 78175
          started_at: "2026-10-16T02:25:02.653988Z"
          finished_at: "2026-10-16T02:27:01.189532Z"
          session_id: 1c4b734c-8a03-4912-a162-0c1220fb65db
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9f9ef53e22c1459bada56338194af260814fb187
        tracker_head: 73c7345de9bac26a27aaf7181cdacf5db9d1004d
        branch_point: 223364394fba895f872f362e7e8fb4d7de4546b4
        since: "2026-10-15T19:13:39-07:00"
        until: "2026-10-15T19:24:39-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T19:13:39-07:00"
              end: "2026-10-15T19:24:39-07:00"
              began: "2026-10-15T19:13:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 10f437e836ecbde30b56906adac8d1aec84fd2e5f2190b22592ae7d67650ce21
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 3833992
              windows:
                - start: "2026-10-15T19:13:39-07:00"
                  end: "2026-10-15T19:24:39-07:00"
      "n": 1
      timestamp: "2026-10-15T19:27:08-07:00"
      dispatched: "2026-10-15T19:25:02-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: Receipt validity clauses are stated twice in generation.lua write_result
          detail: generation.lua:353-360 re-checks attempted>=1, attempted<=pending.bytes, integer(committed), committed<0 and committed>attempted inside the branch the outer guard already entered (ARCH-DRY). Two local predicates (bounds_ok, status_ok) would state each rule once. Only instance in the window.
          family: duplicated-validity-predicate
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Missing-blob uncertain branch in generation_runner write() has no test
          detail: generation_runner.lua:421-431, both the write dispatch and the manual_append effect.done path. Reverting generation_runner.lua leaves every test green. The Log says it is unreachable by construction, so this is acceptable, but no test runs the branch.
          family: defensive-branch-untested
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: 9f9ef53e22c1459bada56338194af260814fb187
      blocked: false
---

# Gate ledger — parley.nvim#341 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T19:27:08-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `duplicated-validity-predicate` (kind: defect) Receipt validity clauses are stated twice in generation.lua write_result
  generation.lua:353-360 re-checks attempted>=1, attempted<=pending.bytes, integer(committed), committed<0 and committed>attempted inside the branch the outer guard already entered (ARCH-DRY). Two local predicates (bounds_ok, status_ok) would state each rule once. Only instance in the window.
- **BR-2** [Minor] `defensive-branch-untested` (kind: defect) Missing-blob uncertain branch in generation_runner write() has no test
  generation_runner.lua:421-431, both the write dispatch and the manual_append effect.done path. Reverting generation_runner.lua leaves every test green. The Log says it is unreachable by construction, so this is acceptable, but no test runs the branch.

## Open findings

- **BR-1** [Minor] `duplicated-validity-predicate` (kind: defect) Receipt validity clauses are stated twice in generation.lua write_result
- **BR-2** [Minor] `defensive-branch-untested` (kind: defect) Missing-blob uncertain branch in generation_runner write() has no test
