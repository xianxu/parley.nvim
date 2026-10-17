# Boundary Review — parley.nvim#363 (whole-issue close)

| field | value |
|-------|-------|
| issue | 363 — Cliproxy credential-restart lifecycle cases intermittently time out and probe the killed port |
| repo | parley.nvim |
| issue file | workshop/issues/000363-cliproxy-lifecycle-restart-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0104d021f848ad05be4fc49e034d3cec7ade0866..2d1479cccec4cfd37e62736564ab3a3654b77dc5 |
| command | sdlc close --issue 363 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T17:27:33-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The fixture repair matches the revised contract: synthetic stalls require confirmed process exit, legitimate fallback probes remain real, and delayed callbacks cannot resume after teardown. Production code, existing assertions, and deadlines are unchanged. No blocking findings.

Done-when: current — its regression, completion, teardown, and suite requirements cover the revised fixture repair.

```findings
{}
```

1. **Strengths**
   - The stall wrapper checks both signalled PIDs and actual exit before intercepting probes (`tests/integration/cliproxy_lifecycle_spec.lua:939–955`).
   - Teardown cancels timers and guards callbacks already queued (`tests/integration/cliproxy_lifecycle_spec.lua:958–975`).
   - New regressions cover unidentified listeners, still-live listeners, and closed-port callback retirement.
   - Atlas documentation accurately describes the fixture’s revised behavior (`atlas/providers/cliproxy-managed.md:125`).

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Independently ran the lifecycle file: **66 passed**, zero failures/errors, clean process census.
   - In a disposable pinned-head checkout, removed the stall restrictions and callback guard: **all three new regressions failed**, while the remaining 63 passed. Checkout removed afterward.
   - Changed Lua lint and diff whitespace checks passed.
   - Verified the retained full-suite log and matching SHA-256: **453 passing files**, zero failed files, clean lint and process census. Reviewed code matches that suite’s tested commit.

6. **Architecture**
   - **ARCH-DRY: pass.** Reuses existing process, readiness, and await helpers; one teardown helper owns timer retirement.
   - **ARCH-PURE: pass.** Changes remain within the integration fixture’s IO boundary; no business logic moved into production handlers.
   - **ARCH-PURPOSE: pass.** Covers all three listener states and callback isolation while retaining both original restart assertions.
   - Atlas updated; no new user-facing surface requires a README update. No Core concepts table is present.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ae798973-da10-41ef-bac8-96163f2af55d","repository":"github.com/xianxu/parley.nvim","issue_id":"000363","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/557f3ccb616a3fc9","reviewed_head":"2d1479cccec4cfd37e62736564ab3a3654b77dc5","slot":"parley.nvim:1","requested_at":"2026-10-17T00:25:07.264583Z"},"phase":"finished","pid":84506,"started_at":"2026-10-17T00:25:07.505526Z","finished_at":"2026-10-17T00:27:29.152165Z","session_id":"01a1473f-8986-7690-a14b-6298f3a365a7","outcome":"returned"}] -->
