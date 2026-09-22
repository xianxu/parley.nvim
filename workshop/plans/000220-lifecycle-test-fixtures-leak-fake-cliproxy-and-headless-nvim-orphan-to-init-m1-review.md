# Boundary Review — parley.nvim#220 (milestone M1)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..89f59ff1f17bcc5ccae04f9af6aaae4e81bb2c75 |
| command | sdlc milestone-close --issue 220 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-22T14:48:45-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation largely delivers M1: watchdogs, registry cleanup, census logic, and direct tests work. Boundary crossing is blocked by a Core-concepts/testing contradiction: entities documented as PURE are only tested through subprocesses, filesystem inputs, or real processes.

```findings
findings:
  - id: new
    severity: Critical
    family: pure-entity-test-seam
    title: |
      Core-concepts PURE entities are not tested without IO
    detail: |
      The plan labels parse_ps, select_orphans, ancestry, and orphaned as PURE (workshop/plans/000220-reap-test-fixture-processes-plan.md:67-129), but the tests invoke the Python script through vim.system and --ps-from (tests/unit/reap_test_orphans_spec.lua:7-10), while watchdog behavior is tested only through real orphaned processes (tests/integration/fixture_reaping_spec.lua:17-85). Add direct no-IO tests for the pure functions, or revise the Core-concepts table and classifications to INTEGRATION; record the correction in ## Revisions.
```

Strengths: the shared registry centralizes spawn/reap ownership; watchdog coverage includes the boot-time `ppid == 1` race; the census excludes the invoking ancestry and operator editors; direct tests pass.

Critical findings: listed above.

Important findings: none.

Minor findings: none.

Test coverage notes: direct census unit test passed 8/8; lifecycle integration passed 11 tests with one expected sandbox-pending `ps` case. Python compilation passed.

Architectural notes:

- ARCH-DRY: pass — lifecycle logic is centralized.
- ARCH-PURE: flag — pure entities lack no-IO unit tests.
- ARCH-PURPOSE: pass — M1’s stated reaping and measurement scope is delivered.
- ARCH-MOCK: pass — recorded process-table input and live conformance seam exist.
- ARCH-CONSTRAINTS: pass — census grace is bounded.
- ARCH-SECURE: pass — no secrets or real user state are introduced.
- ARCH-ORDER: pass — registry marks and teardown behavior are exercised.
- ARCH-FUNERAL: pass — spawned handles and orphaned processes have cleanup paths.

Plan revision recommendations:

- Add a `## Revisions` entry documenting whether the four entities remain PURE with direct tests, or are reclassified as INTEGRATION because their current tests require IO.

---

## Re-review — 2026-09-22T14:54:20-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..33e2d297f9b85b5e214e3fc76adb6c2897888736 |
| command | sdlc milestone-close --issue 220 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-22T14:54:20-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 substantially delivers the reaping layers and passes the targeted and full integration coverage observed. One Important seam bug remains: grace-period resampling ignores the configured `--ps-command`. BR-1 remains unresolved but is Minor.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The durable plan remains approximately 1997 lines and still embeds complete spec bodies and census implementation text.
  - id: BR-2
    disposition: addressed
    note: |
      tests/unit/reap_test_orphans_pure.py directly tests parse_ps, select_orphans, ancestry, and orphaned without process or filesystem IO; 5/5 tests pass.
findings:
  - id: new
    severity: Important
    family: external-seam-consistency
    title: |
      Grace resampling ignores the configured ps command
    detail: |
      scripts/reap-test-orphans.py:115 calls read_process_table(None, "ps") instead of using the caller's --ps-command. A custom or injected process-table provider is used for the initial sample but silently replaced by the real ps during grace polling. Thread ps_command through persistent_candidates and add a regression test proving every sample uses the configured seam. ARCH-MOCK.
```

1. Strengths: centralized `fixture_process` registry; boot-time orphan detection in both watchdogs; direct PURE tests now exist and pass; migrated cliproxy integration tests pass; real-process lifecycle tests pass.

2. Critical findings: none.

3. Important findings: the `--ps-command` seam is not preserved during grace resampling, as detailed above.

4. Minor findings: BR-1 plan restatement remains unresolved.

5. Test coverage notes: pure Python tests passed 5/5; fixture lifecycle tests passed 11 tests with the expected sandbox-pending `ps` check; the integration suite passed all reached files. No test covers repeated grace sampling with a custom `--ps-command`.

6. Architectural notes:

- ARCH-DRY: pass — registry and watchdog ownership are centralized.
- ARCH-PURE: pass — census predicates have direct no-IO tests.
- ARCH-PURPOSE: pass for M1’s reaping layers and census.
- ARCH-MOCK: flag — configured process-table seam is bypassed during resampling.
- ARCH-CONSTRAINTS: pass — polling and grace periods are bounded.
- ARCH-SECURE: pass — selection is narrowed by checkout path and process shape; recorded tables signal nothing.
- ARCH-ORDER: pass — startup orphaning, teardown, and marked registry lifetimes are covered.
- ARCH-FUNERAL: pass — spawned processes have normal-exit, parent-death, and census cleanup paths.

7. Plan revision recommendations:

- Add a `## Revisions` entry documenting the `--ps-command` propagation fix and its regression test.
- BR-1 still recommends reducing duplicated implementation/spec bodies in the durable plan.

---

## Re-review — 2026-09-22T14:59:10-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..dea6cb100c0e18ce428dcfe6193976ee40f4665c |
| command | sdlc milestone-close --issue 220 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-22T14:59:10-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1’s lifecycle layers and census are implemented and targeted tests pass. Boundary crossing is blocked by a missing architectural atlas update; the durable-plan restatement finding also remains unresolved.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The durable plan remains approximately 2003 lines and still embeds complete implementation/spec bodies.
  - id: BR-3
    disposition: addressed
    note: |
      scripts/reap-test-orphans.py now threads ps_command through persistent_candidates, with a regression test in tests/unit/reap_test_orphans_pure.py that fails if resampling uses literal ps.
findings:
  - id: new
    severity: Important
    family: atlas-update-missing
    title: |
      Atlas update is missing for the new fixture lifecycle/reaping surface
    detail: |
      The diff adds exit_with_parent, fixture-process registry ownership, watchdog-based fixture cleanup, and the reap-test-orphans census, but only updates traceability.yaml; atlas/infra/test_harness.md is unchanged and has no corresponding lifecycle/reaping documentation. Add the architectural surface to atlas in this boundary. ARCH-PURPOSE.
```

1. Strengths

- `fixture_process` centralizes registration, marking, pruning, and teardown.
- Both watchdogs cover the boot-time `ppid == 1` race.
- Pure census predicates now have direct no-IO Python tests.
- Targeted tests passed: census 8/8, lifecycle 11 reached tests, pure Python tests 6/6.

2. Critical findings

None.

3. Important findings

- Missing atlas documentation for the new fixture lifecycle/reaping architecture, as listed above.

4. Minor findings

- BR-1 remains open: the durable plan duplicates extensive implementation and test bodies.

5. Test coverage notes

`git diff --check`, Python compilation, pure tests, census tests, and lifecycle tests passed. The real-`ps` conformance case was correctly pending in the sandbox. `make test-unit JOBS=1` was interrupted after partial progress without producing a final result.

6. Architectural notes

- ARCH-DRY: Pass — ownership is consolidated in `fixture_process` and `LoopbackHTTPServer`.
- ARCH-PURE: Pass — pure census/watchdog predicates have direct tests.
- ARCH-PURPOSE: Flag — atlas coverage does not yet document the new lifecycle surface.
- ARCH-MOCK: Pass — the process-table seam is injectable and the `ps_command` fix is covered.
- ARCH-CONSTRAINTS: Pass — census grace polling is bounded.
- ARCH-SECURE: Pass — recorded tables do not signal processes; selection is narrowed by checkout and process shape.
- ARCH-ORDER: Pass — registry marks and teardown ordering are exercised.
- ARCH-FUNERAL: Pass — normal exit, parent death, and census cleanup paths exist.

7. Plan revision recommendations

- Add a `## Revisions` entry documenting the `ps_command` propagation fix and regression test.
- Add a `## Revisions` entry documenting the unresolved plan-restatement issue or reduce the duplicated plan bodies.
- Add an atlas documentation step to the M1 plan, or explicitly revise the boundary contract if documentation is intentionally deferred to M2.

---

## Re-review — 2026-09-22T15:04:43-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..ee97c9af13fdafa4e99d51395a8951c937c59c7c |
| command | sdlc milestone-close --issue 220 --milestone M1 |
| reviewer | codex |
| timestamp | 2026-09-22T15:04:43-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

M1 delivers the lifecycle watchdogs, centralized fixture registry, orphan census, and atlas documentation. Targeted and full unit verification passed; no Critical or Important findings remain.

1. Strengths

- `fixture_process` centralizes spawn/reap ownership.
- Watchdogs cover both changed-parent and boot-time `ppid == 1` cases.
- Pure census/watchdog functions have direct no-IO tests.
- Atlas documents the new lifecycle/reaping architecture.

2. Critical findings

None.

3. Important findings

None.

4. Minor findings

- BR-1 remains unresolved: the durable plan still embeds extensive implementation and test bodies.

5. Test coverage notes

- Pure Python tests: 6/6 passed.
- Census spec: 8/8 passed.
- Fixture lifecycle spec: 11 passed, with the real-`ps` case correctly pending in the sandbox.
- Full unit suite: passed.
- Python compilation and `git diff --check`: passed.

6. Architectural notes

- ARCH-DRY: pass — shared registry and constructor chokepoints.
- ARCH-PURE: pass — pure census predicates are directly tested.
- ARCH-PURPOSE: pass — M1’s reaping and measurement scope is delivered.
- ARCH-MOCK: pass — `ps` has a recorded-table seam and live conformance case.
- ARCH-CONSTRAINTS: pass — watchdog polling and census grace are bounded.
- ARCH-SECURE: pass — census selection is narrowed and recorded tables cannot signal.
- ARCH-ORDER: pass — startup orphaning and teardown ordering are covered.
- ARCH-FUNERAL: pass — created processes and handles have cleanup paths.

7. Plan revision recommendations

- Reduce or remove the duplicated implementation/spec bodies noted by BR-1.
- Update the M2 documentation checklist to reflect that the atlas lifecycle documentation already landed in M1.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The durable plan still embeds extensive implementation and test bodies; retain as a Minor follow-up.
  - id: BR-4
    disposition: addressed
    note: |
      atlas/infra/test_harness.md now documents the watchdogs, fixture registry, detached-process handling, and orphan census.
```
