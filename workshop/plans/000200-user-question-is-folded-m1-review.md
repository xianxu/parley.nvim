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
