---
id: 000395
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: '4d8ad09cb55b1e56e78cbeab2989b927dfd26faf' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T19:32:05-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "e0848ff7"}
---

# jit_tuning_spec foreign JIT trace count is 0 under suite load (flake)

## Problem

`tests/unit/jit_tuning_spec.lua` "module-scoped compiler protection in a real VM keeps unrelated JIT traces active while protecting the entire document pipeline" failed at line 126 (`assert.is_true(result.foreign > 0)`) in the full suite on parley.nvim#391's head 0c9ab358, a diff that touches no JIT or document-pipeline code. The child VM's foreign trace never reached `stop`: an abort or flush under suite load clears `foreign_trace`, so the count stays 0. The same file passed three isolated runs (`make test-spec SPEC=infra/test_harness`) on the same head, and the previous full suite on c3c50006 passed.

Evidence: suite log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8f1ede4b55ff8fded222bbfdcb96c6e5.log (sha256 ee66cec1ac34), recorded as sdlc-local/suite on 0c9ab358.

## Spec

## Done when

- The test proves foreign traces stay enabled without depending on a single trace completing under load (for example, a loop that retries until a foreign trace stops, bounded), and it passes under a loaded full suite.

## Plan

Reproduced (2026-10-19) by running the case's child script 120 times in parallel, with each abort's reason recorded:
- The preferred runtime (LuaJIT with the arm64 mcode fix): 240 of 240 runs reach `foreign=2`, with no aborts.
- The installed nvim 0.11.7 (no fix): 6 of 120, then 11 of 120, end `foreign=0`. In each, the foreign loop starts about 271 traces, and every one aborts with `failed to allocate mcode memory`, then flushes. Both recorded failures (8f1ede4b, f72dafcf) were in the suite's compat pass on 0.11.7.

So the compiler stays on for the unrelated code, which keeps starting traces, but that LuaJIT can't place machine code. This is the #294 defect, not the policy. The test's other gap: one `foreign_trace` slot, which any start from another source, any abort, or any flush resets.

- [x] Track every foreign trace id (a set), and record each foreign abort's reason through `jit.vmdef.traceerr`.
- [x] Assert, at no loss of strength:
  - `own == 0` starts: the document pipeline never compiles (unchanged).
  - `foreign_starts > 0`: the compiler is on for unrelated code. This is the same measure `own` uses; a global `jit.off()` would make it 0.
  - `foreign_stops > 0`, unless every foreign abort was `failed to allocate mcode memory` (the #294 LuaJIT defect, matched by its `traceerr` text). Then the test records it and still requires the starts.
  - A failure message carries the counts and up to five abort reasons.
- [x] Tests:
  - Re-run the 120-way stress on both runtimes, using the spec's child script, and log the outcome.
  - Red checks: a global `jit.off()` in the child fails the starts assertion; a policy that compiles the document pipeline fails `own == 0`.

## Log

### 2026-10-19
- 2026-10-19: closed — Test-only, no new surface (--no-atlas). Root cause measured: with the case child script run 120 ways in parallel, the preferred runtime gives 240/240 foreign=2, and installed 0.11.7 gives 6/120 and 11/120 foreign=0, every foreign abort "failed to allocate mcode memory" (the #294 arm64 defect); both recorded failures were in the 0.11.7 compat pass. The case now tracks foreign trace ids as a set, records abort reasons, and asserts own==0 starts, foreign starts>0, and foreign stops>0 unless every abort is the mcode error, with a message that cites #294. Stress under the new rule: 120/120 on preferred; 112+8 (exemption) of 120 on 0.11.7. Red checks: jit.off(foreign,true) fails the starts assertion; removing the forced interpreter requirement fails the case. infra/test_harness green on both runtimes.; review verdict: SHIP
- Implemented:
  - Foreign trace ids are kept in a set, so another source's start, an abort or a flush no longer hides a later stop.
  - Abort reasons come from `jit.vmdef.traceerr`.
  - Assertions: `own == 0` starts; `foreign > 0` starts; `foreign_stops > 0` unless every foreign abort is #294's mcode-allocation error, with a message that cites #294 and carries the counts and up to five reasons.
- Stress with the spec's child script, 120 parallel runs per runtime, under the new rule:
  - Preferred runtime: 120 of 120 pass.
  - nvim 0.11.7: 112 pass outright and 8 pass through the mcode exemption (foreign starts > 0, every abort the mcode error).
- Red checks:
  - `jit.off(foreign, true)` (the compiler off for only the unrelated chunk, global status still on) fails the starts assertion.
  - Removing the forced `requires_interpreter` lets the pipeline compile, and the case fails.
- `make test-spec SPEC=infra/test_harness` is green on both runtimes.

