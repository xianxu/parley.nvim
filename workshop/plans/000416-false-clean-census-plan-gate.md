---
reviewer_runs:
    - version: 1
      intent:
        id: 5576c307-5ce5-4fb3-92ee-417f6a5606da
        repository: github.com/xianxu/parley.nvim
        issue_id: "000416"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: codex
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        reviewed_head: f9dae7142ebb23b82253c95ccbf06e8e82760802
        slot: parley.nvim:3
        requested_at: "2026-10-22T23:23:06.479827Z"
      phase: finished
      pid: 43722
      started_at: "2026-10-22T23:23:06.674612Z"
      finished_at: "2026-10-22T23:23:34.606347Z"
      session_id: 01a165ec-e7d1-7b71-a305-93fb695efdaf
      outcome: returned
gate: plan-quality
issue: 416
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 2de8f7d4-d876-42b3-afe7-880d320f6c27
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: e3cb6b9eeb9bd366b61a008454b764b193ea6c7b
            slot: parley.nvim:3
            requested_at: "2026-10-22T23:19:21.831972Z"
          phase: finished
          pid: 80877
          started_at: "2026-10-22T23:19:21.921702Z"
          finished_at: "2026-10-22T23:20:13.398216Z"
          session_id: 01a165e9-7944-7bf0-a615-1ffaba584dd0
          outcome: returned
      "n": 1
      timestamp: "2026-10-22T16:20:13-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: PQ-1
          severity: Important
          title: Define recovery for death between child creation and birth-record publication
          detail: 'ARCH-ORDER: Plan lines 51–52 cover checked registration failures but do not define durable state when the spawning process dies after jobstart and before publication; current spec_jobs.lua:25–32 has exactly that ordering. Specify a persisted pending-registration transition or equivalent protocol whose interrupted state prevents clean, with deterministic interruption testing and no speculative signaling when ownership remains unknown.'
          family: durable-registration-before-effects
          round: 1
        - id: PQ-2
          severity: Important
          title: Replace prose test inventories with named functions and adversarial strategies
          detail: Tasks 1–3 enumerate test cases while leaving the new policy, registry and observation functions unnamed. Name the functions to be unit-tested and give one concise adversarial-input or event-sequence strategy plus its mechanical guard per risky function; compress the case inventories as required by this gate.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: e3b773f8-8cf9-4b29-967c-71b7c886daae
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 8ee57704a5d7222db5ed2409c0bb1d9d15c6bc37
            slot: parley.nvim:3
            requested_at: "2026-10-22T23:21:40.032079Z"
          phase: finished
          pid: 21649
          started_at: "2026-10-22T23:21:40.131917Z"
          finished_at: "2026-10-22T23:22:06.323676Z"
          session_id: 01a165eb-9540-75d0-8d38-10b11d67edd1
          outcome: returned
      "n": 2
      timestamp: "2026-10-22T16:22:06-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Plan lines 52 and 87 require durable pre-spawn tickets, retained unknown outcomes without signaling, and controlled native interruption testing.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Plan lines 83–93 name the functions under test and give concise adversarial strategies with mechanical guards.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: c984d0c2-fdfb-4bcd-a28d-24773d9350fc
            repository: github.com/xianxu/parley.nvim
            issue_id: "000416"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: codex
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: f9dae7142ebb23b82253c95ccbf06e8e82760802
            slot: parley.nvim:3
            requested_at: "2026-10-22T23:22:41.043577Z"
          phase: finished
          pid: 33086
          started_at: "2026-10-22T23:22:41.173658Z"
          finished_at: "2026-10-22T23:23:04.631327Z"
          session_id: 01a165ec-83eb-71f1-ba11-6c087e76b404
          outcome: returned
      "n": 3
      timestamp: "2026-10-22T16:23:04-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Durable pending tickets precede child creation; interrupted publication retains unknown evidence and prevents a clean verdict.
          round: 3
        - id: PQ-2
          disposition: addressed
          note: The verification contract names risky functions and pairs each with an adversarial strategy and mechanical guard.
          round: 3
      blocked: false
content_hash: 07e1d24dce1643bcb69900b3ef8e87fcb4dee3e157557cf16627fe6a499c54f0
---

# Gate ledger — parley.nvim#416 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-22T16:20:13-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `durable-registration-before-effects` Define recovery for death between child creation and birth-record publication
  ARCH-ORDER: Plan lines 51–52 cover checked registration failures but do not define durable state when the spawning process dies after jobstart and before publication; current spec_jobs.lua:25–32 has exactly that ordering. Specify a persisted pending-registration transition or equivalent protocol whose interrupted state prevents clean, with deterministic interruption testing and no speculative signaling when ownership remains unknown.
- **PQ-2** [Important] `function-level-test-strategy` Replace prose test inventories with named functions and adversarial strategies
  Tasks 1–3 enumerate test cases while leaving the new policy, registry and observation functions unnamed. Name the functions to be unit-tested and give one concise adversarial-input or event-sequence strategy plus its mechanical guard per risky function; compress the case inventories as required by this gate.

## Round 2 — 2026-10-22T16:22:06-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Plan lines 52 and 87 require durable pre-spawn tickets, retained unknown outcomes without signaling, and controlled native interruption testing.
- PQ-2 — addressed — Plan lines 83–93 name the functions under test and give concise adversarial strategies with mechanical guards.

## Round 3 — 2026-10-22T16:23:04-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Durable pending tickets precede child creation; interrupted publication retains unknown evidence and prevents a clean verdict.
- PQ-2 — addressed — The verification contract names risky functions and pairs each with an adversarial strategy and mechanical guard.

## Open findings

(none — every finding has been disposed)
