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
    - "n": 4
      timestamp: "2026-08-20T21:52:18-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: FOLDABLE derived from ANCHOR_KIND at fold_projection.lua:22-23; drift is now structurally impossible.
          round: 4
        - id: BR-2
          disposition: addressed
          note: tool_folds_spec.lua:488 folds the frontmatter and asserts it survives a full reconcile.
          round: 4
        - id: BR-3
          disposition: addressed
          note: grep verify_span over atlas/ is empty; the section now states "no positional fallback" and documents the containment tie.
          round: 4
        - id: BR-4
          disposition: not-addressed
          note: Core-concepts fixed at plan:37, but Revisions still stop at round 7 — rounds 8 and 9 unrecorded.
          round: 4
        - id: BR-5
          disposition: addressed
          note: Weak mode dropped (tool_folds.lua:162); rederived[buf] cleared on BufUnload/BufDelete at :484.
          round: 4
        - id: BR-6
          disposition: not-addressed
          note: tool_folds.lua:348-354 still repeats the paragraph; :345 still splits the declaration from :355.
          round: 4
        - id: BR-7
          disposition: not-addressed
          note: tool_folds.lua:256-260 unchanged.
          round: 4
        - id: BR-8
          disposition: not-addressed
          note: Both comments unchanged — spec :184-186 still describes wall-clock sampling, :93 still says the case above sits outside every span when it now asserts that fold IS cleared.
          round: 4
        - id: BR-9
          disposition: not-addressed
          note: fold_projection.lua:80 still requires highlight_structure unconditionally; the purity test still checks load time only.
          round: 4
        - id: BR-10
          disposition: not-addressed
          note: tool_folds.lua:344 unchanged.
          round: 4
        - id: BR-11
          disposition: not-addressed
          note: tool_folds.lua:50-51 and :57 still return before the iteration count is written at :103.
          round: 4
        - id: BR-12
          disposition: not-addressed
          note: tool_folds.lua:293-300 unchanged.
          round: 4
        - id: BR-13
          disposition: not-addressed
          note: tool_folds.lua:335 still unguarded while the clear half reasons about E350 at :63-68.
          round: 4
        - id: BR-14
          disposition: not-addressed
          note: The new lessons entry keys on a shrinking suite and a comm -13 set diff; duplicates collapse in a set, so no rule covers the duplicate-block defect.
          round: 4
        - id: BR-15
          disposition: not-addressed
          note: workshop/issues/ still holds eight issues, none for the scratch-dir contention.
          round: 4
        - id: BR-16
          disposition: not-addressed
          note: No README.md change anywhere in 38a6cdd..HEAD.
          round: 4
        - id: BR-17
          disposition: not-addressed
          note: fold_invariants_spec.lua:17 unchanged; the >= 8 floor still mitigates it.
          round: 4
        - id: BR-18
          disposition: not-addressed
          note: Every Task 1-5 step checkbox in the durable plan is still unticked.
          round: 4
        - id: BR-19
          disposition: addressed
          note: Guard at tool_folds.lua:76-98 with two foldenable=false tests; verified foldlevel() reads 0 under nofoldenable and that :fold does not re-enable the option.
          round: 4
        - id: BR-20
          disposition: not-addressed
          note: exchange_anchors.lua:70-74 still resolves every anchor per call; no memo, and the scaling test still varies span length only.
          round: 4
        - id: BR-21
          disposition: not-addressed
          note: tool_folds.lua:191 still carries logged forward; no writer resets it on success. This is the unmet "refusal is not silent" Done-when.
          round: 4
        - id: BR-22
          disposition: not-addressed
          note: tool_folds.lua:97,103 unchanged.
          round: 4
        - id: BR-23
          disposition: not-addressed
          note: grep identified over lua/ and tests/ returns only the two emit sites.
          round: 4
        - id: BR-24
          disposition: not-addressed
          note: tool_folds_spec.lua:260,765 still reset inline; after_each at :22 resets only _model_provider.
          round: 4
        - id: BR-25
          disposition: not-addressed
          note: tool_folds.lua:444-454 unchanged.
          round: 4
      findings:
        - id: BR-26
          severity: Minor
          title: per-chunk reconcile cost is linear in projected-range length, and that axis is unasserted
          detail: |-
            covered_lines plus verify_anchors' interior scan is an O(span) buffer read
            this milestone introduced on the per-streamed-chunk path. Measured
            best-of-30 per reconcile with a single thinking range: 0.0070 / 0.0100 /
            0.0230 / 0.0825 / 0.3440 ms at 25 / 100 / 400 / 1600 / 6400 body rows —
            clean linearity, so streaming a long foldable block is O(N^2) overall.
            Absolute cost is small, but the in-suite scaling test asserts only
            clear-loop iteration count, so nothing pins this axis.
          round: 4
        - id: BR-27
          severity: Minor
          title: atlas does not record that the clear transiently forces 'foldenable'
          detail: |-
            The last commit made tool_folds write a window option it does not own,
            saving and restoring it around the clear. atlas/chat/exchange_model.md's
            fold-reconciliation section describes the zj/zD walk but not this, so the
            operator-visible contract ("your foldenable setting is momentarily forced
            on and restored") lives only in a code comment. One-line delta.
          round: 4
        - id: BR-28
          severity: Minor
          title: prepare clears the identified span unverified while reconcile refuses to create unverified
          detail: |-
            prepare_exchange_update destroys every fold in the identified span with no
            range verification; reconcile_exchange refuses to create when verification
            fails. If finalize's reconcile then refuses, the span is left cleared with
            nothing recreated and hydrate_window latches. I could not reach this in
            production — the re-derive normally heals within the same call — so this is
            an asymmetry note rather than a demonstrated bug, but it is the shape
            lessons.md's own "widening a destructive operation demands widening its
            verification" entry warns about.
          round: 4
      boundary: M1
      blocked: false
    - "n": 5
      timestamp: "2026-08-21T11:47:17-07:00"
      agent: claude
      findings:
        - id: BR-29
          severity: Critical
          title: answer_structure's unterminated-fence rewind fires on a correctly closed fence, truncating the tool block
          detail: "lua/parley/answer_structure.lua:114 gates the rewind on `cursor > #lines`, which is\nequally true when the fence closed on the last line of the span. A tool body containing\na BOUNDARY-classified line (\U0001F4DD:/\U0001F4AC:/\U0001F916:/\U0001F512:) whose close is that last line is truncated\nat its opener: reduce returns tool_result 1..2 / summary 3..3 / text 4..4 where dc5ee17\nreturned tool_result 1..4. Measured on real fold state, the body leaks out of its fold\nand a fold is anchored on the in-body marker. Reachable on the streaming path\n(chat_respond.lua:1704) and on cold parse of a chat ending at a tool-result fence.\nFix: track a `closed` flag set in the close branch and gate the rewind on `not closed`."
          family: failure-fallback-misgated
          round: 5
        - id: BR-30
          severity: Critical
          title: chat_parser's in-body suppression is unbounded, so one unclosed fence swallows the rest of the chat
          detail: "lua/parley/chat_parser.lua:526 suppresses structural classification while tool_fence_len\nis set and tool_body_complete is false, with no terminator. An opener that never gets a\nmatching bare close reclassifies every later marker to text and forks no further\nexchange: 3 exchanges before M2, 1 after. Reachable without a malformed file — an answer\nquoting a \U0001F4CE: line inside ordinary markdown prose (fence-naive by design) opens a tool\nblock whose body never closes. Exchange starts feed exchange_anchors identity, which\ndrives the M1 destructive fold clear. answer_structure got a bounded fallback for this\ncase in the same milestone; chat_parser did not. Fix: precompute in_tool_body[] with a\nlookahead that requires the close to exist, and suppress on that."
          family: unterminated-fence-degradation
          round: 5
        - id: BR-31
          severity: Important
          title: 11 pre-existing tests deleted from chat_parser_tools_spec.lua, undeclared
          detail: |-
            The file was replaced wholesale (344 -> 108 lines), dropping the entire #81
            content_blocks contract plus "a tool_use prefix without a fenced body ... empty input" —
            the only malformed-tool-tolerance test, and the class of the C2 regression. None were
            relocated. The M2 Log reports "chat_parser_tools_spec 5/5" without noting it was 11.
            This is the rule at workshop/lessons.md:706-713, added by this issue.
          family: spec-surgery-loses-tests
          round: 5
        - id: BR-32
          severity: Important
          title: atlas/chat/format.md still names tools/serialize.lua as the fence single source
          detail: |-
            Plan Task 11 Step 3 names atlas/chat/format.md explicitly and is ticked, but the file is
            untouched: line 12 still reads "Single source of truth for the schema:
            lua/parley/tools/serialize.lua". atlas/chat/parsing.md never mentions the in-body-content
            rule and line 17 still says structural markers "always terminate either mode".
            traceability.yaml adds fence.lua under chat/exchange_model + providers/tool_use, not
            chat/parsing as the plan directed. ARCH-PURPOSE shadow sweep incomplete.
          family: shadow-consumer-not-derived
          round: 5
        - id: BR-33
          severity: Important
          title: fold_projection's interior scan enters body mode on any fence, disabling the question guard
          detail: |-
            lua/parley/fold_projection.lua:120-126 treats any open_len-matching line as a body opener
            for any foldable range kind. A bare run is indistinguishable from an opener, so one
            unmatched or grammar-rejected fence (e.g. an info string with non-word characters, as
            render_buffer.lua:104 emits) desyncs the scan and it stops checking for user markers for
            the rest of the range — silently disabling the guard that defends "a question is never
            inside a fold". Fix: fence-track only for tool_use/tool_result and require the body to
            open at range.start_0 + 1.
          family: drift-guard-blinded
          round: 5
        - id: BR-34
          severity: Important
          title: Plan Task 11 Step 2 (127-transcript audit re-run) is ticked with no evidence in the Log
          detail: |-
            The M2 Log records spec counts, make test, lint and the M1 drift probes, but no re-run of
            the three audit scans against the operator's live chat_dir. That audit is the only
            evidence covering the C2 shape: the in-repo corpus provably lacks it (old-vs-new parser
            exchange counts differ on 0 of 23 in-repo transcripts).
          family: ticked-without-evidence
          round: 5
        - id: BR-35
          severity: Minor
          title: chat_parser.lua:267 require is unindented in a tab-indented function body
          family: style-consistency
          round: 5
        - id: BR-36
          severity: Minor
          title: chat_parser.lua:457-459 comment still restates the fence grammar the module no longer owns
          family: shadow-consumer-not-derived
          round: 5
        - id: BR-37
          severity: Minor
          title: fold_projection.lua:122-123 calls fence.open_len twice on the same line
          family: redundant-computation
          round: 5
        - id: BR-38
          severity: Minor
          title: fence.lua declares itself pure but is absent from the PURE_FILES arch guard
          detail: |-
            tests/arch/buffer_mutation_spec.lua:62 lists the modules whose purity is enforced. The
            new module's header claim ("Pure: no Neovim API, no state") and the plan's PURE
            classification are documentation until it is added there. One line.
          family: purity-claim-unenforced
          round: 5
        - id: BR-39
          severity: Minor
          title: fold_invariants_spec's oracle derives from the same parse it validates, so segmentation bugs pass
          detail: |-
            Both the expectations and the fold state come from one parse, so a mis-segmentation is
            asserted as correct — C1 and C2 both pass this harness. It validates fold application,
            not segmentation; the header comment should say so rather than let the harness be
            credited with coverage it cannot have.
          family: oracle-derives-from-subject
          round: 5
      boundary: M2
      blocked: true
    - "n": 6
      timestamp: "2026-08-21T12:36:09-07:00"
      agent: claude
      dispose:
        - id: BR-29
          disposition: not-addressed
          note: "Unchanged at answer_structure.lua:114; reproduced end-to-end — tool_result truncated to 2 rows and a fold anchored on an in-body \U0001F4DD:."
          round: 6
        - id: BR-30
          disposition: not-addressed
          note: Unchanged at chat_parser.lua:526; measured 3 exchanges pre-M2 vs 1 at HEAD on two independent reachable inputs.
          round: 6
        - id: BR-31
          disposition: addressed
          note: All 11 names from 9a6e939~1 present plus 5 new; 16/16 green, zero duplicate it() names.
          round: 6
        - id: BR-32
          disposition: not-addressed
          note: format.md fixed; traceability.yaml still omits fence.lua from chat/parsing and atlas/chat/parsing.md still lacks the in-body-content rule.
          round: 6
        - id: BR-33
          disposition: addressed
          note: Fix verified by revert — rejected-opener case flips true→false. Only one of the two claimed tests has teeth (see the new ticked-without-evidence finding).
          round: 6
        - id: BR-34
          disposition: addressed
          note: Audit run and recorded with the census bounding it (115 files, 1155 assertions, zero tool blocks).
          round: 6
        - id: BR-35
          disposition: not-addressed
          note: chat_parser.lua:267 still at column 0 in a tab-indented body.
          round: 6
        - id: BR-36
          disposition: not-addressed
          note: chat_parser.lua:456-459 comment unchanged.
          round: 6
        - id: BR-37
          disposition: addressed
          note: fold_projection.lua:121 now calls fence.open_len once.
          round: 6
        - id: BR-38
          disposition: not-addressed
          note: fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
          round: 6
        - id: BR-39
          disposition: not-addressed
          note: Header comment still justifies the oracle without stating that it validates fold application, not segmentation.
          round: 6
      findings:
        - id: BR-40
          severity: Critical
          title: max_full_exchanges default changed 42 to 999 in the M2 fix commit, unrelated and undeclared
          detail: "lua/parley/config.lua:640, introduced solely in b2bf1d5 (git log -S confirms) and\nunmentioned in that commit message, the issue, or the plan. Consumed at\nchat_respond.lua:737, so chat-memory summarisation effectively never fires and every\nprior exchange is sent to the provider in full instead of as its \U0001F4DD: summary. A\nuser-visible cost and context-window change with no connection to fence grammar or\nfolding. Revert, or split into its own issue with a rationale and a README note."
          family: undeclared-scope-change
          round: 6
        - id: BR-41
          severity: Important
          title: Gate steps ticked from inside the gate, and a regression test claimed to pin a fix that it does not
          detail: |-
            This is the 2nd (and 3rd) finding in family ticked-without-evidence. Do NOT fix the
            instances — fix the rule. Prevalence, all in this issue: BR-34 (Task 11 Step 2, fixed
            last round); plan lines 1338 and 1352 tick "sdlc milestone-close M2" and "sdlc close"
            while this review IS that milestone-close, no "closed M2" log line exists and status is
            still working; and the Log's "Two tests pin it" for BR-33 is false — reverting
            fold_projection.lua to b2bf1d5~1 leaves fold_projection_spec.lua:184 green, so only the
            rejected-opener test pins anything. Rule: a tick, or a written claim that a test pins a
            fix, is a claim of evidence and may only be written by the action that produced it — for
            a regression test that evidence is the revert going RED, not the suite going green.
            Corollary: never tick a gate step from inside the gate. workshop/lessons.md:722-726
            states half this rule and was violated by the same commit that wrote it; extend it with
            the revert half.
          family: ticked-without-evidence
          round: 6
        - id: BR-42
          severity: Minor
          title: The fence-aware interior scan requires the body to open at exactly start_0 + 1
          detail: |-
            fold_projection.lua:121 keys on the shape serialize.render_call/render_result emit today.
            A hand-edited or LLM-emitted transcript with a blank line between the marker and its
            opening fence loses fence-awareness, so an in-body marker refuses the whole exchange.
            Either name the coupling in the comment or accept the first non-blank line after the
            marker.
          family: serialized-shape-assumed
          round: 6
      boundary: M2
      blocked: true
    - "n": 7
      timestamp: "2026-08-21T13:14:09-07:00"
      agent: claude
      dispose:
        - id: BR-29
          disposition: addressed
          note: 'Revert-verified — restoring the `cursor > #lines` gate turns answer_structure_spec.lua:115 and :129 RED (2 vs 7).'
          round: 7
        - id: BR-30
          disposition: not-addressed
          note: Bounded only the no-close-anywhere case; 3 shapes still swallow exchanges at HEAD (3 -> 2) and one folds a user question on real fold state. See C1.
          round: 7
        - id: BR-32
          disposition: not-addressed
          note: format.md fixed; atlas/chat/parsing.md line 17 and traceability.yaml chat/parsing (:95-105) untouched since round 6, while Task 11 Step 3 stays ticked.
          round: 7
        - id: BR-35
          disposition: not-addressed
          note: chat_parser.lua:267 still at column 0 in a tab-indented body.
          round: 7
        - id: BR-36
          disposition: not-addressed
          note: chat_parser.lua:456-459 comment unchanged.
          round: 7
        - id: BR-38
          disposition: not-addressed
          note: fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
          round: 7
        - id: BR-39
          disposition: not-addressed
          note: Header unchanged, and now proven load-bearing — the harness reports 0 violations on a transcript where row 20's question has foldclosed=13.
          round: 7
        - id: BR-40
          disposition: addressed
          note: config.lua:640 restored to 42; no test pins config defaults, so the same accident stays undetectable by the suite.
          round: 7
        - id: BR-41
          disposition: addressed
          note: lessons.md:733-742 carries the revert half plus the gate corollary. Plan line 1338 is still ticked and the new BR-30 tests repeat the pattern — recorded in I3, not re-raised.
          round: 7
        - id: BR-42
          disposition: withdrawn
          note: The remedy asked for is already present — fold_projection.lua:118-121 names the immediately-after-the-marker coupling verbatim, unchanged since b2bf1d5.
          round: 7
      findings:
        - id: BR-43
          severity: Critical
          title: The tool-body scan accepts an opener anywhere after the marker, so a closing fence is read as an opening one and a user question ends up folded
          detail: |-
            2nd finding in family drift-guard-blinded (BR-33 was the 1st, in fold_projection). Do NOT
            patch the two instances — fix the rule. Rule: a tool body's extent requires (a) the marker
            at fence depth 0, (b) the opener on the immediately-following line (already enforced at
            fold_projection.lua:121), (c) an open_len that recognises every CommonMark opener, since a
            rejected opener leaves its closer to be misread as an opener. One function computes this;
            every consumer calls it. fence.extract_body is the natural home and implements none of the
            three. Sites: chat_parser.lua:536-550 and answer_structure.lua:90-97. Measured against
            dc5ee17 (M1 close): three shapes each drop 3 exchanges to 2 at HEAD - a rejected opener
            such as the ```json {"type": "request"} that render_buffer.lua:104 emits, an unclosed body
            fence followed by any later bare fence, and an answer that shows the transcript format
            inside a plain ```text block. On real Neovim fold state the third gives foldclosed=13 for
            the question at row 20 where dc5ee17 gives -1 - the issue's headline symptom, reintroduced.
            answer_structure fails the Spec's second invariant instead - a summary is swallowed into
            tool_result[1..7] where dc5ee17 emits summary[5..5]. The live 115-file corpus is unaffected
            only because it contains zero tool markers; it does contain 5 grammar-rejected openers and
            3 markers quoted inside plain fenced blocks. tests/fixtures/fold_adversarial.md covers none
            of the three shapes.
          family: drift-guard-blinded
          round: 7
        - id: BR-44
          severity: Important
          title: A second in-tool-body tracker was introduced while the plan's Core concepts states none was
          detail: |-
            3rd finding in family shadow-consumer-not-derived. Do NOT fix the instance - state the rule:
            one fact, one computation, injected into both consumers; a second derivation of "am I inside
            a tool body" is the same DRY violation M2 exists to remove, relocated one layer up.
            cb_state.tool_fence_len / tool_body_complete at chat_parser.lua:460-466 still drives block
            finalisation while in_tool_body[] at :529-556 drives main-loop classification; they compute
            the same fact by different rules and diverge on exactly the C1 shapes. Plan line 44 asserts
            "No second fence tracker is introduced (PQ-3)" - a Core-concepts contradiction the checklist
            rates Critical by default; filed Important because C1 carries the behavioural weight and the
            fix folds into C1's shared helper. Needs a "## Revisions" entry either way. Same rule at
            lower stakes: log_emit.lua:253-272 and skills/review/journal.lua:14 hand-pick fence strings,
            the latter documenting the unsound case fence.for_content solves.
          family: shadow-consumer-not-derived
          round: 7
        - id: BR-45
          severity: Important
          title: The precompute reclassifies every line two to three times, making parse_chat about 48 percent slower
          detail: |-
            2nd finding in family redundant-computation (BR-37 was fence.open_len twice on one line).
            Do NOT fix the instance - the rule is: a per-line grammar or classification predicate is
            computed once per parse into a shared array and read from there, never recomputed inside a
            scan. answer_structure.reduce:29 already does this. chat_parser now calls
            highlight_structure.classify in the precompute row loop (:533), again in every inner scan
            (:538), and a third time in the main loop (:561). Measured best-of-10 on a 10,104-line
            tool-heavy transcript: 24.49 ms at dc5ee17 to 36.22 ms at HEAD. parse_chat runs at
            tool_folds.lua:150 on hydrate and every drift re-derive, and eight times across
            chat_respond.lua. The issue's own Done-when commits to no streaming regression and M1 took
            per-chunk reconcile from 3.705 ms to 0.067 ms. Same edit as C1 - build kinds[] once and pass
            it to the shared span helper.
          family: redundant-computation
          round: 7
        - id: BR-46
          severity: Important
          title: The revert-must-go-red rule was written and then not applied by the commit that wrote it
          detail: |-
            4th finding in family ticked-without-evidence. Do NOT fix the instances. BR-41's remedy did
            land - lessons.md:733-742 states the rule and the gate corollary. In the same commit,
            describe("unterminated tool body (#200 BR-30)") presents two tests as pinning BR-30; against
            b2bf1d5 the file is 17 pass / 1 fail, so chat_parser_tools_spec.lua:485 is green on revert -
            characterization wearing a fix-pin label, unlabelled. Plan line 1338 still ticks
            "sdlc milestone-close M2" while this review is that milestone-close; only line 1352 was
            unticked. Prevalence in this issue: BR-34, BR-41 twice, and these two - five instances, the
            last three after the rule was written. Escalation: a third prose restatement will not hold.
            The rule needs a mechanical gate - a Pinned-by trailer that milestone-close refuses without
            a recorded red-on-revert run, and a close-gate check that no plan step naming
            sdlc milestone-close or sdlc close is ticked at the moment that command runs.
          family: ticked-without-evidence
          round: 7
      boundary: M2
      blocked: true
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

## Round 4 — 2026-08-20T21:52:18-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — FOLDABLE derived from ANCHOR_KIND at fold_projection.lua:22-23; drift is now structurally impossible.
- BR-2 — addressed — tool_folds_spec.lua:488 folds the frontmatter and asserts it survives a full reconcile.
- BR-3 — addressed — grep verify_span over atlas/ is empty; the section now states "no positional fallback" and documents the containment tie.
- BR-4 — not-addressed — Core-concepts fixed at plan:37, but Revisions still stop at round 7 — rounds 8 and 9 unrecorded.
- BR-5 — addressed — Weak mode dropped (tool_folds.lua:162); rederived[buf] cleared on BufUnload/BufDelete at :484.
- BR-6 — not-addressed — tool_folds.lua:348-354 still repeats the paragraph; :345 still splits the declaration from :355.
- BR-7 — not-addressed — tool_folds.lua:256-260 unchanged.
- BR-8 — not-addressed — Both comments unchanged — spec :184-186 still describes wall-clock sampling, :93 still says the case above sits outside every span when it now asserts that fold IS cleared.
- BR-9 — not-addressed — fold_projection.lua:80 still requires highlight_structure unconditionally; the purity test still checks load time only.
- BR-10 — not-addressed — tool_folds.lua:344 unchanged.
- BR-11 — not-addressed — tool_folds.lua:50-51 and :57 still return before the iteration count is written at :103.
- BR-12 — not-addressed — tool_folds.lua:293-300 unchanged.
- BR-13 — not-addressed — tool_folds.lua:335 still unguarded while the clear half reasons about E350 at :63-68.
- BR-14 — not-addressed — The new lessons entry keys on a shrinking suite and a comm -13 set diff; duplicates collapse in a set, so no rule covers the duplicate-block defect.
- BR-15 — not-addressed — workshop/issues/ still holds eight issues, none for the scratch-dir contention.
- BR-16 — not-addressed — No README.md change anywhere in 38a6cdd..HEAD.
- BR-17 — not-addressed — fold_invariants_spec.lua:17 unchanged; the >= 8 floor still mitigates it.
- BR-18 — not-addressed — Every Task 1-5 step checkbox in the durable plan is still unticked.
- BR-19 — addressed — Guard at tool_folds.lua:76-98 with two foldenable=false tests; verified foldlevel() reads 0 under nofoldenable and that :fold does not re-enable the option.
- BR-20 — not-addressed — exchange_anchors.lua:70-74 still resolves every anchor per call; no memo, and the scaling test still varies span length only.
- BR-21 — not-addressed — tool_folds.lua:191 still carries logged forward; no writer resets it on success. This is the unmet "refusal is not silent" Done-when.
- BR-22 — not-addressed — tool_folds.lua:97,103 unchanged.
- BR-23 — not-addressed — grep identified over lua/ and tests/ returns only the two emit sites.
- BR-24 — not-addressed — tool_folds_spec.lua:260,765 still reset inline; after_each at :22 resets only _model_provider.
- BR-25 — not-addressed — tool_folds.lua:444-454 unchanged.

### Raised

- **BR-26** [Minor] per-chunk reconcile cost is linear in projected-range length, and that axis is unasserted
  covered_lines plus verify_anchors' interior scan is an O(span) buffer read
  this milestone introduced on the per-streamed-chunk path. Measured
  best-of-30 per reconcile with a single thinking range: 0.0070 / 0.0100 /
  0.0230 / 0.0825 / 0.3440 ms at 25 / 100 / 400 / 1600 / 6400 body rows —
  clean linearity, so streaming a long foldable block is O(N^2) overall.
  Absolute cost is small, but the in-suite scaling test asserts only
  clear-loop iteration count, so nothing pins this axis.
- **BR-27** [Minor] atlas does not record that the clear transiently forces 'foldenable'
  The last commit made tool_folds write a window option it does not own,
  saving and restoring it around the clear. atlas/chat/exchange_model.md's
  fold-reconciliation section describes the zj/zD walk but not this, so the
  operator-visible contract ("your foldenable setting is momentarily forced
  on and restored") lives only in a code comment. One-line delta.
- **BR-28** [Minor] prepare clears the identified span unverified while reconcile refuses to create unverified
  prepare_exchange_update destroys every fold in the identified span with no
  range verification; reconcile_exchange refuses to create when verification
  fails. If finalize's reconcile then refuses, the span is left cleared with
  nothing recreated and hydrate_window latches. I could not reach this in
  production — the re-derive normally heals within the same call — so this is
  an asymmetry note rather than a demonstrated bug, but it is the shape
  lessons.md's own "widening a destructive operation demands widening its
  verification" entry warns about.

## Round 5 — 2026-08-21T11:47:17-07:00 (claude) — BLOCKED

### Raised

- **BR-29** [Critical] `failure-fallback-misgated` answer_structure's unterminated-fence rewind fires on a correctly closed fence, truncating the tool block
  lua/parley/answer_structure.lua:114 gates the rewind on `cursor > #lines`, which is
  equally true when the fence closed on the last line of the span. A tool body containing
  a BOUNDARY-classified line (📝:/💬:/🤖:/🔒:) whose close is that last line is truncated
  at its opener: reduce returns tool_result 1..2 / summary 3..3 / text 4..4 where dc5ee17
  returned tool_result 1..4. Measured on real fold state, the body leaks out of its fold
  and a fold is anchored on the in-body marker. Reachable on the streaming path
  (chat_respond.lua:1704) and on cold parse of a chat ending at a tool-result fence.
  Fix: track a `closed` flag set in the close branch and gate the rewind on `not closed`.
- **BR-30** [Critical] `unterminated-fence-degradation` chat_parser's in-body suppression is unbounded, so one unclosed fence swallows the rest of the chat
  lua/parley/chat_parser.lua:526 suppresses structural classification while tool_fence_len
  is set and tool_body_complete is false, with no terminator. An opener that never gets a
  matching bare close reclassifies every later marker to text and forks no further
  exchange: 3 exchanges before M2, 1 after. Reachable without a malformed file — an answer
  quoting a 📎: line inside ordinary markdown prose (fence-naive by design) opens a tool
  block whose body never closes. Exchange starts feed exchange_anchors identity, which
  drives the M1 destructive fold clear. answer_structure got a bounded fallback for this
  case in the same milestone; chat_parser did not. Fix: precompute in_tool_body[] with a
  lookahead that requires the close to exist, and suppress on that.
- **BR-31** [Important] `spec-surgery-loses-tests` 11 pre-existing tests deleted from chat_parser_tools_spec.lua, undeclared
  The file was replaced wholesale (344 -> 108 lines), dropping the entire #81
  content_blocks contract plus "a tool_use prefix without a fenced body ... empty input" —
  the only malformed-tool-tolerance test, and the class of the C2 regression. None were
  relocated. The M2 Log reports "chat_parser_tools_spec 5/5" without noting it was 11.
  This is the rule at workshop/lessons.md:706-713, added by this issue.
- **BR-32** [Important] `shadow-consumer-not-derived` atlas/chat/format.md still names tools/serialize.lua as the fence single source
  Plan Task 11 Step 3 names atlas/chat/format.md explicitly and is ticked, but the file is
  untouched: line 12 still reads "Single source of truth for the schema:
  lua/parley/tools/serialize.lua". atlas/chat/parsing.md never mentions the in-body-content
  rule and line 17 still says structural markers "always terminate either mode".
  traceability.yaml adds fence.lua under chat/exchange_model + providers/tool_use, not
  chat/parsing as the plan directed. ARCH-PURPOSE shadow sweep incomplete.
- **BR-33** [Important] `drift-guard-blinded` fold_projection's interior scan enters body mode on any fence, disabling the question guard
  lua/parley/fold_projection.lua:120-126 treats any open_len-matching line as a body opener
  for any foldable range kind. A bare run is indistinguishable from an opener, so one
  unmatched or grammar-rejected fence (e.g. an info string with non-word characters, as
  render_buffer.lua:104 emits) desyncs the scan and it stops checking for user markers for
  the rest of the range — silently disabling the guard that defends "a question is never
  inside a fold". Fix: fence-track only for tool_use/tool_result and require the body to
  open at range.start_0 + 1.
- **BR-34** [Important] `ticked-without-evidence` Plan Task 11 Step 2 (127-transcript audit re-run) is ticked with no evidence in the Log
  The M2 Log records spec counts, make test, lint and the M1 drift probes, but no re-run of
  the three audit scans against the operator's live chat_dir. That audit is the only
  evidence covering the C2 shape: the in-repo corpus provably lacks it (old-vs-new parser
  exchange counts differ on 0 of 23 in-repo transcripts).
- **BR-35** [Minor] `style-consistency` chat_parser.lua:267 require is unindented in a tab-indented function body
- **BR-36** [Minor] `shadow-consumer-not-derived` chat_parser.lua:457-459 comment still restates the fence grammar the module no longer owns
- **BR-37** [Minor] `redundant-computation` fold_projection.lua:122-123 calls fence.open_len twice on the same line
- **BR-38** [Minor] `purity-claim-unenforced` fence.lua declares itself pure but is absent from the PURE_FILES arch guard
  tests/arch/buffer_mutation_spec.lua:62 lists the modules whose purity is enforced. The
  new module's header claim ("Pure: no Neovim API, no state") and the plan's PURE
  classification are documentation until it is added there. One line.
- **BR-39** [Minor] `oracle-derives-from-subject` fold_invariants_spec's oracle derives from the same parse it validates, so segmentation bugs pass
  Both the expectations and the fold state come from one parse, so a mis-segmentation is
  asserted as correct — C1 and C2 both pass this harness. It validates fold application,
  not segmentation; the header comment should say so rather than let the harness be
  credited with coverage it cannot have.

## Round 6 — 2026-08-21T12:36:09-07:00 (claude) — BLOCKED

### Disposed

- BR-29 — not-addressed — Unchanged at answer_structure.lua:114; reproduced end-to-end — tool_result truncated to 2 rows and a fold anchored on an in-body 📝:.
- BR-30 — not-addressed — Unchanged at chat_parser.lua:526; measured 3 exchanges pre-M2 vs 1 at HEAD on two independent reachable inputs.
- BR-31 — addressed — All 11 names from 9a6e939~1 present plus 5 new; 16/16 green, zero duplicate it() names.
- BR-32 — not-addressed — format.md fixed; traceability.yaml still omits fence.lua from chat/parsing and atlas/chat/parsing.md still lacks the in-body-content rule.
- BR-33 — addressed — Fix verified by revert — rejected-opener case flips true→false. Only one of the two claimed tests has teeth (see the new ticked-without-evidence finding).
- BR-34 — addressed — Audit run and recorded with the census bounding it (115 files, 1155 assertions, zero tool blocks).
- BR-35 — not-addressed — chat_parser.lua:267 still at column 0 in a tab-indented body.
- BR-36 — not-addressed — chat_parser.lua:456-459 comment unchanged.
- BR-37 — addressed — fold_projection.lua:121 now calls fence.open_len once.
- BR-38 — not-addressed — fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
- BR-39 — not-addressed — Header comment still justifies the oracle without stating that it validates fold application, not segmentation.

### Raised

- **BR-40** [Critical] `undeclared-scope-change` max_full_exchanges default changed 42 to 999 in the M2 fix commit, unrelated and undeclared
  lua/parley/config.lua:640, introduced solely in b2bf1d5 (git log -S confirms) and
  unmentioned in that commit message, the issue, or the plan. Consumed at
  chat_respond.lua:737, so chat-memory summarisation effectively never fires and every
  prior exchange is sent to the provider in full instead of as its 📝: summary. A
  user-visible cost and context-window change with no connection to fence grammar or
  folding. Revert, or split into its own issue with a rationale and a README note.
- **BR-41** [Important] `ticked-without-evidence` Gate steps ticked from inside the gate, and a regression test claimed to pin a fix that it does not
  This is the 2nd (and 3rd) finding in family ticked-without-evidence. Do NOT fix the
  instances — fix the rule. Prevalence, all in this issue: BR-34 (Task 11 Step 2, fixed
  last round); plan lines 1338 and 1352 tick "sdlc milestone-close M2" and "sdlc close"
  while this review IS that milestone-close, no "closed M2" log line exists and status is
  still working; and the Log's "Two tests pin it" for BR-33 is false — reverting
  fold_projection.lua to b2bf1d5~1 leaves fold_projection_spec.lua:184 green, so only the
  rejected-opener test pins anything. Rule: a tick, or a written claim that a test pins a
  fix, is a claim of evidence and may only be written by the action that produced it — for
  a regression test that evidence is the revert going RED, not the suite going green.
  Corollary: never tick a gate step from inside the gate. workshop/lessons.md:722-726
  states half this rule and was violated by the same commit that wrote it; extend it with
  the revert half.
- **BR-42** [Minor] `serialized-shape-assumed` The fence-aware interior scan requires the body to open at exactly start_0 + 1
  fold_projection.lua:121 keys on the shape serialize.render_call/render_result emit today.
  A hand-edited or LLM-emitted transcript with a blank line between the marker and its
  opening fence loses fence-awareness, so an in-body marker refuses the whole exchange.
  Either name the coupling in the comment or accept the first non-blank line after the
  marker.

## Round 7 — 2026-08-21T13:14:09-07:00 (claude) — BLOCKED

### Disposed

- BR-29 — addressed — Revert-verified — restoring the `cursor > #lines` gate turns answer_structure_spec.lua:115 and :129 RED (2 vs 7).
- BR-30 — not-addressed — Bounded only the no-close-anywhere case; 3 shapes still swallow exchanges at HEAD (3 -> 2) and one folds a user question on real fold state. See C1.
- BR-32 — not-addressed — format.md fixed; atlas/chat/parsing.md line 17 and traceability.yaml chat/parsing (:95-105) untouched since round 6, while Task 11 Step 3 stays ticked.
- BR-35 — not-addressed — chat_parser.lua:267 still at column 0 in a tab-indented body.
- BR-36 — not-addressed — chat_parser.lua:456-459 comment unchanged.
- BR-38 — not-addressed — fence.lua still absent from PURE_FILES at tests/arch/buffer_mutation_spec.lua:62.
- BR-39 — not-addressed — Header unchanged, and now proven load-bearing — the harness reports 0 violations on a transcript where row 20's question has foldclosed=13.
- BR-40 — addressed — config.lua:640 restored to 42; no test pins config defaults, so the same accident stays undetectable by the suite.
- BR-41 — addressed — lessons.md:733-742 carries the revert half plus the gate corollary. Plan line 1338 is still ticked and the new BR-30 tests repeat the pattern — recorded in I3, not re-raised.
- BR-42 — withdrawn — The remedy asked for is already present — fold_projection.lua:118-121 names the immediately-after-the-marker coupling verbatim, unchanged since b2bf1d5.

### Raised

- **BR-43** [Critical] `drift-guard-blinded` The tool-body scan accepts an opener anywhere after the marker, so a closing fence is read as an opening one and a user question ends up folded
  2nd finding in family drift-guard-blinded (BR-33 was the 1st, in fold_projection). Do NOT
  patch the two instances — fix the rule. Rule: a tool body's extent requires (a) the marker
  at fence depth 0, (b) the opener on the immediately-following line (already enforced at
  fold_projection.lua:121), (c) an open_len that recognises every CommonMark opener, since a
  rejected opener leaves its closer to be misread as an opener. One function computes this;
  every consumer calls it. fence.extract_body is the natural home and implements none of the
  three. Sites: chat_parser.lua:536-550 and answer_structure.lua:90-97. Measured against
  dc5ee17 (M1 close): three shapes each drop 3 exchanges to 2 at HEAD - a rejected opener
  such as the ```json {"type": "request"} that render_buffer.lua:104 emits, an unclosed body
  fence followed by any later bare fence, and an answer that shows the transcript format
  inside a plain ```text block. On real Neovim fold state the third gives foldclosed=13 for
  the question at row 20 where dc5ee17 gives -1 - the issue's headline symptom, reintroduced.
  answer_structure fails the Spec's second invariant instead - a summary is swallowed into
  tool_result[1..7] where dc5ee17 emits summary[5..5]. The live 115-file corpus is unaffected
  only because it contains zero tool markers; it does contain 5 grammar-rejected openers and
  3 markers quoted inside plain fenced blocks. tests/fixtures/fold_adversarial.md covers none
  of the three shapes.
- **BR-44** [Important] `shadow-consumer-not-derived` A second in-tool-body tracker was introduced while the plan's Core concepts states none was
  3rd finding in family shadow-consumer-not-derived. Do NOT fix the instance - state the rule:
  one fact, one computation, injected into both consumers; a second derivation of "am I inside
  a tool body" is the same DRY violation M2 exists to remove, relocated one layer up.
  cb_state.tool_fence_len / tool_body_complete at chat_parser.lua:460-466 still drives block
  finalisation while in_tool_body[] at :529-556 drives main-loop classification; they compute
  the same fact by different rules and diverge on exactly the C1 shapes. Plan line 44 asserts
  "No second fence tracker is introduced (PQ-3)" - a Core-concepts contradiction the checklist
  rates Critical by default; filed Important because C1 carries the behavioural weight and the
  fix folds into C1's shared helper. Needs a "## Revisions" entry either way. Same rule at
  lower stakes: log_emit.lua:253-272 and skills/review/journal.lua:14 hand-pick fence strings,
  the latter documenting the unsound case fence.for_content solves.
- **BR-45** [Important] `redundant-computation` The precompute reclassifies every line two to three times, making parse_chat about 48 percent slower
  2nd finding in family redundant-computation (BR-37 was fence.open_len twice on one line).
  Do NOT fix the instance - the rule is: a per-line grammar or classification predicate is
  computed once per parse into a shared array and read from there, never recomputed inside a
  scan. answer_structure.reduce:29 already does this. chat_parser now calls
  highlight_structure.classify in the precompute row loop (:533), again in every inner scan
  (:538), and a third time in the main loop (:561). Measured best-of-10 on a 10,104-line
  tool-heavy transcript: 24.49 ms at dc5ee17 to 36.22 ms at HEAD. parse_chat runs at
  tool_folds.lua:150 on hydrate and every drift re-derive, and eight times across
  chat_respond.lua. The issue's own Done-when commits to no streaming regression and M1 took
  per-chunk reconcile from 3.705 ms to 0.067 ms. Same edit as C1 - build kinds[] once and pass
  it to the shared span helper.
- **BR-46** [Important] `ticked-without-evidence` The revert-must-go-red rule was written and then not applied by the commit that wrote it
  4th finding in family ticked-without-evidence. Do NOT fix the instances. BR-41's remedy did
  land - lessons.md:733-742 states the rule and the gate corollary. In the same commit,
  describe("unterminated tool body (#200 BR-30)") presents two tests as pinning BR-30; against
  b2bf1d5 the file is 17 pass / 1 fail, so chat_parser_tools_spec.lua:485 is green on revert -
  characterization wearing a fix-pin label, unlabelled. Plan line 1338 still ticks
  "sdlc milestone-close M2" while this review is that milestone-close; only line 1352 was
  unticked. Prevalence in this issue: BR-34, BR-41 twice, and these two - five instances, the
  last three after the rule was written. Escalation: a third prose restatement will not hold.
  The rule needs a mechanical gate - a Pinned-by trailer that milestone-close refuses without
  a recorded red-on-revert run, and a close-gate check that no plan step naming
  sdlc milestone-close or sdlc close is ticked at the moment that command runs.

## Open findings

- **BR-4** [Important] Plan Core-concepts entry contradicts the code and the plan's own line 65
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
- **BR-20** [Important] reconcile_exchange is O(number of exchanges) per call on the per-chunk streaming path
- **BR-21** [Important] the drift refusal is logged once per buffer lifetime, not once per buffer state
- **BR-22** [Minor] vim.g.parley_fold_clear_iters is a test instrument written to a global on the per-chunk path
- **BR-23** [Minor] the prepare event's `identified` flag has no consumer and no test
- **BR-24** [Minor] _observer is reset inline rather than in after_each, so a failing assertion leaks it
- **BR-25** [Minor] foldtext hardcodes the four marker prefixes instead of deriving from highlight_structure.patterns
- **BR-26** [Minor] per-chunk reconcile cost is linear in projected-range length, and that axis is unasserted
- **BR-27** [Minor] atlas does not record that the clear transiently forces 'foldenable'
- **BR-28** [Minor] prepare clears the identified span unverified while reconcile refuses to create unverified
- **BR-30** [Critical] `unterminated-fence-degradation` chat_parser's in-body suppression is unbounded, so one unclosed fence swallows the rest of the chat
- **BR-32** [Important] `shadow-consumer-not-derived` atlas/chat/format.md still names tools/serialize.lua as the fence single source
- **BR-35** [Minor] `style-consistency` chat_parser.lua:267 require is unindented in a tab-indented function body
- **BR-36** [Minor] `shadow-consumer-not-derived` chat_parser.lua:457-459 comment still restates the fence grammar the module no longer owns
- **BR-38** [Minor] `purity-claim-unenforced` fence.lua declares itself pure but is absent from the PURE_FILES arch guard
- **BR-39** [Minor] `oracle-derives-from-subject` fold_invariants_spec's oracle derives from the same parse it validates, so segmentation bugs pass
- **BR-43** [Critical] `drift-guard-blinded` The tool-body scan accepts an opener anywhere after the marker, so a closing fence is read as an opening one and a user question ends up folded
- **BR-44** [Important] `shadow-consumer-not-derived` A second in-tool-body tracker was introduced while the plan's Core concepts states none was
- **BR-45** [Important] `redundant-computation` The precompute reclassifies every line two to three times, making parse_chat about 48 percent slower
- **BR-46** [Important] `ticked-without-evidence` The revert-must-go-red rule was written and then not applied by the commit that wrote it
