# Boundary Review — parley.nvim#264 (whole-issue close)

| field | value |
|-------|-------|
| issue | 264 — Semantic folds flicker open on a local blank-line edit |
| repo | parley.nvim |
| issue file | workshop/issues/000264-semantic-folds-flicker-open-on-a-local-blank-line-edit.md |
| boundary | whole-issue close |
| milestone | — |
| window | 18b54e44534e98e93cb8180364d144db95e55dfb..0f54fc9ee485e9f455b46320936408cb1e60a083 |
| command | sdlc close --issue 264 |
| reviewer | claude |
| timestamp | 2026-09-27T15:20:39-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

I reviewed the full range 18b54e44..0f54fc9e: the stat and name-status output, and the diffs for `fold_native.lua`, `fold_diff.lua`, `tool_folds.lua`, `semantic.lua`, `dependencies.lua` and their specs. The eight directly affected spec files all pass when run on their own: fold_diff 8/8, fold_native 3/3, document_semantic 22/22, document_dependencies 15/15, tool_folds 2/2, uncertainty_extent 5/5, fold_continuity 31/31, document_folds 7/7.

The Done-when criteria are met:
- **Continuity oracle:** closure is checked after every interleaved document and fold step, not only once repair settles.
- **Matrix:** all four foldable kinds and the blank-count matrix are covered.
- **Local uncertainty:** the uncertain range stays local (header restart, with cold-parse equality).
- **Folds stay closed:** uncertainty no longer clears native folds, and folds are reconciled by diff.

Of the six open findings, four are addressed (BR-7, BR-9, BR-10, BR-11) and BR-8 is withdrawn. BR-6 is fixed in code, but the Log's reason for leaving it untested ("no deterministic way to make `zC` fail") is wrong. A deterministic trigger exists, and I confirmed it. It is Minor and does not block.

**1. Strengths**
- **Pure diff with a property test.** `fold_diff.lua` is pure and small. Its property test (200 seeds) checks three things: exact matches are never touched, regions stay whole, and the result equals the desired set. The oversize-region rule is stated at `fold_diff.lua:11`.
- **One constructor and one restart rule.** `splice_evidence` (`semantic.lua:227`) is the single builder of what `after_splice` reads, and `restart_point` (`:237`) is the single restart rule. `evidence_store[` is now assigned at only one site (`:229`), so the BR-9 class is closed, not just the named instance.
- **Clean prune/install split.** `prune_from`/`install` separates computing the pruned roots from committing them. `remove_from` is rebuilt on top of the two, and a twin-index test shows it installs exactly what `remove_from` would.
- **Guard test proven to go red.** In a scratch copy I reduced the guard at `semantic.lua:531` to `if not r`, and "falls back to row 0 when the dependency index changed after pruning" failed (21/22).
- **Reconcile re-checks before acting.** Each batch is re-checked at `tool_folds.lua:280-293` before it is applied, and a stale inventory re-plans instead of guessing.

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **BR-6 (not addressed).** A deterministic trigger exists: set `foldminlines=1` (the default) and create a one-row fold (`3,3fold`). Then `zC` can't close it, `foldclosed` returns -1, and inventory raises. I confirmed this headless: `pcall(Native.walk, …, 'inventory')` returns the "could not close the fold at row 3" error. Add this as a `fold_native_spec` case and correct the Log sentence.
- **Unused `status` parameter.** `splice_evidence`'s `status` parameter (`semantic.lua:227`) has no caller that passes it; drop it.
- **Removals can apply before a creation check discards the plan.** In reconcile, a batch's removals run before its creation guard. If the creation guard then fails because the user ran `zf` between slices, the region stays unfolded until the re-plan one slice later. This only happens in the user-interleaving case and it converges, but the "no region unfolded between turns" comment at `:273` doesn't hold there.

**5. Test coverage notes**
- The continuity harness interleaves one document step with one fold step, deterministically. That matches the scheduled callbacks, but it observes only one interleaving (ARCH-ORDER oracle caveat). The mutation evidence in the Log (the eager clear restored turns 22 cases red) shows it does discriminate.
- BR-6's error path is the only new behaviour with no test (see above).

**6. Architecture**
- **ARCH-DRY: pass.** `splice_evidence` and `restart_point` are shared, and the native walk lives only in `fold_native`.
- **ARCH-PURE: pass.** `fold_diff` is pure and `fold_native` is the IO shell.
- **ARCH-PURPOSE: pass.** All four kinds are handled, and uncertainty is fixed in both halves (a and b). The re-insert slowdown is logged as a separable follow-up.
- **ARCH-MOCK: N/A.** The only dependency is Neovim itself, and the tests run in real headless nvim.
- **ARCH-CONSTRAINTS: pass.** Measured per-key cost is 0.50 → 0.48 ms, repair steps drop from 401 to 10, and paging is bounded above 50k rows.
- **ARCH-SECURE: N/A.** There is no untrusted input and no secrets.
- **ARCH-ORDER: pass with notes.** Apply's phases are explicit (capture → inventory → reconcile → done). The staleness guards are start-row-only (BR-8, accepted) plus the Minor above.
- **ARCH-FUNERAL: pass.** Plan and window state live in memory and die with the plan. The `b:parley_fold_inventory_broken` variable is overwritten on every walk.

**7. Plan revisions:** none. The `before_rank` omission and the `restart_point` deviation are already logged.

```findings
dispose:
  - id: BR-6
    disposition: not-addressed
    note: |
      Code fix present (fold_native.lua:105,176) but untested; Log claims no deterministic trigger, yet foldminlines=1 plus a one-row fold (3,3fold) makes zC fail deterministically (verified headless). Add that fold_native_spec case.
  - id: BR-7
    disposition: addressed
    note: |
      tool_folds.lua:139 computes first once; job.first=first at :147 (pure refactor, no behaviour change).
  - id: BR-8
    disposition: withdrawn
    note: |
      Accepted in the Log (M1 review minors item 3): same reach as the pre-#264 clear walk, not a regression; a re-plan converges.
  - id: BR-9
    disposition: addressed
    note: |
      splice_evidence (semantic.lua:227) is the sole evidence_store writer (:229); before_splice, before_fragment normal and after_fragment local restart all use it.
  - id: BR-10
    disposition: addressed
    note: |
      Plan deviation (prune_from without before_rank) is logged in the issue M2 review entry with its reason.
  - id: BR-11
    disposition: addressed
    note: |
      document_semantic_spec guard test; reverting the guard at semantic.lua:531 in a scratch copy turns it red (21/22).
findings:
  - id: new
    severity: Minor
    family: preserved-path-underspecified
    title: |
      splice_evidence takes a status parameter no caller passes
    detail: |
      semantic.lua:227: every caller passes nil, so status is always derived from fallback. Drop the parameter so the constructor's surface matches its use.
```
