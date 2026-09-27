---
gate: boundary-review
issue: 284
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T20:25:12-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: README omits Option+p and the prune binding migration
          detail: lua/parley/config.lua:414-419 changes shipped bindings and adds chat_shortcut_private_note, but README.md does not describe them. Document private-note insertion, Normal/Insert support, the configuration key, and prune's retained Ctrl+g b binding.
          family: user-surface-documentation
          round: 1
        - id: BR-2
          severity: Important
          title: The shipped Basics tutorial references an unpackaged branch
          detail: packaging/tutorials/basics.md:106 links to a file absent from the pinned tree, and lua/parley/starter.lua:127 seeds only the three tutorials. Restore plain text or package and seed the destination so fresh installations can follow the example. ARCH-PURPOSE.
          family: packaged-reference-integrity
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#284 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T20:25:12-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `user-surface-documentation` README omits Option+p and the prune binding migration
  lua/parley/config.lua:414-419 changes shipped bindings and adds chat_shortcut_private_note, but README.md does not describe them. Document private-note insertion, Normal/Insert support, the configuration key, and prune's retained Ctrl+g b binding.
- **BR-2** [Important] `packaged-reference-integrity` The shipped Basics tutorial references an unpackaged branch
  packaging/tutorials/basics.md:106 links to a file absent from the pinned tree, and lua/parley/starter.lua:127 seeds only the three tutorials. Restore plain text or package and seed the destination so fresh installations can follow the example. ARCH-PURPOSE.

## Open findings

- **BR-1** [Important] `user-surface-documentation` README omits Option+p and the prune binding migration
- **BR-2** [Important] `packaged-reference-integrity` The shipped Basics tutorial references an unpackaged branch
