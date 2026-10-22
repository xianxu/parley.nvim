---
gate: plan-quality
issue: 408
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 7af85595-169c-42a2-886a-a94811082a92
            repository: github.com/xianxu/parley.nvim
            issue_id: "000408"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: 618a9f5743b2d4e43f3d24a94d030cd387801869
            slot: parley.nvim:1
            requested_at: "2026-10-22T09:35:43.192943Z"
          phase: finished
          pid: 63175
          started_at: "2026-10-22T09:35:43.293251Z"
          finished_at: "2026-10-22T09:36:48.952018Z"
          session_id: 01a162f7-67e1-7a50-85ba-8daa8c35ef7c
          outcome: returned
      "n": 1
      timestamp: "2026-10-22T02:36:49-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: Replace prose test-case inventories with named-function strategies
          detail: The durable plan's Tasks 1–2 enumerate test cases instead of providing the required concise strategies. Name operator_admission's dispatch/snapshot, couch.operator_result, couch.operator_proof, and couch.operator_lock, giving each its adversarial input class and mechanical guard; summarize native admission/freshness ordering separately. Preserve the state-transition contract and acceptance criteria, but compress the prose case inventories.
          family: function-level-test-strategy
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#408 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T02:36:49-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace prose test-case inventories with named-function strategies
  The durable plan's Tasks 1–2 enumerate test cases instead of providing the required concise strategies. Name operator_admission's dispatch/snapshot, couch.operator_result, couch.operator_proof, and couch.operator_lock, giving each its adversarial input class and mechanical guard; summarize native admission/freshness ordering separately. Preserve the state-transition contract and acceptance criteria, but compress the prose case inventories.

## Open findings

- **PQ-1** [Important] `function-level-test-strategy` Replace prose test-case inventories with named-function strategies
