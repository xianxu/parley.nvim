---
gate: plan-quality
issue: 418
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 385eb6e4-d5fd-4868-92c8-7c544fa30efe
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: f71eebac0f562a1e05c658c0930aa4804219ac37
            slot: parley.nvim:3
            requested_at: "2026-10-23T10:17:07.933521Z"
          phase: finished
          pid: 72019
          started_at: "2026-10-23T10:17:08.087003Z"
          finished_at: "2026-10-23T10:18:27.061239Z"
          session_id: 01a16843-aea0-7920-96a7-5d9a440c147c
          outcome: returned
      "n": 1
      timestamp: "2026-10-23T03:18:27-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: 'ARCH-ORDER: preparation edits cancel the save operation they belong to'
          detail: The plan places insertion inside the accepted save effect, but agentic_document.lua:467–481 dispatches changed for buffer edits while busy; document_session.lua:230–253 cancels save, leaving its later saved event ignored. Specify a narrowly scoped ownership/transition mechanism for preparation edits that preserves unrelated-edit invalidation, and verify it with the real buffer observer plus deterministic interruption coverage.
          family: owned-edit-operation-validity
          round: 1
        - id: PQ-2
          severity: Important
          title: Compress test inventories into named function strategies
          detail: Plan lines 107 and 116 enumerate test cases rather than supplying the required strategy per risky function. Name the tested resolver, filler, header scanner and changed reader functions; give each its adversarial input class and mechanical guard, using generated malformed headers and reproducible event ordering where applicable.
          family: function-test-strategy
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: 77dfd4b5-b6cb-483d-9a21-e8346aa440de
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 4f749db943509b02f05f1b7d41d89ff6ddb0fc17
            slot: parley.nvim:3
            requested_at: "2026-10-23T10:23:54.586532Z"
          phase: finished
          pid: 11011
          started_at: "2026-10-23T10:23:54.716455Z"
          finished_at: "2026-10-23T10:24:26.419477Z"
          session_id: 01a16849-e2e5-78e3-b96e-38f5a790946e
          outcome: returned
      "n": 2
      timestamp: "2026-10-23T03:24:26-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Explicit witnessed preparation recognizes only its exact observed edit before save; unrelated edits still cancel, with deterministic real-observer verification required.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Function strategies replace case inventories with adversarial generators, independent mechanical guards and reproducible production-event ordering.
          round: 2
      blocked: false
content_hash: 7b6add5d21668bff182b625d28ee07981aa55e8698e717f14364373d4fd9eac1
---

# Gate ledger — parley.nvim#418 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T03:18:27-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `owned-edit-operation-validity` ARCH-ORDER: preparation edits cancel the save operation they belong to
  The plan places insertion inside the accepted save effect, but agentic_document.lua:467–481 dispatches changed for buffer edits while busy; document_session.lua:230–253 cancels save, leaving its later saved event ignored. Specify a narrowly scoped ownership/transition mechanism for preparation edits that preserves unrelated-edit invalidation, and verify it with the real buffer observer plus deterministic interruption coverage.
- **PQ-2** [Important] `function-test-strategy` Compress test inventories into named function strategies
  Plan lines 107 and 116 enumerate test cases rather than supplying the required strategy per risky function. Name the tested resolver, filler, header scanner and changed reader functions; give each its adversarial input class and mechanical guard, using generated malformed headers and reproducible event ordering where applicable.

## Round 2 — 2026-10-23T03:24:26-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Explicit witnessed preparation recognizes only its exact observed edit before save; unrelated edits still cancel, with deterministic real-observer verification required.
- PQ-2 — addressed — Function strategies replace case inventories with adversarial generators, independent mechanical guards and reproducible production-event ordering.

## Open findings

(none — every finding has been disposed)
