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
    - "n": 2
      timestamp: "2026-09-26T21:14:11-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:57-61 now documents insertion, Normal/Insert support, both configuration keys, and retained Ctrl+g b pruning; these match config.lua and the registered callbacks.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The pinned correction replaces the missing branch link at packaging/tutorials/basics.md:106 with plain text. Remaining tutorial destinations match the three files seeded by starter.lua:127.
          round: 2
      findings:
        - id: BR-3
          severity: Important
          title: Lifecycle atlas still advertises Option+p for pruning
          detail: 'atlas/chat/lifecycle.md:138 labels pruning as "<M-p>, legacy <C-g>b", contradicting config.lua:414-419: Option+p now inserts a note. This is the 2nd finding in family user-surface-documentation. ARCH-PURPOSE: apply the rule that every current description of a migrated binding must match the registry/config; sweep README, atlas, packaged documentation, and help descriptions together rather than patching only this instance. The sweep found one remaining obsolete pruning advertisement.'
          family: user-surface-documentation
          round: 2
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

## Round 2 — 2026-09-26T21:14:11-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — README.md:57-61 now documents insertion, Normal/Insert support, both configuration keys, and retained Ctrl+g b pruning; these match config.lua and the registered callbacks.
- BR-2 — addressed — The pinned correction replaces the missing branch link at packaging/tutorials/basics.md:106 with plain text. Remaining tutorial destinations match the three files seeded by starter.lua:127.

### Raised

- **BR-3** [Important] `user-surface-documentation` Lifecycle atlas still advertises Option+p for pruning
  atlas/chat/lifecycle.md:138 labels pruning as "<M-p>, legacy <C-g>b", contradicting config.lua:414-419: Option+p now inserts a note. This is the 2nd finding in family user-surface-documentation. ARCH-PURPOSE: apply the rule that every current description of a migrated binding must match the registry/config; sweep README, atlas, packaged documentation, and help descriptions together rather than patching only this instance. The sweep found one remaining obsolete pruning advertisement.

## Open findings

- **BR-3** [Important] `user-surface-documentation` Lifecycle atlas still advertises Option+p for pruning
