# Boundary Review — parley.nvim#416 (whole-issue close)

| field | value |
|-------|-------|
| issue | 416 — Test census reports clean while an orphaned embedded Neovim survives |
| repo | parley.nvim |
| issue file | workshop/issues/000416-false-clean-census.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1752271061691fd0780994a45b93d46463c8c747..3cffa5e844a392b8e0299d823262e6e09c913fdb |
| command | sdlc close --issue 416 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T17:08:00-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The main false-clean regression is addressed: retained ownership evidence reaches both runner cleanup and the independent terminal census, and the native regressions pass on both supported runtimes. Two reproduced defects remain: publication corrupts some unknown JSON values, and concurrent scope allocation can exceed the limit that the census accepts.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: persisted-unknown-value-preservation
    title: |
      Birth publication silently changes unknown JSON numbers
    detail: |
      tests/helpers/test_processes.lua:111 re-encodes unknown fields through Lua numbers, violating ARCH-EVOLVE and the plan's preservation contract. Calling prepare(), writing a pending record containing future.number=9007199254740993, then complete() produces future.number=9007199254740992. Preserve unknown numeric tokens losslessly, including nested values, and add a regression whose oracle does not use the same lossy decoder.
  - id: new
    severity: Important
    kind: defect
    family: atomic-capacity-admission
    title: |
      Concurrent scope allocation exceeds the census's accepted capacity
    detail: |
      tests/helpers/test_processes.lua:242 checks the scope count separately from fs_mkdtemp(). With 63 existing scopes and two callers synchronized after enumeration, both allocations succeed, producing 65 scopes against the default limit of 64. The terminal verifier then exits 2 with "registry entry limit reached" before reconciling records. Make capacity reservation atomic across parallel runners and add a controlled concurrent-admission regression (ARCH-CONSTRAINTS, ARCH-ORDER).
```

**1. Strengths**

- Pending tickets precede child creation; interrupted publication remains visible as unknown.
- Runner and terminal census share native identity observation and reconciliation.
- The native orphan regression verifies TERM resistance, observed death, snapshot noninterference, and protection of a same-argv foreign child.
- Atlas, traceability, and tooling documentation cover the retained registry and legacy-path migration.

**2. Critical findings**

- [test_processes.lua:111](/Volumes/TestScratch/review-checkouts/1b0508c8bbc76e8d/tests/helpers/test_processes.lua:111): unknown numeric values lose precision during publication. Preserve their original representation through the rewrite and test large integers and precise decimals in nested structures.

**3. Important findings**

- [test_processes.lua:242](/Volumes/TestScratch/review-checkouts/1b0508c8bbc76e8d/tests/helpers/test_processes.lua:242): scope admission needs an atomic reservation. The checkout lease serializes runs, but parallel spec runners share one run context.

**4. Minor findings**

None.

**5. Test coverage notes**

- Passed: 15 Python census tests and 26 lease tests.
- Passed on Neovim **0.12.5 and 0.11.7**: six native census cases, seven policy cases, eighteen registry cases, and five embedded-helper cases.
- Both new findings have deterministic reviewer reproductions; existing tests miss them.
- The broader harness completed with eight scratch-placement failures caused by the review environment placing TMPDIR inside the checkout. Its remaining cases passed, and terminal census reported verified/clean. This is not a full harness pass.
- Pinned diff checks passed. No source changes remain.

**6. Architectural notes**

| Marker | Result | Evidence |
|---|---|---|
| ARCH-DRY | Pass | Shared identity reader and reconciliation module serve both consumers. |
| ARCH-PURE | Pass | Observation classification is data-only and tested directly. |
| ARCH-PURPOSE | Pass | Independent census catches recorded children after caller death. |
| ARCH-MOCK | Pass | Stateful observation/effect fake plus native conformance exercises lifecycle behavior. |
| ARCH-CONSTRAINTS | **Flag** | Concurrent admission can exceed the declared scope bound. |
| ARCH-SECURE | Pass | Changed cleanup requires private evidence and matching native identity. |
| ARCH-ORDER | **Flag** | Scope count and allocation lack an atomic transition across runners. |
| ARCH-FUNERAL | Pass | Records retire after observed death; drained directories have cleanup paths. |
| ARCH-EVOLVE | **Flag** | Unknown numeric members change during publication. |

The Core concepts entities exist at the documented paths and classifications match their roles. Atlas changes satisfy the architectural documentation gate; this range adds no new user-facing command or configuration requiring a README update.

**7. Plan revision recommendations**

Add two `## Revisions` entries:

- Specify lossless preservation of unknown JSON numeric tokens and an independent regression oracle.
- Specify atomic scope-capacity reservation across parallel runners, including a controlled two-caller test at the admission limit.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e1c7fb82-1315-418e-8fae-37974686dfad","repository":"github.com/xianxu/parley.nvim","issue_id":"000416","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/1b0508c8bbc76e8d","reviewed_head":"3cffa5e844a392b8e0299d823262e6e09c913fdb","slot":"parley.nvim:3","requested_at":"2026-10-23T00:03:45.256108Z"},"phase":"finished","pid":23091,"started_at":"2026-10-23T00:03:45.41282Z","finished_at":"2026-10-23T00:07:59.865664Z","session_id":"01a16612-1e7a-7f61-a615-d30fec32f83c","outcome":"returned"}] -->
