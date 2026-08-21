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

---

## Re-review — 2026-08-20T17:55:36-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 7a2529453f9a9affd9a62c87d89eb47dd6627152..7a2529453f9a9affd9a62c87d89eb47dd6627152 |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T17:55:36-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The extmark-identity design is the right answer to five rounds of positional heuristics, and the milestone's headline symptom is genuinely fixed and well pinned: a drifted model no longer anchors a fold on `💬:`, no longer throws `E16`, and the four earlier C1 scenarios each have a regression test with teeth. What blocks SHIP is that `exchange_anchors.span`'s aliasing guard is still one-sided — it checks the anchor *count* and only the two marks bounding `k`, so any **compensating** structural edit (delete one exchange, add another) keeps `#ids == count` while leaving anchor *k* describing a different exchange than model index *k*. I reproduced this twice through the production streaming entry (`with_exchange_update`, `chat_respond.lua:1743`) with a *fresh* parse as the model: a neighbouring `📎:` goes `17 → foldclosed=-1` with `drift_event=false`, and `hydrate_window` latches so nothing recreates it — the Spec's second invariant failing with exactly the silent-and-permanent signature #200 exists to remove, on the destructive path this milestone widened. Separately, the in-suite scaling test that the Spec's Done-when names as the pin for the streaming-perf criterion never creates or clears a fold at all (every `reconcile_exchange` call in it refuses), so that Done-when is not actually pinned; and four round-6 findings (atlas `verify_span`, plan Core-concepts, README, the `which == "span"` test) are unaddressed.

## 1. Strengths

- **The identity split is the right architecture and is honestly documented.** `lua/parley/exchange_anchors.lua:1-16` and `atlas/chat/exchange_model.md:69-80` state the actual insight — creation is *verified*, destruction is *identified*, and the two halves cannot share one guard. That is a real architectural gain over four rounds of sharpening one positional predicate.
- **The `verified` gate added this round is correct and load-bearing.** I confirmed `tests/integration/tool_folds_spec.lua:380` ("does not install identity from a model that stops short of the buffer") drives the prefix-stale shape through `with_exchange_update` with no hand-built model, and it is the round-6 C1 repro turned into a test.
- **`clear_folds_in_span` (`lua/parley/tool_folds.lua:49-93`) genuinely delivers its performance property.** Wiring the module seam into the scaling scenario myself, 16× the rows costs 2.0× the time (0.77 ms → 1.54 ms) — the fold-to-fold `zj`/`zD` walk is real, and the `s:guard` E350 bound is a sound absolute stop.
- **`fold_projection` is still genuinely pure.** The "loads without a Neovim global" case at `tests/unit/fold_projection_spec.lua:32` passes; `covered_lines` is the single row-map reader; `is_foldable()` is an accessor and the corpus oracle actually consumes it (`fold_invariants_spec.lua:87`) rather than restating the policy.
- **The corpus harness is honest about its own limits.** `fold_invariants_spec.lua:39-47` states outright that the real corpus carries zero tool blocks and names the fixtures that supply the shape, with a `checked > 0` floor. Verified: 12/12, and `make lint` is 0 warnings / 0 errors across 331 files exactly as the Log claims.

## 2. Critical findings

**C1 — `exchange_anchors.span` aliases when a structural edit deletes one exchange and adds another: anchor *k* then describes a different exchange, and the clear silently destroys a neighbour's tool folds, permanently.**
`lua/parley/exchange_anchors.lua:55-77` (`M.span`), `lua/parley/tool_folds.lua:225-231` (`owned_span`), `:246-283` (`reconcile_exchange`) — `ARCH-PURPOSE`.

The module's own contract says the count check is what stops aliasing: *"a structural edit that adds or removes an exchange makes anchor k describe a different exchange than model index k, which is exactly the aliasing this module exists to prevent"* (`exchange_anchors.lua:52-54`). But `#ids ~= count` is defeated by any edit pair that nets to zero, and `span` validates only marks `k` and `k+1` — an invalid mark *below* `k` is never noticed. So after "delete an earlier exchange, ask a new question", the anchors are stale, the count matches, and `owned_span` hands back rows the exchange does not own — with `verified = false`, so nothing re-derives and nothing reports.

Reproduced through the production per-chunk path, model = a fresh `chat_parser` parse of the current buffer (the same shape `chat_respond.lua:1523-1524` builds), so `model_fits` passes and the drift branch never runs:

```
HYDRATED (4 exchanges):        t1@9->9   t2@17->17  t3@25->25  t4@33->33
AFTER delete-ex2 + append q5:  t1@9->9   t3@17->17  t4@25->25  t5@33->-1
  span(1,4)=nil  span(2,4)=nil  span(3,4)={13,20}  span(4,4)={21,36}
AFTER with_exchange_update(fresh, 3):
                               t1@9->9   t3@17->-1  t4@25->25  t5@33->33
  drift_event=false
```

`📎: t3` loses its fold and nothing recreates it — `hydrate_window` latches per buf/win, and streaming reconciles only the target exchange. The three-exchange variant is the same, via the last anchor's unbounded span-to-EOF: `span(3,3)={13,28}` covers model exchanges 2 *and* 3, and `📎: t3` goes `17 → -1`. Only a forced full `apply_folds` (which reconciles `k=1` first, declines, and reinstalls identity) heals it.

This is a regression the milestone introduced: pre-#200 `delete_projected_folds` only `zd`'d at projected start rows and could not reach a neighbour. The user sequence is ordinary parley usage — prune an old exchange to shed context, then ask the next question.

Fix sketch — make `span` decline whenever the index→exchange mapping *could* have shifted, not only when the count changed:

```lua
function M.span(buf, k, count)
    if not vim.api.nvim_buf_is_valid(buf) then return nil end
    local ids = anchors[buf]
    if not ids or #ids == 0 or #ids ~= count then return nil end
    if k < 1 or k > #ids then return nil end
    -- EVERY anchor must still resolve, ascending. One deleted line anywhere
    -- means index k may no longer be exchange k — a compensating delete+add
    -- keeps the count equal while re-indexing the exchanges.
    local rows, previous = {}, -1
    for i = 1, #ids do
        local row = anchor_row(buf, ids, i)
        if not row or row <= previous then return nil end
        rows[i], previous = row, row
    end
    ...
end
```

A decline routes to the re-derive, which reinstalls identity from a fresh parse — verified to heal both probes. Cost is one extra parse, already bounded by the `changedtick` memo and the 250 ms backoff (the same trade round 6 accepted). Also worth closing in the same edit: `owned_span` with `verified = true` (`tool_folds.lua:226`) reads `exchange_anchors.span` *before* reinstalling, so even the drift branch prefers possibly-stale marks over the just-parsed model it is holding — prefer `anchor_from` when a verified model is in hand.

Regression test: the probe above — hydrate N exchanges, delete a middle one and append a new one, then drive `with_exchange_update(buf, fresh_parse, #exchanges, function() end)` and assert every `📎:` still has `foldclosed == its own row`.

## 3. Important findings

**I1 — The scaling test never creates or clears a fold; the Done-when it is named as pinning is unpinned.**
`tests/integration/tool_folds_spec.lua:188-224`.

The test builds a hand model but does not call the file's own `truth()` helper, so `_model_provider` is nil and the probe buffer has no `---` frontmatter — `default_model_provider` returns nil. I instrumented it: every `reconcile_exchange` call returns `false` with `phase="drift"`, `foldclosed(7) == -1`, at both 50 and 800 body rows. Both timings measure the refusal early-return (bounded further by the 250 ms backoff), so `large < small * 6 + 3` passes vacuously and a return to O(span) clearing would not be caught. The Spec's Done-when — *"Measured per-chunk … and pinned by an in-suite scaling test"* — is therefore not met by this test. Fix: add `truth(model)` before the first reconcile (the same one-line fixture change round 6 applied to the other seven tests) and assert `reconcile_exchange` returns true / `foldclosed` is the fold row before timing. I verified this makes the path real *and* the property still holds: 0.77 ms → 1.54 ms for 16× the rows.

**I2 — `tests/unit/fold_projection_spec.lua:180-266` is a byte-identical copy of `:49-135`.**
Seven `it()` cases are defined and run twice (`anchor verification` appears twice in the output). Beyond the ARCH-DRY hazard of two copies silently diverging, the "22/22" figure the issue Log reports — and `sdlc close` consumes as verification evidence — is inflated: 15 distinct cases, not 22. Delete `:180-266` (keep the first copy, which carries the `#200` rationale comment at `:45-48`) and correct the Log's counts.

**I3 — The atlas still documents `verify_span` and a fallback that no longer exists (round-6 I1, unaddressed).**
`atlas/chat/exchange_model.md:83-85` — AGENTS.md §8.

*"The positional check (`verify_span`) remains only as the fallback floor for those cases…"* — `grep -rn verify_span lua/` returns nothing, and `tool_folds.lua:219-223` says explicitly "There is deliberately no positional fallback". This is the third hand-maintained restatement of the ownership contract (module header, atlas, plan) and the atlas copy is wrong. Rewrite: identity declines on count mismatch or a deleted bounding mark (and, per C1, on any unresolvable anchor); a decline routes to the re-derive, which installs identity from a fresh parse; `verify_starts` validates a whole model's starts at *install* time and is the only positional check left.

**I4 — Plan Core-concepts contradicts the code (round-6 I3, unaddressed).**
`workshop/plans/000200-fold-reconciliation-plan.md:37` and `:41`.

The `fold_projection` bullet still reads *"gains … `verify_span(first_0, last_0, lines, patterns, anchor_required)` guarding the destructive half"* and *"Future extensions: none outstanding — whole-range verification and span verification both shipped in M1."* Neither is true at HEAD; the later bullet at `:65` correctly names `verify_starts`, so the plan contradicts itself. The greppable table is what M2 and downstream work read — fix the bullet, don't leave the correction only in `## Revisions`.

**I5 — README not updated for the fold-ownership change (round-6 I2 — fifth consecutive round open).**
`README.md:159-160` — Docs update gate.

The README mentions folds only for the toggle shortcut. M1 makes Parley delete **any** fold inside an exchange span, including a manual `zf` the operator made, and round 5 widened the last exchange's span to end-of-buffer so a manual fold in the trailing prose is cleared too (`tests/integration/tool_folds_spec.lua:55` asserts exactly this). That is a change to what a user's own keystrokes do, recorded in the atlas and the plan but nowhere a user reads. Two lines near `:159`.

**I6 — No test pins the declined-identity refusal (round-6 I5, unaddressed).**
`tests/integration/tool_folds_spec.lua:255`.

`grep -rn '"span"\|identified' tests/` returns nothing. The only drift-reporting test asserts `which == "ranges"` / `failed_index == 1`. Nothing asserts that when identity declines and `ranges` is empty (so `model_fits` is vacuously true), reconcile refuses, creates nothing, and emits `which == "span"`; nothing asserts `prepare_exchange_update`'s new `identified = false` on the prepare event. That refusal is now the only thing standing between a declined identity and an unverified clear — it should be pinned, not inferred. (Round 6 asked for this; the round-6 Log answers the *design* question but not the coverage one.)

## 4. Minor findings

- `lua/parley/tool_folds.lua:143` — `setmetatable({}, {__mode = "k"})` is still a no-op (integer buffer handles are never collectable) and `rederived[buf]` is still not dropped in the `BufUnload`/`BufDelete` callback at `:441-447`, which does clear `initialized` and `exchange_anchors`. Round-5/6 Minor, still open.
- `lua/parley/exchange_anchors.lua:25` — `M.set` returns without dropping `anchors[buf]` when the buffer is invalid, leaving a stale id list. Round-5/6 Minor, still open.
- `tests/unit/exchange_anchors_spec.lua` creates buffers and calls the extmark API, but TOOLING.md reserves `tests/unit/` for "pure logic, no Neovim APIs" and the plan classifies `exchange_anchors` as an Integration entity. Belongs under `tests/integration/`. Round-5/6 Minor, still open.
- `lua/parley/tool_folds.lua:196` — `anchor_from`'s `@return boolean installed` still returns `true` when `exchange_anchors.set` internally bailed. Harmless (the caller re-reads through `span()`), but the name lies. Round-6 Minor, still open.
- `workshop/lessons.md` — the largest lesson of rounds 3-6 is still missing: *a positional heuristic is not an identity; when a check must distinguish this instance from a structurally identical one, anchor it to a durable handle — and only install that handle from a source derived from current truth.* Round-5/6 Minor, still open; C1 adds the corollary that a count check is not an identity check either.
- `lua/parley/tool_folds.lua:392-396` — `foldtext()`'s `else` fallback still renders a corrupt fold as ordinary text, which the issue's own root-cause chain blames for masking #200 for a whole session. Round-6 Minor, still open.
- `lua/parley/tool_folds.lua:293-301` — two stacked comment blocks say the same thing ("Same destructive operation as reconcile, so the same rule…" then "Destructive, so the same rule as reconcile…"); collapse to one.
- `lua/parley/tool_folds.lua:82-84` — the `break` when `foldlevel` is still > 0 after `zD` gives up on the rest of the span silently. Correct as a hang guard, but a debug line there would surface an E350 rather than degrade to a partial clear.

## 5. Test coverage notes

- Verified myself: `fold_projection_spec` 22/22 (15 distinct — see I2), `exchange_anchors_spec` 10/10, `tool_folds_spec` 23/23, `fold_invariants_spec` 12/12; `make lint` 0 warnings / 0 errors in 331 files. All match the Log.
- `make test` exits 1 here on `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua`. I confirmed the Log's mechanism directly rather than re-litigating it: `git init .test-tmp/probe_gi` fails with `fatal: cannot copy '…/templates/hooks/commit-msg.sample' … Operation not permitted`, and this session's environment also denies `/tmp` writes and process substitution. Neither spec contains the string `fold`. The Log's environment qualifier (round 6) is accurate as written.
- **Uncovered:** C1's compensating delete+add shape (no test drives a structural edit that preserves the exchange count); the `which == "span"` refusal and `prepare`'s `identified = false` (I6); the span-clear performance property, which I1 shows is asserted but never exercised.
- The corpus harness remains cold-path only (`hydrate_window` on a fresh parse), which the issue's own audit measured clean *before* the fix — correctly scoped as a regression net and honestly labelled at `fold_invariants_spec.lua:39-47`.

## 6. Architectural notes

- **ARCH-DRY — flag (I2, I3, I4).** `is_foldable()` / `ANCHOR_KIND` are single-sourced and actually consumed, and the twin row-map readers are gone. But the diff ships a verbatim duplicated 87-line test block (I2), and the fold-ownership contract is stated in prose in three places (module header, atlas, plan) with two of the three currently wrong — three hand-maintained restatements of one contract is precisely the shape that produced this issue.
- **ARCH-PURE — pass.** `fold_projection` stays nvim-free with the buffer read hoisted into `covered_lines`; `exchange_anchors` is a thin extmark shell with no business logic; the "when may identity be installed" policy correctly lives in `tool_folds`, not inside it. Keep C1's fix on that side of the seam — the all-anchors-resolve rule belongs in `span` (a property of the marks) while the reinstall decision stays in `owned_span`.
- **ARCH-PURPOSE — flag (C1).** Shadow-sweep over the Spec's two invariants: *"a question is never folded"* is defended on both halves and pinned by six scenarios. *"`🔧:`/`📎:`/`📝:`/`🧠:` are always folded"* is defended on creation and still loses on destruction — this round moved the failure from a stale *model* to stale *anchors*, but the outcome for the user is identical: a neighbour's tool fold vanishes, silently, for the session. The milestone has now built the right primitive twice and each time guarded it with a predicate weaker than the property it must establish (count ≠ identity, just as span ≠ identity).
- **ARCH-MOCK — pass, n/a.** No external binary or service on the production path. `M._model_provider` / `M._observer` are real injected seams I drove directly. `git ls-files` in `fold_invariants_spec.lua:17` is test-only and honestly labelled as a single point of definition rather than an injection seam.
- **Going into M2:** the interaction flagged in round 6 stands and now has a second edge. Whatever M2 does to stop a `💬:` inside a fenced tool body forking an exchange changes both what "every question line is a start" means (so any completeness scan added to `verify_starts` must consume the `fence` grammar) *and* what the exchange count is — which C1 shows is load-bearing for identity. A fence fix that changes `#model.exchanges` on existing transcripts will make identity decline across the corpus on first parse; budget one re-derive per buffer for that, and re-run `fold_invariants_spec` as the canary.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — Core concepts corrected: `verify_span` no longer exists (round-6 I3, still open).** Fix the `fold_projection` bullet at `:37` to list `anchor_kind`, `verify_anchors`, `verify_starts`, `is_foldable`, and replace `:41`'s "whole-range verification and span verification both shipped in M1" with the delivered shape: creation is verified by `verify_anchors`; destruction is identified by `exchange_anchors`; `verify_starts` guards the identity *install*, not the clear.
- **2026-08-20 — M1 round 7: the anchor-count guard is not an identity check (C1).** Record that `#ids ~= count` is defeated by a compensating structural edit (delete one exchange, add another) and that `span` validates only marks `k` and `k+1`, so an invalid mark below `k` goes unnoticed — reproduced through `with_exchange_update` with a fresh parse (`📎 17 → foldclosed=-1`, `drift_event=false`, both at the terminal anchor's span-to-EOF and at a non-terminal index). Record the fix (every anchor must resolve and be strictly ascending, else decline to the re-derive; `owned_span(verified=true)` prefers reinstalling over remembered marks) and name the regression test.
- **2026-08-20 — Task 3 Step 6's scaling pin was vacuous (I1).** Record that `tests/integration/tool_folds_spec.lua:188` omitted the `truth()` seam, so every `reconcile_exchange` in it refused (`which="span"`, `foldclosed=-1`) and the timing measured the refusal path; the Spec's streaming-perf Done-when was unpinned until the seam was wired. Note the re-measured real figures (50-row 0.77 ms vs 800-row 1.54 ms).

Then update the issue: correct the round-5/6 `## Log` test counts for the duplicated `fold_projection_spec` block (15 distinct cases, not 22), and add a `## Log` entry for C1 so the round-6 "all six scenarios hold" table is not left standing as the last word.

---

## Re-review — 2026-08-20T18:11:01-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | b48e1d2e829148ccd7df5c00f502fc7064bd7c12..b48e1d2e829148ccd7df5c00f502fc7064bd7c12 |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T18:11:01-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The extmark identity primitive is the right architecture and rounds 4–7 built it well: `exchange_anchors` is a clean, thin shell, `fold_projection` stayed genuinely pure, and I confirmed the six earlier scenarios all still hold. What blocks SHIP is a **new** failure axis that all seven prior rounds sit orthogonal to. Rounds 1–7 all asked "is the span I clear correct?" This one is: the span is *correct* — identity is intact — while the *ranges being created* come from the stale model, and **nothing checks that the two describe the same exchange**. Round 5's "creation is verified, destruction is identified" split severed the only coupling between them, and `model_fits` verifies ranges against line *content* only, never against the identified span. I reproduced at HEAD, through `with_exchange_update` with a real `chat_parser` model and no hand-built anything, an ordinary edit — insert 8 lines into an earlier exchange's answer, no deletion, no new question, every anchor valid — that silently deletes the streamed exchange's `📎:` fold (`drift_event=false`, nothing logged, nothing recreates it) while creating the fold on a *neighbour's* marker row. That is the Spec's second invariant failing with the exact persistence signature #200 exists to remove, and it is a regression: pre-#200 `delete_projected_folds` only `zd`'d at projected start rows and could not reach that fold. The fix is small and routes into machinery already proven to heal. Separately, five round-7 Important findings (I1–I5) are untouched at HEAD, including a scaling test I re-confirmed is measuring the refusal early-return, and a Docs-gate README miss now in its sixth consecutive round.

## 1. Strengths

- **The round-7 whole-mapping fix is real and load-bearing.** `exchange_anchors.span` (`lua/parley/exchange_anchors.lua:63-80`) resolving *every* anchor strictly ascending genuinely closes the compensating delete+add hole — I drove prune-one/add-one through `with_exchange_update` with a fresh parse and every `📎:` kept `foldclosed == its own row`. `tests/unit/exchange_anchors_spec.lua:66` and `:76` are the right two regression shapes.
- **Reinstall-before-read in `owned_span` (`tool_folds.lua:237-240`) is the correct ordering.** With a verified model in hand, a current-buffer parse strictly dominates marks that may predate the edit that caused the decline; the comment says exactly that and the code does exactly that.
- **The identity mechanism survives every ordinary edit I could construct.** I ran retext-a-question-in-place, delete-an-exchange, raw-append-an-exchange, insert-above, demote-a-question-to-prose, and demote+promote through hydrate → edit → `with_exchange_update(fresh_parse)`: all six hold both invariants, most without even needing a re-derive.
- **`fold_projection` is still genuinely pure** — `tests/unit/fold_projection_spec.lua:32` ("loads without a Neovim global") passes, buffer reads stay hoisted in `covered_lines`, and `is_foldable()`/`ANCHOR_KIND` name the policy and the `answer_structure`↔`highlight_structure` bridge exactly once, with `fold_invariants_spec.lua:87` actually consuming the accessor.
- **The corpus harness is honest about its own limits and the honesty is load-bearing.** `fold_invariants_spec.lua:39-47` states the real corpus has zero tool blocks, names the fixtures supplying that shape, and floors `checked > 0`. It also passing 12/12 is real evidence that `verify_starts` holds across every tracked transcript — if it did not, hydration would install no identity and every file would refuse.
- **Verified independently:** `fold_projection_spec` 22/22, `exchange_anchors_spec` 12/12, `tool_folds_spec` 24/24, `fold_invariants_spec` 12/12; `make lint` 0 warnings / 0 errors across 331 files — all exactly as the Log claims.

## 2. Critical findings

**C1 — Reconcile clears rows from identity but creates folds from the model, and nothing requires the two to describe the same exchange. An ordinary insertion into an earlier answer silently and permanently destroys a later exchange's tool fold.**
`lua/parley/tool_folds.lua:258` / `:261` / `:263` / `:295-301`, and `model_fits` at `:118-125` — `ARCH-PURPOSE`.

`ranges = projection.desired_folds(model, exchange_index)` is in **model** coordinates. `first_0, last_0 = owned_span(...)` is in **extmark** coordinates. `model_fits` checks each range's anchor line and interior against buffer *text* — it never checks `range ⊆ [first_0, last_0]`. The comment at `:120-121` makes the omission explicit ("The span is NOT checked here: it is established by identity in `owned_span`"), which is correct for *destruction* but leaves *creation* completely uncoupled from it.

So when a pure insertion shifts rows below it — no line deleted, no question added, count unchanged — identity stays perfectly correct while the model's rows go stale. If the drifted range lands on a same-kind marker with a clean interior (routine in a chat of uniformly-shaped exchanges, or a tool-loop answer with repeated `🔧:`/`📎:` pairs), `verify_anchors` passes, the drift branch never runs, and reconcile clears the exchange's *real* span while creating the fold on a *different* exchange's marker.

Reproduced at HEAD through the production entry point (`with_exchange_update`, model from a real `chat_parser` parse, nothing hand-built):

```
HYDRATED:  📎: t1@9->9   📎: t2@17->17   📎: t3@25->25
   (edit: insert 8 prose lines into exchange 1's answer — no deletion, no new question)
with_exchange_update(buf, model, 3, …) -> nil   drift_event=false
AFTER   :  📎: t1@9->9   📎: t2@25->25   📎: t3@33->-1
```

and the disjointness measured directly:

```
identity span for ex3 (0-based): 29..36
model range: tool_result rows 24..27   INSIDE SPAN = false
```

`📎: t3` is unfolded, **no drift event, no debug line**, and nothing recreates it — `hydrate_window` latches per buf/win and streaming reconciles only `target_idx`. Gone for the session. Confirmed the re-derive branch would heal it: `reconcile_exchange(buf, win, parse(buf), 3)` restores `t3@33->33`.

This is a regression this milestone introduces. At `38a6cdd`, `delete_projected_folds` (`tool_folds.lua:24-38` in that revision) only `zd`'d at projected start rows, so a fold at row 33 — which no projected start names — could not be deleted.

Fix sketch — restore the coupling with the containment check, right where both coordinate systems are in hand (`tool_folds.lua:263-264`):

```lua
local fits, failed_index, which = model_fits(buf, ranges, patterns)
if fits and first_0 == nil then fits, which = false, "span" end
-- Creation and destruction must describe the SAME exchange. Verification
-- proves a range matches the buffer's TEXT; only containment proves it
-- belongs to the rows identity says this exchange owns.
if fits then
    for index, range in ipairs(ranges) do
        if range.start_0 < first_0 or range.end_0 > last_0 then
            fits, failed_index, which = false, index, "span"
            break
        end
    end
end
```

This cannot reintroduce round 2's permanent refusal: `anchor_from` installs marks at `model:exchange_start(k)`, so a freshly-installed identity has `rows[k] == exchange_start(k)`, making the identity span equal to (last exchange: a superset of) the model's own exchange bounds — and `desired_folds` already asserts every range lies inside those bounds (`fold_projection.lua:113`). A verified re-derive therefore always satisfies containment. Cost is O(#ranges), not O(span), so it stays off the per-chunk scaling concern.

Regression test: the probe above — hydrate 3 uniform exchanges, insert N lines into exchange 1's answer where N is one exchange's height, then `with_exchange_update(buf, pre_edit_model, 3, function() end)` and assert every `📎:` still has `foldclosed == its own row`. Verified to fail at HEAD.

## 3. Important findings

**I1 — The scaling test still never creates or clears a fold; the Spec's streaming-perf Done-when remains unpinned.** (round-7 I1, unaddressed)
`tests/integration/tool_folds_spec.lua:187-224`.

`best_reconcile_ms` still omits the file's own `truth()` helper, so `_model_provider` is nil and the probe buffer has no `---` frontmatter. I instrumented it at HEAD:

```
reconcile_exchange returned: false
events: drift/span
foldclosed(7) = -1     foldlevel(7) = 0
```

Every call takes the refusal early-return (further collapsed by the `changedtick` memo and the 250 ms backoff), so `large < small * 6 + 3` passes vacuously and a return to O(span) clearing would not be caught. Fix is the same one-line change round 6 applied to the other seven tests: `local model = truth(...)` before the first reconcile, plus an assertion that `reconcile_exchange` returned true / `foldclosed` is the fold row before timing.

**I2 — `tests/unit/fold_projection_spec.lua:180-266` is still a byte-identical copy of `:49-135`.** (round-7 I2, unaddressed) — `ARCH-DRY`.
Verified with `diff`: identical. Seven `it()` cases are defined and run twice; the runner prints `anchor verification …` twice and reports 22 where there are 15 distinct cases. The issue's round-7 `## Log` still records "fold_projection_spec 22/22" as verification evidence, and `sdlc close` consumes that. Delete `:180-266` (keep the first copy, which carries the `#200` rationale at `:45-48`) and correct the Log counts.

**I3 — The atlas still documents `verify_span` and a positional fallback that do not exist, and its decline rule is now also stale.** (round-7 I3, third consecutive round) — AGENTS.md §8.
`atlas/chat/exchange_model.md:83-88`: *"The positional check (`verify_span`) remains only as the fallback floor for those cases…"* — `grep -rn verify_span lua/` returns nothing but a comment saying the opposite (`tool_folds.lua:228`, "There is deliberately no positional fallback"). The preceding sentence, *"when either bounding mark's line was deleted"*, is also stale since round 7: `span` now declines when **any** anchor anywhere fails to resolve or is out of order. Rewrite both: identity declines on count mismatch or on any unresolvable/non-ascending anchor; a decline routes to the re-derive, which installs identity from a fresh parse; `verify_starts` is the only positional check left and it guards the identity *install*, not the clear.

**I4 — Plan Core-concepts still contradicts the code.** (round-7 I4, unaddressed) — `ARCH-DRY`.
`workshop/plans/000200-fold-reconciliation-plan.md:37` still lists `verify_span(first_0, last_0, lines, patterns, anchor_required)` "guarding the destructive half", and `:41` still claims *"Future extensions: none outstanding — whole-range verification and span verification both shipped in M1."* Neither is true at HEAD, and `:65` in the same document correctly names `verify_starts` — the plan contradicts itself. The greppable table is what M2 reads; fix the bullet itself, not only `## Revisions`.

**I5 — README not updated for the fold-ownership change.** (round-7 I5, sixth consecutive round) — Docs update gate.
`README.md:159-160` mentions folds only for the toggle shortcut. M1 makes Parley delete **any** fold inside an exchange span, including a manual `zf`, and round 5 widened the last exchange's span to end-of-buffer so a manual fold in trailing prose is cleared too — `tests/integration/tool_folds_spec.lua:55` asserts exactly that. This changes what a user's own keystrokes do. It is written in the atlas and the plan and nowhere a user reads. Two lines near `:159`.

**I6 — No test pins the declined-identity refusal or `prepare`'s `identified` flag.** (round-7 I6, unaddressed)
`grep -rn '"span"\|identified' tests/` returns nothing. The only drift-reporting test (`tests/integration/tool_folds_spec.lua:255`) asserts `which == "ranges"`. Nothing asserts that when identity declines and `ranges` is empty — so `model_fits` is vacuously true — reconcile refuses, creates nothing, and reports `which == "span"`; nothing asserts `prepare_exchange_update`'s `identified = false` on the prepare event. That refusal is the only thing between a declined identity and an unverified clear.

## 4. Minor findings

- `lua/parley/tool_folds.lua:143` — `setmetatable({}, {__mode = "k"})` is still a no-op (integer buffer handles are never collectable), and `rederived[buf]` is still not dropped in the `BufUnload`/`BufDelete` callback at `:444-450`, which does clear `initialized` and `exchange_anchors`. Round-5/6/7 Minor, still open.
- `lua/parley/exchange_anchors.lua:25` — `M.set` returns without dropping `anchors[buf]` when the buffer is invalid, leaving a stale id list. Round-5/6/7 Minor, still open.
- `tests/unit/exchange_anchors_spec.lua` creates buffers and calls the extmark API, but TOOLING.md reserves `tests/unit/` for "pure logic, no Neovim APIs" and the plan's own table classifies `exchange_anchors` as an Integration entity. Belongs under `tests/integration/`. Round-5/6/7 Minor, still open.
- `lua/parley/tool_folds.lua:196` — `anchor_from`'s `@return boolean installed` still returns `true` when `exchange_anchors.set` internally bailed. Harmless (the caller re-reads through `span()`), but the name lies. Round-6/7 Minor, still open.
- `workshop/lessons.md` — the largest lesson of rounds 3–7 is still absent: *a positional heuristic is not an identity; a count is not an identity either; anchor to a durable handle and install it only from current truth.* The three entries added (`:653`, `:663`, `:674`) cover Lua scope, widening-destruction, and wall-clock tests. Round-5/6/7 Minor, still open — and C1 adds the corollary that identity and verification must also *agree with each other*.
- `lua/parley/tool_folds.lua:419-423` — `foldtext()`'s `else` fallback still renders a corrupt fold as ordinary text, which the issue's own root-cause chain blames for masking #200 for a whole session. Round-6/7 Minor, still open.
- `lua/parley/tool_folds.lua:311-318` — two stacked comment blocks say the same thing ("Same destructive operation as reconcile, so the same rule…" then "Destructive, so the same rule as reconcile…"); collapse to one. Round-7 Minor, still open.
- `lua/parley/tool_folds.lua:77-79` — the `break` when `foldlevel` is still > 0 after `zD` gives up on the rest of the span silently. Correct as a hang guard, but a debug line would surface an E350 rather than degrade to a partial clear. Round-7 Minor, still open.

## 5. Test coverage notes

- Verified myself: `fold_projection_spec` 22/22 (15 distinct — I2), `exchange_anchors_spec` 12/12, `tool_folds_spec` 24/24, `fold_invariants_spec` 12/12; `make lint` 0/0 across 331 files. All match the Log.
- **Uncovered — C1's shape:** every drift test in `tool_folds_spec.lua` drifts by an amount that makes the *span* wrong (`:229`, `:260`, `:307`, `:337`, `:373`, `:416`). None drifts by an amount that leaves the span **right** and the *ranges* landing on another exchange's same-kind marker. That is the one shape neither guard can see, and it is exactly the gap that shipped C1.
- **`make test` — measured, reported plainly.** Two full runs from a cleaned `.test-tmp`/`.test-home`/`.test-xdg`, both exit non-zero, each on a *different* pre-existing spec, neither containing the string `fold`:
  - Run 1: `tests/unit/tools_builtin_find_spec.lua` — "treats command substitution text in name as data" got `is_error = true`. It passes 4/4 in isolation. Consistent with the round-6 diagnosis (`find` over the repo root traversing scratch dirs that the 8 parallel jobs are actively populating), but note the round-7 Log's remediation claim — *"`make test` exit 0 after `rm -rf .test-tmp .test-home .test-xdg`"* — did **not** reproduce: I did exactly that and it still failed, because `PREP_TEST_ENV` recreates the dirs and the parallel jobs refill them during the run. The Log should record the honest state (still flaky from clean) rather than a remediation that does not hold.
  - Run 2: `git_markdown_source_spec.lua` and `markdown_finder_async_spec.lua` — `git init -q` exits 128, `cannot copy '/Library/Developer/CommandLineTools/.../commit-msg.sample' … Operation not permitted`. I reproduced this **with and without** the harness's `TMPDIR`/`HOME`, so it is this agent process's filesystem restriction, not the Makefile and not this diff. Not re-litigating further; three rounds have already been spent on it.
- The corpus harness remains cold-path only (`hydrate_window` on a fresh parse), correctly scoped as a regression net and honestly labelled — but that also means nothing in the suite exercises the warm streaming path against real transcripts, which is where C1 lives.

## 6. Architectural notes

- **ARCH-DRY — flag (I2, I3, I4).** `is_foldable()` / `ANCHOR_KIND` are single-sourced and actually consumed; `covered_lines` is the single row-map reader. But the diff still ships a byte-identical 87-line duplicated test block (I2), and the fold-ownership contract is restated in prose in three places — module header, atlas, plan — with **two of the three currently wrong** (I3, I4). Three hand-maintained restatements of one contract is precisely the shape that produced this issue.
- **ARCH-PURE — pass.** `fold_projection` stays nvim-free with the buffer read hoisted into `covered_lines` (the load-without-vim test passes); `exchange_anchors` is a thin extmark shell with no business logic; the "when may identity be installed" policy correctly lives in `tool_folds`. Keep C1's fix on that side of the seam — the containment check is a policy statement about reconcile's two inputs and belongs in `tool_folds` (or as a pure predicate in `fold_projection` taking `first_0, last_0, ranges`), not inside `exchange_anchors`.
- **ARCH-PURPOSE — flag (C1).** Shadow-sweep over the Spec's two invariants. *"A question is never inside a fold"* is defended on both halves and holds under every probe I ran — that half is done. *"`🔧:`/`📎:`/`📝:`/`🧠:` are always folded"* is still not: rounds 1–7 hardened the span, and this round the span is finally right, but the ranges that get *created* are checked against buffer text and never against that span. Eight rounds is the signal that the milestone has been checking one input at a time rather than stating the invariant once. The invariant is a single sentence — *the ranges I am about to create must lie inside the rows I am about to clear, and those rows must be exchange k's* — and it wants to be one check, not a growing family of them. The Done-when *"A drifted exchange that cannot be folded says so — the refusal is not silent"* is also unmet in this shape: C1 refuses nothing, reports nothing, and destroys.
- **ARCH-MOCK — pass, n/a.** No external binary or service on the production path. `M._model_provider` / `M._observer` are real injected seams I drove directly (both). `git ls-files` in `fold_invariants_spec.lua:17` is test-only and honestly labelled as a single point of definition rather than an injection seam.
- **Going into M2:** the round-6/7 interaction stands and C1 sharpens it. When `chat_parser` stops forking an exchange for a `💬:` inside a fenced tool body, `#model.exchanges` changes on existing transcripts, so identity declines corpus-wide on first parse (budget one re-derive per buffer; `fold_invariants_spec` is the canary). And because M2 moves *block* boundaries too, not just exchange boundaries, a fence-naive mis-segmentation will now shift the ranges as well as the span — which is precisely the C1 axis. Land the containment check before M2 touches `answer_structure`.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — M1 round 8: creation was never checked against identity (C1).** Record that `reconcile_exchange` takes `ranges` from the caller's model and `first_0/last_0` from extmark identity, and that `model_fits` verifies ranges only against buffer text — so a pure insertion above an exchange (identity correct, model stale) can pass verification on a *neighbour's* same-kind marker, clear the exchange's true span, and create the fold elsewhere. Reproduced through `with_exchange_update` with a real parse: `📎 33 → foldclosed=-1`, `drift_event=false`, identity span `29..36` vs range `24..27`. Record the fix (every range must lie inside the identified span, else route to the re-derive) and the argument that it cannot reintroduce a permanent refusal (`anchor_from` installs at `exchange_start`, so a freshly-installed identity always contains the fresh ranges). Name the regression test.
- **Fix Core concepts at `:37` and `:41` directly (round-6 I3 / round-7 I4, still open).** Replace `verify_span(first_0, last_0, lines, patterns, anchor_required)` with the actual `fold_projection` surface — `anchor_kind`, `verify_anchors`, `verify_starts`, `is_foldable` — and replace *"whole-range verification and span verification both shipped in M1"* with the delivered shape: creation is verified by `verify_anchors` **and contained by identity**; destruction is identified by `exchange_anchors`; `verify_starts` guards the identity install, not the clear. Do not leave this correction only in `## Revisions` — the table is what M2 greps.
- **2026-08-20 — Task 3 Step 6's scaling pin is still vacuous (round-7 I1, still open).** Record that `tests/integration/tool_folds_spec.lua:187` omits the `truth()` seam, so every `reconcile_exchange` in it refuses (`which="span"`, `foldclosed=-1`, `reconcile → false`, re-measured at HEAD) and the timings measure the refusal early-return; the Spec's streaming-perf Done-when is unpinned until the seam is wired.

Then update the issue: correct the `## Log` test counts for the duplicated `fold_projection_spec` block (15 distinct cases, not 22), soften the round-7 `make test` claim to what reproduces (still flaky from a cleaned scratch dir; `tools_builtin_find_spec` and the two `git init` specs each failed on a separate clean run here, none containing fold code), and add a round-8 entry so the "all six earlier scenarios still hold" table is not left standing as the last word.

---

## Re-review — 2026-08-20T18:31:05-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | bedc1a1dfe12a6a729ef69a8ea15edade80556e4..bedc1a1dfe12a6a729ef69a8ea15edade80556e4 |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T18:31:05-07:00 |
| verdict | unknown |

## Review

The review window is degenerate (Base == Head → empty diff). Since this is the M1 close boundary, I'll review M1's actual delivery: the branch range from the plan commit to HEAD.
API Error: Your computer went to sleep mid-response. The response above may be incomplete.

---

## Re-review — 2026-08-20T21:25:31-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | bedc1a1dfe12a6a729ef69a8ea15edade80556e4..296085ead910d98b2fb05c9b81f994aae60433cb |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T21:25:31-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 delivers what the Spec asked for, and I verified it rather than taking the Log's word: all five fold specs are green at the corrected count (15 + 12 + 1 + 25 + 12 = 65), lint is 0/0 across 331 files, and the window commit's claim — that a `describe("anchor verification")` block was duplicated — checks out exactly (the two blocks at `bedc1a1:49-138` and `:180-266` diff clean, and the surviving file has 15 `it()`s with zero duplicate names). I independently confirmed the two things prior rounds left doubt about: the scaling test is no longer vacuous (`reconcile → true`, fold created, 3 loop iterations at both 50 and 800 rows), and the extmark identity mechanism holds a fold outside every exchange span untouched. No Critical findings. What holds this back from SHIP is a set of cheap gaps: a duplicated policy table that can silently disable folding for a whole exchange (`ARCH-DRY`), an atlas section that names a function deleted three rounds ago and describes a fallback that was deliberately removed, a plan Core-concepts entry contradicting both the code and the plan's own text, a memo leak whose `__mode = "k"` guard provably does nothing for integer buffer handles, and the loss of the one test that pinned the *upper* bound of destruction — the exact axis eight review rounds were about.

## 1. Strengths

- **The creation/destruction split is the right architecture, and the code says why.** `tool_folds.lua:238-247` and `atlas`'s framing — "creation is *verified*, destruction is *identified*" — is a genuine insight earned across the rounds, and `owned_span`'s docstring explains the `verified` gate well enough that a future editor won't casually reopen round 6.
- **`verify_anchors`' interior scan is correctly and deliberately narrower than the full classifier** (`fold_projection.lua:85-95`). I walked `highlight_structure.classify`'s branch order: `footnote`, `=== label ===`, `^%s*```", `reasoning_end`, `reasoning` — none can claim a line starting `💬:` at column 0, so the direct `user_pattern` match is a strict over-approximation of `classify(...) == "user"`. It fails closed, and it keeps the per-chunk cost linear-and-cheap rather than ~10 patterns + a `require` per row.
- **The scaling test now measures the algorithm, not the machine.** `tests/integration/tool_folds_spec.lua:188` counting `_last_clear_iters` instead of wall-clock is the correct instrument, and my own probe confirms it: 3 iterations at 50 rows, 3 at 800.
- **The drift regression tests use the real parser and real buffer mutations,** not the `truth()` fake — `:127` builds its stale model from `chat_parser.parse_chat` and drifts it with `buffer_edit.insert_lines_at`, then asserts every `💬:` in the *post-mutation* buffer is unfolded and the real `📎:` healed. That's a pin on behavior, not on the implementation.
- **The corpus harness's oracle walks the parsed model and reads the policy from its owner** (`fold_invariants_spec.lua:87` calls `projection.is_foldable`), and floors the subject count so a corpus that vanishes fails loudly instead of going green-and-empty.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `FOLDABLE` and `ANCHOR_KIND` are two tables holding the same fact; drift between them silently kills folding for the whole exchange (`ARCH-DRY`).**
`lua/parley/fold_projection.lua:5-11` and `:22-27` list identical key sets. Add a fifth foldable kind to `FOLDABLE` alone and `desired_folds` emits a range whose `anchor_kind` is `nil`; `verify_anchors:80` then compares `classify(anchor).kind ~= nil` → false → `which="ranges"` → re-derive → identical result → **permanent refusal of the entire exchange**, not just that block. Nothing pins the agreement: `fold_projection_spec.lua:53-60` tests `anchor_kind` alone, `tool_folds_spec.lua` (unit) tests `desired_folds` alone. Fix: delete `FOLDABLE`, make `is_foldable(k)` return `ANCHOR_KIND[k] ~= nil`, and have `desired_folds:110` call `M.is_foldable(block.kind)`.

**I2 — the upper bound of destruction is now untested.** `clear_folds_in_span`'s docstring (`tool_folds.lua:48`) and the atlas both promise "folds outside every exchange span are untouched", but no test asserts it. The test that did — `tool_folds_spec.lua:39` — was converted in round 5 (last exchange now owns to EOF) and never replaced; `:55` and `:72` now both assert *clearing*, and `:93`'s "Contrast the case above, whose fold sits outside every span" points at a test that no longer demonstrates that. I verified the behavior still holds (a `1,4fold` over the frontmatter survives a reconcile that folds the `📎:` at row 10), so this is coverage, not a bug — but given the diff widened destruction twice, a regression pin on the one remaining untouched region is the cheapest insurance available. Fix: add a case folding the header rows before `exchange_start(1)` and asserting `foldclosed(1) == 1` after reconcile.

**I3 — atlas describes the round-4 design, not what shipped (Docs update gate).** `atlas/chat/exchange_model.md:84` says: "The positional check (`verify_span`) remains only as the fallback floor for those cases." Both halves are wrong at HEAD — `grep -rn verify_span lua/ tests/` returns nothing (renamed to `verify_starts` in round 5), and `owned_span`'s own comment states "There is deliberately no positional fallback." The section also enumerates "three properties" of the reconcile contract without the round-8 containment tie (`tool_folds.lua:279-286`), which is now load-bearing. Fix: rewrite that bullet to say identity declines route to the re-derive, name `verify_starts` as an *install-time* gate, and add containment as the fourth property.

**I4 — the plan's Core concepts entry contradicts the code and the plan's own Integration-points text.** `workshop/plans/000200-fold-reconciliation-plan.md:37` still says `fold_projection` gains `verify_span(first_0, last_0, lines, patterns, anchor_required)`, while `:65` (updated in round 5) correctly says `verify_starts`. The `## Revisions` record the rename at `:1592` but the Core-concepts body was never edited. Separately, `## Revisions` stops at round 7 — round 8's design change (tying creation ranges to the identified span; replacing the wall-clock scaling assertion with an iteration count) is recorded only in the issue `## Log`, not in the plan. See §7 for the entries.

**I5 — the re-derive memo leaks a parsed model per buffer, behind a guard that provably does nothing.** `tool_folds.lua:148` declares `rederived = setmetatable({}, { __mode = "k" })`, but the keys are integer buffer handles and Lua only collects *collectable* weak keys — I measured it: 1000/1000 integer-keyed entries survive two full `collectgarbage("collect")` passes, while table-keyed entries drop to 0. Meanwhile the `BufUnload`/`BufDelete` autocmd at `:466-472` clears `initialized[buf]` and `exchange_anchors`, but not `rederived[buf]`, so every chat buffer closed in a session leaves its last parsed `exchange_model` retained for the life of the process. Fix: add `rederived[buf] = nil` to that callback and drop the `__mode` metatable, which reads as a leak guard and isn't one.

## 4. Minor findings

- `tool_folds.lua:335-346` — two consecutive comment paragraphs say the same thing ("Same destructive operation as reconcile…" / "Destructive, so the same rule as reconcile…"); copy-paste leftover. Also `local first_0, last_0` at `:331` is declared two lines before its only assignment.
- `tool_folds.lua:242-246` — `owned_span` writes `return exchange_anchors.span(buf, exchange_index, #model.exchanges)` twice verbatim; collapses to `if verified and not anchor_from(...) then return nil end` + one return (`ARCH-DRY`).
- `tests/integration/tool_folds_spec.lua:180-186` — the comment still describes wall-clock sampling and comparing minima; the test counts iterations and samples nothing. `:93`'s cross-reference is stale in the same way (see I2).
- `fold_projection.lua:76` — `verify_anchors` `require`s `highlight_structure` unconditionally, even when `patterns` is passed, so it cannot run with `_G.vim = nil` (verified: fails in `vim/_init_packages.lua`), while `verify_starts` runs fine. The "loads without a Neovim global" test at `fold_projection_spec.lua:32` pins module *load* only, so the plan's "pure and nvim-free" claim is unpinned at call time.
- `tool_folds.lua:330` — `prepare_exchange_update` computes `desired_folds` solely to populate the observer event; that's per-streamed-chunk work for a test seam.
- `tool_folds.lua:93` — `M._last_clear_iters` is never reset on `clear_folds_in_span`'s three early-return paths, so a reader can pick up a stale count from a previous call.
- `tool_folds.lua:279-286` — the containment rule is pure logic (`ranges ⊆ [first_0, last_0]`) living in the IO shell, reachable only through an integration test (`:453`). Extracting it to `fold_projection` would make it unit-pinnable (`ARCH-PURE`).
- `tool_folds.lua:321` — the `%d,%dfold` creation loop is unprotected against E350, though `clear_folds_in_span:65-68` explicitly reasons about non-manual `foldmethod`. Pre-existing, but the asymmetry is newly visible now that one half handles it.
- `workshop/lessons.md` gained five good entries, but none covers the defect *this window fixed*: the existing "deleted tests do not fail" rule keys on a **shrinking** green suite, whereas a duplicated `describe` block makes it **grow** — which is exactly why the count check read as "I added tests" for four rounds. Add the `uniq -d` over `it("...")` names as its own rule (AGENTS.md §4).
- Round 6's Log diagnosed a shared-harness defect (`tools_builtin_find_spec` traverses a `.test-tmp` being mutated under it) and said it was "Worth its own issue" — no issue was filed, and the diagnosis will be archived to `workshop/history/` at close.
- README says nothing about the new fold-ownership contract. A manual `zf` inside an exchange — now including the entire tail of the buffer after the last block — is destroyed on the next reconcile. That is operator-visible and only documented in the atlas.
- `fold_invariants_spec.lua:17` calls `git ls-files` directly via `vim.fn.systemlist` (`ARCH-MOCK`: an external binary outside any seam). Mitigated — the `#corpus >= 8` floor turns a missing/failed `git` into a loud failure rather than a silently shrunken suite — so noting only.
- The plan doc's Task 1–5 step checkboxes are all still `- [ ]` although M1 is complete; the issue's `## Plan` is correctly ticked.

## 5. Test coverage notes

- **Suite state, measured here.** All five fold specs pass individually at 15/12/1/25/12. `make lint` is 0 warnings / 0 errors across 331 files. `make test` from a cleaned scratch dir fails on exactly two specs — `git_markdown_source_spec` and `markdown_finder_async_spec` — both at a `before_each` `git init` returning 128. I isolated the mechanism further than the Log did: `git init` succeeds outside the repo but fails in **any** directory under the repo root (I reproduced it in `.review-tmp/`, not just `.test-tmp/`), while `cp` of the very same template hook into the same directory succeeds. So it is a restriction on the `git` subprocess, not a filesystem permission, and `TMPDIR=$(CURDIR)/.test-tmp` is what places those specs inside the affected tree. Neither spec contains fold code. Not a finding against this diff — but the "`make test` green" Done-when is environment-conditional, and the issue Log's round-8 wording ("environment-sensitive") is the honest one.
- **Headline-marker coverage rests on one fixture.** The harness is transparent that the real corpus carries zero `tool_use`/`tool_result` blocks (`fold_invariants_spec.lua:39-42`), so the issue's own `🔧:`/`📎:` case is exercised by `fold_tool_transcript.md` alone among 11 subjects. The adversarial fixture is M2's Task 10, so this is per plan — flagging only so the "12/12 over the corpus" number isn't read as broader than it is.
- The `truth()` seam is used correctly: the tests that need a *real* parse (the drift and identity regressions at `:127`, `:302`, `:334`, `:375`, `:415`) don't use it; the ones that use it are bare block-layout fixtures with no frontmatter, which the default provider genuinely cannot parse.
- Unpinned: `classify(line).kind == "user"` ⟺ `line:match(user_pattern)`. `verify_anchors`' interior fast path depends on this and it holds today, but a reorder of `classify`'s branches would break it with no failing test. A small property test over the marker set would close it.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flagged** (I1, plus the `owned_span` duplicated return and the duplicated comment paragraph). The block-kind ↔ marker-kind mapping was correctly named once, which is what the plan committed to; the *foldability* fact is still stated twice.
- **ARCH-PURE — pass, with notes.** `fold_projection` calls no `vim.*` API and takes `lines`/`patterns` as data, which is the real content of the claim. Two seams sit on the wrong side: the containment rule is pure logic inside the shell, and `verify_anchors`' call-time `require` breaks the nvim-free property in practice.
- **ARCH-PURPOSE — pass.** Shadow-sweep of M1's scope: `verify_anchors` (anchor + interior), `clear_folds_in_span`, verify → re-derive → clear → create, the corpus harness, and the streaming measurement are all delivered and pinned; the two converted ownership tests were genuinely converted, not weakened. Nothing that *is* the point was deferred — the fence grammar is M2 by design, declared up front. One consequence worth carrying forward: under **sustained** drift the design deliberately refuses, so "🔧:/📎:/📝:/🧠: are always folded" holds for a cold parse and an in-sync model but not for a chat left drifted. `hydrate_window` latches per buf/win and the only bound keybinding toggles `foldenable`, so an operator in that state has no in-editor way to force re-hydration. Not a regression (pre-#200 had none either), but M2 or a follow-up should give the refusal an escape hatch — a `:ParleyRefold`-style command that clears `initialized[buf]` — otherwise the refusal path is correct and unrecoverable at the same time.
- **ARCH-MOCK — pass.** No external binary or service in the production fold path; extmark identity is exercised against real Neovim through the integration suite rather than a stateless double, and `_model_provider`/`_observer` are in-process seams over pure code, not stand-ins for an external dependency. Sole external call is the test-only `git ls-files`, noted above.
- **Verification scales with span, clearing scales with folds.** The Done-when constrains only the clear, and the clear is now O(#folds) — but `covered_lines` + `verify_anchors` remain O(foldable rows) per chunk. Measured: 0.032 ms at 50 rows → 0.166 ms at 3200 (clean linear, ~0.04 µs/row). Comfortably fine at real sizes, so no action; worth knowing before M2 adds fence-aware work to the same path.

## 7. Plan revision recommendations

Append to `workshop/plans/000200-fold-reconciliation-plan.md` `## Revisions`:

- **2026-08-20 — Core concepts corrected to match the shipped API.** The `fold_projection` bullet (`:37`) still advertised `verify_span(first_0, last_0, lines, patterns, anchor_required)`, which round 5 replaced with `verify_starts(starts_0, lines, patterns)` and moved from per-clear guarding to install-time gating. Line 65 was updated at the time; the Core-concepts body was not. Record that `verify_span` does not exist at HEAD and that `is_foldable` should derive from `ANCHOR_KIND` rather than a parallel `FOLDABLE` table.
- **2026-08-20 — M1 round 8: creation tied to destruction (no prior Revisions entry).** `model_fits` proves a range matches the buffer's *text*; identity proves which rows the exchange *owns*; nothing proved they described the same exchange. `reconcile_exchange` now requires every range to lie inside the identified span (`which="containment"`), and `model_fits` no longer reports on the span at all. Record it as the fourth property of the reconcile contract, alongside the same round's test-instrument change: the scaling assertion moved from wall-clock to `clear_folds_in_span`'s loop-iteration count exposed via `M._last_clear_iters`.
- **2026-08-20 — Task 5 Step 2 is not yet satisfied.** The atlas subsection landed but describes the round-4 design: it names `verify_span` and calls the positional check a "fallback floor" that round 5 deliberately removed, and it omits the containment tie. Re-open the step until `atlas/chat/exchange_model.md` matches HEAD.

Then, in the issue: note that `workshop/lessons.md` still lacks a rule for the duplicate-block defect corrected in this window (the existing rule keys on a shrinking suite; duplication grows it), and file the harness scratch-dir contention diagnosed in round 6 as its own issue before the round-6 Log is archived.

```findings
findings:
  - id: new
    severity: Important
    title: |
      FOLDABLE duplicates ANCHOR_KIND's key set; drift silently refuses the whole exchange
    detail: |
      fold_projection.lua:5-11 and :22-27 state "which kinds fold" twice. Adding a kind to
      FOLDABLE alone makes anchor_kind return nil, verify_anchors reject the range, and the
      re-derive reproduce it — a permanent refusal of the entire exchange, not just that
      block. No test pins the two key sets agree. Fix: delete FOLDABLE, define
      is_foldable(k) as ANCHOR_KIND[k] ~= nil, and have desired_folds call it (ARCH-DRY).
  - id: new
    severity: Important
    title: |
      No test pins "folds outside every exchange span are untouched"
    detail: |
      clear_folds_in_span's docstring (tool_folds.lua:48) and the atlas both promise it, but
      the only test that demonstrated it (tool_folds_spec.lua:39) was converted in round 5
      when the last exchange's span widened to EOF, and was not replaced. Verified the
      behavior still holds — a 1,4fold over the frontmatter survives a reconcile that folds
      the tool_result at row 10 — so this is coverage, not a bug. Given the diff widened
      destruction twice, add a case pinning the header region above exchange_start(1).
  - id: new
    severity: Important
    title: |
      atlas names verify_span and a positional fallback that were both removed in round 5
    detail: |
      atlas/chat/exchange_model.md:84 says "The positional check (verify_span) remains only
      as the fallback floor". grep -rn verify_span lua/ tests/ returns nothing, and
      owned_span's own comment reads "There is deliberately no positional fallback." The
      section also omits round 8's containment tie, which is load-bearing. Docs update gate.
  - id: new
    severity: Important
    title: |
      Plan Core-concepts entry contradicts the code and the plan's own line 65
    detail: |
      000200-fold-reconciliation-plan.md:37 still lists verify_span(first_0, last_0, lines,
      patterns, anchor_required) as what fold_projection gains, while :65 correctly names
      verify_starts. Separately, the plan's Revisions stop at round 7 — round 8's design
      change (creation ranges must lie inside the identified span; iteration-count scaling
      test) is recorded only in the issue Log. See the review's section 7 for both entries.
  - id: new
    severity: Important
    title: |
      rederived memo leaks a parsed model per buffer behind a no-op weak-key guard
    detail: |
      tool_folds.lua:148 uses __mode = "k" with integer buffer handles; Lua only collects
      collectable weak keys. Measured: 1000/1000 integer-keyed entries survive two full GC
      passes, table-keyed drop to 0. The BufUnload/BufDelete autocmd at :466-472 clears
      initialized and exchange_anchors but not rederived[buf], so every closed chat retains
      its last exchange_model for the process lifetime. Add rederived[buf] = nil there and
      drop the __mode metatable, which reads as a guard and is not one.
  - id: new
    severity: Minor
    title: |
      Duplicated comment paragraph and split declaration in prepare_exchange_update
    detail: |
      tool_folds.lua:335-346 repeats the same "same rule as reconcile" paragraph twice;
      :331 declares first_0/last_0 two lines before its only assignment.
  - id: new
    severity: Minor
    title: |
      owned_span writes the same return statement twice (ARCH-DRY)
    detail: |
      tool_folds.lua:242-246 collapses to a single guard plus one return.
  - id: new
    severity: Minor
    title: |
      Two stale test comments in the integration fold spec
    detail: |
      tool_folds_spec.lua:180-186 describes wall-clock sampling the test no longer does;
      :93's "Contrast the case above, whose fold sits outside every span" points at :55,
      which now asserts that fold IS cleared.
  - id: new
    severity: Minor
    title: |
      verify_anchors cannot run without a vim global; the purity test only pins module load
    detail: |
      fold_projection.lua:76 requires highlight_structure unconditionally even when patterns
      is supplied, so it fails in vim/_init_packages.lua under _G.vim = nil, while
      verify_starts runs fine. fold_projection_spec.lua:32 checks load-time purity only, so
      the plan's "pure and nvim-free" claim is unpinned at call time (ARCH-PURE).
  - id: new
    severity: Minor
    title: |
      prepare_exchange_update computes desired_folds only to fill the observer event
    detail: |
      tool_folds.lua:330 — per-streamed-chunk work whose sole consumer is the test seam.
  - id: new
    severity: Minor
    title: |
      M._last_clear_iters is not reset on clear_folds_in_span's early returns
    detail: |
      tool_folds.lua:50-57 return before :93 in three cases, so a reader can pick up a stale
      iteration count from a previous call.
  - id: new
    severity: Minor
    title: |
      The containment rule is pure logic living in the IO shell (ARCH-PURE)
    detail: |
      tool_folds.lua:279-286 is a pure predicate over ranges and a row span, reachable only
      through an integration test. Extracting it to fold_projection makes it unit-pinnable.
  - id: new
    severity: Minor
    title: |
      The fold-creation loop is unprotected against E350 though the clear half handles it
    detail: |
      tool_folds.lua:321 throws out of reconcile under a non-manual foldmethod, while
      clear_folds_in_span:65-68 explicitly reasons about that case. Pre-existing, but the
      asymmetry is newly visible.
  - id: new
    severity: Minor
    title: |
      lessons.md has no rule for the duplicate-test-block defect this window fixed
    detail: |
      The existing "deleted tests do not fail" entry keys on a SHRINKING green suite; a
      duplicated describe block makes it grow, which is why the count check read as "I added
      tests" for four rounds. Add the uniq -d audit over it("...") names (AGENTS.md section 4).
  - id: new
    severity: Minor
    title: |
      No follow-up issue filed for the harness scratch-dir contention diagnosed in round 6
    detail: |
      The Log says tools_builtin_find_spec traverses a .test-tmp being mutated under it and
      that it is "worth its own issue". No issue exists; the diagnosis will be archived to
      workshop/history/ at close.
  - id: new
    severity: Minor
    title: |
      README not updated for the new fold-ownership contract
    detail: |
      A manual zf inside an exchange — now including the whole buffer tail after the last
      block — is destroyed on the next reconcile. Operator-visible, documented only in atlas.
  - id: new
    severity: Minor
    title: |
      Corpus harness shells out to git ls-files outside any seam (ARCH-MOCK)
    detail: |
      fold_invariants_spec.lua:17. Mitigated by the "#corpus >= 8" floor, which makes a
      missing or failed git a loud failure rather than a silently shrunken suite. Noting only.
  - id: new
    severity: Minor
    title: |
      Plan doc Task 1-5 step checkboxes still unticked although M1 is complete
    detail: |
      The issue's Plan section is correctly ticked; the durable plan's steps lag.
```

---

## Re-review — 2026-08-20T21:38:20-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | c7b06080c6f71061805d867bcc0bb65f2243f60b..c7b06080c6f71061805d867bcc0bb65f2243f60b |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T21:38:20-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M1 reconciliation design is sound and the review history shows real convergence — the verified-creation / identified-destruction split is the right architecture, `fold_projection` stayed pure and nvim-free, `FOLDABLE` now derives from `ANCHOR_KIND`, and 66 fold tests plus a corpus harness pin eight previously-reproduced scenarios (all green here: 15 + 12 + 1 + 26 + 12; lint 0/0 across 331 files). What blocks SHIP is that the new clearing mechanism has an undeclared precondition: `clear_folds_in_span` gates every deletion on `foldlevel()`, which returns 0 for every row when the window has `'nofoldenable'`. In that state the clear is a complete no-op, reconcile degrades to exactly the pre-#200 append-only behaviour, and I reproduced both the headline symptom (`💬: q (4 lines)` surviving a reconcile) and unbounded fold nesting (25 reconciles → 25 nested levels at the same rows, i.e. one level per streamed chunk). Parley itself ships `chat_toggle_tool_folds`, which sets `vim.wo.foldenable = not vim.wo.foldenable`, so this is a first-class user state, and no fold spec exercises it — every one sets `foldenable = true` in `before_each`.

## 1. Strengths

- **The creation/destruction split is the right abstraction.** `lua/parley/tool_folds.lua:118-130` + `lua/parley/exchange_anchors.lua:63-80` — "creation is verified, destruction is identified" is the lesson four rounds of positional heuristics could not reach, and the module comment states *why* a row-span is not an identity rather than just what the code does.
- **`exchange_anchors.span` validates the whole mapping, not the bounding pair** (`lua/parley/exchange_anchors.lua:69-74`). The compensating delete-and-add case (prune an exchange, ask again) is ordinary usage and would have aliased under a count-only check; `tests/unit/exchange_anchors_spec.lua:76-82` pins it.
- **`FOLDABLE` derived from `ANCHOR_KIND`** (`lua/parley/fold_projection.lua:15-23`) with the drift mode named in the comment — and `tests/integration/fold_invariants_spec.lua:87` reads the policy through `projection.is_foldable()` instead of restating it. Clean `ARCH-DRY` closure.
- **The scaling test counts work instead of timing it** (`tests/integration/tool_folds_spec.lua:188-219`, `M._last_clear_iters`). Converting a flaky wall-clock assertion into "16× the rows must cost no more iterations" is the correct instrument, and the corresponding `workshop/lessons.md` entry generalises it.
- **The corpus harness fails loudly rather than shrinking to green** — the `#corpus >= 8` floor and the `checked > 0` per-file assertion (`tests/integration/fold_invariants_spec.lua:56-59, 96-98`) both defend against the "green-and-empty" failure that the Log records happening three separate times.

## 2. Critical findings

**C-A — `clear_folds_in_span` deletes nothing when the window has `'nofoldenable'`; #200's exact symptom returns and persists.** `lua/parley/tool_folds.lua:75,77`

The VimL loop only reaches `zD` via `if foldlevel(line('.')) > 0`. Measured raw Vim behaviour: with `nofoldenable`, `:fold` **does** create the fold, but `foldlevel()` reports `0` for its rows (re-enabling shows `foldlevel(13)=1`, `foldclosed(13)=12`). `zj` still navigates. So the loop walks fold-to-fold and never deletes — reconcile becomes append-only, which is the root cause #200 exists to remove.

Reproduced, two failure modes:

```
foldenable at reconcile=true  -> foldclosed(3)=-1
foldenable at reconcile=false -> foldclosed(3)=3    💬: q (4 lines)
```

```
foldenable during 25 reconciles=true  -> foldlevel(10)=1
foldenable during 25 reconciles=false -> foldlevel(10)=25
```

The first is the operator's originally reported render, byte-for-byte, surviving a reconcile that is supposed to remove it — and it is permanent, because nothing else deletes folds and `hydrate_window` latches on `initialized[buf][win]`. The second means fold nesting grows one level per streamed chunk (`chat_respond.lua:1743` wraps every chunk), directly violating the property `tests/integration/tool_folds_spec.lua:698` claims to pin.

Trigger conditions are ordinary: `set nofoldenable` in a user config, `zi`, or parley's own `chat_toggle_tool_folds` (`lua/parley/init.lua:2236`, `config_key = chat_shortcut_toggle_tool_folds`). It is a regression this milestone introduced — the pre-#200 `zd` at projected start rows did not consult `foldlevel()`.

Fix sketch: inside the existing `nvim_win_call`, save and force the option around the clear only —

```
let s:fen = &l:foldenable | setlocal foldenable
... existing loop ...
let &l:foldenable = s:fen
```

Creation needs no guard: `%d,%dfold` works under either setting and does not itself flip `foldenable` (verified). Then add a `foldenable = false` variant of the ownership and the "exactly one fold level across consecutive appends" tests — the whole fold suite currently runs only with `foldenable = true` (`tests/integration/tool_folds_spec.lua:15`, `tests/integration/fold_invariants_spec.lua:71`), which is why this shipped.

## 3. Important findings

**I-A — `reconcile_exchange` is now O(number of exchanges in the chat) per call, on the per-chunk streaming path, and nothing pins that axis.** `lua/parley/exchange_anchors.lua:69-74` via `lua/parley/tool_folds.lua:270,345`

`span()` resolves *every* anchor on every call (correctly — that is the round-7 aliasing fix), so the cost scales with chat length rather than exchange length. Measured, streaming exchange held constant:

```
exchanges=10    lines=125    per-reconcile=0.0386 ms
exchanges=50    lines=605    per-reconcile=0.0495 ms
exchanges=200   lines=2405   per-reconcile=0.1172 ms
exchanges=500   lines=6005   per-reconcile=0.2549 ms
```

`with_exchange_update` calls `owned_span` twice per chunk (prepare + finalize), so ≈0.5 ms/chunk at 500 exchanges against the 0.078 ms pre-#200 baseline the Log cites. The `0.067 ms` M1 measurement was taken on a short chat and does not cover this axis, and the in-suite scaling test varies `body_lines` only. Fix sketch: memoise the resolved anchor rows per `(buf, changedtick)` — exact, since extmarks only move on edits and every edit bumps the tick — and extend the iteration-count test with a second dimension that holds span length fixed while growing the exchange count.

**I-B — the drift refusal is logged once per buffer *lifetime*, not once per buffer *state*.** `lua/parley/tool_folds.lua:181,195-197,312-314`

`rederived[buf].logged` is carried forward into every new tick's entry (`logged = hit and hit.logged or false`) and never reset on a successful reconcile, so after the first refusal in a buffer every later refusal — including an unrelated drift much later in the session — produces no debug line. The comment at `:310-311` says "logged once per buffer state", and the Done-when says "A drifted exchange that cannot be folded says so — the refusal is not silent." Silent persistent non-folding is #200's own pathology. Fix sketch: clear `rederived[buf].logged` when `reconcile_exchange` succeeds, or key the suppression on the tick rather than the buffer.

## 4. Minor findings

- `lua/parley/tool_folds.lua:88,93` — `vim.g.parley_fold_clear_iters` is a test instrument written to a *global* on every clear, on the per-chunk path. `nvim_exec2(..., { output = true })` or a `vim.b` var would keep it out of the global namespace.
- `lua/parley/tool_folds.lua:351,357` — `identified` is emitted on the prepare event but nothing consumes or asserts it; a diagnostic with no reader.
- `tests/integration/tool_folds_spec.lua:252,706` — `_observer` is set inline and reset inline, but not in `after_each` (unlike `_model_provider` at `:23`); a failing assertion between the two leaks the observer into later tests.
- `lua/parley/tool_folds.lua:434-449` — `foldtext()` hardcodes `🔧:`/`📎:`/`🧠:`/`📝:` instead of deriving from `highlight_structure.patterns(config)`, so a customised prefix silently falls through to the preview branch — the same branch that rendered `💬: q (4 lines)` and masked #200. Pre-existing and outside the diff, but it is now the last hand-maintained copy of the marker vocabulary BR-1 consolidated (`ARCH-DRY`), and making that branch loud is cheap insurance.

## 5. Test coverage notes

Verified green in this environment: `fold_projection_spec` 15/15, `exchange_anchors_spec` 12/12, `tool_folds_spec` 1/1 unit + 26/26 integration, `fold_invariants_spec` 12/12 (11 files — the corpus floor of 8 absorbs the one transcript deleted-but-unstaged in the working tree). `make lint` 0 warnings / 0 errors across 331 files. The eight reproduced scenarios each have a named regression test, and the fixtures (`fold_assistant_first.md`, `fold_tool_transcript.md`) genuinely cover shapes the real corpus lacks — the harness comment honestly records that the real corpus has zero tool blocks.

The gap is one-dimensional and it is exactly where C-A lives: **`'foldenable'` is never varied**. Both fold specs pin it to `true` in setup, so the entire fold surface is tested in one of its two window states. Adding the `foldenable = false` variant of the ownership test, the stale-fold test, and the "exactly one fold level" test would have caught C-A and would catch its whole class. Secondarily, no test varies exchange *count* while holding span length fixed (I-A).

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass**, with the Minor above. `FOLDABLE` deriving from `ANCHOR_KIND` and the corpus spec reading `is_foldable()` are the right shape; `foldtext()` is the residual restatement.
- **ARCH-PURE — pass**, with a structural caution. `fold_projection` is pure and nvim-free; `exchange_anchors` and `tool_folds` are the IO shell. But the clearing *algorithm* now lives as an embedded VimL program string inside that shell (`tool_folds.lua:69-89`) — there is no representation of it that can be tested below the Neovim boundary, and C-A is precisely the kind of environment-coupled defect that hides there. Worth stating its preconditions (`foldmethod=manual`, `foldenable`) explicitly in the comment as part of the fix rather than only the E350 case that is already noted.
- **ARCH-PURPOSE — flag, via C-A.** The Spec's contract is "Folding holds these two invariants **at all times**, not merely on a cold open." M1 delivers that for `foldenable` windows only; in the other state the invariant fails in the originally reported form. This is the purpose of the issue, not a separable extension, so it belongs inside M1 rather than as follow-up. Everything else on the M1 checklist is delivered as claimed.
- **ARCH-MOCK — pass.** No external binary or service in the production path. The test-only `vim.fn.systemlist("git ls-files …")` in `corpus_provider` is a file enumeration with an in-file acknowledgement that it is a single point of definition rather than an injection seam; the tracked fixtures make the assertions themselves git-independent.
- **For M2:** the fence extraction should not re-learn C-A's lesson — when a pure module's grammar is consumed by a Neovim-side scanner, keep the environment-dependent predicate (`foldlevel`, `foldenable`, fence state) out of the pure module's contract and pin the shell's preconditions with a test that varies them.

## 7. Plan revision recommendations

- **`workshop/plans/000200-fold-reconciliation-plan.md` — a `## Revisions` entry for the `foldenable` precondition.** The plan's `tool_folds` integration entry and the atlas paragraph ("Clearing walks fold-to-fold (`zj`/`zD` in a single VimL crossing) … must scale with the number of folds present") describe the mechanism without its precondition. Record that fold-to-fold clearing depends on `foldlevel()`, that `foldlevel()` reports 0 under `'nofoldenable'`, and that the clear therefore forces the option for its duration — plus the test obligation to run the ownership cases in both window states.
- **Same file / `atlas/chat/exchange_model.md` — a note on the new scaling axis.** Both currently state only the per-chunk *span-length* property. Add that identity resolution is O(number of exchanges) per reconcile (with the measurements above), and whichever mitigation is chosen for I-A.
- No revision needed for the Core-concepts table: `fold_projection` (modified), `tool_folds` (modified) and `exchange_anchors` (new, `lua/parley/exchange_anchors.lua`) all exist at their stated paths with the stated kinds, PURE/INTEGRATION classification holds, and the `verify_span` / positional-fallback text was already corrected to match round 5's code. `fence` @ `lua/parley/fence.lua` is correctly absent — it is M2 Task 6.

```findings
findings:
  - id: new
    severity: Critical
    title: |
      clear_folds_in_span deletes nothing under 'nofoldenable', restoring the #200 symptom permanently
    detail: |
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
  - id: new
    severity: Important
    title: |
      reconcile_exchange is O(number of exchanges) per call on the per-chunk streaming path
    detail: |
      exchange_anchors.span resolves every anchor on every call, so per-chunk
      cost scales with chat length, not exchange length. Measured with the
      streamed exchange held constant: 0.0386 ms at 10 exchanges, 0.0495 at 50,
      0.1172 at 200, 0.2549 at 500 — and owned_span runs twice per chunk
      (prepare + finalize) against a 0.078 ms pre-200 baseline. The in-suite
      scaling test varies span length only, so this axis is unpinned. Fix:
      memoise resolved anchor rows per (buf, changedtick) — exact, since marks
      only move on edits and every edit bumps the tick — and extend the
      iteration-count test to hold span fixed while growing exchange count.
  - id: new
    severity: Important
    title: |
      the drift refusal is logged once per buffer lifetime, not once per buffer state
    detail: |
      rederived[buf].logged is carried into every new tick's entry
      (tool_folds.lua:181) and never reset on a successful reconcile, so after
      the first refusal in a buffer every later refusal — including an
      unrelated drift much later in the session — is silent. The comment at
      :310-311 says "once per buffer state" and the Done-when requires the
      refusal not be silent. Fix: clear the flag when reconcile_exchange
      succeeds, or key the suppression on the tick rather than the buffer.
  - id: new
    severity: Minor
    title: |
      vim.g.parley_fold_clear_iters is a test instrument written to a global on the per-chunk path
    detail: |
      tool_folds.lua:88,93. Prefer nvim_exec2 with output capture, or a
      buffer-local var, so the production hot path does not publish a global.
  - id: new
    severity: Minor
    title: |
      the prepare event's `identified` flag has no consumer and no test
    detail: |
      tool_folds.lua:351,357 emit it, nothing reads or asserts it.
  - id: new
    severity: Minor
    title: |
      _observer is reset inline rather than in after_each, so a failing assertion leaks it
    detail: |
      tests/integration/tool_folds_spec.lua:252,706 — _model_provider is reset
      in after_each (:23) but _observer is not.
  - id: new
    severity: Minor
    title: |
      foldtext hardcodes the four marker prefixes instead of deriving from highlight_structure.patterns
    detail: |
      tool_folds.lua:434-449. A customised chat_tool_use_prefix silently falls
      through to the preview branch — the same branch that rendered
      "💬: q (4 lines)" and masked #200. Pre-existing and outside the diff, but
      it is now the last hand-maintained copy of the marker vocabulary BR-1
      consolidated into ANCHOR_KIND (ARCH-DRY).
```

---

## Re-review — 2026-08-20T21:52:18-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 200 — user question is folded |
| repo | parley.nvim |
| issue file | workshop/issues/000200-user-question-is-folded.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 5213a2acb707f994e641d329bd9558cce8c80d64..5213a2acb707f994e641d329bd9558cce8c80d64 |
| command | sdlc milestone-close --issue 200 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-20T21:52:18-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The review window handed to me was empty (`5213a2a..5213a2a`), so I reviewed the whole M1 range `38a6cdd..HEAD` against the issue's Spec/Plan and re-verified every prior finding against the code. The Critical from the last round (BR-19, the `nofoldenable` no-op clear) is genuinely fixed: the guard is present at `tool_folds.lua:76-98`, saved/forced/restored inside the existing `nvim_win_call`, and two `foldenable = false` variants were added. I re-ran all five fold specs — 15 + 12 + 1 + 28 + 12 = 68 green — and `luacheck` at 0/0 across 331 files. I independently confirmed the mechanism (`foldlevel()` does read 0 under `nofoldenable`; `zE` and `:fold` both work regardless, and `:fold` does *not* silently re-enable the option the way `zf` does, so the "creation needs no guard" claim holds). No new Critical surfaced: I probed the two hypotheses most likely to reopen the round-2 permanent-refusal class — a `🔒:` local section between exchanges shifting `exchange_start`, and `zE` no-opping under `nofoldenable` — and both were disproved empirically. What keeps this off SHIP is that the two Importants raised alongside BR-19 were not touched: **BR-21 leaves an M1 `Done when` line unmet** ("a drifted exchange that cannot be folded says so — the refusal is not silent"), and it is a one-line fix; BR-20's per-chunk scaling axis is still unmeasured in-suite.

### 1. Strengths

- **`fold_projection.lua:15-23`** — deriving `FOLDABLE` from `ANCHOR_KIND` is the right consolidation, and it makes the drift structurally impossible rather than merely tested (ARCH-DRY). The mapping test at `fold_projection_spec.lua:52` pins the surviving hand-maintained half.
- **`tool_folds.lua:76-99`** — the foldenable guard is correctly scoped: it wraps only the clear, uses `&l:` so the global default for new windows is untouched, and the restore sits after `endwhile` so a `break` still reaches it. `tool_folds_spec.lua:538` asserts the operator's setting survives, which is the part that would otherwise regress silently.
- **`tool_folds_spec.lua:543`** — the "does not deepen fold nesting" test is the better of the two new cases: it pins the compounding failure (one level per streamed chunk), not just the single-shot symptom.
- **`tool_folds.lua:158-162, 484`** — the memo-leak fix is honest about *why* `__mode = "k"` was a no-op, and clears on the same lifecycle event as `initialized` and the anchors.
- **`exchange_anchors.lua:63-80`** — whole-mapping validation with a strict-ascending check, declining rather than guessing, is the correct shape for an identity oracle. The module comment earns its length.
- **Test-inventory discipline** — I re-ran the audit the log claims: zero duplicate `it()`/`describe()` names across all five fold specs. That claim checks out.

### 2. Critical findings

None.

### 3. Important findings

Both are prior findings re-raised; see the dispose block. In brief:

- **BR-21** (`tool_folds.lua:191`) — `logged` is carried into every new tick's entry and is never reset; `grep -n logged lua/parley/tool_folds.lua` shows `mark_drift_logged` as the only writer and no clear on success. After the first refusal in a buffer, every later refusal is silent, including an unrelated drift much later in the session. This is the M1 `Done when` line "the refusal is not silent", and the issue's Plan ticks M1 complete. Fix: clear the flag when `reconcile_exchange` succeeds, or key suppression on the tick.
- **BR-20** (`exchange_anchors.lua:70-74`) — `span` resolves every anchor on every call, twice per streamed chunk. Unchanged.
- **BR-4** is half-done: the plan's Core-concepts entry now correctly names `verify_starts` (`000200-fold-reconciliation-plan.md:37`), but `## Revisions` still stops at round 7 — round 8's containment tie and the round-9 foldenable guard are recorded only in the issue Log.

### 4. Minor findings

- New: per-chunk reconcile cost is linear in projected-range *length* (`covered_lines` + `verify_anchors`' interior scan), an O(span) read this milestone introduced. Measured best-of-30: 0.0070 / 0.0100 / 0.0230 / 0.0825 / 0.3440 ms at 25 / 100 / 400 / 1600 / 6400 body rows. Small in absolute terms; the point is that the in-suite scaling test asserts only clear-loop iterations, so this axis is unasserted.
- New: `atlas/chat/exchange_model.md`'s clearing bullet describes `zj`/`zD` but not that the clear transiently forces `'foldenable'` — a window option the module does not own. One-line delta; docs gate.
- New: `prepare_exchange_update` clears the identified span with no range verification, while `reconcile_exchange` refuses to *create* unverified. If finalize's reconcile then refuses, the span is left cleared with nothing recreated. I could not reach this in production (the re-derive normally heals), so it is an asymmetry note, not a demonstrated bug — but it is the exact shape of `lessons.md`'s own "widening a destructive operation demands widening its verification".
- Prior minors BR-6 through BR-18 and BR-22 through BR-25 are all still present verbatim; disposed below.

### 5. Test coverage notes

- 68 fold tests, all green, no duplicate names, lint clean. The two new `foldenable = false` cases close the "the suite fixed an environment setting" gap for the clear path.
- Still uncovered: (a) `foldmethod` other than `manual` on the creation half (BR-13) — the clear half reasons about E350 explicitly, the create half throws; (b) the `identified` prepare-event field has no assertion anywhere (BR-23); (c) `_observer` is reset inline at `tool_folds_spec.lua:260,765` rather than in `after_each`, so a failing assertion leaks it into the next test (BR-24).
- The corpus harness currently enumerates 11 files (2 fixtures + 9 tracked; `2026-05-03…global-warming-overview.md` is deleted-but-unstaged in the working tree and correctly dropped by the `filereadable` filter). The `#corpus >= 8` floor is doing real work here.

### 6. Architectural notes

- **ARCH-DRY — flag.** The `FOLDABLE`/`ANCHOR_KIND` consolidation is a clean pass. Three duplications remain: the repeated comment paragraph and split declaration in `prepare_exchange_update` (`tool_folds.lua:345-355`, BR-6), the doubled return in `owned_span` (`:256-260`, BR-7), and `foldtext`'s hardcoded four marker prefixes (`:444-454`, BR-25) — now the last hand-maintained copy of the marker vocabulary, and the branch that rendered `💬: q (4 lines)` in the first place.
- **ARCH-PURE — flag.** The verify path is well-shaped: `covered_lines` does the one buffer read, `verify_anchors` is a pure function over the resulting map. Two leaks persist: `verify_anchors` requires `highlight_structure` unconditionally even when `patterns` is supplied (`fold_projection.lua:80`), so the module's "pure and nvim-free" claim is pinned at load time only (BR-9); and the containment predicate at `tool_folds.lua:293-300` is pure logic living in the IO shell, reachable only through integration tests (BR-12).
- **ARCH-PURPOSE — flag.** M1's scope is a legitimate milestone, not an under-delivery — M2's fence work is separable and has its own boundary. But one M1 `Done when` is not met (BR-21), and the Plan ticks M1 anyway. That is the finding.
- **ARCH-MOCK — pass with one noted exception.** No external binary or service is in the production path. The corpus harness shells to `git ls-files` outside any seam (`fold_invariants_spec.lua:17`, BR-17), mitigated by the `>= 8` floor turning a missing git into a loud failure rather than a silently shrunken suite.

For M2: the "explicit non-fix" recorded in the round-6 revision — do not add a buffer-wide completeness scan to `verify_starts` until it can consume the `fence` grammar — is the load-bearing note. Carry it into the M2 plan, not just the Revisions.

### 7. Plan revision recommendations

Two `## Revisions` entries are missing from `workshop/plans/000200-fold-reconciliation-plan.md`:

- **M1 round 8: tie creation to destruction** — `model_fits` proves a range matches the buffer's text; identity proves which rows the exchange owns; nothing proved they described the same exchange. Delta: an O(#ranges) containment check in `reconcile_exchange`; and the scaling test now asserts `clear_folds_in_span`'s loop-iteration count instead of wall-clock.
- **M1 round 9: the clear forces `'foldenable'`** — `zj`/`zD` are inert under `nofoldenable`, so the clear silently no-opped and a stale question-anchored fold survived permanently. Delta: save/force/restore `&l:foldenable` inside the existing `nvim_win_call`, creation needs no guard, two `foldenable = false` spec variants.

Separately, the plan's Task 1-5 step checkboxes (`:85` through `:753`) are all still unticked although M1 is complete (BR-18).

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      FOLDABLE derived from ANCHOR_KIND at fold_projection.lua:22-23; drift is now structurally impossible.
  - id: BR-2
    disposition: addressed
    note: |
      tool_folds_spec.lua:488 folds the frontmatter and asserts it survives a full reconcile.
  - id: BR-3
    disposition: addressed
    note: |
      grep verify_span over atlas/ is empty; the section now states "no positional fallback" and documents the containment tie.
  - id: BR-4
    disposition: not-addressed
    note: |
      Core-concepts fixed at plan:37, but Revisions still stop at round 7 — rounds 8 and 9 unrecorded.
  - id: BR-5
    disposition: addressed
    note: |
      Weak mode dropped (tool_folds.lua:162); rederived[buf] cleared on BufUnload/BufDelete at :484.
  - id: BR-6
    disposition: not-addressed
    note: |
      tool_folds.lua:348-354 still repeats the paragraph; :345 still splits the declaration from :355.
  - id: BR-7
    disposition: not-addressed
    note: |
      tool_folds.lua:256-260 unchanged.
  - id: BR-8
    disposition: not-addressed
    note: |
      Both comments unchanged — spec :184-186 still describes wall-clock sampling, :93 still says the case above sits outside every span when it now asserts that fold IS cleared.
  - id: BR-9
    disposition: not-addressed
    note: |
      fold_projection.lua:80 still requires highlight_structure unconditionally; the purity test still checks load time only.
  - id: BR-10
    disposition: not-addressed
    note: |
      tool_folds.lua:344 unchanged.
  - id: BR-11
    disposition: not-addressed
    note: |
      tool_folds.lua:50-51 and :57 still return before the iteration count is written at :103.
  - id: BR-12
    disposition: not-addressed
    note: |
      tool_folds.lua:293-300 unchanged.
  - id: BR-13
    disposition: not-addressed
    note: |
      tool_folds.lua:335 still unguarded while the clear half reasons about E350 at :63-68.
  - id: BR-14
    disposition: not-addressed
    note: |
      The new lessons entry keys on a shrinking suite and a comm -13 set diff; duplicates collapse in a set, so no rule covers the duplicate-block defect.
  - id: BR-15
    disposition: not-addressed
    note: |
      workshop/issues/ still holds eight issues, none for the scratch-dir contention.
  - id: BR-16
    disposition: not-addressed
    note: |
      No README.md change anywhere in 38a6cdd..HEAD.
  - id: BR-17
    disposition: not-addressed
    note: |
      fold_invariants_spec.lua:17 unchanged; the >= 8 floor still mitigates it.
  - id: BR-18
    disposition: not-addressed
    note: |
      Every Task 1-5 step checkbox in the durable plan is still unticked.
  - id: BR-19
    disposition: addressed
    note: |
      Guard at tool_folds.lua:76-98 with two foldenable=false tests; verified foldlevel() reads 0 under nofoldenable and that :fold does not re-enable the option.
  - id: BR-20
    disposition: not-addressed
    note: |
      exchange_anchors.lua:70-74 still resolves every anchor per call; no memo, and the scaling test still varies span length only.
  - id: BR-21
    disposition: not-addressed
    note: |
      tool_folds.lua:191 still carries logged forward; no writer resets it on success. This is the unmet "refusal is not silent" Done-when.
  - id: BR-22
    disposition: not-addressed
    note: |
      tool_folds.lua:97,103 unchanged.
  - id: BR-23
    disposition: not-addressed
    note: |
      grep identified over lua/ and tests/ returns only the two emit sites.
  - id: BR-24
    disposition: not-addressed
    note: |
      tool_folds_spec.lua:260,765 still reset inline; after_each at :22 resets only _model_provider.
  - id: BR-25
    disposition: not-addressed
    note: |
      tool_folds.lua:444-454 unchanged.
findings:
  - id: new
    severity: Minor
    title: |
      per-chunk reconcile cost is linear in projected-range length, and that axis is unasserted
    detail: |
      covered_lines plus verify_anchors' interior scan is an O(span) buffer read
      this milestone introduced on the per-streamed-chunk path. Measured
      best-of-30 per reconcile with a single thinking range: 0.0070 / 0.0100 /
      0.0230 / 0.0825 / 0.3440 ms at 25 / 100 / 400 / 1600 / 6400 body rows —
      clean linearity, so streaming a long foldable block is O(N^2) overall.
      Absolute cost is small, but the in-suite scaling test asserts only
      clear-loop iteration count, so nothing pins this axis.
  - id: new
    severity: Minor
    title: |
      atlas does not record that the clear transiently forces 'foldenable'
    detail: |
      The last commit made tool_folds write a window option it does not own,
      saving and restoring it around the clear. atlas/chat/exchange_model.md's
      fold-reconciliation section describes the zj/zD walk but not this, so the
      operator-visible contract ("your foldenable setting is momentarily forced
      on and restored") lives only in a code comment. One-line delta.
  - id: new
    severity: Minor
    title: |
      prepare clears the identified span unverified while reconcile refuses to create unverified
    detail: |
      prepare_exchange_update destroys every fold in the identified span with no
      range verification; reconcile_exchange refuses to create when verification
      fails. If finalize's reconcile then refuses, the span is left cleared with
      nothing recreated and hydrate_window latches. I could not reach this in
      production — the re-derive normally heals within the same call — so this is
      an asymmetry note rather than a demonstrated bug, but it is the shape
      lessons.md's own "widening a destructive operation demands widening its
      verification" entry warns about.
```
