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
    - "n": 2
      timestamp: "2026-09-16T21:38:56-07:00"
      agent: claude
      blocked: true
      protocol_error: no valid findings block
    - "n": 3
      timestamp: "2026-09-16T21:55:37-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Integration spec is parameterized over {"n","i"} (both undo cases pass, 15/15 measured), plus a real nvim_feedkeys insert session; init.lua:2805 comment no longer credits stopinsert and cites branch_ref's i handler, which exists at init.lua:2598.
          round: 3
        - id: BR-2
          disposition: addressed
          note: 'Verified against config.lua/registry: <C-g>-leading = outline, chat_drill_in, new_question; alt-leading = open_file, branch_ref, chat_prune. The 3-3 claim is now true in atlas, config.lua and the registry comment.'
          round: 3
        - id: BR-3
          disposition: addressed
          note: chat_context(what) at init.lua:4278; ChatPrune, ExchangeCut, ExchangePaste and NewQuestion all consume it including ctx.cursor_line (grep-verified, no nvim_win_get_cursor left in the four).
          round: 3
        - id: BR-4
          disposition: addressed
          note: 'Accepted-and-tracked rather than changed: divergence remains in-tree by explicit decision, filed as parley.nvim#265 (issue file exists) with the real-generation fixture the proper test needs.'
          round: 3
        - id: BR-5
          disposition: addressed
          note: Test is relabelled as a double at tests/integration/new_question_spec.lua:282-296 with the measured reasons both realer routes fail, and the plan's Revisions records the substitution.
          round: 3
        - id: BR-6
          disposition: not-addressed
          note: Corrected to "integration 14/14" but round 2 added a 15th case; measured 15/15. It also still omits the tests/arch/superseded_comment_spec.lua failure this diff introduces, and the issue Log's "everything else in make test-unit / make test-integration passes" is false for the same reason.
          round: 3
        - id: BR-7
          disposition: addressed
          note: '"`<C-g>` is the prefix surface for everything else." is back with the alt-family paragraph at atlas/ui/keybindings.md:135-136. The same rule recurs in code — raised separately below, not re-raised here.'
          round: 3
        - id: BR-8
          disposition: addressed
          note: Integration case "opens above the first exchange when the cursor is in the header" passes, and atlas/chat/lifecycle.md:21-24 names it as get_paste_line's header fallback.
          round: 3
      findings:
        - id: BR-9
          severity: Critical
          title: The exchange_index_at insertion orphaned get_paste_line's doc block, turning tests/arch/superseded_comment_spec.lua red
          detail: 'lua/parley/exchange_clipboard.lua:58 — get_paste_line''s @param/@return block now sits above M.exchange_index_at (:76) and get_paste_line (:86) has no doc at all. Measured: the arch spec passes 9/9 at base bbe05eef and fails 8/9 at head 62c7f292, reporting "@param header_end, but the signature is (parsed_chat, cursor_line, total_lines)". This is the 2nd finding in family prose-continuity (BR-7 was the atlas instance). Do not just move this block — state the rule (an insertion never lands between a doc block and the symbol it documents; the added definition carries the displaced block with it) and note that the code half is already mechanically enforced by superseded_comment_spec while the markdown half has no enforcer.'
          family: prose-continuity
          round: 3
        - id: BR-10
          severity: Important
          title: chat_context is listed under the plan's "Pure entities" table but reads the current buffer, window and logger
          detail: 'workshop/plans/000263-new-question-chord-plan.md:26 places chat_context in "### Pure entities (the conceptual core)". lua/parley/init.lua:4278-4310 calls nvim_get_current_buf, nvim_buf_get_name, nvim_buf_get_lines, nvim_win_get_cursor and M.logger.warning/error — it cannot run without a real buffer, window and logger. It belongs in the "Integration points" table with M.cmd.NewQuestion. No test was written against the wrong classification, which is why this is Important rather than Critical; fix the row plus a ## Revisions entry.'
          family: pure-classification-drift
          round: 3
        - id: BR-11
          severity: Minor
          title: chat_respond.M.respond and M.respond_all still carry the preamble verbatim, outside chat_context's reach
          detail: '3rd finding in family duplicated-command-preamble. lua/parley/chat_respond.lua:1717-1735 (M.respond) and :1918-1930 (M.respond_all) repeat not_chat -> warning, find_chat_header_end -> error, parse_chat (+ cursor in respond_all). chat_context is file-local to init.lua so they cannot consume it. Measured prevalence: 4 migrated in init.lua, 2 unmigrated in chat_respond.lua, 1 partial in exporter.lua:965, 1 deliberate divergence in delete_entity_range (init.lua:4547, entity_textobj parity — correctly excluded). Do not fix these two sites; decide the rule — one owner in a shared module, or a written-down boundary explaining why init.lua''s helper stops at init.lua.'
          family: duplicated-command-preamble
          round: 3
        - id: BR-12
          severity: Minor
          title: The corrected 3-3 lead split is still a hand-maintained restatement of the registry with no enforcing test
          detail: 2nd finding in family doc-claim-contradicts-code. atlas/ui/keybindings.md:136-145 (and the same phrasing in config.lua:372-383 and keybinding_registry.lua:657-663) asserts a count I verified as currently true, but nothing derives it — grep of keybindings_spec.lua and keybinding_agreement_spec.lua finds no case pinning it. The rule adopted after BR-2 was manual ("run a script before it ships"); the family's history is that manual discipline is what failed. The class fix is one spec case deriving the lead split from the registry so a seventh pair fails the suite instead of drifting the page.
          family: doc-claim-contradicts-code
          round: 3
      blocked: true
    - "n": 4
      timestamp: "2026-09-16T22:22:40-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: not-addressed
          note: 'Round 1 corrected 15/15->14/14; rounds 2-3 then drifted it again. plan:1005 says "integration 14/14 ... 627 files"; measured at head: integration 15/15, lint 628 files, keybindings 80/80. 2nd in family stale-close-evidence, so the fix is the class: the plan should not carry a literal count at all (lessons.md:158-164 already says build --verified from the closing run) -- delete the literal, keep the rule.'
          round: 4
        - id: BR-9
          disposition: addressed
          note: 'Verified: exchange_index_at carries its own complete @param/@return block placed before get_paste_line''s; tests/arch/superseded_comment_spec.lua runs 9/9 at head (was 8/9 at 62c7f292). Rule written at lessons.md:6-12. Gap noted only: the lesson states the verification rule ("run the arch suite after any edit that relocates code") but not the structural rule the finding asked for, and does not record that the markdown half of prose-continuity has no enforcer.'
          round: 4
        - id: BR-10
          disposition: addressed
          note: chat_buffer/parse/resolve moved to the "Integration points" table (plan:74-80) with chat_context.lua listed and each function's boundary named; the Pure-entities bullet at plan:63 records the correction inline and the round-3 Revisions entry names BR-10.
          round: 4
        - id: BR-11
          disposition: addressed
          note: 'Rule chosen and applied: one owner in a shared module (lua/parley/chat_context.lua), two-phase because respond_all interleaves its batch precondition. Both chat_respond sites migrated with wording and message ordering preserved verbatim (diffed against base); chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10. Swept tree-wide: exactly one file now contains the not_chat/find_header_end/parse_chat co-occurrence. See new finding on enforcement.'
          round: 4
        - id: BR-12
          disposition: addressed
          note: keybindings_spec.lua:1055-1092 derives the split from the registry and pins both sides, plus a case that flips one entry's key order to prove the derivation reads keys[1] rather than membership; keybindings 80/80. keybinding_registry.lua:1264 confirms help renders keys[1].
          round: 4
      findings:
        - id: BR-13
          severity: Important
          title: The rule that ends this family is prose in a module header; nothing stops a fifth copy
          detail: '4th finding in this family. The sweep is genuinely complete -- I measured it, exactly one file in lua/ contains not_chat( with find_header_end(/parse_chat( within 25 lines. But "it is written out nowhere else" (chat_context.lua:22-24, plan:1245) is a sentence, and the same round rejected manual discipline as a remedy for doc-claim-contradicts-code. Do not fix another instance: add one case to tests/arch/single_source_sweeps_spec.lua asserting the match set is exactly {lua/parley/chat_context.lua}, with exporter.lua (partial) and delete_entity_range (entity_textobj.parsed_for) as the recorded exclusions. I confirmed such a sweep lands green today. ARCH-DRY, ARCH-PURPOSE.'
          family: duplicated-command-preamble
          round: 4
        - id: BR-14
          severity: Important
          title: lua/parley/chat_context.lua has no atlas entry and no traceability row
          detail: The same diff routed lua/parley/new_question.lua into atlas/traceability.yaml under both chat/lifecycle and ui/keybindings and documented it in atlas/chat/lifecycle.md. chat_context.lua -- now depended on by four init.lua commands and two chat_respond.lua entry points, with a stated two-phase contract and a new repo-wide convention -- appears in no atlas file and no traceability list (grep -rln chat_context atlas/ tests/ is empty). AGENTS.md section 8. The existing sweep only enforces routing for added specs, so nothing caught it.
          family: new-surface-not-in-atlas
          round: 4
        - id: BR-15
          severity: Important
          title: No test enters any error branch of the six migrated call sites, and the invariant justifying the two-phase split is unasserted
          detail: '2nd finding in this family. grep for "does not look like a chat file", "chat header unavailable", "Batch not started", "could not find header separator" across tests/ returns nothing -- yet those branches are exactly what round 3 rewrote. chat_context.lua:11-16 states a specific guarantee (a header-less chat with an active batch must report the batch, not the header) that no fixture enters. Do not add the one missing case: the rule is that a clause stated as a guarantee gets an assertion or gets deleted, and this round''s enumeration is (a) that ordering invariant, (b) not_chat and no_header for each of the six callers, (c) resolve''s `kind` discriminator, which is the only thing keeping init.lua''s chat_context(what) from logging a warning where it should log an error. A tests/unit/chat_context_spec.lua covers (a) and (c) directly.'
          family: acceptance-clause-untested
          round: 4
        - id: BR-16
          severity: Minor
          title: Two absolute claims introduced by this diff after the lesson that bans unchecked absolutes
          detail: '3rd finding in this family. State the rule, do not patch the sentence: an absolute claim is a grep-checkable assertion and must be scoped or enforced (lessons.md:112-119, written in this same diff). Enumeration: (a) exchange_clipboard.lua:61 "The single owner of ''which exchange is the cursor in''" -- parley.find_exchange_at_line (init.lua:4125) and chat_parser.find_exchange_at_line (chat_parser.lua:277) both answer it with different boundary conventions and are consumed by ChatPrune, ExchangeCut, chat_respond.respond and entity_range; the claim is true only within exchange_clipboard. (b) plan:71 still states that stopinsert keeps the write out of the surrounding insert session''s undo block -- the mechanism the same document retracts at :1117-1122 on measured evidence and that init.lua:2806-2812 no longer claims.'
          family: doc-claim-contradicts-code
          round: 4
        - id: BR-17
          severity: Minor
          title: chat_context.parse reads the cursor from handle.win without checking it displays handle.buf
          detail: lua/parley/chat_context.lua:44-56 pairs lines from handle.buf with nvim_win_get_cursor(handle.win). Every caller today passes the current buffer/window pair so it is unreachable, but this is now the shared entry point for six call sites and the next caller may pass a buf without its window.
          family: shared-entrypoint-unchecked-pairing
          round: 4
      blocked: false
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

## Round 2 — 2026-09-16T21:38:56-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 3 — 2026-09-16T21:55:37-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — Integration spec is parameterized over {"n","i"} (both undo cases pass, 15/15 measured), plus a real nvim_feedkeys insert session; init.lua:2805 comment no longer credits stopinsert and cites branch_ref's i handler, which exists at init.lua:2598.
- BR-2 — addressed — Verified against config.lua/registry: <C-g>-leading = outline, chat_drill_in, new_question; alt-leading = open_file, branch_ref, chat_prune. The 3-3 claim is now true in atlas, config.lua and the registry comment.
- BR-3 — addressed — chat_context(what) at init.lua:4278; ChatPrune, ExchangeCut, ExchangePaste and NewQuestion all consume it including ctx.cursor_line (grep-verified, no nvim_win_get_cursor left in the four).
- BR-4 — addressed — Accepted-and-tracked rather than changed: divergence remains in-tree by explicit decision, filed as parley.nvim#265 (issue file exists) with the real-generation fixture the proper test needs.
- BR-5 — addressed — Test is relabelled as a double at tests/integration/new_question_spec.lua:282-296 with the measured reasons both realer routes fail, and the plan's Revisions records the substitution.
- BR-6 — not-addressed — Corrected to "integration 14/14" but round 2 added a 15th case; measured 15/15. It also still omits the tests/arch/superseded_comment_spec.lua failure this diff introduces, and the issue Log's "everything else in make test-unit / make test-integration passes" is false for the same reason.
- BR-7 — addressed — "`<C-g>` is the prefix surface for everything else." is back with the alt-family paragraph at atlas/ui/keybindings.md:135-136. The same rule recurs in code — raised separately below, not re-raised here.
- BR-8 — addressed — Integration case "opens above the first exchange when the cursor is in the header" passes, and atlas/chat/lifecycle.md:21-24 names it as get_paste_line's header fallback.

### Raised

- **BR-9** [Critical] `prose-continuity` The exchange_index_at insertion orphaned get_paste_line's doc block, turning tests/arch/superseded_comment_spec.lua red
  lua/parley/exchange_clipboard.lua:58 — get_paste_line's @param/@return block now sits above M.exchange_index_at (:76) and get_paste_line (:86) has no doc at all. Measured: the arch spec passes 9/9 at base bbe05eef and fails 8/9 at head 62c7f292, reporting "@param header_end, but the signature is (parsed_chat, cursor_line, total_lines)". This is the 2nd finding in family prose-continuity (BR-7 was the atlas instance). Do not just move this block — state the rule (an insertion never lands between a doc block and the symbol it documents; the added definition carries the displaced block with it) and note that the code half is already mechanically enforced by superseded_comment_spec while the markdown half has no enforcer.
- **BR-10** [Important] `pure-classification-drift` chat_context is listed under the plan's "Pure entities" table but reads the current buffer, window and logger
  workshop/plans/000263-new-question-chord-plan.md:26 places chat_context in "### Pure entities (the conceptual core)". lua/parley/init.lua:4278-4310 calls nvim_get_current_buf, nvim_buf_get_name, nvim_buf_get_lines, nvim_win_get_cursor and M.logger.warning/error — it cannot run without a real buffer, window and logger. It belongs in the "Integration points" table with M.cmd.NewQuestion. No test was written against the wrong classification, which is why this is Important rather than Critical; fix the row plus a ## Revisions entry.
- **BR-11** [Minor] `duplicated-command-preamble` chat_respond.M.respond and M.respond_all still carry the preamble verbatim, outside chat_context's reach
  3rd finding in family duplicated-command-preamble. lua/parley/chat_respond.lua:1717-1735 (M.respond) and :1918-1930 (M.respond_all) repeat not_chat -> warning, find_chat_header_end -> error, parse_chat (+ cursor in respond_all). chat_context is file-local to init.lua so they cannot consume it. Measured prevalence: 4 migrated in init.lua, 2 unmigrated in chat_respond.lua, 1 partial in exporter.lua:965, 1 deliberate divergence in delete_entity_range (init.lua:4547, entity_textobj parity — correctly excluded). Do not fix these two sites; decide the rule — one owner in a shared module, or a written-down boundary explaining why init.lua's helper stops at init.lua.
- **BR-12** [Minor] `doc-claim-contradicts-code` The corrected 3-3 lead split is still a hand-maintained restatement of the registry with no enforcing test
  2nd finding in family doc-claim-contradicts-code. atlas/ui/keybindings.md:136-145 (and the same phrasing in config.lua:372-383 and keybinding_registry.lua:657-663) asserts a count I verified as currently true, but nothing derives it — grep of keybindings_spec.lua and keybinding_agreement_spec.lua finds no case pinning it. The rule adopted after BR-2 was manual ("run a script before it ships"); the family's history is that manual discipline is what failed. The class fix is one spec case deriving the lead split from the registry so a seventh pair fails the suite instead of drifting the page.

## Round 4 — 2026-09-16T22:22:40-07:00 (claude) — passed

### Disposed

- BR-6 — not-addressed — Round 1 corrected 15/15->14/14; rounds 2-3 then drifted it again. plan:1005 says "integration 14/14 ... 627 files"; measured at head: integration 15/15, lint 628 files, keybindings 80/80. 2nd in family stale-close-evidence, so the fix is the class: the plan should not carry a literal count at all (lessons.md:158-164 already says build --verified from the closing run) -- delete the literal, keep the rule.
- BR-9 — addressed — Verified: exchange_index_at carries its own complete @param/@return block placed before get_paste_line's; tests/arch/superseded_comment_spec.lua runs 9/9 at head (was 8/9 at 62c7f292). Rule written at lessons.md:6-12. Gap noted only: the lesson states the verification rule ("run the arch suite after any edit that relocates code") but not the structural rule the finding asked for, and does not record that the markdown half of prose-continuity has no enforcer.
- BR-10 — addressed — chat_buffer/parse/resolve moved to the "Integration points" table (plan:74-80) with chat_context.lua listed and each function's boundary named; the Pure-entities bullet at plan:63 records the correction inline and the round-3 Revisions entry names BR-10.
- BR-11 — addressed — Rule chosen and applied: one owner in a shared module (lua/parley/chat_context.lua), two-phase because respond_all interleaves its batch precondition. Both chat_respond sites migrated with wording and message ordering preserved verbatim (diffed against base); chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10. Swept tree-wide: exactly one file now contains the not_chat/find_header_end/parse_chat co-occurrence. See new finding on enforcement.
- BR-12 — addressed — keybindings_spec.lua:1055-1092 derives the split from the registry and pins both sides, plus a case that flips one entry's key order to prove the derivation reads keys[1] rather than membership; keybindings 80/80. keybinding_registry.lua:1264 confirms help renders keys[1].

### Raised

- **BR-13** [Important] `duplicated-command-preamble` The rule that ends this family is prose in a module header; nothing stops a fifth copy
  4th finding in this family. The sweep is genuinely complete -- I measured it, exactly one file in lua/ contains not_chat( with find_header_end(/parse_chat( within 25 lines. But "it is written out nowhere else" (chat_context.lua:22-24, plan:1245) is a sentence, and the same round rejected manual discipline as a remedy for doc-claim-contradicts-code. Do not fix another instance: add one case to tests/arch/single_source_sweeps_spec.lua asserting the match set is exactly {lua/parley/chat_context.lua}, with exporter.lua (partial) and delete_entity_range (entity_textobj.parsed_for) as the recorded exclusions. I confirmed such a sweep lands green today. ARCH-DRY, ARCH-PURPOSE.
- **BR-14** [Important] `new-surface-not-in-atlas` lua/parley/chat_context.lua has no atlas entry and no traceability row
  The same diff routed lua/parley/new_question.lua into atlas/traceability.yaml under both chat/lifecycle and ui/keybindings and documented it in atlas/chat/lifecycle.md. chat_context.lua -- now depended on by four init.lua commands and two chat_respond.lua entry points, with a stated two-phase contract and a new repo-wide convention -- appears in no atlas file and no traceability list (grep -rln chat_context atlas/ tests/ is empty). AGENTS.md section 8. The existing sweep only enforces routing for added specs, so nothing caught it.
- **BR-15** [Important] `acceptance-clause-untested` No test enters any error branch of the six migrated call sites, and the invariant justifying the two-phase split is unasserted
  2nd finding in this family. grep for "does not look like a chat file", "chat header unavailable", "Batch not started", "could not find header separator" across tests/ returns nothing -- yet those branches are exactly what round 3 rewrote. chat_context.lua:11-16 states a specific guarantee (a header-less chat with an active batch must report the batch, not the header) that no fixture enters. Do not add the one missing case: the rule is that a clause stated as a guarantee gets an assertion or gets deleted, and this round's enumeration is (a) that ordering invariant, (b) not_chat and no_header for each of the six callers, (c) resolve's `kind` discriminator, which is the only thing keeping init.lua's chat_context(what) from logging a warning where it should log an error. A tests/unit/chat_context_spec.lua covers (a) and (c) directly.
- **BR-16** [Minor] `doc-claim-contradicts-code` Two absolute claims introduced by this diff after the lesson that bans unchecked absolutes
  3rd finding in this family. State the rule, do not patch the sentence: an absolute claim is a grep-checkable assertion and must be scoped or enforced (lessons.md:112-119, written in this same diff). Enumeration: (a) exchange_clipboard.lua:61 "The single owner of 'which exchange is the cursor in'" -- parley.find_exchange_at_line (init.lua:4125) and chat_parser.find_exchange_at_line (chat_parser.lua:277) both answer it with different boundary conventions and are consumed by ChatPrune, ExchangeCut, chat_respond.respond and entity_range; the claim is true only within exchange_clipboard. (b) plan:71 still states that stopinsert keeps the write out of the surrounding insert session's undo block -- the mechanism the same document retracts at :1117-1122 on measured evidence and that init.lua:2806-2812 no longer claims.
- **BR-17** [Minor] `shared-entrypoint-unchecked-pairing` chat_context.parse reads the cursor from handle.win without checking it displays handle.buf
  lua/parley/chat_context.lua:44-56 pairs lines from handle.buf with nvim_win_get_cursor(handle.win). Every caller today passes the current buffer/window pair so it is unreachable, but this is now the shared entry point for six call sites and the next caller may pass a buf without its window.

## Open findings

- **BR-6** [Minor] `stale-close-evidence` The plan's literal --verified string states counts and a suite status that are not true
- **BR-13** [Important] `duplicated-command-preamble` The rule that ends this family is prose in a module header; nothing stops a fifth copy
- **BR-14** [Important] `new-surface-not-in-atlas` lua/parley/chat_context.lua has no atlas entry and no traceability row
- **BR-15** [Important] `acceptance-clause-untested` No test enters any error branch of the six migrated call sites, and the invariant justifying the two-phase split is unasserted
- **BR-16** [Minor] `doc-claim-contradicts-code` Two absolute claims introduced by this diff after the lesson that bans unchecked absolutes
- **BR-17** [Minor] `shared-entrypoint-unchecked-pairing` chat_context.parse reads the cursor from handle.win without checking it displays handle.buf
