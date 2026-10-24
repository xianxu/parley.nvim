---
reviewer_runs:
    - version: 1
      intent:
        id: 9777fcf7-5cde-47cd-8b9a-ce058be9b9a0
        repository: github.com/xianxu/parley.nvim
        issue_id: "000419"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        reviewed_head: e78037174a733b8180aca3cc325c3290e64e68ee
        slot: parley.nvim:3
        requested_at: "2026-10-24T00:37:16.041865Z"
      phase: finished
      pid: 19693
      started_at: "2026-10-24T00:37:16.197541Z"
      finished_at: "2026-10-24T00:37:45.595938Z"
      session_id: 01a16b57-2899-7771-9dce-5d1ec9cd8f53
      outcome: returned
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
    - reviewer_runs:
        - version: 1
          intent:
            id: abb5a894-c33e-4b44-a2e2-9fb4f95c8993
            repository: github.com/xianxu/parley.nvim
            issue_id: "000419"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: e78037174a733b8180aca3cc325c3290e64e68ee
            slot: parley.nvim:3
            requested_at: "2026-10-24T00:35:27.425246Z"
          phase: finished
          pid: 85045
          started_at: "2026-10-24T00:35:27.567124Z"
          finished_at: "2026-10-24T00:35:49.230785Z"
          session_id: 01a16b55-8036-77d1-bd45-44425a58ff21
          outcome: returned
      "n": 2
      timestamp: "2026-10-23T17:35:49-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Named function strategies replace prose case inventories and retain pinned executable oracles.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Pre-parse size admission, approved workload basis, visible degradation and blocking latency qualification bound render-path parsing.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: deff6121-9d9b-4965-a394-15c109ca3ba2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000419"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: e78037174a733b8180aca3cc325c3290e64e68ee
            slot: parley.nvim:3
            requested_at: "2026-10-24T00:36:45.843733Z"
          phase: finished
          pid: 12029
          started_at: "2026-10-24T00:36:45.995023Z"
          finished_at: "2026-10-24T00:37:13.780016Z"
          session_id: 01a16b56-b2bc-7da3-bcea-5bc9bc7b58e7
          outcome: returned
      "n": 3
      timestamp: "2026-10-23T17:37:14-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Named function-level strategies replace prose case inventories.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Render parsing has pre-read admission, visible degradation, counted growth controls and a measured latency gate.
          round: 3
      blocked: false
content_hash: 8e23fc8e5092b4ba705b3955172ea063804424183d08f5cbeaa0fbb4c8287b80
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

## Round 2 — 2026-10-23T17:35:49-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Named function strategies replace prose case inventories and retain pinned executable oracles.
- PQ-2 — addressed — Pre-parse size admission, approved workload basis, visible degradation and blocking latency qualification bound render-path parsing.

## Round 3 — 2026-10-23T17:37:14-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Named function-level strategies replace prose case inventories.
- PQ-2 — addressed — Render parsing has pre-read admission, visible degradation, counted growth controls and a measured latency gate.

## Open findings

(none — every finding has been disposed)
