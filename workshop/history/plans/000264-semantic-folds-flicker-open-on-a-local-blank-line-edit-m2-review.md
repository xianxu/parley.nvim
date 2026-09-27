# Boundary Review — parley.nvim#264 (milestone M2)

| field | value |
|-------|-------|
| issue | 264 — Semantic folds flicker open on a local blank-line edit |
| repo | parley.nvim |
| issue file | workshop/issues/000264-semantic-folds-flicker-open-on-a-local-blank-line-edit.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 03a98d9f05c24e2b44f61dcc5636a24931446aba..03b004a39d1dc2872d89127b5ebf0c7ef2b711f3 |
| command | sdlc milestone-close --issue 264 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-27T15:04:50-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

M2 does what the plan says. A fragment transfer that fails only its end-checkpoint comparison now restarts at the edit's answer header instead of row 0. The restart logic now lives in one shared helper, `restart_point`, and `before_splice` keeps its old behaviour line for line. The dependency pruning is split into `prune_from` and `install`, so the index can be pruned before the splice while every handle still ranks. Before `install`, a guard checks that the index roots are the same objects that were pruned. The shortcut is sound. It makes the same `affected.origin==nil` proof over the `changed` channels that `before_splice` would make with `channels=changed`. Its restart row equals `before_splice`'s restart row, because `last<=frontier` forces `first<=position(w,w.global)`. At head, the extent spec passes 5/5 and the dependency spec passes 15/15; I ran both. Commit `bfd651d4` added the extent spec before the fix, and it was red then, so these tests do fail without the change. Every remaining finding is Minor, and none blocks the milestone.

1. **Strengths**
   - `semantic.lua:220-234`: `restart_point` replaces the old inline block with the same behaviour, including the fallback to row 0 when there is no checkpoint. This resolves the DRY concern carried from plan quality.
   - `dependencies.lua:171-196`: `prune_from` only computes; `install` is what commits. `remove_from` is now prune then install, with the same behaviour. The new unit test checks this against a twin index that runs `remove_from` directly, and checks that a prune that runs out of budget changes nothing.
   - `semantic.lua:519`: the guard compares `w.deps` and `w.deps.roots` by identity, which is O(1). This covers the gap the plan pointed out: `deps:add` does not bump `serial`, so the serial check alone can't prove the index is unchanged.
   - `document_uncertainty_extent_spec.lua`: each case checks the settled result against a fresh parse of the same text, comparing only fields that contain no handles, plus the fold ranges. It is the right oracle for a change that takes a shortcut through the parser.
   - Only the end-checkpoint mismatch takes the local restart. Every other reason to fall back still restarts at row 0.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**
   - `semantic.lua:520-523`, `:268-275`, `:410`: three places build an `evidence_store` entry by hand. `after_splice` reads all of these fields, and the plan had to spell out "**every** field `after_splice` reads". That shows how fragile this is: a new field would need three edits. (ARCH-DRY)
   - `semantic.lua:420`: `prune_from` is called without the `before_rank` the plan specified. It is consistent with the fragment path's own `restart_origin` call, and cost is bounded by `dep_budget` visits (at most 256). But the deviation is not recorded in the Log.
   - `semantic.lua:519`: no test reaches the guard's failing branch, where the index changed between the two calls. Nothing in the current flow mutates `w.deps` there, so the guard is defensive.
   - On the local-restart path, `evidence_store[captured.normal]` is never cleared. The store is weak-keyed, so this is harmless (ARCH-FUNERAL passes), but the reused path clears it and this one doesn't.

5. **Test coverage notes**
   - For the question-edit case, `range==nil` passes on its own because that case never falls back (the Log says so). It guards against regressions but does not exercise the local restart.
   - The m==n blank-count case (deleting the only blank) is not in the extent spec. It may be covered elsewhere through the M1 continuity spec.
   - The plan asked for work counts in `document_splice_admission_spec`. The Log records ms/key timing instead (0.50 → 0.48). That is acceptable as a measurement, but no test pins it.

6. **Architecture**
   - **ARCH-DRY**: flagged Minor (the evidence entries). Otherwise it passes: `restart_point` is shared.
   - **ARCH-PURE**: passes. The change stays in the pure parser and index; there is no IO.
   - **ARCH-PURPOSE**: passes. The per-kind negative (keeping a summary confirmed after an edit below it) was deliberately narrowed, and that is recorded in both the issue and the plan. The slower re-insert path the Log mentions is a separate extension, not the point of the issue.
   - **ARCH-MOCK**: not applicable. There is no external dependency; the tests use real buffers.
   - **ARCH-CONSTRAINTS**: passes. Pruning is bounded by `dep_budget`, and the timing was measured with no regression. The 242-row case went from 401 repair steps to 10.
   - **ARCH-SECURE**: not applicable. There is no untrusted input and there are no secrets.
   - **ARCH-ORDER**: passes. The state carried between `before_fragment` and `after_fragment` is guarded by identity on `serial`, `global` and the index roots; a mismatch takes the conservative path.
   - **ARCH-FUNERAL**: passes. The pruned roots live in the fragment store, which is weak-keyed, and are dropped once used or on the reused path.
   - For later work: the three hand-built evidence entries suggest `evidence_store` should have a single constructor next to `after_splice`.

7. **Plan revision recommendations**
   - Record in the Log that `prune_from` in `before_fragment` runs without `before_rank` (and why), next to the existing note about `restart_point` versus the captured header.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      tests/unit/fold_diff_spec.lua:67 property test over 200 seeds (exact matches untouched, regions whole, desired reached).
  - id: BR-2
    disposition: addressed
    note: |
      fold_diff.lua:11 and plan Step 3 state an oversized connected region forms its own batch exceeding limit, bounded by the plan span.
  - id: BR-3
    disposition: addressed
    note: |
      semantic.lua:220 restart_point shared by before_splice (:272) and before_fragment (:417); header reuse replaced by the helper, deviation logged.
  - id: BR-4
    disposition: addressed
    note: |
      tool_folds.lua reconcile re-verifies each batch before applying it (removals still folded, creation rows fold-free) and discards the plan when stale.
  - id: BR-5
    disposition: addressed
    note: |
      Suspended scopes run the same inventory+reconcile with paged walks (tool_folds.lua:257,262); the old clear/create phases are gone.
findings:
  - id: new
    severity: Minor
    family: reuse-existing-helper
    title: |
      evidence_store entries are hand-built at three sites; one constructor should own the shape after_splice reads
    detail: |
      This is the 2nd finding in family reuse-existing-helper. The rule is that a record read by one consumer (after_splice) is built by one constructor next to it. before_splice evidence() (:246), before_fragment normal (:410) and the new after_fragment local restart (:520) should all build through it, rather than fixing this one site.
  - id: new
    severity: Minor
    family: preserved-path-underspecified
    title: |
      prune_from in before_fragment omits the before_rank the plan specified; the deviation is unlogged
    detail: |
      This is the 2nd finding in family preserved-path-underspecified. The rule is that every plan-specified option that the implementation drops is recorded in the Log with its reason. The call matches the fragment path's own restart_origin call, and cost stays bounded by dep_budget.
  - id: new
    severity: Minor
    family: guard-branch-untested
    title: |
      No test reaches after_fragment's failing guard branch (index changed since prune)
    detail: |
      semantic.lua:519 falls back to row 0 when w.deps or its roots changed. No fixture mutates the index between before_fragment and after_fragment, so the guard is defensive and unexercised. A unit test that calls deps:add between the two calls would pin it.
```
