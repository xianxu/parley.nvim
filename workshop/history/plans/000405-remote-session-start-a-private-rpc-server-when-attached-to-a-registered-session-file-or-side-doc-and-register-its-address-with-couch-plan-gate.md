---
reviewer_runs:
    - version: 1
      intent:
        id: 5b1b1a38-48b0-40eb-8f0e-557fbe0d0fa8
        repository: github.com/xianxu/parley.nvim
        issue_id: "000405"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        reviewed_head: f3e6aae133600f67b800f6c3c4df28f94e043579
        slot: parley.nvim:1
        requested_at: "2026-10-22T12:18:59.818207Z"
      phase: finished
      pid: 78490
      started_at: "2026-10-22T12:18:59.914612Z"
      finished_at: "2026-10-22T12:19:33.000207Z"
      session_id: 01a1638c-e3cf-7b91-a5c2-fb326f3ae063
      outcome: returned
gate: plan-quality
issue: 405
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 1f662517-16ef-4560-a249-eea82f0070b9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: b2cfaf2ce1fdc37bc137b5825f0705f7d79c3e43
            slot: parley.nvim:1
            requested_at: "2026-10-22T12:12:14.516722Z"
          phase: finished
          pid: 7536
          started_at: "2026-10-22T12:12:14.648229Z"
          finished_at: "2026-10-22T12:13:37.519792Z"
          session_id: 01a16386-b503-73f3-934d-1c36ecd543ba
          outcome: returned
      "n": 1
      timestamp: "2026-10-22T05:13:37-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: Define atomic admission to the shared runtime parent
          detail: The plan promises a maximum of 256 process directories but specifies no cross-process reservation or serialization mechanism; concurrent editors can both observe capacity and exceed it. Under ARCH-ORDER and ARCH-CONSTRAINTS, specify the allocation/cleanup transaction, interrupted-owner recovery, and a controlled concurrent-admission test that proves the bound.
          family: shared-resource-admission-serialization
          round: 1
        - id: PQ-2
          severity: Important
          title: Specify the process-inspection seam and startup budget
          detail: The startup sweep adds ps-based death evidence without a named production seam, stateful fake, numeric inspection deadline, or aggregate startup deadline. Under ARCH-MOCK and ARCH-CONSTRAINTS, define asynchronous bounded inspection, its typed uncertain outcomes and cancellation ownership, and controlled sequence tests through the same seam; pure cleanup predicates and a successful kill probe alone do not verify that boundary.
          family: external-process-boundary-contract
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: 8b7f5949-def0-478a-9c5f-c5b9d0e196ec
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: d2df07eafa8fa660538c3fd71ae2263f97e5ba74
            slot: parley.nvim:1
            requested_at: "2026-10-22T12:16:26.604024Z"
          phase: finished
          pid: 53186
          started_at: "2026-10-22T12:16:26.692585Z"
          finished_at: "2026-10-22T12:16:55.857917Z"
          session_id: 01a1638a-8d3e-73c2-8e2a-0aed5bf28af9
          outcome: returned
      "n": 2
      timestamp: "2026-10-22T05:16:56-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: One kernel guard serializes count/create/reclaim; interrupted residue remains counted, with controlled concurrent-admission and owner-death tests.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: The named asynchronous process seam includes stateful doubles, typed uncertainty, numeric inspection/startup deadlines, cancellation ownership and controlled sequence verification.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: 0af70cf0-e59d-484c-80a8-865b4da9bf0a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000405"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: f3e6aae133600f67b800f6c3c4df28f94e043579
            slot: parley.nvim:1
            requested_at: "2026-10-22T12:18:29.721842Z"
          phase: finished
          pid: 73525
          started_at: "2026-10-22T12:18:29.814692Z"
          finished_at: "2026-10-22T12:18:58.928907Z"
          session_id: 01a1638c-6e36-7142-94d2-59f91265ff08
          outcome: returned
      "n": 3
      timestamp: "2026-10-22T05:18:59-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      blocked: false
content_hash: c0b28aa9b77cc5b45edb11571d27cc2e32c013b87796749312569c12735a431e
---

# Gate ledger — parley.nvim#405 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T05:13:37-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `shared-resource-admission-serialization` Define atomic admission to the shared runtime parent
  The plan promises a maximum of 256 process directories but specifies no cross-process reservation or serialization mechanism; concurrent editors can both observe capacity and exceed it. Under ARCH-ORDER and ARCH-CONSTRAINTS, specify the allocation/cleanup transaction, interrupted-owner recovery, and a controlled concurrent-admission test that proves the bound.
- **PQ-2** [Important] `external-process-boundary-contract` Specify the process-inspection seam and startup budget
  The startup sweep adds ps-based death evidence without a named production seam, stateful fake, numeric inspection deadline, or aggregate startup deadline. Under ARCH-MOCK and ARCH-CONSTRAINTS, define asynchronous bounded inspection, its typed uncertain outcomes and cancellation ownership, and controlled sequence tests through the same seam; pure cleanup predicates and a successful kill probe alone do not verify that boundary.

## Round 2 — 2026-10-22T05:16:56-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — One kernel guard serializes count/create/reclaim; interrupted residue remains counted, with controlled concurrent-admission and owner-death tests.
- PQ-2 — addressed — The named asynchronous process seam includes stateful doubles, typed uncertainty, numeric inspection/startup deadlines, cancellation ownership and controlled sequence verification.

## Round 3 — 2026-10-22T05:18:59-07:00 (codex) — passed

## Open findings

(none — every finding has been disposed)
