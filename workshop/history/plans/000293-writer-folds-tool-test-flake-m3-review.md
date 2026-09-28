# Boundary Review — parley.nvim#293 (milestone M3)

| field | value |
|-------|-------|
| issue | 293 — writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait |
| repo | parley.nvim |
| issue file | workshop/issues/000293-writer-folds-tool-test-flake.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | ec5be02274a8e041d81c11a1a6fbb820bf4179db..d56fa578cf618e82e17752c22cfb51491ceba0c8 |
| command | sdlc milestone-close --issue 293 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-27T21:03:32-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

M3 does what the plan asked for. `visible_spans` is a small pure function that is checked against a separately written brute-force row filter. `on_win` now splits the viewport around closed folds, keeps the 256-row-per-redraw cap across those spans, and adds the fold layout to the cache key as PQ-3 required. Both budget cases are enabled and pass: fewer rows are queried under a closed fold, and opening and closing a fold works as expected. I ran `make test-spec SPEC=chat/document` at head `d56fa578`. It includes both new specs, and the last run exited 0 with no failures. An earlier run exited 1, but busted reported no failures in its output; that fits the load-sensitive specs the issue Log already records. Nothing here blocks SHIP. The findings below are Minor.

**1. Strengths**
- **`visible_spans`** (`lua/parley/highlighter.lua:942-958`): pure, and folds come in through an injected `fold_end_of`. Neighbouring spans merge, so a one-row fold doesn't split a span. A fold that starts above the window correctly shows `first`.
- **The unit test's oracle is written separately.** `drawn_rows` (`tests/unit/highlighter_visible_spans_spec.lua:31-41`) states the rule directly: "hidden when inside a fold after `max(fold start, first)`". It does not re-run the implementation's walk. It uses a fixed random seed and 500 layouts, so a failure can be reproduced.
- **The budget loop's edge cases are right** (`highlighter.lua:1131-1142`):
  - `stop` is exclusive, so `stop <= span[2]` correctly detects a span cut short.
  - When budget runs out exactly at a span's end, the pass resumes at `span[2]+1`, and the next span starts from `max(span[1], next_row)`.
  - When the loop finishes, `resume = end_row`, which sets `next_row` back to `toprow`.
  - The margin is already included in `end_row`, so passing `margin = 0` for every span matches what the plan intended ("0 except last span").
- **The fold-toggle test controls for scrolling**: it asserts the first visible line (`w0`) is unchanged before checking the fold interior. The implementer mutation-tested the fold cache key, reported that the test passes without it, and recorded that in the plan's Revisions and in `lessons.md` rather than over-claiming.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **The `spans_key` cache guard has no test.** The code comment says it only matters when a pass resumes over more than 256 drawn rows, and a 22-row test window can't get there. A test hook for the 256 budget (like `_VIEWPORT_MARGIN`) would let a small test cover it. As it stands the guard is harmless but unproven. This is stated honestly in the comment and in Revisions.
- **The fold-toggle test is weaker than planned.** It asserts that `D.query` covered the interior row. Plan Task 6 Step 2 asked for an assertion that an interior row actually *carries* a decoration. That would also cover `cache.rows` being filled after the cache rebuild. The swap isn't logged as a deviation.
- **Test residue.** The budget spec sets `foldmethod = "manual"` on the shared current window and never restores it in `after_each`. Only this file's later cases are affected. I don't count this as a repeat of `test-residue-cleanup`, which was about a leftover temp directory.

**5. Test coverage notes**
- Covered: the pure span logic (property test), the query count under a closed fold (budget case), and closing/opening a fold without scrolling (integration).
- Not covered: resuming across spans when a pass is over budget, and the `spans_key` rebuild. Both need more than 256 drawn rows, or a test hook for the budget.

**6. Architecture notes**
- **ARCH-DRY: pass.** The per-span loop reuses `compute_window_decorations` through a new optional `margin` parameter instead of copying it.
- **ARCH-PURE: pass.** The span logic is pure. `foldclosedend` is called only in the thin `on_win` wrapper, inside `nvim_win_call`.
- **ARCH-PURPOSE: pass.** Every row a window draws goes through the span filter. There is no second decoration path that still reads fold interiors.
- **ARCH-MOCK: pass.** Only Neovim is involved; tests use a real window with a real fold.
- **ARCH-CONSTRAINTS: pass.** On each redraw, `foldclosedend` is called once per drawn row, because fold interiors are skipped, and the 256-row cap is kept.
- **ARCH-SECURE: N/A.** No untrusted input and no secrets are involved.
- **ARCH-ORDER: pass, with a note.** The cache holds state across redraws; the new state is a key comparison that forces a full rebuild, which removes cases where a resumed pass skips rows. The resume ordering it guards can't be tested yet (see the first Minor finding).
- **ARCH-FUNERAL: pass.** The per-window cache entry is still cleared on `WinClosed`, and `spans_key` is a string held inside that entry.

**7. Plan revision recommendations**
- Optionally, add a line under Revisions saying the fold-toggle test asserts query coverage instead of an applied extmark, as a logged change from Task 6 Step 2.

```findings
findings:
  - id: new
    severity: Minor
    family: untested-guard
    title: |
      spans_key cache guard has no test; only reachable past 256 drawn rows
    detail: |
      Mutation showed the toggle test stays green without the key (acknowledged in Revisions). A test seam for the 256-row per-redraw budget in on_win would let a small window exercise resume-across-fold-change and pin the key.
  - id: new
    severity: Minor
    family: plan-deviation-unlogged
    title: |
      fold-toggle case asserts query coverage, not the applied decoration Task 6 Step 2 specified
    detail: |
      tests/integration/repair_work_budget_spec.lua checks D.query ranges cover the interior row; the plan asked for an interior row to carry its extmark highlight, which would also pin cache.rows population after the spans_key rebuild. Log the deviation or tighten the assertion.
  - id: new
    severity: Minor
    family: test-window-option-residue
    title: |
      budget spec sets foldmethod=manual on the shared current window without restoring it
    detail: |
      after_each deletes the buffer but leaves vim.wo[win].foldmethod changed for later cases on the same window.
```
