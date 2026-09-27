---
gate: boundary-review
issue: 286
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T20:25:07-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: README omits the Option+p reassignment and private-note configuration
          detail: lua/parley/config.lua:414–419 reassigns Option+p from prune to private-note insertion and adds chat_shortcut_private_note. Update README.md's shortcut guidance to describe the new Normal/Insert behavior and Ctrl+g b for pruning.
          family: user-facing-shortcut-documentation
          round: 1
        - id: BR-2
          severity: Important
          title: Boundary verification did not complete successfully
          detail: make test-spec SPEC=infra/starter produced 182 passes and one failure at tests/integration/starter_config_spec.lua:167. Both starter and keybinding commands also could not perform the required process census because ps was unavailable. Rerun with process inspection available and resolve or establish the cause of the starter failure before claiming successful verification.
          family: boundary-verification-evidence
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-26T21:13:04-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: README.md:57–61 documents Option+p in Normal/Insert mode, chat_shortcut_private_note, chat_local_prefix, and Ctrl+g b pruning; these match config.lua:414–419 and the insertion callbacks.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: The starter rerun exited 0 and the previously failing concurrent-creator test passed, but ps was denied and the harness explicitly skipped process census. Required teardown verification remains unavailable; rerun with process inspection enabled.
          round: 2
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#286 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T20:25:07-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `user-facing-shortcut-documentation` README omits the Option+p reassignment and private-note configuration
  lua/parley/config.lua:414–419 reassigns Option+p from prune to private-note insertion and adds chat_shortcut_private_note. Update README.md's shortcut guidance to describe the new Normal/Insert behavior and Ctrl+g b for pruning.
- **BR-2** [Important] `boundary-verification-evidence` Boundary verification did not complete successfully
  make test-spec SPEC=infra/starter produced 182 passes and one failure at tests/integration/starter_config_spec.lua:167. Both starter and keybinding commands also could not perform the required process census because ps was unavailable. Rerun with process inspection available and resolve or establish the cause of the starter failure before claiming successful verification.

## Round 2 — 2026-09-26T21:13:04-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — README.md:57–61 documents Option+p in Normal/Insert mode, chat_shortcut_private_note, chat_local_prefix, and Ctrl+g b pruning; these match config.lua:414–419 and the insertion callbacks.
- BR-2 — not-addressed — The starter rerun exited 0 and the previously failing concurrent-creator test passed, but ps was denied and the harness explicitly skipped process census. Required teardown verification remains unavailable; rerun with process inspection enabled.

## Open findings

- **BR-2** [Important] `boundary-verification-evidence` Boundary verification did not complete successfully
