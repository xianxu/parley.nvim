---
reviewer_runs:
    - version: 1
      intent:
        id: 5e4b7a7b-452e-4f38-b45c-2f5db88e1809
        repository: github.com/xianxu/parley.nvim
        issue_id: "000319"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        reviewed_head: ba43b312b6242b74f7d6b9193d3b6ca661043346
        slot: parley.nvim:1
        requested_at: "2026-10-16T01:06:07.640357Z"
      phase: finished
      pid: 4241
      started_at: "2026-10-16T01:06:08.212397Z"
      finished_at: "2026-10-16T01:06:32.720542Z"
      session_id: 01a1423e-b822-7e10-98ba-78536ba8f5c3
      outcome: returned
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
    - reviewer_runs:
        - version: 1
          intent:
            id: 01ffcc9e-fbcb-4978-8958-59a3c8fd1744
            repository: github.com/xianxu/parley.nvim
            issue_id: "000319"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: ba43b312b6242b74f7d6b9193d3b6ca661043346
            slot: parley.nvim:1
            requested_at: "2026-10-16T01:02:54.480263Z"
          phase: finished
          pid: 86389
          started_at: "2026-10-16T01:02:54.706161Z"
          finished_at: "2026-10-16T01:03:17.939351Z"
          session_id: 01a1423b-c235-7140-aec0-476b729ef99f
          outcome: returned
      "n": 2
      timestamp: "2026-10-15T18:03:18-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Named function-level strategies cover generator validation, rendering, comparison and instruction.context; integration scenarios are compressed into invariants.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: 854f1fc1-9aa9-4ca0-8ed4-1fd1b09864af
            repository: github.com/xianxu/parley.nvim
            issue_id: "000319"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: ba43b312b6242b74f7d6b9193d3b6ca661043346
            slot: parley.nvim:1
            requested_at: "2026-10-16T01:05:31.660234Z"
          phase: finished
          pid: 335
          started_at: "2026-10-16T01:05:31.890697Z"
          finished_at: "2026-10-16T01:06:06.05499Z"
          session_id: 01a1423e-282c-7252-b50a-a43332482dec
          outcome: returned
      "n": 3
      timestamp: "2026-10-15T18:06:06-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Named risky functions now have adversarial input strategies and mechanical guards, with portable integration coverage for IO and source composition.
          round: 3
      blocked: false
content_hash: 843537d13f5f01eef883fcaf6601c0818495e15b81d1bceb8c86399693f09375
---

# Gate ledger — parley.nvim#319 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T18:01:37-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `function-level-test-strategy` Replace test-case inventories with named function-level strategies
  Execution task 2 enumerates test scenarios, while the new generator names only a script and fixture categories rather than its unit-tested functions. Name the generator validation/transformation functions and give each risky function, including instruction.context, one adversarial-input strategy and mechanical guard; compress the scenario inventory into concise integration invariants. This also makes the ARCH-PURE validation boundary reviewable before implementation.

## Round 2 — 2026-10-15T18:03:18-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Named function-level strategies cover generator validation, rendering, comparison and instruction.context; integration scenarios are compressed into invariants.

## Round 3 — 2026-10-15T18:06:06-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Named risky functions now have adversarial input strategies and mechanical guards, with portable integration coverage for IO and source composition.

## Open findings

(none — every finding has been disposed)
