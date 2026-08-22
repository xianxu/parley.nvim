# Boundary Review — parley.nvim#200 (whole-issue close)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | whole-issue close |
| milestone | — |
| window | 38a6cdd7ba668be2ccfd41034cb8b4a3669e4ead..d017ce758d76b3b451f5ad0207e29a5ddb3d7405 |
| command | sdlc close --issue 200 |
| reviewer | claude |
| timestamp | 2026-08-21T17:49:36-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The shipped code is in good shape and I verified it rather than trusting the record: a 144-combination adversarial sweep over fence/marker shapes (464 depth-0 question rows, real Neovim fold state) found **zero folded questions**, and a 15-chunk streaming simulation through the real `with_exchange_update` seam kept both invariants at every step while an in-body `💬:`/`🤖:` pair inside a ````-fenced result with a nested ``` block stayed content. Lint is 0/0 across 333 files and every fold/fence spec is green. Fifteen prior findings are genuinely addressed this round. What holds this back from SHIP is not the code — it is the net under it and the record on top of it. The raw-text oracle added in the close commit to fix the "harness can't see segmentation bugs" defect filters its subjects with `fence.scan`, **the function under test**: I reverted the depth fix and got `fold_invariants_spec` **14/14 green while `fold_marker_in_prose.md` folds the user question at row 18** — the milestone's own headline symptom, in the fixture written to catch it, undetected. The close commit's evidence says that revert "produces 4 failures"; it produces zero. Separately, the BR-47 cleanup deleted `it("requires the opener immediately after the marker")` and the four replacement scan tests do not replace it — removing adjacency marks a real question as in-body and the *entire* suite stays green. And `answer_structure` now swallows trailing answer prose into the tool fold on two shapes where both the base and M1 got it right.

## 1. Strengths

- **The invariant genuinely holds under adversarial load.** I built 144 two-piece answer combinations from 12 adversarial fragments (markers at depth 1, empty bodies, unclosed fences, nested shorter fences, grammar-rejected info strings) and checked every depth-0 `💬:` against real `foldclosed()`: **0 violations across 464 question rows**. That is the issue's headline invariant, measured independently of the implementor's harness.
- **The streaming path is clean end-to-end.** Feeding a 15-line tool-loop answer chunk-by-chunk through `with_exchange_update` produced `🧠:`@17, `🔧:`@18, `📎:`@22, `📝:`@30 each folded at its own marker, the in-body `💬:`/`🤖:` at 24–25 correctly inside the `📎:` fold, and both real questions unfolded at every one of the 15 steps.
- **`fence.scan` is the right shape** (`lua/parley/fence.lua:119`): one linear pass that establishes depth by *skipping closed blocks* rather than counting, returning both facts so consumers cannot disagree about body extent.
- **BR-45 is fixed on the metric that isn't noise.** `highlight_structure.classify` calls per `parse_chat` are now **1.98/line at HEAD, dc5ee17 and 38a6cdd alike** (10,901 calls over 5,505 lines) — the double/triple classification is gone. Residual wall-clock is +6% best-of-10 vs base, which is `fence.scan`'s own pass, not redundancy.
- **BR-20's scaling axis is measurably flat**: best reconcile with span held constant is 0.0398 / 0.0370 / 0.0349 / 0.0358 ms at 10 / 50 / 200 / 500 exchanges. The changedtick memo does what it claims.
- **The gate corollary was honoured this time** — plan Steps 4 and 6 are unticked, and three tests now carry explicit `Characterization, NOT a fix pin` labels.

## 2. Critical findings

None. No shipped code path violates a stated Spec invariant on input parley itself can produce.

## 3. Important findings

**A. The new raw-text oracle exonerates exactly the rows a `fence.scan` defect corrupts** — `tests/integration/fold_invariants_spec.lua:115-127`.

The oracle selects subjects with `if text:match("^💬:") and not body_rows[row]`, where `body_rows` comes from `fence.scan` — the function it exists to guard. Measured, on `tests/fixtures/fold_marker_in_prose.md`:

```
HEAD              oracle SUBJECT question rows: 6,18,34   EXCLUDED: (none)
depth fix reverted oracle SUBJECT question rows: 6,34     EXCLUDED: 18
                   → row 18 "💬: and a tool call?"  foldclosed = 13
                   → fold_invariants_spec: Success 14  Failed 0
```

This is BR-39's rule re-committed against a new source, by the commit that claimed to close it. Fix: derive the filter from something independent — the fixture rows are known, so list them, or compute in-body rows with a deliberately naive independent scanner. The property to preserve is that the oracle's *subject selection* must not consult the subject.

**B. The one test with teeth for opener-adjacency was deleted and not replaced.** *This is the 2nd finding in family `spec-surgery-loses-tests`.* Do NOT just re-add the test — state the rule: **a spec-inventory diff proves names survived, not properties; when a test is removed, the removing change must name the behavioural property it pinned and show the replacement goes red on the same revert.** `git show 6c0132d:tests/unit/fence_spec.lua` had `requires the opener immediately after the marker`; HEAD does not. Measured at HEAD: patching `fence.scan` to accept an opener anywhere after the marker makes `📎: read id=1 / some prose / ``` / 💬: a real question / ``` ` report `in_tool_body = {3,4}` — a real user question marked as body, which suppresses both `chat_parser`'s classification and `verify_anchors`' guard — and `fold_invariants` 14/14, `chat_parser_tools` 21/21, `fence_spec` 18/18 all stay **green**. Of BR-43's three requirements, only depth (a) has any behavioural pin (`chat_parser_tools_spec`, 1 failure on revert); CommonMark `open_len` (c) is pinned only by `fence_spec`'s own grammar assertions; adjacency (b) is pinned by nothing. The issue Log's "5 tests removed, 4 scan tests added; inventory diffed against HEAD" is accurate about counts and silent about this.

**C. `answer_structure` swallows trailing answer prose into the tool fold — a regression against both the base and M1** (`lua/parley/answer_structure.lua:34-44`). This is BR-52 instance A generalised; measured directly:

| shape | 38a6cdd (base) | dc5ee17 (M1) | HEAD |
|---|---|---|---|
| empty tool body then prose | `tool_result[1..3] text[5..5]` | same | **`tool_result[1..5]`** |
| marker with no adjacent body, later plain block | `tool_result[1..5] text[6..6]` | same | **`tool_result[1..6]`** |
| normal body then prose | `tool_result[1..4] text[6..6]` | same | same ✓ |

On real fold state that is fold `9..13` swallowing "some prose after the empty result" where base gives `9..11`. Cause: `body_close` is reconstructed by walking `body_rows` from `marker + 2`, which yields nothing when the body is empty, so the section falls into the run-to-next-boundary arm. Not reachable from `serialize.render_result` (it always emits a body line), so this needs a hand-edited or truncated transcript — the #203 class. No stated invariant breaks, but prose visibly disappears into a fold.

**D. `verify_anchors` still cannot run without a Neovim global, and the comment added this round says it can.** `lua/parley/fold_projection.lua:76-86` reads "the module stays callable — not merely loadable — without a Neovim global". Measured with the module pre-loaded and `patterns` supplied: `verify_anchors → ok=false, vim/_init_packages.lua:0: attempt to index global 'vim'`, while `verify_starts → ok=true`. The purity test at `fold_projection_spec.lua:31` exercises `verify_starts` and `ranges_within` — the two that pass — and not `verify_anchors`.

**E. The two atlas pages now contradict each other on the rule this milestone owns.** `atlas/chat/parsing.md:20-24` (written in the close commit) says a marker inside "**any other fenced block**" is content; `atlas/providers/tool_use.md:170` says "Ordinary answer prose is a deliberate exception: it stays fence-naive". Both are half-right and neither says which half: tool markers *are* depth-gated, `💬:`/`🤖:` are *not*. Measured: `💬:` inside a plain ` ```text ` block still forks an exchange (3 where 2 is correct) and swallows the following `📝:` into the question content — and across my sweep that shape accounts for **all 14** "marker not folded" cases. `tool_use.md` also still says "bare-word info string (`json`, `lua`)", the grammar `6c0132d` replaced, and still names `chat_parser`'s `tool_fence_len` tracker as what the main loop consults (it consults `in_tool_body[]`/`depth0_marker[]`); `fence.scan` is unmentioned.

**F. The mechanical gate BR-46 escalated to was never filed.** The instances are fixed, but `../ariadne/workshop/issues/` has no issue for a `Pinned-by` trailer or a close-gate tick check, and no peer repo mentions red-on-revert. This is the family's 6th instance across the issue; a seventh prose restatement will not hold it.

## 4. Minor findings

- `lua/parley/tool_folds.lua:353-360` still states the same "same rule as reconcile" paragraph twice; `:351` declares `first_0, last_0` ten lines before its only assignment.
- `lua/parley/tool_folds.lua:256-260` — `owned_span` writes the same return twice.
- `tests/integration/tool_folds_spec.lua:93` — "Contrast the case above, whose fold sits outside every span" points at a test that now asserts the fold **is** cleared.
- `lua/parley/tool_folds.lua:338` — the `%d,%dfold` loop is still unguarded against `E350` while the clear half reasons about it explicitly at `:64-68`.
- `lua/parley/chat_parser.lua:267` — `local fence = require(...)` at column 0 in a tab-indented body; `:456-459` still restates the open/close grammar `fence` owns (and is now wrong about the info string).
- `lua/parley/fence.lua:37` still returns `#ticks, info` under an `@return integer|nil` annotation; no caller reads it.
- `lua/parley/fold_projection.lua:134-135` calls `classify` twice on the same line inside the per-chunk scan, and copies each tool range into a shifted window per verify; `fence.closes:50` matches `^(`+)` twice; `fence.scan`'s `close_of` rescans to EOF per unclosed opener (O(k·n)).
- `prepare_exchange_update` still clears the identified span with no range verification while `reconcile_exchange` refuses to create without it.

## 5. Test coverage notes

- Green here: `fence_spec` 18/18, `fold_projection_spec` 26/26, `answer_structure_spec` 9/9, `chat_parser_tools_spec` 21/21, `exchange_anchors_spec` 12/12, `tools_serialize_spec` 18/18, `tool_folds_spec` 30/30, `fold_invariants_spec` 14/14, `buffer_mutation_spec` 8/8; `make test-spec SPEC=chat/parsing` 54/54 and `SPEC=providers/tool_use` 29/29 — so the traceability wiring for `fence.lua` works.
- `make test` fails here on `git_markdown_source_spec` and `markdown_finder_async_spec`. Verified environmental and unrelated: `git init` under the repo tree returns `cannot copy .../commit-msg.sample: Operation not permitted`, both specs pass in isolation (`git_markdown_source_spec` 11/11), and neither contains `fold` or `fence`. Issue #202 covers it. Not re-litigating; the issue Log's "make test exit 0" should carry the environment qualifier.
- Revert matrix for BR-43's three requirements: depth → 1 unit failure, harness green; CommonMark `open_len` → 2 `fence_spec` failures only; adjacency → **nothing red anywhere**.
- The corpus enumerates 10 tracked transcripts of which 9 are readable (one deleted-but-unstaged in the working tree) plus 4 fixtures; the `>= 8` floor still has slack.

## 6. Architectural notes

- **ARCH-DRY — flag.** The token grammar is genuinely single-sourced and every listed consumer derives from it. The *model* is not: `answer_structure.lua:34-44` reconstructs block extents from `fence.scan`'s derived row set (finding C), and `markers` is computed at `:34` and never consulted — the loop at `:93` still branches on the depth-naive `kinds[i]`, which is why a `📎:` at depth 1 becomes a foldable `tool_result` while `chat_parser.lua:551` calls the identical row `text`. Two consumers of "one grammar" still disagree about the same row. `fence.scan` should return `marker → close_row` plus the depth-0 marker set, and consumers should branch on that.
- **ARCH-PURE — flag.** `fence.lua` is genuinely pure and now enforced in `PURE_FILES`. `fold_projection`'s purity claim is stronger than the code (finding D), and the test picks the functions that satisfy it.
- **ARCH-PURPOSE — flag.** The shadow sweep over *code* consumers is complete. Over *documentation* consumers it has now inverted: the prose restatements drifted so far apart inside one milestone that two atlas pages assert opposite things (finding E). The enforceable substitute BR-48 named — reduce restating sections to a pointer at the source docstring, and register the source module under every atlas key whose page states the rule — is the only version of this that survives the next edit.
- **ARCH-MOCK — pass.** No external binary or service on the production path. `git ls-files` in `fold_invariants_spec.lua:17` remains the only external call, test-only, honestly labelled as a single point of definition rather than a seam, and floored so a missing `git` fails loudly.
- **For upcoming work:** the recurring structural lesson of this issue is that *both* of its guards — `verify_anchors` and the corpus harness — are now written in terms of `fence.scan`. A single defect in that one function blinds the code path and its verifier simultaneously. The next thing built on `fence` should have at least one check that does not consult it.

## 7. Plan revision recommendations

- **Core concepts, `fence` bullet (`:33`)** — "one grammar, three consumers" is four (`fold_projection` joined in M2), and the surface as shipped is `MIN`, `open_len`, `closes`, `longest_run`, `for_content`, `extract_body`, `scan`.
- **Core concepts, `chat_parser` bullet (`:44`)** — still says `in_tool_body[]` is "built from `fence.tool_body`", a function `8b94fde` deleted. Replace with `fence.scan` and state its return contract (row set + marker set) so finding C's reconstruction gap is visible at design level.
- **`## Revisions` stops at M1 round 7.** No entry exists for M1 round 8 (creation ranges must lie inside the identified span), M1 round 9 (the clear forces `'foldenable'`), or **any** of M2 — including the two design changes that define it: `fence.scan` replacing `fence.tool_body`, and the depth-0 requirement. BR-44's Correction is in Core concepts rather than Revisions, which is where a mid-stream design change belongs.
- **Task 11 Step 3 evidence** — record what `traceability.yaml` actually received (`chat/parsing` ✓ this round, plus `chat/exchange_model` and `providers/tool_use`) next to the tick.
- **Non-goals (`:15`)** — reaffirm the answer-prose boundary explicitly, and correct the issue Log line ~1135 and `atlas/chat/parsing.md` which now claim the opposite.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      fold_projection entry fixed; but the fence bullet still says three consumers, the chat_parser bullet still names the deleted fence.tool_body, and Revisions still stop at M1 round 7 with no M2 entry at all.
  - id: BR-6
    disposition: not-addressed
    note: |
      tool_folds.lua:353-360 still states the paragraph twice; :351 still splits the declaration from :361.
  - id: BR-7
    disposition: not-addressed
    note: |
      tool_folds.lua:256-260 unchanged.
  - id: BR-8
    disposition: not-addressed
    note: |
      The wall-clock comment is fixed; tool_folds_spec.lua:93 still says the case above sits outside every span, and that case now asserts the fold IS cleared.
  - id: BR-9
    disposition: not-addressed
    note: |
      Measured with the module preloaded and patterns supplied - verify_anchors errors on vim/_init_packages.lua while verify_starts returns true; the new purity test covers only the two that pass, and the added comment claims the opposite.
  - id: BR-10
    disposition: addressed
    note: |
      desired_folds is no longer computed in prepare; the comment states why.
  - id: BR-11
    disposition: addressed
    note: |
      tool_folds.lua:52 resets _last_clear_iters before every early return.
  - id: BR-12
    disposition: addressed
    note: |
      ranges_within lives in fold_projection and is unit-pinned by five cases at fold_projection_spec.lua:236-262.
  - id: BR-13
    disposition: not-addressed
    note: |
      tool_folds.lua:338 still unguarded while clear_folds_in_span:64-68 reasons about E350 explicitly.
  - id: BR-14
    disposition: addressed
    note: |
      workshop/lessons.md:711 carries the uniq -d audit over it() names.
  - id: BR-15
    disposition: addressed
    note: |
      workshop/issues/000202-make-test-is-unreliable-specs-traverse-and-mutate-a-shared-test-tmp.md filed.
  - id: BR-16
    disposition: addressed
    note: |
      README.md gains the fold-ownership contract including the buffer tail and the outside-every-exchange exemption.
  - id: BR-17
    disposition: not-addressed
    note: |
      fold_invariants_spec.lua:17 unchanged; the corpus floor still mitigates it and this was noting-only.
  - id: BR-18
    disposition: addressed
    note: |
      Every Task 1-5 step is ticked; the only two unticked boxes are the gate steps, correctly.
  - id: BR-20
    disposition: addressed
    note: |
      The changedtick memo landed at dc5ee17; measured flat with span held constant - 0.0398 / 0.0370 / 0.0349 / 0.0358 ms at 10 / 50 / 200 / 500 exchanges. The suggested exchange-count test was not added, which BR-26 already covers.
  - id: BR-21
    disposition: addressed
    note: |
      logged is no longer carried forward (tool_folds.lua:199) and rederived[buf] is dropped on a successful reconcile (:344).
  - id: BR-22
    disposition: addressed
    note: |
      Now a buffer-local b:parley_fold_clear_iters, not a global.
  - id: BR-23
    disposition: addressed
    note: |
      tests/integration/tool_folds_spec.lua:594 asserts identified true then false across a count mismatch.
  - id: BR-24
    disposition: addressed
    note: |
      _observer is reset in after_each alongside _model_provider.
  - id: BR-25
    disposition: addressed
    note: |
      foldtext derives every branch from highlight_structure.patterns and the fallback now announces an unexpected fold.
  - id: BR-26
    disposition: not-addressed
    note: |
      The only scaling test still varies body_lines and asserts clear-loop iterations; nothing pins the covered_lines plus interior-scan axis.
  - id: BR-27
    disposition: addressed
    note: |
      atlas/chat/exchange_model.md:108 records that the clear transiently forces foldenable and restores the operator's value.
  - id: BR-28
    disposition: not-addressed
    note: |
      prepare_exchange_update still clears the identified span with no range verification while reconcile refuses to create without it.
  - id: BR-32
    disposition: addressed
    note: |
      format.md:12 names fence.lua, parsing.md states the depth-0 rule, and traceability chat/parsing lists fence.lua plus fence_spec - though parsing.md's new wording is itself inaccurate, which BR-48 covers.
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 is still at column 0 inside a tab-indented body.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 still restates the open/close grammar and is now also wrong about the info string.
  - id: BR-38
    disposition: addressed
    note: |
      lua/parley/fence.lua is listed in PURE_FILES at tests/arch/buffer_mutation_spec.lua:63 and the spec passes 8/8.
  - id: BR-39
    disposition: not-addressed
    note: |
      The header comment is unchanged, and the raw-text oracle added as the remedy filters its subjects with fence.scan - measured green at 14/14 with the question at fold_marker_in_prose.md:18 folded. See the new finding.
  - id: BR-44
    disposition: addressed
    note: |
      The plan states the rule as an inline Correction and I could not reproduce a divergence at HEAD on the named shape or on three variants; both trackers agree. The Correction belongs in Revisions, which BR-4 covers.
  - id: BR-45
    disposition: addressed
    note: |
      Deterministic metric now identical across trees - 10,901 classify calls over 5,505 lines, 1.98 per line at HEAD, dc5ee17 and 38a6cdd. Residual wall-clock is +6% vs base, which is fence.scan's own pass.
  - id: BR-46
    disposition: not-addressed
    note: |
      The instances are fixed - gate Steps 4 and 6 unticked, three tests labelled characterization - but no peer-repo issue exists in ariadne for the Pinned-by trailer or the close-gate tick check, so the rule-level remedy landed nowhere.
  - id: BR-48
    disposition: not-addressed
    note: |
      atlas/providers/tool_use.md is untouched and now contradicts atlas/chat/parsing.md written in the close commit; it still says bare-word info string and still names tool_fence_len as what the main loop consults.
  - id: BR-49
    disposition: not-addressed
    note: |
      fence.lua:37 still returns two values under an integer-or-nil annotation; no caller reads the second.
  - id: BR-50
    disposition: addressed
    note: |
      The dead body_first assignment is gone.
  - id: BR-51
    disposition: not-addressed
    note: |
      fold_projection.lua:129-135 still copies each range into a shifted window and calls classify twice per line; fence.closes still matches twice; fence.scan's close_of additionally rescans to EOF per unclosed opener.
  - id: BR-52
    disposition: not-addressed
    note: |
      Both instances reproduce, and instance A is now measured as a regression - answer_structure gives tool_result[1..5] where base and M1 give tool_result[1..3] plus text[5..5], swallowing prose into the fold.
  - id: BR-53
    disposition: not-addressed
    note: |
      Still measured at 3 exchanges where 2 is correct, and the record got worse - atlas/chat/parsing.md now asserts the false claim too, contradicting atlas/providers/tool_use.md.
findings:
  - id: new
    severity: Important
    family: oracle-derives-from-subject
    title: |
      The raw-text oracle added to fix the circular harness selects its subjects with the function under test
    detail: |
      This is the 2nd finding in family oracle-derives-from-subject. Do NOT fix only this
      instance - state the rule: an oracle's SUBJECT SELECTION may not consult the artifact
      under test, only its assertion may; a filter computed from the subject exonerates
      exactly the rows a defect corrupts. fold_invariants_spec.lua:115-127 selects question
      rows with `not body_rows[row]` where body_rows comes from fence.scan. Measured on
      tests/fixtures/fold_marker_in_prose.md - at HEAD the oracle's subjects are rows 6,18,34;
      with the depth fix reverted in fence.scan they are 6,34 and row 18 is EXCLUDED as
      in-body, while foldclosed(18) = 13, i.e. the milestone's headline symptom in the fixture
      written to catch it. fold_invariants_spec reports Success 14 Failed 0. The close
      commit's evidence states that reverting the depth fix "produces 4 failures where the
      harness previously reported none"; it produces zero. Prevalence in this issue: 2, the
      second committed by the change that closed the first.
  - id: new
    severity: Important
    family: spec-surgery-loses-tests
    title: |
      The BR-47 cleanup deleted the only test with teeth for opener-adjacency and the four replacements do not cover it
    detail: |
      This is the 2nd finding in family spec-surgery-loses-tests. Do NOT just re-add the test -
      state the rule: a spec-inventory diff proves NAMES survived, not PROPERTIES; a change that
      removes tests must name the behavioural property each pinned and show the replacement goes
      red on the same revert. git show 6c0132d:tests/unit/fence_spec.lua contains
      it("requires the opener immediately after the marker"); HEAD does not, and the four new
      scan tests do not cover it. Measured at HEAD by patching fence.scan to accept an opener
      anywhere after the marker: the input 📎: read id=1 / some prose / ``` / 💬: a real question
      / ``` yields in_tool_body = {3,4}, marking a genuine user question as body - which
      suppresses both chat_parser's classification and verify_anchors' guard - while
      fold_invariants 14/14, chat_parser_tools 21/21 and fence_spec 18/18 all stay green. Of
      BR-43's three requirements only depth has a behavioural pin (1 failure on revert);
      CommonMark open_len is pinned only by fence_spec's own grammar assertions; adjacency by
      nothing. The issue Log's "5 tests removed, 4 scan tests added; inventory diffed against
      HEAD" is accurate about counts and silent about the lost property.
```
