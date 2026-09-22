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
