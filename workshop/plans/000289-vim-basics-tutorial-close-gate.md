---
gate: boundary-review
issue: 289
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-28T11:56:39-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: Wrapped-line movement is incorrectly described for Insert mode
          detail: 'packaging/tutorials/vim-basics.md:28-29 implies Up/Down follow wrapped lines in both Normal and Insert. packaging/starter-config/init.lua:20-24 maps these keys only in Normal and Visual; a real packaged-profile check confirmed Insert Down moves to the next logical line. Family enumeration: both Up and Down in this passage. Restrict the claim to supported modes, preserving the no-new-behavior scope (ARCH-PURPOSE).'
          family: documented-mode-behavior
          round: 1
        - id: BR-2
          severity: Important
          title: README update appears missing for the fourth tutorial
          detail: 'README.md:118-123 lists Welcome, Basics, and Advanced but omits the newly shipped VIM Basics lesson; README is unchanged in the pinned range. Family enumeration: the new fourth lesson is the sole added user surface missing from this catalog. Add its packaged-content link and a concise description.'
          family: readme-user-surface-discovery
          round: 1
      recipe: small-diff-review
      blocked: true
---

# Gate ledger — parley.nvim#289 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-28T11:56:39-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `documented-mode-behavior` Wrapped-line movement is incorrectly described for Insert mode
  packaging/tutorials/vim-basics.md:28-29 implies Up/Down follow wrapped lines in both Normal and Insert. packaging/starter-config/init.lua:20-24 maps these keys only in Normal and Visual; a real packaged-profile check confirmed Insert Down moves to the next logical line. Family enumeration: both Up and Down in this passage. Restrict the claim to supported modes, preserving the no-new-behavior scope (ARCH-PURPOSE).
- **BR-2** [Important] `readme-user-surface-discovery` README update appears missing for the fourth tutorial
  README.md:118-123 lists Welcome, Basics, and Advanced but omits the newly shipped VIM Basics lesson; README is unchanged in the pinned range. Family enumeration: the new fourth lesson is the sole added user surface missing from this catalog. Add its packaged-content link and a concise description.

## Open findings

- **BR-1** [Important] `documented-mode-behavior` Wrapped-line movement is incorrectly described for Insert mode
- **BR-2** [Important] `readme-user-surface-discovery` README update appears missing for the fourth tutorial
