---
gate: boundary-review
issue: 225
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-08T19:16:06-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
          detail: |-
            3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
            ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
            (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
            edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
            which markdown already reaches. Keeping it behind is_chat carries the duplication through
            the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
            (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
            (carried from plan-quality PQ-9, deferred to the boundary review)
          family: unbacked-existing-behavior-claim
          round: 1
        - id: BR-2
          severity: Minor
          title: The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
          detail: |-
            2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
            a grep of the literal and dispositions every hit, including each test asserting the old
            value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
            7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
            default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
            :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
            collision guard and CI both catch these loudly.
            (carried from plan-quality PQ-10, deferred to the boundary review)
          family: doc-consumer-enumeration
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-08T19:16:06-07:00"
      agent: claude
      findings:
        - id: BR-3
          severity: Important
          title: The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
          detail: |-
            artifact_ref.lua:208 calls M.run_resolve with three arguments, so the documented
            runner(argv, on_complete) seam is dead on the production path. open_reference_spec.lua:338
            therefore replaces artifact_ref.run_resolve itself, which means the test flow and the
            production flow do not share a boundary (ARCH-MOCK). Thread opts.runner through
            goto_ref_at_cursor and let the spec inject a fake returning canned `sdlc resolve --json`
            stdout; the same change retires the identical stub at artifact_ref_spec.lua:249-252.
          family: external-seam-not-shared
          round: 2
        - id: BR-4
          severity: Important
          title: vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
          detail: |-
            Verified end-to-end through the real command: a chat line @@`touch <path> && echo /nope`@@
            with the cursor on it creates the file when <M-o> is pressed. ref_path comes from buffer
            content whose provenance is model output. Pre-existing (both deleted chains expanded the
            same value), but this diff makes it single-sited. Class enumeration: init.lua:4382 and
            init.lua:4396 (both derive from ref_path, so one guard after extraction covers both), plus
            the sibling consumer helper.find_files:313 reached via chat_respond.lua:847. Reject or
            escape a backtick in ref_path and degrade to "none"/warn rather than expanding.
          family: untrusted-path-expansion
          round: 2
        - id: BR-5
          severity: Important
          title: The is_chat directory divergence has no negative test; flattening it leaves the suite green
          detail: |-
            The Spec names D4 "the one that must NOT be flattened" and the Plan promises
            characterisation tests for all four arms. Mutating init.lua:4387 to `if true and (...)`
            -- flattening exactly that divergence -- leaves all 17 tests in open_reference_spec
            passing. Add the negative half: a directory reference in a MARKDOWN buffer must not issue
            Explore and must take the "failed"/warning exit.
          family: divergence-not-pinned
          round: 2
        - id: BR-6
          severity: Important
          title: focus_other_split swept two of three copies; open_buf still carries its own inline version
          detail: |-
            init.lua:4314 is a verbatim extraction of the block open_buf still holds at 2960-2984.
            The comment explains why a separate CALL SITE is needed (netrw does not go through
            open_buf) but not why the logic must be duplicated. Since ARCH-DRY is the stated
            rationale for the whole extraction, stopping at the two instances the issue named is
            instance-not-class. Move focus_other_split above open_buf and call it there.
          family: two-split-preference-duplicated
          round: 2
        - id: BR-7
          severity: Minor
          title: The glob-to-base-dir derivation duplicates helper.process_directory_pattern
          detail: |-
            init.lua:4395's gsub pair is a near-duplicate of helper.lua:370-379. Moved code rather
            than new, but it is the pure fragment that belongs in one tested helper -- and the
            counterexample to the Core-concepts table's "Pure entities: None".
          family: two-split-preference-duplicated
          round: 2
        - id: BR-8
          severity: Minor
          title: The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
          detail: |-
            single_source_sweeps_spec.lua:192 short-circuits the whole row, so a plan can mark a row
            deleted while the symbol survives. Stronger: for a deleted row, assert no definition
            exists. (open_chat_reference is in fact gone -- I grepped -- but the guard would not know.)
          family: divergence-not-pinned
          round: 2
        - id: BR-9
          severity: Minor
          title: The markdown "is mapped" list gained <M-s> but never <M-o>
          detail: |-
            keybinding_agreement_spec.lua:370 pins <C-g>ve/<M-s>/<M-CR> on a markdown buffer. The
            Done-when's "in both buffer types" is asserted at the command level only; the collision
            this issue fixed lived at the binding level.
          family: binding-level-coverage-gap
          round: 2
        - id: BR-10
          severity: Minor
          title: The <M-o> fall-through spawns sdlc resolve with no in-flight guard
          detail: |-
            init.lua:4475 routes the most-pressed key into an uncancelled subprocess; two presses
            before the first returns start two spawns and can open twice or show two pickers.
            Pre-existing on gf, but the key it now sits behind is pressed far more often
            (ARCH-CONSTRAINTS / ARCH-ORDER extent).
          family: unbounded-inflight-spawn
          round: 2
        - id: BR-11
          severity: Minor
          title: 'Chat''s chain order flipped: inline branch links now precede open_branch_ref'
          detail: "init.lua:4356-4358 adopts markdown's order. Observable only on a \U0001F33F: line that also\ncontains an inline [\U0001F33F:…](file) with the cursor inside it. Intentional, but not recorded\nin the divergence table or the Log."
          family: chain-order-change-unrecorded
          round: 2
        - id: BR-12
          severity: Minor
          title: Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
          detail: |-
            ~1,300 lines on pi history, special relativity and Io's orbital period landed in the
            commit titled "#225: one reference chain, three-valued...". git log --grep "^#225" now
            returns a commit whose diff is mostly unrelated prose (AGENTS.md section 12).
          family: commit-scope-hygiene
          round: 2
      blocked: true
---

# Gate ledger — parley.nvim#225 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-08T19:16:06-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `unbacked-existing-behavior-claim` Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
  3rd in family, so the ask is the RULE: an "X exists only in path A" claim must cite the
  ABSENCE in path B, not the presence in A. Measured prevalence 3. Here the cited range
  (init.lua:4463-4492) backs the directory Explore arm only; the chat chain's split-aware
  edit is at init.lua:4574-4597 and duplicates M.open_buf's logic (init.lua:2963-2984),
  which markdown already reaches. Keeping it behind is_chat carries the duplication through
  the extraction (ARCH-DRY); collapsing it onto open_buf also adds file-tracking
  (init.lua:2945-2946) and existing-window reuse (init.lua:2948-2958) to the chat path.
  (carried from plan-quality PQ-9, deferred to the boundary review)
- **BR-2** [Minor] `doc-consumer-enumeration` The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
  2nd in family, so the RULE: a plan moving a key or identifier derives its update list from
  a grep of the literal and dispositions every hit, including each test asserting the old
  value as "will fail" / "passes for the wrong reason" / "unaffected". Measured: 13 hits in
  7 files, plan names 2 files. keybinding_registry.lua:750 is review_menu's functional
  default_key. keybinding_agreement_spec.lua:370 and :397 keep passing for the wrong reason;
  :407 (journal sidecar asserts is_nil for M-o) fails outright. Kept Minor because step 1's
  collision guard and CI both catch these loudly.
  (carried from plan-quality PQ-10, deferred to the boundary review)

## Round 2 — 2026-09-08T19:16:06-07:00 (claude) — BLOCKED

### Raised

- **BR-3** [Important] `external-seam-not-shared` The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
  artifact_ref.lua:208 calls M.run_resolve with three arguments, so the documented
  runner(argv, on_complete) seam is dead on the production path. open_reference_spec.lua:338
  therefore replaces artifact_ref.run_resolve itself, which means the test flow and the
  production flow do not share a boundary (ARCH-MOCK). Thread opts.runner through
  goto_ref_at_cursor and let the spec inject a fake returning canned `sdlc resolve --json`
  stdout; the same change retires the identical stub at artifact_ref_spec.lua:249-252.
- **BR-4** [Important] `untrusted-path-expansion` vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
  Verified end-to-end through the real command: a chat line @@`touch <path> && echo /nope`@@
  with the cursor on it creates the file when <M-o> is pressed. ref_path comes from buffer
  content whose provenance is model output. Pre-existing (both deleted chains expanded the
  same value), but this diff makes it single-sited. Class enumeration: init.lua:4382 and
  init.lua:4396 (both derive from ref_path, so one guard after extraction covers both), plus
  the sibling consumer helper.find_files:313 reached via chat_respond.lua:847. Reject or
  escape a backtick in ref_path and degrade to "none"/warn rather than expanding.
- **BR-5** [Important] `divergence-not-pinned` The is_chat directory divergence has no negative test; flattening it leaves the suite green
  The Spec names D4 "the one that must NOT be flattened" and the Plan promises
  characterisation tests for all four arms. Mutating init.lua:4387 to `if true and (...)`
  -- flattening exactly that divergence -- leaves all 17 tests in open_reference_spec
  passing. Add the negative half: a directory reference in a MARKDOWN buffer must not issue
  Explore and must take the "failed"/warning exit.
- **BR-6** [Important] `two-split-preference-duplicated` focus_other_split swept two of three copies; open_buf still carries its own inline version
  init.lua:4314 is a verbatim extraction of the block open_buf still holds at 2960-2984.
  The comment explains why a separate CALL SITE is needed (netrw does not go through
  open_buf) but not why the logic must be duplicated. Since ARCH-DRY is the stated
  rationale for the whole extraction, stopping at the two instances the issue named is
  instance-not-class. Move focus_other_split above open_buf and call it there.
- **BR-7** [Minor] `two-split-preference-duplicated` The glob-to-base-dir derivation duplicates helper.process_directory_pattern
  init.lua:4395's gsub pair is a near-duplicate of helper.lua:370-379. Moved code rather
  than new, but it is the pure fragment that belongs in one tested helper -- and the
  counterexample to the Core-concepts table's "Pure entities: None".
- **BR-8** [Minor] `divergence-not-pinned` The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
  single_source_sweeps_spec.lua:192 short-circuits the whole row, so a plan can mark a row
  deleted while the symbol survives. Stronger: for a deleted row, assert no definition
  exists. (open_chat_reference is in fact gone -- I grepped -- but the guard would not know.)
- **BR-9** [Minor] `binding-level-coverage-gap` The markdown "is mapped" list gained <M-s> but never <M-o>
  keybinding_agreement_spec.lua:370 pins <C-g>ve/<M-s>/<M-CR> on a markdown buffer. The
  Done-when's "in both buffer types" is asserted at the command level only; the collision
  this issue fixed lived at the binding level.
- **BR-10** [Minor] `unbounded-inflight-spawn` The <M-o> fall-through spawns sdlc resolve with no in-flight guard
  init.lua:4475 routes the most-pressed key into an uncancelled subprocess; two presses
  before the first returns start two spawns and can open twice or show two pickers.
  Pre-existing on gf, but the key it now sits behind is pressed far more often
  (ARCH-CONSTRAINTS / ARCH-ORDER extent).
- **BR-11** [Minor] `chain-order-change-unrecorded` Chat's chain order flipped: inline branch links now precede open_branch_ref
  init.lua:4356-4358 adopts markdown's order. Observable only on a 🌿: line that also
  contains an inline [🌿:…](file) with the cursor inside it. Intentional, but not recorded
  in the divergence table or the Log.
- **BR-12** [Minor] `commit-scope-hygiene` Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
  ~1,300 lines on pi history, special relativity and Io's orbital period landed in the
  commit titled "#225: one reference chain, three-valued...". git log --grep "^#225" now
  returns a commit whose diff is mostly unrelated prose (AGENTS.md section 12).

## Open findings

- **BR-1** [Minor] `unbacked-existing-behavior-claim` Row 4 bundles "split-aware edit" with the Explore arm, but markdown already has it via open_buf
- **BR-2** [Minor] `doc-consumer-enumeration` The M-o consumer list is recalled, not grep-derived; omits keybinding_registry.lua:750 and three keybinding_agreement_spec assertions
- **BR-3** [Important] `external-seam-not-shared` The resolve arm stubs run_resolve wholesale; the injected-runner seam the Done-when promised is unreachable from goto_ref_at_cursor
- **BR-4** [Important] `untrusted-path-expansion` vim.fn.expand on transcript-derived text executes backticks, reachable from the unified chain
- **BR-5** [Important] `divergence-not-pinned` The is_chat directory divergence has no negative test; flattening it leaves the suite green
- **BR-6** [Important] `two-split-preference-duplicated` focus_other_split swept two of three copies; open_buf still carries its own inline version
- **BR-7** [Minor] `two-split-preference-duplicated` The glob-to-base-dir derivation duplicates helper.process_directory_pattern
- **BR-8** [Minor] `divergence-not-pinned` The sweep now skips `deleted` rows entirely instead of asserting the symbol is gone
- **BR-9** [Minor] `binding-level-coverage-gap` The markdown "is mapped" list gained <M-s> but never <M-o>
- **BR-10** [Minor] `unbounded-inflight-spawn` The <M-o> fall-through spawns sdlc resolve with no in-flight guard
- **BR-11** [Minor] `chain-order-change-unrecorded` Chat's chain order flipped: inline branch links now precede open_branch_ref
- **BR-12** [Minor] `commit-scope-hygiene` Twelve unrelated workshop/parley transcripts were swept into implementation commit bb7050a
