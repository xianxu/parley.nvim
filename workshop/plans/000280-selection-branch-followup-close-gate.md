---
gate: boundary-review
issue: 280
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T00:14:02-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Concurrent reset can delete a running editor's profile
          detail: parley_app:38-51 checks the recorded PID separately from publishing launch ownership or deleting the demo. A deterministic launch/reset interleaving produced nuke_exit=0, editor_still_running=True, demo_exists=False. Serialize ownership validation, acquisition and reset, and add controlled competing-launch/reset regressions (ARCH-ORDER).
          family: atomic-profile-ownership
          round: 1
        - id: BR-2
          severity: Important
          title: Starter shortcut overrides fail the existing architecture suite
          detail: lua/parley/starter_config.lua:61-63 introduces three accesses rejected by tests/arch/single_source_sweeps_spec.lua:662. The indexed pinned snapshot reports 24 passed and 1 failed; removing those accesses yields 25 passed. Integrate the overrides into option construction or explicitly justify the guard's supported exemption for configuration assembly, preserving runtime registry enforcement.
          family: preserve-architecture-guards
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#280 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T00:14:02-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `atomic-profile-ownership` Concurrent reset can delete a running editor's profile
  parley_app:38-51 checks the recorded PID separately from publishing launch ownership or deleting the demo. A deterministic launch/reset interleaving produced nuke_exit=0, editor_still_running=True, demo_exists=False. Serialize ownership validation, acquisition and reset, and add controlled competing-launch/reset regressions (ARCH-ORDER).
- **BR-2** [Important] `preserve-architecture-guards` Starter shortcut overrides fail the existing architecture suite
  lua/parley/starter_config.lua:61-63 introduces three accesses rejected by tests/arch/single_source_sweeps_spec.lua:662. The indexed pinned snapshot reports 24 passed and 1 failed; removing those accesses yields 25 passed. Integrate the overrides into option construction or explicitly justify the guard's supported exemption for configuration assembly, preserving runtime registry enforcement.

## Open findings

- **BR-1** [Critical] `atomic-profile-ownership` Concurrent reset can delete a running editor's profile
- **BR-2** [Important] `preserve-architecture-guards` Starter shortcut overrides fail the existing architecture suite
