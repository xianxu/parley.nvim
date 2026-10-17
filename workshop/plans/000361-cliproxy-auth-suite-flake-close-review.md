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
