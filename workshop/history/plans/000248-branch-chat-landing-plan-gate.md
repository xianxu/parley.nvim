---
gate: plan-quality
issue: 248
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-14T08:52:34-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Specify which window owns scheduled navigation and when it is cancelled.
          detail: 'ARCH-ORDER: Existing callbacks use the current window at execution time (lua/parley/init.lua:2409 and :2481). State whether the shared helper targets the originating window or follows current focus, and what happens if that window closes or changes buffers before execution; name a controllable scheduler seam to verify that policy.'
          family: deferred-effect-ownership
          round: 1
        - id: PQ-2
          severity: Important
          title: Name the tested functions and their adversarial strategies.
          detail: The first checkbox lists observable outcomes but does not name the shared helper or give function-level strategies. Name that helper and the insert_plain/insert_planned/insert_inline surface reached through _branch_inserters, then give one strategy line each covering adversarial child structure and controlled navigation/write failures; identify tests/integration/branch_child_spec.lua as the behavioral regression location without expanding into a case inventory.
          family: function-level-test-strategy
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T08:53:41-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Originating-window ownership and cancellation on invalidity, lost focus, or changed buffer are explicit, with a controlled vim.schedule queue for verification.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: The revision names open_branch_question and all three inserters through _branch_inserters, with adversarial child, scheduling, and write-failure strategies in tests/integration/branch_child_spec.lua.
          round: 2
      blocked: false
content_hash: 6d0da0b635df22f6190560de183c697374af1574ce617f1672949d3d05f0418d
---

# Gate ledger — parley.nvim#248 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T08:52:34-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `deferred-effect-ownership` Specify which window owns scheduled navigation and when it is cancelled.
  ARCH-ORDER: Existing callbacks use the current window at execution time (lua/parley/init.lua:2409 and :2481). State whether the shared helper targets the originating window or follows current focus, and what happens if that window closes or changes buffers before execution; name a controllable scheduler seam to verify that policy.
- **PQ-2** [Important] `function-level-test-strategy` Name the tested functions and their adversarial strategies.
  The first checkbox lists observable outcomes but does not name the shared helper or give function-level strategies. Name that helper and the insert_plain/insert_planned/insert_inline surface reached through _branch_inserters, then give one strategy line each covering adversarial child structure and controlled navigation/write failures; identify tests/integration/branch_child_spec.lua as the behavioral regression location without expanding into a case inventory.

## Round 2 — 2026-09-14T08:53:41-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — Originating-window ownership and cancellation on invalidity, lost focus, or changed buffer are explicit, with a controlled vim.schedule queue for verification.
- PQ-2 — addressed — The revision names open_branch_question and all three inserters through _branch_inserters, with adversarial child, scheduling, and write-failure strategies in tests/integration/branch_child_spec.lua.

## Open findings

(none — every finding has been disposed)
