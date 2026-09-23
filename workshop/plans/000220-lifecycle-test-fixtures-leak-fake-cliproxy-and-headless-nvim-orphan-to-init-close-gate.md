---
gate: boundary-review
issue: 220
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-22T14:48:45-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: 1803 lines carrying complete spec bodies and the whole census script verbatim
          detail: |-
            The function names plus one strategy line per risky function carry the same
            design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
            is the right instinct done wrong — it already says the arch guard, not the
            table, owns completeness, so the table can go.
            (carried from plan-quality PQ-5, deferred to the boundary review)
          family: plan-restates-the-diff
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-22T14:48:45-07:00"
      agent: codex
      findings:
        - id: BR-2
          severity: Critical
          title: Core-concepts PURE entities are not tested without IO
          detail: 'The plan labels parse_ps, select_orphans, ancestry, and orphaned as PURE (workshop/plans/000220-reap-test-fixture-processes-plan.md:67-129), but the tests invoke the Python script through vim.system and --ps-from (tests/unit/reap_test_orphans_spec.lua:7-10), while watchdog behavior is tested only through real orphaned processes (tests/integration/fixture_reaping_spec.lua:17-85). Add direct no-IO tests for the pure functions, or revise the Core-concepts table and classifications to INTEGRATION; record the correction in ## Revisions.'
          family: pure-entity-test-seam
          round: 2
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-22T14:54:20-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The durable plan remains approximately 1997 lines and still embeds complete spec bodies and census implementation text.
          round: 3
        - id: BR-2
          disposition: addressed
          note: tests/unit/reap_test_orphans_pure.py directly tests parse_ps, select_orphans, ancestry, and orphaned without process or filesystem IO; 5/5 tests pass.
          round: 3
      findings:
        - id: BR-3
          severity: Important
          title: Grace resampling ignores the configured ps command
          detail: scripts/reap-test-orphans.py:115 calls read_process_table(None, "ps") instead of using the caller's --ps-command. A custom or injected process-table provider is used for the initial sample but silently replaced by the real ps during grace polling. Thread ps_command through persistent_candidates and add a regression test proving every sample uses the configured seam. ARCH-MOCK.
          family: external-seam-consistency
          round: 3
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 4
      timestamp: "2026-09-22T14:59:10-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The durable plan remains approximately 2003 lines and still embeds complete implementation/spec bodies.
          round: 4
        - id: BR-3
          disposition: addressed
          note: scripts/reap-test-orphans.py now threads ps_command through persistent_candidates, with a regression test in tests/unit/reap_test_orphans_pure.py that fails if resampling uses literal ps.
          round: 4
      findings:
        - id: BR-4
          severity: Important
          title: Atlas update is missing for the new fixture lifecycle/reaping surface
          detail: The diff adds exit_with_parent, fixture-process registry ownership, watchdog-based fixture cleanup, and the reap-test-orphans census, but only updates traceability.yaml; atlas/infra/test_harness.md is unchanged and has no corresponding lifecycle/reaping documentation. Add the architectural surface to atlas in this boundary. ARCH-PURPOSE.
          family: atlas-update-missing
          round: 4
      boundary: M1
      recipe: milestone-review
      blocked: true
    - "n": 5
      timestamp: "2026-09-22T15:04:43-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The durable plan still embeds extensive implementation and test bodies; retain as a Minor follow-up.
          round: 5
        - id: BR-4
          disposition: addressed
          note: atlas/infra/test_harness.md now documents the watchdogs, fixture registry, detached-process handling, and orphan census.
          round: 5
      boundary: M1
      recipe: milestone-review
      blocked: false
    - "n": 6
      timestamp: "2026-09-22T18:45:43-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The plan still contains complete implementation and test bodies, including Task 4's census script at workshop/plans/000220-reap-test-fixture-processes-plan.md:1108. Retain contracts, function names, and verification strategy; remove duplicated bodies and stale line-number inventories.
          round: 6
        - id: BR-2
          disposition: not-addressed
          note: 'The prior purity correction remains incomplete: the plan''s Pure entities table lists orphaned at line 76, but tests/fixtures/fixture_watchdog.py:25 reads os.getppid(), and tests/unit/reap_test_orphans_pure.py patches that dependency in all three watchdog cases. Direct invocation did not make this entity PURE. Extract orphaned(parent, current_ppid) and test it without mocks, or revise its classification.'
          round: 6
      findings:
        - id: BR-5
          severity: Critical
          title: The census selects unrelated editors and pagers for SIGKILL
          detail: scripts/reap-test-orphans.py:72 treats any argument containing the fixture-directory path as process ownership. Direct evaluation selects both "/usr/bin/nvim /repo/tests/fixtures/fake_cliproxy" and "/usr/bin/less /repo/tests/fixtures/ps_test_orphans.txt"; reap() then sends SIGKILL at line 131. Establish executable/script identity rather than matching arbitrary arguments, and add negative cases for editors, viewers, and commands merely mentioning fixture paths.
          family: process-ownership-before-signalling
          round: 6
        - id: BR-6
          severity: Critical
          title: Malformed grace-period samples turn known survivors into a clean result
          detail: 'scripts/reap-test-orphans.py:119 parses subsequent samples without the initial sample''s validity check. A valid initial table containing a fixture followed by malformed successful output empties survivors; invoking main with that sequence printed "clean: no surviving test processes" and returned 0. Validate every sample through one shared boundary and preserve an explicit unknown/broken outcome; test valid-to-malformed and valid-to-unavailable sequences.'
          family: process-observation-validity
          round: 6
        - id: BR-7
          severity: Important
          title: Watchdog query-directory cleanup always fails in the timer callback
          detail: tests/minimal_init.vim:54 calls vim.fn.delete from the fast-event callback in tests/helpers/exit_with_parent.lua:46. A headless Neovim reproduction returned E5560; pcall suppresses it before os.exit skips VimLeavePre. Use cleanup valid in that context and verify that an orphaned harness removes its query directory, not merely that its PID disappears.
          family: cleanup-execution-context
          round: 6
        - id: BR-8
          severity: Important
          title: README update is missing for the new manual census command
          detail: TOOLING.md:78 introduces an operator command with --root and --phase, but README.md is unchanged in the pinned range. The existing generic contributor link does not satisfy this review's explicit same-range README gate. Add a short cleanup-command pointer linking to the detailed TOOLING section.
          family: readme-surface-discovery
          round: 6
      boundary: M2
      recipe: milestone-review
      blocked: true
    - "n": 7
      timestamp: "2026-09-22T18:59:15-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: The plan still contains full implementation/spec snapshots; lines 2071–2074 explicitly retain them. The appended revision explains retention but does not resolve the duplication concern. Remains Minor.
          round: 7
        - id: BR-5
          disposition: not-addressed
          note: scripts/reap-test-orphans.py:84 fails to delimit -c/--cmd at the beginning of rest. Direct evaluation selects nvim -c echo " --headless -u /repo/tests/minimal_init.vim " and the equivalent --cmd form, although the apparent harness options are command text. Remains Critical in process-ownership-before-signalling; enumerate command-argument boundaries and test both leading and later positions.
          round: 7
        - id: BR-6
          disposition: addressed
          note: Initial and subsequent samples use validated_rows. The sequence regression passes; replacing validation with permissive parsing in memory makes both malformed-later-sample cases fail. Unavailable resampling also returns BROKEN without signalling.
          round: 7
        - id: BR-7
          disposition: addressed
          note: tests/minimal_init.vim uses synchronous libuv cleanup. The orphan regression passes, including directory removal and symlink-target preservation. Replacing cleanup with pcall(vim.fn.delete, ...) in a scratch copy makes that exact regression fail at fixture_reaping_spec.lua:69.
          round: 7
        - id: BR-8
          disposition: addressed
          note: README.md:105–106 adds the cleanup-command link in the pinned range. Its TOOLING.md#orphaned-test-processes target documents the actual --root/--phase invocation and ps caveat.
          round: 7
      boundary: M2
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#220 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-22T14:48:45-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
  The function names plus one strategy line per risky function carry the same
  design at a fraction of the staleness. Task 3's line-numbered uv.spawn table
  is the right instinct done wrong — it already says the arch guard, not the
  table, owns completeness, so the table can go.
  (carried from plan-quality PQ-5, deferred to the boundary review)

## Round 2 — 2026-09-22T14:48:45-07:00 (codex) — BLOCKED

### Raised

- **BR-2** [Critical] `pure-entity-test-seam` Core-concepts PURE entities are not tested without IO
  The plan labels parse_ps, select_orphans, ancestry, and orphaned as PURE (workshop/plans/000220-reap-test-fixture-processes-plan.md:67-129), but the tests invoke the Python script through vim.system and --ps-from (tests/unit/reap_test_orphans_spec.lua:7-10), while watchdog behavior is tested only through real orphaned processes (tests/integration/fixture_reaping_spec.lua:17-85). Add direct no-IO tests for the pure functions, or revise the Core-concepts table and classifications to INTEGRATION; record the correction in ## Revisions.

## Round 3 — 2026-09-22T14:54:20-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The durable plan remains approximately 1997 lines and still embeds complete spec bodies and census implementation text.
- BR-2 — addressed — tests/unit/reap_test_orphans_pure.py directly tests parse_ps, select_orphans, ancestry, and orphaned without process or filesystem IO; 5/5 tests pass.

### Raised

- **BR-3** [Important] `external-seam-consistency` Grace resampling ignores the configured ps command
  scripts/reap-test-orphans.py:115 calls read_process_table(None, "ps") instead of using the caller's --ps-command. A custom or injected process-table provider is used for the initial sample but silently replaced by the real ps during grace polling. Thread ps_command through persistent_candidates and add a regression test proving every sample uses the configured seam. ARCH-MOCK.

## Round 4 — 2026-09-22T14:59:10-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The durable plan remains approximately 2003 lines and still embeds complete implementation/spec bodies.
- BR-3 — addressed — scripts/reap-test-orphans.py now threads ps_command through persistent_candidates, with a regression test in tests/unit/reap_test_orphans_pure.py that fails if resampling uses literal ps.

### Raised

- **BR-4** [Important] `atlas-update-missing` Atlas update is missing for the new fixture lifecycle/reaping surface
  The diff adds exit_with_parent, fixture-process registry ownership, watchdog-based fixture cleanup, and the reap-test-orphans census, but only updates traceability.yaml; atlas/infra/test_harness.md is unchanged and has no corresponding lifecycle/reaping documentation. Add the architectural surface to atlas in this boundary. ARCH-PURPOSE.

## Round 5 — 2026-09-22T15:04:43-07:00 (codex) — passed

### Disposed

- BR-1 — not-addressed — The durable plan still embeds extensive implementation and test bodies; retain as a Minor follow-up.
- BR-4 — addressed — atlas/infra/test_harness.md now documents the watchdogs, fixture registry, detached-process handling, and orphan census.

## Round 6 — 2026-09-22T18:45:43-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The plan still contains complete implementation and test bodies, including Task 4's census script at workshop/plans/000220-reap-test-fixture-processes-plan.md:1108. Retain contracts, function names, and verification strategy; remove duplicated bodies and stale line-number inventories.
- BR-2 — not-addressed — The prior purity correction remains incomplete: the plan's Pure entities table lists orphaned at line 76, but tests/fixtures/fixture_watchdog.py:25 reads os.getppid(), and tests/unit/reap_test_orphans_pure.py patches that dependency in all three watchdog cases. Direct invocation did not make this entity PURE. Extract orphaned(parent, current_ppid) and test it without mocks, or revise its classification.

### Raised

- **BR-5** [Critical] `process-ownership-before-signalling` The census selects unrelated editors and pagers for SIGKILL
  scripts/reap-test-orphans.py:72 treats any argument containing the fixture-directory path as process ownership. Direct evaluation selects both "/usr/bin/nvim /repo/tests/fixtures/fake_cliproxy" and "/usr/bin/less /repo/tests/fixtures/ps_test_orphans.txt"; reap() then sends SIGKILL at line 131. Establish executable/script identity rather than matching arbitrary arguments, and add negative cases for editors, viewers, and commands merely mentioning fixture paths.
- **BR-6** [Critical] `process-observation-validity` Malformed grace-period samples turn known survivors into a clean result
  scripts/reap-test-orphans.py:119 parses subsequent samples without the initial sample's validity check. A valid initial table containing a fixture followed by malformed successful output empties survivors; invoking main with that sequence printed "clean: no surviving test processes" and returned 0. Validate every sample through one shared boundary and preserve an explicit unknown/broken outcome; test valid-to-malformed and valid-to-unavailable sequences.
- **BR-7** [Important] `cleanup-execution-context` Watchdog query-directory cleanup always fails in the timer callback
  tests/minimal_init.vim:54 calls vim.fn.delete from the fast-event callback in tests/helpers/exit_with_parent.lua:46. A headless Neovim reproduction returned E5560; pcall suppresses it before os.exit skips VimLeavePre. Use cleanup valid in that context and verify that an orphaned harness removes its query directory, not merely that its PID disappears.
- **BR-8** [Important] `readme-surface-discovery` README update is missing for the new manual census command
  TOOLING.md:78 introduces an operator command with --root and --phase, but README.md is unchanged in the pinned range. The existing generic contributor link does not satisfy this review's explicit same-range README gate. Add a short cleanup-command pointer linking to the detailed TOOLING section.

## Round 7 — 2026-09-22T18:59:15-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The plan still contains full implementation/spec snapshots; lines 2071–2074 explicitly retain them. The appended revision explains retention but does not resolve the duplication concern. Remains Minor.
- BR-5 — not-addressed — scripts/reap-test-orphans.py:84 fails to delimit -c/--cmd at the beginning of rest. Direct evaluation selects nvim -c echo " --headless -u /repo/tests/minimal_init.vim " and the equivalent --cmd form, although the apparent harness options are command text. Remains Critical in process-ownership-before-signalling; enumerate command-argument boundaries and test both leading and later positions.
- BR-6 — addressed — Initial and subsequent samples use validated_rows. The sequence regression passes; replacing validation with permissive parsing in memory makes both malformed-later-sample cases fail. Unavailable resampling also returns BROKEN without signalling.
- BR-7 — addressed — tests/minimal_init.vim uses synchronous libuv cleanup. The orphan regression passes, including directory removal and symlink-target preservation. Replacing cleanup with pcall(vim.fn.delete, ...) in a scratch copy makes that exact regression fail at fixture_reaping_spec.lua:69.
- BR-8 — addressed — README.md:105–106 adds the cleanup-command link in the pinned range. Its TOOLING.md#orphaned-test-processes target documents the actual --root/--phase invocation and ps caveat.

## Open findings

- **BR-1** [Minor] `plan-restates-the-diff` 1803 lines carrying complete spec bodies and the whole census script verbatim
- **BR-2** [Critical] `pure-entity-test-seam` Core-concepts PURE entities are not tested without IO
- **BR-5** [Critical] `process-ownership-before-signalling` The census selects unrelated editors and pagers for SIGKILL
