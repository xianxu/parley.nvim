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

---

## Re-review — 2026-08-21T18:21:04-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | whole-issue close |
| milestone | — |
| window | 38a6cdd7ba668be2ccfd41034cb8b4a3669e4ead..e81a944356d154065800db38021df444706a93a1 |
| command | sdlc close --issue 200 |
| reviewer | claude |
| timestamp | 2026-08-21T18:21:04-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both Spec invariants now hold under independent measurement, and the four Important findings that blocked round 10 are genuinely fixed — I verified each by revert rather than by commit message. Reverting the depth rule in `fence.scan` turns `fold_invariants_spec` **RED** at `fold_marker_in_prose.md` (round 10 measured 14/14 green on the same revert, which was BR-54's whole point); reverting opener-adjacency turns `fence_spec` red; BR-52's two shapes both measure correct at HEAD against the M1-close control. My own adversarial sweep — 144 two-fragment combinations, subject selection by a literal backtick tracker that consults nothing from parley — found **0 folded questions across 402 depth-0 question rows**, a 15-step streaming simulation through the real `with_exchange_update` seam held both invariants at every step, and an independent raw sweep over the corpus plus fixtures found **61 depth-0 foldable markers, all folded at their own row**. What keeps this off SHIP is entirely the record: the close-review Log says BR-53 was "Corrected in place", but the retracted claim is still asserted verbatim in the `closed M2` Log line and in `atlas/chat/parsing.md`, where it now contradicts `atlas/providers/tool_use.md` — and I measured it false on both counts it makes. Sixteen prior findings remain open, mostly Minor.

## 1. Strengths

- **`fence.scan` (`lua/parley/fence.lua:120`) is the right shape and now returns the right model.** One linear pass that establishes depth by *skipping* closed blocks rather than counting, returning `marker_row -> {first, last, close}` **and** the depth-0 marker set. Both consumers branch on that model — `answer_structure.lua:89` gates on `markers[i]`, `:95` reads `bodies[i].close`. BR-52's two measured regressions are gone: empty body gives `tool_result[1..3] text[5..5]` (matching the M1 control) where the M2-close commit gave a fold swallowing the prose; a `📎:` inside a plain ` ```text ` block gives `text[3..5]` where M1 and base both gave a foldable `tool_result[3..5]`.
- **The oracle fix has teeth, and it is the fix BR-54 asked for.** `tests/integration/fold_invariants_spec.lua:115-127` now selects subjects with a hand-written backtick tracker. Measured: revert the depth rule → 1 failure (`fold_marker_in_prose.md`) plus `chat_parser_tools` and `fence_spec` each red. Round 10's exact complaint — the harness reporting green while the fixture written to catch the symptom exhibited it — is closed.
- **The opener-adjacency property is pinned again, and verified on the same revert BR-55 named.** Relaxing `fence.scan` to accept an opener anywhere after the marker turns `fence_spec` red (18/1). The rule behind it is recorded at `workshop/lessons.md` ("a spec-inventory diff proves NAMES survived, not PROPERTIES").
- **The streaming path is clean end-to-end.** Feeding a 15-line tool-loop answer chunk by chunk: `🧠:`@9 folded at 9, `🔧:`@10 folded 10..13 (including the CommonMark opener M1's grammar rejected), `📎:`@14 folded 14..21 (swallowing the in-body `💬:`/`🤖:` and a nested shorter fence — correctly), `📝:`@22 folded at 22, both real questions unfolded, at every one of the 15 steps.
- **`atlas/providers/tool_use.md` is the model BR-48 asked for**: it declines to restate the grammar, points at `fence.lua`'s docstrings as the specification, names why (prose cannot derive), and its non-goal sentence is now accurate.
- Lint 0 warnings / 0 errors across 333 files; every fold and fence spec green (`fence` 19, `fold_projection` 26, `answer_structure` 9, `chat_parser_tools` 21, `exchange_anchors` 12, `tools_serialize` 18, `buffer_mutation` 8, `tool_folds` 30, `fold_invariants` 14).

## 2. Critical findings

None. No shipped code path violates a stated Spec invariant on any input I could construct.

## 3. Important findings

**A. BR-53's "Corrected in place" is contradicted by the tree, in the two places the claim actually lives.** The commit message and the close-review Log entry both retract it correctly. But `workshop/issues/000200-user-question-is-folded.md:890` — the durable `closed M2` line — still reads verbatim: *"This also corrects a scope note wrong since M2 began: markers inside ANY fenced block are content, not only inside tool bodies."* And `atlas/chat/parsing.md:17-27`, written in the M2-close commit, asserts the same thing as normative documentation. Measured false on both counts it makes:

```
💬: inside a plain ```text block  → 3 exchanges where 2 is correct
🧠: block + depth-1 💬:           → thinking[1..3]; the depth-1 marker TERMINATED the block
```

`chat_parser.lua:551` gates only `tool_use`/`tool_result` on `depth0_marker`. `atlas/providers/tool_use.md:170` now says the opposite of `atlas/chat/parsing.md` — a reader gets two answers depending which page they open.

**B. BR-48's remedy landed on one page and was violated on another in the same commit.** `atlas/chat/parsing.md` is a *new* hand-maintained restatement of the single-sourced model, written by the commit that adopted "prose cannot derive — point at the docstring." Two further gaps in the same rule: `atlas/chat/format.md` states the fence rule but `chat/format` in `traceability.yaml` lists neither `lua/parley/fence.lua` nor `tests/unit/fence_spec.lua`, so `make test-changed` does not couple them (remedy (ii) is only done for `chat/parsing` and `providers/tool_use`); and `fence.lua:13` — the docstring `providers/tool_use.md` just designated *as the specification* — still says "three consumers" where there are four.

**C. BR-4's plan corrections are half-landed.** Revisions are now current through M2 (good — that half is fixed). But Core concepts line 33 still says *"one grammar, three consumers (`serialize`, `answer_structure`, `chat_parser`)"*, and the `chat_parser` bullet still says `in_tool_body[]` is *"built from `fence.tool_body`"* — a function `8b94fde` deleted. The greppable table is what downstream work reads.

**D. BR-46's mechanical gate is not filed, and a fresh instance shipped this round.** The instances are fixed and the rule *was* applied to this round's own work with real evidence — I confirmed both reverts go red. The Log explicitly declines to file the `sdlc` gate in a peer repo and flags it for the operator instead, which is a defensible call. But finding A above is the seventh instance in this issue, and it is the strongest available argument that prose alone has not held: the same commit that retracted the claim wrote "Corrected in place" while leaving it asserted in two files.

## 4. Minor findings

- `lua/parley/fold_projection.lua:95` — `M._classify` is read at exactly one site and **written at zero** (grep over `lua/` and `tests/`). An injection seam with no producer and no test; it passes every suite while doing nothing.
- `README.md:162-166` — the new fold-ownership paragraph is inserted into the middle of the **In Chat Buffer** keybinding list, so `<C-g>l`, `<C-g>i` and `gf` now render as a second list below a fold discussion. (The pre-existing tool-fold paragraph already split it; this widens the break from 2 lines to 7.)
- BR-9 root cause located: `verify_anchors` still errors under `_G.vim = nil` even with `patterns` supplied and `highlight_structure` preloaded — the require is at **`highlight_structure.lua:58`** (`require("parley.define").is_footnote_line`), inside `classify`, not in `fold_projection`. Making `fold_projection`'s require lazy cannot fix it; the comment at `:88-89` claims callability the dependency chain denies.
- `lua/parley/skills/review/journal.lua:14` still hardcodes `FENCE = "````"` with a comment documenting the exact unsoundness (*"a doc using 4-backtick fences is the rare exception"*) that `fence.for_content` exists to remove. Out of the plan's declared scope, but it is the clearest live counterexample to the rule the milestone establishes.
- `answer_structure` splits a text run at a depth-1 tool marker (`text[1..2] text[3..5]` where one section would do), because the `BOUNDARY[kinds[cursor]]` checks remain depth-naive. Cosmetic — both halves are unfoldable, no fold impact measured.
- Plan `:1340` Step 4 (`sdlc milestone-close --issue 200 --milestone M2`) is unticked although M2 *did* close (Log line 890, `Review-Verdict` trailer on `d017ce7`) — the mirror of the error BR-46 was raised about.
- Issue frontmatter `updated: 2026-08-19` while work ran through 2026-08-21.
- BR-6, BR-7, BR-8, BR-13, BR-17, BR-26, BR-28, BR-35, BR-36, BR-49, BR-51 all still present verbatim; disposed individually below.

## 5. Test coverage notes

- Revert matrix, run in this tree and restored after: depth rule → `fold_invariants` 13/1, `chat_parser_tools` 20/1, `fence_spec` 18/1. Opener adjacency → `fence_spec` 18/1 only; `chat_parser_tools`, `answer_structure`, `fold_projection`, `fold_invariants`, `tool_folds`, `tools_serialize` all stay green. So adjacency is pinned at the grammar level but not at the behavioural level BR-55 measured harm at (a real question marked as body). That satisfies the rule as written; it is worth knowing the pin is one layer above the damage.
- `make test` exits non-zero on `git_markdown_source_spec` and `markdown_finder_async_spec`. Confirmed environmental and unrelated: `git init` under the repo tree returns `cannot copy .../commit-msg.sample: Operation not permitted`, and `grep -c 'fold\|fence'` returns 0 for both files. Rounds 3, 5, 7 and 9 already litigated the mechanism; not reopening it. The close-review Log's unqualified "`make test` exit 0" does not reproduce here.
- The corpus enumerates 13 readable files (4 fixtures + 9 tracked; one transcript is deleted-but-unstaged in the working tree and correctly dropped, with slack against the `>= 8` floor).
- Uncovered: the two Important record defects are not the kind a test catches — but the `chat/format` traceability gap means an edit to `fence.lua` does not re-run anything that would surface `format.md` drifting again.

## 6. Architectural notes

- **ARCH-DRY — flag (B, C).** The token grammar *and* the body model are now genuinely single-sourced, and both consumers branch on the model rather than reconstructing it — that is the real gain of this round and it closed a measured regression. What is not single-sourced is the *description* of the model: three atlas pages plus the module docstring plus the plan all state it by hand, and three of those four are currently wrong or stale. `fold_projection.M._classify` is a second, dead path to the same classification.
- **ARCH-PURE — pass with a caveat.** `fence.lua` is genuinely pure (no `vim` reference at all) and now enforced by `PURE_FILES`. `fold_projection` and `answer_structure` are deterministic and unit-tested without mocks; `covered_lines` keeps the buffer read in the shell. The caveat is the purity *claim* at `fold_projection.lua:88-89`, which the `highlight_structure` → `parley.define` require chain falsifies.
- **ARCH-PURPOSE — pass on the code, flag on the record.** The shadow sweep over code consumers is complete and each derives: `serialize` (writer + both readers), `answer_structure`, `chat_parser` (precompute + `cb_state`), `fold_projection`. The issue's stated purpose is delivered and I verified it independently on both invariants rather than accepting the harness's word. The deferred consumers are the prose ones, and a milestone whose whole subject is "one source, every consumer derives" ending with two atlas pages asserting opposite things is the finding.
- **ARCH-MOCK — pass.** No external binary or service on the production fold path. `git ls-files` in `fold_invariants_spec.lua:17` is test-only, honestly labelled as a single point of definition rather than a seam, and floored so a missing `git` fails loudly. `_model_provider` / `_observer` are real in-process seams the tests drive (I used both).
- **For upcoming work:** the recurring structural risk is unchanged and now sharper — the code path (`chat_parser`, `answer_structure`, `fold_projection`) and one of its two verifiers both route through `fence.scan`. The raw-text oracle added this round is the only check that does not, which is exactly why it is the one that caught the depth revert. Anything built on `fence` should keep at least one verifier that does not consult it.

## 7. Plan revision recommendations

- **Core concepts, `fence` bullet (`:33`)** — "one grammar, three consumers" → four (`fold_projection` joined in M2), and list `extract_body` / `scan` / `body_rows` alongside `open_len` / `closes` / `for_content`.
- **Core concepts, `chat_parser` bullet (`:44`)** — replace `fence.tool_body` (deleted in `8b94fde`) with `fence.scan`, and state its return contract (block extents **plus** the depth-0 marker set) so the model/derived-set distinction BR-52 turned on is visible at design level.
- **New `## Revisions` entry** recording that the *scope* correction claimed at issue Log `:890` was itself wrong and is retracted: only tool markers are depth-gated; a `💬:`/`📝:`/`🧠:` inside a plain fenced block is still structural, which is what the Non-goal at `:15` already says and what the code, the spec and `atlas/providers/tool_use.md` all agree on.
- **Tick Step 4** (`sdlc milestone-close --issue 200 --milestone M2`) with its evidence — that gate did run (`d017ce7`, `Review-Verdict: FIX-THEN-SHIP`, Log line 890) and the plan now under-claims it.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      Revisions are now current through M2 — that half is fixed. But Core concepts line 33 still says three consumers where there are four, and the chat_parser bullet still names fence.tool_body, deleted in 8b94fde.
  - id: BR-6
    disposition: not-addressed
    note: |
      tool_folds.lua:353 and :357 still state the same "same rule as reconcile" paragraph twice.
  - id: BR-7
    disposition: not-addressed
    note: |
      owned_span still writes the identical exchange_anchors.span return on both branches.
  - id: BR-8
    disposition: not-addressed
    note: |
      tool_folds_spec.lua:93 still says "Contrast the case above, whose fold sits outside every span"; the case above (:56) asserts foldclosed(11) == -1, i.e. that the fold IS cleared.
  - id: BR-9
    disposition: not-addressed
    note: |
      Measured with highlight_structure preloaded and patterns supplied - verify_starts and ranges_within return true, verify_anchors errors. Traceback locates the require at highlight_structure.lua:58 (parley.define) inside classify, not in fold_projection, so making fold_projection's require lazy cannot fix it and the :88-89 comment claims the opposite.
  - id: BR-13
    disposition: not-addressed
    note: |
      tool_folds.lua:338 still unguarded against E350 while clear_folds_in_span reasons about it explicitly.
  - id: BR-17
    disposition: not-addressed
    note: |
      fold_invariants_spec.lua:17 unchanged; the corpus floor still mitigates it and this was noting-only.
  - id: BR-26
    disposition: not-addressed
    note: |
      The scaling test still varies body_lines and asserts clear-loop iterations; the covered_lines plus interior-scan axis remains unasserted.
  - id: BR-28
    disposition: not-addressed
    note: |
      prepare_exchange_update still clears the identified span with no range verification while reconcile refuses to create without it.
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 is still at column 0 inside a tab-indented body.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 still restates the open/close grammar fence.lua owns, and is still wrong about the info string.
  - id: BR-39
    disposition: addressed
    note: |
      Superseded by a stronger remedy than the comment asked for - a second oracle that does validate segmentation, and I verified it goes red on the depth revert. The RAW-TEXT ORACLE block states the model-derived half's limit in the terms the finding asked for.
  - id: BR-46
    disposition: not-addressed
    note: |
      The rule was genuinely applied to this round's own work - I confirmed both the depth revert and the adjacency relaxation go red - but no mechanical gate exists and no ariadne issue was filed (grep over ../ariadne/workshop for Pinned-by / red-on-revert returns nothing). The Log declines to file it unilaterally and flags it for the operator, which is defensible; recording that a seventh instance shipped this round (Important A) as the escalation evidence.
  - id: BR-48
    disposition: not-addressed
    note: |
      Remedy (i) landed on atlas/providers/tool_use.md and is a good model. But atlas/chat/parsing.md is a NEW hand-maintained restatement written by the same commit and is measurably false; remedy (ii) is incomplete for chat/format, which states the rule but registers neither fence.lua nor fence_spec.lua in traceability.yaml; and fence.lua:13 - the docstring that page just designated as the specification - still says three consumers.
  - id: BR-49
    disposition: not-addressed
    note: |
      fence.lua:37 still returns "#ticks, info" under an "@return integer|nil" annotation at :32; no caller reads the second value.
  - id: BR-51
    disposition: not-addressed
    note: |
      fold_projection.lua:129-133 still copies each tool range into a shifted window per verify; fence.closes:50 still matches twice; fence.scan's close_of still rescans to EOF per unclosed opener.
  - id: BR-52
    disposition: addressed
    note: |
      Both instances measured fixed against the M1-close control. Empty body now gives tool_result[1..3] text[5..5] where d017ce7 gave a fold swallowing the prose; a depth-1 tool marker now gives text[3..5] where dc5ee17 and 38a6cdd both gave a foldable tool_result[3..5]. answer_structure branches on markers[i] and reads bodies[i].close.
  - id: BR-53
    disposition: not-addressed
    note: |
      Commit message and close-review Log entry are corrected, but the claim persists verbatim at issue Log :890 (the closed M2 line) and in atlas/chat/parsing.md:17-27, which now contradicts atlas/providers/tool_use.md:170. Measured false: a 💬: in a plain ```text block still forks (3 where 2 is correct) and still terminates a 🧠: block. The Log's "Corrected in place" is itself the defect.
  - id: BR-54
    disposition: addressed
    note: |
      Verified by revert, not by commit message - the oracle's subject selection is now a literal backtick tracker, and reverting the depth rule in fence.scan turns fold_invariants_spec RED at fold_marker_in_prose.md where round 10 measured 14/14 green on the same revert.
  - id: BR-55
    disposition: addressed
    note: |
      Test restored AND verified red on the same revert - relaxing fence.scan to accept an opener anywhere after the marker turns fence_spec 18/1. The rule is recorded in lessons.md. Worth knowing the pin sits at the grammar layer; no behavioural spec goes red on that revert.
findings:
  - id: new
    severity: Minor
    family: failure-fallback-misgated
    title: |
      fold_projection.M._classify is an injection seam read at one site and written at zero
    detail: |
      This is the 3rd finding in family failure-fallback-misgated. Earlier rounds fixed
      instances (BR-29 fired on the wrong input, BR-47 fired on none). Do NOT fix this
      instance - the rule is already stated and covers it: a seam or degradation path is
      real only when a producer reaches it AND a test drives it; a field set at zero call
      sites passes every suite while doing nothing and reads as extensibility. What is
      missing is enforcement, and here it is mechanisable: an arch test over lua/ that
      flags any M._<name> read in a module but assigned nowhere in lua/ or tests/ would
      catch all three. Measured: fold_projection.lua:95 reads M._classify; grep over lua/
      and tests/ finds no writer (cliproxy.lua:127 sets its own unrelated M._classify).
      Prevalence in this issue: 3.
  - id: new
    severity: Minor
    family: docs-structure-drift
    title: |
      The README fold-ownership paragraph is inserted into the middle of the keybinding list
    detail: |
      README.md:162-166. The In Chat Buffer list runs to :158, is interrupted by the
      tool-fold-toggle prose, and now by a five-line fold-ownership paragraph, after which
      three more list items follow (<C-g>l, <C-g>i, gf). Rendered, those three read as
      belonging to the fold discussion rather than to the keybinding list. The
      interruption is pre-existing but this widens it from two lines to seven; move the
      paragraph below the list or above the In Chat Buffer heading.
```

---

## Re-review — 2026-08-21T18:31:55-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | whole-issue close |
| milestone | — |
| window | 38a6cdd7ba668be2ccfd41034cb8b4a3669e4ead..d55671addc3020275a9505276c0968bc86730418 |
| command | sdlc close --issue 200 |
| reviewer | claude |
| timestamp | 2026-08-21T18:31:55-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

All checks are done. Here is the review.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fold/fence work is in good shape and I verified it rather than trusting the record: a 144-combination adversarial sweep over 12 answer fragments checked 432 real-question rows against live Neovim fold state and found violations in exactly **one** shape — the one already deferred to issue 203 — with `fence.scan`'s depth rule, `answer_structure`'s `markers[i]`/`bodies[i].close` branching, and the empty-body case all measurably correct against the pre-#200 control. All 9 fold/fence specs pass (129 tests), lint is 0/0 across 333 files, `make test` fails only on the two known `git init` specs. Two facts hold this back from SHIP. First, **this round reviews a tree that is byte-identical, in every `lua/`, `tests/`, `atlas/` and `README.md` file, to the one round 11 reviewed** — the only commit since is a one-line plan edit — so all 18 open findings are `not-addressed` by construction, and I re-measured each rather than assuming. Second, the deferral to issue 203 was granted on an understated premise: I measured that on that shape a **user question is folded** at HEAD (`foldclosed(13) = 9`) where both `38a6cdd` (pre-issue) and `dc5ee17` (M1 close) leave it unfolded — i.e. the milestone introduced a new way to fold a user question, the symptom this issue is named for, and neither the issue Log nor issue 203 records that. The deferral may still be the right call; it should be re-made with that measurement in hand.

## 1. Strengths

- **`fence.scan` (`lua/parley/fence.lua:120`) holds up under independent adversarial load.** 144 two-fragment answers built from rejected-info openers, depth-1 markers, empty bodies, nested shorter fences and bare fence pairs → 432 real-question rows checked on real `foldclosed()`; 0 violations outside the deferred shape.
- **BR-52's fix is real, verified against the M1 control.** Empty tool body: `answer_structure` now yields `tool_result[1..3]` + `text[5..5]` where `d017ce7` swallowed the prose. Depth-1 tool marker: `text` where `dc5ee17` and `38a6cdd` both emitted a foldable `tool_result`. Branching on `markers[i]` and reading `bodies[i].close` is the right shape — return the model, not a derived set.
- **The raw-text oracle in `tests/integration/fold_invariants_spec.lua:115` is genuinely independent.** Its subject filter is a literal backtick-run tracker that consults nothing under test — the correct remedy for BR-54, not a restatement of it.
- **The deferral is properly filed.** `workshop/issues/000203-*.md` exists with the three failed heuristics, and `chat_parser_tools_spec.lua:537` carries a `pending()` case pointing at it. That is better hygiene than most deferrals get.
- **Green where it counts:** `fence_spec` 19/19, `fold_projection_spec` 26/26, `answer_structure_spec` 9/9, `chat_parser_tools_spec` 21/21, `exchange_anchors_spec` 12/12, `tools_serialize_spec` 18/18, `tool_folds_spec` 30/30, `fold_invariants_spec` 14/14, `buffer_mutation_spec` 8/8.

## 2. Critical findings

None.

## 3. Important findings

**A. (new) The issue-203 deferral record understates its consequence, and the understatement is a regression against the pre-issue baseline.**

*This is the 2nd finding in family `unterminated-fence-degradation`.* Do NOT fix this instance — the operator already deferred it. The rule that covers both: **a deferral is only as good as the consequence it records; when a defect is deferred, the record must state its worst measured consequence against the pre-change baseline, in the vocabulary of the issue's own invariants — otherwise the deferral is granted on a premise the reviewer supplied and the operator never saw.**

Measured, same buffer, four revisions, real fold state after `hydrate_window` + `zM`:

```
📎: read id=1 / ``` / never closed / (blank) / 💬: real question 2 / ... / 🔧: read id=1 / ```json ...

38a6cdd (pre-#200)  row 13  foldclosed = -1
dc5ee17 (M1 close)  row 13  foldclosed = -1
d017ce7 (M2 close)  row 13  foldclosed =  9   <<< question folded
HEAD                row 13  foldclosed =  9   <<< question folded
```

`fence.scan`'s `close_of` searches to end-of-buffer, so the unclosed opener at row 10 binds to the *next* block's closer at row 19; `chat_parser` reclassifies row 13 as text, `verify_anchors` suppresses its own user-pattern guard over the "body" rows, and the `📎:` fold spans 9..19 with the question inside it. What the record says instead: `workshop/plans/000200-fold-reconciliation-plan.md` ("Unreachable from anything parley writes"), the issue Log ("Current behaviour: 2 exchanges, where M1 gave 3"), and issue 203's Problem section ("the rest of the chat collapses into one exchange… the folds go with it"). All three describe lost exchanges and lost folds; none says a user question ends up folded, and none says it is a regression against `38a6cdd`.

Reachability is also broader than "hand-edited, truncated, or pasted": the shape needs only a `📎:`/`🔧:` at column 0 in prose followed by a fenced block whose closer the model omits — which is ordinary LLM output, not a corrupt file. Correct issue 203's Problem and Done-when to name the fold consequence and the baseline, and correct the plan's and Log's one-line characterisation.

**B. BR-53 — the false claim is now in two more places than when it was raised.** Measured at HEAD: a `💬:` inside a plain ` ```text ` block still forks (3 exchanges where 2 is correct), and the following `📝:` is swallowed into the question content and **not folded** (`foldclosed(13) = -1`), breaking the Spec's "`📝:` blocks are always folded". `atlas/chat/parsing.md:24-27` asserts markers inside "**any other fenced block**" are content; `atlas/providers/tool_use.md:171-173` asserts the opposite and is the correct one. The issue Log at `:890` — the archived `closed M2` line — still reads "markers inside ANY fenced block are content, not only inside tool bodies." Two atlas pages that contradict each other is the worst possible resting state for a close.

**C. BR-48 remedy (ii) is still incomplete, and the designated specification is stale.** `atlas/chat/format.md` states the fence rule and points at `lua/parley/fence.lua`, but `chat/format` in `atlas/traceability.yaml` registers neither `fence.lua` nor `fence_spec.lua`, so `make test-changed` does not couple them. `chat/exchange_model` lists `fence.lua` without `fence_spec.lua`. And `fence.lua:13` — the docstring `tool_use.md:152-153` designates as *the* specification — still says "One source, three consumers" where there are four.

**D. BR-4 — `d55671a` fixed one third of it.** The `fold_projection` bullet now lists `ranges_within`; Revisions are current through M2. Still wrong: line 33 "one grammar, three consumers (`serialize`, `answer_structure`, `chat_parser`)" omits `fold_projection`; line 44 names `fence.tool_body`, deleted in `8b94fde`; line 32's stated surface omits `scan`, `body_rows`, `extract_body`, `longest_run`, `MIN`.

**E. BR-46 — the escalation landed nowhere.** The instances are clean (both gate steps unticked, characterization tests labelled), but `grep` over `../ariadne/workshop/issues/` for `Pinned-by` / red-on-revert returns nothing, and there is no ariadne issue for the mechanical gate. Seven instances across this issue with no enforcement is the definition of a rule that will not hold.

## 4. Minor findings

- **BR-9** — measured with `highlight_structure` preloaded and `patterns` supplied: `verify_starts` → true, `ranges_within` → true, `verify_anchors` → `vim/_init_packages.lua:0: attempt to index global 'vim'`. Traceback locates the `require` at `highlight_structure.lua:58` *inside* `classify`, so `fold_projection`'s lazy require cannot fix it and the comment at `:88-89` ("stays callable — not merely loadable — without a Neovim global") claims the opposite of what runs.
- **BR-56** — `fold_projection.lua:95` reads `M._classify`; grep over `lua/` and `tests/` finds no writer (`cliproxy.lua:127` is unrelated).
- **BR-6** — `tool_folds.lua:353-360` states the same paragraph twice; `:351` declares `first_0, last_0` ten lines before `:361`.
- **BR-7** — `tool_folds.lua:265` and `:267` are the identical return.
- **BR-8** — `tool_folds_spec.lua:94` says "Contrast the case above, whose fold sits outside every span"; that case (`:56-71`) asserts `foldclosed(11) == -1`.
- **BR-13** — `tool_folds.lua:338` `%d,%dfold` unguarded against E350 while `clear_folds_in_span:68-71` reasons about it explicitly.
- **BR-28** — `prepare_exchange_update:361-371` clears the identified span with no range verification; `reconcile_exchange` refuses to create without it.
- **BR-35** — `chat_parser.lua:267` at column 0 in a tab-indented body. **BR-36** — `:456-459` restates the grammar and is wrong about the info string.
- **BR-49** — `fence.lua:37` returns `#ticks, info` under `@return integer|nil` at `:32`; no caller reads it.
- **BR-51** — `fold_projection.lua:129-132` copies each tool range into a shifted window per verify; `fence.closes:50` matches twice; `scan`'s `close_of` rescans to EOF per unclosed opener.
- **BR-26** — the only scaling test varies `body_lines` and asserts clear-loop iterations; the `covered_lines` + interior-scan axis is unasserted. **BR-17** — `fold_invariants_spec.lua:17` shells `git ls-files`, floored, noting-only.
- **BR-57** — `README.md:162-166` still splits the In-Chat-Buffer list.

## 5. Test coverage notes

- `make test` exits 2 on `git_markdown_source_spec` and `markdown_finder_async_spec`, both at `git init … → 128, cannot copy commit-msg.sample: Operation not permitted` under `.test-tmp`. Neither contains `fold` or `fence`; issue 202 covers it. The issue Log's "make test exit 0 on a clean scratch dir" is not reproducible here — keep the environment qualifier.
- **Neither oracle in `fold_invariants_spec` can see finding A's shape.** The model-derived half never gets the swallowed question as a subject, and the raw-text half — deliberately crude — sets `depth = 1` on the unclosed opener and so *excludes* rows 11..18 too. BR-54's remedy is independent of `fence.scan` but shares its blind spot for unclosed fences. No fixture contains an unclosed depth-0 fence after a tool marker, so nothing in the suite would go red if that shape got worse.
- Round 11's addressed claims re-verified independently, not from commit messages: the empty-body and depth-1-marker segmentations (BR-52) both differ from the `d017ce7`/`dc5ee17` controls in the direction claimed.

## 6. Architectural notes

- **ARCH-DRY — pass, with named residue.** One token grammar, and the shadow sweep over code consumers is complete: `serialize` (writer + both readers), `answer_structure`, `chat_parser`, `fold_projection` all derive from `parley.fence`. Residue is declared rather than hidden: two in-body trackers in `chat_parser` (plan Correction BR-44) and the grammar restated in prose at `chat_parser.lua:456-459` and `fence.lua:13`.
- **ARCH-PURE — flag.** `fence`, `fold_projection`, `answer_structure` and `chat_parser` all contain zero `vim.api`/`vim.cmd`/`vim.schedule` — the substance holds. Two gaps: `verify_anchors` is not callable without a `vim` global despite a comment asserting it is (BR-9), and of the four modules the plan classifies PURE only `fence.lua` is registered in `PURE_FILES` (`tests/arch/buffer_mutation_spec.lua:62`), so three purity claims remain documentation. Registering a module in `PURE_FILES` in the same change that declares it PURE is the mechanisable version of that rule.
- **ARCH-PURPOSE — flag.** Over code, the sweep is done. Over documentation it has inverted: `atlas/chat/parsing.md` is a *new* hand-maintained restatement, written by the closing commit, that is measurably false and contradicts the page BR-48 held up as the model. And the purpose itself — "user questions should not be folded" — is not fully delivered: finding A shows a shape where a question is folded at HEAD and was not at `38a6cdd`. That it is deferred is legitimate; that the deferral record does not say so is not.
- **ARCH-MOCK — pass.** No external binary or service on the production fold path. `git ls-files` in `fold_invariants_spec.lua:17` is test-only, honestly labelled as a single point of definition rather than a seam, and floored at `#corpus >= 8` so a missing `git` fails loudly.
- **For upcoming work:** both of this issue's guards — `verify_anchors` and the corpus harness — are now expressed in terms of fence depth, and both go blind on the same input class (unclosed opener). Whatever issue 203 builds should carry one check that does not depend on fence state at all.

## 7. Plan revision recommendations

- **Core concepts, `fence` bullet (`:32-33`)** — "one grammar, three consumers" → four (`fold_projection` joined in M2); list the shipped surface (`MIN`, `open_len`, `closes`, `longest_run`, `for_content`, `extract_body`, `scan`, `body_rows`).
- **Core concepts, `chat_parser` bullet (`:44`)** — `in_tool_body[]` is built from `fence.scan`, not `fence.tool_body` (deleted in `8b94fde`). State `scan`'s return contract here so the empty-body lossiness BR-52 hit is visible at design level. The issue's own `## Plan` line still reads "the main loop consults it — no second tracker", which the plan's Correction (BR-44) contradicts; reconcile the two.
- **New `## Revisions` entry — the issue-203 deferral is recorded with the wrong consequence.** Replace "Unreachable from anything parley writes" with the measurement: at HEAD the shape folds a user question (`foldclosed(13) = 9`) where `38a6cdd` and `dc5ee17` give `-1`, and it is producible by an LLM omitting a closing fence, not only by a hand-edited file. Mirror it into issue 203's Problem and Done-when.
- **Non-goals (`:15`)** — reaffirm the answer-prose boundary, and fix `atlas/chat/parsing.md:24-27` and the issue Log's `closed M2` line, which currently claim the opposite.

```findings
dispose:
  - id: BR-4
    disposition: not-addressed
    note: |
      d55671a added ranges_within to the fold_projection bullet; line 33 still says three consumers where there are four, and line 44 still names fence.tool_body, deleted in 8b94fde.
  - id: BR-6
    disposition: not-addressed
    note: |
      tool_folds.lua:353-360 still states the same paragraph twice; :351 still declares first_0/last_0 ten lines before its only assignment at :361.
  - id: BR-7
    disposition: not-addressed
    note: |
      tool_folds.lua:265 and :267 are still the identical exchange_anchors.span return on both branches.
  - id: BR-8
    disposition: not-addressed
    note: |
      tool_folds_spec.lua:94 still says the case above sits outside every span; that case at :56-71 asserts foldclosed(11) == -1, i.e. that the fold IS cleared.
  - id: BR-9
    disposition: not-addressed
    note: |
      Re-measured with highlight_structure preloaded and patterns supplied - verify_starts and ranges_within return true, verify_anchors errors on a nil vim global. Traceback puts the require inside highlight_structure.classify at :58, so the lazy require cannot fix it and the comment at :88-89 asserts the opposite of what runs.
  - id: BR-13
    disposition: not-addressed
    note: |
      tool_folds.lua:338 still unguarded against E350 while clear_folds_in_span:68-71 reasons about it explicitly.
  - id: BR-17
    disposition: not-addressed
    note: |
      fold_invariants_spec.lua:17 unchanged; the corpus floor still mitigates it and this was noting-only.
  - id: BR-26
    disposition: not-addressed
    note: |
      The only scaling test still varies body_lines and asserts clear-loop iterations; the covered_lines plus interior-scan axis remains unasserted.
  - id: BR-28
    disposition: not-addressed
    note: |
      prepare_exchange_update:361-371 still clears the identified span with no range verification while reconcile refuses to create without it.
  - id: BR-35
    disposition: not-addressed
    note: |
      chat_parser.lua:267 is still at column 0 inside a tab-indented body; verified byte-wise.
  - id: BR-36
    disposition: not-addressed
    note: |
      chat_parser.lua:456-459 still restates the open/close grammar fence.lua owns and is still wrong about the info string.
  - id: BR-46
    disposition: not-addressed
    note: |
      Instances remain clean - both gate steps unticked, characterization tests labelled - but grep over ../ariadne/workshop/issues for Pinned-by or red-on-revert returns nothing and no peer issue was filed, so the rule-level remedy still lands nowhere.
  - id: BR-48
    disposition: not-addressed
    note: |
      Remedy (i) holds on atlas/providers/tool_use.md. Remedy (ii) does not - chat/format states the rule but registers neither fence.lua nor fence_spec.lua in traceability.yaml, chat/exchange_model omits fence_spec.lua, and fence.lua:13, the docstring that page designates as the specification, still says three consumers.
  - id: BR-49
    disposition: not-addressed
    note: |
      fence.lua:37 still returns two values under an @return integer|nil annotation at :32; no caller reads the second.
  - id: BR-51
    disposition: not-addressed
    note: |
      fold_projection.lua:129-132 still copies each tool range into a shifted window per verify; fence.closes:50 still matches twice; fence.scan's close_of still rescans to EOF per unclosed opener.
  - id: BR-53
    disposition: not-addressed
    note: |
      Re-measured on real fold state - a question marker in a plain text-fenced block still forks (3 exchanges where 2 is correct) and the following summary marker is swallowed into the question content and left unfolded, foldclosed = -1. The claim persists verbatim at issue Log :890 and at atlas/chat/parsing.md:24-27, which contradicts atlas/providers/tool_use.md:171-173.
  - id: BR-56
    disposition: not-addressed
    note: |
      fold_projection.lua:95 still reads M._classify; grep over lua/ and tests/ finds no writer, and no arch test flags the pattern.
  - id: BR-57
    disposition: not-addressed
    note: |
      README.md:162-166 still splits the In Chat Buffer list, with three keybinding items following the fold-ownership paragraph.
findings:
  - id: new
    severity: Important
    family: unterminated-fence-degradation
    title: |
      The deferral to issue 203 was granted on an understated premise - the deferred shape folds a user question, and that is a regression against the pre-issue baseline
    detail: |
      This is the 2nd finding in family unterminated-fence-degradation. Earlier rounds fixed
      instances. Do NOT fix this instance - the operator already deferred it. State the rule
      instead: a deferral is only as good as the consequence it records; when a defect is
      deferred, the record must state its worst MEASURED consequence against the pre-change
      baseline, in the vocabulary of the issue's own invariants, or the deferral is granted on
      a premise the operator never saw. Measured on real Neovim fold state, same buffer, after
      hydrate_window plus zM, for the shape a tool marker followed by an unclosed opener
      followed by a later block - question row 13 foldclosed is -1 at 38a6cdd (pre-issue) and
      -1 at dc5ee17 (M1 close), but 9 at d017ce7 and at HEAD. So the milestone introduced a new
      way to fold a user question, which is the symptom this issue is named for. What the record
      says instead - plan Revisions "Unreachable from anything parley writes", issue Log "2
      exchanges, where M1 gave 3", issue 203 Problem "the rest of the chat collapses into one
      exchange ... the folds go with it" - describes lost exchanges and lost folds only; none
      names the fold consequence and none names the baseline regression. Reachability is also
      broader than the recorded "hand-edited, truncated, or pasted": the shape needs only a
      tool marker at column 0 in prose followed by a fenced block whose closer the model omits,
      which is ordinary LLM output. An independent 144-combination sweep over 432 real-question
      rows found violations in this shape and no other. Neither oracle in fold_invariants_spec
      can see it - the raw-text tracker sets depth 1 on the unclosed opener and excludes exactly
      those rows - so nothing in the suite would go red if it got worse.
```
