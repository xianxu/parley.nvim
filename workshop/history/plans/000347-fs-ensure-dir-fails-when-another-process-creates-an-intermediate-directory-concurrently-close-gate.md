---
gate: boundary-review
issue: 347
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 74705fb6-3462-4860-ab84-4f6c20789f80
            repository: github.com/xianxu/parley.nvim
            issue_id: "000347"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/7022b662f7868166
            reviewed_head: 3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd
            slot: parley.nvim:3
            requested_at: "2026-10-16T09:13:58.187132Z"
          phase: finished
          pid: 64486
          started_at: "2026-10-16T09:13:58.341512Z"
          finished_at: "2026-10-16T09:16:05.656871Z"
          session_id: cc8f3590-5a69-4a19-a23a-1d967fd9d73d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd
        tracker_head: 59cde2edf771ff24378f9faa0dcba35c785d7e8e
        branch_point: 9e31a35c874aba9fcdae0d38002d162cab056bf5
        since: "2026-10-16T02:04:31-07:00"
        until: "2026-10-16T02:13:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T02:04:31-07:00"
              end: "2026-10-16T02:04:40-07:00"
              began: "2026-10-16T02:04:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            - start: "2026-10-16T02:11:15-07:00"
              end: "2026-10-16T02:13:30-07:00"
              began: "2026-10-16T02:11:15-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 48c0e21e99dc1bee209e8f2ad3ada584e49f72412a62835c38bb132fe7efefa9
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 8544786
              windows:
                - start: "2026-10-16T02:04:31-07:00"
                  end: "2026-10-16T02:04:40-07:00"
                - start: "2026-10-16T02:11:15-07:00"
                  end: "2026-10-16T02:13:30-07:00"
      "n": 1
      timestamp: "2026-10-16T02:16:08-07:00"
      dispatched: "2026-10-16T02:13:58-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: ensure_dir_race_spec header cites "8 of 180" but the spec runs 120 creators
          detail: tests/integration/ensure_dir_race_spec.lua:4 restates the Log's 6x30 measurement while the spec loops 20 rounds x 6. Only count claim in the window; say where it came from or use the spec's own numbers.
          family: doc-claim-unverified-count
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: No test for a real failure (file in the way) at an INTERMEDIATE level
          detail: The "still raises a real failure" clause is tested only at the leaf (prepare_dir_spec "rejects a file obstructing", "preserves the original mkdir error"). Add a case where root/file is a regular file and ensure_dir(root/file/child) raises, which exercises mkdir_level's raise on a non-leaf level.
          family: done-when-both-modes-coverage
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd
      blocked: false
---

# Gate ledger — parley.nvim#347 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T02:16:08-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-unverified-count` (kind: defect) ensure_dir_race_spec header cites "8 of 180" but the spec runs 120 creators
  tests/integration/ensure_dir_race_spec.lua:4 restates the Log's 6x30 measurement while the spec loops 20 rounds x 6. Only count claim in the window; say where it came from or use the spec's own numbers.
- **BR-2** [Minor] `done-when-both-modes-coverage` (kind: defect) No test for a real failure (file in the way) at an INTERMEDIATE level
  The "still raises a real failure" clause is tested only at the leaf (prepare_dir_spec "rejects a file obstructing", "preserves the original mkdir error"). Add a case where root/file is a regular file and ensure_dir(root/file/child) raises, which exercises mkdir_level's raise on a non-leaf level.

## Open findings

- **BR-1** [Minor] `doc-claim-unverified-count` (kind: defect) ensure_dir_race_spec header cites "8 of 180" but the spec runs 120 creators
- **BR-2** [Minor] `done-when-both-modes-coverage` (kind: defect) No test for a real failure (file in the way) at an INTERMEDIATE level
