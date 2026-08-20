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
