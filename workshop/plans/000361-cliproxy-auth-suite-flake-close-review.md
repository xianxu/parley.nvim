# Boundary Review — parley.nvim#361 (whole-issue close)

| field | value |
|-------|-------|
| issue | 361 — Cliproxy expired-token recovery intermittently retries instead of prompting |
| repo | parley.nvim |
| issue file | workshop/issues/000361-cliproxy-auth-suite-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6759ce28d37377959224580f2118f0fdac4985b5..15f3948fe88ef9ba9f1799abb9e34b555b9f5d5c |
| command | sdlc close --issue 361 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T03:26:01-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff read; checking the new regression test's lsof dependency and running the focused specs now.

Running the focused specs (nodiscard, ready_port, auth_login) to confirm behavior.

Setting up the isolated test env to run the three changed specs directly.

Specs pass. Now a quick mutation check: put one bare `wait_listening` back and confirm the guard flags it.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix holds up. The real defect was 38 test call sites that ignored the result of `wait_listening`. They now use `require_listening`, which fails with the fake's port in the message. The `nodiscard_spec` guard now covers spec-side helpers, and no production code changed. I ran the three changed specs in the harness's isolated environment: nodiscard 2/2, ready_port 14/14 and cliproxy_auth_login 23/23 all pass. I also put one bare `ready_port.wait_listening(port)` back at `cliproxy_recovery_e2e_spec.lua:44`. The guard flagged it by file and line, and I reverted the change afterwards. One cheap Important finding stops a clean SHIP. The new forced-window regression test depends on `lsof` but does not skip when `lsof` is missing, unlike the test next to it in `ready_port_spec`. On a host without `lsof` it fails every time.

1. **Strengths**
   - `tests/helpers/ready_port.lua:186` — `require_listening` names the port and the wait time, and it raises at level 2 so the error points at the caller. It is unit-tested for both cases: no listener and a real listener (`tests/unit/ready_port_spec.lua:125-139`).
   - ARCH-DRY: the guard extends the existing `nodiscard_spec` (`DECLARING`/`CALLING`, plus `is_spec_side(member)`) instead of adding a second check. Limiting spec files to helper members only is a reasoned choice, and the code comment explains it.
   - `fake_cliproxy` `PARLEY_FAKE_BIND_DELAY_MS` is capped at 10 s. Holding the window open makes the regression deterministic instead of a race.
   - The sweep is complete: no bare `wait_listening` statement remains anywhere in `tests/`. Every remaining caller uses the result (wrapped in `assert(...)` or asserted directly).
   - The atlas is updated (`atlas/infra/test_harness.md:168-172`) for the new helper and the guard.

2. **Critical:** none.

3. **Important**
   - `tests/integration/cliproxy_auth_login_spec.lua:141` — the new test replaces `_connect` with a stub that always succeeds. That only works if `lsof` confirms the listener. Without `lsof`, `is_listening` returns `not _lsof_present()`, which is `true`. Readiness then passes at once, `recover` runs against a fake that isn't bound yet, and the test fails deterministically. The test next to it, `tests/unit/ready_port_spec.lua:85`, already skips in this case with `pending("needs lsof to confirm the listener")`. Fix: add the same guard at the top of this test. This is the only unguarded test in the window that stubs `_connect`.

4. **Minor**
   - The plan and log say "the 37 calls that dropped the answer (lifecycle 26, update 9, recovery_e2e, auth_login, fake_releases)". Those parts add up to 26+9+1+1+1 = 38, and the head has 38 `require_listening` call sites. The count appears in both the Plan checklist and the Log.
   - ARCH-DRY: 12 existing sites still write `assert(ready_port.wait_listening(port), "...")` by hand, which repeats what `require_listening` now does:
     - `openai_tool_loop_spec:37`
     - `cliproxy_catalog_spec:22,141,155,214,350,430`
     - `fixture_reaping_spec:147`
     - `cliproxy_caller_teardown_spec:46`
     - `cliproxy_dispatch_spec:29`
     - `stream_integrity_spec:37`
     - `tests/helpers/provider_scenarios.lua:20`

     They are correct, so this is optional cleanup.

5. **Test coverage**
   - The forced-window regression fails if the #360 LISTEN confirm is removed (per the log). It checks #360's fix, not this round's `nodiscard` change. That change is checked by `nodiscard_spec`, and my mutation run confirmed it.
   - The Done-when clause "preserve healthy-credential retry" is met trivially, since no production code changed.

6. **Architecture**
   - **ARCH-DRY: pass.** The existing guard is extended, not duplicated; the 12 hand-written asserts above are Minor.
   - **ARCH-PURE: pass.** The diff only touches test code. The IO is behind seams that can be swapped out (`_connect`, `_run_lsof`, `_lsof_present`).
   - **ARCH-PURPOSE: pass.** Every caller that dropped the result was converted, and the guard enforces the rule mechanically instead of leaving it to documentation.

7. **Plan revisions:** correct "37 calls" to 38 in the Plan item and the Log.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: lsof-dependent-test-guard
    title: |
      Forced-window regression stubs _connect but lacks the lsof-absent pending guard
    detail: |
      tests/integration/cliproxy_auth_login_spec.lua:141 replaces ready_port._connect with a stub that always succeeds. Where lsof is absent, is_listening returns not _lsof_present() (true), so readiness passes at once against a fake that is not yet bound, and the test fails deterministically. Add the same guard tests/unit/ready_port_spec.lua:85 uses: if not ready_port._lsof_present() then return pending("needs lsof to confirm the listener") end. This is the only unguarded test in the window that stubs _connect.
  - id: new
    severity: Minor
    kind: defect
    family: doc-count-claims
    title: |
      Plan and Log say 37 converted calls; the listed parts and the code give 38
    detail: |
      Plan item and Log both say 37 (lifecycle 26, update 9, recovery_e2e, auth_login, fake_releases), which adds up to 38. The head has 38 require_listening call sites outside ready_port.lua and its unit spec. Fix both mentions.
  - id: new
    severity: Minor
    kind: defect
    family: ready-wait-assert-restated
    title: |
      12 existing sites still hand-write assert(ready_port.wait_listening(port), msg), repeating require_listening
    detail: |
      ARCH-DRY. Sites: openai_tool_loop_spec:37, cliproxy_catalog_spec:22,141,155,214,350,430, fixture_reaping_spec:147, cliproxy_caller_teardown_spec:46, cliproxy_dispatch_spec:29, stream_integrity_spec:37, tests/helpers/provider_scenarios.lua:20. They are correct; converting them is optional cleanup.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"988648ae-313b-4042-be57-0f9d45d37fdd","repository":"github.com/xianxu/parley.nvim","issue_id":"000361","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ce176c11e9286153","reviewed_head":"15f3948fe88ef9ba9f1799abb9e34b555b9f5d5c","slot":"parley.nvim:4","requested_at":"2026-10-17T10:23:20.627625Z"},"phase":"finished","pid":70933,"started_at":"2026-10-17T10:23:20.832415Z","finished_at":"2026-10-17T10:26:00.296046Z","session_id":"d9d98c43-d1e0-45f6-b06b-4ddd49339a3f","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T04:29:12-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 361 — Cliproxy expired-token recovery intermittently retries instead of prompting |
| repo | parley.nvim |
| issue file | workshop/issues/000361-cliproxy-auth-suite-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6759ce28d37377959224580f2118f0fdac4985b5..12105c271e036569b9a917a5ca3da1c1860116ba |
| command | sdlc close --issue 361 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T04:29:12-07:00 |
| verdict | SHIP |

## Review

Prior-round fixes check out on inspection: 50 call sites, the lsof guard is present, and no bare `wait_listening` is left. Next I'm running the focused specs to confirm.

I'm looking for a make target that runs a single spec file, so the test environment gets set up.

Old make. I'll write a small makefile in a scratch directory that includes the repo's Makefile.

Raw output has ANSI color codes, so my grep missed it. Rerunning with summary lines only.

All focused specs pass. One last check: put a bare `wait_listening` call back and confirm the nodiscard guard catches it.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: ship it.** All three findings from round 1 are fixed. I checked each one against the code at head `12105c27` and against tests I ran myself. The cause matches what the issue's Log describes. The `serve()` helper ignored the result of its readiness wait (`wait_listening`). Combined with the #360 false positive, recovery could then run against a fake proxy that wasn't listening yet. Every fixture wait now goes through one function, `require_listening`, which fails the spec by name when the fake never comes up. A dropped `wait_listening` result is now caught mechanically by the existing `nodiscard_spec`, not just by convention. Nothing blocks shipping.

1. **Strengths**
   - **The guard has real effect.** I changed `tests/helpers/fake_releases.lua` back to a bare `ready_port.wait_listening(port)`. `tests/arch/nodiscard_spec.lua` then failed ("never drops one as a bare statement unless declared"). I reverted it and the checkout is clean.
   - **One shared helper.** `tests/helpers/ready_port.lua:139` holds `require_listening`, and `DEFAULT_LISTEN_MS` is shared so the error message reports the real timeout. Outside `ready_port.lua` and its unit spec, there are 50 `require_listening` call sites and no bare `wait_listening` calls left. The only other match is a comment and a name string in `nodiscard_spec`.
   - **The spec-side scope is narrow on purpose.** In files under `tests/`, the arch check (`nodiscard_spec.lua:62-63`) only flags results of `---@nodiscard` functions declared in helpers. It does not flag product results that spec setup ignores deliberately.
   - **The new regression test cleans up.** It restores `_connect` after the `pcall`, even when `serve` fails (`cliproxy_auth_login_spec.lua:151-156`). The new fake-proxy bind delay is capped at 10 s and ignores values of zero or less (`tests/fixtures/fake_cliproxy:556-561`).

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none.

5. **Test coverage notes**
   - Every spec I ran passed with no failures or errors:

     | Spec | Passed |
     |---|---|
     | ready_port | 14 |
     | nodiscard | 2 |
     | cliproxy_auth_login | 23 |
     | cliproxy_catalog | 22 |
     | fixture_reaping | 12 |
     | cliproxy_dispatch | 3 |
     | stream_integrity | 1 |
     | openai_tool_loop | 3 |
     | cliproxy_caller_teardown | 5 |

   - I did not run the full suite, or the lifecycle and update specs. Their 35 call sites are mechanical one-line swaps of a call whose result was already ignored, and the arch check covers them.
   - **BR-1's guard was checked by reading only.** The guard only matters on a machine without lsof, and this machine has lsof, so the branch can't be triggered here. Its form is identical to the existing guard in `tests/unit/ready_port_spec.lua:85`.

6. **Architectural notes**
   - **ARCH-DRY: pass.** All 12 places that hand-wrote the wait-and-assert now use the shared helper. A repo-wide grep found no other copy.
   - **ARCH-PURE: pass.** The diff is test-harness glue. The pure decision in `is_listening` stays reachable through the existing `_connect`, `_has_listener` and `_lsof_present` seams.
   - **ARCH-PURPOSE: pass.** I swept the whole class: every readiness wait in the tree derives from `require_listening`, and the arch check enforces it. The Done-when clauses are met:
     - The forced-window regression reproduces the bug.
     - The fix is in the fixture, which is where the cause was.
     - Real healthy-credential retry tests in `cliproxy_auth_login_spec` still pass (23/23).

7. **Plan revision recommendations:** none. The plan's figure of 38 is right for that plan item. The Log entry for round 1 accounts for the other 12.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      cliproxy_auth_login_spec.lua:148-150 now returns pending when lsof is absent (same guard as ready_port_spec.lua:85); the other _connect stubs either guard or stub _lsof_present; the spec passes 23/23 at head.
  - id: BR-2
    disposition: addressed
    note: |
      Plan item and Log now say 38, which matches the listed parts (26+9+1+1+1) and the original call sites.
  - id: BR-3
    disposition: addressed
    note: |
      All 12 sites now call require_listening; no bare or asserted wait_listening is left outside ready_port and its unit spec; the affected specs all pass.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"747aede9-29d0-49ff-8453-5084834f0d78","repository":"github.com/xianxu/parley.nvim","issue_id":"000361","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/070d05f3053a4a95","reviewed_head":"12105c271e036569b9a917a5ca3da1c1860116ba","slot":"parley.nvim:4","requested_at":"2026-10-17T11:25:44.919802Z"},"phase":"finished","pid":94646,"started_at":"2026-10-17T11:25:45.01347Z","finished_at":"2026-10-17T11:29:10.8586Z","session_id":"220b9b12-b9d0-4d30-8c25-83078094c504","outcome":"returned"}] -->
