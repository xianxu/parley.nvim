---
id: 000219
status: done
deps: []
github_issue:
created: 2026-09-05
updated: 2026-09-13
estimate_hours: 0.988
started: 2026-09-13T13:03:44-07:00
actual_hours: N/A
---

# prepare_dir races on concurrent setup, failing specs intermittently

## Problem

Observed during #218's close: `make test` failed with

```
E739: Cannot create directory
  .../xdg/data/nvim/parley/persisted: file already exists
    helper.lua:554  prepare_dir
    vault.lua:34    setup
    init.lua:550    setup
```

`tests/unit/chat_slug_resolve_spec.lua` failed in the full run and **passed in
isolation**; an immediate re-run of the whole suite was green. The path in
question exists and is a directory, so nothing was corrupt.

`helper.lua:552-555` is check-then-act:

```lua
if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
end
```

Two spec processes calling `parley.setup()` at the same time both observe
`isdirectory == 0`, both call `mkdir`, and the loser raises. The guard is what
creates the window — it is a classic TOCTOU.

Not a #218 defect: nothing on that issue's diff is on this path. Filed rather
than dismissed as a flake, because "re-run until green" is how a real race gets
normalised.

## Spec

Make directory creation idempotent rather than guarded. `pcall` the `mkdir` and
re-check `isdirectory` afterwards, so a concurrent creator is indistinguishable
from success; only a path that is genuinely not a directory afterwards is an
error.

Sweep the class, not this call: any check-then-act around `mkdir`/`writefile` in
`lua/` has the same shape. `helper.prepare_dir` is the shared seam most callers
already use — the finding is whether any caller bypasses it.

## Done when

- concurrent `setup()` cannot raise E739
- a path that exists as a FILE where a directory is needed still errors, loudly
- the enumeration of check-then-act `mkdir` sites in `lua/` is recorded, and
  each either routes through `prepare_dir` or says why not

## Plan

- [x] Enumerate check-then-act `mkdir` sites in `lua/`
- [x] Make `prepare_dir` idempotent; keep the file-in-the-way case an error
- [x] Test: two calls racing the same path both succeed; a file at the path fails
- [x] Route or justify each other site

## Log


- 2026-09-13: closed — Deterministic E739 regression red then 8/8 green; six affected consumer suites pass; lint 395 files clean; integrated archive all unit specs pass, unrelated chat_move E95 and branch_child path fixture failures under #208 investigation. No measurable delegated worktree activity; --no-actual avoids invented hours.; review verdict: SHIP
### 2026-09-05

Surfaced by #218's close run. Frequency unknown — one occurrence in roughly a
dozen full-suite runs this session.

## Revisions

### 2026-09-13 — resumed as #208 release blocker

The class sweep finds logger's dependency prevents importing helper at module load. Delegate literal mkdir to a dependency-free filesystem seam and route all writers through it; helper retains path expansion. Detailed plan: `workshop/plans/000219-prepare-dir-race-plan.md`.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.20 impl=0.30
item: cross-cutting-refactor design=0.08 impl=0.12
item: atlas-docs design=0.02 impl=0.04
item: milestone-review design=0.02 impl=0.16
design-buffer: 0.15
total: 0.988
```

Derived after plan-quality passed: focused Lua seam 1.0h design ×0.2 and 0.75h implementation ×0.4; mechanical consumer sweep 0.4h ×0.2 and 0.3h ×0.4; atlas 0.1h ×0.2 and 0.1h ×0.4; review 0.1h ×0.2 and 0.4h ×0.4. Existing Neovim mkdir/isdirectory supplies the IO, no novel library. Design subtotal 0.32h with 15% buffer plus implementation 0.62h = 0.988h.

### 2026-09-13 — implementation and sweep

Plan-quality accepted round 2 (PQ-1 addressed). Estimate-quality INFO: the Lua allocation includes deterministic seam/helper regressions; cross-cutting includes the writer audit and singleton-source guard; review includes verification/shipping. No novel library or new content-write policy.

ARCH-DRY/ORDER: the shared literal-path `fs.ensure_dir` owns one mkdir attempt and postcondition check. `helper.prepare_dir` delegates after its existing expansion/rejection. Logger and file_tracker retain their existence fast paths; notes retains default-template content policy. All direct writers now delegate: tools/builtin/write_file parent, raw_log parent, issues child-issue directory, cliproxy config/key/catalog/bin/staging, and assets' mkdir adapter (preserving false,error). There are no remaining raw mkdir sites outside fs.lua.

The writefile sweep covered memory_prefs, issue_finder, issues, notes, file_tracker, init, and cliproxy. These writes persist content or apply edits; their readable/existence checks choose content or prevent accidental overwrite, not an alternative directory creator. Their content concurrency contracts are unchanged.

TDD evidence: `/tmp/parley219-red.log` has the deterministic real competing creator raising E739 through old prepare_dir (3 pass, 1 fail); `/tmp/parley219-green.log` has 8 passing directory regression tests. Baseline helper suite passed 19 tests before changes. Parent #208 will run complete integrated archive suite before close.

Targeted affected consumers all passed in isolated HOME/XDG (helper_io, assets, logger, raw_log, file_tracker, cliproxy_config); lint 395 files has 0 warnings/errors; git diff --check clean. Integrated archive run `/tmp/parley208-resume-archive-full.log` passed every unit spec including the original concurrent setup path; integration failed in chat_move (E95 fixture buffer reuse) and branch_child (long-path backlink expectation), which parent #208 is investigating independently. `sdlc actual --issue 219 --brain-dir /Users/xianxu/workspace/brain` found no measurable activity for this delegated worktree; close uses --no-actual rather than inventing hours.
