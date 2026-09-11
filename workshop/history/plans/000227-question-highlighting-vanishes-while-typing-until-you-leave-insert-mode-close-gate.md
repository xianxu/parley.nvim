---
gate: boundary-review
issue: 227
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-10T18:05:17-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: highlighting_spec.lua keeps production 250ms timers while the same file pumps the loop
          detail: |-
            Task 4 injects the repair deferral only into the new highlight_typing_spec.lua.
            The structural-edit tests in highlighting_spec.lua (around lines 572, 626, 729,
            745-773, 852) will arm real vim.uv timers, and that file waits on the event loop
            for 700ms at line 1198 (also 1173, 1236) — long enough for a stray repair to
            rebuild a prior test's buffer and fire nvim__redraw mid-test. Install the manual
            deferral in a top-level before_each/after_each there too, or expose the swap from
            tests/helpers/decoration.lua so both specs construct the ordering instead of
            sampling it.
            (carried from plan-quality PQ-1, deferred to the boundary review)
          family: injected-clock-in-tests
          round: 1
        - id: BR-2
          severity: Minor
          title: traceability lists highlighting_spec.lua at two sites, Task 6 names one
          detail: |-
            atlas/traceability.yaml references tests/integration/highlighting_spec.lua at both
            line 52 and line 624 (two different atlas entries). Task 6 Step 4 says to add the
            new spec "beside" it in the singular, so an implementer will likely update one and
            leave the other's coverage list incomplete. Decide which entries own the new spec
            and name both.
            (carried from plan-quality PQ-2, deferred to the boundary review)
          family: class-not-instance
          round: 1
        - id: BR-3
          severity: Minor
          title: two init.lua pointers in the issue's diagnosis are off by 5-7 lines
          detail: |-
            The Problem section cites init.lua:1707 for the chat buffer being
            filetype=markdown (the actual site is the prep_chat block near :1714) and
            init.lua:2865 as the highlight_question_block path (the wrapper is at :2872-2873).
            Both behavioral claims are correct; only the line numbers drifted, and a later
            reader following them lands on ExportMarkdown and on the _parley_bufs declaration.
            (carried from plan-quality PQ-3, deferred to the boundary review)
          family: stale-file-line-pointer
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-10T18:05:17-07:00"
      agent: claude
      findings:
        - id: BR-4
          severity: Important
          title: on_lines discards replace's work, so the splice's O(n) copy is invisible to every gate
          detail: |-
            lua/parley/highlighter.lua:1008 captures only (out, rows, reason) from the pcall and
            drops work, so entries_copied never reaches record_work at :1021, which sends only
            structure_rows_processed = #new_lines. The #170 hard gate (tests/perf/chat_typing.lua:116)
            asserts that value is 1 and therefore certifies a path whose real cost it cannot see;
            make perf's new structure_splice phase is report-only. Swap the shallow two-array copy
            in M.replace for vim.deepcopy and every test stays green while an Enter at 5,000 lines
            silently costs tens of ms. Fix: pass structure_entries_copied through record_work, add
            it to WORK_KEYS, and bound it in assert_hard_gates.
          family: work-accounting-blind-spot
          round: 2
        - id: BR-5
          severity: Minor
          title: nvim__redraw is a private API called unprotected inside a scheduled callback
          detail: |-
            lua/parley/highlighter.lua:967. If it errors or is renamed, every structure repair
            surfaces an error to the user and the repaint is lost. The repo guards other runtime
            APIs (vim.uv or vim.loop); pcall this one and degrade to no repaint.
          family: private-api-unguarded
          round: 2
        - id: BR-6
          severity: Minor
          title: the repair seam is installed per spec file, so the next spec re-opens the real-timer hole
          detail: |-
            lua/parley/highlighter.lua:88 and tests/integration/highlighting_spec.lua:78. PQ-1 named
            highlighting_spec.lua; the class is every spec that edits a parley buffer and pumps the
            loop. Today's tree is safe (branch_child_spec, fence_containment_spec and
            tests/perf/chat_typing.lua make only inert edits that never arm a timer) but nothing
            keeps it that way. Default new_deferral to a manual deferral under g:parley_test_mode
            and make the real clock opt-in.
          family: injected-clock-in-tests
          round: 2
        - id: BR-7
          severity: Minor
          title: the render walk keeps a second hand-written copy of leave_row's reasoning rules
          detail: |-
            lua/parley/highlighter.lua:240-283 re-implements structural-marker termination,
            reasoning_end, reasoning + lookahead and the blank terminator that leave_row
            (highlight_structure.lua:319) now owns. They already differ: the render walk's
            reasoning_end branch does not clear in_reasoning_explicit_end. Harmless today, but this
            is the drift shape #218 fixed for the fence toggle, and this diff created the shared
            helper without routing the second copy through it (ARCH-DRY).
          family: duplicated-state-machine
          round: 2
        - id: BR-8
          severity: Minor
          title: 'an unrelated issue file for #233 is committed on #227''s branch'
          detail: |-
            f00b1de adds workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md inside
            this review window. Harmless (tracker artifact, excluded by the diff pathspec) but it
            will land under #227's merge.
          family: unrelated-work-in-window
          round: 2
      blocked: true
    - "n": 3
      timestamp: "2026-09-10T18:31:16-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: Per-file install replaced by the harness default that covers highlighting_spec; M4 reddens highlight_typing_spec.lua:375.
          round: 3
        - id: BR-2
          disposition: addressed
          note: Both traceability entries list the new spec (atlas/traceability.yaml:53 and :626).
          round: 3
        - id: BR-3
          disposition: addressed
          note: Issue now cites init.lua:1714 and :2872, both correct at HEAD.
          round: 3
        - id: BR-4
          disposition: addressed
          note: 'Verified by reverting: 0-copied reporting reddens the observer test and aborts make perf at chat_typing.lua:130; a deepcopy splice reddens the unit sharing test.'
          round: 3
        - id: BR-5
          disposition: addressed
          note: Unguarding nvim__redraw reddens the refusing-redraw test (highlight_typing_spec.lua:233).
          round: 3
        - id: BR-6
          disposition: addressed
          note: 'Harness default keyed on the env var every spec inherits (probe: g is nil, env is 1); removing it reddens the harness-default test.'
          round: 3
        - id: BR-7
          disposition: not-addressed
          note: Deferred to issue 234 with a concrete Spec incl. the chat_parser sweep; a separable, acceptable deferral for a Minor, non-blocking.
          round: 3
        - id: BR-8
          disposition: addressed
          note: The issue Log now declares f00b1de as a rider; the family rule is stated in the new finding on 5596d22.
          round: 3
      findings:
        - id: BR-9
          severity: Minor
          title: file_tracker still reads g:parley_test_mode, which this diff proved never reaches a spec
          detail: '2nd in family. lua/parley/file_tracker.lua:10-12 guards load_data/save_data/init on vim.g.parley_test_mode, nil in every spec but chat_move_spec; a make test run leaves topic_gen_spec paths in the shared scratch file_access.json. Class measured at 2 production readers of the harness signal (highlighter.lua:91, file_tracker.lua:11), 1 migrated. Rule: one helper keyed on $PARLEY_TEST_MODE is the only production reader, enforced by an arch guard; then drop minimal_init.vim:24 and chat_move_spec.lua:5.'
          family: class-not-instance
          round: 3
        - id: BR-10
          severity: Minor
          title: 5596d22 changes shipping config defaults inside the issue window and is undeclared in the tracker
          detail: '2nd in family. lua/parley/config.lua:576 max_full_exchanges 42 to 242 and :145 live-model providers ride this issue''s close verdict and merge; neither the issue nor the plan names the commit. Prevalence: 2 riders in a 12-commit window, 1 declared. Rule: every commit from branch point to HEAD starts with the issue tag or is listed in the Log as a rider (sha plus one line), checkable via git log subjects; declare it or cherry-pick it to main.'
          family: unrelated-work-in-window
          round: 3
        - id: BR-11
          severity: Minor
          title: 'round-2 findings (work-accounting blind spot, g: not reaching spec children) have no lessons.md rule'
          detail: 'AGENTS.md section 4 requires review-found mistakes to become lessons; caa4a51 fixed BR-4 and BR-6 without one (the lessons in dcbebfb predate round 2). Candidates: equal results cannot tell a shallow splice from a deep copy, so a cost added to a gated hot path must flow through the accounting seam and be pinned by mechanism; harness signals travel via the environment, not g: variables.'
          family: review-lesson-unrecorded
          round: 3
      blocked: false
---

# Gate ledger — parley.nvim#227 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-10T18:05:17-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `injected-clock-in-tests` highlighting_spec.lua keeps production 250ms timers while the same file pumps the loop
  Task 4 injects the repair deferral only into the new highlight_typing_spec.lua.
  The structural-edit tests in highlighting_spec.lua (around lines 572, 626, 729,
  745-773, 852) will arm real vim.uv timers, and that file waits on the event loop
  for 700ms at line 1198 (also 1173, 1236) — long enough for a stray repair to
  rebuild a prior test's buffer and fire nvim__redraw mid-test. Install the manual
  deferral in a top-level before_each/after_each there too, or expose the swap from
  tests/helpers/decoration.lua so both specs construct the ordering instead of
  sampling it.
  (carried from plan-quality PQ-1, deferred to the boundary review)
- **BR-2** [Minor] `class-not-instance` traceability lists highlighting_spec.lua at two sites, Task 6 names one
  atlas/traceability.yaml references tests/integration/highlighting_spec.lua at both
  line 52 and line 624 (two different atlas entries). Task 6 Step 4 says to add the
  new spec "beside" it in the singular, so an implementer will likely update one and
  leave the other's coverage list incomplete. Decide which entries own the new spec
  and name both.
  (carried from plan-quality PQ-2, deferred to the boundary review)
- **BR-3** [Minor] `stale-file-line-pointer` two init.lua pointers in the issue's diagnosis are off by 5-7 lines
  The Problem section cites init.lua:1707 for the chat buffer being
  filetype=markdown (the actual site is the prep_chat block near :1714) and
  init.lua:2865 as the highlight_question_block path (the wrapper is at :2872-2873).
  Both behavioral claims are correct; only the line numbers drifted, and a later
  reader following them lands on ExportMarkdown and on the _parley_bufs declaration.
  (carried from plan-quality PQ-3, deferred to the boundary review)

## Round 2 — 2026-09-10T18:05:17-07:00 (claude) — BLOCKED

### Raised

- **BR-4** [Important] `work-accounting-blind-spot` on_lines discards replace's work, so the splice's O(n) copy is invisible to every gate
  lua/parley/highlighter.lua:1008 captures only (out, rows, reason) from the pcall and
  drops work, so entries_copied never reaches record_work at :1021, which sends only
  structure_rows_processed = #new_lines. The #170 hard gate (tests/perf/chat_typing.lua:116)
  asserts that value is 1 and therefore certifies a path whose real cost it cannot see;
  make perf's new structure_splice phase is report-only. Swap the shallow two-array copy
  in M.replace for vim.deepcopy and every test stays green while an Enter at 5,000 lines
  silently costs tens of ms. Fix: pass structure_entries_copied through record_work, add
  it to WORK_KEYS, and bound it in assert_hard_gates.
- **BR-5** [Minor] `private-api-unguarded` nvim__redraw is a private API called unprotected inside a scheduled callback
  lua/parley/highlighter.lua:967. If it errors or is renamed, every structure repair
  surfaces an error to the user and the repaint is lost. The repo guards other runtime
  APIs (vim.uv or vim.loop); pcall this one and degrade to no repaint.
- **BR-6** [Minor] `injected-clock-in-tests` the repair seam is installed per spec file, so the next spec re-opens the real-timer hole
  lua/parley/highlighter.lua:88 and tests/integration/highlighting_spec.lua:78. PQ-1 named
  highlighting_spec.lua; the class is every spec that edits a parley buffer and pumps the
  loop. Today's tree is safe (branch_child_spec, fence_containment_spec and
  tests/perf/chat_typing.lua make only inert edits that never arm a timer) but nothing
  keeps it that way. Default new_deferral to a manual deferral under g:parley_test_mode
  and make the real clock opt-in.
- **BR-7** [Minor] `duplicated-state-machine` the render walk keeps a second hand-written copy of leave_row's reasoning rules
  lua/parley/highlighter.lua:240-283 re-implements structural-marker termination,
  reasoning_end, reasoning + lookahead and the blank terminator that leave_row
  (highlight_structure.lua:319) now owns. They already differ: the render walk's
  reasoning_end branch does not clear in_reasoning_explicit_end. Harmless today, but this
  is the drift shape #218 fixed for the fence toggle, and this diff created the shared
  helper without routing the second copy through it (ARCH-DRY).
- **BR-8** [Minor] `unrelated-work-in-window` an unrelated issue file for #233 is committed on #227's branch
  f00b1de adds workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md inside
  this review window. Harmless (tracker artifact, excluded by the diff pathspec) but it
  will land under #227's merge.

## Round 3 — 2026-09-10T18:31:16-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Per-file install replaced by the harness default that covers highlighting_spec; M4 reddens highlight_typing_spec.lua:375.
- BR-2 — addressed — Both traceability entries list the new spec (atlas/traceability.yaml:53 and :626).
- BR-3 — addressed — Issue now cites init.lua:1714 and :2872, both correct at HEAD.
- BR-4 — addressed — Verified by reverting: 0-copied reporting reddens the observer test and aborts make perf at chat_typing.lua:130; a deepcopy splice reddens the unit sharing test.
- BR-5 — addressed — Unguarding nvim__redraw reddens the refusing-redraw test (highlight_typing_spec.lua:233).
- BR-6 — addressed — Harness default keyed on the env var every spec inherits (probe: g is nil, env is 1); removing it reddens the harness-default test.
- BR-7 — not-addressed — Deferred to issue 234 with a concrete Spec incl. the chat_parser sweep; a separable, acceptable deferral for a Minor, non-blocking.
- BR-8 — addressed — The issue Log now declares f00b1de as a rider; the family rule is stated in the new finding on 5596d22.

### Raised

- **BR-9** [Minor] `class-not-instance` file_tracker still reads g:parley_test_mode, which this diff proved never reaches a spec
  2nd in family. lua/parley/file_tracker.lua:10-12 guards load_data/save_data/init on vim.g.parley_test_mode, nil in every spec but chat_move_spec; a make test run leaves topic_gen_spec paths in the shared scratch file_access.json. Class measured at 2 production readers of the harness signal (highlighter.lua:91, file_tracker.lua:11), 1 migrated. Rule: one helper keyed on $PARLEY_TEST_MODE is the only production reader, enforced by an arch guard; then drop minimal_init.vim:24 and chat_move_spec.lua:5.
- **BR-10** [Minor] `unrelated-work-in-window` 5596d22 changes shipping config defaults inside the issue window and is undeclared in the tracker
  2nd in family. lua/parley/config.lua:576 max_full_exchanges 42 to 242 and :145 live-model providers ride this issue's close verdict and merge; neither the issue nor the plan names the commit. Prevalence: 2 riders in a 12-commit window, 1 declared. Rule: every commit from branch point to HEAD starts with the issue tag or is listed in the Log as a rider (sha plus one line), checkable via git log subjects; declare it or cherry-pick it to main.
- **BR-11** [Minor] `review-lesson-unrecorded` round-2 findings (work-accounting blind spot, g: not reaching spec children) have no lessons.md rule
  AGENTS.md section 4 requires review-found mistakes to become lessons; caa4a51 fixed BR-4 and BR-6 without one (the lessons in dcbebfb predate round 2). Candidates: equal results cannot tell a shallow splice from a deep copy, so a cost added to a gated hot path must flow through the accounting seam and be pinned by mechanism; harness signals travel via the environment, not g: variables.

## Open findings

- **BR-7** [Minor] `duplicated-state-machine` the render walk keeps a second hand-written copy of leave_row's reasoning rules
- **BR-9** [Minor] `class-not-instance` file_tracker still reads g:parley_test_mode, which this diff proved never reaches a spec
- **BR-10** [Minor] `unrelated-work-in-window` 5596d22 changes shipping config defaults inside the issue window and is undeclared in the tracker
- **BR-11** [Minor] `review-lesson-unrecorded` round-2 findings (work-accounting blind spot, g: not reaching spec children) have no lessons.md rule
