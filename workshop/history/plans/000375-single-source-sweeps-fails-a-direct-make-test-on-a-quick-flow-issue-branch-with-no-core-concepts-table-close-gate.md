---
gate: boundary-review
issue: 375
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: cb8647a9-7303-4ab3-b7bb-4ea1065ffd8d
            repository: github.com/xianxu/parley.nvim
            issue_id: "000375"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/dcf99c939e609e8b
            reviewed_head: c6708d6f26f4d3a6e803ea45579c932c6d495c55
            slot: parley.nvim:3
            requested_at: "2026-10-17T13:25:30.422447Z"
          phase: finished
          pid: 77759
          started_at: "2026-10-17T13:25:30.595834Z"
          finished_at: "2026-10-17T13:28:57.183803Z"
          session_id: ffd1c960-7a5a-44e1-a0c8-5479c8d0dd36
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: c6708d6f26f4d3a6e803ea45579c932c6d495c55
        tracker_head: cf7e989940d071591a0dbb472219c54fec985f37
        branch_point: 3cd5f862bca097262961a519083271acde75ea3c
        since: "2026-10-17T05:45:26-07:00"
        until: "2026-10-17T05:47:17-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T05:45:26-07:00"
              end: "2026-10-17T05:47:17-07:00"
              began: "2026-10-17T05:45:26-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 941444a8441d3d7680db9b6090dc57acf524176a7afc5c8b89e50d085986218d
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 25109899
              windows:
                - start: "2026-10-17T05:45:26-07:00"
                  end: "2026-10-17T05:47:17-07:00"
      "n": 1
      timestamp: "2026-10-17T06:28:58-07:00"
      dispatched: "2026-10-17T06:25:30-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: 'Quick-flow tables whose rows don''t start with a backtick (#330, #331) still fail the plan-to-code case, and the sibling code-to-table case fails on quick-flow branches'
          detail: 'concept_rows counts a Status-headed table but keeps only rows starting with a backtick. #330 and #331 (both quick flow, rows like "| Lock baseline | ...") give tables=1, rows=0, so make test still fails with the wrong message "has no rows" (13 workshop docs have this shape, including active plan 000209). Instances in this file: (a) the assert at single_source_sweeps_spec.lua:383; (b) the sibling code-to-table case at :171-244, which uses a second table definition (the "## Core concepts" section scan at :174) and fails on any quick-flow branch that adds an M.x export. Fix: count rows of any shape for the floor (or name the no-backtick case in the message), and have the sibling case use concept_rows and go pending when tables == 0. ARCH-DRY, ARCH-PURPOSE.'
          family: core-concepts-guard-misreads-quick-flow-docs
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: When the issue has no docs at all, the pending reason wrongly says there is no Core-concepts table (quick flow)
          detail: 'At single_source_sweeps_spec.lua:377-380, tables == 0 also covers the case #docs == 0, and the pending message then blames the quick flow. The sibling case handles this separately at :144-147. Reuse that wording.'
          family: pending-reason-mislabels-cause
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 78b8a365-0036-4d97-b830-f78170dc1e40
            repository: github.com/xianxu/parley.nvim
            issue_id: "000375"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/6e5e32216947c3c8
            reviewed_head: 847a807c5ffd5ede0730be6f61e19484927db9db
            slot: parley.nvim:3
            requested_at: "2026-10-17T13:30:30.811227Z"
          phase: finished
          pid: 48166
          started_at: "2026-10-17T13:30:31.139309Z"
          finished_at: "2026-10-17T13:39:13.812995Z"
          session_id: b8c6660b-0425-4280-8f58-cb1b6985ea88
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 847a807c5ffd5ede0730be6f61e19484927db9db
        tracker_head: cf7e989940d071591a0dbb472219c54fec985f37
        branch_point: 3cd5f862bca097262961a519083271acde75ea3c
        since: "2026-10-17T05:45:26-07:00"
        until: "2026-10-17T06:29:50-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T05:45:26-07:00"
              end: "2026-10-17T06:29:50-07:00"
              began: "2026-10-17T05:45:26-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: da36c49474c10f2e0ddda3a13f0df46f69a219742988c8162fb91fcfd8df5d49
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 25252604
              windows:
                - start: "2026-10-17T05:45:26-07:00"
                  end: "2026-10-17T06:29:50-07:00"
        cuts:
            - dispatched: "2026-10-17T06:25:30-07:00"
              finalized: "2026-10-17T06:28:58-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T06:39:14-07:00"
      dispatched: "2026-10-17T06:30:30-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: concept_rows keeps rows of any shape and the sibling reads through it; the new spec fails when the backtick-only filter is restored (checked by reverting).
          round: 2
        - id: BR-2
          disposition: addressed
          note: A separate pending for no docs was added at :317-320, matching the sibling's wording at :144-147.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Minor
          title: The pending reason at :181 and :389 blames "quick flow" when the measured condition is that no table has a Status header
          detail: '2nd finding in this family. Rule: a pending reason states the condition the code measured, not a guessed cause. Instances: single_source_sweeps_spec.lua:181 and :389. Measured prevalence: 6 archived issue docs (e.g. 000226, 000243, 000329, 000343, 000347, 000348) have a Core concepts section whose table lacks a Status column and would be mislabelled. Fix both sites to say something like "no Status-headed Core-concepts table".'
          family: pending-reason-mislabels-cause
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 847a807c5ffd5ede0730be6f61e19484927db9db
      blocked: false
---

# Gate ledger — parley.nvim#375 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T06:28:58-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `core-concepts-guard-misreads-quick-flow-docs` (kind: defect) Quick-flow tables whose rows don't start with a backtick (#330, #331) still fail the plan-to-code case, and the sibling code-to-table case fails on quick-flow branches
  concept_rows counts a Status-headed table but keeps only rows starting with a backtick. #330 and #331 (both quick flow, rows like "| Lock baseline | ...") give tables=1, rows=0, so make test still fails with the wrong message "has no rows" (13 workshop docs have this shape, including active plan 000209). Instances in this file: (a) the assert at single_source_sweeps_spec.lua:383; (b) the sibling code-to-table case at :171-244, which uses a second table definition (the "## Core concepts" section scan at :174) and fails on any quick-flow branch that adds an M.x export. Fix: count rows of any shape for the floor (or name the no-backtick case in the message), and have the sibling case use concept_rows and go pending when tables == 0. ARCH-DRY, ARCH-PURPOSE.
- **BR-2** [Minor] `pending-reason-mislabels-cause` (kind: defect) When the issue has no docs at all, the pending reason wrongly says there is no Core-concepts table (quick flow)
  At single_source_sweeps_spec.lua:377-380, tables == 0 also covers the case #docs == 0, and the pending message then blames the quick flow. The sibling case handles this separately at :144-147. Reuse that wording.

## Round 2 — 2026-10-17T06:39:14-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — concept_rows keeps rows of any shape and the sibling reads through it; the new spec fails when the backtick-only filter is restored (checked by reverting).
- BR-2 — addressed — A separate pending for no docs was added at :317-320, matching the sibling's wording at :144-147.

### Raised

- **BR-3** [Minor] `pending-reason-mislabels-cause` (kind: defect) The pending reason at :181 and :389 blames "quick flow" when the measured condition is that no table has a Status header
  2nd finding in this family. Rule: a pending reason states the condition the code measured, not a guessed cause. Instances: single_source_sweeps_spec.lua:181 and :389. Measured prevalence: 6 archived issue docs (e.g. 000226, 000243, 000329, 000343, 000347, 000348) have a Core concepts section whose table lacks a Status column and would be mislabelled. Fix both sites to say something like "no Status-headed Core-concepts table".

## Open findings

- **BR-3** [Minor] `pending-reason-mislabels-cause` (kind: defect) The pending reason at :181 and :389 blames "quick flow" when the measured condition is that no table has a Status header
