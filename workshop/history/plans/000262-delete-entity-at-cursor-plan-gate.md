---
gate: plan-quality
issue: 262
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-16T12:56:14-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: The text-object snippet breaks `vae`; an x-mode mapping must leave visual mode before `normal!`
          detail: |-
            Verified on nvim 0.11.7 with the plan's exact snippet: `dae`/`yae` take lines
            4-6 correctly, but `vae` from row 5 selects 5..6 because the `V` in
            `normal! 4GV6G` toggles the already-active linewise visual OFF. Prepending an
            escape restores 4..6. Done-when names `v` explicitly; Task 10 tests only
            dae/daE/die. Reuse the existing per-mode callback idiom at init.lua:2805-2812
            (chat_exchange_cut's v/x entries already do `normal! <Esc>` first) rather than
            inventing a second shape (ARCH-DRY), and add a `vae` case to Task 10.
          family: visual-mode-normal-reentry
          round: 1
        - id: PQ-2
          severity: Important
          title: Tasks 9 and 14 call `sdlc milestone-close --milestone M1|M2` but the issue's Plan has no Mx rows
          detail: |-
            `sdlc milestone-close --help` states it "ticks the `- [ ] Mx — ...` item in
            ## Plan"; the issue's ## Plan is seven plain checkboxes. `sdlc close --help`
            adds that a Plan with only plain checkboxes carries no Review-Verdict
            requirement, so the two boundary reviews would also go undemanded at issue
            close. The two-boundary split is justified — tag the issue's ## Plan rows M1
            (detection + marker policy) and M2 (surface, tests, docs) to match the plan
            file, per AGENTS.md section 3.
          family: milestone-tag-contract
          round: 1
        - id: PQ-3
          severity: Important
          title: '`to_end` can delete to EOF: the exchange is resolved with one span definition and bounded with another'
          detail: |-
            `exchange_at` resolves via chat_parser.find_exchange_at_line, whose containment
            test ends at the TRIMMED `answer.line_end` (chat_parser.lua:219-230, :383), then
            bounds via exchange_clipboard.get_exchange_line_range, which runs to
            `semantic_start(next)-1` and by its own header comment
            (exchange_clipboard.lua:1-6) includes trailing blanks and branch markers. A
            cursor in that gap resolves to no exchange, so `scope="to_end"` falls into the
            "outside any exchange" branch and runs to EOF across every later exchange —
            violating the plan's own "never crosses the next question" guarantee. Task 7's
            test 4 is written from a body paragraph and cannot see it. Name which
            definition owns the span and test a cursor on a trailing blank and on a branch
            line.
          family: exchange-span-source-mismatch
          round: 1
        - id: PQ-4
          severity: Important
          title: Four Spec/Done-when deviations are made silently after one was correctly recorded in Revisions
          detail: |-
            The class, enumerated: (a) the branch-link policy — Spec offers preserve /
            refuse / warn and Done-when forbids silent orphaning, the plan picks "ordinary
            content" i.e. silent deletion; (b) the summary on a whole-exchange delete —
            Spec defaults to preserve-uniformly and Done-when says summaries survive a
            spanning deletion, the plan drops it, attributed to an operator decision with
            no record in the issue Log; (c) heading levels — Spec says one through six,
            the dialect caps at three, parked as an Open item rather than recorded; (d)
            dap equivalence — Done-when requires it verified in tests, Task 4's own cases
            diverge on a blank-line cursor and on a final paragraph with no trailing
            blanks. Write one Revisions entry plus the Done-when edits covering all four
            in this round, the way the precedence deviation was handled (ARCH-PURPOSE:
            the class, not the instance).
          family: undeclared-spec-deviation
          round: 1
        - id: PQ-5
          severity: Minor
          title: Several cited seams and file:line anchors do not say what the plan claims
          detail: |-
            `lexical.token(line, patterns)` does not exist and `M.classify`
            (lexical.lua:78-110) never computes heading_level — only `finish(c)` does, via
            lex_start/lex_step/lex_token (:298,385,381). Makefile.parley's perf target is
            at line 198, not ~57 (cited twice). outline.lua's heading branch is gated by
            `elseif not opts.is_chat` (:52) and emits per-level indent prefixes, neither
            supplied by markdown_heading.level. single_source_sweeps_spec.lua:588-647 is
            about native_map/feature_gated, not hand-rolled vim.keymap.set.
            buffer_mutation_spec.lua:41 currently ALLOWS nvim_buf_set_lines in init.lua.
            init.lua:216 documents #215's fix to parse_chat_headers, not a live not_chat
            hazard. None of these change a design decision; all are recoverable at
            implementation time.
          family: unverified-code-claim
          round: 1
        - id: PQ-6
          severity: Minor
          title: The summary-preservation predicate is written three incompatible ways
          detail: |-
            Core concepts says "when `last` would land on or after a summary line ... it is
            pulled back", which would wrongly trim Task 7's interior-summary case; the next
            sentence says "preservation is an edge-trim only"; Task 7's summary_guard says
            "at or after `range.last`'s trailing-blank region". State it once: trim only
            when the summary line lies inside the range and everything after it inside the
            range is blank.
          family: rule-stated-twice-differently
          round: 1
        - id: PQ-7
          severity: Minor
          title: The parity test pins the two surfaces only on a static buffer, where they cannot diverge
          detail: |-
            The programmatic path inherits replace_user_lines' refusal (buffer_edit.lua:91-94
            raises on an unavailable or refused grant) while the native `d` path does not —
            so the two surfaces differ exactly when a response is streaming into the
            exchange, which is the one ordering the plan itself identifies as unblockable
            (ARCH-ORDER). Say that the parity claim is scoped to a quiescent document, or
            give the text object the same refusal.
          family: two-surface-parity-scope
          round: 1
        - id: PQ-8
          severity: Minor
          title: Tasks 6 and 7 enumerate fourteen test cases in prose instead of stating the property
          detail: |-
            Tasks 2, 4 and 5 give literal test code, which is right. Tasks 6 and 7 give
            numbered prose lists that will be rewritten as code within the hour. Compress
            to the invariants they encode plus one adversarial-input line for
            `entity_range.range` — the input is arbitrary hand-edited transcript text, so:
            property-test over generated line arrays asserting first <= last, range within
            [1,#lines], and no range spanning a question marker other than its own.
          family: prose-test-enumeration
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-16T13:06:21-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Escape-before-normal added, reusing the init.lua:2803-2812 idiom; vae now tested in Tasks 10 and 13.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: 'Issue ## Plan now carries M1/M2 rows matching the plan file''s two chunks.'
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Rule 1 names get_exchange_line_range as the sole span, with a fallback scan for rows in the trailing gap.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: One Revisions entry covers all four deviations as a class, with matching Done-when edits.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: 'Anchors re-verified: lexical 298/381/385, Makefile.parley 198, outline is_chat gate, agreement-spec MODES.'
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Predicate stated once as rule 5; summary_trim implements exactly it.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: Parity scoped to a quiescent document in Done-when, ARCH-ORDER, and the Task 13 comment.
          round: 2
        - id: PQ-8
          disposition: addressed
          note: Tasks 6 and 7 are now literal test code plus a property test over malformed transcripts.
          round: 2
      blocked: false
content_hash: 60127bf8f0ab7ce4cd2198ec847a37bc0f35880d749c7e8dd9ac23186cf397d7
---

# Gate ledger — parley.nvim#262 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-16T12:56:14-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `visual-mode-normal-reentry` The text-object snippet breaks `vae`; an x-mode mapping must leave visual mode before `normal!`
  Verified on nvim 0.11.7 with the plan's exact snippet: `dae`/`yae` take lines
  4-6 correctly, but `vae` from row 5 selects 5..6 because the `V` in
  `normal! 4GV6G` toggles the already-active linewise visual OFF. Prepending an
  escape restores 4..6. Done-when names `v` explicitly; Task 10 tests only
  dae/daE/die. Reuse the existing per-mode callback idiom at init.lua:2805-2812
  (chat_exchange_cut's v/x entries already do `normal! <Esc>` first) rather than
  inventing a second shape (ARCH-DRY), and add a `vae` case to Task 10.
- **PQ-2** [Important] `milestone-tag-contract` Tasks 9 and 14 call `sdlc milestone-close --milestone M1|M2` but the issue's Plan has no Mx rows
  `sdlc milestone-close --help` states it "ticks the `- [ ] Mx — ...` item in
  ## Plan"; the issue's ## Plan is seven plain checkboxes. `sdlc close --help`
  adds that a Plan with only plain checkboxes carries no Review-Verdict
  requirement, so the two boundary reviews would also go undemanded at issue
  close. The two-boundary split is justified — tag the issue's ## Plan rows M1
  (detection + marker policy) and M2 (surface, tests, docs) to match the plan
  file, per AGENTS.md section 3.
- **PQ-3** [Important] `exchange-span-source-mismatch` `to_end` can delete to EOF: the exchange is resolved with one span definition and bounded with another
  `exchange_at` resolves via chat_parser.find_exchange_at_line, whose containment
  test ends at the TRIMMED `answer.line_end` (chat_parser.lua:219-230, :383), then
  bounds via exchange_clipboard.get_exchange_line_range, which runs to
  `semantic_start(next)-1` and by its own header comment
  (exchange_clipboard.lua:1-6) includes trailing blanks and branch markers. A
  cursor in that gap resolves to no exchange, so `scope="to_end"` falls into the
  "outside any exchange" branch and runs to EOF across every later exchange —
  violating the plan's own "never crosses the next question" guarantee. Task 7's
  test 4 is written from a body paragraph and cannot see it. Name which
  definition owns the span and test a cursor on a trailing blank and on a branch
  line.
- **PQ-4** [Important] `undeclared-spec-deviation` Four Spec/Done-when deviations are made silently after one was correctly recorded in Revisions
  The class, enumerated: (a) the branch-link policy — Spec offers preserve /
  refuse / warn and Done-when forbids silent orphaning, the plan picks "ordinary
  content" i.e. silent deletion; (b) the summary on a whole-exchange delete —
  Spec defaults to preserve-uniformly and Done-when says summaries survive a
  spanning deletion, the plan drops it, attributed to an operator decision with
  no record in the issue Log; (c) heading levels — Spec says one through six,
  the dialect caps at three, parked as an Open item rather than recorded; (d)
  dap equivalence — Done-when requires it verified in tests, Task 4's own cases
  diverge on a blank-line cursor and on a final paragraph with no trailing
  blanks. Write one Revisions entry plus the Done-when edits covering all four
  in this round, the way the precedence deviation was handled (ARCH-PURPOSE:
  the class, not the instance).
- **PQ-5** [Minor] `unverified-code-claim` Several cited seams and file:line anchors do not say what the plan claims
  `lexical.token(line, patterns)` does not exist and `M.classify`
  (lexical.lua:78-110) never computes heading_level — only `finish(c)` does, via
  lex_start/lex_step/lex_token (:298,385,381). Makefile.parley's perf target is
  at line 198, not ~57 (cited twice). outline.lua's heading branch is gated by
  `elseif not opts.is_chat` (:52) and emits per-level indent prefixes, neither
  supplied by markdown_heading.level. single_source_sweeps_spec.lua:588-647 is
  about native_map/feature_gated, not hand-rolled vim.keymap.set.
  buffer_mutation_spec.lua:41 currently ALLOWS nvim_buf_set_lines in init.lua.
  init.lua:216 documents #215's fix to parse_chat_headers, not a live not_chat
  hazard. None of these change a design decision; all are recoverable at
  implementation time.
- **PQ-6** [Minor] `rule-stated-twice-differently` The summary-preservation predicate is written three incompatible ways
  Core concepts says "when `last` would land on or after a summary line ... it is
  pulled back", which would wrongly trim Task 7's interior-summary case; the next
  sentence says "preservation is an edge-trim only"; Task 7's summary_guard says
  "at or after `range.last`'s trailing-blank region". State it once: trim only
  when the summary line lies inside the range and everything after it inside the
  range is blank.
- **PQ-7** [Minor] `two-surface-parity-scope` The parity test pins the two surfaces only on a static buffer, where they cannot diverge
  The programmatic path inherits replace_user_lines' refusal (buffer_edit.lua:91-94
  raises on an unavailable or refused grant) while the native `d` path does not —
  so the two surfaces differ exactly when a response is streaming into the
  exchange, which is the one ordering the plan itself identifies as unblockable
  (ARCH-ORDER). Say that the parity claim is scoped to a quiescent document, or
  give the text object the same refusal.
- **PQ-8** [Minor] `prose-test-enumeration` Tasks 6 and 7 enumerate fourteen test cases in prose instead of stating the property
  Tasks 2, 4 and 5 give literal test code, which is right. Tasks 6 and 7 give
  numbered prose lists that will be rewritten as code within the hour. Compress
  to the invariants they encode plus one adversarial-input line for
  `entity_range.range` — the input is arbitrary hand-edited transcript text, so:
  property-test over generated line arrays asserting first <= last, range within
  [1,#lines], and no range spanning a question marker other than its own.

## Round 2 — 2026-09-16T13:06:21-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Escape-before-normal added, reusing the init.lua:2803-2812 idiom; vae now tested in Tasks 10 and 13.
- PQ-2 — addressed — Issue ## Plan now carries M1/M2 rows matching the plan file's two chunks.
- PQ-3 — addressed — Rule 1 names get_exchange_line_range as the sole span, with a fallback scan for rows in the trailing gap.
- PQ-4 — addressed — One Revisions entry covers all four deviations as a class, with matching Done-when edits.
- PQ-5 — addressed — Anchors re-verified: lexical 298/381/385, Makefile.parley 198, outline is_chat gate, agreement-spec MODES.
- PQ-6 — addressed — Predicate stated once as rule 5; summary_trim implements exactly it.
- PQ-7 — addressed — Parity scoped to a quiescent document in Done-when, ARCH-ORDER, and the Task 13 comment.
- PQ-8 — addressed — Tasks 6 and 7 are now literal test code plus a property test over malformed transcripts.

## Open findings

(none — every finding has been disposed)
