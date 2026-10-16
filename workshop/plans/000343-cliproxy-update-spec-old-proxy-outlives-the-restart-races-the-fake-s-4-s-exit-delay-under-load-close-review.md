# Boundary Review — parley.nvim#343 (whole-issue close)

| field | value |
|-------|-------|
| issue | 343 — cliproxy_update_spec: 'old proxy outlives the restart' races the fake's 4 s exit delay under load |
| repo | parley.nvim |
| issue file | workshop/issues/000343-cliproxy-update-spec-old-proxy-outlives-the-restart-races-the-fake-s-4-s-exit-delay-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 30a94402e6a3978a2ce58fbf795dc3eee9389d2d..a3365ebb9598f2eb2c074fa23bd8988f8a89e852 |
| command | sdlc close --issue 343 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-15T23:52:39-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I'm checking whether parley's own `uv.spawn` of the managed proxy goes through the fixture reap seam.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix itself is sound. Replacing the 4 s wall-clock exit delay with `PARLEY_FAKE_IGNORE_SIGTERM=1` turns a timed window into a state, which matches the issue's Spec. The restart-race case can no longer lose the race in either failure mode, whether the fake exits before the 2 s port wait ends or before the final probe. Every reference to `PARLEY_FAKE_EXIT_DELAY_MS` is gone from code, tests and atlas. One thing blocks a clean SHIP: the change explains how the old proxy ends in a way the code doesn't support. The old managed proxy is started by parley's own `cliproxy.spawn` (`uv.spawn`, detached, `lua/parley/cliproxy.lua:680`), not by `fixture_process.spawn`. So `fixture_process.reap` never sends it a signal of any kind. The only teardown signal it gets is `cliproxy.stop()`'s SIGTERM in `after_each` (`cliproxy_update_spec.lua:257`), and it now ignores that. Despite what the comments say, no SIGKILL reaps it. It keeps holding its port until the spec file's nvim exits and the fixture watchdog fires.

1. **Strengths**
   - `tests/fixtures/fake_cliproxy:542-548`: a state the test controls (SIG_IGN) replaces a timed window. This is the right shape of fix for the root cause the issue names.
   - The old window was shown to be real before the fix (the case fails at 1000 and 2500 ms), so the change answers a measured race, not a guess.
   - The sweep of `EXIT_DELAY` references is complete: `cliproxy.lua:468,493`, `fixture_process.lua:57-59`, `fixture_reaping_spec.lua:192-193`, atlas `:487`, and the spec's `after_each` env reset `:262`.
   - The unused `threading` import was removed together with the timer.

2. **Critical findings**: none.

3. **Important findings**
   - **The claim that the reap SIGKILLs the SIGTERM-ignoring proxy is false.** The case leaks a live proxy for the rest of the spec file's run.
     - `fixture_process.reap` only walks its own registry (`tests/helpers/fixture_process.lua:61-77`).
     - The managed proxy is spawned through `cliproxy.spawn` → `uv.spawn` (`lua/parley/cliproxy.lua:680`), which is outside that seam.
     - Changing the spec's `reap()` from `sigterm` to the default SIGKILL therefore has no effect on this process.
     - At base, the old fake didn't die from the reap either. It died 4 s after `cliproxy.stop()`'s SIGTERM. So the issue's rationale "its only reason was this window" doesn't hold either.

     Every place that makes the claim:
     - `tests/integration/cliproxy_update_spec.lua:45-46`
     - `cliproxy_update_spec.lua:482-485` ("serves until the reap SIGKILLs it")
     - `tests/fixtures/fake_cliproxy:542-543` ("only SIGKILL (the spec's reap) ends it")
     - `atlas/providers/cliproxy-managed.md:487-488` ("until a SIGKILL reap")
     - The issue's Spec and Core concepts row.

     Fix sketch: before `update()`, record the old pid (`cliproxy.spawned_pids()[1]`, which the case already reads via `ours_row`). Then SIGKILL it in the case's teardown, using a pcall-guarded `uv.kill(pid, "sigkill")` registered so it runs even when an assertion fails. Then correct the comments and atlas to name that kill. Optionally, add an assertion that the pid is gone after teardown, so the leak can't come back silently.

4. **Minor findings**
   - The `fixture_process.lua:57-59` doc names `cliproxy_conformance_spec` as the example caller that passes `sigterm`. `openai_tool_loop_spec:89` and `stream_integrity_spec:67` do too. It isn't wrong, since it's framed as an example.

5. **Test coverage notes**
   - The red evidence (the window shrunk to 1000/2500 ms fails) and the green evidence (12×40 concurrent runs) cover the race.
   - Nothing covers the old proxy's lifetime after the case. That gap is how the false reap claim went unnoticed.
   - The Log line "No fake_cliproxy left running after them" was measured after nvim exited, which is when the watchdog kills it. It doesn't show that anything reaped the proxy during the run.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The diff adds no duplicated logic.
   - **ARCH-PURE: pass.** Only test fixtures and comments change.
   - **ARCH-PURPOSE: pass on purpose, with the caveat above.** Both Done-when clauses are delivered: there is no wall-clock dependency, and the loaded-suite runs are recorded. The teardown story is the gap.
   - For later work: processes that parley spawns itself, and specs then make SIGTERM-immune, fall outside the `fixture_process` seam. Any future fake mode that resists `stop()` needs its own SIGKILL path.

7. **Plan revision recommendations**
   - Add a "## Revisions" entry. The reap-signal change doesn't end the SIGTERM-ignoring proxy, because `fixture_process.reap` never covered parley-spawned proxies. The case now kills the old pid explicitly with SIGKILL. Then correct the Spec sentence "the spec's reap SIGKILLs it (the shared reap drops `sigterm`: its only reason was this window)" and the Core concepts row.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: teardown-claim-unbacked-by-kill-path
    title: |
      SIGTERM-ignoring old proxy is never SIGKILLed; the reap cannot reach parley-spawned proxies
    detail: |
      The old managed proxy is spawned by cliproxy.spawn (uv.spawn, lua/parley/cliproxy.lua:680), not fixture_process.spawn, so fixture_process.reap (tests/helpers/fixture_process.lua:61-77) never signals it. after_each's cliproxy.stop() sends SIGTERM, which it now ignores, so it holds its port until nvim exits and the watchdog fires. False claims: cliproxy_update_spec.lua:45-46 and :482-485, fake_cliproxy:542-543, atlas/providers/cliproxy-managed.md:487-488, and the issue Spec and Core concepts. Fix: record the old pid before update(), SIGKILL it in a guarded teardown, and correct those comments and the atlas.
  - id: new
    severity: Minor
    kind: defect
    family: doc-example-incomplete
    title: |
      fixture_process.reap doc cites only cliproxy_conformance_spec as a sigterm caller
    detail: |
      openai_tool_loop_spec:89 and stream_integrity_spec:67 also pass signal = "sigterm". It is phrased as an example, so this is a nit.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"56bbd892-6165-4d06-a400-7e9124a37c14","repository":"github.com/xianxu/parley.nvim","issue_id":"000343","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/281e18471be36419","reviewed_head":"a3365ebb9598f2eb2c074fa23bd8988f8a89e852","slot":"parley.nvim:3","requested_at":"2026-10-16T06:51:23.516139Z"},"phase":"finished","pid":17971,"started_at":"2026-10-16T06:51:24.085341Z","finished_at":"2026-10-16T06:52:37.870206Z","session_id":"cb0d355e-818f-4477-a860-15d83795e288","outcome":"returned"}] -->
