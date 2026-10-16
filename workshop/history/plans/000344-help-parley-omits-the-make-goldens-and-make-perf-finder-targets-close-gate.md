---
gate: boundary-review
issue: 344
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d7a9e65c-c95e-47ea-8ef7-4e2ede63c88d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000344"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/9a3603f238715332
            reviewed_head: b3ce489106e4353652201bb9cfaa3b396edb8b6e
            slot: parley.nvim:3
            requested_at: "2026-10-16T07:17:13.183632Z"
          phase: finished
          pid: 36732
          started_at: "2026-10-16T07:17:13.490887Z"
          finished_at: "2026-10-16T07:18:06.848572Z"
          session_id: 19e10694-99c4-43f0-a804-2c2e3657f639
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: b3ce489106e4353652201bb9cfaa3b396edb8b6e
        tracker_head: 6f2b180594a0754c937c6642485ee24040479df3
        branch_point: 5c41f37526c2df5e808282f3cbbe8f1cb51c51f4
        since: "2026-10-16T00:15:31-07:00"
        until: "2026-10-16T00:16:20-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T00:15:31-07:00"
              end: "2026-10-16T00:16:20-07:00"
              began: "2026-10-16T00:15:31-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: dce8463375eaf40d7d9e5cb1276567183fa46562d297ba7573502e6c731eb701
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 6942460
              windows:
                - start: "2026-10-16T00:15:31-07:00"
                  end: "2026-10-16T00:16:20-07:00"
      "n": 1
      timestamp: "2026-10-16T00:18:09-07:00"
      dispatched: "2026-10-16T00:17:13-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: help-parley target list is hand-maintained, separate from the target definitions
          detail: This drift (targets added in 342 without help lines) can recur. Generating help from the comment above each target would make the target definitions the single source. Advisory only; the two-line fix is correct as shipped.
          family: help-text-hand-restated
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: b3ce489106e4353652201bb9cfaa3b396edb8b6e
      blocked: false
---

# Gate ledger — parley.nvim#344 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T00:18:09-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `help-text-hand-restated` (kind: defect) help-parley target list is hand-maintained, separate from the target definitions
  This drift (targets added in 342 without help lines) can recur. Generating help from the comment above each target would make the target definitions the single source. Advisory only; the two-line fix is correct as shipped.

## Open findings

- **BR-1** [Minor] `help-text-hand-restated` (kind: defect) help-parley target list is hand-maintained, separate from the target definitions
