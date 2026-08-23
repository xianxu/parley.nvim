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
    - "n": 2
      timestamp: "2026-08-22T18:55:56-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Verified by revert (fence_spec goes red) and by a 321-file base-vs-HEAD parse sweep that diffs empty.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Verified by revert; removing emit_definition from NOT_ECHOING turns the new case red. Residual is the call-shape axis, raised as a new Critical in the same family.
          round: 2
        - id: BR-3
          disposition: addressed
          note: BOUNDARY now derives; membership identical to the old hand-list, suite green.
          round: 2
        - id: BR-4
          disposition: addressed
          note: format.md updated; its new wording is imprecise ("INDENTED", "how every tool emits them") and is folded into the new Critical's doc fix.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: Tree state unresolved (the transcript is still deleted-but-unstaged), Done-when still claims "every tracked transcript", the <= 1 threshold encodes the current breakage, and Makefile.parley's RUN_SPEC discards the print on pass.
          round: 2
        - id: BR-6
          disposition: not-addressed
          note: Docblock still has duplicate @param lines/@param is_tool_marker after @return, and the rework merged the bounded rationale into the comment above the UNBOUNDED close_of, so it now reads as its own contradiction on the function BR-1 turned on.
          round: 2
        - id: BR-7
          disposition: not-addressed
          note: fold_projection.lua:139-141 unchanged; the same per-call require now also exists at answer_structure.lua:41.
          round: 2
        - id: BR-8
          disposition: not-addressed
          note: tool_output_prefix_spec.lua:105 still iterates pairs(READ_INPUTS).
          round: 2
        - id: BR-9
          disposition: not-addressed
          note: workshop/plans/203-experiment.patch still committed at 1760 lines, still deletes a tracked transcript on apply.
          round: 2
        - id: BR-10
          disposition: not-addressed
          note: highlight_structure_spec.lua untouched, and it is not in chat/parsing's tests list even though highlight_structure.lua was added to that entry's code list.
          round: 2
        - id: BR-11
          disposition: not-addressed
          note: fence.lua:126 signature unchanged; is_structural still optional.
          round: 2
      findings:
        - id: BR-12
          severity: Critical
          title: grep/ack omit --with-filename, so a single-file search emits column-0 markers and a well-formed tool body now forks the chat
          detail: |-
            This is the 2nd finding in family guard-covers-instance-not-class, so
            the ask is the RULE, not this instance: a producer-side invariant must be
            ENFORCED by the producer and guarded across the tool x call-shape x
            content-shape matrix, never observed on one hand-picked call.
            Verified enumeration on this machine: grep with path=<single file> returns
            the raw matched line, no prefix (kind=user, structural=true); ack the same;
            ls returns bare basenames with no prefix mechanism at all, so a directory
            holding a file named "the marker: notes.md" emits a column-0 marker on a
            success path; find's prefix comes from the caller's path arg and its guard
            case is vacuous; chat_history_search is excluded by assertion and never
            exercised. End-to-end on the block tools/serialize.render_result writes for
            grep-on-a-single-file: 3 exchanges at dbb2ed9 vs 2 at 5c65036 — the grep
            output line becomes a real question, so Spec bullet 2 and Done-when bullet 2
            ("well-formed bodies unaffected") are false as shipped. The guard misses it
            because tool_output_prefix_spec.lua:91-94 receives the file and passes the
            directory. NOT_ECHOING:84 names the fix itself — chat_history_search is
            excluded because it runs rg with --with-filename --line-number, the flags
            grep/ack omit. Consolidate that prefixing discipline (ARCH-DRY), drive
            READ_INPUTS off a call-shape product with a marker-named file in the
            fixture, and move whatever remains into the atlas's stated-exception
            paragraph. Three doc statements are falsified and must change with it:
            atlas/providers/tool_use.md's "no tool emits a column-0 marker … ls/find
            paths", the same claim at lua/parley/fence.lua:134-139, and
            atlas/chat/format.md:12's "content when they are INDENTED, which is how
            every tool emits them" (only read_file indents; a column-0 reasoning marker
            is still content).
          family: guard-covers-instance-not-class
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-08-22T19:17:37-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: Named exclusion with teeth — removing the KNOWN_UNREADABLE entry turns the new case red; I also confirmed the excluded transcript shows no base-vs-HEAD divergence.
          round: 3
        - id: BR-6
          disposition: addressed
          note: scan's docblock is one block now; the same commit duplicated extract_body's and deleted scan's @return, raised as the family's 2nd finding rather than re-raised here.
          round: 3
        - id: BR-7
          disposition: not-addressed
          note: answer_structure's per-call require is gone and fold_projection's laziness is now justified, but the second full classify per line remains — no shared kinds memo.
          round: 3
        - id: BR-8
          disposition: addressed
          note: Both the tool names and the shape names are sorted before registration.
          round: 3
        - id: BR-9
          disposition: not-addressed
          note: workshop/plans/203-experiment.patch still tracked at 1760 lines and still deletes a tracked transcript on apply.
          round: 3
        - id: BR-10
          disposition: not-addressed
          note: highlight_structure_spec.lua untouched and still absent from chat/parsing's tests list though the module is in its code list.
          round: 3
        - id: BR-11
          disposition: not-addressed
          note: fence.lua:108 signature unchanged; the guard at :145 is still `if is_structural and ...`.
          round: 3
        - id: BR-12
          disposition: addressed
          note: Verified by revert (grep and ack single-file cases both go red without -H) and end-to-end (serialized grep-on-a-single-file block parses to 2 exchanges, matching base); 343-file base-vs-HEAD sweep diffs empty.
          round: 3
      findings:
        - id: BR-13
          severity: Important
          title: The fence.lua docblock rework deleted M.scan's grammar prose and both @return lines, and duplicated extract_body's block
          detail: |-
            This is the 2nd finding in family docblock-hygiene, so the ask is the
            RULE. fence.lua:76-85 carries extract_body's docblock twice verbatim, and
            M.scan's docblock at :102-107 lost the "One linear pass" grammar
            description and both @return entries — the bodies extent model
            (marker_row -> {first,last,close}, first > last for an empty body, close
            nil when none found) is now undocumented, though #200 BR-52 requires
            consumers to branch on exactly that. Two atlas pages designate this
            docstring as the specification and are falsified by the deletion:
            atlas/chat/parsing.md:19 ("see its docstrings for the grammar itself") and
            atlas/providers/tool_use.md:153 ("Its docstrings are the specification —
            this page deliberately does not restate the rule"), which then restates
            the rule twice in its own new section. The rule: fence.lua's docstrings
            are a designated specification surface, not commentary, so a docblock
            rewrite must be diffed against the block it replaces — the Log records
            this edit as a recovered span-edit, which is the exact failure mode that
            silently drops a block. Enumeration for this round: every docblock touched
            in 5c65036..bd1a623 (fence.extract_body, fence.scan,
            highlight_structure.STRUCTURAL_KINDS, highlight_structure.is_structural_kind
            — the last has no @param or @return at all), checked for no duplication, a
            @param per parameter, a @return per return value, and any prose an atlas
            page defers to.
          family: docblock-hygiene
          round: 3
        - id: BR-14
          severity: Important
          title: A test still asserts by name the premise this issue refuted, and stays green because its assertion cannot see the change
          detail: |-
            chat_parser_tools_spec.lua:407 "treats a tool-result marker inside a tool
            body as content" puts a column-0 tool-result marker inside a grep body and
            asserts only that there is 1 exchange. Measured on that exact window:
            base 5c65036 gives bodies[1] = {first=3,last=4,close=5} (the marker IS body
            content), HEAD gives bodies[1] = nil (the body is refused and the marker is
            skipped by depth). Both yield 1 exchange, so the assertion cannot
            distinguish, and the test now reads as coverage for the opposite of what
            the code does. Plan step 7 enumerated "the tests that went red" rather than
            "the tests that encode the premise", which is why this one was never swept.
            Consequence beyond the stale name: nothing anywhere pins the tool-marker
            members of STRUCTURAL_KINDS — fence_spec, the new chat_parser fork case and
            fold_projection_spec all use a user-marker predicate, so tool_use,
            tool_result, summary, branch and local bounding a body is asserted nowhere,
            in the issue that single-sourced that set. Fix: give this case the "%5d  "
            prefix its siblings got, and add a case pinning a column-0 tool-result
            marker refusing the body, asserted on fence.scan's bodies.
          family: stale-test-premise
          round: 3
        - id: BR-15
          severity: Minor
          title: The producer guard silently drops ack coverage on a host without ack, while the atlas claims it fails loudly rather than skipping
          detail: |-
            This is the 2nd finding in family silent-skip-guard, so the ask is the
            RULE, not this instance. tool_output_prefix_spec.lua:141-151 returns
            Success after asserting only "is optional" when tools.get returns nil, so
            on a host without ack 2 of 7 cases vanish with nothing reporting it —
            while atlas/providers/tool_use.md:197 states the guard "fails loudly
            rather than skipping when a tool is unregistered". Same file, same shape:
            the marker-named fixture at :47 says "without this the path-echoing tools
            were never exercised", but ls/find were moved to NOT_ECHOING at :116-117,
            so no case reads it. The rule: every coverage-dropping skip must be
            counted and asserted against a NAMED allowlist with a reason — which is
            exactly the mechanism fold_invariants_spec.lua:95-109 now has for its
            corpus. Apply that same shape here (a named OPTIONAL_ABSENT record, and a
            case that fails when a fixture no consumer reads is left behind), and make
            the atlas sentence state the exception instead of overstating it.
          family: silent-skip-guard
          round: 3
        - id: BR-16
          severity: Minor
          title: The producer guard's own header still states the absolute claim BR-12 falsified, contradicting its body 100 lines down
          detail: |-
            This is the 2nd finding in family atlas-surface-not-updated, so the ask is
            the RULE. tool_output_prefix_spec.lua:3-8 still reads "no tool EMITS one —
            every tool prefixes its output", which BR-12 disproved and which :110-117
            of the same file contradicts. Six of the invariant's seven prose
            restatements (fence.lua, grep.lua, ack.lua, tool_use.md, format.md,
            parsing.md) were updated for BR-12 and this one was not. The rule: the
            producer invariant must be STATED once — in atlas/providers/tool_use.md's
            bounded-claim paragraph — and every other site must point at it rather
            than restate it, because a restatement is a deferred consumer that drifts
            silently (ARCH-DRY). Enumeration: grep the tree for "prefixes its output",
            "column-0 marker" and "-H" and reduce each hit to a pointer.
          family: atlas-surface-not-updated
          round: 3
        - id: BR-17
          severity: Minor
          title: fold_projection's new is_structural closure reads an upvalue initialized only as a side effect of another closure
          detail: |-
            fold_projection.lua:140 calls highlight_structure.is_structural_kind on the
            local declared at :94, which is assigned only inside the `not patterns`
            branch or as a side effect of the DEFAULT classify closure at :98-101. With
            M._classify injected — the seam that line exists for — the first tool_use /
            tool_result range indexes a nil value and verify_anchors crashes. Nothing
            sets M._classify today so it is unreachable, but the diff introduced the
            coupling. One unconditional assignment of highlight_structure before the
            loop removes it.
          family: closure-captures-lazy-upvalue
          round: 3
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

## Round 2 — 2026-08-22T18:55:56-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Verified by revert (fence_spec goes red) and by a 321-file base-vs-HEAD parse sweep that diffs empty.
- BR-2 — addressed — Verified by revert; removing emit_definition from NOT_ECHOING turns the new case red. Residual is the call-shape axis, raised as a new Critical in the same family.
- BR-3 — addressed — BOUNDARY now derives; membership identical to the old hand-list, suite green.
- BR-4 — addressed — format.md updated; its new wording is imprecise ("INDENTED", "how every tool emits them") and is folded into the new Critical's doc fix.
- BR-5 — not-addressed — Tree state unresolved (the transcript is still deleted-but-unstaged), Done-when still claims "every tracked transcript", the <= 1 threshold encodes the current breakage, and Makefile.parley's RUN_SPEC discards the print on pass.
- BR-6 — not-addressed — Docblock still has duplicate @param lines/@param is_tool_marker after @return, and the rework merged the bounded rationale into the comment above the UNBOUNDED close_of, so it now reads as its own contradiction on the function BR-1 turned on.
- BR-7 — not-addressed — fold_projection.lua:139-141 unchanged; the same per-call require now also exists at answer_structure.lua:41.
- BR-8 — not-addressed — tool_output_prefix_spec.lua:105 still iterates pairs(READ_INPUTS).
- BR-9 — not-addressed — workshop/plans/203-experiment.patch still committed at 1760 lines, still deletes a tracked transcript on apply.
- BR-10 — not-addressed — highlight_structure_spec.lua untouched, and it is not in chat/parsing's tests list even though highlight_structure.lua was added to that entry's code list.
- BR-11 — not-addressed — fence.lua:126 signature unchanged; is_structural still optional.

### Raised

- **BR-12** [Critical] `guard-covers-instance-not-class` grep/ack omit --with-filename, so a single-file search emits column-0 markers and a well-formed tool body now forks the chat
  This is the 2nd finding in family guard-covers-instance-not-class, so
  the ask is the RULE, not this instance: a producer-side invariant must be
  ENFORCED by the producer and guarded across the tool x call-shape x
  content-shape matrix, never observed on one hand-picked call.
  Verified enumeration on this machine: grep with path=<single file> returns
  the raw matched line, no prefix (kind=user, structural=true); ack the same;
  ls returns bare basenames with no prefix mechanism at all, so a directory
  holding a file named "the marker: notes.md" emits a column-0 marker on a
  success path; find's prefix comes from the caller's path arg and its guard
  case is vacuous; chat_history_search is excluded by assertion and never
  exercised. End-to-end on the block tools/serialize.render_result writes for
  grep-on-a-single-file: 3 exchanges at dbb2ed9 vs 2 at 5c65036 — the grep
  output line becomes a real question, so Spec bullet 2 and Done-when bullet 2
  ("well-formed bodies unaffected") are false as shipped. The guard misses it
  because tool_output_prefix_spec.lua:91-94 receives the file and passes the
  directory. NOT_ECHOING:84 names the fix itself — chat_history_search is
  excluded because it runs rg with --with-filename --line-number, the flags
  grep/ack omit. Consolidate that prefixing discipline (ARCH-DRY), drive
  READ_INPUTS off a call-shape product with a marker-named file in the
  fixture, and move whatever remains into the atlas's stated-exception
  paragraph. Three doc statements are falsified and must change with it:
  atlas/providers/tool_use.md's "no tool emits a column-0 marker … ls/find
  paths", the same claim at lua/parley/fence.lua:134-139, and
  atlas/chat/format.md:12's "content when they are INDENTED, which is how
  every tool emits them" (only read_file indents; a column-0 reasoning marker
  is still content).

## Round 3 — 2026-08-22T19:17:37-07:00 (claude) — BLOCKED

### Disposed

- BR-5 — addressed — Named exclusion with teeth — removing the KNOWN_UNREADABLE entry turns the new case red; I also confirmed the excluded transcript shows no base-vs-HEAD divergence.
- BR-6 — addressed — scan's docblock is one block now; the same commit duplicated extract_body's and deleted scan's @return, raised as the family's 2nd finding rather than re-raised here.
- BR-7 — not-addressed — answer_structure's per-call require is gone and fold_projection's laziness is now justified, but the second full classify per line remains — no shared kinds memo.
- BR-8 — addressed — Both the tool names and the shape names are sorted before registration.
- BR-9 — not-addressed — workshop/plans/203-experiment.patch still tracked at 1760 lines and still deletes a tracked transcript on apply.
- BR-10 — not-addressed — highlight_structure_spec.lua untouched and still absent from chat/parsing's tests list though the module is in its code list.
- BR-11 — not-addressed — fence.lua:108 signature unchanged; the guard at :145 is still `if is_structural and ...`.
- BR-12 — addressed — Verified by revert (grep and ack single-file cases both go red without -H) and end-to-end (serialized grep-on-a-single-file block parses to 2 exchanges, matching base); 343-file base-vs-HEAD sweep diffs empty.

### Raised

- **BR-13** [Important] `docblock-hygiene` The fence.lua docblock rework deleted M.scan's grammar prose and both @return lines, and duplicated extract_body's block
  This is the 2nd finding in family docblock-hygiene, so the ask is the
  RULE. fence.lua:76-85 carries extract_body's docblock twice verbatim, and
  M.scan's docblock at :102-107 lost the "One linear pass" grammar
  description and both @return entries — the bodies extent model
  (marker_row -> {first,last,close}, first > last for an empty body, close
  nil when none found) is now undocumented, though #200 BR-52 requires
  consumers to branch on exactly that. Two atlas pages designate this
  docstring as the specification and are falsified by the deletion:
  atlas/chat/parsing.md:19 ("see its docstrings for the grammar itself") and
  atlas/providers/tool_use.md:153 ("Its docstrings are the specification —
  this page deliberately does not restate the rule"), which then restates
  the rule twice in its own new section. The rule: fence.lua's docstrings
  are a designated specification surface, not commentary, so a docblock
  rewrite must be diffed against the block it replaces — the Log records
  this edit as a recovered span-edit, which is the exact failure mode that
  silently drops a block. Enumeration for this round: every docblock touched
  in 5c65036..bd1a623 (fence.extract_body, fence.scan,
  highlight_structure.STRUCTURAL_KINDS, highlight_structure.is_structural_kind
  — the last has no @param or @return at all), checked for no duplication, a
  @param per parameter, a @return per return value, and any prose an atlas
  page defers to.
- **BR-14** [Important] `stale-test-premise` A test still asserts by name the premise this issue refuted, and stays green because its assertion cannot see the change
  chat_parser_tools_spec.lua:407 "treats a tool-result marker inside a tool
  body as content" puts a column-0 tool-result marker inside a grep body and
  asserts only that there is 1 exchange. Measured on that exact window:
  base 5c65036 gives bodies[1] = {first=3,last=4,close=5} (the marker IS body
  content), HEAD gives bodies[1] = nil (the body is refused and the marker is
  skipped by depth). Both yield 1 exchange, so the assertion cannot
  distinguish, and the test now reads as coverage for the opposite of what
  the code does. Plan step 7 enumerated "the tests that went red" rather than
  "the tests that encode the premise", which is why this one was never swept.
  Consequence beyond the stale name: nothing anywhere pins the tool-marker
  members of STRUCTURAL_KINDS — fence_spec, the new chat_parser fork case and
  fold_projection_spec all use a user-marker predicate, so tool_use,
  tool_result, summary, branch and local bounding a body is asserted nowhere,
  in the issue that single-sourced that set. Fix: give this case the "%5d  "
  prefix its siblings got, and add a case pinning a column-0 tool-result
  marker refusing the body, asserted on fence.scan's bodies.
- **BR-15** [Minor] `silent-skip-guard` The producer guard silently drops ack coverage on a host without ack, while the atlas claims it fails loudly rather than skipping
  This is the 2nd finding in family silent-skip-guard, so the ask is the
  RULE, not this instance. tool_output_prefix_spec.lua:141-151 returns
  Success after asserting only "is optional" when tools.get returns nil, so
  on a host without ack 2 of 7 cases vanish with nothing reporting it —
  while atlas/providers/tool_use.md:197 states the guard "fails loudly
  rather than skipping when a tool is unregistered". Same file, same shape:
  the marker-named fixture at :47 says "without this the path-echoing tools
  were never exercised", but ls/find were moved to NOT_ECHOING at :116-117,
  so no case reads it. The rule: every coverage-dropping skip must be
  counted and asserted against a NAMED allowlist with a reason — which is
  exactly the mechanism fold_invariants_spec.lua:95-109 now has for its
  corpus. Apply that same shape here (a named OPTIONAL_ABSENT record, and a
  case that fails when a fixture no consumer reads is left behind), and make
  the atlas sentence state the exception instead of overstating it.
- **BR-16** [Minor] `atlas-surface-not-updated` The producer guard's own header still states the absolute claim BR-12 falsified, contradicting its body 100 lines down
  This is the 2nd finding in family atlas-surface-not-updated, so the ask is
  the RULE. tool_output_prefix_spec.lua:3-8 still reads "no tool EMITS one —
  every tool prefixes its output", which BR-12 disproved and which :110-117
  of the same file contradicts. Six of the invariant's seven prose
  restatements (fence.lua, grep.lua, ack.lua, tool_use.md, format.md,
  parsing.md) were updated for BR-12 and this one was not. The rule: the
  producer invariant must be STATED once — in atlas/providers/tool_use.md's
  bounded-claim paragraph — and every other site must point at it rather
  than restate it, because a restatement is a deferred consumer that drifts
  silently (ARCH-DRY). Enumeration: grep the tree for "prefixes its output",
  "column-0 marker" and "-H" and reduce each hit to a pointer.
- **BR-17** [Minor] `closure-captures-lazy-upvalue` fold_projection's new is_structural closure reads an upvalue initialized only as a side effect of another closure
  fold_projection.lua:140 calls highlight_structure.is_structural_kind on the
  local declared at :94, which is assigned only inside the `not patterns`
  branch or as a side effect of the DEFAULT classify closure at :98-101. With
  M._classify injected — the seam that line exists for — the first tool_use /
  tool_result range indexes a nil value and verify_anchors crashes. Nothing
  sets M._classify today so it is unreachable, but the diff introduced the
  coupling. One unconditional assignment of highlight_structure before the
  loop removes it.

## Open findings

- **BR-7** [Minor] `redundant-per-line-work-in-scan` fold_projection's is_structural predicate does a per-line require plus a second full classify in a function documented as per-streamed-chunk hot
- **BR-9** [Minor] `experiment-artifact-committed-unpruned` workshop/plans/203-experiment.patch is 1760 lines, ~1690 of which are a corpus transcript it would delete on apply
- **BR-10** [Minor] `single-source-untested-directly` STRUCTURAL_KINDS and is_structural_kind have no direct unit test despite deciding the rule
- **BR-11** [Minor] `optional-param-documented-as-required` fence.scan's is_structural is documented "Required in practice" but is optional in the signature
- **BR-13** [Important] `docblock-hygiene` The fence.lua docblock rework deleted M.scan's grammar prose and both @return lines, and duplicated extract_body's block
- **BR-14** [Important] `stale-test-premise` A test still asserts by name the premise this issue refuted, and stays green because its assertion cannot see the change
- **BR-15** [Minor] `silent-skip-guard` The producer guard silently drops ack coverage on a host without ack, while the atlas claims it fails loudly rather than skipping
- **BR-16** [Minor] `atlas-surface-not-updated` The producer guard's own header still states the absolute claim BR-12 falsified, contradicting its body 100 lines down
- **BR-17** [Minor] `closure-captures-lazy-upvalue` fold_projection's new is_structural closure reads an upvalue initialized only as a side effect of another closure
