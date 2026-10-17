# Boundary Review — parley.nvim#375 (whole-issue close)

| field | value |
|-------|-------|
| issue | 375 — single_source_sweeps fails a direct make test on a quick-flow issue branch with no Core-concepts table |
| repo | parley.nvim |
| issue file | workshop/issues/000375-single-source-sweeps-fails-a-direct-make-test-on-a-quick-flow-issue-branch-with-no-core-concepts-table.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3cd5f862bca097262961a519083271acde75ea3c..c6708d6f26f4d3a6e803ea45579c932c6d495c55 |
| command | sdlc close --issue 375 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T06:28:58-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Running the spec on a simulated issue branch to check the pending path.

Still trying to run the spec; the test runner couldn't find plenary, so I'm locating it.

Plenary isn't installed here, so I'll check `concept_rows` directly against the repo's real issue and plan docs.

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The refactor works as intended. The inline parser moved into a pure `concept_rows(body)` without changing behaviour: the `deleted` and live-row branches get the same lines as before, because `rows` now holds only rows that are inside a Status-headed table and start with a backtick. The plan→code case goes pending when no doc has a Status-headed table, and the `rows > 0` floor still applies once a header is found, which matches the Spec. When I ran the extracted function over the repo's workshop docs, it returned `0` tables for #375's own issue file, so the case goes pending on this branch.

I could not run the spec under Plenary because `plenary.busted` is not installed in this review environment. So the "28/0" result in the Plan is unconfirmed here, though the code makes the pending path easy to follow.

One gap is worth fixing cheaply. A quick-flow issue that does have a Core-concepts table, but whose rows don't start with a backtick, still fails `make test` on its branch. #330 and #331 were both quick-flow issues with exactly that shape. When that happens, the new failure message ("has no rows") is also wrong.

**Strengths**
1. `tests/arch/single_source_sweeps_spec.lua:114` — the parser is now a pure, IO-free function that a test can call directly. This is good ARCH-PURE work, and the doc comment explaining why the header defines the class (BR-89) moved with it.
2. `:330`/`:344` — dropping the repeated `in_concepts and line:match("^| \`")` checks is correct, because every line in `rows` already meets both conditions. The diff is simpler and behaves the same.
3. `:377-383` — the pending branch sits after the loop and is keyed on the table count, not the row count. So an emptied table still fails, as the Spec requires.
4. `:392` — the new spec covers all three states: no table (including a decoy table without a Status column that has backtick rows), an emptied table, and a full table with a stray row after the prose.

**Critical findings**
None.

**Important findings**
- **The case still fails on real quick-flow tables whose rows don't start with a backtick** (`:117`, `:383`).
  - `concept_rows` counts a Status-headed table but keeps only rows that start with `` | ` ``.
  - #330 (`| Concept | Implementing entities | Kind | Status | Change |`, rows like `| Lock baseline | lua/parley/...`) and #331 both took the quick flow, and both give tables=1, rows=0.
  - On either branch, `make test` still fails, now with the inaccurate "has no rows".
  - Across the repo, 13 workshop docs have this tables>0/rows=0 shape. One of them is the active plan `workshop/plans/000209-*`.
  - Instances of this class (a quick-flow branch with no table, or a table this guard does not recognise, failing a direct `make test`) in this file:
    - (a) this assert at `:383`;
    - (b) the sibling code→table case at `:171-244`. It uses a second, separate definition of a Core-concepts table (`## Core concepts` section, any `^| ` line). On a quick-flow branch that adds any `M.x` export, `plan_body` is empty and it fails.
  - Fix sketch:
    - Either count rows of any shape for the floor, or split the message so it says "N rows, none name a backticked symbol".
    - Have the sibling case use `concept_rows` and go pending when `tables == 0`, so there is one definition of a Core-concepts table (ARCH-DRY, ARCH-PURPOSE).

**Minor findings**
- `:377-380`: when an id has no docs at all (`#docs == 0`), the case now goes pending with the reason "has no Core-concepts table (quick flow)", which is misleading. The sibling case has its own `#docs == 0` pending reason. Reuse that wording.
- The Problem section says "Every quick-flow issue is like that". #330 and #331 show quick-flow issues can carry tables. This is prose only.

**Test coverage notes**
- The pure parser is pinned in all three states.
- The integration-level Done-when clause ("`make test` … passes this case as pending") has no automated test. It was only checked by hand on the branch. That's acceptable for an arch guard keyed on the branch name.
- No fixture covers a table whose rows don't start with a backtick, which is the gap above.

**Architecture**
- **ARCH-DRY:** flag. Two parsers still disagree about what a Core-concepts table is: `concept_rows` (Status header) and the sibling's `## Core concepts` section scan at `:174`. This is covered by the Important finding.
- **ARCH-PURE:** pass. The extracted function is pure and tested without IO.
- **ARCH-PURPOSE:** flag, but partial. The purpose ("make test on a quick-flow branch doesn't fail spuriously") is met for issues with no table, but not for the table shapes quick-flow issues have actually used, and not for the sibling case.

**Plan revisions**
None needed if the Important finding is fixed. If it's deferred instead, add a `## Revisions` entry saying that quick-flow tables whose rows don't start with a backtick (e.g. #330/#331), and the sibling case at `:171`, still fail a direct `make test`.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: core-concepts-guard-misreads-quick-flow-docs
    title: |
      Quick-flow tables whose rows don't start with a backtick (#330, #331) still fail the plan-to-code case, and the sibling code-to-table case fails on quick-flow branches
    detail: |
      concept_rows counts a Status-headed table but keeps only rows starting with a backtick. #330 and #331 (both quick flow, rows like "| Lock baseline | ...") give tables=1, rows=0, so make test still fails with the wrong message "has no rows" (13 workshop docs have this shape, including active plan 000209). Instances in this file: (a) the assert at single_source_sweeps_spec.lua:383; (b) the sibling code-to-table case at :171-244, which uses a second table definition (the "## Core concepts" section scan at :174) and fails on any quick-flow branch that adds an M.x export. Fix: count rows of any shape for the floor (or name the no-backtick case in the message), and have the sibling case use concept_rows and go pending when tables == 0. ARCH-DRY, ARCH-PURPOSE.
  - id: new
    severity: Minor
    kind: defect
    family: pending-reason-mislabels-cause
    title: |
      When the issue has no docs at all, the pending reason wrongly says there is no Core-concepts table (quick flow)
    detail: |
      At single_source_sweeps_spec.lua:377-380, tables == 0 also covers the case #docs == 0, and the pending message then blames the quick flow. The sibling case handles this separately at :144-147. Reuse that wording.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cb8647a9-7303-4ab3-b7bb-4ea1065ffd8d","repository":"github.com/xianxu/parley.nvim","issue_id":"000375","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/dcf99c939e609e8b","reviewed_head":"c6708d6f26f4d3a6e803ea45579c932c6d495c55","slot":"parley.nvim:3","requested_at":"2026-10-17T13:25:30.422447Z"},"phase":"finished","pid":77759,"started_at":"2026-10-17T13:25:30.595834Z","finished_at":"2026-10-17T13:28:57.183803Z","session_id":"ffd1c960-7a5a-44e1-a0c8-5479c8d0dd36","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T06:39:14-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 375 — single_source_sweeps fails a direct make test on a quick-flow issue branch with no Core-concepts table |
| repo | parley.nvim |
| issue file | workshop/issues/000375-single-source-sweeps-fails-a-direct-make-test-on-a-quick-flow-issue-branch-with-no-core-concepts-table.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3cd5f862bca097262961a519083271acde75ea3c..847a807c5ffd5ede0730be6f61e19484927db9db |
| command | sdlc close --issue 375 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T06:39:14-07:00 |
| verdict | SHIP |

## Review

Checking how this repo runs its tests so I can run the changed spec.

Running the spec through the repo's isolated test harness.

Old make lacks `--eval`; using a temp makefile include instead.

```verdict
verdict: SHIP
confidence: high
```

Both prior findings are fixed, and I checked each fix against the code rather than the commit messages. `concept_rows` (`tests/arch/single_source_sweeps_spec.lua:116`) is now the only place that parses Core-concepts tables, and both directions of the sweep use it. The code-to-table case no longer scans the `## Core concepts` section separately. A table whose rows name concepts in prose (as in #330 and #331) now counts its rows. The case with no docs at all has its own pending reason. I ran the spec through the repo's isolated test harness on a probe branch named `000375-…`, so the issue id came from the branch name the way it does for a worker. It passed. I then changed `concept_rows` back to its old backtick-only row filter, and the new spec "concept_rows tells a body without a table from an emptied one, and keeps prose rows" failed. So that fix has a regression test that fails without it. The only new finding is one Minor about pending-reason wording, which doesn't block.

1. **Strengths**
   - `concept_rows` is a pure function that parses a string and returns `(tables, rows)`. It is unit-tested directly, with no IO, on three bodies: no table, an emptied table and a full table (`:400-416`).
   - A table with no rows still fails: the floor `rows > 0` (`:392`) applies whenever a Status-headed table exists. That is the Spec's second clause.
   - Where a row with a backtick name matters, the plan-to-code case filters for those rows itself (`:329`). Rows of any shape still count toward the floor, which is what BR-1 asked for.
   - The code-to-table case now uses the same definition of a table as the plan-to-code case. BR-1(b) is closed.

2. **Critical**: none.

3. **Important**: none.

4. **Minor**
   - The pending reason at `:181` and `:389` says "has no Core-concepts table (quick flow)". The test it describes is that no table has a `Status` header. I counted 6 archived issue docs with a `## Core concepts` section whose table has no Status column (for example `000226`, `000243`, `000329`, `000343`, `000347` and `000348`, with headers like `| Concept | Meaning |`). On a branch like that, both cases now go pending and blame the quick flow, when the doc does have a Core-concepts table. This is the 2nd finding in family `pending-reason-mislabels-cause`. The rule that covers both: a pending reason should state the condition the code measured, not a cause it guessed. Both sites should say something like "no Status-headed Core-concepts table".

5. **Test coverage**
   - `concept_rows` is pinned for all three body shapes. Removing the fix makes the test fail; I checked by reverting it.
   - The pending path when there are zero tables, in both directions, is only exercised on a real issue branch. I ran it on a probe branch and it passed. There is no fixture test for it, which is acceptable for an arch guard that reads the branch name.
   - The pending path when there are no docs (BR-2) is not tested. It is a trivial branch that matches the wording the sibling case already uses (`:144-147`).

6. **Architecture**
   - **ARCH-DRY: pass.** The second table parser (the `## Core concepts` section scan) is gone, and both cases use one definition.
   - **ARCH-PURE: pass.** The parsing is a pure function, and the file and git IO stay in the test cases.
   - **ARCH-PURPOSE: pass.** Both Done-when clauses are delivered: the case is pending on a quick-flow branch, and a spec covers docs that exist but have no table. The class BR-1 named was also handled: prose rows, and the sibling case's separate parser.
   - One thing to watch: the Status header now defines what counts as a Core-concepts table for the code-to-table direction too. So a plan with an unrelated table that has a Status column can satisfy that direction. This was already true for the plan-to-code direction, so it is not raised.

7. **Plan revisions**: none. The plan's checklist and the Log entry for round 1 match the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      concept_rows keeps rows of any shape and the sibling reads through it; the new spec fails when the backtick-only filter is restored (checked by reverting).
  - id: BR-2
    disposition: addressed
    note: |
      A separate pending for no docs was added at :317-320, matching the sibling's wording at :144-147.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: pending-reason-mislabels-cause
    title: |
      The pending reason at :181 and :389 blames "quick flow" when the measured condition is that no table has a Status header
    detail: |
      2nd finding in this family. Rule: a pending reason states the condition the code measured, not a guessed cause. Instances: single_source_sweeps_spec.lua:181 and :389. Measured prevalence: 6 archived issue docs (e.g. 000226, 000243, 000329, 000343, 000347, 000348) have a Core concepts section whose table lacks a Status column and would be mislabelled. Fix both sites to say something like "no Status-headed Core-concepts table".
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"78b8a365-0036-4d97-b830-f78170dc1e40","repository":"github.com/xianxu/parley.nvim","issue_id":"000375","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6e5e32216947c3c8","reviewed_head":"847a807c5ffd5ede0730be6f61e19484927db9db","slot":"parley.nvim:3","requested_at":"2026-10-17T13:30:30.811227Z"},"phase":"finished","pid":48166,"started_at":"2026-10-17T13:30:31.139309Z","finished_at":"2026-10-17T13:39:13.812995Z","session_id":"b8c6660b-0425-4280-8f58-cb1b6985ea88","outcome":"returned"}] -->
