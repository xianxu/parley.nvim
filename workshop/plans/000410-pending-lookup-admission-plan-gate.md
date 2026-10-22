---
gate: plan-quality
issue: 410
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 95c54b9f-ddbb-4968-bfee-aa28badb3630
            repository: github.com/xianxu/parley.nvim
            issue_id: "000410"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            reviewed_head: d786021763058f5ca814ec06b0f211ef7fab9c83
            slot: parley.nvim:4
            requested_at: "2026-10-22T19:28:40.160182Z"
          phase: finished
          pid: 51303
          started_at: "2026-10-22T19:28:40.282437Z"
          finished_at: "2026-10-22T19:29:38.987125Z"
          session_id: 01a16516-448a-7a02-a048-a98b58514a1c
          outcome: returned
      "n": 1
      timestamp: "2026-10-22T12:29:39-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: Specify the history-preserving legacy-to-registered handoff
          detail: Revision step 4 proposes ordinary release followed by reacquisition, but operator_admission.dispatch clears all history on released (lua/parley/operator_admission.lua:78–80), including observations applied before release. Name the owner-controlled transition sequence and define retained baseline/content, freshness eligibility and protection outcome after release failure, successful release followed by expiry/refusal/unavailability, and foreign replacement. Replace the conditional “If this cannot preserve history/failure semantics” with an executable decision; name dispatch sequence tests that verify independently stated history invariants under controlled failures (ARCH-PURE/ORDER).
          family: ownership-handoff-preserves-history
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace test-case inventories with named function strategies
          detail: The remaining_ms paragraph, Tasks 1–2 and revision step 5 enumerate individual test cases and outcome combinations rather than the required compact strategies. Compress these into named functions under test and one adversarial-input or event-sequence strategy with a mechanical guard per risky function, including the revised admission handoff; retain production-order native coverage and measured deadline/count assertions without a prose case inventory.
          family: test-plan-strategy-over-enumeration
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#410 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T12:29:39-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `ownership-handoff-preserves-history` Specify the history-preserving legacy-to-registered handoff
  Revision step 4 proposes ordinary release followed by reacquisition, but operator_admission.dispatch clears all history on released (lua/parley/operator_admission.lua:78–80), including observations applied before release. Name the owner-controlled transition sequence and define retained baseline/content, freshness eligibility and protection outcome after release failure, successful release followed by expiry/refusal/unavailability, and foreign replacement. Replace the conditional “If this cannot preserve history/failure semantics” with an executable decision; name dispatch sequence tests that verify independently stated history invariants under controlled failures (ARCH-PURE/ORDER).
- **PQ-2** [Important] `test-plan-strategy-over-enumeration` Replace test-case inventories with named function strategies
  The remaining_ms paragraph, Tasks 1–2 and revision step 5 enumerate individual test cases and outcome combinations rather than the required compact strategies. Compress these into named functions under test and one adversarial-input or event-sequence strategy with a mechanical guard per risky function, including the revised admission handoff; retain production-order native coverage and measured deadline/count assertions without a prose case inventory.

## Open findings

- **PQ-1** [Important] `ownership-handoff-preserves-history` Specify the history-preserving legacy-to-registered handoff
- **PQ-2** [Important] `test-plan-strategy-over-enumeration` Replace test-case inventories with named function strategies
