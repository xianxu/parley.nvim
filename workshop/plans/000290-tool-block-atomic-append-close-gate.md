---
gate: boundary-review
issue: 290
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-27T16:47:46-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: fold_written misses the first tool call of a round when prose precedes it
          detail: 'insert_tool prefixes call 1 with two newlines (response_tools.lua:146), so the receipt''s first_row (generation_runner.lua:403) is the prose row the first byte lands on. The append branch (tool_folds.lua:460-464) trims only blank rows, takes the prose row as the anchor and folds nothing. Reproduced: a scratch copy of writer_folds_spec that streams ''Let me check.'' before the call emits 1 written fold instead of 2. Family: the anchor logic, the first_row semantics, the spec''s missing prose-before-call case (and a second-round first call), and the atlas claim at atlas/chat/document.md:139-142. Fix: begin at the first row that starts inside the write (carry the first byte''s column in the receipt and skip first_row when col>0), and add the test.'
          family: writer-fold-range-from-written-bytes
          round: 1
        - id: BR-2
          severity: Important
          title: Done-when and Spec still claim fenced-summary removal and multi-line reshape, with no Revisions entry
          detail: 'The Log records that the parser folds a fenced summary row and only a summary''s marker row, and the tests were changed to assert agreement with the parse. Done-when clauses 3-4 and the Spec''s Summaries bullets still promise removal/reshape. Append a ## Revisions entry updating them, and record the receipt field name first_row (the plan says from).'
          family: plan-revision-on-spec-divergence
          round: 1
        - id: BR-3
          severity: Minor
          title: fold_written duplicates the setting_foldenable / nvim_win_call / restore_window wrapper
          detail: The same wrapper pattern is at tool_folds.lua:233-322 and in the new fold_written; a with_window helper in fold_native would consolidate it (ARCH-DRY).
          family: shared-window-fold-wrapper
          round: 1
        - id: BR-4
          severity: Minor
          title: fold_written's range computation is not separable from window IO
          detail: Extracting a pure written_ranges(kind, receipt, seen) would let the prose-before-call and split-prefix cases be unit-tested without a real window (ARCH-PURE).
          family: writer-fold-pure-core
          round: 1
      recipe: small-diff-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-27T16:53:26-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: first_col skip at tool_folds.lua:455; e2e two-round test goes red when the line is reverted in a scratch copy
          round: 2
        - id: BR-2
          disposition: addressed
          note: Revisions entry dated 2026-09-27 records the Spec, Done-when and Plan changes, including first_row/first_col; Done-when restated
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: 'wrapper still duplicated in fold_written; implementer deferred it because the other copy is #264''s reconcile apply; Minor, non-blocking'
          round: 2
        - id: BR-4
          disposition: addressed
          note: pure written_ranges extracted and unit-tested in tests/unit/tool_folds_spec.lua
          round: 2
      findings:
        - id: BR-5
          severity: Minor
          title: BLOCK_LIMIT restates the runner staging ceiling as a separate 1048576 literal
          detail: document/init.lua:18 hardcodes 1048576 and says it is generation.lua:242-243's staged_bytes limit; nothing ties the two, so changing one silently breaks the claim that a block the runner admitted is never refused. Define the value in one place and derive the other from it.
          family: single-source-limit-constants
          round: 2
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#290 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-27T16:47:46-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `writer-fold-range-from-written-bytes` fold_written misses the first tool call of a round when prose precedes it
  insert_tool prefixes call 1 with two newlines (response_tools.lua:146), so the receipt's first_row (generation_runner.lua:403) is the prose row the first byte lands on. The append branch (tool_folds.lua:460-464) trims only blank rows, takes the prose row as the anchor and folds nothing. Reproduced: a scratch copy of writer_folds_spec that streams 'Let me check.' before the call emits 1 written fold instead of 2. Family: the anchor logic, the first_row semantics, the spec's missing prose-before-call case (and a second-round first call), and the atlas claim at atlas/chat/document.md:139-142. Fix: begin at the first row that starts inside the write (carry the first byte's column in the receipt and skip first_row when col>0), and add the test.
- **BR-2** [Important] `plan-revision-on-spec-divergence` Done-when and Spec still claim fenced-summary removal and multi-line reshape, with no Revisions entry
  The Log records that the parser folds a fenced summary row and only a summary's marker row, and the tests were changed to assert agreement with the parse. Done-when clauses 3-4 and the Spec's Summaries bullets still promise removal/reshape. Append a ## Revisions entry updating them, and record the receipt field name first_row (the plan says from).
- **BR-3** [Minor] `shared-window-fold-wrapper` fold_written duplicates the setting_foldenable / nvim_win_call / restore_window wrapper
  The same wrapper pattern is at tool_folds.lua:233-322 and in the new fold_written; a with_window helper in fold_native would consolidate it (ARCH-DRY).
- **BR-4** [Minor] `writer-fold-pure-core` fold_written's range computation is not separable from window IO
  Extracting a pure written_ranges(kind, receipt, seen) would let the prose-before-call and split-prefix cases be unit-tested without a real window (ARCH-PURE).

## Round 2 — 2026-09-27T16:53:26-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — first_col skip at tool_folds.lua:455; e2e two-round test goes red when the line is reverted in a scratch copy
- BR-2 — addressed — Revisions entry dated 2026-09-27 records the Spec, Done-when and Plan changes, including first_row/first_col; Done-when restated
- BR-3 — not-addressed — wrapper still duplicated in fold_written; implementer deferred it because the other copy is #264's reconcile apply; Minor, non-blocking
- BR-4 — addressed — pure written_ranges extracted and unit-tested in tests/unit/tool_folds_spec.lua

### Raised

- **BR-5** [Minor] `single-source-limit-constants` BLOCK_LIMIT restates the runner staging ceiling as a separate 1048576 literal
  document/init.lua:18 hardcodes 1048576 and says it is generation.lua:242-243's staged_bytes limit; nothing ties the two, so changing one silently breaks the claim that a block the runner admitted is never refused. Define the value in one place and derive the other from it.

## Open findings

- **BR-3** [Minor] `shared-window-fold-wrapper` fold_written duplicates the setting_foldenable / nvim_win_call / restore_window wrapper
- **BR-5** [Minor] `single-source-limit-constants` BLOCK_LIMIT restates the runner staging ceiling as a separate 1048576 literal
