# Boundary Review — 000219-prepare-dir-races-on-concurrent-setup-failing-specs-intermittently#219 (whole-issue close)

| field | value |
|-------|-------|
| issue | 219 — prepare_dir races on concurrent setup, failing specs intermittently |
| repo | 000219-prepare-dir-races-on-concurrent-setup-failing-specs-intermittently |
| issue file | workshop/issues/000219-prepare-dir-races-on-concurrent-setup-failing-specs-intermittently.md |
| boundary | whole-issue close |
| milestone | — |
| window | 9fa5e1ad99e4531139dcc413ae8b0b6081a7130c..3c795d04b39f3828985a5333f2aa4df0d7dad45b |
| command | sdlc close --issue 219 |
| reviewer | codex |
| timestamp | 2026-09-13T13:12:17-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned diff satisfies the directory-race contract. All production `mkdir` calls use the shared postcondition check, genuine failures remain visible, and the regression fails with the original helper. No blocking findings; two minor Plan documentation gaps remain.

1. **Strengths**
   - `lua/parley/fs.lua:6` centralizes directory creation without introducing helper/logger dependency cycles.
   - `tests/unit/prepare_dir_spec.lua:15` deterministically reproduces the competing creator using a real temporary directory.
   - `lua/parley/assets.lua:1022` preserves its boolean/error interface.
   - The issue records the writer enumeration, and the atlas documents the new internal seam. No new user-facing surface requires a README change.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings**
   - `workshop/plans/000219-prepare-dir-race-plan.md:31`: the documented focused-test command fails because `prepare_dir` has no traceability mapping. Replace it with a working invocation or add the mapping.
   - `workshop/plans/000219-prepare-dir-race-plan.md:15`: add the required `Kind` column and classify `ensure_dir` as `INTEGRATION`. The surrounding prose already classifies it correctly.

5. **Test coverage notes**
   - All **243 tests across seven focused/affected suites passed**, including all eight new regressions.
   - Loading the pinned base helper against the new tests produces **7 passes and 1 failure**, specifically the E739 race regression.
   - Lint passed: **395 files, zero warnings/errors**. Diff whitespace checks passed.
   - Full-suite results recorded by the implementor were not independently rerun.

6. **Architectural notes**
   - **ARCH-DRY — pass:** one production mkdir boundary; source guard enforces consolidation.
   - **ARCH-PURE — pass:** small filesystem integration; path policy stays with callers.
   - **ARCH-PURPOSE — pass:** all production mkdir consumers migrated; content-write policies remain explicitly outside this fix.
   - **ARCH-MOCK — pass:** injected ordering changes real temporary filesystem state; no new external service dependency.
   - **ARCH-CONSTRAINTS — pass:** one mkdir attempt and postcondition check; no retries or background work.
   - **ARCH-SECURE — pass:** literal paths remain literal; tests use isolated temporary storage.
   - **ARCH-ORDER — pass:** the losing-creator ordering is reproducible and independently demonstrated red without the fix.
   - **ARCH-FUNERAL — pass:** no new production artifact family; test roots are cleaned up.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry correcting the focused-test invocation and making the integration classification explicit.

```findings
findings:
  - id: new
    severity: Minor
    family: verification-command-accuracy
    title: |
      The Plan's focused-test command does not run the regression
    detail: |
      workshop/plans/000219-prepare-dir-race-plan.md:31 specifies SPEC=prepare_dir, but that key has no traceability mapping and the command exits 2. Document a working isolated Plenary invocation or add the mapping; the regression passes when run directly.
  - id: new
    severity: Minor
    family: core-concept-classification
    title: |
      The Core concepts table omits the required Kind column
    detail: |
      workshop/plans/000219-prepare-dir-race-plan.md:15 should classify ensure_dir as INTEGRATION. Its implementation and surrounding prose agree on that classification, so this is a table-format omission rather than an ARCH-PURE contradiction.
```
