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

## Open findings

- **BR-1** [Important] `user-facing-shortcut-documentation` README omits the Option+p reassignment and private-note configuration
- **BR-2** [Important] `boundary-verification-evidence` Boundary verification did not complete successfully
