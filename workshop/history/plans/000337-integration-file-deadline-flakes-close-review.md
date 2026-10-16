# Boundary Review — parley.nvim#337 (whole-issue close)

| field | value |
|-------|-------|
| issue | 337 — Flake: integration files exceed a load-dependent whole-file deadline |
| repo | parley.nvim |
| issue file | workshop/issues/000337-integration-file-deadline-flakes.md |
| boundary | whole-issue close |
| milestone | — |
| window | 2e143c9da23ff52b5926e241dc59f2c61d5662f5..775cb6f922c13217daee958b9151817157832f6a |
| command | sdlc close --issue 337 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T16:24:22-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The deadline policy addresses the whole-file timeout model while preserving existing assertions and corpus budgets. All 22 focused tests pass under current load, and the recorded full-suite evidence checks out. However, three new tests fail at the supported 4× load cap, introducing another load-dependent suite failure.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: control-environment-dependent-test-inputs
    title: |
      Native timeout tests fail at the supported load cap
    detail: |
      tests/integration/spec_runner_native_spec.lua:62, :90 and :106 all require "stalled", but Runner.execute samples real machine load (tests/helpers/spec_runner.lua:35). At factor 4, the idle budget equals the absolute ceiling, whose documented precedence correctly produces "absolute-expired". Running this spec with vim.uv.loadavg returning 100000 reproduced all three failures (3 passed, 3 failed; exit 1). These are every instance of this assumption in the window. Inject controlled load/CPU inputs for reason-specific conformance tests and exercise both ordinary and capped load, preserving the policy's absolute-ceiling precedence. This undermines the load-flake purpose checked by ARCH-PURPOSE.
```

1. **Strengths**
   - Pure policy tests cover exact expiry boundaries, late progress, sequence validation, terminal states and load scaling.
   - The child wrapper delegates assertions and fixture execution to actual Plenary.
   - Native tests verify assertion failure propagation and PID disappearance after timeout.
   - Atlas documentation and traceability cover the new harness components.

2. **Critical findings:** None.

3. **Important findings:** The environment-dependent assertions enumerated above. Fix by controlling load inputs and covering the capped outcome.

4. **Minor findings:** None.

5. **Test coverage notes:** Independently ran 22 focused cases successfully. Controlled capped-load execution reproduced three failures. Verified the recorded suite log’s SHA-256, affected-file passes and clean process report; the tested commit differs from pinned head only in issue documentation.

6. **Architectural notes**
   - **ARCH-DRY: Pass.** Shared policy; Plenary remains the assertion executor.
   - **ARCH-PURE: Pass.** Deadline decisions are isolated from process and clock IO.
   - **ARCH-PURPOSE: Flag.** Production policy addresses the intended timeout mismatch, but new conformance tests fail under supported contention.

7. **Plan revision recommendation:** Add a `## Revisions` entry recording controlled ordinary/capped-load conformance and the sweep of all three reason-specific assertions.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d5cd5bca-5efd-429b-9fed-f28c7351ad9a","repository":"github.com/xianxu/parley.nvim","issue_id":"000337","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/2aa9432f73e67dd3","reviewed_head":"775cb6f922c13217daee958b9151817157832f6a","slot":"parley.nvim:2","requested_at":"2026-10-15T23:23:01.811314Z"},"phase":"finished","pid":76285,"started_at":"2026-10-15T23:23:01.916292Z","finished_at":"2026-10-15T23:24:22.562828Z","session_id":"01a141e0-50a5-7c73-961f-50dcaf436396","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T16:59:23-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 337 — Flake: integration files exceed a load-dependent whole-file deadline |
| repo | parley.nvim |
| issue file | workshop/issues/000337-integration-file-deadline-flakes.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8023e3acb99e88c79d2c51aef576ab5d42f73015..013b81fccc9f2153a1202fff33c01460106e1f15 |
| command | sdlc close --issue 337 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T16:59:23-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The implementation fulfills the documented deadline policy while preserving Plenary assertions and existing corpus budgets. BR-1 is addressed with meaningful regression evidence. No new blocking findings remain.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      All three stalled-reason tests now receive controlled ordinary load/CPU inputs, and the new capped-load case exercises absolute precedence. All seven native tests pass with machine load forced to 100000. Removing the runner's injected-input handling in memory makes the capped-load regression fail at spec_runner_native_spec.lua:103 (6 passed, 1 failed; exit 1).
```

1. **Strengths**
   - Deadline decisions are isolated in a deterministic policy with exact-boundary, invalid-event and terminal-state tests.
   - `tests/helpers/spec_child.lua:8` delegates full case execution, including fixtures, to Plenary before reporting progress.
   - Native tests verify assertion propagation, arbitrary-output rejection, timeout reasons and PID disappearance.
   - Atlas documentation and traceability cover the new harness components.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes:** Independently passed 23 focused tests, including seven native tests under forced capped machine load. The input-handling mutation produced the expected regression failure. Verified the recorded full-suite log’s SHA-256: 436 files passed, lint reported zero warnings/errors across 738 files, and process checks reported no survivors. That tested commit differs from pinned head only in issue documentation. `git diff --check` passed.

6. **Architectural notes**
   - **ARCH-DRY: Pass.** Shared deadline policy; Plenary remains the assertion and fixture executor.
   - **ARCH-PURE: Pass.** Policy logic is separated from clock, process and output IO.
   - **ARCH-PURPOSE: Pass.** Progress permits bounded useful work beyond the former whole-file minimum, while stalls and absolute expiry remain enforced. BR-1’s full three-instance family is covered.
   - Atlas updates satisfy the new architectural surface. No new user-facing command, flag or configuration requires a README update.

7. **Plan revision recommendations:** None. The existing revisions accurately record the controlled-load correction and its regression coverage.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"30618885-c6d8-49d5-8055-a0d8b0a0c571","repository":"github.com/xianxu/parley.nvim","issue_id":"000337","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e413f1475bc33c40","reviewed_head":"013b81fccc9f2153a1202fff33c01460106e1f15","slot":"parley.nvim:2","requested_at":"2026-10-15T23:58:33.394372Z"},"phase":"finished","pid":85247,"started_at":"2026-10-15T23:58:33.490249Z","finished_at":"2026-10-15T23:59:22.708604Z","session_id":"01a14200-d6f3-7c20-8391-512b0cc709cf","outcome":"returned"}] -->
