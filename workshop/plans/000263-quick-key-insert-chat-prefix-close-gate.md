---
gate: boundary-review
issue: 263
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-16T21:18:37-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: The "one undo step" Done-when clause is asserted only for the normal-mode press
          detail: |-
            tests/integration/new_question_spec.lua:162 undoes after a NORMAL-mode press, where the
            insert-path stopinsert (lua/parley/init.lua:2809) plays no part; the insert-mode case at
            :150 never undoes. Measured counterfactual: an insert mapping without stopinsert, driven
            by real <M-n> keystrokes after typed text, restores identically on a single u — so the
            mechanism the comment credits has no test that fails without it. Add the undo assertion
            to the insert-mode case (verified passing against the shipped mapping) and soften the
            comment to cite the existing branch_ref idiom at init.lua:2599.
          family: acceptance-clause-untested
          round: 1
        - id: BR-2
          severity: Important
          title: atlas claims the new entry is "the one place" the portable key does not lead; it is the third
          detail: |-
            atlas/ui/keybindings.md:136-139. Three registry entries lead with <C-g> over an <M-> twin:
            outline (keybinding_registry.lua:531), chat_drill_in (:741) and new_question (:664); only
            open_file (:428) and branch_ref (:545) lead with the alt key. The same paragraph names
            outline as "the same shape" two lines after claiming uniqueness. lua/parley/config.lua:376
            carries the same phrasing scoped to the entry.
          family: doc-claim-contradicts-code
          round: 1
        - id: BR-3
          severity: Minor
          title: NewQuestion is the fourth verbatim copy of the not_chat/find_header_end/parse_chat preamble
          detail: |-
            lua/parley/init.lua:4606-4623 repeats :4276 (Prune), :4443 (ExchangeCut) and :4575
            (ExchangePaste). ARCH-DRY: extract a chat_context(name) helper returning
            buf, lines, header_end, parsed_chat or a reason string.
          family: duplicated-command-preamble
          round: 1
        - id: BR-4
          severity: Minor
          title: NewQuestion catches the buffer_edit refusal and warns; the other 12 call sites let it raise
          detail: |-
            lua/parley/init.lua:4629-4636 pcalls replace_user_lines; :4595 (ExchangePaste),
            :4557 (delete_entity_range) and the rest surface a bare Lua error instead. The new
            behavior is the better one; the siblings now diverge from it.
          family: inconsistent-refusal-ux
          round: 1
        - id: BR-5
          severity: Minor
          title: The streaming-refusal test stubs capture_user's verdict rather than building real guarded state
          detail: |-
            tests/integration/new_question_spec.lua:239 replaces buffer_edit.capture_user with a
            function returning nil. The plan's Task 4 case 9 prescribed driving document.capture_user
            per document_user_guards_spec. What ships proves the catch-and-report path, not that a
            live generation produces the refusal. No Revisions entry records the substitution.
          family: stubbed-verdict-not-seam
          round: 1
        - id: BR-6
          severity: Minor
          title: The plan's literal --verified string states counts and a suite status that are not true
          detail: |-
            workshop/plans/000263-new-question-chord-plan.md:989 says "unit 15/15 + integration 10/10
            green; make test full suite green". Measured: unit 14/14, integration 11/11, and
            tests/unit/parley_harness_golden_spec.lua fails (pre-existing golden drift, acknowledged
            in the issue Log). Correct before sdlc close.
          family: stale-close-evidence
          round: 1
        - id: BR-7
          severity: Minor
          title: The inserted atlas paragraph swallowed a pre-existing sentence
          detail: |-
            atlas/ui/keybindings.md:140-141 — "`<C-g>` is the prefix surface for everything else."
            now trails the #263 exception paragraph instead of the alt-family paragraph it belongs to.
          family: prose-continuity
          round: 1
        - id: BR-8
          severity: Minor
          title: Header-cursor placement is neither tested nor documented
          detail: |-
            With the cursor in the front matter the new question lands above the first exchange
            (verified by hand). That is correct <C-g>V parity, but atlas/chat/lifecycle.md:6 says only
            "after the exchange at the cursor". One clause plus one test case would close it.
          family: undocumented-branch
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#263 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-16T21:18:37-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `acceptance-clause-untested` The "one undo step" Done-when clause is asserted only for the normal-mode press
  tests/integration/new_question_spec.lua:162 undoes after a NORMAL-mode press, where the
  insert-path stopinsert (lua/parley/init.lua:2809) plays no part; the insert-mode case at
  :150 never undoes. Measured counterfactual: an insert mapping without stopinsert, driven
  by real <M-n> keystrokes after typed text, restores identically on a single u — so the
  mechanism the comment credits has no test that fails without it. Add the undo assertion
  to the insert-mode case (verified passing against the shipped mapping) and soften the
  comment to cite the existing branch_ref idiom at init.lua:2599.
- **BR-2** [Important] `doc-claim-contradicts-code` atlas claims the new entry is "the one place" the portable key does not lead; it is the third
  atlas/ui/keybindings.md:136-139. Three registry entries lead with <C-g> over an <M-> twin:
  outline (keybinding_registry.lua:531), chat_drill_in (:741) and new_question (:664); only
  open_file (:428) and branch_ref (:545) lead with the alt key. The same paragraph names
  outline as "the same shape" two lines after claiming uniqueness. lua/parley/config.lua:376
  carries the same phrasing scoped to the entry.
- **BR-3** [Minor] `duplicated-command-preamble` NewQuestion is the fourth verbatim copy of the not_chat/find_header_end/parse_chat preamble
  lua/parley/init.lua:4606-4623 repeats :4276 (Prune), :4443 (ExchangeCut) and :4575
  (ExchangePaste). ARCH-DRY: extract a chat_context(name) helper returning
  buf, lines, header_end, parsed_chat or a reason string.
- **BR-4** [Minor] `inconsistent-refusal-ux` NewQuestion catches the buffer_edit refusal and warns; the other 12 call sites let it raise
  lua/parley/init.lua:4629-4636 pcalls replace_user_lines; :4595 (ExchangePaste),
  :4557 (delete_entity_range) and the rest surface a bare Lua error instead. The new
  behavior is the better one; the siblings now diverge from it.
- **BR-5** [Minor] `stubbed-verdict-not-seam` The streaming-refusal test stubs capture_user's verdict rather than building real guarded state
  tests/integration/new_question_spec.lua:239 replaces buffer_edit.capture_user with a
  function returning nil. The plan's Task 4 case 9 prescribed driving document.capture_user
  per document_user_guards_spec. What ships proves the catch-and-report path, not that a
  live generation produces the refusal. No Revisions entry records the substitution.
- **BR-6** [Minor] `stale-close-evidence` The plan's literal --verified string states counts and a suite status that are not true
  workshop/plans/000263-new-question-chord-plan.md:989 says "unit 15/15 + integration 10/10
  green; make test full suite green". Measured: unit 14/14, integration 11/11, and
  tests/unit/parley_harness_golden_spec.lua fails (pre-existing golden drift, acknowledged
  in the issue Log). Correct before sdlc close.
- **BR-7** [Minor] `prose-continuity` The inserted atlas paragraph swallowed a pre-existing sentence
  atlas/ui/keybindings.md:140-141 — "`<C-g>` is the prefix surface for everything else."
  now trails the #263 exception paragraph instead of the alt-family paragraph it belongs to.
- **BR-8** [Minor] `undocumented-branch` Header-cursor placement is neither tested nor documented
  With the cursor in the front matter the new question lands above the first exchange
  (verified by hand). That is correct <C-g>V parity, but atlas/chat/lifecycle.md:6 says only
  "after the exchange at the cursor". One clause plus one test case would close it.

## Open findings

- **BR-1** [Important] `acceptance-clause-untested` The "one undo step" Done-when clause is asserted only for the normal-mode press
- **BR-2** [Important] `doc-claim-contradicts-code` atlas claims the new entry is "the one place" the portable key does not lead; it is the third
- **BR-3** [Minor] `duplicated-command-preamble` NewQuestion is the fourth verbatim copy of the not_chat/find_header_end/parse_chat preamble
- **BR-4** [Minor] `inconsistent-refusal-ux` NewQuestion catches the buffer_edit refusal and warns; the other 12 call sites let it raise
- **BR-5** [Minor] `stubbed-verdict-not-seam` The streaming-refusal test stubs capture_user's verdict rather than building real guarded state
- **BR-6** [Minor] `stale-close-evidence` The plan's literal --verified string states counts and a suite status that are not true
- **BR-7** [Minor] `prose-continuity` The inserted atlas paragraph swallowed a pre-existing sentence
- **BR-8** [Minor] `undocumented-branch` Header-cursor placement is neither tested nor documented
