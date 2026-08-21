# Boundary Review — parley.nvim#200 (milestone M1)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 38a6cdd7ba668be2ccfd41034cb8b4a3669e4ead^..HEAD |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T15:49:13-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The reconciler rewrite is well-built where it was verified: `verify_anchors` is genuinely pure, the interior scan closes PQ-4, the drift re-derive heals rather than merely refusing, and the fold-to-fold VimL clear is both faster than the pre-#200 baseline and correct on straddling/nested folds (I probed all of these). What blocks SHIP is an asymmetry: the diff verifies what it **creates** and not what it **destroys**. `ranges_fit` checks only the projected fold ranges; the span `first_0..last_0` handed to `clear_folds_in_span` comes from the same possibly-stale model and is never checked — and when an exchange has no foldable block, `ranges` is empty and `verify_anchors({}, …)` returns `true` vacuously, so the drift branch never even runs. I reproduced a drifted reconcile of exchange 1 deleting exchange 2's `📎:` fold and never recreating it; because `hydrate_window` latches on `initialized[buf][win]`, that fold is gone for the session — the same persistence signature #200 exists to eliminate, now on the "always folded" invariant instead of the "never fold a question" one. This is a regression the diff introduces: the old `delete_projected_folds` could only ever `zd` at projected start rows, so it could not reach a neighbour's fold.

## 1. Strengths

- **`fold_projection.verify_anchors` (`lua/parley/fold_projection.lua:43`) is genuinely pure.** The caller reads the buffer once and hands in a row→text map; the "loads without a Neovim global" test still passes. Good `ARCH-PURE` shape, and the interior scan is the right answer to PQ-4.
- **The direct `user_pattern` match instead of full `classify` is sound, not a shortcut.** I checked every earlier branch in `highlight_structure.classify` (`:57-71`): footnote, `=== x ===`, `^%s*```` and both reasoning patterns are all unreachable for a line starting with the user prefix at column 0, so there are no false negatives. The comment at `:53-59` justifies it correctly.
- **`clear_folds_in_span` is correct on the hard fold shapes.** I probed a fold straddling the span start (1–10 vs span 3–41), two folds inside, one nested, and one outside: all in-span folds gone, the outside fold and the projected fold intact, cursor restored. The `s:guard` bound is real — I confirmed each `nvim_exec2` gets a *fresh* script scope (so `s:` cannot leak) and that 20 000 calls add zero entries to `:scriptnames`.
- **The drift test heals rather than refuses** (`tests/integration/tool_folds_spec.lua:117-152`) — asserting the real `📎:` folds after re-derive is what makes it a fix and not a mute. It also covers the `default_model_provider` scope bug described in the Log.
- **Removing the planned memo was the right call and the reasoning holds.** Verification proves the *model* matches the buffer, not which folds exist; short-circuiting would have let an externally-added fold survive the span it was supposed to own.

## 2. Critical findings

**C1 — The span that gets cleared is never verified; a drifted reconcile permanently deletes a neighbouring exchange's tool fold.**
`lua/parley/tool_folds.lua:137` / `:139` / `:155` (and `:169`/`:173` in `prepare_exchange_update`) — `ARCH-PURPOSE`.

`ranges_fit` (`:105-111`) validates only the ranges that will be *created*. `first_0, last_0` — the input to the destructive `clear_folds_in_span` — is read from the same model and never checked. With `ranges == {}`, `verify_anchors` returns `true` vacuously, so no drift is detected and no re-derive happens; the stale span is cleared as-is.

Failure scenario (reproduced): exchange 1 = question + agent_header + 12 lines of prose (no foldable block); exchange 2 has a `📎:` fold. Build the model, then mutate the buffer without `with_exchange_update` (delete 10 prose lines), then reconcile exchange 1. Stale span `5..20` now covers exchange 2's `📎:` at row 16. Measured before/after:

```
after hydrate: 📎 line 27 foldclosed=27
exchange1 span (0-based): 5 20     exchange2 span (0-based): 22 29
RESULT: 📎 at line 17 -> foldclosed=-1 (want 17)
```

The fold is destroyed and nothing recreates it — `reconcile_exchange(…, 1)` creates nothing, and `hydrate_window` will not re-run. This breaks the Spec's second invariant ("`🔧:`, `📎:`, `📝:` and `🧠:` blocks are always folded") for the rest of the session. Note the same hole exists even with non-empty `ranges`: `last_0` runs past the last fold range to `last_nonempty_block_end`, so end-drift confined to trailing prose leaves every range verifying while the span overshoots.

Fix sketch — verify the span in the same pure module, in the same drift check:

```lua
-- fold_projection.lua, beside verify_anchors
--- The span an exchange owns must anchor on its own question and contain no
--- other. Drift that leaves the fold ranges intact can still overshoot the
--- span into the next exchange, where the clear destroys folds we want.
function M.verify_span(first_0, last_0, lines, patterns)
    patterns = patterns or require("parley.highlight_structure").patterns()
    if lines[first_0] == nil or not lines[first_0]:match(patterns.user_pattern) then
        return false
    end
    for row = first_0 + 1, last_0 do
        local line = lines[row]
        if line == nil or line:match(patterns.user_pattern) then return false end
    end
    return true
end
```

and in `reconcile_exchange`, fold it into the existing gate (reading the span rows once, alongside `covered_lines`):

```lua
if not (ranges_fit(buf, ranges, patterns) and span_fits(buf, first_0, last_0, patterns)) then
```

applying the same check to `prepare_exchange_update` before it clears. I validated both halves against the whole tracked corpus: **0 spurious interior hits and 0 exchanges whose span anchor is not a user line** across 46 exchanges — so neither half causes false drift on real transcripts. Regression test: the probe above, asserting the neighbour's `📎:` still reports `foldclosed == its own row` after reconciling the drifted exchange.

## 3. Important findings

**I1 — Atlas not updated for the new reconcile contract (plan Task 5 Step 2; AGENTS.md §8).**
`atlas/chat/exchange_model.md:49` still describes only where fold ranges come from. Nothing in `atlas/` records the three things this milestone actually changed: the projection is a *desired state*; Parley owns **every** fold within an exchange span (a manual `zf` inside an exchange is now deleted — an operator-decided contract change); and ranges are verified against the buffer with a one-shot re-derive on drift. The only atlas change in the window is the `traceability.yaml` test row. Add a short "Fold reconciliation" subsection stating those three. Consider one README line too, since the deleted-user-fold behaviour is user-visible (README currently mentions folds only at `:159` for the toggle shortcut).

**I2 — The corpus harness contains no tool blocks, but its comment claims it covers them.**
`tests/integration/fold_invariants_spec.lua:5-6` says it pins "a tool call / tool result / summary / thinking block". I counted the parsed corpus: `thinking 20, summary 20, question 46, text 38, agent_header 38` — **zero `tool_use`, zero `tool_result`**. The issue's headline case (`🔧:`/`📎:`) is exercised only by hand-built models in `tool_folds_spec.lua`, never against a real transcript. The adversarial fixture is deferred to M2 Task 10 by design, but the harness should not claim coverage it lacks. Either add a minimal tool-bearing fixture now (cheap: the harness already accepts any tracked path) or correct the comment to name the gap and point at Task 10.

**I3 — A Done-when this milestone owns is now unmeetable as written and was not revised.**
`workshop/issues/000200-user-question-is-folded.md:75`: "Reconciling an exchange whose fold set is unchanged does no fold work." The memo was deliberately removed (correctly — see Strengths), so every reconcile clears and recreates unconditionally. The Plan bullet records the removal; the Done-when line was not updated and still states a criterion the code intentionally does not meet. Reword to the criterion actually delivered, e.g. "reconcile cost scales with the number of folds present, not with exchange length — measured per-chunk on a 600-row exchange."

**I4 — Verification evidence overstates the suite state; `make test` does not exit 0 here.**
`workshop/issues/000200-user-question-is-folded.md:351` reads "`make test` exit 0, full suite green" and then, in the same paragraph, that two specs fail "under the sandbox … they pass unsandboxed". I ran `make test` and `make test-integration` twice with no sandbox: both exit 1, deterministically, on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua`. The cause is not the agent sandbox — it is a machine-local OS permission, reproduced directly:

```
$ HOME=$PWD/.test-home git -C $PWD/.test-tmp/gitprobe init -q
fatal: cannot copy '.../git-core/templates/hooks/commit-msg.sample' to
  '.../.test-tmp/gitprobe/.git/hooks/commit-msg.sample': Operation not permitted
```

`make` sets `TMPDIR=$(CURDIR)/.test-tmp`, and `git init` cannot populate templates there. Both specs pass in isolation with a normal `TMPDIR` (9/9 and 3/3), and neither contains the string "fold". The substance — unrelated to #200 — is right; the wording is not, and the close gate will consume this as `--verified`. Restate precisely, since "run it unsandboxed" is not the workaround.

**I5 — The drift refusal is entirely silent, and the diagnostic that exists is discarded.**
`lua/parley/tool_folds.lua:110` wraps `verify_anchors` in parens specifically to drop `failed_index`, and `:143`/`:148` emit a `"drift"` event that only an injected `M._observer` (i.e. a test) ever sees. In production a drifted exchange just stops folding, with zero signal — the same silent-persistent-failure shape the issue's own Log blames `foldtext()`'s `else` fallback for. Note the pre-#200 code *raised* here (`E16: Invalid range`); swallowing it is intended per the Done-when, but it should not swallow the diagnosis too. Thread `failed_index` (and the failing range) into the drift event and emit one debug-level log line.

## 4. Minor findings

- `lua/parley/tool_folds.lua:106-108` — the explicit `end_0 >= line_count` loop duplicates a rule `verify_anchors` already owns (a missing row is drift). Redundant second expression of one fact (`ARCH-DRY`); `covered_lines` already clamps and the interior scan already returns false.
- `tests/integration/tool_folds_spec.lua:166` — the test name "in time independent of the span length" overstates what it measures. Reconcile is still O(span) through `covered_lines` + the interior scan: I measured 0.035 ms @50 rows → 0.065 @800 → 0.196 @3200 (~0.05 µs/row). The `large < small * 6 + 3` bound still catches a return to a row-walk clear (2–6 µs/row), which is the point, but rename it to say so.
- The Log cites `make perf` as evidence for the streaming fold path; `grep -rn "tool_folds\|fold" tests/perf/*.lua` returns nothing — the perf harness never touches folds. The real evidence is the direct per-chunk benchmark plus the in-suite scaling test; say that instead.
- `lua/parley/fold_projection.lua:14` — `M.FOLDABLE` exports the live table by reference, so a consumer can mutate the fold policy. A copy or an `M.is_foldable(kind)` accessor is a more stable surface for a newly-published field.
- `tests/integration/fold_invariants_spec.lua:32` shells to `git ls-files` with no seam (`ARCH-MOCK`). A `_corpus_provider` injection point, mirroring the module's existing `_model_provider` / `_observer` pattern, would make M2 Task 10's fixture extension trivial and drop the CWD/`git`-on-PATH dependency.
- `tests/integration/fold_invariants_spec.lua:46` silently `return`s when `find_header_end` is nil. Non-vacuous today (I counted 46 question + 40 foldable assertions), but a format change could turn the suite green-and-empty while the `#corpus >= 8` floor still passes. A total-assertion floor would pin it.
- `tests/integration/tool_folds_spec.lua:154` asserts only `has_no.errors` for the past-EOF case; adding "and no fold was created or destroyed" would pin the refusal, not just the non-crash.
- The Log flags a lesson worth keeping ("in Lua a `local function` is not in scope for functions defined earlier, and a `pcall` at the call site hides it") but `workshop/lessons.md` has no `#200` section yet. It is scheduled for M2 Task 11 Step 5; fine to defer, worth not losing.

## 5. Test coverage notes

- **The corpus harness cannot fail for the defect M1 fixed.** It exercises only the cold path (`hydrate_window` on a fresh parse), which the issue's own audit measured clean across all 127 transcripts *before* the fix. It is a regression net over real shapes, exactly as the plan says — the drift tests in `tool_folds_spec.lua:98-152` are the actual coverage of the defect. Worth stating in the Log so the harness is not later mistaken for the fix's proof.
- All targeted suites pass: `fold_projection_spec` 9/9, `tool_folds_spec` 16/16, `fold_invariants_spec` 10/10, lint 0/0 across 329 files.
- Corpus floor has one file of slack (`>= 8` vs 9 readable; 10 tracked, 1 deleted-but-unstaged in the working tree).
- Missing: a test for C1 (drifted span destroying a neighbour's fold), and any real-transcript coverage of `tool_use`/`tool_result` folding (I2).

## 6. Architectural notes

- **ARCH-DRY — pass, with one nit.** `FOLDABLE` is exported and consumed rather than restated (the harness reads `projection.FOLDABLE`), and `ANCHOR_KIND` names the `answer_structure`↔`highlight_structure` vocabulary bridge exactly once. Only nit is the duplicated fits-in-buffer rule (Minor above). M2's three-owner fence grammar remains the real DRY debt and is correctly scoped there.
- **ARCH-PURE — pass.** Verification is pure and nvim-free with the buffer read hoisted to a thin shell (`covered_lines`); the IO stays in `tool_folds`. Keep `verify_span` in `fold_projection` for the same reason rather than inlining the row scan into `reconcile_exchange`.
- **ARCH-PURPOSE — flag (C1).** The shadow-sweep here is over *operations on fold state*, not consumers of a source. The diff widened destruction (start rows → whole span) but widened verification only over creation. Both invariants in the Spec are equal; only one is defended. Going into M2, the same lens applies to `answer_structure`/`chat_parser`: the section boundaries they emit feed `exchange_span`, so a fence-naive mis-segmentation is now a *destructive* input, not just a display one.
- **ARCH-MOCK — pass (n/a in production).** No external binary or service on the production path; `M._model_provider` / `M._observer` are real injected seams and the tests use them. The only external call introduced is `git ls-files` in a test (Minor above).

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — M1 implementation deltas.** (a) **Task 3's memo is removed.** `applied_matches` / `record_applied` / the `"unchanged"` phase and Step 5's observer-phase test do not exist in the code and should not: verification proves the model matches the buffer, not which folds exist, so the short-circuit let an externally-added fold survive the span it was meant to own. PQ-5 is answered algorithmically instead. Strike the memo block and Step 5 from Task 3 so the plan stops describing code that was deliberately not written. (b) **Task 2's `clear_folds_in_span` is a fold-to-fold VimL walk, not a per-row `foldlevel` probe** — one `nvim_exec2` crossing, `zj`/`zD`, span-bounded `s:guard`. Measured 0.078 → 3.705 (Lua row walk) → 1.198 (VimL row walk) → 0.067 ms per chunk on a 600-row exchange. (c) **Task 4's harness enumerates via `git ls-files` + a readability filter with a `>= 8` floor**, not `assert.is_true(#corpus > 0)`; the oracle reads `projection.FOLDABLE` as PQ-2 required. (d) **New: span verification** — record C1 and the `verify_span` addition, since Task 3's "verify → re-derive → clear → create" as written verifies only the creation half.
- Then update the issue's `## Done when` line 75 per I3, and the `## Log` verification paragraph per I4.

---

## Re-review — 2026-08-20T16:11:11-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 1aa279cfdf973ff0260263e07ab4d209a04ebfd4..HEAD |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T16:11:11-07:00 |
| verdict | REWORK |

## Review

I have everything I need.

```verdict
verdict: REWORK
confidence: high
```

The C1 rework from the previous round is genuinely done — `verify_span` is pure, both destructive paths are guarded, and I reproduced the neighbour-destruction scenario and confirmed it now holds. The atlas section, the lessons entries, and the tool-bearing fixture (6 real foldable blocks, not a vacuous pass) are all substantive. What blocks SHIP is that the C1 fix over-corrected: `verify_span` hardcodes "an exchange span must start on a `💬:` line," but `chat_parser` explicitly builds exchanges without a real question (the `🤖:`-with-no-preceding-`💬:` path at `chat_parser.lua:623`). For any such transcript, `reconcile_exchange` refuses permanently — the re-derive cannot rescue it, because a fresh parse produces the same non-question anchor, and `hydrate_window` latches per buf/win. I measured it: `🔧:`/`📎:`/`📝:` at rows 10/15/20 fold correctly at base `38a6cdd` and report `foldclosed=-1` at HEAD with `which="span"`. That is the Spec's second invariant ("`🔧:`, `📎:`, `📝:` and `🧠:` blocks are always folded") failing with exactly the permanent-for-the-session signature #200 exists to remove — the same failure class as the C1 it was written to fix, now caused by the fix. Secondarily, the drift path re-parses the whole buffer per streamed chunk with no bound (10.9 ms/chunk on a 5000-line chat), so C1 also degrades streaming badly rather than just disabling folds.

## 1. Strengths

- **The previous round's C1 is really fixed, not merely asserted.** I reproduced the drifted-exchange-deletes-neighbour scenario (`tests/integration/tool_folds_spec.lua:215`) and the `📎:` fold survives. `fold_projection.verify_span` (`lua/parley/fold_projection.lua:45`) is genuinely pure — the "loads without a Neovim global" test still passes, and both destructive callers (`tool_folds.lua:141`, `:214`) read the buffer in the thin shell and hand a row map in. Textbook `ARCH-PURE`.
- **The tool-bearing fixture is real coverage, not a comment fix.** I parsed `tests/fixtures/fold_tool_transcript.md`: `tool_use 2, tool_result 2, summary 1, thinking 1` — 6 foldable blocks actually asserted against live Neovim fold state. I2 from the last round was addressed on the merits, and the corpus harness now exercises the issue's headline case.
- **`clear_folds_in_span` holds its performance claim.** Measured per-reconcile on this machine: 0.033 ms @50 rows → 0.078 @600 → 0.349 @3200. The clear itself is O(folds); what residual linearity exists is the verification scans, not the `zj`/`zD` walk. The `s:guard` bound against `E350` (`tool_folds.lua:64-66`) is a real hazard correctly anticipated.
- **The `workshop/lessons.md` entries generalize correctly** — particularly "widening a destructive operation demands widening its verification" and "a vacuous input (empty list, nil span) must fail closed rather than open." Those are the right abstractions from what went wrong, and the second one is exactly the lens that would have caught C1 in review rather than after.
- **`is_foldable()` and `ANCHOR_KIND`** (`fold_projection.lua:14`, `:21`) name the policy and the `answer_structure`↔`highlight_structure` vocabulary bridge exactly once, and the harness consumes the accessor rather than restating the set. Clean `ARCH-DRY`.

## 2. Critical findings

**C1 — `verify_span`'s anchor rule permanently refuses to fold any exchange the parser builds without a `💬:` question line.**
`lua/parley/fold_projection.lua:48`, applied at `lua/parley/tool_folds.lua:141` and `:214` — `ARCH-PURPOSE`.

`verify_span` unconditionally requires `lines[first_0]` to match `user_pattern`. But `chat_parser.lua:623-635` explicitly handles "assistant message without preceding user message" by fabricating a question block from `header_end + 1`, so `exchange_start(k)` lands on prose or a blank line. The span check then fails, the drift branch re-derives — and a *fresh* parse of the same buffer yields the identical non-question anchor, so `model_fits` fails again and `reconcile_exchange` returns `false` having created nothing. Because `hydrate_window` latches on `initialized[buf][win]`, nothing retries for the rest of the session.

Reproduced against base vs. HEAD on the same buffer (a transcript whose first turn is `🤖:`):

```
desired ranges (0-based):
  tool_use     9..12   anchor="🔧: read id=x"
  tool_result  14..17  anchor="📎: read id=x"
  summary      19..19  anchor="📝: did it"

BASE (38a6cdd, no verification):   row 10 foldclosed=10   row 15 foldclosed=15   row 20 foldclosed=20
HEAD (verified): reconcile=false, drift which="span"
                                   row 10 foldclosed=-1   row 15 foldclosed=-1   row 20 foldclosed=-1
```

Note the ranges themselves verify fine (`which="span"`, not `"ranges"`) — the projection is correct and the anchors are real; only the span heuristic refuses. This is a regression the milestone introduces: base created these folds unconditionally.

Fix sketch — the logic error is applying a *staleness* check to a model that was derived from the buffer one instruction earlier. A model produced by `default_model_provider` cannot be stale by construction, so span-refusing it converts a heuristic false positive into a permanent refusal. In `reconcile_exchange` (`tool_folds.lua:174-193`), accept the re-derived model's span rather than re-running `verify_span` on it:

```lua
if ok and fresh and fresh.exchanges[exchange_index] then
    fresh_ranges = projection.desired_folds(fresh, exchange_index)
    fresh_first, fresh_last = exchange_span(fresh, exchange_index)
    -- A model parsed from this buffer cannot be stale; keep range verification
    -- as a projection sanity check, but the span it derives IS the buffer's.
    fits = projection.verify_anchors(fresh_ranges, covered_lines(buf, fresh_ranges), patterns)
        and fresh_first ~= nil
end
```

I validated this direction: the assistant-first transcript folds all three markers again (`reconcile -> true`, `foldclosed = 10/15/20`) **and** the C1 regression test still passes (`📎: grep` keeps `foldclosed == its own row`), because the fresh model's span for the drifted exchange is `5..9`, which no longer covers the neighbour.

Do **not** simply drop the anchor check from `verify_span`: I confirmed the interior scan alone catches the reproduced C1 case (`💬: second` sits at row 11 inside the stale span `5..19`), but the anchor half is still load-bearing against forward-drift, where a stale span slides wholly past a question into the next exchange's answer. Keep it on the stale-model path; stop applying it to a just-parsed one.

Regression test: the assistant-first fixture above, asserting all three markers fold — this is the shape neither `tool_folds_spec.lua` nor the corpus harness contains (every corpus file and the new fixture start with `💬:`).

## 3. Important findings

**I1 — The drift path re-parses the entire buffer on every streamed chunk, unbounded.**
`lua/parley/tool_folds.lua:176` (`pcall(provider, buf)`) and `:34` (`logger.debug`).

`chat_respond.lua:1743`'s `around_write` wraps every streamed chunk in `with_exchange_update` → `finalize_exchange_update` → `reconcile_exchange`. When verification fails, each call runs `default_model_provider`: a full `nvim_buf_get_lines(0, -1)` plus a full `parse_chat` over the whole transcript, plus a `logger.debug` that does an unconditional `io.open/write/close` (`logger.lua:89-93` has no level gate on the file write). Nothing memoizes or backs off, and a drifted exchange typically stays drifted, so this runs per chunk indefinitely. Measured per refused reconcile:

```
buffer   114 lines ->  0.281 ms
buffer   514 lines ->  1.080 ms
buffer  2014 lines ->  4.340 ms
buffer  5014 lines -> 10.860 ms
```

versus 0.067–0.078 ms on the healthy path — 160× on a 5000-line chat, synchronous on the write path, thousands of times per answer. This is the same hot-path class PQ-5 raised; the plan answered it for `clear_folds_in_span` only. C1 makes it reachable on ordinary input rather than only after a bypassed mutation. Fix: cache the re-derive against `nvim_buf_get_changedtick(buf)` (a failed re-derive at tick T cannot succeed at tick T), and log the refusal once per buf/exchange until it recovers.

**I2 — `make test` is not green here, and the Log's correction of the previous review's I4 is factually wrong.**
`workshop/issues/000200-user-question-is-folded.md:354`, `:363`, `:401-403`; `workshop/plans/000200-fold-reconciliation-plan.md:1442`.

The Log states "`make test` exit 0 (run twice), full suite green" and then corrects the prior review: "The Makefile sets no `TMPDIR` (`grep -rn TMPDIR Makefile` is empty)". The Makefile does set it — `Makefile.parley:28`:

```make
TEST_ENV = HOME="$(TEST_HOME)" … TMPDIR="$(TEST_TMP)" …
TEST_TMP = $(CURDIR)/.test-tmp
```

reached via `Makefile` → `Makefile.local:4` → `Makefile.parley`; `make -pn` confirms both variables in the expanded database. The grep was scoped to the top-level `Makefile`, which only *includes* the file that sets it. I ran `make test` unsandboxed with a normal outer `TMPDIR` and it fails deterministically:

```
=== Failed integration test files ===
tests/integration/git_markdown_source_spec.lua
tests/integration/markdown_finder_async_spec.lua
make: *** [test-integration] Error 1
```

while `git_markdown_source_spec.lua` passes 11/11 standalone with a normal `TMPDIR`. So the previous review's I4 mechanism was correct and this milestone's record now contradicts it. Neither spec touches folds, so this doesn't impugn the fold work — but it is the boundary's stated proof, the close gate consumes it as `--verified`, and the wrong correction will outlive the session. Restate both the evidence and the correction.

**I3 — README not updated for the operator-visible fold-ownership change (Docs gate).**
`README.md:159` is the only fold-facing user documentation (the `chat_shortcut_toggle_tool_folds` opt-in), and nothing in the window touches it. This milestone changes behaviour a user can observe directly: a manual `zf` created inside an exchange is now deleted on the next reconcile. That was an explicit operator decision (`atlas/chat/exchange_model.md`, plan `## Revisions`), and the atlas records it — but the atlas is the agent-facing map, not the place a user learns why their fold vanished. One sentence at `README.md:159`.

**I4 — The corpus harness's "injectable seam" does not exist, and three artifacts claim it does.**
`tests/integration/fold_invariants_spec.lua:12-16`, `:41-44` — `ARCH-MOCK`.

The comment reads "Seam mirroring tool_folds' `_model_provider` / `_observer` pattern: the corpus source is injectable, so this does not hard-depend on cwd or git-on-PATH," and the plan's M1 revision repeats "enumerates via an injectable corpus seam." What landed is a file-local `local M_corpus_provider = function() … end` invoked directly at `:42` during the `describe` body — there is no override point, and it still shells `vim.fn.systemlist("git ls-files …")`, so the cwd and git-on-PATH dependencies are exactly as they were. The prior round's Minor was renamed rather than addressed, and a false claim was added on top of it. Either export it (`M._corpus_provider`, read at call time) or delete the claim from both the comment and the plan revision.

## 4. Minor findings

- `lua/parley/tool_folds.lua:105-118` and `:120-129` — `covered_lines` and `span_lines` are near-identical row-map readers, and since `desired_folds` asserts every range lies inside the span (`fold_projection.lua:105`), one `span_lines(first_0, last_0)` read would serve both verifiers. Currently the per-chunk path does two overlapping buffer reads and two O(span) scans (`ARCH-DRY`).
- `lua/parley/tool_folds.lua:214-216` — `prepare_exchange_update`'s span refusal is silent: no `report_drift`, and it still emits `notify({phase = "prepare", ranges = <stale>})`, so an observer cannot tell "cleared" from "refused". The Done-when's "the refusal is not silent" holds only on the reconcile path.
- `workshop/issues/000200-user-question-is-folded.md:340` — the `0.067ms` per-chunk figure predates the C1 fix's added `span_lines` + `verify_span` pass; the same 600-row shape measures 0.078 ms here. Small, but it is the number the Done-when is graded against.
- `workshop/issues/000200-user-question-is-folded.md:177`, `:341` — `make perf` is still cited as evidence for the streaming fold path; `grep -rn fold tests/perf/*.lua` is empty, so the perf harness cannot exercise folds. The real evidence is the direct benchmark plus the in-suite scaling test. (Deferred Minor from the previous round, still valid.)
- `lua/parley/tool_folds.lua:307` — `foldtext()`'s `else` fallback still renders a non-marker fold as ordinary prose. The Log itself blames this branch for masking #200 for a whole session; now that reconcile guarantees no Parley fold anchors off-marker, it could log instead of masking.
- `workshop/plans/000200-fold-reconciliation-plan.md:38-41` — the `fold_projection` Core-concepts prose lists only `anchor_kind` / `verify_anchors`, and its "Future extensions" bullet proposes interior checking as hypothetical future work that M1 already shipped (plus `verify_span` and `is_foldable`, which it never mentions).

## 5. Test coverage notes

- **The gap that shipped C1 is structural, not incidental.** Every file in the corpus and the new fixture begins with `💬:`, and every hand-built model in `tool_folds_spec.lua` uses `add_exchange(n)` with a real question line — so no test in the suite can reach `chat_parser`'s question-less exchange path. One fixture whose first turn is `🤖:` closes it.
- Targeted suites all pass as claimed: `fold_projection_spec` 14/14, `tool_folds_spec` 18/18, `fold_invariants_spec` 11/11, lint 0 warnings / 0 errors across 329 files.
- The scaling test at `tool_folds_spec.lua:172` is honestly named now and its best-of-N minimum construction is the right instrument. Its `large < small * 6 + 3` bound still catches a return to a row-walk clear.
- The corpus harness exercises only the cold `hydrate_window` path, which the issue's own audit measured clean *before* the fix. The real coverage of the defect is `tool_folds_spec.lua:111-152` and `:215`. Worth one Log line so the harness is not later mistaken for the fix's proof.
- No test covers the drift path's cost or repetition (I1). An observer-phase assertion that N reconciles at one changedtick trigger at most one re-derive would pin it.

## 6. Architectural notes

- **ARCH-DRY — pass, two nits.** `is_foldable()`/`ANCHOR_KIND` are single-sourced and consumed, not restated; the fits-in-buffer rule the previous round flagged as duplicated is now correctly delegated with a comment at `tool_folds.lua:137-138`. Remaining: the `covered_lines`/`span_lines` pair. M2's three-owner fence grammar is the real DRY debt and stays correctly scoped there.
- **ARCH-PURE — pass.** Verification is pure and nvim-free with the buffer reads hoisted into the shell; `verify_span` was correctly placed in `fold_projection` rather than inlined. Keep the C1 fix in the same shape — the change belongs in `reconcile_exchange`'s drift branch (which model to trust), not inside the pure predicate.
- **ARCH-PURPOSE — flag (C1).** The shadow-sweep here runs over *operations on fold state*. Last round destruction was unverified; this round it is verified, but the verification's precondition ("every exchange starts on a question") is stricter than what the producer guarantees. Both Spec invariants must hold, and the milestone now trades a violation of "never fold a question" for a violation of "always fold tool blocks." Going into M2 the same lens applies with more force: once `chat_parser` suppresses markers inside tool bodies, exchange boundaries move, and `exchange_span` feeds a destructive operation — a fence-naive mis-segmentation there will destroy folds, not just mis-render them.
- **ARCH-MOCK — pass on the production path, flag in tests.** No external binary or service in production; `M._model_provider` / `M._observer` are real seams the tests drive. The only external call is `git ls-files` in `fold_invariants_spec.lua`, which is claimed to sit behind a seam and does not (I4).

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — M1 boundary review round 2 (C1 over-correction).** `verify_span`'s anchor requirement assumes every exchange starts on a `💬:` line, which `chat_parser.lua:623` does not guarantee — an assistant-first transcript stops folding entirely and permanently. Record the narrowed contract actually adopted: the span anchor check applies to the *stale* model only; a model re-derived from the buffer is authoritative for its own span. Add the assistant-first fixture to Task 4's harness as the regression pin.
- **Same entry — Task 3's drift re-derive is unbounded on the streaming path.** Record the measured cost (0.28 ms @114 lines → 10.9 ms @5014 lines per refused reconcile, once per streamed chunk) and the mitigation adopted (changedtick memo + log-once), so PQ-5's hot-path concern is answered for the drift branch as well as for the clear.
- **Correct the `fold_projection` Core-concepts entry** (`:38-41`): it should name `verify_span` and `is_foldable`, and its "Future extensions" bullet should stop proposing whole-range verification, which M1 shipped.
- **Strike the "injectable corpus seam" claim** from the M1 implementation-deltas revision, or make it true; as written the plan asserts a seam the spec does not have.
- **Correct the I4 rebuttal** at `:1442`: `Makefile.parley:28` does set `TMPDIR=$(CURDIR)/.test-tmp` (included via `Makefile` → `Makefile.local`), and `make test` fails deterministically on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua` on this machine. The original finding stands.

---

## Re-review — 2026-08-20T16:29:07-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 387d8c44be087e3559f226b5076710f1698d7c95..HEAD |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T16:29:07-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Note on scope: the supplied window (`387d8c4..HEAD`) is empty — `387d8c4` **is** `HEAD`. M1 has never been closed (rounds 1 and 2 both returned REWORK), so I reviewed the branch point to HEAD, `38a6cdd..HEAD`, which is the full un-closed M1 work.

The round-2 C1 fix is real — the assistant-first transcript folds again, the fixture has teeth, and the changedtick memo genuinely collapses the hydration fan-out. What blocks SHIP is that the narrowing over-corrected in the opposite direction and re-opened round-1's C1. `verify_span` now accepts any span with no question *after* its first row; the code comment (`fold_projection.lua:49-50`) and the plan (`:1460`) justify this with "a span reaching a neighbour is still caught, because reaching one means covering its question," which is false when a stale span lands *inside* a neighbour's answer rather than straddling its question. I reproduced it: an exchange with no foldable block (empty `ranges` ⇒ `verify_anchors` vacuously true) plus a 30-line upstream deletion makes `reconcile_exchange` return `true` while destroying a later exchange's `📎:` fold — `foldclosed 77 → -1`, and `hydrate_window` returns `false` (latched), so it never comes back. The same probe against base `38a6cdd` keeps the fold at `foldclosed=47`, so this is a regression the milestone introduces, not a pre-existing hole. `prepare_exchange_update` carries the same check with **no** re-derive fallback and destroys the fold on its own. That is the Spec's second invariant ("`🔧:`, `📎:`, `📝:` and `🧠:` blocks are always folded") failing with exactly the session-persistent signature #200 exists to remove — for the third round running, now from the loose side.

## 1. Strengths

- **The round-2 C1 is genuinely fixed and pinned by a real transcript.** `tests/fixtures/fold_assistant_first.md` is a parsed transcript, not a hand-built model, and `fold_invariants_spec` runs it green at 12/12. The narrowing solves the problem it was written for.
- **Verification is properly pure.** `verify_anchors` / `verify_span` (`fold_projection.lua:52`, `:74`) take a row→text map from a caller that reads the buffer once; the "loads without a Neovim global" test still passes and the unit spec drives both with plain Lua tables. Textbook `ARCH-PURE`.
- **The memo does fix the fan-out case it can fix.** Measured on a 4325-line chat with a drifted model: 20 reconciles at one changedtick cost 5.90 ms/call amortized (≈ one parse total) instead of 20 full parses. `hydrate_window`'s per-exchange × per-window loop is the real beneficiary.
- **Verification adds zero false positives on real input.** I instrumented `_observer` across all 11 corpus files on a cold `hydrate_window`: **0 drift refusals**. The checks don't fire on healthy transcripts.
- **The `workshop/lessons.md` entries generalize correctly** — "widening a destructive operation demands widening its verification" and "a vacuous input must fail closed rather than open" are the right abstractions. (Round 3 violates the same principle from the other side: the check is now weaker than the destruction it guards.)
- **`clear_folds_in_span` holds its scaling claim** and the `s:guard` E350 bound (`tool_folds.lua:64-67`) is a real hazard correctly anticipated.

## 2. Critical findings

**C1 — The narrowed `verify_span` re-opens round 1's C1: a drifted reconcile permanently destroys a neighbouring exchange's tool fold.**
`lua/parley/fold_projection.lua:52-61`, applied at `lua/parley/tool_folds.lua:142` and `:240` — `ARCH-PURPOSE`.

Dropping `if not first:match(patterns.user_pattern) then return false end` leaves the interior scan as the only span guard. The interior scan catches a span that *straddles* a neighbour's question; it cannot catch a span that lands wholly inside a neighbour's answer. Combined with `verify_anchors({}, …) == true` for an exchange with no foldable block, the destructive half is unguarded again.

Reproduced (3 exchanges; exchange 2 = question + prose, no foldable block; exchange 3 = long answer with a `📎:` fold; delete 30 prose lines from exchange 1 bypassing `with_exchange_update`; reconcile exchange 2):

```
BEFORE: 📎 at row 77 foldclosed=77
stale exchange 2 span (0-based) = 40..49 ; ranges=0
after mutation rows 40..49 hold: "e3 prose 16..20", "", "📎: grep id=z", "```", "hit 1", "hit 2"   <- no 💬: anywhere
reconcile_exchange(stale, 2) -> true
AFTER:  📎 at row 47 foldclosed=-1 (want 47)
hydrate_window again -> false          <- latched; nothing recreates it
```

Same probe with base `38a6cdd`'s `tool_folds.lua` + `fold_projection.lua` prepended to `runtimepath`: `AFTER: 📎 at row 47 foldclosed=47`. **The fold survives at base and dies at HEAD** — a regression, because the old start-row-only `zd` could never reach a neighbour.

`prepare_exchange_update` is affected identically and is worse: it has no re-derive fallback, only a "skip the clear" branch. Called alone on the stale model it produces the same `foldclosed 77 → -1`. It is on the per-chunk streaming path (`chat_respond.lua:1743`), so a user pruning an earlier exchange mid-response reaches it — deleting an earlier exchange does not move the #138 agent-header extmark, so the lease stays valid and the model stays stale.

**Fix sketch — restore the anchor rule and exempt only what the producer actually leaves unanchored.** `chat_parser.lua:627` fabricates a question block only when `current_exchange` is nil, and `current_exchange` is never reset to nil (`:278`, `:572`, `:627` are its only assignments), so an unanchored span can only ever be exchange **1**:

```lua
function M.verify_span(first_0, last_0, lines, patterns, allow_unanchored)
    patterns = patterns or require("parley.highlight_structure").patterns()
    local first = lines[first_0]
    if first == nil then return false end
    -- Only exchange 1 can legitimately start off-question: chat_parser
    -- fabricates a question block for an assistant-first transcript
    -- (chat_parser.lua:623-635), and only when no exchange exists yet.
    if not allow_unanchored and not first:match(patterns.user_pattern) then return false end
    for row = first_0 + 1, last_0 do
        local line = lines[row]
        if line == nil or line:match(patterns.user_pattern) then return false end
    end
    return true
end
```

with both call sites passing `exchange_index == 1`. The exemption is free: `exchange_start(1)` is `header_lines + MARGIN` (`exchange_model.lua:168-174`) and cannot drift forward, and end-drift past the next question is still caught by the interior scan. (Round 2's alternative — trust the freshly re-derived model's own span — also works, but it forces a re-parse on every reconcile for assistant-first transcripts, which compounds I1.)

**Regression test:** the probe above, on **both** `reconcile_exchange` and `prepare_exchange_update`, asserting the later `📎:` keeps `foldclosed == its own row`. No existing test reaches the "empty ranges + drifted span landing in a question-free window" shape.

## 3. Important findings

**I1 — The changedtick memo does not bound the streaming path it was added for.**
`lua/parley/tool_folds.lua:164-173`.

Round 2's I1 was specifically "the drift path re-parses the entire buffer on every streamed chunk." Every streamed chunk *mutates the buffer*, so the tick moves and the memo misses every time. Measured on a 4325-line chat with a drifted model:

```
same-tick reconcile   (memo hits) :  5.90 ms/call   (≈ one parse amortised over 20)
tick-moving reconcile (streaming) : 81.82 ms/call   (a full re-parse every call)
```

The commit message's "1356 ms → 1.05 ms" describes the fan-out case only. Secondary: `report_drift`'s "once per buffer state" is once per tick, i.e. once per chunk while streaming, and `logger.lua:89-93` does an unconditional `io.open`/write/`close` with no level gate. Fix: back off per (buf, exchange) for the duration of a drift episode rather than per tick.

**I2 — The atlas now contradicts the code it documents.**
`atlas/chat/exchange_model.md:71` still reads "the exchange span must start on its own question and contain no other" — the round-1 rule, which `387d8c4` deliberately removed. The one restatement of the model in the docs has drifted from its source, which is the same `ARCH-DRY` hazard this issue is about. Update it in the same pass as the C1 fix.

**I3 — README not updated for the operator-visible fold-ownership change (Docs gate; round-2 I3, still open).**
`README.md:159` is the only fold-facing user documentation and is untouched in the window. The milestone makes a manual `zf` inside an exchange vanish on the next reconcile — an operator-decided contract change. The atlas records it; the place a user would look does not. One sentence.

**I4 — "`make test` green" is not reproducible here, and the recorded mechanism is wrong for the third round.**
`workshop/issues/000200-user-question-is-folded.md:354`, `:413`, and the caveat at `:379-403`.

With sandboxing disabled in this session, `make test` exits **2**, failing on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua` (neither contains the string "fold"). Cause is `git init` → 128, `cannot copy .../git-core/templates/hooks/commit-msg.sample ... Operation not permitted`. The Log attributes this to `TMPDIR=$(TEST_TMP)` plus the agent sandbox. Measured mechanism:

```
git init in .test-tmp/gitprobe              -> 128   (real HOME, no sandbox)
git init in .gitprobe4  (repo root, no TMPDIR involvement) -> 128
git init in $HOME/gitprobe3                 ->   0
cp  .../commit-msg.sample  .test-tmp/       ->   0
```

So it is neither TMPDIR nor the sandbox flag — `git init` is blocked for **any** directory under the repo root for this process tree, while the same template file copies fine. The substance is unrelated to #200 and the fold work is green (independently confirmed: `fold_projection_spec` 15/15, `tool_folds_spec` 18/18, `fold_invariants_spec` 12/12, lint 0 warnings / 0 errors across 329 files). But `sdlc close` consumes this text as `--verified`, so state it as "fold suites green; `make test` blocked on two fold-unrelated specs by a machine-local `git init` restriction under the repo root," not "exit 0, full suite green."

**I5 — `prepare_exchange_update`'s refusal is silent and mis-reports (round-2 Minor, escalated by C1).**
`lua/parley/tool_folds.lua:240-248`. On span-verify failure it nils the span, skips the clear, and still emits `notify({phase = "prepare", ranges = <stale ranges>})` with no `report_drift`. An observer cannot distinguish "cleared" from "refused", so the Done-when "a drifted exchange that cannot be folded says so" holds only on the reconcile path — and this is the path C1 shows destroying folds, so it needs both the corrected check and the diagnostic.

## 4. Minor findings

- `tool_folds.lua:164` — `setmetatable({}, {__mode = "k"})` is a no-op: keys are buffer *numbers*, which aren't collectable, so nothing is ever weakly reclaimed. Nothing clears `rederived[buf]` on `BufUnload`/`BufDelete` either, though the sibling `initialized[buf]` is (`:358-361`). Each entry pins a whole parsed model for the session.
- `tool_folds.lua:213` — `report_drift` logs `ranges` / `failed_index` / `which` from the **stale** `model_fits`, but the refusal decision came from the **fresh** one; the logged "which half drifted" can name the wrong half.
- `tool_folds.lua:106-119` vs `:121-130` — `covered_lines` and `span_lines` are near-identical row-map readers; since `desired_folds` asserts every range lies inside the span (`fold_projection.lua:111`), one span read would serve both verifiers instead of two overlapping buffer reads per chunk (`ARCH-DRY`, carried from round 2).
- The `rederived` memo has no reset seam, and a cache hit at the same changedtick silently bypasses an injected `M._model_provider` — a test swapping providers without touching the buffer gets the previous model.
- `tool_folds.lua:333` — `foldtext()`'s `else` fallback still renders an off-marker fold as ordinary prose; the Log blames this branch for masking #200 for a whole session.
- `workshop/issues/…:177`, `:341` — `make perf` still cited as evidence for the streaming fold path; `grep -rln fold tests/perf/` is empty (only `chat_typing.lua`, `harness.lua`). Carried from rounds 1 and 2.
- `workshop/issues/…:340` — the `0.067 ms` per-chunk figure predates round 1's added `span_lines` + `verify_span` pass; round 2 measured 0.078 ms for the same shape.
- `tests/integration/fold_invariants_spec.lua:17` shells `git ls-files` with no seam (`ARCH-MOCK`). The false "injectable seam" claim is correctly withdrawn and the comment is now honest; the direct external call remains.

## 5. Test coverage notes

- All three fold suites pass, run independently: `fold_projection_spec` 15/15, `tool_folds_spec` 18/18, `fold_invariants_spec` 12/12 (11 subjects + the floor check). Lint 0/0 across 329 files.
- **The gap that shipped C1 is structural.** Every drift test in `tool_folds_spec.lua` either gives the exchange foldable ranges (so `verify_anchors` catches the drift) or drifts by a small enough amount that the neighbour's question lands inside the window — `:215` ("does not destroy a neighbouring exchange's fold") is exactly the small-drift shape. Nothing covers empty-`ranges` + a drifted span landing in a question-free window. One fixture closes it.
- **`prepare_exchange_update`'s destructive path has no direct test** — every existing test reaches it via `with_exchange_update` or tests `reconcile_exchange`. My probe shows it destroys folds on its own.
- The corpus harness exercises only the cold `hydrate_window` path, which the issue's own audit measured clean *before* the fix; I confirmed zero drift refusals across all 11 files. It is a regression net over real shapes, not proof of the fix — the drift tests in `tool_folds_spec.lua` are. Worth one Log line (carried from round 2).
- No test pins the re-derive's cost or repetition (I1). An observer assertion that N reconciles across N ticks trigger at most one re-derive per drift episode would pin it.

## 6. Architectural notes

- **ARCH-DRY — flag (minor).** `is_foldable()` and `ANCHOR_KIND` are single-sourced and consumed rather than restated — good. Two restatements remain: `covered_lines`/`span_lines`, and the atlas prose at `exchange_model.md:71`, which has now drifted from the rule in code (I2). M2's three-owner fence grammar is the real DRY debt and stays correctly scoped there.
- **ARCH-PURE — pass.** Verification is pure and nvim-free with buffer reads hoisted into the shell; the new `rederived` memo is module-level mutable state but sits in the IO shell (`tool_folds`), not the pure module — correct placement. Keep the C1 fix in that same split: the predicate learns one parameter, the shell decides what to pass.
- **ARCH-PURPOSE — flag (C1).** Shadow-sweep over operations on fold state. Round 1: destruction unverified. Round 2: the check was stricter than the producer guarantees, breaking "always folded." Round 3: the check is looser than the invariant requires, breaking "always folded" again from the other side. Both Spec invariants must hold *simultaneously*; the fix has to distinguish what the producer guarantees (exchange 1 may be unanchored) from what it does not (exchanges 2..N always start on a question). Into M2, the same lens bites harder: `answer_structure`/`chat_parser` boundaries feed `exchange_span`, which is now a **destructive** input — a fence-naive mis-segmentation there will delete folds, not merely mis-render them.
- **ARCH-MOCK — pass on the production path, minor in tests.** No external binary or service in production; `M._model_provider` / `M._observer` are real seams the tests drive. The only external call is `git ls-files` in `fold_invariants_spec.lua:17`, now honestly documented as a single point of definition rather than a seam.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — M1 boundary review round 3 (the narrowing was too loose).** The round-2 revision at `:1460` claims the "no question after the first row" rule "still catches a span reaching a neighbour — reaching one means covering its question," and that it is "simpler than the reviewer's suggested 'trust the re-derived model's span' and needs no stale-vs-fresh distinction." Both are wrong: a stale span landing wholly *inside* a neighbour's answer covers no question, and with an empty range list nothing else guards the clear. Reproduced against base vs HEAD. Record the rule actually adopted — the anchor requirement holds for every exchange except index 1, whose off-question anchor is what `chat_parser.lua:627` guarantees (and only there, since `current_exchange` is never reset to nil).
- **Same entry — the changedtick memo bounds the same-tick fan-out only.** Record the measured tick-moving cost (81.8 ms/call on a 4325-line chat vs 5.9 ms/call amortised same-tick) so round-2's I1 is not recorded as fully answered, and name the backoff actually adopted.
- **Correct the code comment** at `fold_projection.lua:44-50`, which carries the same false justification into the source.
- **Update `atlas/chat/exchange_model.md:71`** in the same pass so the atlas stops stating the round-1 rule (I2).
- **Restate the `## Log` verification paragraph** (`workshop/issues/…:354`, `:413`, `:379-403`) per I4: `git init` is blocked for any directory under the repo root on this machine, independent of `TMPDIR` and of the agent sandbox; the fold suites are green and `make test` is not.

---

## Re-review — 2026-08-20T16:45:20-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 6355f0affcd8924c4e33ff3b961cea0b69f67b59..HEAD |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T16:45:20-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Round 3's narrowing is a genuine improvement — `verify_span` now requires both an on-question anchor and a clean interior, the exchange-1 exemption is correctly derived from what `chat_parser` actually guarantees (I re-verified `current_exchange`'s three assignment sites at `chat_parser.lua:278`/`:572`/`:627`; the fabricated-question path can only ever produce index 1), the atlas now matches the code, and all three fold suites are green (16/16, 19/19, 12/12) with lint 0/0 across 329 files. What blocks SHIP is that the anchor test is *aliasable*: it proves the span's first row is **a** question, never that it is **this exchange's** question. I reproduced a stale span for an exchange with no foldable block landing exactly on a *later* exchange's `💬:` line — anchor check passes, interior scan passes (no second question in range), range verification passes vacuously on the empty list — so the clear deletes that later exchange's `📎:` fold and creates nothing. Same probe at base `38a6cdd` keeps `foldclosed=31`; at HEAD it is `-1`, and `hydrate_window` is latched, so it is gone for the session. `prepare_exchange_update` does it on its own with no re-derive fallback at all. That is the Spec's second invariant failing with the exact persistence signature #200 exists to remove, for the fourth round — and the pattern matters more than this instance: a predicate over local buffer text provably cannot distinguish exchange K's question from exchange M's, so patching it a fourth time is not the durable answer. Secondarily, the re-derive backoff added this round is a no-op for the case it was written for (measured: 10 full parses over 10 ticks).

## 1. Strengths

- **The exchange-1 exemption is derived, not guessed.** `fold_projection.lua:56-61` states the reason and the proof obligation, and it holds: `chat_parser.lua:627` fires only when `current_exchange` is nil, and the only assignments (`:278` init, `:572`, `:627`) never restore nil. `tests/fixtures/fold_assistant_first.md` is a real parsed transcript, not a hand-built model, and it runs green in the corpus harness.
- **Verification is properly pure and stays that way.** `verify_anchors` / `verify_span` (`fold_projection.lua:64`, `:87`) take a row→text map from a shell that reads the buffer once; the "loads without a Neovim global" test still passes and the unit spec drives both with plain Lua tables. `ARCH-PURE` textbook.
- **The atlas section now matches the code it documents** (`atlas/chat/exchange_model.md`, *Fold reconciliation*). Round 3's I2 is genuinely closed — it states the ownership change, both halves of verification, the vacuous-empty-range reason, and the exchange-1 waiver, in the same words the code uses.
- **`clear_folds_in_span` holds its scaling claim and its hazard bound.** I re-ran the in-suite scaling test; the `s:guard` E350 bound at `tool_folds.lua:64-67` is a real failure mode correctly anticipated, and the `zj`/`zD` walk in one `nvim_exec2` crossing is the right shape for a per-chunk path.
- **The `workshop/lessons.md` entries generalize correctly** — "a vacuous input (empty list, nil span) must fail closed rather than open" is exactly the lens that catches C1 below, which makes it a lesson the diff has not yet finished applying to itself.

## 2. Critical findings

**C1 — `verify_span`'s question anchor aliases across exchanges: a stale span that lands on a *different* exchange's question passes verification, and the clear permanently destroys that exchange's tool fold.**
`lua/parley/fold_projection.lua:67`, applied at `lua/parley/tool_folds.lua:142` and `:270` — `ARCH-PURPOSE`.

`verify_span` asks "is `lines[first_0]` a question?", which is satisfied by *any* exchange's question line. When the drift offset happens to align exchange K's stale start with exchange M's real start (M > K), the anchor check passes; the interior scan passes because there is no *second* question in range; and if exchange K has no foldable block, `verify_anchors({}, …)` is vacuously true. All three guards pass and the destructive half runs against a neighbour's span.

Reproduced — four exchanges, E2 and E3 the same line count, E3 with no foldable block, E4 carrying a `📎:`; delete E2 outright (bypassing `with_exchange_update`), then reconcile exchange 3:

```
BEFORE: 📎 at row 43 foldclosed=43
stale exchange-3 span (0-based) = 25..35 ; foldable ranges = 0
deleted rows 14..25 (exchange 2)
span now covers 0-based 25..35; first row = "💬: q4"
  question after first row inside span? false
reconcile_exchange(stale, 3) -> true
AFTER:  📎 at row 31 foldclosed=-1 (want 31)
hydrate_window again -> false          <- latched; nothing recreates it
```

Same probe with base `38a6cdd`'s `tool_folds.lua` + `fold_projection.lua` prepended to `runtimepath`: `AFTER: 📎 at row 31 foldclosed=31`. **The fold survives at base and dies at HEAD** — a regression, because the old start-row-only `zd` deleted nothing when the range list was empty.

`prepare_exchange_update` is affected identically and is worse: it has no re-derive fallback, only a skip-the-clear branch. Called alone on the stale model it produces the same result, and reports nothing:

```
prepare_exchange_update alone -> observer phases {prepare}
AFTER:  📎 at row 31 foldclosed=-1 (want 31)
```

It sits on the per-chunk streaming path (`chat_respond.lua:1743`, `tool_loop.lua:153`).

Reachability, stated honestly: this needs drift *plus* an offset that aligns `first_0` with some question line — narrower than round 3's "span lands in any question-free window". Deleting a whole upstream exchange of the same size does it (above); the streaming mirror is an upstream insertion of exactly `exchange_start(K) - exchange_start(M)` lines while a response streams.

**Fix — two levels; the first is one edit, the second is the durable one.**

*(a) Fail closed on the vacuous case (closes the reproduced hole now).* When `#ranges == 0` the span has **no** corroboration — range verification contributes nothing — and clearing buys nothing either, since there is nothing to create. Do not clear on a stale model in that case; re-derive first (the `changedtick` memo already bounds the cost) and use the fresh model's span. `prepare_exchange_update` needs the same re-derive path it currently lacks. In `model_fits` / its callers:

```lua
-- An empty range list makes verify_anchors vacuous, so the span check stands
-- alone — and an on-question anchor cannot tell THIS exchange's question from
-- a neighbour's. With nothing to create, refuse the stale span outright.
if #ranges == 0 then return false, nil, "span" end
```

I confirmed this closes the probe: the re-derive yields exchange 3's real span (`13..21`) and E4's fold at row 31 is untouched.

*(b) The residual, and the durable answer.* With a non-empty range list the aliasing is still possible in principle — it additionally requires the stale ranges to anchor on matching markers at the drifted rows, which is much harder but not impossible. Local text can never establish *identity*, only shape, which is why this predicate has now failed in four distinct ways (unverified → too strict → too loose → aliasable). The codebase already has the right primitive: `chat_lease.lua:35` anchors a response on an `invalidate=true` extmark precisely so a row position cannot drift silently. Anchoring each exchange start — or, narrower, recording the folds Parley created per exchange as extmarks and clearing only those plus the new desired ranges — makes the destructive scope O(folds), identity-exact under any mutation, and still fixes #200's original root cause (a drifted Parley fold is found because its extmark moved with it). Worth a follow-up issue if it does not fit inside M1.

**Regression test:** the probe above, on **both** `reconcile_exchange` and `prepare_exchange_update`, asserting the later `📎:` keeps `foldclosed == its own row`. No existing test reaches the "empty ranges + stale span aliased onto another exchange's question" shape, and no existing test drives `prepare_exchange_update`'s destructive path directly.

## 3. Important findings

**I1 — The re-derive backoff is a no-op for the case it was added for.**
`lua/parley/tool_folds.lua:180-185`, with `mark_rederive_unhelpful` at `:199-202`.

The guard reads `if hit and hit.model == nil and hit.failed_at and (now - hit.failed_at) < REDERIVE_RETRY_MS`. But `mark_rederive_unhelpful` — whose own docstring says "the re-derived model did not resolve the drift … even though the parse itself succeeded" — sets `failed_at` on an entry whose `model` is **non-nil**, so the `hit.model == nil` conjunct excludes exactly it. Only a parse that *returns nil* backs off. Measured, 10 reconciles each at a fresh changedtick (the streaming shape):

```
PARSE-SUCCEEDS-BUT-UNHELPFUL: provider calls over 10 ticks = 10
PARSE-RETURNS-NIL:            provider calls over 10 ticks = 1
```

So round 3's I1 is unresolved for persistent drift with a parseable buffer — the reachable case, e.g. a fresh model whose exchange count no longer contains `exchange_index` after the user deleted an earlier exchange mid-response. At round 3's measured 81.8 ms per re-parse on a 4325-line chat, that is a full-buffer parse per streamed chunk: O(chunks × buffer), i.e. the quadratic-in-answer-size shape the `Done when` forbids. Fix: drop the `hit.model == nil` conjunct — `failed_at` alone already means "the last re-derive did not help".

**I2 — `prepare_exchange_update`'s refusal is still silent and mis-reports (round-3 I5, second round open).**
`lua/parley/tool_folds.lua:270-278`. On span-verify failure it nils the span, skips the clear, and still emits `notify({phase = "prepare", ranges = <stale ranges>})` with no `report_drift` and no log line. An observer cannot distinguish "cleared" from "refused", so the `Done when` "a drifted exchange that cannot be folded says so — the refusal is not silent" holds only on the reconcile path. C1 shows this is the path that destroys folds, so it needs the diagnostic as much as the corrected check.

**I3 — README not updated for the operator-visible fold-ownership change (Docs gate; third round open).**
`README.md:159-160` is the only fold-facing user documentation (the `chat_shortcut_toggle_tool_folds` opt-in) and nothing in the window touches it. This milestone makes a manual `zf` created inside an exchange vanish on the next reconcile — an explicit operator decision recorded in the atlas and the plan `## Revisions`. The atlas is the agent-facing map; the README is where a user would look to find out why their fold disappeared. One sentence.

**I4 — `prepare_exchange_update` has no direct test of its destructive path (round-3 coverage note, still open).**
Every test in `tests/integration/tool_folds_spec.lua` reaches it through `with_exchange_update` or exercises `reconcile_exchange` instead. My probe shows it deletes a neighbour's fold on its own, before any mutation runs and with no reconcile to follow. Given it carries the same check with strictly less recovery, it needs its own case.

## 4. Minor findings

- `tool_folds.lua:165` — `setmetatable({}, {__mode = "k"})` is a no-op: buffer numbers are not collectable. Nothing clears `rederived[buf]` on `BufUnload`/`BufDelete`, though the sibling `initialized[buf]` is (`:389-392`), so each entry pins a whole parsed model for the session. (Carried from round 3.)
- `tool_folds.lua:242` — `report_drift` is passed `failed_index`, `which` and `ranges` from the **stale** `model_fits`; the refusal decision came from the fresh one at `:232`, whose returns are discarded. The logged "which half drifted" can name the wrong half. (Carried from round 3.)
- `tool_folds.lua:191` — `logged` is carried forward forever (`hit and hit.logged or false`) and never reset when drift resolves, so a later, unrelated drift episode on the same buffer logs nothing.
- `tool_folds.lua:106-119` vs `:121-130` — `covered_lines` and `span_lines` are near-identical row-map readers; since `desired_folds` asserts every range lies inside the span (`fold_projection.lua:120`), one span read would serve both verifiers instead of two overlapping buffer reads per chunk (`ARCH-DRY`, carried from rounds 2 and 3).
- `tool_folds.lua:364` — `foldtext()`'s `else` fallback still renders an off-marker fold as ordinary prose; the Log itself blames this branch for masking #200 for a whole session.
- `workshop/plans/000200-fold-reconciliation-plan.md:37` — the Core-concepts entry still documents `verify_span(first_0, last_0, lines, patterns)`; the shipped signature has a fifth `anchor_required` parameter, recorded only in `## Revisions`.
- `tests/integration/fold_invariants_spec.lua:17` shells `git ls-files` with no seam (`ARCH-MOCK`). The false "injectable seam" claim was correctly withdrawn and the comment is now honest; the direct external call remains.
- `workshop/issues/000200-user-question-is-folded.md:339-341` — the `0.067 ms` per-chunk figure predates the added `span_lines` + `verify_span` pass (round 2 measured 0.078 ms for the same shape), and it is the number the `Done when` is graded against.
- `make test` exits **2** in this environment, on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua` (`git init` → 128, `cannot copy … commit-msg.sample … Operation not permitted`). I measured `git init` failing under `.test-tmp` **and** under a plain repo-root subdirectory, and succeeding under `$HOME`, with this session's harness sandbox disabled — so the Log's "Outside the sandbox the same `git init` under `.test-tmp` succeeds … and `make test` exits 0" does not reproduce here. The Log's `TMPDIR` correction is right (`Makefile.parley:28` does set `TMPDIR="$(TEST_TMP)"`, reached via `Makefile` → `Makefile.local:4`). Neither spec contains the string `fold`. Since `sdlc close` consumes this text as `--verified`, phrase it as environment-dependent rather than an unconditional "exit 0".

**A correction I owe the record:** rounds 1–3 all flagged "`make perf` is cited as evidence for the fold path but `grep fold tests/perf/` is empty". That inference is wrong. `tests/perf/chat_typing.lua:138-158` calls `require("parley").setup(...)`, sets `filetype=markdown`, fires `BufEnter` and waits for production chat handlers to attach — and `init.lua:2030` calls `tool_folds.setup(buf)` on attach, so `hydrate_window` does run on the 100/1000/5000-line perf buffers. The accurate nit is narrower: `make perf` exercises hydration and typing, not the *streaming* reconcile path, so `workshop/issues/…:177` should not call it "streaming perf measured" — the direct per-chunk benchmark is what covers streaming.

## 5. Test coverage notes

- All three fold suites pass, run independently: `fold_projection_spec` 16/16, `tool_folds_spec` 19/19, `fold_invariants_spec` 12/12. Lint 0 warnings / 0 errors across 329 files.
- **The gap that shipped C1 is structural.** Every drift test in `tool_folds_spec.lua` drifts by an amount that leaves the stale span either straddling a question (`:215`) or landing in prose (`:250`). Nothing exercises an offset that *aligns* the stale start with another exchange's question — the one shape the anchor check cannot see. One fixture closes it.
- No test drives `prepare_exchange_update` directly (I4), and none pins the re-derive's repetition (I1). An observer assertion that N reconciles across N ticks trigger at most one re-derive per drift episode would pin the latter and would have failed today.
- The corpus harness exercises only the cold `hydrate_window` path, which the issue's own audit measured clean *before* the fix; it is a regression net over real shapes, not proof of the fix. The drift tests in `tool_folds_spec.lua` are. Still worth one Log line (carried from rounds 2 and 3).
- `tests/fixtures/fold_tool_transcript.md` is real coverage — the tracked corpus carries zero `tool_use`/`tool_result` blocks, so this fixture is the only place the issue's headline `🔧:`/`📎:` case meets live Neovim fold state.

## 6. Architectural notes

- **ARCH-DRY — pass, two nits.** `is_foldable()` and `ANCHOR_KIND` are single-sourced and consumed rather than restated, and the atlas prose that had drifted in round 3 now matches the code. Remaining: the `covered_lines`/`span_lines` pair, and the plan's stale `verify_span` signature. M2's three-owner fence grammar is the real DRY debt and stays correctly scoped there.
- **ARCH-PURE — pass.** Both predicates are pure and nvim-free, with buffer reads hoisted into the shell; the new `rederived` memo is module-level mutable state but sits in the IO shell (`tool_folds`), not the pure module — correct placement. Keep the C1 fix in that split: the shell decides which model to trust, the predicate stays a predicate.
- **ARCH-PURPOSE — flag (C1).** Shadow-sweep over *operations on fold state*. Round 1: destruction unverified. Round 2: the check stricter than the producer guarantees. Round 3: looser than the invariant requires. Round 4: shape-correct but identity-blind. Four rounds of patching one predicate is the signal — the purpose is that both Spec invariants hold *simultaneously and at all times*, and a row-span derived from a possibly-stale model cannot carry identity no matter how the predicate is written. The extmark primitive the codebase already uses for leases (`chat_lease.lua:35`) is the shape that can. Into M2 the same lens bites harder: once `chat_parser` suppresses markers inside tool bodies, exchange boundaries move, and `exchange_span` feeds a **destructive** operation — a fence-naive mis-segmentation there will delete folds, not merely mis-render them.
- **ARCH-MOCK — pass on the production path, minor in tests.** No external binary or service in production; `M._model_provider` / `M._observer` are real seams the tests drive. The only external call is `git ls-files` in `fold_invariants_spec.lua:17`, now honestly documented as a single point of definition rather than a seam.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — M1 boundary review round 4 (the anchor check aliases).** Round 3's revision claims the two-part rule ("starts on its own question, no question after the first row") closes the span hole. It does not: the anchor test cannot distinguish *this* exchange's question from any other exchange's, so a stale span aligned onto a later exchange's start passes both halves while the range check is vacuous. Reproduced against base vs HEAD (E4's `📎:` keeps `foldclosed=31` at `38a6cdd`, loses it at HEAD; `prepare_exchange_update` reproduces it alone). Record the rule actually adopted, and record explicitly that a stale row-span is not an identity — name the extmark-anchored direction as the durable fix, whether it lands here or as a follow-up issue.
- **Same entry — the 250 ms re-derive backoff does not bound the streaming path.** `rederive_model`'s guard requires `hit.model == nil`, which excludes exactly the entries `mark_rederive_unhelpful` marks. Measured 10 full parses over 10 ticks. Record the corrected guard and the measurement so round-3's I1 is not recorded as answered.
- **Correct the Core-concepts entry** (`:37`): `verify_span` takes five parameters, including `anchor_required`.
- Then in the issue: soften the `make test` verification wording to the environment-dependent form (`:354`, `:379-403`), and correct `:177` — `make perf` exercises fold hydration through the production attach path (`chat_typing.lua:138-158` → `init.lua:2030`), but not streaming; the direct per-chunk benchmark is the streaming evidence. The "perf harness never touches folds" claim carried from rounds 1–3 is wrong and should not propagate further.

---

## Re-review — 2026-08-20T17:09:39-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | c89793bcfd0209f80b6d944e474882cc854f1a9d..HEAD |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T17:09:39-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1's pure core is genuinely good — `fold_projection` is nvim-free and well-tested, `clear_folds_in_span` is both correct on hard fold shapes and measurably faster than the pre-#200 baseline, the drift re-derive heals rather than mutes, the atlas section is substantive, and lint is clean (0/0 across 331 files). What blocks SHIP is that round 4's headline mechanism — extmark identity — is **inert in the production path it was built for**. `anchor_from` runs only at `hydrate_window` and after a drift re-derive, and `hydrate_window` latches per buf/win; so the moment the user types one more question, `#ids ~= #model.exchanges` and `exchange_anchors.span` declines for *every* exchange for the rest of the session. Destruction then falls back to `verify_span`, the positional rule round 4 itself proved aliases. I reproduced the resulting failure end-to-end through the real streaming entry point (`with_exchange_update`): a streamed chunk into a new exchange that has no foldable block yet (`ranges == {}` ⇒ `model_fits` passes vacuously) clears a span that has aliased onto exchange 2's question and destroys exchange 2's `📎:` fold — silently (no drift event), permanently (nothing recreates it). That is the Spec's second invariant failing with exactly the persistence signature #200 exists to remove. Separately, a mutation test shows the whole identity mechanism is unpinned: stubbing `owned_span`'s identity call to `nil` leaves all 21 `tool_folds_spec` and 12 `fold_invariants_spec` tests green.

## 1. Strengths

- **`lua/parley/exchange_anchors.lua` is the right primitive, cleanly built.** `invalidate = true` marks, decline-don't-guess on a deleted bounding mark, and the module-header rationale ("a row-span is not an identity") is the correct diagnosis of rounds 1–3. `tests/unit/exchange_anchors_spec.lua` covers the mechanism itself well (10/10), including both aliasing guards. The idea is sound — only its wiring is incomplete.
- **`fold_projection` is genuinely pure and stayed that way** (`lua/parley/fold_projection.lua:62`, `:86`): callers hoist the buffer read into `covered_lines`/`span_lines` and hand a row→text map in. Textbook `ARCH-PURE`, and `is_foldable()`/`ANCHOR_KIND` name the policy and the `answer_structure`↔`highlight_structure` bridge exactly once.
- **`clear_folds_in_span` holds its performance claim and its safety bound** (`tool_folds.lua:69-88`). The `s:guard` bound against `E350` is a real hazard correctly anticipated, and the scaling test at `tests/integration/tool_folds_spec.lua:172` compares best-of-N minimums rather than wall clock — the right instrument, correctly named after the property it pins.
- **The re-derive memo + 250 ms backoff is exact, not approximate** (`tool_folds.lua:163-197`). Keying on `changedtick` cannot go stale silently, and the comment at `:178-181` explaining why the guard is *not* conditioned on `hit.model == nil` documents a genuinely subtle correction.
- **The atlas "Fold reconciliation" section** (`atlas/chat/exchange_model.md:57`) is real documentation of the contract, not a checkbox — the creation-is-verified / destruction-is-identified split is the actual lesson from four rounds and it is written down.

## 2. Critical findings

**C1 — Extmark identity declines for the whole session after the first added question, so destruction falls back to the aliasing positional rule; a streamed chunk permanently destroys a neighbouring exchange's tool fold, silently.**
`lua/parley/tool_folds.lua:226-235` (`owned_span`), `:213-217` + `:265` + `:372` (the only two `anchor_from` call sites), `lua/parley/exchange_anchors.lua:63` — `ARCH-PURPOSE`.

`anchor_from` is called from `hydrate_window` (which latches on `initialized[buf][win]`) and from the drift-recovery branch only. It is never called on a successful reconcile. So anchors are frozen at the exchange count the buffer had when the window was first hydrated, while `chat_respond:1523` re-parses a fresh model per response. Measured:

```
after hydrate: exchanges=2   anchored span ex2 = { 13, 20 }
after new question: model exchanges=3
  identity span ex1 = DECLINED   identity span ex2 = DECLINED   identity span ex3 = DECLINED
```

Every subsequent clear therefore uses `verify_span` — the rule round 4's own C1 showed cannot tell this exchange's rows from another's. Reproduced through the production entry point (`with_exchange_update`, i.e. the per-chunk streaming path), with no hand-built model:

```
hydrated:  📎 line 9 foldclosed=9    📎 line 17 foldclosed=17
live model: 3 exchanges, target=3, ranges for target = 0     <- vacuous verification
identity for target -> nil                                   <- anchors=2, model=3
stale target span starts at row 21 (0-based) = "💬: q2"       <- aliased onto exchange 2
after streamed chunk: 📎 line 17 foldclosed=17
after streamed chunk: 📎 line 25 foldclosed=-1               <- destroyed, no drift event
```

The steps are all ordinary: open a chat (hydrate), type the next question and send, then one buffer edit above that `with_exchange_update` did not wrap. The target exchange has no foldable block yet, so `ranges == {}` and `model_fits` returns true vacuously — no drift is detected, `reconcile` returns success, and `hydrate_window` will not re-run, so the fold is gone for the session.

Fix sketch — refresh identity whenever a model derived from the buffer is available, not only at hydrate and on drift. Validated: adding a re-anchor at the point the fresh model is adopted turns the same probe green (`📎 line 25 foldclosed=25`). Concretely, either (a) call `anchor_from(buf, model)` when `owned_span` declines *for a count reason* and the model was just parsed from this buffer (`chat_respond`'s fresh parse, `tool_loop`'s registered live model), or (b) have `exchange_anchors` expose a `refresh_if_stale(buf, starts)` that `reconcile_exchange` calls on the verified path. Whichever is chosen, the second half matters too: **when identity declines and `ranges` is empty, verification has proved nothing — the destructive path must refuse and report drift rather than fall through to `verify_span`.** A floor that silently destroys is worse than a refusal; the Done-when "a drifted exchange that cannot be folded says so" is not met on this path. Please also correct `atlas/chat/exchange_model.md:80-84`, which presents the decline as an exceptional "structural edit re-indexed the exchanges" case when it is the steady state.

## 3. Important findings

**I1 — Neither round-4 test exercises the identity path in `reconcile_exchange`; the mechanism is entirely unpinned.**
`tests/integration/tool_folds_spec.lua:291` and `:319`.

`:291` ("clears the rows an exchange actually owns after edits the model never saw") hydrates, reads spans, inserts lines, asserts the spans moved, then asserts every `📎:` still folds at its own row — but it never calls `reconcile_exchange` after the edit, so *nothing was cleared* and the second assertion is vacuous (Vim shifts manual folds on insertion by itself). `:319` ("falls back rather than trusting identity across a structural change") asserts only `anchors.span(buf, 2, 4) == nil`, duplicating `tests/unit/exchange_anchors_spec.lua:45`; it never drives the fallback through `reconcile_exchange`, which is what the name claims. Proof the gap is total: replacing the identity lookup in `owned_span` with `nil` leaves **21/21 `tool_folds_spec` and 12/12 `fold_invariants_spec` green**. Add a test in the shape of C1's probe — hydrate at N exchanges, append one, drift, reconcile the target through `with_exchange_update`, assert the neighbour's `📎:` keeps `foldclosed == its own row` — and one asserting `anchor_from` re-installs identity when the count changes.

**I2 — The plan's Core-concepts table omits `exchange_anchors`, and its Integration table still claims `tool_folds` is the only integration entity.**
`workshop/plans/000200-fold-reconciliation-plan.md:21-56` vs `lua/parley/exchange_anchors.lua`.

The module is fully designed in `## Revisions` (`:1523`), but the greppable table — the thing downstream work and the next review read — never gained a row. Its Integration table lists exactly one entity, which the code now contradicts. Add the row (`exchange_anchors` | `lua/parley/exchange_anchors.lua` | new | Neovim extmark namespace) with its injected-into / relationships notes, and state the identity-vs-verification split in Core concepts rather than only in the revision log.

**I3 — README not updated for the user-visible fold-ownership change.**
`README.md:159` mentions folds only for the toggle shortcut. M1 makes Parley delete **any** fold inside an exchange span, including a manual `zf` the operator created — an operator-decided contract change (recorded in the atlas and the issue's `## Revisions`) that changes what a user's own keystrokes do. One or two lines near `:159` stating "folds inside an exchange are owned by Parley and are recreated from the model on every reconcile; folds outside any exchange are untouched" closes the docs gate.

**I4 — The Log's verification evidence does not reproduce here, and the close gate consumes it as `--verified`.**
`workshop/issues/000200-user-question-is-folded.md` (M1 verification paragraphs).

I ran `make test` at HEAD with sandboxing disabled for this session: it exits **1**, on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua`. Characterised directly:

```
git init  /Users/xianxu/workspace/parley.nvim/.test-tmp/p1  -> rc=128 (cannot copy .../hooks/commit-msg.sample: Operation not permitted)
git init  /Users/xianxu/workspace/parley.nvim/p2            -> rc=128 (same)
git init  /Users/xianxu/p4                                  -> rc=0
```

So the restriction is scoped to the repo tree, not to `.test-tmp`, and it is not the agent sandbox (none is active). Neither spec contains the string `fold`, and lint is 0/0 — the substance ("unrelated to #200") is right. I cannot rule out a difference between my shell and yours, so the ask is not to re-litigate the mechanism but to state the claim with its environment qualifier: "`make test` exits 1 on two git-dependent specs in environments where `git init` cannot populate templates under the repo tree; both are unrelated to folding, and the fold suites are green" — rather than an unconditional "exit 0", and drop the "agent sandbox" attribution, which does not hold under measurement here.

## 4. Minor findings

- `lua/parley/tool_folds.lua:107` and `:123` — `covered_lines` and `span_lines` are near-identical row→text map readers; one helper taking either a range list or a pair (`ARCH-DRY`).
- `lua/parley/tool_folds.lua:230` — `projection.verify_span(buf and first_0, …)`: `buf` is always a truthy integer here, so `buf and` is a dead guard that reads as if it were checking something.
- `lua/parley/tool_folds.lua:163` — `setmetatable({}, { __mode = "k" })` is a no-op: keys are integer buffer handles, which are never collectable, so the memo table is never pruned. Either key it on the buffer's `nvim_buf_get_var` table, or clear it alongside `exchange_anchors.clear(buf)` in the `BufUnload`/`BufDelete` autocmd at `:424`.
- `lua/parley/exchange_anchors.lua:26` — when `nvim_buf_is_valid(buf)` is false, `M.set` returns without dropping `anchors[buf]`, so a stale id list survives for a dead (and possibly reused) handle. Call `M.clear` on that branch.
- `tests/unit/exchange_anchors_spec.lua` needs a live Neovim buffer and extmark API; TOOLING.md reserves `tests/unit/` for "pure logic, no Neovim APIs". `exchange_anchors` is an integration entity — the spec belongs under `tests/integration/`.
- `workshop/lessons.md` carries rounds 1–2's lessons but not the biggest one, from rounds 3–4: "a positional heuristic is not an identity; when a check must distinguish *this* instance from a structurally identical one, anchor it to a durable handle." Worth adding while it is fresh.

## 5. Test coverage notes

- Targeted suites at HEAD: `exchange_anchors_spec` 10/10, `fold_projection_spec` 16/16, `tool_folds_spec` 21/21, `fold_invariants_spec` 12/12. Lint 0 warnings / 0 errors across 331 files. Full `make test` exits 1 on the two git-dependent specs (I4).
- **The identity mechanism has zero effective coverage** (I1) — proven by mutation, not inferred.
- **No test constructs the round-4 C1 shape** (a stale span landing *exactly* on a later exchange's question). `:215` and `:260` are caught by `verify_span`'s anchor/interior rules, which is why they stay green with identity disabled; the aliasing case slips past both.
- **No test covers the vacuous-verification × declined-identity combination**, which is what makes C1 silent rather than merely wrong. A test asserting "when `ranges` is empty and identity declined, nothing is cleared and a drift event is emitted" would pin the fix directly.
- The corpus harness (`fold_invariants_spec`) remains cold-path only — it exercises `hydrate_window` on a fresh parse, which the issue's own audit measured clean before the fix. Correctly scoped as a regression net, but it cannot fail for the defect M1 exists to fix.

## 6. Architectural notes

- **ARCH-DRY — pass, two nits.** `is_foldable()`/`ANCHOR_KIND` are single-sourced and consumed (`fold_invariants_spec.lua:87` reads the accessor rather than restating the policy). Nits: the twin row-map readers, and the fold-ownership rule now stated in three prose places (module header, atlas, plan) that must be kept in step — acceptable, but note the atlas copy is currently the inaccurate one (C1).
- **ARCH-PURE — pass.** `fold_projection` stays nvim-free with the buffer read hoisted to the shell; `exchange_anchors` is a genuinely thin IO shell over the extmark API with no business logic. Keep the C1 fix on this side of the seam — the "when may identity be refreshed" rule is a policy decision and belongs in `tool_folds`/`fold_projection`, not inside `exchange_anchors`.
- **ARCH-PURPOSE — flag (C1).** The shadow-sweep here is over the two invariants the Spec states, and only one is defended in the production path. The milestone built the right mechanism and then wired it to two call sites that a live session leaves behind after the first question. "Follow-up" is not available for this: closing the aliasing hole *is* what round 4 was chartered to do, and the operator decided explicitly to fix identity inside M1 rather than defer it.
- **ARCH-MOCK — pass (n/a on the production path).** No external binary or service; `M._model_provider` / `M._observer` are real injected seams the tests drive. `git ls-files` in `fold_invariants_spec.lua:17` is the only external call, test-only, deliberately a single point of definition with the comment saying so — fine.

Going into M2: the fence-grammar work feeds `answer_structure` → `exchange_span`, which is now a **destructive** input. Any fence-naive mis-segmentation there no longer just mis-renders — it moves the rows a reconcile clears. Worth carrying the identity lens into M2's plan rather than re-deriving it at that boundary.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — Core concepts: `exchange_anchors` added (I2).** Add the missing table row under **Integration points** — `exchange_anchors` | `lua/parley/exchange_anchors.lua` | new | Neovim extmark namespace — with its relationships (consumed only by `tool_folds`; consumes no other module), and correct the standing claim that `tool_folds` is the only integration entity. State the creation-is-verified / destruction-is-identified split in Core concepts, not only in the round-4 revision entry.
- **2026-08-20 — M1 round 4 scope correction: identity refresh (C1).** The round-4 design says anchors are "refreshed only from a model that has verified against the buffer (hydration, and after a successful re-derive)". Record that this refresh set is insufficient: `hydrate_window` latches per buf/win, so after the first appended exchange `#ids ~= #model.exchanges` and identity declines for every exchange, permanently. Record the added refresh point, and record the second half — that with `ranges == {}` verification is vacuous, so a declined identity must refuse and report drift rather than fall through to `verify_span`. Reproduced through `with_exchange_update`; fix validated by probe.
- **2026-08-20 — Round-4 test coverage (I1).** Note that `tool_folds_spec.lua:291` and `:319` do not drive `reconcile_exchange` and so pin nothing about identity (mutation-verified), and name the two tests that replace them.

Then update the issue: `## Log`'s M1 verification paragraph per I4, and add a `## Log` entry for the C1 above so the "four scenarios hold together" table does not stand as the last word.

---

## Re-review — 2026-08-20T17:30:05-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | e01a399c6ba1df64f93ff1d0c6e4c075408721f7..e01a399c6ba1df64f93ff1d0c6e4c075408721f7 |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T17:30:05-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Round 5's fix is real and the mechanism is now load-bearing — I mutation-verified that disabling the reinstall makes `tool_folds_spec`'s new identity test fail (`📎` at row 25 → `foldclosed=-1`), so the round-5 C1 is genuinely closed and pinned, not merely asserted. All 66 fold tests pass (`fold_projection_spec` 22/22, `exchange_anchors_spec` 10/10, `tool_folds_spec` 22/22, `fold_invariants_spec` 12/12) and lint is 0/0 across 331 files, both as claimed. What blocks SHIP is that the commit message's own claim — "a decline routes to the re-derive instead of clearing rows we cannot prove we own" — is not what the code does: `owned_span` first calls `anchor_from(buf, model, …)` with the *caller's live, unverified* model, and its guard `verify_starts` has no completeness check, so any model whose exchange starts are a **prefix** of the buffer's questions installs identity. The last anchor then owns everything to end-of-buffer (`exchange_anchors.lua:67-68`), and the trailing exchanges' folds are destroyed. I reproduced this through the production per-chunk entry point (`with_exchange_update`, `chat_respond.lua:1743`): a neighbouring `📎:` goes `25 → foldclosed=-1`, with **no drift event**, and `hydrate_window` latches so nothing recreates it. That is the Spec's second invariant failing with the same silent-and-permanent signature #200 exists to remove, on the destructive path, inside the input domain `reconcile_exchange`'s own docstring declares ("any mutation not wrapped in `with_exchange_update`"). Separately the atlas now documents a function that no longer exists, and the README docs gate is open for the fourth consecutive round.

## 1. Strengths

- **The round-5 fix is pinned, not vacuous.** I ran the mutation round 5 used to prove the previous tests were empty: stubbing `exchange_anchors.set` to a no-op makes `tests/integration/tool_folds_spec.lua:327` fail (`reconcile → false`, `📎 25 → -1`). The reinstall path is genuinely covered this time.
- **Removing the positional fallback was the right call, and the refusal it routes to works.** With identity forced to decline, `reconcile_exchange` returns `false` and emits `drift` with `which="span"` and creates nothing — I measured it. `verify_starts`' relocation to install-time (`fold_projection.lua:51`) is the correct place for positional reasoning, and the docstring's justification of the exchange-1 exemption is accurate.
- **`fold_projection` is still genuinely pure** — the "loads without a Neovim global" test at `tests/unit/fold_projection_spec.lua:32` passes, and `span_lines`/`exchange_span` are gone, so `covered_lines` is now the single row-map reader (`ARCH-DRY` nit from round 5 resolved).
- **`clear_folds_in_span` (`tool_folds.lua:49-93`)** keeps both its properties: the `s:guard` E350 bound and the fold-to-fold `zj`/`zD` walk in one VimL crossing, with the scaling test comparing best-of-N minimums rather than wall clock.
- **The corpus harness's honesty improved.** `fold_invariants_spec.lua:39-47` now states outright that the real corpus carries zero tool blocks and names the fixtures that supply the shape, plus a `checked > 0` floor so a parser change cannot turn a file green-and-empty.

## 2. Critical findings

**C1 — `anchor_from` installs extmark identity from an unverified, possibly prefix-stale model; the last anchor then owns to EOF and a reconcile silently destroys the trailing exchanges' folds.**
`lua/parley/tool_folds.lua:224-229` (`owned_span`), `:197-210` (`anchor_from`), `lua/parley/fold_projection.lua:51-63` (`verify_starts`), `lua/parley/exchange_anchors.lua:22-24` and `:67-68` — `ARCH-PURPOSE`.

`exchange_anchors.set`'s own contract is written in the file: *"Call only with rows from a model that has verified against the buffer — anchoring a stale parse would install misleading identity."* Its only caller, `anchor_from`, substitutes `verify_starts`, which checks that the given starts are ascending, in-buffer, and (index > 1) on a question line. It does **not** check that the model accounts for every exchange in the buffer. A model whose exchanges are a *prefix* of the buffer's therefore passes trivially — and prefix-staleness is the canonical drift (the buffer gained a trailing exchange the model never saw; `chat_respond.lua:1922-1937` appends the next `💬:` prompt to the buffer without adding it to the model, outside `with_exchange_update`).

Reproduced through the production streaming entry, no hand-built model — two exchanges hydrated, chat grows to three and is folded through a fresh parse, then one `with_exchange_update` with the earlier two-exchange model:

```
BEFORE:  📎 9->9   📎 17->17   📎 25->25
AFTER:   📎 9->9   📎 17->17   📎 25->-1     drift_event=false
anchors span(ex2) before: { 13, 20 }  ->  after: { 13, 28 }
```

The chain: `owned_span` declines (3 anchors vs. 2 model exchanges) → `anchor_from` re-installs **2** anchors from the stale model (`verify_starts` passes: rows 5 and 13 are both question lines) → exchange 2 is now the last anchor, so its span runs to EOF and swallows exchange 3 → `model_fits` passes because exchange 2's own ranges are unchanged → the span is cleared with no verification and no report. `hydrate_window` latches, so `📎: t3` stays unfolded for the session. The destruction actually lands in `prepare_exchange_update` (`:300-304`), which clears on identity alone and never checks ranges at all.

I could **not** exhibit an end-user keystroke sequence at HEAD that leaves a prefix-stale model live long enough to be reconciled — every non-recursive `M.respond` re-parses, and `tool_loop.reset` drops the registered model. So this is an unsound guard on the destructive path rather than a defect I can demonstrate a user hitting today. I am still calling it Critical: handling a drifted model *is* this module's stated contract, five rounds of this review loop have each closed one instance of this class and opened the next, and the code does not do what its own commit message and its own module contract say it does.

Fix sketch — make the contract true rather than widening the heuristic. `anchor_from` should only be reachable with a model produced from the current buffer, which by construction covers it:

```lua
--- @param verified boolean  true only for a model just parsed from this buffer
local function owned_span(buf, model, exchange_index, patterns, verified)
    local first_0, last_0 = exchange_anchors.span(buf, exchange_index, #model.exchanges)
    if first_0 then return first_0, last_0 end
    if not verified then return nil end        -- decline -> re-derive, per the commit message
    if not anchor_from(buf, model, patterns) then return nil end
    return exchange_anchors.span(buf, exchange_index, #model.exchanges)
end
```

`reconcile_exchange:246` passes `false`; the drift branch's `owned_span(buf, fresh, …)` at `:259` and `hydrate_window:365` pass `true`. Cost is one extra parse when identity declines, already bounded by the `changedtick` memo and the 250 ms backoff. `prepare_exchange_update` gets the same `false` and must report drift when identity declines instead of silently clearing nothing (see I4).

Do **not** fix this by adding a completeness scan ("every `user_pattern` line in the buffer is one of the starts") to `verify_starts`: that would be correct today but becomes a trap at M2, where a `💬:` inside a fenced tool body stops forking an exchange — the scan would then see a question that is not a start, decline forever, and re-open round 2's permanent-refusal C1. If you go that route it must consume the M2 `fence` grammar, not a raw regex.

Regression test: the probe above — hydrate at N, grow the buffer and fold the tail through a fresh model, then drive `with_exchange_update` with the N-exchange model and assert the tail `📎:` keeps `foldclosed == its own row`.

## 3. Important findings

**I1 — The atlas documents a function that was deleted and a fallback that was removed.**
`atlas/chat/exchange_model.md:81-88` — AGENTS.md §8, `ARCH-DRY`.

The "Fold reconciliation" section says: *"The positional check (`verify_span`) remains only as the fallback floor for those cases, and its question-anchor requirement is waived for exchange 1…"*. `grep -rn verify_span lua/` returns nothing — round 5 replaced it with `verify_starts` and **deleted the fallback entirely** (`tool_folds.lua:219-223` says so explicitly: "There is deliberately no positional fallback"). The atlas is now the inaccurate copy of a rule stated in three places, and it also still frames the decline as an exceptional "structural edit re-indexed the exchanges" case, which round 5's C1 showed is the steady state — the correction round 5 asked for was not made. Rewrite the third bullet to: identity declines on count-mismatch or a deleted bounding mark; a decline routes to the re-derive, which installs identity from a fresh parse; `verify_starts` validates a whole model's starts at install time and is the only positional check left.

**I2 — README not updated for the user-visible fold-ownership change (Docs gate; fourth consecutive round open).**
`README.md:159`.

The README mentions folds only for the toggle shortcut. M1 makes Parley delete **any** fold inside an exchange span — including a manual `zf` the operator created — and round 5 widened that further: the last exchange's span now runs to end-of-buffer, so a manual fold in the trailing prose after the final block is cleared too (`tests/integration/tool_folds_spec.lua:42` converts `:39` to assert exactly this). That is a change to what a user's own keystrokes do, recorded in the atlas and the issue's `## Revisions` but nowhere a user reads. Two lines near `:159`: folds inside an exchange are owned by Parley and are recreated from the model on every reconcile — including the tail after the last block; folds outside every exchange span are untouched.

**I3 — Plan Core-concepts contradicts the code: it names `verify_span` as shipped and declares span verification complete.**
`workshop/plans/000200-fold-reconciliation-plan.md:37` and `:41`.

The `fold_projection` bullet still reads *"gains … `verify_span(first_0, last_0, lines, patterns, anchor_required)` guarding the destructive half"* and *"Future extensions: none outstanding — whole-range verification and **span verification** both shipped in M1."* Neither is true at HEAD: `verify_span` was removed and the destructive half is now guarded by identity, not by span verification. The Integration table correctly gained its `exchange_anchors` row (round-5 I2 addressed) and a later bullet does say `verify_starts` is "the remaining positional check" — so the plan contradicts itself. The greppable table is what the next boundary and downstream work read; fix the bullet, don't leave the correction only in `## Revisions`.

**I4 — `prepare_exchange_update`'s refusal is silent and mis-reports (round-3 I5, round-4 I2 — third round open, and now the destructive path).**
`lua/parley/tool_folds.lua:300-306`.

When `owned_span` returns nil, `clear_folds_in_span` no-ops on the nil guard at `:51`, nothing is cleared, no drift is reported, and the `notify({ phase = "prepare", … , ranges = ranges })` at `:305` still fires with the ranges as if they had been cleared. The Spec's Done-when — *"A drifted exchange that cannot be folded says so — the refusal is not silent"* — is met in `reconcile_exchange` and not here. This is also where C1's destruction actually lands, since `prepare` clears with **no range verification at all**: it is the one destructive path with neither guard. Route the decline through `report_drift` with `which = "span"`, and emit the prepare event with `ranges = {}` when nothing was cleared.

**I5 — No test covers the identity-declined refusal, which is the fix's whole second half.**
`tests/integration/tool_folds_spec.lua:243`.

The only drift-reporting test asserts `which == "ranges"` / `failed_index == 1`. Nothing asserts the `which == "span"` path — that when identity declines and `ranges` is empty (so `model_fits` is vacuously true), reconcile refuses, creates nothing, and emits a drift event. Round 5's C1 asked for exactly this test and it was not added; I had to stub `exchange_anchors.span` myself to confirm the behaviour is correct. That path is now the *only* thing standing between a declined identity and an unverified clear, so it should be pinned, not inferred.

## 4. Minor findings

- `lua/parley/tool_folds.lua:143` — `setmetatable({}, { __mode = "k" })` is still a no-op (integer buffer handles are never collectable) and `rederived[buf]` is still not dropped in the `BufUnload`/`BufDelete` autocmd at `:417-423`, which does clear `initialized` and `exchange_anchors`. Beyond the leak: a reused buffer handle whose `changedtick` matches the stale entry would be handed a foreign parsed model. Round-5 Minor, still open.
- `lua/parley/exchange_anchors.lua:25` — `M.set` returns without dropping `anchors[buf]` when the buffer is invalid, leaving a stale id list on a dead (possibly reused) handle. Round-5 Minor, still open.
- `tests/unit/exchange_anchors_spec.lua` creates buffers and calls the extmark API, but TOOLING.md reserves `tests/unit/` for "pure logic, no Neovim APIs", and the plan itself classifies `exchange_anchors` as an Integration entity. Belongs under `tests/integration/`. Round-5 Minor, still open.
- `lua/parley/tool_folds.lua:196` — `anchor_from`'s `@return boolean installed` is inaccurate: it returns `true` even when `exchange_anchors.set` internally bailed (invalid buffer, out-of-range row, extmark failure). Harmless today because `owned_span` re-reads through `span()`, but the name lies.
- `workshop/lessons.md` — the largest lesson of rounds 3-5 is still missing: *"a positional heuristic is not an identity; when a check must distinguish this instance from a structurally identical one, anchor it to a durable handle."* Round-5 Minor, still open; rounds 1-2's lessons are there.
- `lua/parley/tool_folds.lua:392-396` — `foldtext()`'s `else` fallback still renders a corrupt fold as ordinary text, which the issue's own root-cause chain (point 4) blames for masking #200 for a whole session. Not in the Done-when, so a note, not a gate: a debug line there would have surfaced this class immediately.

## 5. Test coverage notes

- Verified myself, unsandboxed: `fold_projection_spec` 22/22, `exchange_anchors_spec` 10/10, `tool_folds_spec` 22/22, `fold_invariants_spec` 12/12; `make lint` 0 warnings / 0 errors in 331 files. All match the Log.
- `make test` exits **1** in my environment, on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua`. `git init` fails with `Operation not permitted` here for *every* target I tried, including `/tmp` — so my environment cannot settle the mechanism and I am not re-litigating it (rounds 3 and 5 both did). Neither spec contains the string `fold`. The ask stands from round-5 I4 and is unchanged: the Log's unconditional "`make test` exit 0" is what `sdlc close` consumes as `--verified`; give it the environment qualifier ("exits 1 on two git-dependent specs where `git init` cannot populate templates; both unrelated to folding; fold suites green") rather than a bare claim a reviewer cannot reproduce.
- **Uncovered:** C1's prefix-stale shape; the `which == "span"` refusal (I5); `prepare_exchange_update`'s declined-identity path (round-3 coverage note, still open — it has no direct destructive-path test at all).
- The corpus harness remains cold-path only (`hydrate_window` on a fresh parse), which the issue's own audit measured clean *before* the fix. Correctly scoped as a regression net, and now honestly documented as such at `fold_invariants_spec.lua:39-47`.

## 6. Architectural notes

- **ARCH-DRY — pass, one flag.** `is_foldable()` / `ANCHOR_KIND` are single-sourced and actually consumed (`fold_invariants_spec.lua:87` reads the accessor). The twin row-map readers are gone. The flag is that the fold-ownership rule is stated in prose in three places (module header, atlas, plan) and the atlas and plan copies are both currently wrong (I1, I3) — three hand-maintained restatements of one contract is the shape that produced this.
- **ARCH-PURE — pass.** `fold_projection` stays nvim-free with the buffer read hoisted into `covered_lines`; `exchange_anchors` is a thin extmark shell with no business logic, and the "when may identity be installed" policy correctly lives in `tool_folds`, not inside it. Keep C1's fix on that side of the seam — `owned_span` gaining a `verified` parameter is a policy change in the shell, which is right.
- **ARCH-PURPOSE — flag (C1).** Shadow-sweep over the Spec's two invariants: "a question is never folded" is defended on both halves; "`🔧:`/`📎:`/`📝:`/`🧠:` are always folded" is defended on creation and still loses on destruction when the model lags the buffer. The milestone built the right primitive twice and each time wired it with a guard weaker than the property it is meant to establish.
- **ARCH-MOCK — pass, n/a.** No external binary or service on the production path. `M._model_provider` / `M._observer` are real injected seams the tests drive (I used both). `git ls-files` in `fold_invariants_spec.lua:17` is test-only and honestly labelled as a single point of definition rather than an injection seam — the withdrawn round-2 claim stays withdrawn.
- **Going into M2:** `answer_structure` feeds exchange segmentation, which is now a **destructive** input — a fence-naive mis-segmentation moves the rows a reconcile clears, not just what renders. And note the interaction flagged in C1: whatever M2 does to stop a `💬:` inside a tool body forking an exchange changes what "every question line in the buffer" means, so any completeness check added to `verify_starts` must consume the `fence` grammar rather than `user_pattern` directly.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — Core concepts corrected: `verify_span` no longer exists (I3).** Round 5 replaced it with `verify_starts` and removed the positional fallback entirely. Fix the `fold_projection` bullet at `:37` to list `anchor_kind`, `verify_anchors`, `verify_starts`, `is_foldable`, and replace `:41`'s "whole-range verification and span verification both shipped in M1" with the actual delivered shape: creation is verified by `verify_anchors`; destruction is identified by `exchange_anchors`; `verify_starts` guards the identity *install*, not the clear.
- **2026-08-20 — M1 round 5 scope correction: identity may only be installed from a model derived from the buffer (C1).** Record that `owned_span`'s reinstall passes the caller's live model to `anchor_from`, that `verify_starts` accepts a model whose starts are a prefix of the buffer's questions, and that the last anchor owning to end-of-buffer then makes a prefix-stale model destroy the trailing exchanges' folds — reproduced through `with_exchange_update` (`📎 25 → foldclosed=-1`, no drift event). Record the chosen fix (decline routes to the re-derive; `anchor_from` reachable only from a just-parsed model) and the M2 trap that rules out a `user_pattern`-based completeness check.
- **2026-08-20 — Destructive-path guards are asymmetric (I4).** Record that `prepare_exchange_update` clears on identity alone with no range verification and no drift report, and that its declined-identity branch is the one destructive path with neither guard; name the test that pins it.

Then update the issue: correct the round-5 `## Log` "Verification" paragraph per the environment qualifier in §5, and add a `## Log` entry for C1 so the round-5 "all five scenarios still hold" table is not left standing as the last word.
