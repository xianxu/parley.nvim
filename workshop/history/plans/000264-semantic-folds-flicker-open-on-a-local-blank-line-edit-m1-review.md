# Boundary Review — parley.nvim#264 (milestone M1)

| field | value |
|-------|-------|
| issue | 264 — Semantic folds flicker open on a local blank-line edit |
| repo | parley.nvim |
| issue file | workshop/issues/000264-semantic-folds-flicker-open-on-a-local-blank-line-edit.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 18b54e44534e98e93cb8180364d144db95e55dfb..feacac76caf1e572061a65a0fe06b338d72acd4b |
| command | sdlc milestone-close --issue 264 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-27T13:04:40-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

**Verdict: SHIP (medium confidence).** M1 does what the Plan's M1 row and the 2026-09-27 operator-direction revision promise.

- **Reconcile in place:** `apply` now runs capture, then a read-only inventory, then a pure `fold_diff`, then batch reconcile. It leaves exact-match folds alone and never splits an overlap region across event-loop turns.
- **Uncertainty removes no folds:** below `INTERACTIVE_ROWS`, `clear_uncertainty` does no native fold work. It only widens the repair scope.
- **Regression test:** the continuity spec checks after every fold step and every document step, not just once repair settles. That is the oracle the issue asked for.

I ran fold_diff (8), fold_native (3), document_fold_continuity (31), document_folds (7), tool_folds (2), document_fold_join (3) and document_presentation_reentrant (8) at HEAD `feacac76`. All passed. The implementer's Log records a mutation check: putting the eager clear back turns 22 cases red. That matches how the harness is built (`repair()` interleaves `F.step` with `D.repair_step`), though I did not re-run the mutation myself. Nothing blocks the boundary. Two things are left for M2 or later: the whole-document `uncertain_range` (Spec (a)) and the stale-fold-during-uncertainty trade the operator accepted.

1. **Strengths**
   - `lua/parley/fold_diff.lua:13` is a small, pure, property-tested diff (200 seeds). Keeping exact matches out of every batch and sweeping connected regions is the right primitive, and it makes the "untouched fold never blinks" invariant structural.
   - Moving the walk into `lua/parley/fold_native.lua` (ARCH-DRY) gives the VimL walk one home. The ≥50k-row delete path and the new inventory mode now share one guarded crossing.
   - `tests/integration/document_fold_continuity_spec.lua:59-73` interleaves document and fold steps as the scheduler does. The Log shows this was found by mutation, which is the right way to validate an oracle.
   - The reconcile phase re-checks its inventory before acting: removals need `foldlevel>0` and creations need `foldlevel==0` at both ends. This covers user `zf`/`zd` between slices, which don't bump `changedtick` (`tool_folds.lua:295-307`).
   - Existing tests that pinned the old eager clear were updated to state the new invariant, not deleted, and the renamed test titles say what changed.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Inventory can stop early but report success** (`fold_native.lua` inventory branch). If `zC` leaves `foldclosed == -1` (`if s:fs == -1 | break | endif`), the walk exits and `done` still evaluates true. Folds below that point are then missing from the inventory. The creation pre-check would then call `discard_plan`, and the next step re-plans the same way, so it can loop without bound. It is unlikely because `configure` forces manual folds and `foldenable` is on. Suggested fix: set a failure flag so `done` is false, or report an error.
   - **Duplicated expression** (`tool_folds.lua:139` vs `:146`). `math.max(scope.first, s.owned_first or scope.first)` is computed as `first` and then recomputed for `job.first`. Reuse `first`.
   - **Removal checks the start row, not the extent** (`tool_folds.lua:295`). The stale-inventory guard only tests `foldlevel(start)>0`. A user fold made between slices at the same start row, with a different extent, would be `zD`'d. The old clear walk deleted user folds in the span too, so this is not a regression.
   - **One template, two modes** (`fold_native.walk`). The inventory flag is spliced into the delete template via `%s`. It works, but the walk is now two algorithms in one VimL string. Consider splitting it if M2 touches it again.

5. **Test coverage notes**
   - Covered: summary, thinking and tool with the blank matrix (m<n and m==n); a second exchange; real-keystroke joins; streaming appends; zero-touch `removed==0` counters. Inventory has direct unit tests for nesting, a fold ending on the last row, and paging.
   - The tool-pair blank cases are green controls: they had no uncertainty before, so they can't show a regression. That fits the bounded-extent analysis.
   - The Done-when item "`uncertain_range` no longer reports a whole-document span" is correctly left to M2, which will need the extent spec.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The walk is moved, not copied. The duplicated expression above is minor.
   - **ARCH-PURE: pass.** `fold_diff` is pure; native IO stays in `fold_native` and in the `apply` shell.
   - **ARCH-PURPOSE: pass for M1.** The class is swept: every foldable kind, and both the `apply()` streaming site and `clear_uncertainty`. Spec (a) is a planned M2, not a deferral of the point of the issue.
   - **ARCH-MOCK: N/A.** No external binaries or services; the tests run against real Neovim folds.
   - **ARCH-CONSTRAINTS: pass.** The ≥50k-row path is unchanged. Inventory costs about 6 ops per group instead of 2, but no fold is deleted and recreated, and the Log's measured suite times went down. Cost is O(folds), not O(rows).
   - **ARCH-SECURE: N/A.** No untrusted input or secrets.
   - **ARCH-ORDER: pass, with a note.** The per-window phases are a readable enumeration (capture → inventory → reconcile → done), and each slice checks `current()` for `changedtick` and ownership. The Minor pre-check loop above is the one unbounded retry.
   - **ARCH-FUNERAL: pass.** Nothing durable is created. The `b:parley_fold_clear_*` variables are overwritten on every walk.
   - **Docs gate:** `atlas/chat/document.md` and `atlas/traceability.yaml` are updated. No README surface was added.

7. **Plan revisions:** none needed. The Core-concepts table names `diff` in `fold_diff.lua`, and the Log records `walk`, `valid_target` and `restore_window` in `fold_native.lua`, which matches the code.

```findings
findings:
  - id: new
    severity: Minor
    family: walk-early-exit-reports-done
    title: |
      fold_native inventory can break on zC failure yet report done=true, truncating the inventory
    detail: |
      The `s:fs == -1` break leaves done computed true; the creation pre-check then discards and re-plans without bound. Flag the failure so done is false, or raise an error.
  - id: new
    severity: Minor
    family: duplicated-expression
    title: |
      clear_uncertainty computes first then recomputes the same expression for job.first
  - id: new
    severity: Minor
    family: stale-inventory-guard-precision
    title: |
      reconcile removal guard checks foldlevel at the start row only, not the inventoried extent
    detail: |
      A user fold at the same start row but a different extent, made between slices, would be zD'd. The pre-#264 clear walk had the same reach, so this is not a regression.
```
