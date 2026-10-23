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

---

## Re-review — 2026-10-22T17:16:09-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 416 — Test census reports clean while an orphaned embedded Neovim survives |
| repo | parley.nvim |
| issue file | workshop/issues/000416-false-clean-census.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1752271061691fd0780994a45b93d46463c8c747..fee0af023b597fded78c36facb08c559085aaf5b |
| command | sdlc close --issue 416 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T17:16:09-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior findings are addressed, with regressions independently confirmed to fail against the preceding implementation. The retained census detects and joins owned survivors on both supported runtimes. One new concurrency defect blocks admission: normal scope retirement can cause an unrelated healthy spec to fail before launch.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Publication preserves validated raw unknown-member slices. The numeric-text regression passes at head and fails with the preceding module, exposing 9007199254740993 becoming 9007199254740992.
  - id: BR-2
    disposition: addressed
    note: |
      Atomic mkdir reserves canonical bounded slots. The controlled two-allocator regression passes at head and fails with the preceding module because both callers are admitted.
findings:
  - id: new
    severity: Important
    kind: defect
    family: atomic-capacity-admission
    title: |
      Concurrent scope retirement incorrectly rejects healthy admission
    detail: |
      tests/helpers/test_processes.lua:273-277 treats every failed lstat of an enumerated scope as invalid evidence. Reproduced on both runtimes: pause allocation after fs_scandir, prune an existing empty spec-1, then resume; scope() returns nil with "unknown or legacy registry scope" despite available capacity. spec_runner.lua:66 consequently returns code 125 before launching the spec; parallel suite workers routinely allocate while siblings retire. This is the 2nd finding in family atomic-capacity-admission. State and enforce the admission rule across allocation/allocation, allocation/retirement and retirement/reuse interleavings: explicit ENOENT from concurrent retirement must permit continued atomic reservation, while unreadable or invalid existing evidence must still refuse. Add controlled regressions covering that enumeration.
```

1. **Strengths**

   - Runner and terminal census share reconciliation and native identity logic.
   - Pending tickets preserve uncertainty across launcher death.
   - Native tests verify TERM resistance, joined death, foreign-process protection, and independent terminal detection.
   - Unknown JSON preservation now uses raw bytes and an independent regression oracle.

2. **Critical findings**

   None.

3. **Important findings**

   The admission/retirement race above, at `tests/helpers/test_processes.lua:273`. Distinguish explicit disappearance from inspection failure, then let atomic `mkdir` determine reservation success.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Neovim 0.12.5 harness mapping: **209 tests across 29 files passed**.
   - Neovim 0.11.7 focused mapping: **36 tests passed**.
   - Python census: **15 passed**; lease controls: **26 passed**.
   - Both runtime mappings ended with verified clean census results.
   - Both prior regressions failed against the preceding module.
   - The newly reported retirement interleaving reproduced on both runtimes.
   - No recorded full-suite acceptance result was established by this review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared identity reader and reconciliation module.
   - **ARCH-PURE — pass:** data-only classification tested directly; IO remains in integration modules.
   - **ARCH-PURPOSE — pass:** independent census covers survival after caller death.
   - **ARCH-MOCK — pass:** stateful observation/effect sequences complemented by native conformance.
   - **ARCH-CONSTRAINTS — flag:** bounded capacity is enforced, but healthy admission fails during retirement.
   - **ARCH-SECURE — pass:** inspected refusal paths retain uncertain evidence and protect replacement identities.
   - **ARCH-ORDER — flag:** controlled coverage omits allocation racing with retirement.
   - **ARCH-FUNERAL — pass:** observed death retires records; empty scopes and old runs have cleanup paths.
   - **ARCH-EVOLVE — pass:** unknown member bytes survive publication; malformed and duplicate data are rejected.

   Core-concept entities exist at their documented paths and classifications match their implementation. Atlas and tooling cover the new internal surface; no new public command, flag, keybinding, or configuration requires a README addition.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining concurrent admission and retirement semantics, including explicit `ENOENT`, reservation contention, scope reuse, and unreadable existing entries. Require deterministic tests for those interleavings before closing the issue.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b0ae51fe-05cf-4bd9-b6d6-c97d4f499528","repository":"github.com/xianxu/parley.nvim","issue_id":"000416","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/a5a3b318e5c94607","reviewed_head":"fee0af023b597fded78c36facb08c559085aaf5b","slot":"parley.nvim:3","requested_at":"2026-10-23T00:12:30.056533Z"},"phase":"finished","pid":59533,"started_at":"2026-10-23T00:12:30.216475Z","finished_at":"2026-10-23T00:16:08.418423Z","session_id":"01a1661a-2022-7700-b88e-50d198b40adb","outcome":"returned"}] -->
