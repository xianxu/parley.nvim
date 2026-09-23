# Boundary Review — parley.nvim#220 (whole-issue close)

| field | value |
|-------|-------|
| issue | 220 — Lifecycle test fixtures leak: fake_cliproxy and headless nvim orphan to init |
| repo | parley.nvim |
| issue file | workshop/issues/000220-lifecycle-test-fixtures-leak-fake-cliproxy-and-headless-nvim-orphan-to-init.md |
| boundary | whole-issue close |
| milestone | — |
| window | 451190265e1a453044fdbd3b8efc5f7322107fb9..74d9e8986588e31bdec2b22bd98aa6017c9f52c8 |
| command | sdlc close --issue 220 |
| reviewer | codex |
| timestamp | 2026-09-22T19:09:42-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The implementation delivers the planned lifecycle layers and census integration. BR-2 is addressed with direct pure-function tests and a documented revision. No blocking findings remain. BR-1 remains advisory. Independent targeted tests passed; live `ps` conformance was unavailable in this sandbox, and I did not repeat the full-suite or interrupted-suite proofs.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The plan still embeds complete implementations and test bodies; its revision at line 2071 explicitly retains them. This remains a non-blocking documentation recommendation.
  - id: BR-2
    disposition: addressed
    note: |
      tests/unit/reap_test_orphans_pure.py directly tests all four PURE entities without IO in those test cases. Both watchdog loops consume the extracted predicates. The plan records the correction under Revisions at line 1992. Restoring the old Python change-only predicate in memory makes the init-parent regression fail.
  - id: BR-3
    disposition: addressed
    note: |
      Grace resampling forwards ps_command to read_process_table; the configured-command regression passes.
  - id: BR-4
    disposition: addressed
    note: |
      atlas/infra/test_harness.md adds the process-lifecycle map, covering watchdogs, registry ownership, census behavior, and the real-binary exception.
  - id: BR-5
    disposition: addressed
    note: |
      Selection requires executable/script position or recognized Neovim harness launch forms. The negative command-boundary corpus and positive fixture/harness cases pass.
  - id: BR-6
    disposition: addressed
    note: |
      Resampling validates every observation and returns BROKEN before signaling on invalid samples. Injected malformed and unavailable observation tests pass.
  - id: BR-7
    disposition: addressed
    note: |
      Query cleanup uses synchronous libuv operations. The real orphan integration test passes for populated-directory removal and preservation of the external symlink target.
  - id: BR-8
    disposition: addressed
    note: |
      README.md links to TOOLING.md's orphaned-process section, which supplies the physical-root ps listing and census command.
```

1. **Strengths**
   - Shared spawn ownership replaces the spec-local registries; sequence marks preserve file-scope fixtures during per-case cleanup.
   - Watchdogs cover HTTP fixtures, blocking non-HTTP modes, and harness Neovims—including orphaning during startup.
   - Invalid resampling fails visibly without signaling from stale observations.
   - README, TOOLING, atlas, and traceability updates describe the introduced surface.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings**
   - **BR-1 / ARCH-DRY:** [The plan](/Users/xianxu/workspace/parley.nvim/workshop/plans/000220-reap-test-fixture-processes-plan.md:271) still duplicates substantial executable source. Retain the existing advisory recommendation to summarize strategies and reference source locations.

5. **Test coverage**
   - Python: **13 passed**.
   - Lua census: **10 passed**.
   - Lifecycle architecture guard: **4 passed**.
   - Lifecycle integration: **11 behavioral cases passed**; real-`ps` conformance explicitly pending because the sandbox refused it.
   - Counterfactual: the old change-only watchdog predicate fails the init-parent regression.
   - Pinned-range `git diff --check`: passed.

6. **Architectural assessment**
   - **ARCH-DRY — flag, Minor:** BR-1; executable lifecycle ownership is consolidated appropriately.
   - **ARCH-PURE — pass:** predicates accept observations as data and have direct tests.
   - **ARCH-PURPOSE — pass:** teardown, parent-death cleanup, census failure, and prevention guards are delivered.
   - **ARCH-MOCK — pass:** recorded process tables and injected observation sequences exercise the census seam; live conformance exists but was pending here.
   - **ARCH-CONSTRAINTS — pass:** bounded grace and polling intervals; same-checkout concurrency limitations are documented.
   - **ARCH-SECURE — pass:** ownership selection excludes arbitrary argument mentions; cleanup preserves symlink targets.
   - **ARCH-ORDER — pass:** startup orphaning, spontaneous exit, marked cleanup, and invalid later observations are exercised.
   - **ARCH-FUNERAL — pass:** fixture processes and query directories have explicit cleanup paths; the real-binary limitation is documented.

7. **Plan revision recommendations**
   - No additional mandatory revision. BR-2’s correction is recorded. Any later BR-1 consolidation should include a revision explaining the replacement of embedded source snapshots with implementation references.
