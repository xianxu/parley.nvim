---
reviewer_runs:
    - version: 1
      intent:
        id: d037acf1-5328-456d-b6bb-dad82c9d2aaa
        repository: github.com/xianxu/parley.nvim
        issue_id: "000373"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        reviewed_head: 2fa6f4c1c0daf3e80a21c18299ed8d610bc2c1cb
        slot: parley.nvim:1
        requested_at: "2026-10-17T14:39:09.384856Z"
      phase: finished
      pid: 51704
      started_at: "2026-10-17T14:39:09.474502Z"
      finished_at: "2026-10-17T14:39:35.722758Z"
      session_id: 01a14a4d-6978-7983-87a6-96666ef3d84d
      outcome: returned
gate: plan-quality
issue: 373
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: f8696fcf-5bd9-4830-b819-4b5e6a8b697a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: 87f063ec301be9858714b83bf920078aef972d9b
            slot: parley.nvim:1
            requested_at: "2026-10-17T14:34:30.170241Z"
          phase: finished
          pid: 57322
          started_at: "2026-10-17T14:34:30.404705Z"
          finished_at: "2026-10-17T14:35:13.989031Z"
          session_id: 01a14a49-286a-71d0-a9b1-3b2a480c0c3d
          outcome: returned
      "n": 1
      timestamp: "2026-10-17T07:35:14-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Define the authoritative recovery transition model before implementation.
          detail: 'ARCH-ORDER/ARCH-PURE: The plan promises a shared state table but supplies only ordered effects, without naming a pure transition function, explicit states/events, or enforcement against direct checkpoint mutation. Define that model for orphan publication, parent publication, editor synchronization, subsequent saves, and uncertain metadata completion; identify how fresh and recovered operations use it and how controllable event sequences verify its invariants.'
          family: authoritative-transition-model
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace prose test inventories with named functions and adversarial strategies.
          detail: M1 and M2 enumerate extensive test cases but do not name the functions to be unit-tested or provide one strategy line per risky function. Compress those lists into function-level contracts covering the projection/rewrite, manifest validation/rendering, and recovery transition logic, naming each adversarial input class and mechanical guard while retaining fixture-driven integration acceptance.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: a0be67b1-784e-41ac-862f-3e380042a60f
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: f69f64144fff7d1d40e42bb20e4964199fef524d
            slot: parley.nvim:1
            requested_at: "2026-10-17T14:37:06.448959Z"
          phase: finished
          pid: 43181
          started_at: "2026-10-17T14:37:06.548746Z"
          finished_at: "2026-10-17T14:37:36.65487Z"
          session_id: 01a14a4b-894e-7253-a995-a82ca9bdaccb
          outcome: returned
      "n": 2
      timestamp: "2026-10-17T07:37:36-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The pure v2 reducer, phase/event model, single dispatcher, mutation guard, recovery rules, and adversarial sequence strategy satisfy the finding.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Named function contracts now pair adversarial inputs with mechanical guards while retaining fixture-driven integration acceptance.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: aba028c2-d147-4482-b239-ba44889c84ec
            repository: github.com/xianxu/parley.nvim
            issue_id: "000373"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
            reviewed_head: 2fa6f4c1c0daf3e80a21c18299ed8d610bc2c1cb
            slot: parley.nvim:1
            requested_at: "2026-10-17T14:38:35.514514Z"
          phase: finished
          pid: 49199
          started_at: "2026-10-17T14:38:35.612828Z"
          finished_at: "2026-10-17T14:39:08.36832Z"
          session_id: 01a14a4c-e538-7380-a5e6-3262ec911043
          outcome: returned
      "n": 3
      timestamp: "2026-10-17T07:39:08-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The pure v2 reducer, phase/event model, single dispatcher, and recovery invariants define authoritative state transitions.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: Test contracts name functions, adversarial input classes, and mechanical guards across pure and integration boundaries.
          round: 3
      blocked: false
content_hash: 62ee1fa2e25e315634beedfa1cbe7f3f35d0127bdb1d409c2ade3b271850be90
---

# Gate ledger — parley.nvim#373 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T07:35:14-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `authoritative-transition-model` Define the authoritative recovery transition model before implementation.
  ARCH-ORDER/ARCH-PURE: The plan promises a shared state table but supplies only ordered effects, without naming a pure transition function, explicit states/events, or enforcement against direct checkpoint mutation. Define that model for orphan publication, parent publication, editor synchronization, subsequent saves, and uncertain metadata completion; identify how fresh and recovered operations use it and how controllable event sequences verify its invariants.
- **PQ-2** [Important] `function-level-test-strategy` Replace prose test inventories with named functions and adversarial strategies.
  M1 and M2 enumerate extensive test cases but do not name the functions to be unit-tested or provide one strategy line per risky function. Compress those lists into function-level contracts covering the projection/rewrite, manifest validation/rendering, and recovery transition logic, naming each adversarial input class and mechanical guard while retaining fixture-driven integration acceptance.

## Round 2 — 2026-10-17T07:37:36-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The pure v2 reducer, phase/event model, single dispatcher, mutation guard, recovery rules, and adversarial sequence strategy satisfy the finding.
- PQ-2 — addressed — Named function contracts now pair adversarial inputs with mechanical guards while retaining fixture-driven integration acceptance.

## Round 3 — 2026-10-17T07:39:08-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The pure v2 reducer, phase/event model, single dispatcher, and recovery invariants define authoritative state transitions.
- PQ-2 — addressed — Test contracts name functions, adversarial input classes, and mechanical guards across pure and integration boundaries.

## Open findings

(none — every finding has been disposed)
