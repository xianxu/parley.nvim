# Boundary Review — parley.nvim#293 (whole-issue close)

| field | value |
|-------|-------|
| issue | 293 — writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait |
| repo | parley.nvim |
| issue file | workshop/issues/000293-writer-folds-tool-test-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | fbade52193d887f1fc9cb91597b34cb3532ddf69..aa389df3b499279dce269eeddb273faa6f205339 |
| command | sdlc close --issue 293 |
| reviewer | claude |
| timestamp | 2026-09-27T21:07:01-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All five open findings (BR-6 to BR-10) are fixed at HEAD `aa389df3`, and I found nothing new. The diff does what the issue asked. The fixed 5s wait that flaked is now a wait that keeps going while repair makes progress, and the underlying cause is fixed too. `sequence.lua` no longer makes three deep copies around every combine call, and the highlighter now decorates only rows a window actually draws, so a closed fold's interior is skipped. A spec pins both fixes with deterministic counters rather than wall time. I ran the four new or changed specs in a scratch copy of HEAD and all passed: `repair_work_budget_spec` 4/4, `document_sequence_spec` 36/36, `highlighter_visible_spans_spec` 2/2, `writer_folds_spec` 5/5, plus `await_helper_spec` 4/4. With the `spans_key` cache check removed, the resume test fails, so the test does guard that key.

1. **Strengths**
   - `tests/helpers/await.lua:51` `until_progress` takes an injected clock and wait function. Its unit tests assert exact fake-clock times (350, 300, 5000), so they can't flake on scheduler timing.
   - `repair_work_budget_spec` budgets `summary_values_copied`, a count rather than a time, and records the baseline (483057) next to the budget (96000).
   - `visible_spans` is a small pure function. Its test compares it against a brute-force row filter over 500 random fold layouts with a fixed seed.
   - The per-redraw loop over spans in `on_win` is correct at the edges. `stop` is exclusive, so `stop <= span[2]` means the span wasn't finished. Resume always lands inside a drawn span, and running out of spans falls back to `end_row`, which resets to `toprow`.
   - The purity contract is stated on `M.new` (`sequence.lua:182`). Values still enter through `copy()` at summarize time and leave through it in `M.summary`.

2. **Critical:** none.

3. **Important:** none.

4. **Minor:**
   - One lessons.md bullet says the fold-key test "stayed green without the key". That was true when written, but the new resume case now fails without it. The bullet is still a fair historical note.
   - `copy()` used to check the 256-value bound on combine outputs at runtime. That check now exists only as a unit property test over the two shipped combines. This is acceptable and documented, since `grammar.combine` and `projection.combine` are the only combines passed to the sequence.

5. **Test coverage notes:** The property test walks nested tables, so an output that reuses an operand's inner table (e.g. `{flags=a.flags}`) fails. The resume test uses the `_redraw_row_budget` seam with a buffer shorter than the window, so `end_row` stays fixed and only `spans_key` can restart the pass; the mutation confirmed this. The fold-toggle case checks which rows are queried, not the applied highlight, and the Revisions section logs that deviation.

6. **Architecture:**
   - **ARCH-DRY: pass.** `_VIEWPORT_MARGIN` comes from the real constant, and `compute_window_decorations` is reused with `margin=0`.
   - **ARCH-PURE: pass.** `visible_spans` is pure. `foldclosedend` is injected at the `on_win` boundary.
   - **ARCH-PURPOSE: pass.** Both combines passed to the sequence are covered by the purity test. The root cause (how much work repair does) is fixed, not just the timeout.
   - **ARCH-MOCK: pass.** No external dependencies. Replacing `D.query` in the specs is a spy that is restored afterwards (inside `pcall`).
   - **ARCH-CONSTRAINTS: pass.** The 256-row per-redraw budget is kept. The `foldclosedend` walk skips fold interiors, so it stays bounded by the rows the window draws.
   - **ARCH-SECURE: N/A.** No untrusted input or secrets are touched.
   - **ARCH-ORDER: pass.** The one state this adds between redraws is `spans_key` in the redraw cache. It is part of the existing cache rebuild check, and a test covers a fold opening between two redraws.
   - **ARCH-FUNERAL: pass.** The temp dir is removed on `VimLeavePre`, the redraw cache lives as long as its window, and the subscription is removed in `after_each`.

7. **Plan revisions:** none. The Revisions section already records the M3 dispositions.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      sequence.lua:182-184 states the purity requirement on the M.new header (the public entry point).
  - id: BR-7
    disposition: addressed
    note: |
      document_sequence_spec now marks all tables reachable from a and b and walks out recursively (aliased), catching nested aliasing.
  - id: BR-8
    disposition: addressed
    note: |
      _redraw_row_budget seam plus the resume-across-fold-open case; scratch mutation (cache.spans_key check removed) turned that case red, 3/4 passed.
  - id: BR-9
    disposition: addressed
    note: |
      Plan Revisions (M3 boundary review) logs the deviation: ephemeral extmarks are not readable, so query coverage is asserted instead.
  - id: BR-10
    disposition: addressed
    note: |
      before_each saves vim.wo[win].foldmethod and after_each restores it when the window is still valid.
```
