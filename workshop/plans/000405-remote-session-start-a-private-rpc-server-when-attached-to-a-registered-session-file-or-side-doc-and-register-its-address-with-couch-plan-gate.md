---
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

## Open findings

- **PQ-1** [Important] `shared-resource-admission-serialization` Define atomic admission to the shared runtime parent
- **PQ-2** [Important] `external-process-boundary-contract` Specify the process-inspection seam and startup budget
