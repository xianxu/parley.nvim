---
gate: plan-quality
issue: 319
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 10f89fd5-1c04-49bf-b558-9a9bc83a09cf
            repository: github.com/xianxu/parley.nvim
            issue_id: "000319"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: d19b082b99247350ae696d619b2bf335b68020a8
            slot: parley.nvim:1
            requested_at: "2026-10-16T01:00:42.662938Z"
          phase: finished
          pid: 73515
          started_at: "2026-10-16T01:00:42.863874Z"
          finished_at: "2026-10-16T01:01:37.222668Z"
          session_id: 01a14239-bf1b-7bf0-ab35-87bfe0a9c79e
          outcome: returned
      "n": 1
      timestamp: "2026-10-15T18:01:37-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Replace test-case inventories with named function-level strategies
          detail: Execution task 2 enumerates test scenarios, while the new generator names only a script and fixture categories rather than its unit-tested functions. Name the generator validation/transformation functions and give each risky function, including instruction.context, one adversarial-input strategy and mechanical guard; compress the scenario inventory into concise integration invariants. This also makes the ARCH-PURE validation boundary reviewable before implementation.
          family: function-level-test-strategy
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#319 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T18:01:37-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace test-case inventories with named function-level strategies
  Execution task 2 enumerates test scenarios, while the new generator names only a script and fixture categories rather than its unit-tested functions. Name the generator validation/transformation functions and give each risky function, including instruction.context, one adversarial-input strategy and mechanical guard; compress the scenario inventory into concise integration invariants. This also makes the ARCH-PURE validation boundary reviewable before implementation.

## Open findings

- **PQ-1** [Important] `function-level-test-strategy` Replace test-case inventories with named function-level strategies
