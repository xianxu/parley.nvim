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
