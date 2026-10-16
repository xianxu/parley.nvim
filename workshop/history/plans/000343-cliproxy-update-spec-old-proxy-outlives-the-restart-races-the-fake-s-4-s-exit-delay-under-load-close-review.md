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

---

## Re-review — 2026-10-15T23:58:08-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 343 — cliproxy_update_spec: 'old proxy outlives the restart' races the fake's 4 s exit delay under load |
| repo | parley.nvim |
| issue file | workshop/issues/000343-cliproxy-update-spec-old-proxy-outlives-the-restart-races-the-fake-s-4-s-exit-delay-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 30a94402e6a3978a2ce58fbf795dc3eee9389d2d..eec0403b71acd1f29ee4207627c34023e7852f7c |
| command | sdlc close --issue 343 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-15T23:58:08-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking how to run the spec so I can try the mutation, then I'll write up the verdict.

Running the spec directly is blocked by the environment-isolation guard, so I'm running it through the harness instead.

Passes at head. Next I'm removing the in-case kill to confirm the regression test goes red without it.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The round-1 leak is fixed and I proved it. The case now saves the old proxy's pids (`held = cliproxy.spawned_pids()`, a copy). It SIGKILLs them with `kill_held()` and then asserts that the port goes down. `after_each` also calls `kill_held()` so a failing case still cleans up. Through the harness (`PARLEY_TEST_ENV_ROOT` set, orphan gate on), `cliproxy_update_spec.lua` passes at head. With the in-case `kill_held()` removed, it fails at `:508` with "the held old proxy still answers after SIGKILL". So the fix has a regression test that goes red without it. What's left is prose. BR-1 named several places that say "the reap" ends the proxy, and most were not corrected. Comments in the spec and the fake, plus the issue's Spec and Core concepts, still give that credit to `fixture_process.reap`, which never reaches a proxy that parley started.

1. **Strengths**
   - `tests/integration/cliproxy_update_spec.lua:242-250, 492, 508-511`: the kill uses explicit pids, is guarded with `pcall`, and covers the failure path through `after_each`. The case also checks that the port is free after the kill, so a leak like this one can't come back silently. Confirmed red by mutation.
   - `tests/fixtures/fake_cliproxy:542-548`: `SIG_IGN` makes "old proxy still alive" a state the case controls instead of a time window, which is the root-cause fix the issue asks for.
   - `tests/helpers/fixture_process.lua:57-58`: the doc no longer names one example caller, which fixes the BR-2 nit.
   - The sweep of `PARLEY_FAKE_EXIT_DELAY_MS` is complete across lua, tests and atlas, and the unused `threading` import was removed.

2. **Critical findings**: none.

3. **Important findings**
   - **2nd finding in family `teardown-claim-unbacked-by-kill-path`.**
     - **Rule:** any text that says what ends the SIGTERM-ignoring proxy must name the case's pid kill (`kill_held`). It must never credit "the reap": `fixture_process.reap` only signals processes started through `fixture_process.spawn`, and parley's `cliproxy.spawn` starts this one.
     - **Instances still wrong at head:**
       - `tests/integration/cliproxy_update_spec.lua:45-46`: the `reap()` comment gives the old proxy as the reason for SIGKILL, but `reap` never signals that proxy. The real reason is simply that nothing in this file watches a fixture shut down gracefully.
       - `tests/fixtures/fake_cliproxy:542-543`: "only SIGKILL (the spec's reap) ends it".
       - `atlas/providers/cliproxy-managed.md:487-488`: "until a SIGKILL reap". This is ambiguous; it should say "until the spec SIGKILLs it by pid".
       - The issue's `## Spec`: "the spec's reap SIGKILLs it (the shared reap drops `sigterm`: its only reason was this window)".
       - The issue's `## Core concepts` row: "(the spec's reap)".
       - The plan item "reap uses SIGKILL" carries the same rationale.
     - **Fix:** go through all six in one pass (grep `reap` near `IGNORE_SIGTERM`) and add a `## Revisions` entry.

4. **Minor findings**: none new.

5. **Test coverage notes**
   - The mutation check is confirmed: removing the in-case `kill_held()` makes the spec fail at `:508`, and with it the spec passes in 28 s.
   - The orphan gate reported no survivors after the run at head.
   - The "fails both ways" clause of Done-when is covered by the log's measured red at shortened delays, and the old time window is gone.

6. **Architectural notes**
   - ARCH-DRY: pass. `kill_held` is one helper used at both sites.
   - ARCH-PURE: pass. Only tests and fixtures change.
   - ARCH-PURPOSE: pass on behaviour. The prose sweep above is the class the BR-1 fix left incomplete.
   - For later work: any fake mode that resists `cliproxy.stop()` needs its own kill by pid, because the `fixture_process` seam doesn't cover processes parley starts.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry saying `fixture_process.reap` never covered parley-started proxies, so the case SIGKILLs the held pids itself (BR-1).
   - Reword the Spec sentence and the Core concepts row to say the case SIGKILLs the old proxy by pid.
   - Give the spec's switch to SIGKILL its real reason: no case in that file watches a graceful shutdown.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The kill path exists (held pids, kill_held in the case and in after_each) and the spec goes red at :508 without it, verified by mutation. The leftover false prose is raised as a new finding in the same family.
  - id: BR-2
    disposition: addressed
    note: |
      fixture_process.lua:57-58 no longer names a single example caller.
findings:
  - id: new
    severity: Important
    kind: defect
    family: teardown-claim-unbacked-by-kill-path
    title: |
      Comments, atlas and issue Spec still credit "the reap" with SIGKILLing the SIGTERM-ignoring proxy
    detail: |
      2nd in family. Rule: text naming what ends the SIGTERM-ignoring proxy must name the case's pid kill (kill_held), never fixture_process.reap, which only signals processes from fixture_process.spawn and never reaches a proxy parley spawned. Instances at head: cliproxy_update_spec.lua:45-46 (the reap() comment justifies SIGKILL by a proxy reap never signals), fake_cliproxy:542-543 "(the spec's reap)", atlas/providers/cliproxy-managed.md:487-488 "until a SIGKILL reap", the issue Spec sentence "the spec's reap SIGKILLs it (the shared reap drops sigterm: its only reason was this window)", the issue Core concepts row "(the spec's reap)", and the Plan item's rationale. Fix all six in one pass and add a Revisions entry.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f0ddc047-1aa4-4083-b5ae-7fdaf2603bee","repository":"github.com/xianxu/parley.nvim","issue_id":"000343","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/8affff9517abc49e","reviewed_head":"eec0403b71acd1f29ee4207627c34023e7852f7c","slot":"parley.nvim:3","requested_at":"2026-10-16T06:55:34.771121Z"},"phase":"finished","pid":45773,"started_at":"2026-10-16T06:55:35.205246Z","finished_at":"2026-10-16T06:58:03.379206Z","session_id":"5a6efc96-4f51-4504-8c95-ea8f84086daf","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T00:05:28-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 343 — cliproxy_update_spec: 'old proxy outlives the restart' races the fake's 4 s exit delay under load |
| repo | parley.nvim |
| issue file | workshop/issues/000343-cliproxy-update-spec-old-proxy-outlives-the-restart-races-the-fake-s-4-s-exit-delay-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 30a94402e6a3978a2ce58fbf795dc3eee9389d2d..10db2bcdc144b82f823a01f020d0e2e0e2fbcff0 |
| command | sdlc close --issue 343 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T00:05:28-07:00 |
| verdict | SHIP |

## Review

Checking how to run the spec so I can verify the fix directly.

Locating the harness mapping for the update spec, then running it.

The plenary path didn't resolve; retrying with the real one.

```verdict
verdict: SHIP
confidence: high
```

This change is ready to ship. The fix swaps the old 4 s wall-clock exit delay for a state the case controls: `PARLEY_FAKE_IGNORE_SIGTERM=1`. That one change removes both failure modes in the issue. The port wait now always ends with the old proxy still answering, and the final probe always sees 9.9.4. The case keeps the pids parley spawned, SIGKILLs them itself, and then checks that the port goes down. The one open finding, BR-3, is fixed at all six places it named, and a Revisions entry was added. I ran `cliproxy_update_spec` twice at head in an isolated harness environment. Both runs passed 40/40 with 0 failed and 0 errors, and no `fake_cliproxy` from this checkout was left running afterwards. The only thing left is a Minor wording leftover in `## Done when`.

Done-when: current. Clause 1 is met: the wall-clock window is gone, and `grep EXIT_DELAY` outside `workshop/` finds nothing. Clause 2 is backed by the Log's 12 concurrent runs at 40/40. The one wording leftover ("then is reaped") is noted below as Minor and does not change what the clause requires.

1. **Strengths**
   - `tests/fixtures/fake_cliproxy:542-548`: the fake no longer runs a timer. It just sets `SIG_IGN`, which makes the race deterministic, and the `threading` import was removed with it.
   - `tests/integration/cliproxy_update_spec.lua:243-251, 267`: `held`/`kill_held` covers both paths. The case kills the proxy itself when it passes, and `after_each` kills it if the case failed before getting that far. `pcall` keeps an already-dead pid harmless.
   - `cliproxy_update_spec.lua:509-512`: after the kill, the case checks that the port actually goes down. Without that check, a leaked proxy would go unnoticed.
   - The shared reap is back on default SIGKILL (`:48-50`). Its doc comment now says correctly that the reap never sees parley's own spawn.
   - The fake's env var was renamed everywhere it appears: `cliproxy.lua:468,493`, the atlas, `fixture_process.lua:58` and `fixture_reaping_spec.lua:192`. No stale references to the old name remain.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**
   - Issue `## Done when` clause 1 still says the old proxy "then is reaped". This is the 3rd finding in family `teardown-claim-unbacked-by-kill-path` (detail below).

5. **Test coverage notes**
   - The race the issue describes is now impossible by construction, so no new timing test is needed. The red evidence in the Log (shrinking the delay to 1000 or 2500 ms fails at :490) shows the old case really did race.
   - The `kill_held` regression is caught by `:509-512`. The Log's mutation (dropping the in-case kill makes the case fail at :508) is consistent with the code.

6. **Architectural notes**
   - **ARCH-DRY: pass.** `kill_held` is a 5-line local helper with a single owner. Nothing in the tree already kills arbitrary pids for specs: `fixture_process.reap` only signals processes started through `fixture_process.spawn`.
   - **ARCH-PURE: pass.** The change only touches test fixtures and comments. No production logic changed.
   - **ARCH-PURPOSE: pass.** The wall-clock window was removed outright, not widened. Every consumer was swept, and no reference to the old env var remains outside the workshop files.

7. **Plan revision recommendations**: none beyond the Done-when wording below. The existing Revisions entry covers BR-1 and BR-3.

```findings
dispose:
  - id: BR-3
    disposition: addressed
    note: |
      All six instances fixed at head - spec reap comment (cliproxy_update_spec.lua:45-47), fake_cliproxy:542-546, atlas cliproxy-managed.md:487-489, issue Spec, Core concepts row, Plan item - plus a Revisions entry; prose-only, and the kill path itself is pinned by cliproxy_update_spec.lua:509-512.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: teardown-claim-unbacked-by-kill-path
    title: |
      Issue Done-when clause 1 still says the held proxy "then is reaped"
    detail: |
      3rd in family. Rule: any text saying what ends the SIGTERM-ignoring proxy must name the case's own pid SIGKILL (kill_held), never "reap", because fixture_process.reap only signals fixture_process.spawn children. Enumeration in this window: the only remaining instance is the "e.g." in Done-when clause 1. All code, atlas and Spec/Plan/Core-concepts text is now correct. Fix: reword to "...until the case SIGKILLs the pids it held", if the flow allows editing Done-when.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9ff1c12f-5bc5-4d65-b495-e838cd044d64","repository":"github.com/xianxu/parley.nvim","issue_id":"000343","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/11b5b4ff912a9b05","reviewed_head":"10db2bcdc144b82f823a01f020d0e2e0e2fbcff0","slot":"parley.nvim:3","requested_at":"2026-10-16T06:59:34.964307Z"},"phase":"finished","pid":69666,"started_at":"2026-10-16T06:59:35.205788Z","finished_at":"2026-10-16T07:05:26.623427Z","session_id":"dd15fe84-658e-4096-bf46-63613088ae0f","outcome":"returned"}] -->
