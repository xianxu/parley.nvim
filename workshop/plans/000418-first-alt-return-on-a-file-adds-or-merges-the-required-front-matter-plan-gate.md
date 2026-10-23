---
reviewer_runs:
    - version: 1
      intent:
        id: 4345dc7d-726a-45e9-badd-efaa8e255653
        repository: github.com/xianxu/parley.nvim
        issue_id: "000418"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        reviewed_head: 0f8a35d03fd1183ec669055783673eac93e48a96
        slot: parley.nvim:3
        requested_at: "2026-10-23T10:26:19.886494Z"
      phase: finished
      pid: 13033
      started_at: "2026-10-23T10:26:19.978397Z"
      finished_at: "2026-10-23T10:26:54.627529Z"
      session_id: 01a1684c-19d5-7ea1-b48f-ce5bd7992a9a
      outcome: returned
    - version: 1
      intent:
        id: 9cec9c6c-a6db-41b6-8bb4-abbed43abaa3
        repository: github.com/xianxu/parley.nvim
        issue_id: "000418"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        reviewed_head: 26db39f88d250fcf6fd9e517470b8414402a7627
        slot: parley.nvim:3
        requested_at: "2026-10-23T17:12:56.642454Z"
      phase: finished
      pid: 29727
      started_at: "2026-10-23T17:12:56.820412Z"
      finished_at: "2026-10-23T17:13:26.532136Z"
      session_id: 01a169c0-5e6b-7520-a04e-7cbcd9b2bd03
      outcome: returned
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
    - reviewer_runs:
        - version: 1
          intent:
            id: 328d8967-9898-42b7-96c7-47d069e3e861
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 0f8a35d03fd1183ec669055783673eac93e48a96
            slot: parley.nvim:3
            requested_at: "2026-10-23T10:25:46.675481Z"
          phase: finished
          pid: 96573
          started_at: "2026-10-23T10:25:46.803762Z"
          finished_at: "2026-10-23T10:26:18.832823Z"
          session_id: 01a1684b-98a5-7ae1-8392-3526214286d4
          outcome: returned
      "n": 3
      timestamp: "2026-10-23T03:26:19-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Witnessed preparation precedes ordinary save and preserves invalidation for unrelated edits.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Named function strategies replace test inventories with adversarial classes and mechanical guards.
          round: 3
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: f5a2a7de-0834-4bd7-b253-2f926c4602ff
            repository: github.com/xianxu/parley.nvim
            issue_id: "000418"
            recipe: plan-quality
            round: 4
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 26db39f88d250fcf6fd9e517470b8414402a7627
            slot: parley.nvim:3
            requested_at: "2026-10-23T17:12:22.452314Z"
          phase: finished
          pid: 18100
          started_at: "2026-10-23T17:12:22.566543Z"
          finished_at: "2026-10-23T17:12:54.842203Z"
          session_id: 01a169bf-d875-7182-b889-3ea4cc4dc503
          outcome: returned
      "n": 4
      timestamp: "2026-10-23T10:12:55-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Witnessed preparation remains on the existing operation; skipped fill uses its established no-op path.
          round: 4
        - id: PQ-2
          disposition: addressed
          note: Named risky functions have adversarial strategies and mechanical guards covering the revised boundary.
          round: 4
      blocked: false
content_hash: f6511c76d93da83830c1767ed82fd8544dd9a1c91406d44f08c120e596ea3f30
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

## Round 3 — 2026-10-23T03:26:19-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Witnessed preparation precedes ordinary save and preserves invalidation for unrelated edits.
- PQ-2 — addressed — Named function strategies replace test inventories with adversarial classes and mechanical guards.

## Round 4 — 2026-10-23T10:12:55-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Witnessed preparation remains on the existing operation; skipped fill uses its established no-op path.
- PQ-2 — addressed — Named risky functions have adversarial strategies and mechanical guards covering the revised boundary.

## Open findings

(none — every finding has been disposed)
