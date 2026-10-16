# Boundary Review — parley.nvim#355 (whole-issue close)

| field | value |
|-------|-------|
| issue | 355 — cliproxy_auth_login_spec restart-rung case flakes under load (fixed 6 s wait) |
| repo | parley.nvim |
| issue file | workshop/issues/000355-cliproxy-auth-login-spec-restart-rung-case-flakes-under-load-fixed-6-s-wait.md |
| boundary | whole-issue close |
| milestone | — |
| window | 10c9369e314b629f096da4ca6520fe620a20ff06..fb0694d52d805cdb99e84e395484a64d4e797fb1 |
| command | sdlc close --issue 355 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T11:21:17-07:00 |
| verdict | SHIP |

## Review

Still working out how this repo runs a single spec so I can run the new test and check that it goes red without the fix.

Found the harness. Next I'll run just this one spec file through it.

Simplest route: a one-off Makefile target that reuses the harness env.

The spec passes at head (22/22). Now I'm checking that the new regression case fails when the wait goes back to the old 6000 ms.

The regression goes red without the fix and green with it. One last check on the comment's "curl's 2 s max-time" claim, then the verdict.

```verdict
verdict: SHIP
confidence: high
```

This is a test-only change in `tests/integration/cliproxy_auth_login_spec.lua`, and it fixes what the issue says. All three hard-coded waits on a claimed recovery are gone: the 6000 in `run()`, the 9000 in the EXHAUSTIVE case and the 6000 in the seed read. They now use one bound, `SETTLE_MS = require("parley.dispatcher").recovery_timeout_ms` (30 000 ms, `lua/parley/dispatcher.lua:33`). The Done-when clause asks for "plus a margin". The margin is built into that bound: `tests/unit/cliproxy_budget_spec.lua:47` asserts the backstop is at least 5 s above the itemized repair budget, so the test waits on the same number production code uses. The Revisions entry replaces the "20 runs under load" clause with a fixed regression case, and gives a reason. I checked that case in this checkout. At head the whole spec passes, 22/22 in about 23 s. With `SETTLE_MS` set back to `6000`, the new case "settles the restart rung within the backstop when every probe is slow (#355)" **fails**, and the original restart-rung case still passes. That fits the flake report: the old value only broke when the proxy was slow. I restored the file afterwards (`git status` clean). Nothing blocks shipping.

1. **Strengths**
   - One source of truth for the wait (`cliproxy_auth_login_spec.lua:17`). It derives from the production backstop instead of a new literal. Its comment points at the budget spec that proves the repair fits under it.
   - The regression is deterministic. It uses the fake's existing `PARLEY_FAKE_GET_DELAY_MS` knob (`tests/fixtures/fake_cliproxy:302-304`) instead of relying on machine load, and it demonstrably goes red without the fix.
   - The scenario body became the local `restart_rung()`, so the normal case and the slow-probe case share one body instead of copying it (`:404-431`).
   - The env var is restored after a `pcall`, then the error is re-raised (`:438-442`), so a failure doesn't leak the delay into later cases.
   - The comment's claims check out: the 1.5 s delay is under `CURL_MAX_TIME = 2` (`lua/parley/cliproxy.lua:29`).

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - The plan says "fails with `SETTLE_MS = 6000` … 5/5 runs". I confirmed that once, not five times.
   - On failure the slow case now waits up to 30 s before reporting, not 6 s. That's an acceptable trade for a test that should never fail.

5. **Test coverage notes:** The new case pins the exact failure the issue describes (`settled` nil after a fixed wait while the rung was still inside its budget), and I confirmed it fails when the fix is reverted. A passing run still settles in under a second, so the bigger wait doesn't slow the suite.

6. **Architectural notes**
   - **ARCH-DRY: pass.** There is one `SETTLE_MS` and one shared `restart_rung` body. The other literal waits in this file are 200 ms quiescence sleeps, not settle waits, so they're a different kind of wait.
   - **ARCH-PURE: pass / not applicable.** No production code changed.
   - **ARCH-PURPOSE: pass.** The shadow-sweep covers every claimed-recovery wait in this spec, and all of them now derive from the backstop. The Log explicitly leaves the other cliproxy specs' waits out of scope because they cover different paths and haven't flaked. Those are separate extensions, not the purpose of this issue. If one of them flakes, the same `recovery_timeout_ms` derivation applies.

7. **Plan revision recommendations:** none. The existing Revisions entry already covers the replaced Done-when clause.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: unverified-repeat-count-claim
    title: |
      Plan claims the regression fails at 6000 ms in 5/5 runs; review confirmed one run
    detail: |
      Reverting SETTLE_MS to 6000 made the #355 case fail once in this checkout; the 5/5 count in the Plan is the implementer's, not re-measured here. The rest of this window has no other run-count claims.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3a2b1e59-161e-4134-a84e-540550ac7f46","repository":"github.com/xianxu/parley.nvim","issue_id":"000355","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/9e0219cf797082ab","reviewed_head":"fb0694d52d805cdb99e84e395484a64d4e797fb1","slot":"parley.nvim:4","requested_at":"2026-10-16T18:18:54.447166Z"},"phase":"finished","pid":17808,"started_at":"2026-10-16T18:18:54.637502Z","finished_at":"2026-10-16T18:21:15.652271Z","session_id":"8ef1726d-7350-4d50-a02f-a9c93d625bf0","outcome":"returned"}] -->
