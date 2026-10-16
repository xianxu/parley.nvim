---
gate: boundary-review
issue: 348
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e1083162-f294-401e-8801-4f59d7f79821
            repository: github.com/xianxu/parley.nvim
            issue_id: "000348"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/805e2331b8f9fa23
            reviewed_head: 030ca6380c1a92b867f409496792a6169d73032b
            slot: parley.nvim:3
            requested_at: "2026-10-16T10:07:00.431694Z"
          phase: finished
          pid: 47367
          started_at: "2026-10-16T10:07:00.661537Z"
          finished_at: "2026-10-16T10:13:34.027571Z"
          session_id: 1d73f8dd-7324-47c5-8ead-a8cece219e8e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 030ca6380c1a92b867f409496792a6169d73032b
        tracker_head: 3a34863088579e3d0aec6558b1a8686fa3955faf
        branch_point: 0a616029f43d1a239f5a46bb3fc0b42a129dcd9a
        since: "2026-10-16T02:14:02-07:00"
        until: "2026-10-16T03:06:11-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T02:14:02-07:00"
              end: "2026-10-16T02:14:09-07:00"
              began: "2026-10-16T02:14:02-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            - start: "2026-10-16T03:01:05-07:00"
              end: "2026-10-16T03:06:11-07:00"
              began: "2026-10-16T03:01:05-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 636e07afe6ef559cfaeb2920ce60db888d742444a69af965a816f3fe40f102ba
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 9040151
              windows:
                - start: "2026-10-16T03:01:05-07:00"
                  end: "2026-10-16T03:06:11-07:00"
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: b96085e1aa15b3137bfdc3785335cf2077b485da60ade351581c066517aafc67
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 4896965
              windows:
                - start: "2026-10-16T02:14:02-07:00"
                  end: "2026-10-16T02:14:09-07:00"
      "n": 1
      timestamp: "2026-10-16T03:13:35-07:00"
      dispatched: "2026-10-16T03:07:00-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Waiter lock-identity re-check (ino/dev) has no test that fails without it
          detail: 'With the check changed from `same and (...)` to `stat and (...)` at lua/parley/starter.lua:131, all 21 starter_config cases still pass. The case it protects (an owner retires or replaces the lock between the waiter''s lstat and its owner read) is never reached: under the new code the RETIRE gate fires only after the lock is renamed away. Add a waiter-side gate, e.g. a hook on the waiter''s io.open of welcome-initializer/owner that pauses after the first lstat, release the owner meanwhile, and assert the waiter exits 0. This is the only behavior in the window without red-test evidence.'
          family: behavior-change-without-red-test
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Gate test names and the atlas garbage-lock claim describe the old model
          detail: 'starter_config_spec.lua:200 and :204 say the waiter waits for an owner mid-take or mid-retire, but under the new code neither gate leaves a lock visible: the second starter takes the lock itself, or the lock is already gone. atlas/infra/starter.md:168 says a lock with no valid owner is garbage, but an empty lock is silently replaced by rename (starter.lua:99-100). Neither place notes that an older starter caught between mkdir and its owner write could be replaced, after which both proceed.'
          family: doc-claim-drift
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#348 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T03:13:35-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `behavior-change-without-red-test` (kind: defect) Waiter lock-identity re-check (ino/dev) has no test that fails without it
  With the check changed from `same and (...)` to `stat and (...)` at lua/parley/starter.lua:131, all 21 starter_config cases still pass. The case it protects (an owner retires or replaces the lock between the waiter's lstat and its owner read) is never reached: under the new code the RETIRE gate fires only after the lock is renamed away. Add a waiter-side gate, e.g. a hook on the waiter's io.open of welcome-initializer/owner that pauses after the first lstat, release the owner meanwhile, and assert the waiter exits 0. This is the only behavior in the window without red-test evidence.
- **BR-2** [Minor] `doc-claim-drift` (kind: defect) Gate test names and the atlas garbage-lock claim describe the old model
  starter_config_spec.lua:200 and :204 say the waiter waits for an owner mid-take or mid-retire, but under the new code neither gate leaves a lock visible: the second starter takes the lock itself, or the lock is already gone. atlas/infra/starter.md:168 says a lock with no valid owner is garbage, but an empty lock is silently replaced by rename (starter.lua:99-100). Neither place notes that an older starter caught between mkdir and its owner write could be replaced, after which both proceed.

## Open findings

- **BR-1** [Important] `behavior-change-without-red-test` (kind: defect) Waiter lock-identity re-check (ino/dev) has no test that fails without it
- **BR-2** [Minor] `doc-claim-drift` (kind: defect) Gate test names and the atlas garbage-lock claim describe the old model
