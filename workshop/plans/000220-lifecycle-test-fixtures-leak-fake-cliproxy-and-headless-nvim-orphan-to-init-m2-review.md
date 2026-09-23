# Boundary Review — parley.nvim#220 (milestone M2)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..bdb895b60cf0f6a4181a4ecfd6348a09fc4583e8 |
| command | sdlc milestone-close --issue 220 --milestone M2 |
| reviewer | codex |
| timestamp | 2026-09-22T18:45:43-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared fixture registry, watchdog placement, and Makefile wiring provide useful cleanup coverage. However, the census can kill unrelated editors, malformed resampling can falsely report success, and watchdog cleanup silently fails. These block shipping. The pinned objects and required inspection commands were available; no files were modified.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The plan still contains complete implementation and test bodies, including Task 4's census script at workshop/plans/000220-reap-test-fixture-processes-plan.md:1108. Retain contracts, function names, and verification strategy; remove duplicated bodies and stale line-number inventories.
  - id: BR-2
    disposition: not-addressed
    note: |
      The prior purity correction remains incomplete: the plan's Pure entities table lists orphaned at line 76, but tests/fixtures/fixture_watchdog.py:25 reads os.getppid(), and tests/unit/reap_test_orphans_pure.py patches that dependency in all three watchdog cases. Direct invocation did not make this entity PURE. Extract orphaned(parent, current_ppid) and test it without mocks, or revise its classification.
findings:
  - id: new
    severity: Critical
    family: process-ownership-before-signalling
    title: |
      The census selects unrelated editors and pagers for SIGKILL
    detail: |
      scripts/reap-test-orphans.py:72 treats any argument containing the fixture-directory path as process ownership. Direct evaluation selects both "/usr/bin/nvim /repo/tests/fixtures/fake_cliproxy" and "/usr/bin/less /repo/tests/fixtures/ps_test_orphans.txt"; reap() then sends SIGKILL at line 131. Establish executable/script identity rather than matching arbitrary arguments, and add negative cases for editors, viewers, and commands merely mentioning fixture paths.
  - id: new
    severity: Critical
    family: process-observation-validity
    title: |
      Malformed grace-period samples turn known survivors into a clean result
    detail: |
      scripts/reap-test-orphans.py:119 parses subsequent samples without the initial sample's validity check. A valid initial table containing a fixture followed by malformed successful output empties survivors; invoking main with that sequence printed "clean: no surviving test processes" and returned 0. Validate every sample through one shared boundary and preserve an explicit unknown/broken outcome; test valid-to-malformed and valid-to-unavailable sequences.
  - id: new
    severity: Important
    family: cleanup-execution-context
    title: |
      Watchdog query-directory cleanup always fails in the timer callback
    detail: |
      tests/minimal_init.vim:54 calls vim.fn.delete from the fast-event callback in tests/helpers/exit_with_parent.lua:46. A headless Neovim reproduction returned E5560; pcall suppresses it before os.exit skips VimLeavePre. Use cleanup valid in that context and verify that an orphaned harness removes its query directory, not merely that its PID disappears.
  - id: new
    severity: Important
    family: readme-surface-discovery
    title: |
      README update is missing for the new manual census command
    detail: |
      TOOLING.md:78 introduces an operator command with --root and --phase, but README.md is unchanged in the pinned range. The existing generic contributor link does not satisfy this review's explicit same-range README gate. Add a short cleanup-command pointer linking to the detailed TOOLING section.
```

1. **Strengths**
   - `fixture_process.lua` consolidates spawn ownership and uses monotonic marks to preserve file-scope fixtures during per-case cleanup.
   - Server watchdog installation occurs at `LoopbackHTTPServer` construction; blocking non-server modes have explicit coverage.
   - Failed Makefile spec loops retain failure status while reaching the after-census.
   - Atlas updates explain the cleanup layers and same-checkout concurrency restriction.

2. **Critical findings**
   - Unsafe process selection and false-clean resampling are detailed above.
   - **BR-2 remains Critical under the Core-concepts contract:** a mocked process observation is still classified as PURE. This is a reopened disposition, not a new finding in `pure-entity-test-seam`.

3. **Important findings**
   - Fast-event cleanup failure and the README omission are detailed above.

4. **Minor findings**
   - **BR-1:** the plan still duplicates implementation extensively; it remains non-blocking.

5. **Test coverage notes**
   - Ran the six Python tests: all passed.
   - Independently reproduced unsafe selection, a false-clean `main()` result, and Neovim’s E5560 cleanup failure.
   - Pinned-range `git diff --check` passed.
   - Did not rerun the destructive live census or full process-spawning suite under the read-only review constraint. Tracker claims of full-suite and interruption success were not treated as independently verified evidence.

6. **Architectural notes**

   | Marker | Assessment |
   |---|---|
   | ARCH-DRY | **Pass:** shared registry and census invocation replace local copies. |
   | ARCH-PURE | **Flag:** BR-2’s watchdog predicate still reads process state. |
   | ARCH-PURPOSE | **Flag:** invalid resampling defeats the promised visible leak failure. |
   | ARCH-MOCK | **Pass:** recorded-table seam and live conformance case exist; sequence coverage needs expansion. |
   | ARCH-CONSTRAINTS | **Pass:** polling/grace budgets and checkout concurrency limits are documented. |
   | ARCH-SECURE | **Flag:** fixture-path arguments do not establish authority to signal a process. |
   | ARCH-ORDER | **Flag:** an invalid observation becomes confirmed absence. |
   | ARCH-FUNERAL | **Flag:** the watchdog exit path leaves query directories behind. |

7. **Plan revision recommendations**
   - Append a `## Revisions` entry defining safe process ownership and valid/invalid resampling outcomes.
   - Correct `orphaned`’s PURE classification or extract the pure predicate.
   - Record fast-event-compatible cleanup and directory-removal verification.
   - Resolve BR-1 by replacing copied bodies with concise contracts and source references.
