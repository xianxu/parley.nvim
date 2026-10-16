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
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: b90aaeab-d5a1-4aaa-aed5-09baf32e81d8
            repository: github.com/xianxu/parley.nvim
            issue_id: "000341"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/ee7c57602710afdf
            reviewed_head: 2d0efab84cd098fc657a4327886d28cc59f8368e
            slot: parley.nvim:3
            requested_at: "2026-10-16T02:28:13.7645Z"
          phase: finished
          pid: 99486
          started_at: "2026-10-16T02:28:13.867288Z"
          finished_at: "2026-10-16T02:30:06.323815Z"
          session_id: 458c1097-2660-4b7e-ae87-e1d2bd8a2ab8
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2d0efab84cd098fc657a4327886d28cc59f8368e
        tracker_head: 988eed88ee1c6ef9babde7299a521d17ccfdd680
        branch_point: 223364394fba895f872f362e7e8fb4d7de4546b4
        since: "2026-10-15T19:13:39-07:00"
        until: "2026-10-15T19:27:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T19:13:39-07:00"
              end: "2026-10-15T19:27:59-07:00"
              began: "2026-10-15T19:13:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: e3bd327c08c1642f633af9e46a2568ca2fd6000a5bf5d483f04169d7acf67089
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 3901767
              windows:
                - start: "2026-10-15T19:13:39-07:00"
                  end: "2026-10-15T19:27:59-07:00"
        cuts:
            - dispatched: "2026-10-15T19:25:02-07:00"
              finalized: "2026-10-15T19:27:08-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-15T19:30:06-07:00"
      dispatched: "2026-10-15T19:28:13-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 2d0efab8 computes validity once as `counted` (generation.lua:353-354) and uses it for both the uncertain decision and the credit. Behavior-neutral refactor; reverting generation.lua fails 3 generation_spec tests, so the rule stays pinned.
          round: 2
        - id: BR-2
          disposition: withdrawn
          note: 'The unreachability argument holds: stop() releases only s.queue items (generation.lua:87-90) and the inflight item is never in the queue, so its blob is freed only after its receipt. Adding a runner seam just to test that branch is worse than the gap; the decision is recorded in the Log.'
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: 2d0efab84cd098fc657a4327886d28cc59f8368e
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

## Round 2 — 2026-10-15T19:30:06-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — 2d0efab8 computes validity once as `counted` (generation.lua:353-354) and uses it for both the uncertain decision and the credit. Behavior-neutral refactor; reverting generation.lua fails 3 generation_spec tests, so the rule stays pinned.
- BR-2 — withdrawn — The unreachability argument holds: stop() releases only s.queue items (generation.lua:87-90) and the inflight item is never in the queue, so its blob is freed only after its receipt. Adding a runner seam just to test that branch is worse than the gap; the decision is recorded in the Log.

## Open findings

(none — every finding has been disposed)
