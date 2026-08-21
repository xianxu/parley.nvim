---
gate: boundary-review
issue: 200
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-08-20T18:31:05-07:00"
      agent: claude
      boundary: M1
      blocked: true
      protocol_error: no valid findings block
    - "n": 2
      timestamp: "2026-08-20T21:25:31-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: FOLDABLE duplicates ANCHOR_KIND's key set; drift silently refuses the whole exchange
          detail: |-
            fold_projection.lua:5-11 and :22-27 state "which kinds fold" twice. Adding a kind to
            FOLDABLE alone makes anchor_kind return nil, verify_anchors reject the range, and the
            re-derive reproduce it — a permanent refusal of the entire exchange, not just that
            block. No test pins the two key sets agree. Fix: delete FOLDABLE, define
            is_foldable(k) as ANCHOR_KIND[k] ~= nil, and have desired_folds call it (ARCH-DRY).
          round: 2
        - id: BR-2
          severity: Important
          title: No test pins "folds outside every exchange span are untouched"
          detail: |-
            clear_folds_in_span's docstring (tool_folds.lua:48) and the atlas both promise it, but
            the only test that demonstrated it (tool_folds_spec.lua:39) was converted in round 5
            when the last exchange's span widened to EOF, and was not replaced. Verified the
            behavior still holds — a 1,4fold over the frontmatter survives a reconcile that folds
            the tool_result at row 10 — so this is coverage, not a bug. Given the diff widened
            destruction twice, add a case pinning the header region above exchange_start(1).
          round: 2
        - id: BR-3
          severity: Important
          title: atlas names verify_span and a positional fallback that were both removed in round 5
          detail: |-
            atlas/chat/exchange_model.md:84 says "The positional check (verify_span) remains only
            as the fallback floor". grep -rn verify_span lua/ tests/ returns nothing, and
            owned_span's own comment reads "There is deliberately no positional fallback." The
            section also omits round 8's containment tie, which is load-bearing. Docs update gate.
          round: 2
        - id: BR-4
          severity: Important
          title: Plan Core-concepts entry contradicts the code and the plan's own line 65
          detail: |-
            000200-fold-reconciliation-plan.md:37 still lists verify_span(first_0, last_0, lines,
            patterns, anchor_required) as what fold_projection gains, while :65 correctly names
            verify_starts. Separately, the plan's Revisions stop at round 7 — round 8's design
            change (creation ranges must lie inside the identified span; iteration-count scaling
            test) is recorded only in the issue Log. See the review's section 7 for both entries.
          round: 2
        - id: BR-5
          severity: Important
          title: rederived memo leaks a parsed model per buffer behind a no-op weak-key guard
          detail: |-
            tool_folds.lua:148 uses __mode = "k" with integer buffer handles; Lua only collects
            collectable weak keys. Measured: 1000/1000 integer-keyed entries survive two full GC
            passes, table-keyed drop to 0. The BufUnload/BufDelete autocmd at :466-472 clears
            initialized and exchange_anchors but not rederived[buf], so every closed chat retains
            its last exchange_model for the process lifetime. Add rederived[buf] = nil there and
            drop the __mode metatable, which reads as a guard and is not one.
          round: 2
        - id: BR-6
          severity: Minor
          title: Duplicated comment paragraph and split declaration in prepare_exchange_update
          detail: |-
            tool_folds.lua:335-346 repeats the same "same rule as reconcile" paragraph twice;
            :331 declares first_0/last_0 two lines before its only assignment.
          round: 2
        - id: BR-7
          severity: Minor
          title: owned_span writes the same return statement twice (ARCH-DRY)
          detail: tool_folds.lua:242-246 collapses to a single guard plus one return.
          round: 2
        - id: BR-8
          severity: Minor
          title: Two stale test comments in the integration fold spec
          detail: |-
            tool_folds_spec.lua:180-186 describes wall-clock sampling the test no longer does;
            :93's "Contrast the case above, whose fold sits outside every span" points at :55,
            which now asserts that fold IS cleared.
          round: 2
        - id: BR-9
          severity: Minor
          title: verify_anchors cannot run without a vim global; the purity test only pins module load
          detail: |-
            fold_projection.lua:76 requires highlight_structure unconditionally even when patterns
            is supplied, so it fails in vim/_init_packages.lua under _G.vim = nil, while
            verify_starts runs fine. fold_projection_spec.lua:32 checks load-time purity only, so
            the plan's "pure and nvim-free" claim is unpinned at call time (ARCH-PURE).
          round: 2
        - id: BR-10
          severity: Minor
          title: prepare_exchange_update computes desired_folds only to fill the observer event
          detail: tool_folds.lua:330 — per-streamed-chunk work whose sole consumer is the test seam.
          round: 2
        - id: BR-11
          severity: Minor
          title: M._last_clear_iters is not reset on clear_folds_in_span's early returns
          detail: |-
            tool_folds.lua:50-57 return before :93 in three cases, so a reader can pick up a stale
            iteration count from a previous call.
          round: 2
        - id: BR-12
          severity: Minor
          title: The containment rule is pure logic living in the IO shell (ARCH-PURE)
          detail: |-
            tool_folds.lua:279-286 is a pure predicate over ranges and a row span, reachable only
            through an integration test. Extracting it to fold_projection makes it unit-pinnable.
          round: 2
        - id: BR-13
          severity: Minor
          title: The fold-creation loop is unprotected against E350 though the clear half handles it
          detail: |-
            tool_folds.lua:321 throws out of reconcile under a non-manual foldmethod, while
            clear_folds_in_span:65-68 explicitly reasons about that case. Pre-existing, but the
            asymmetry is newly visible.
          round: 2
        - id: BR-14
          severity: Minor
          title: lessons.md has no rule for the duplicate-test-block defect this window fixed
          detail: |-
            The existing "deleted tests do not fail" entry keys on a SHRINKING green suite; a
            duplicated describe block makes it grow, which is why the count check read as "I added
            tests" for four rounds. Add the uniq -d audit over it("...") names (AGENTS.md section 4).
          round: 2
        - id: BR-15
          severity: Minor
          title: No follow-up issue filed for the harness scratch-dir contention diagnosed in round 6
          detail: |-
            The Log says tools_builtin_find_spec traverses a .test-tmp being mutated under it and
            that it is "worth its own issue". No issue exists; the diagnosis will be archived to
            workshop/history/ at close.
          round: 2
        - id: BR-16
          severity: Minor
          title: README not updated for the new fold-ownership contract
          detail: |-
            A manual zf inside an exchange — now including the whole buffer tail after the last
            block — is destroyed on the next reconcile. Operator-visible, documented only in atlas.
          round: 2
        - id: BR-17
          severity: Minor
          title: Corpus harness shells out to git ls-files outside any seam (ARCH-MOCK)
          detail: |-
            fold_invariants_spec.lua:17. Mitigated by the "#corpus >= 8" floor, which makes a
            missing or failed git a loud failure rather than a silently shrunken suite. Noting only.
          round: 2
        - id: BR-18
          severity: Minor
          title: Plan doc Task 1-5 step checkboxes still unticked although M1 is complete
          detail: The issue's Plan section is correctly ticked; the durable plan's steps lag.
          round: 2
      boundary: M1
      blocked: false
    - "n": 3
      timestamp: "2026-08-20T21:38:20-07:00"
      agent: claude
      findings:
        - id: BR-19
          severity: Critical
          title: 'clear_folds_in_span deletes nothing under ''nofoldenable'', restoring the #200 symptom permanently'
          detail: "tool_folds.lua:75,77 gate every deletion on foldlevel(), which reports 0\nfor all rows when the window has 'nofoldenable' (verified: :fold still\ncreates the fold, foldlevel() just cannot see it; zj still navigates).\nReconcile degrades to append-only. Reproduced both failure modes — a\nstale fold covering a question survives and renders \"\U0001F4AC: q (4 lines)\",\nand 25 reconciles produce 25 nested fold levels at the same rows, i.e.\none level per streamed chunk. Parley ships chat_toggle_tool_folds\n(init.lua:2236) which sets this very option, and no fold spec varies it.\nFix: save/force/restore &l:foldenable around the clear loop inside the\nexisting nvim_win_call, and add foldenable=false variants of the\nownership and fold-nesting tests."
          round: 3
        - id: BR-20
          severity: Important
          title: reconcile_exchange is O(number of exchanges) per call on the per-chunk streaming path
          detail: |-
            exchange_anchors.span resolves every anchor on every call, so per-chunk
            cost scales with chat length, not exchange length. Measured with the
            streamed exchange held constant: 0.0386 ms at 10 exchanges, 0.0495 at 50,
            0.1172 at 200, 0.2549 at 500 — and owned_span runs twice per chunk
            (prepare + finalize) against a 0.078 ms pre-200 baseline. The in-suite
            scaling test varies span length only, so this axis is unpinned. Fix:
            memoise resolved anchor rows per (buf, changedtick) — exact, since marks
            only move on edits and every edit bumps the tick — and extend the
            iteration-count test to hold span fixed while growing exchange count.
          round: 3
        - id: BR-21
          severity: Important
          title: the drift refusal is logged once per buffer lifetime, not once per buffer state
          detail: |-
            rederived[buf].logged is carried into every new tick's entry
            (tool_folds.lua:181) and never reset on a successful reconcile, so after
            the first refusal in a buffer every later refusal — including an
            unrelated drift much later in the session — is silent. The comment at
            :310-311 says "once per buffer state" and the Done-when requires the
            refusal not be silent. Fix: clear the flag when reconcile_exchange
            succeeds, or key the suppression on the tick rather than the buffer.
          round: 3
        - id: BR-22
          severity: Minor
          title: vim.g.parley_fold_clear_iters is a test instrument written to a global on the per-chunk path
          detail: |-
            tool_folds.lua:88,93. Prefer nvim_exec2 with output capture, or a
            buffer-local var, so the production hot path does not publish a global.
          round: 3
        - id: BR-23
          severity: Minor
          title: the prepare event's `identified` flag has no consumer and no test
          detail: tool_folds.lua:351,357 emit it, nothing reads or asserts it.
          round: 3
        - id: BR-24
          severity: Minor
          title: _observer is reset inline rather than in after_each, so a failing assertion leaks it
          detail: |-
            tests/integration/tool_folds_spec.lua:252,706 — _model_provider is reset
            in after_each (:23) but _observer is not.
          round: 3
        - id: BR-25
          severity: Minor
          title: foldtext hardcodes the four marker prefixes instead of deriving from highlight_structure.patterns
          detail: "tool_folds.lua:434-449. A customised chat_tool_use_prefix silently falls\nthrough to the preview branch — the same branch that rendered\n\"\U0001F4AC: q (4 lines)\" and masked #200. Pre-existing and outside the diff, but\nit is now the last hand-maintained copy of the marker vocabulary BR-1\nconsolidated into ANCHOR_KIND (ARCH-DRY)."
          round: 3
      boundary: M1
      blocked: false
---

# Gate ledger — parley.nvim#200 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-20T18:31:05-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 2 — 2026-08-20T21:25:31-07:00 (claude) — passed

### Raised

- **BR-1** [Important] FOLDABLE duplicates ANCHOR_KIND's key set; drift silently refuses the whole exchange
  fold_projection.lua:5-11 and :22-27 state "which kinds fold" twice. Adding a kind to
  FOLDABLE alone makes anchor_kind return nil, verify_anchors reject the range, and the
  re-derive reproduce it — a permanent refusal of the entire exchange, not just that
  block. No test pins the two key sets agree. Fix: delete FOLDABLE, define
  is_foldable(k) as ANCHOR_KIND[k] ~= nil, and have desired_folds call it (ARCH-DRY).
- **BR-2** [Important] No test pins "folds outside every exchange span are untouched"
  clear_folds_in_span's docstring (tool_folds.lua:48) and the atlas both promise it, but
  the only test that demonstrated it (tool_folds_spec.lua:39) was converted in round 5
  when the last exchange's span widened to EOF, and was not replaced. Verified the
  behavior still holds — a 1,4fold over the frontmatter survives a reconcile that folds
  the tool_result at row 10 — so this is coverage, not a bug. Given the diff widened
  destruction twice, add a case pinning the header region above exchange_start(1).
- **BR-3** [Important] atlas names verify_span and a positional fallback that were both removed in round 5
  atlas/chat/exchange_model.md:84 says "The positional check (verify_span) remains only
  as the fallback floor". grep -rn verify_span lua/ tests/ returns nothing, and
  owned_span's own comment reads "There is deliberately no positional fallback." The
  section also omits round 8's containment tie, which is load-bearing. Docs update gate.
- **BR-4** [Important] Plan Core-concepts entry contradicts the code and the plan's own line 65
  000200-fold-reconciliation-plan.md:37 still lists verify_span(first_0, last_0, lines,
  patterns, anchor_required) as what fold_projection gains, while :65 correctly names
  verify_starts. Separately, the plan's Revisions stop at round 7 — round 8's design
  change (creation ranges must lie inside the identified span; iteration-count scaling
  test) is recorded only in the issue Log. See the review's section 7 for both entries.
- **BR-5** [Important] rederived memo leaks a parsed model per buffer behind a no-op weak-key guard
  tool_folds.lua:148 uses __mode = "k" with integer buffer handles; Lua only collects
  collectable weak keys. Measured: 1000/1000 integer-keyed entries survive two full GC
  passes, table-keyed drop to 0. The BufUnload/BufDelete autocmd at :466-472 clears
  initialized and exchange_anchors but not rederived[buf], so every closed chat retains
  its last exchange_model for the process lifetime. Add rederived[buf] = nil there and
  drop the __mode metatable, which reads as a guard and is not one.
- **BR-6** [Minor] Duplicated comment paragraph and split declaration in prepare_exchange_update
  tool_folds.lua:335-346 repeats the same "same rule as reconcile" paragraph twice;
  :331 declares first_0/last_0 two lines before its only assignment.
- **BR-7** [Minor] owned_span writes the same return statement twice (ARCH-DRY)
  tool_folds.lua:242-246 collapses to a single guard plus one return.
- **BR-8** [Minor] Two stale test comments in the integration fold spec
  tool_folds_spec.lua:180-186 describes wall-clock sampling the test no longer does;
  :93's "Contrast the case above, whose fold sits outside every span" points at :55,
  which now asserts that fold IS cleared.
- **BR-9** [Minor] verify_anchors cannot run without a vim global; the purity test only pins module load
  fold_projection.lua:76 requires highlight_structure unconditionally even when patterns
  is supplied, so it fails in vim/_init_packages.lua under _G.vim = nil, while
  verify_starts runs fine. fold_projection_spec.lua:32 checks load-time purity only, so
  the plan's "pure and nvim-free" claim is unpinned at call time (ARCH-PURE).
- **BR-10** [Minor] prepare_exchange_update computes desired_folds only to fill the observer event
  tool_folds.lua:330 — per-streamed-chunk work whose sole consumer is the test seam.
- **BR-11** [Minor] M._last_clear_iters is not reset on clear_folds_in_span's early returns
  tool_folds.lua:50-57 return before :93 in three cases, so a reader can pick up a stale
  iteration count from a previous call.
- **BR-12** [Minor] The containment rule is pure logic living in the IO shell (ARCH-PURE)
  tool_folds.lua:279-286 is a pure predicate over ranges and a row span, reachable only
  through an integration test. Extracting it to fold_projection makes it unit-pinnable.
- **BR-13** [Minor] The fold-creation loop is unprotected against E350 though the clear half handles it
  tool_folds.lua:321 throws out of reconcile under a non-manual foldmethod, while
  clear_folds_in_span:65-68 explicitly reasons about that case. Pre-existing, but the
  asymmetry is newly visible.
- **BR-14** [Minor] lessons.md has no rule for the duplicate-test-block defect this window fixed
  The existing "deleted tests do not fail" entry keys on a SHRINKING green suite; a
  duplicated describe block makes it grow, which is why the count check read as "I added
  tests" for four rounds. Add the uniq -d audit over it("...") names (AGENTS.md section 4).
- **BR-15** [Minor] No follow-up issue filed for the harness scratch-dir contention diagnosed in round 6
  The Log says tools_builtin_find_spec traverses a .test-tmp being mutated under it and
  that it is "worth its own issue". No issue exists; the diagnosis will be archived to
  workshop/history/ at close.
- **BR-16** [Minor] README not updated for the new fold-ownership contract
  A manual zf inside an exchange — now including the whole buffer tail after the last
  block — is destroyed on the next reconcile. Operator-visible, documented only in atlas.
- **BR-17** [Minor] Corpus harness shells out to git ls-files outside any seam (ARCH-MOCK)
  fold_invariants_spec.lua:17. Mitigated by the "#corpus >= 8" floor, which makes a
  missing or failed git a loud failure rather than a silently shrunken suite. Noting only.
- **BR-18** [Minor] Plan doc Task 1-5 step checkboxes still unticked although M1 is complete
  The issue's Plan section is correctly ticked; the durable plan's steps lag.

## Round 3 — 2026-08-20T21:38:20-07:00 (claude) — passed

### Raised

- **BR-19** [Critical] clear_folds_in_span deletes nothing under 'nofoldenable', restoring the #200 symptom permanently
  tool_folds.lua:75,77 gate every deletion on foldlevel(), which reports 0
  for all rows when the window has 'nofoldenable' (verified: :fold still
  creates the fold, foldlevel() just cannot see it; zj still navigates).
  Reconcile degrades to append-only. Reproduced both failure modes — a
  stale fold covering a question survives and renders "💬: q (4 lines)",
  and 25 reconciles produce 25 nested fold levels at the same rows, i.e.
  one level per streamed chunk. Parley ships chat_toggle_tool_folds
  (init.lua:2236) which sets this very option, and no fold spec varies it.
  Fix: save/force/restore &l:foldenable around the clear loop inside the
  existing nvim_win_call, and add foldenable=false variants of the
  ownership and fold-nesting tests.
- **BR-20** [Important] reconcile_exchange is O(number of exchanges) per call on the per-chunk streaming path
  exchange_anchors.span resolves every anchor on every call, so per-chunk
  cost scales with chat length, not exchange length. Measured with the
  streamed exchange held constant: 0.0386 ms at 10 exchanges, 0.0495 at 50,
  0.1172 at 200, 0.2549 at 500 — and owned_span runs twice per chunk
  (prepare + finalize) against a 0.078 ms pre-200 baseline. The in-suite
  scaling test varies span length only, so this axis is unpinned. Fix:
  memoise resolved anchor rows per (buf, changedtick) — exact, since marks
  only move on edits and every edit bumps the tick — and extend the
  iteration-count test to hold span fixed while growing exchange count.
- **BR-21** [Important] the drift refusal is logged once per buffer lifetime, not once per buffer state
  rederived[buf].logged is carried into every new tick's entry
  (tool_folds.lua:181) and never reset on a successful reconcile, so after
  the first refusal in a buffer every later refusal — including an
  unrelated drift much later in the session — is silent. The comment at
  :310-311 says "once per buffer state" and the Done-when requires the
  refusal not be silent. Fix: clear the flag when reconcile_exchange
  succeeds, or key the suppression on the tick rather than the buffer.
- **BR-22** [Minor] vim.g.parley_fold_clear_iters is a test instrument written to a global on the per-chunk path
  tool_folds.lua:88,93. Prefer nvim_exec2 with output capture, or a
  buffer-local var, so the production hot path does not publish a global.
- **BR-23** [Minor] the prepare event's `identified` flag has no consumer and no test
  tool_folds.lua:351,357 emit it, nothing reads or asserts it.
- **BR-24** [Minor] _observer is reset inline rather than in after_each, so a failing assertion leaks it
  tests/integration/tool_folds_spec.lua:252,706 — _model_provider is reset
  in after_each (:23) but _observer is not.
- **BR-25** [Minor] foldtext hardcodes the four marker prefixes instead of deriving from highlight_structure.patterns
  tool_folds.lua:434-449. A customised chat_tool_use_prefix silently falls
  through to the preview branch — the same branch that rendered
  "💬: q (4 lines)" and masked #200. Pre-existing and outside the diff, but
  it is now the last hand-maintained copy of the marker vocabulary BR-1
  consolidated into ANCHOR_KIND (ARCH-DRY).

## Open findings

- **BR-1** [Important] FOLDABLE duplicates ANCHOR_KIND's key set; drift silently refuses the whole exchange
- **BR-2** [Important] No test pins "folds outside every exchange span are untouched"
- **BR-3** [Important] atlas names verify_span and a positional fallback that were both removed in round 5
- **BR-4** [Important] Plan Core-concepts entry contradicts the code and the plan's own line 65
- **BR-5** [Important] rederived memo leaks a parsed model per buffer behind a no-op weak-key guard
- **BR-6** [Minor] Duplicated comment paragraph and split declaration in prepare_exchange_update
- **BR-7** [Minor] owned_span writes the same return statement twice (ARCH-DRY)
- **BR-8** [Minor] Two stale test comments in the integration fold spec
- **BR-9** [Minor] verify_anchors cannot run without a vim global; the purity test only pins module load
- **BR-10** [Minor] prepare_exchange_update computes desired_folds only to fill the observer event
- **BR-11** [Minor] M._last_clear_iters is not reset on clear_folds_in_span's early returns
- **BR-12** [Minor] The containment rule is pure logic living in the IO shell (ARCH-PURE)
- **BR-13** [Minor] The fold-creation loop is unprotected against E350 though the clear half handles it
- **BR-14** [Minor] lessons.md has no rule for the duplicate-test-block defect this window fixed
- **BR-15** [Minor] No follow-up issue filed for the harness scratch-dir contention diagnosed in round 6
- **BR-16** [Minor] README not updated for the new fold-ownership contract
- **BR-17** [Minor] Corpus harness shells out to git ls-files outside any seam (ARCH-MOCK)
- **BR-18** [Minor] Plan doc Task 1-5 step checkboxes still unticked although M1 is complete
- **BR-19** [Critical] clear_folds_in_span deletes nothing under 'nofoldenable', restoring the #200 symptom permanently
- **BR-20** [Important] reconcile_exchange is O(number of exchanges) per call on the per-chunk streaming path
- **BR-21** [Important] the drift refusal is logged once per buffer lifetime, not once per buffer state
- **BR-22** [Minor] vim.g.parley_fold_clear_iters is a test instrument written to a global on the per-chunk path
- **BR-23** [Minor] the prepare event's `identified` flag has no consumer and no test
- **BR-24** [Minor] _observer is reset inline rather than in after_each, so a failing assertion leaks it
- **BR-25** [Minor] foldtext hardcodes the four marker prefixes instead of deriving from highlight_structure.patterns
