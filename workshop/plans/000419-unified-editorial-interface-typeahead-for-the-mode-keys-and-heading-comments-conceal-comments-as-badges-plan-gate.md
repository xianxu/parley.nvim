---
gate: plan-quality
issue: 419
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 9d17da70-2833-401e-a1a1-3088109c06c5
            repository: github.com/xianxu/parley.nvim
            issue_id: "000419"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 917ccfc3e7cde3782077fa544612dc257a5aa0a5
            slot: parley.nvim:3
            requested_at: "2026-10-24T00:32:08.351373Z"
          phase: finished
          pid: 32169
          started_at: "2026-10-24T00:32:08.451324Z"
          finished_at: "2026-10-24T00:33:30.268918Z"
          session_id: 01a16b52-761f-76f3-93a8-cb001412d341
          outcome: returned
      "n": 1
      timestamp: "2026-10-23T17:33:30-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: Replace prose case inventories with named function test strategies
          detail: The implementation tasks enumerate test cases but generally name only modules and test files. Name each risky production function to unit-test and give one strategy line identifying its adversarial input class and mechanical guard; retain pinned fixtures as executable oracles and remove the prose case inventories.
          family: function-level-test-strategy
          round: 1
        - id: PQ-2
          severity: Important
          title: Bound whole-document parsing on the render path
          detail: 'ARCH-CONSTRAINTS: the plan permits a whole-document parse per render batch, but supplies neither an accepted latency/input budget with a stated basis nor bounded behavior when exceeded. The existing 256-row paint limit does not bound parsing work; specify the render-path budget and oversized-input or over-budget behavior before implementation.'
          family: explicit-runtime-envelope
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#419 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T17:33:30-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace prose case inventories with named function test strategies
  The implementation tasks enumerate test cases but generally name only modules and test files. Name each risky production function to unit-test and give one strategy line identifying its adversarial input class and mechanical guard; retain pinned fixtures as executable oracles and remove the prose case inventories.
- **PQ-2** [Important] `explicit-runtime-envelope` Bound whole-document parsing on the render path
  ARCH-CONSTRAINTS: the plan permits a whole-document parse per render batch, but supplies neither an accepted latency/input budget with a stated basis nor bounded behavior when exceeded. The existing 256-row paint limit does not bound parsing work; specify the render-path budget and oversized-input or over-budget behavior before implementation.

## Open findings

- **PQ-1** [Important] `function-level-test-strategy` Replace prose case inventories with named function test strategies
- **PQ-2** [Important] `explicit-runtime-envelope` Bound whole-document parsing on the render path
