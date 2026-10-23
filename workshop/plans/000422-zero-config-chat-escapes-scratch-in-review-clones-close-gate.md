---
gate: boundary-review
issue: 422
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 83bc23b6-a3ec-4828-a2f1-7bf4f1081007
            repository: github.com/xianxu/parley.nvim
            issue_id: "000422"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/1486cb91ba8f4dd1
            reviewed_head: 50ed7eba83107880c5e83904deccbdc4129547b1
            slot: parley.nvim:1
            requested_at: "2026-10-23T09:12:02.00237Z"
          phase: finished
          pid: 81740
          started_at: "2026-10-23T09:12:02.099614Z"
          finished_at: "2026-10-23T09:15:59.833907Z"
          session_id: af374464-a5bf-4c28-a251-4541dd731a59
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 50ed7eba83107880c5e83904deccbdc4129547b1
        tracker_head: 5f759acbc94e08110a124e0276c75b770c98f77f
        branch_point: 091392db58ad91f7f937e2e977d496894beab962
        since: "2026-10-23T01:58:47-07:00"
        until: "2026-10-23T02:11:25-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T01:58:47-07:00"
              end: "2026-10-23T02:11:25-07:00"
              began: "2026-10-23T01:58:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: b84fe0cf68940bc4fc2caec5fec9e85da93ab10077c9e1ec1d150c3ac57612b9
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 2057579
              windows:
                - start: "2026-10-23T01:58:47-07:00"
                  end: "2026-10-23T02:11:25-07:00"
      "n": 1
      timestamp: "2026-10-23T02:16:00-07:00"
      dispatched: "2026-10-23T02:12:02-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: test-placement.sh treats any existing .parley (file or dir) as a marker; detect_root only counts a readable file
          detail: scripts/test-placement.sh:32 uses [ -e ] while lua/parley/repo_mode.lua:8 uses filereadable, so the guard refuses scratch under a .parley directory the product ignores, contradicting the plan and atlas claim (atlas/infra/test_harness.md:60) that the two state the same rule. Use [ -f ] && [ -r ] and add a directory-marker case to tests/arch/scratch_placement_spec.lua.
          family: guard-rule-diverges-from-product-predicate
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: 50ed7eba83107880c5e83904deccbdc4129547b1
      blocked: false
---

# Gate ledger — parley.nvim#422 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T02:16:00-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `guard-rule-diverges-from-product-predicate` (kind: defect) test-placement.sh treats any existing .parley (file or dir) as a marker; detect_root only counts a readable file
  scripts/test-placement.sh:32 uses [ -e ] while lua/parley/repo_mode.lua:8 uses filereadable, so the guard refuses scratch under a .parley directory the product ignores, contradicting the plan and atlas claim (atlas/infra/test_harness.md:60) that the two state the same rule. Use [ -f ] && [ -r ] and add a directory-marker case to tests/arch/scratch_placement_spec.lua.

## Open findings

- **BR-1** [Minor] `guard-rule-diverges-from-product-predicate` (kind: defect) test-placement.sh treats any existing .parley (file or dir) as a marker; detect_root only counts a readable file
