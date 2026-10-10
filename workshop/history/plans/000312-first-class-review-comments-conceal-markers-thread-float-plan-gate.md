---
gate: plan-quality
issue: 312
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-10-09T20:49:21-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: Plan drops the Spec/Done-when overlap guard (partial-edit revert + tests) without revising the issue
          detail: Spec "Edit protection 2. Overlap guard" and Done-when "partial-overlap edits are reverted, whole-marker deletes pass; tests cover both" remain, but the plan decides "No undo-reverting guard (YAGNI)". Either implement it or revise Spec/Done-when via a Revisions entry; also update the stale issue M1 row (concealcursor=nc) and reconcile "diagnostic" vs ParleyReviewBroken highlight.
          family: done-when-contract-drift
          round: 1
        - id: PQ-2
          severity: Important
          title: No plan step produces the "re-render is incremental (test or trace)" Done-when evidence
          detail: Add a test or trace (e.g. assert compute_markdown_highlights is called only for the viewport/changed rows after a single-line edit) to M1.
          family: done-when-unverified
          round: 1
        - id: PQ-3
          severity: Important
          title: view.layout does not flag a marker whose chain ends in an unclosed opener, so legacy multi-line markers render half-concealed
          detail: "The parser breaks silently on an unmatched [ or { (skills/review/init.lua chain loop), so \U0001F916<X>[line1 (legacy multi-line) returns quoted with no sections and is rendered as a quoted X with raw [line1, not as broken. The rule should be \"byte at stop is [ or { means broken\"; add a test for \U0001F916<X>[open and \U0001F916[a]{b."
          family: marker-broken-detection
          round: 1
        - id: PQ-4
          severity: Important
          title: Cursor may rest on the first hidden byte of a bare chain, letting x/r/i/cw silently edit hidden comment text
          detail: chain_hidden starts the hidden range at the byte after [ and snap allows col == h[1], so the cursor sits on the comment's first char (shown as the ellipsis). Edits there keep the marker parseable, so they are not fail-visible, contradicting "hidden bytes behave as one glyph". Make the legal rest the visible opener/closer (or snap h[1] too) and test normal-mode x on a bare chain.
          family: hidden-bytes-editable
          round: 1
        - id: PQ-5
          severity: Minor
          title: Task 4 test asserts no ParleyReviewUser entry while its implementation step says to keep emitting them
          detail: The stated rationale (insert/visual reveal raw) was removed by the nvic revision; drop the per-section entries or the assertion.
          family: plan-internal-contradiction
          round: 1
        - id: PQ-6
          severity: Minor
          title: Normal-mode CR wraps a native key; repo precedent for that is keybinding_registry.native_overrides, not an owned registry entry
          detail: Choose deliberately and name the help/reality leak-guard spec it must pass instead of "any keybinding-registry spec".
          family: keybinding-ownership-precedent
          round: 1
        - id: PQ-7
          severity: Minor
          title: "Unhandled edges: literal br already in legacy markers, quoted-only \U0001F916<X> with no sections, emptied \U0001F916<>"
          family: edge-case-coverage
          round: 1
        - id: PQ-8
          severity: Minor
          title: Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
          detail: e.g. view.layout -> property-test range bounds/non-overlap/UTF-8 boundaries over generated lines seeded with truncated/nested markers; thread.from_lines -> round-trip property over generated single-line markers.
          family: test-prose-enumeration
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-10-09T20:52:34-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Overlap guard dropped via a Revisions entry; Spec and Done-when restated to snap plus fail-visible. Stale M1 row and "diagnostic" wording carried as a new Minor.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Task 4b adds a viewport-bounded call-count test on a 5000-line buffer; helpers exist (tests/helpers/decoration.lua:5,17).
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Broken = byte at parse stop is an opener; parser stops on the unclosed opener (skills/review/init.lua:118-141); tests added.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: snap never rests on any hidden byte including h[1]; bare-chain test added.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Per-section User/Agent entries dropped, consistent with the assertion.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: CR declared in native_overrides (keybinding_registry.lua:1205); keybinding_agreement_spec named.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: Literal br accepted as a known edge with one-home fix; quoted-only and empty-anchor handled with tests.
          round: 2
        - id: PQ-8
          disposition: not-addressed
          note: Tasks 8 and 10 still enumerate cases in prose; Tasks 1-3 still carry full test code. Property-test strategy lines were added alongside, not in place of.
          round: 2
      findings:
        - id: PQ-9
          severity: Minor
          title: Issue M1 row still says concealcursor=nc, and Spec/Done-when say "diagnostic" where the plan paints ParleyReviewBroken
          detail: '2nd finding in this family. Rule: a revision that changes a decision must sweep every restatement in the issue (Spec, Done-when, Plan rows, Log) in the same edit; the Revisions entry triggers that sweep and does not replace it. Prevalence so far: 2 of 2 rounds.'
          family: done-when-contract-drift
          round: 2
      blocked: false
    - "n": 3
      timestamp: "2026-10-09T20:54:03-07:00"
      agent: claude
      dispose:
        - id: PQ-8
          disposition: not-addressed
          note: Plan unchanged since round 1; Tasks 1-3 full test code and Tasks 8/10 prose case lists remain. Minor, carried to close.
          round: 3
        - id: PQ-9
          disposition: not-addressed
          note: Issue sites fixed; plan Architecture line 7 still says "snaps the normal-mode cursor" (snap is every mode since 17775389). Sweep every restatement on a decision change.
          round: 3
      blocked: false
content_hash: 467081096ab85f492ac0c2111f21d776888d99058c16aa11165ef904316bbf61
---

# Gate ledger — parley.nvim#312 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-09T20:49:21-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `done-when-contract-drift` Plan drops the Spec/Done-when overlap guard (partial-edit revert + tests) without revising the issue
  Spec "Edit protection 2. Overlap guard" and Done-when "partial-overlap edits are reverted, whole-marker deletes pass; tests cover both" remain, but the plan decides "No undo-reverting guard (YAGNI)". Either implement it or revise Spec/Done-when via a Revisions entry; also update the stale issue M1 row (concealcursor=nc) and reconcile "diagnostic" vs ParleyReviewBroken highlight.
- **PQ-2** [Important] `done-when-unverified` No plan step produces the "re-render is incremental (test or trace)" Done-when evidence
  Add a test or trace (e.g. assert compute_markdown_highlights is called only for the viewport/changed rows after a single-line edit) to M1.
- **PQ-3** [Important] `marker-broken-detection` view.layout does not flag a marker whose chain ends in an unclosed opener, so legacy multi-line markers render half-concealed
  The parser breaks silently on an unmatched [ or { (skills/review/init.lua chain loop), so 🤖<X>[line1 (legacy multi-line) returns quoted with no sections and is rendered as a quoted X with raw [line1, not as broken. The rule should be "byte at stop is [ or { means broken"; add a test for 🤖<X>[open and 🤖[a]{b.
- **PQ-4** [Important] `hidden-bytes-editable` Cursor may rest on the first hidden byte of a bare chain, letting x/r/i/cw silently edit hidden comment text
  chain_hidden starts the hidden range at the byte after [ and snap allows col == h[1], so the cursor sits on the comment's first char (shown as the ellipsis). Edits there keep the marker parseable, so they are not fail-visible, contradicting "hidden bytes behave as one glyph". Make the legal rest the visible opener/closer (or snap h[1] too) and test normal-mode x on a bare chain.
- **PQ-5** [Minor] `plan-internal-contradiction` Task 4 test asserts no ParleyReviewUser entry while its implementation step says to keep emitting them
  The stated rationale (insert/visual reveal raw) was removed by the nvic revision; drop the per-section entries or the assertion.
- **PQ-6** [Minor] `keybinding-ownership-precedent` Normal-mode CR wraps a native key; repo precedent for that is keybinding_registry.native_overrides, not an owned registry entry
  Choose deliberately and name the help/reality leak-guard spec it must pass instead of "any keybinding-registry spec".
- **PQ-7** [Minor] `edge-case-coverage` Unhandled edges: literal br already in legacy markers, quoted-only 🤖<X> with no sections, emptied 🤖<>
- **PQ-8** [Minor] `test-prose-enumeration` Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
  e.g. view.layout -> property-test range bounds/non-overlap/UTF-8 boundaries over generated lines seeded with truncated/nested markers; thread.from_lines -> round-trip property over generated single-line markers.

## Round 2 — 2026-10-09T20:52:34-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Overlap guard dropped via a Revisions entry; Spec and Done-when restated to snap plus fail-visible. Stale M1 row and "diagnostic" wording carried as a new Minor.
- PQ-2 — addressed — Task 4b adds a viewport-bounded call-count test on a 5000-line buffer; helpers exist (tests/helpers/decoration.lua:5,17).
- PQ-3 — addressed — Broken = byte at parse stop is an opener; parser stops on the unclosed opener (skills/review/init.lua:118-141); tests added.
- PQ-4 — addressed — snap never rests on any hidden byte including h[1]; bare-chain test added.
- PQ-5 — addressed — Per-section User/Agent entries dropped, consistent with the assertion.
- PQ-6 — addressed — CR declared in native_overrides (keybinding_registry.lua:1205); keybinding_agreement_spec named.
- PQ-7 — addressed — Literal br accepted as a known edge with one-home fix; quoted-only and empty-anchor handled with tests.
- PQ-8 — not-addressed — Tasks 8 and 10 still enumerate cases in prose; Tasks 1-3 still carry full test code. Property-test strategy lines were added alongside, not in place of.

### Raised

- **PQ-9** [Minor] `done-when-contract-drift` Issue M1 row still says concealcursor=nc, and Spec/Done-when say "diagnostic" where the plan paints ParleyReviewBroken
  2nd finding in this family. Rule: a revision that changes a decision must sweep every restatement in the issue (Spec, Done-when, Plan rows, Log) in the same edit; the Revisions entry triggers that sweep and does not replace it. Prevalence so far: 2 of 2 rounds.

## Round 3 — 2026-10-09T20:54:03-07:00 (claude) — passed

### Disposed

- PQ-8 — not-addressed — Plan unchanged since round 1; Tasks 1-3 full test code and Tasks 8/10 prose case lists remain. Minor, carried to close.
- PQ-9 — not-addressed — Issue sites fixed; plan Architecture line 7 still says "snaps the normal-mode cursor" (snap is every mode since 17775389). Sweep every restatement on a decision change.

## Open findings

- **PQ-8** [Minor] `test-prose-enumeration` Tasks 8 and 10 enumerate test cases in prose and Tasks 1-3 carry full test code; compress to one strategy line per risky function
- **PQ-9** [Minor] `done-when-contract-drift` Issue M1 row still says concealcursor=nc, and Spec/Done-when say "diagnostic" where the plan paints ParleyReviewBroken
