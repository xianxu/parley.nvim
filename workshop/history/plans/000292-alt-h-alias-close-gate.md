---
gate: boundary-review
issue: 292
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T17:59:37-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Minor
          title: config.lua lead-split comment still says "the split is even" and lists chat_prune as alt-leading
          detail: |-
            lua/parley/config.lua:379-381. The diff edited line 380 to add help, but left line 379
            ("This is not an exception -- the split is even") and line 381 (chat_prune listed as
            alt-leading) stale. The actual split is 4 <C-g>-leading (outline, chat_drill_in,
            new_question, help) vs 2 alt-leading (open_file, branch_ref); chat_prune is <C-g>b-only
            (keybindings_spec.lua:290,360). The lead-split test (keybindings_spec.lua:1077) points to
            this comment. The one other copy of the grouping is atlas/ui/keybindings.md:140-146, which
            this diff already fixed. Fix: drop "split is even" and remove chat_prune from the alt list.
          family: doc-claim-drift
          round: 1
      recipe: small-diff-review
      blocked: false
---

# Gate ledger — parley.nvim#292 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T17:59:37-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `doc-claim-drift` config.lua lead-split comment still says "the split is even" and lists chat_prune as alt-leading
  lua/parley/config.lua:379-381. The diff edited line 380 to add help, but left line 379
  ("This is not an exception -- the split is even") and line 381 (chat_prune listed as
  alt-leading) stale. The actual split is 4 <C-g>-leading (outline, chat_drill_in,
  new_question, help) vs 2 alt-leading (open_file, branch_ref); chat_prune is <C-g>b-only
  (keybindings_spec.lua:290,360). The lead-split test (keybindings_spec.lua:1077) points to
  this comment. The one other copy of the grouping is atlas/ui/keybindings.md:140-146, which
  this diff already fixed. Fix: drop "split is even" and remove chat_prune from the alt list.

## Open findings

- **BR-1** [Minor] `doc-claim-drift` config.lua lead-split comment still says "the split is even" and lists chat_prune as alt-leading
