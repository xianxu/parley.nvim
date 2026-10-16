# Boundary Review — parley.nvim#347 (whole-issue close)

| field | value |
|-------|-------|
| issue | 347 — fs.ensure_dir fails when another process creates an intermediate directory concurrently |
| repo | parley.nvim |
| issue file | workshop/issues/000347-fs-ensure-dir-fails-when-another-process-creates-an-intermediate-directory-concurrently.md |
| boundary | whole-issue close |
| milestone | — |
| window | 9e31a35c874aba9fcdae0d38002d162cab056bf5..3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd |
| command | sdlc close --issue 347 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T02:16:07-07:00 |
| verdict | SHIP |

## Review

Still checking how the test suite runs so I can run the two changed specs.

Running the two changed specs through the project's isolated test harness.

Both pass. Now reverting fs.lua to base to confirm red.

```verdict
verdict: SHIP
confidence: high
```

This change fixes #347 the way the Spec describes. `fs.ensure_dir` now walks up to the nearest directory that already exists, then creates each missing level with a single `vim.fn.mkdir` call (no `p`). If that call fails but the level is a directory afterwards, it counts as success; otherwise it raises the original error. `vim.fn.mkdir` is still the only production place that creates directories, and the source-guard test still enforces that. I ran both changed specs through the project's isolated test environment: `prepare_dir_spec` passed 10/10 and `ensure_dir_race_spec` passed 1/1. I then put back the base version of `lua/parley/fs.lua` and both went red: the new #347 case failed in `prepare_dir_spec` (9 pass, 1 fail) and the race spec failed. So the regression evidence is real. The checkout is restored and clean. Nothing blocks SHIP. There are only two Minor notes.

1. **Strengths**
   - `lua/parley/fs.lua:28-37`: it checks `isdirectory` before recursing, so a directory that already exists costs one stat call and never calls mkdir. The recursion stops at the root (`parent ~= path`) and on an empty parent. Relative paths stop at `.`.
   - `lua/parley/fs.lua:6-19`: `mkdir_level` keeps the error rules from before: the directory postcondition wins, otherwise the original pcall error is raised, otherwise "Cannot create directory". All the earlier error-path tests still pass unchanged.
   - `mode` now applies to every level the function creates. That matches what Neovim's `mkdir(…, "p", prot)` did before, so callers like `starter.lua:17` and `:165` (mode 448) see no change.
   - There are two kinds of tests. One fakes the race at the mkdir call (`prepare_dir_spec.lua:25`), so it is fast and always gives the same result. The other races real nvim processes (`ensure_dir_race_spec.lua`). Both are confirmed red on the old code.
   - The atlas (`test_harness.md`) and `traceability.yaml` are updated in the same range.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `tests/integration/ensure_dir_race_spec.lua:4`: the header says "8 of 180 failed". That figure is the 6×30 measurement from the Log, but this spec runs 6×20 = 120 creators. This is the only count claim in the window. Reword it to say where the number came from.
   - The Done-when clause about still raising real failures is only tested when the failure is at the leaf (a file at the path, or a faked permission error). Nothing puts a file where an intermediate directory should be, which is the new code path in `mkdir_level` for non-leaf levels. Adding a case like `root/file/child`, where `root/file` is a regular file, would cover it.

5. **Test coverage notes:** the race spec is timing-dependent. On fixed code it cannot fail falsely; it can only pass falsely on broken code. Its role as a red check is backed by the deterministic seam case, which is the right pairing. It runs 120 nvim processes per run, which is acceptable for an integration spec.

6. **Architecture**
   - **ARCH-DRY:** pass. There is one directory-creation seam, and the source guard still keeps it the only one. `raw_log.lua:31` and `file_tracker.lua:32` are thin wrappers that compute a parent path, not duplicates.
   - **ARCH-PURE:** pass. `fs.lua` is meant to be the IO layer, and the small amount of path logic in it doesn't justify pulling out a separate pure function.
   - **ARCH-PURPOSE:** pass. The issue is about any ancestor being created at the same time. Every production caller goes through `fs.ensure_dir`, so all of them get the fix, including `helper.prepare_dir` → `vault.setup`, which is the failure the issue reported.

7. **Plan revision recommendations:** none. The Core concepts table (`mkdir_level`) matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-unverified-count
    title: |
      ensure_dir_race_spec header cites "8 of 180" but the spec runs 120 creators
    detail: |
      tests/integration/ensure_dir_race_spec.lua:4 restates the Log's 6x30 measurement while the spec loops 20 rounds x 6. Only count claim in the window; say where it came from or use the spec's own numbers.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-both-modes-coverage
    title: |
      No test for a real failure (file in the way) at an INTERMEDIATE level
    detail: |
      The "still raises a real failure" clause is tested only at the leaf (prepare_dir_spec "rejects a file obstructing", "preserves the original mkdir error"). Add a case where root/file is a regular file and ensure_dir(root/file/child) raises, which exercises mkdir_level's raise on a non-leaf level.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"74705fb6-3462-4860-ab84-4f6c20789f80","repository":"github.com/xianxu/parley.nvim","issue_id":"000347","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/7022b662f7868166","reviewed_head":"3d9726a73cf806d5ca83e0acdd7f085a10a1ebdd","slot":"parley.nvim:3","requested_at":"2026-10-16T09:13:58.187132Z"},"phase":"finished","pid":64486,"started_at":"2026-10-16T09:13:58.341512Z","finished_at":"2026-10-16T09:16:05.656871Z","session_id":"cc8f3590-5a69-4a19-a23a-1d967fd9d73d","outcome":"returned"}] -->
