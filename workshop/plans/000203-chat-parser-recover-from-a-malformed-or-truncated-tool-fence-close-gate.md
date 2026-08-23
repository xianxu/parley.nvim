---
gate: boundary-review
issue: 203
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-08-22T18:38:31-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Critical
          title: 'The #203 structural bound was added to the shared close_of, so ordinary fenced blocks stop establishing depth and BR-43 returns'
          detail: |-
            fence.lua:140-146 guards both the tool-body close search (line 154) and
            the depth-establishing search for any other opener (line 163). An
            ordinary fenced block containing a column-0 structural marker therefore
            never finds its close, and the scan walks into it. Verified against base
            5c65036 on the tracked BR-43 fixture tests/fixtures/fold_marker_in_prose.md:
            ex1's answer goes from [text 10..16] to [text 10..12, tool_result 13..16],
            and fold_projection folds rows 13..16, hiding real answer prose on line 16
            inside a fabricated tool fold. A base-vs-HEAD scan sweep over all tracked
            transcripts and fixtures found exactly this one divergence; the full suite
            is green because fold_invariants_spec's oracle only checks that questions
            are not folded and that foldable blocks fold. Fix: pass a `bounded` flag
            to close_of and set it only at line 154; verified that keeps every #203
            test green and restores the fixture.
          family: shared-helper-gains-caller-specific-rule
          round: 1
        - id: BR-2
          severity: Important
          title: The producer guard hand-lists five tools while the atlas claims it derives its subjects from the registry
          detail: |-
            tool_output_prefix_spec.lua iterates a hand-written READ_INPUTS of five
            tools; registered() is used only for `#registered() >= 9`, which passes
            when the registry GROWS. So a new builtin is not covered by construction,
            contradicting atlas/providers/tool_use.md and the Plan step. Unguarded:
            chat_history_search (the tool that greps chat transcripts, i.e. the most
            likely producer of a column-0 marker), emit_definition, edit_file,
            write_file, propose_edits. Drive the loop off registered() with an
            explicit, justified NON_ECHOING exclusion set.
          family: guard-covers-instance-not-class
          round: 1
        - id: BR-3
          severity: Important
          title: answer_structure.BOUNDARY still hand-lists the kind set the diff just single-sourced
          detail: |-
            answer_structure.lua:7-16 enumerates exactly STRUCTURAL_KINDS plus
            `reasoning`, in the same file that now imports is_structural_kind at
            line 41. The Plan step was "name the kind set once ... do not hand-list
            kinds at the call sites"; the sweep stopped at the predicate. This is the
            silent-drift class fold_projection.lua:12-16 already warns about for
            FOLDABLE. Derive BOUNDARY from STRUCTURAL_KINDS + reasoning (ARCH-DRY,
            ARCH-PURPOSE).
          family: hand-maintained-set-restates-source
          round: 1
        - id: BR-4
          severity: Important
          title: atlas/chat/format.md was named by the ticked atlas Plan step and not updated, and its statement is now false
          detail: |-
            Line 12 says fence.lua owns "the rule that markers inside a body are
            content". After #203 that holds only for markers that are not column-0
            structural markers. parsing.md and tool_use.md carry the new rule;
            format.md, which the Plan step explicitly named as the third surface,
            does not.
          family: atlas-surface-not-updated
          round: 1
        - id: BR-5
          severity: Important
          title: The corpus audit cited as close evidence silently skipped a tracked transcript deleted in the working tree
          detail: |-
            workshop/parley/2026-05-03.22-29-53.828_global-warming-overview.md is
            tracked at HEAD but deleted in the working tree; fold_invariants_spec's
            filereadable skip drops it and the `>= 8` floor cannot notice, and the
            two untracked replacements are not picked up. I restored the file from
            HEAD and confirmed it shows no base-vs-HEAD scan divergence, so it is not
            hiding a failure — but Done-when claims the audit ran "over every tracked
            transcript" and it did not. Resolve the tree state before close.
          family: silent-skip-guard
          round: 1
        - id: BR-6
          severity: Minor
          title: fence.scan's docblock now has duplicated @param lines / @param is_tool_marker entries, with @param after @return
          detail: fence.lua:115-125. Collapse the two blocks into one.
          family: docblock-hygiene
          round: 1
        - id: BR-7
          severity: Minor
          title: fold_projection's is_structural predicate does a per-line require plus a second full classify in a function documented as per-streamed-chunk hot
          detail: |-
            fold_projection.lua:140-141 re-classifies lines the scan's is_tool_marker
            already classified, inside verify_anchors, whose own comment (lines
            108-113) justifies using a raw prefix match precisely because full
            classification costs ~10 pattern matches plus a footnote lookup per line.
            Hoist the module reference and share one kinds memo.
          family: redundant-per-line-work-in-scan
          round: 1
        - id: BR-8
          severity: Minor
          title: tool_output_prefix_spec iterates READ_INPUTS with pairs(), so test order varies run to run
          detail: tool_output_prefix_spec.lua:79. Use a sorted array of names.
          family: nondeterministic-test-registration
          round: 1
        - id: BR-9
          severity: Minor
          title: workshop/plans/203-experiment.patch is 1760 lines, ~1690 of which are a corpus transcript it would delete on apply
          detail: |-
            The actual experiment is ~40 lines; the rest is the full text of
            workshop/parley/...global-warming-overview.md as deletion lines. The
            issue Log says "tree restored, nothing committed", yet this was
            committed. Prune to the experiment hunks or drop it — the Revisions
            section already records the decision. It also does not follow the
            NNNNNN-slug-plan.md convention for workshop/plans/.
          family: experiment-artifact-committed-unpruned
          round: 1
        - id: BR-10
          severity: Minor
          title: STRUCTURAL_KINDS and is_structural_kind have no direct unit test despite deciding the rule
          detail: |-
            tests/unit/highlight_structure_spec.lua is untouched. Nothing pins the
            set's membership against classify's kind vocabulary, nor the deliberate
            exclusion of `reasoning` / `reasoning_end` that the docstring calls out.
          family: single-source-untested-directly
          round: 1
        - id: BR-11
          severity: Minor
          title: fence.scan's is_structural is documented "Required in practice" but is optional in the signature
          detail: |-
            fence.lua:122-126. A fourth caller that omits it silently gets the
            pre-#203 close search. Make it required, or assert on nil.
          family: optional-param-documented-as-required
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#203 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-22T18:38:31-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `shared-helper-gains-caller-specific-rule` The #203 structural bound was added to the shared close_of, so ordinary fenced blocks stop establishing depth and BR-43 returns
  fence.lua:140-146 guards both the tool-body close search (line 154) and
  the depth-establishing search for any other opener (line 163). An
  ordinary fenced block containing a column-0 structural marker therefore
  never finds its close, and the scan walks into it. Verified against base
  5c65036 on the tracked BR-43 fixture tests/fixtures/fold_marker_in_prose.md:
  ex1's answer goes from [text 10..16] to [text 10..12, tool_result 13..16],
  and fold_projection folds rows 13..16, hiding real answer prose on line 16
  inside a fabricated tool fold. A base-vs-HEAD scan sweep over all tracked
  transcripts and fixtures found exactly this one divergence; the full suite
  is green because fold_invariants_spec's oracle only checks that questions
  are not folded and that foldable blocks fold. Fix: pass a `bounded` flag
  to close_of and set it only at line 154; verified that keeps every #203
  test green and restores the fixture.
- **BR-2** [Important] `guard-covers-instance-not-class` The producer guard hand-lists five tools while the atlas claims it derives its subjects from the registry
  tool_output_prefix_spec.lua iterates a hand-written READ_INPUTS of five
  tools; registered() is used only for `#registered() >= 9`, which passes
  when the registry GROWS. So a new builtin is not covered by construction,
  contradicting atlas/providers/tool_use.md and the Plan step. Unguarded:
  chat_history_search (the tool that greps chat transcripts, i.e. the most
  likely producer of a column-0 marker), emit_definition, edit_file,
  write_file, propose_edits. Drive the loop off registered() with an
  explicit, justified NON_ECHOING exclusion set.
- **BR-3** [Important] `hand-maintained-set-restates-source` answer_structure.BOUNDARY still hand-lists the kind set the diff just single-sourced
  answer_structure.lua:7-16 enumerates exactly STRUCTURAL_KINDS plus
  `reasoning`, in the same file that now imports is_structural_kind at
  line 41. The Plan step was "name the kind set once ... do not hand-list
  kinds at the call sites"; the sweep stopped at the predicate. This is the
  silent-drift class fold_projection.lua:12-16 already warns about for
  FOLDABLE. Derive BOUNDARY from STRUCTURAL_KINDS + reasoning (ARCH-DRY,
  ARCH-PURPOSE).
- **BR-4** [Important] `atlas-surface-not-updated` atlas/chat/format.md was named by the ticked atlas Plan step and not updated, and its statement is now false
  Line 12 says fence.lua owns "the rule that markers inside a body are
  content". After #203 that holds only for markers that are not column-0
  structural markers. parsing.md and tool_use.md carry the new rule;
  format.md, which the Plan step explicitly named as the third surface,
  does not.
- **BR-5** [Important] `silent-skip-guard` The corpus audit cited as close evidence silently skipped a tracked transcript deleted in the working tree
  workshop/parley/2026-05-03.22-29-53.828_global-warming-overview.md is
  tracked at HEAD but deleted in the working tree; fold_invariants_spec's
  filereadable skip drops it and the `>= 8` floor cannot notice, and the
  two untracked replacements are not picked up. I restored the file from
  HEAD and confirmed it shows no base-vs-HEAD scan divergence, so it is not
  hiding a failure — but Done-when claims the audit ran "over every tracked
  transcript" and it did not. Resolve the tree state before close.
- **BR-6** [Minor] `docblock-hygiene` fence.scan's docblock now has duplicated @param lines / @param is_tool_marker entries, with @param after @return
  fence.lua:115-125. Collapse the two blocks into one.
- **BR-7** [Minor] `redundant-per-line-work-in-scan` fold_projection's is_structural predicate does a per-line require plus a second full classify in a function documented as per-streamed-chunk hot
  fold_projection.lua:140-141 re-classifies lines the scan's is_tool_marker
  already classified, inside verify_anchors, whose own comment (lines
  108-113) justifies using a raw prefix match precisely because full
  classification costs ~10 pattern matches plus a footnote lookup per line.
  Hoist the module reference and share one kinds memo.
- **BR-8** [Minor] `nondeterministic-test-registration` tool_output_prefix_spec iterates READ_INPUTS with pairs(), so test order varies run to run
  tool_output_prefix_spec.lua:79. Use a sorted array of names.
- **BR-9** [Minor] `experiment-artifact-committed-unpruned` workshop/plans/203-experiment.patch is 1760 lines, ~1690 of which are a corpus transcript it would delete on apply
  The actual experiment is ~40 lines; the rest is the full text of
  workshop/parley/...global-warming-overview.md as deletion lines. The
  issue Log says "tree restored, nothing committed", yet this was
  committed. Prune to the experiment hunks or drop it — the Revisions
  section already records the decision. It also does not follow the
  NNNNNN-slug-plan.md convention for workshop/plans/.
- **BR-10** [Minor] `single-source-untested-directly` STRUCTURAL_KINDS and is_structural_kind have no direct unit test despite deciding the rule
  tests/unit/highlight_structure_spec.lua is untouched. Nothing pins the
  set's membership against classify's kind vocabulary, nor the deliberate
  exclusion of `reasoning` / `reasoning_end` that the docstring calls out.
- **BR-11** [Minor] `optional-param-documented-as-required` fence.scan's is_structural is documented "Required in practice" but is optional in the signature
  fence.lua:122-126. A fourth caller that omits it silently gets the
  pre-#203 close search. Make it required, or assert on nil.

## Open findings

- **BR-1** [Critical] `shared-helper-gains-caller-specific-rule` The #203 structural bound was added to the shared close_of, so ordinary fenced blocks stop establishing depth and BR-43 returns
- **BR-2** [Important] `guard-covers-instance-not-class` The producer guard hand-lists five tools while the atlas claims it derives its subjects from the registry
- **BR-3** [Important] `hand-maintained-set-restates-source` answer_structure.BOUNDARY still hand-lists the kind set the diff just single-sourced
- **BR-4** [Important] `atlas-surface-not-updated` atlas/chat/format.md was named by the ticked atlas Plan step and not updated, and its statement is now false
- **BR-5** [Important] `silent-skip-guard` The corpus audit cited as close evidence silently skipped a tracked transcript deleted in the working tree
- **BR-6** [Minor] `docblock-hygiene` fence.scan's docblock now has duplicated @param lines / @param is_tool_marker entries, with @param after @return
- **BR-7** [Minor] `redundant-per-line-work-in-scan` fold_projection's is_structural predicate does a per-line require plus a second full classify in a function documented as per-streamed-chunk hot
- **BR-8** [Minor] `nondeterministic-test-registration` tool_output_prefix_spec iterates READ_INPUTS with pairs(), so test order varies run to run
- **BR-9** [Minor] `experiment-artifact-committed-unpruned` workshop/plans/203-experiment.patch is 1760 lines, ~1690 of which are a corpus transcript it would delete on apply
- **BR-10** [Minor] `single-source-untested-directly` STRUCTURAL_KINDS and is_structural_kind have no direct unit test despite deciding the rule
- **BR-11** [Minor] `optional-param-documented-as-required` fence.scan's is_structural is documented "Required in practice" but is optional in the signature
