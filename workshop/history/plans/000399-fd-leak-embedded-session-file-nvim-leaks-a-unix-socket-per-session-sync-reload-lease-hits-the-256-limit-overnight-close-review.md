# Boundary Review — parley.nvim#399 (whole-issue close)

| field | value |
|-------|-------|
| issue | 399 — fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight |
| repo | parley.nvim |
| issue file | workshop/issues/000399-fd-leak-embedded-session-file-nvim-leaks-a-unix-socket-per-session-sync-reload-lease-hits-the-256-limit-overnight.md |
| boundary | whole-issue close |
| milestone | — |
| window | c631353ce8819de93750cc88a9c90322adedcf0e..f5ba60ef647c77630c0dea439b370a21d5d14885 |
| command | sdlc close --issue 399 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T07:59:00-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've confirmed one security issue and am running the new specs now.

Running the specs through the atlas-mapped make target.

Session-sync specs pass. Last check: whether the README lists config keys like this one.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The rescoped issue #399 ("detect and capture") is mostly delivered, and it matches the revised "Done when". The watchdog splits into four pure decisions (`crossed`, `children`, `report`, `stale`) behind a small shell for the timer, commands and files. The two session-sync guards run against the fake couch and passed: 66/66 in `session_sync_spec`, and every spec mapped to `modes/session_sync` was green. Three things should be fixed before close, and none needs a redesign:

- **Secrets on disk:** the capture writes the full command line of every child process to disk. Parley passes API keys to `curl` on its command line, so a capture taken during a request would write a live key into the state directory.
- **README:** the new config key `fd_watchdog_threshold` is missing from the README.
- **Flaky spec:** the integration spec failed once in 10 runs under the real make harness.

**1. Strengths**
- `lua/parley/fd_watchdog.lua:15-62`: the decisions are pure and the unit tests need no IO. That covers the threshold edges (=, >, already fired, 0, nil), the ps parser ignoring grandchildren and junk lines, recording a failed command, and the retention rule ignoring unrelated files.
- `fd_watchdog.lua:76-81`: when spawning fails, the error is turned into a result with `code = -1` instead of being thrown, so a missing `lsof` still produces a capture that records the failure.
- The integration spec uses stand-in `lsof`/`ps` scripts and the real timer and file path, which is the same seam production uses (ARCH-MOCK).
- Every created file has an end (ARCH-FUNERAL): the writer prunes to the newest 5, it fires once per process, and the timer is stoppable.
- The rename-storm guard (`session_sync_spec.lua:379-415`) reproduces the shape of the overnight migration, a mass rename plus one rewrite, against the fake registry.

**2. Critical findings**
None.

**3. Important findings**
- **Secrets written to disk (ARCH-SECURE)**, `fd_watchdog.lua:20-26,46-48`: `children()` keeps each child's full command line (`ps command=`), and the report writes it to disk. Parley puts secrets on the curl command line: `providers.lua:355,643,1069,1290` (`Authorization: Bearer <secret>`, `x-api-key: <secret>`), `oauth.lua:1654…`, and `cliproxy.lua:171`, launched through `dispatcher.lua:886`. A capture taken while a request is streaming writes the key to `state_dir/fd-captures`.
  - Fix: mask header values in the pure `children` function or the report, e.g. replace the value after `Authorization:`, `x-api-key:` and `-H` with `<redacted>`.
  - Add a unit case that feeds in a curl row containing a bearer token.
- **README gap**: README.md documents its sibling keys (`session_sync_ping_minutes` and `session_sync_stale_minutes` at README.md:76-77). It has nothing on the new `fd_watchdog_threshold`, the warning it raises, or the `state_dir/fd-captures` location.
- **Flaky spec**: `tests/integration/fd_watchdog_spec.lua:66` (`assert.equals(0, #warnings)` in "stays quiet…") failed 1 of 10 times under `make test-spec SPEC=infra/fd_watchdog`.
  - The other 9 runs passed, including the rerun with the failure message instrumented, so the stray warning's text was never captured.
  - The `warnings` upvalue is shared between tests and the spec never checks the message. That makes the failure undiagnosable and could hide a late callback from the previous test.
  - Fix: assert on the message content and drain scheduled callbacks in `after_each` before restoring `vim.notify`.

**4. Minor findings**
- `M.stop()` resets `fired`, so calling `setup()` again (a config reload) re-arms the once-per-process capture. The atlas says "fires once per process". `fd_watchdog.lua:125`.
- After firing, the timer keeps listing `/dev/fd` every minute for the rest of the session. It could stop itself once it has fired.
- The stamp in capture file names uses local time (`os.date("%Y%m%d-%H%M%S")`), so `stale`'s sort-by-name can misorder captures across a DST fall-back. The report body uses UTC. Using UTC for the stamp too is cheap.
- If `writefile` fails, the error itself is dropped; only the path is reported (`fd_watchdog.lua:91`).

**5. Test coverage notes**
- All four unit tests pass. The capture-path integration test passed in all 10 runs.
- Nothing covers redacting command lines (see Important #1).
- The two session-sync guards tolerate +2 descriptors and passed in this environment.
- The third "Done when" item (file the root cause from the first capture) depends on a future onset, so it can't be delivered at this boundary. The issue correctly stays `working`.

**6. Architecture notes**
- **ARCH-DRY: flag (minor).** `fds()` is copied into each of the two session-sync guards (`session_sync_spec.lua:363,380`) and again in `fd_watchdog_spec.lua`. All three duplicate the module's private `count()`. Exposing `M.count` would give one source of truth.
- **ARCH-PURE: pass.** The decisions are pure; the IO shell is small.
- **ARCH-PURPOSE: pass**, against the revised scope. The root cause is properly handed to a future issue, and #400 holds the deadline work.
- **ARCH-MOCK: pass.** There are stand-in `lsof`/`ps` scripts and the fake couch on PATH. Real `lsof` output is only free text in the report, so no conformance check is needed.
- **ARCH-CONSTRAINTS: pass.** One `/dev/fd` scan a minute, a 10 s deadline per command, and it runs off the UI path asynchronously.
- **ARCH-SECURE: flag** (Important #1).
- **ARCH-ORDER: pass**, with a note. The only carried state is `{timer, fired}`, and `fired` is set synchronously before the asynchronous capture, so it can't fire twice. Calling `setup()` again while a capture is in flight is harmless.
- **ARCH-FUNERAL: pass.** Pruning happens on the write itself and the capture fires once.
- **ARCH-EVOLVE: N/A.** The capture is a human-read text report that nothing parses back. The new config key is added alongside the existing ones.

**7. Plan revision recommendations**
- In the watchdog row of the Plan, note that child command lines are redacted before they are written. The current text promises "the live children" verbatim, which is exactly what leaks credentials.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: secret-in-persisted-diagnostic
    title: |
      fd capture writes child argv verbatim; curl children carry Authorization/x-api-key secrets
    detail: |
      fd_watchdog.children/report persist ps `command=` for each child to state_dir/fd-captures, while providers.lua:355,643,1069,1290, oauth.lua:1654 and cliproxy.lua:171 put bearer tokens and API keys on curl's argv (dispatcher.lua:886). Redact header values in the pure children/report step and add a unit case with a bearer-token curl row.
  - id: new
    severity: Important
    kind: defect
    family: readme-config-surface
    title: |
      README update appears missing for config key fd_watchdog_threshold and the fd-captures warning
    detail: |
      README.md:76-77 documents sibling session_sync_* keys; the new user-facing key, its 0-disables semantics, the once-per-process warning and the state_dir/fd-captures location are not mentioned.
  - id: new
    severity: Important
    kind: defect
    family: flaky-timer-spec
    title: |
      fd_watchdog integration spec "stays quiet" failed 1 of 10 runs under make test-spec
    detail: |
      tests/integration/fd_watchdog_spec.lua:66 saw an unexpected warning once in 10 runs of `make test-spec SPEC=infra/fd_watchdog`. The shared `warnings` upvalue and the unchecked message content leave the source undiagnosable. Assert the message, and drain scheduled callbacks in after_each before restoring vim.notify.
  - id: new
    severity: Minor
    kind: defect
    family: once-per-process-contract
    title: |
      M.stop resets `fired`, so re-running setup re-arms the "once per process" capture
    detail: |
      fd_watchdog.lua:125; the atlas says it fires once per process. The timer also keeps scanning after firing.
  - id: new
    severity: Minor
    kind: defect
    family: arch-dry-test-helper
    title: |
      /dev/fd counting copied into three specs and duplicating the module's private count()
    detail: |
      session_sync_spec.lua:363,380 and fd_watchdog_spec.lua; expose M.count and reuse it.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e9a80961-6cdc-4405-81a1-bac791b74e8d","repository":"github.com/xianxu/parley.nvim","issue_id":"000399","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/958cfbfc9d73b371","reviewed_head":"f5ba60ef647c77630c0dea439b370a21d5d14885","slot":"parley.nvim:3","requested_at":"2026-10-19T14:53:31.994595Z"},"phase":"finished","pid":18737,"started_at":"2026-10-19T14:53:32.242343Z","finished_at":"2026-10-19T14:58:59.504675Z","session_id":"144aab52-713d-4f01-ba5f-a0dc27d97a59","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T08:14:24-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 399 — fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight |
| repo | parley.nvim |
| issue file | workshop/issues/000399-fd-leak-embedded-session-file-nvim-leaks-a-unix-socket-per-session-sync-reload-lease-hits-the-256-limit-overnight.md |
| boundary | whole-issue close |
| milestone | — |
| window | c631353ce8819de93750cc88a9c90322adedcf0e..637d080c05278db659d095dceb7b58ce5f8d174d |
| command | sdlc close --issue 399 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T08:14:24-07:00 |
| verdict | SHIP |

## Review

Checking prior findings against the code now; next I'll run the watchdog specs a few times to test the flake fix.

8 of 8 runs passed. Next I'll undo the BR-1 fix to confirm the regression test fails without it.

With the BR-1 fix removed, the spec failed as expected. Now testing the BR-4 once-per-process fix the same way, on its own.

Scope matches the documented hub rescope. One last check: running the two new session-sync fd guards.

```verdict
verdict: SHIP
confidence: high
```

All five findings from round 1 are fixed. I checked each one against the code and, where a test was claimed, by removing the fix and re-running the tests.

- **BR-1 (secrets in captures):** fixed. The capture now asks `ps` for `comm=`, which gives the program name without its arguments. When I swapped back to `command=`, the integration spec failed and showed the `SECRET-TOKEN` row.
- **BR-2 (README):** fixed in README.md:90-95.
- **BR-3 (flaky spec):** fixed. It passed 8 of 8 runs.
- **BR-4 (once per process):** fixed.
- **BR-5 (duplicated fd counting):** fixed. `M.count` is now public and the specs use it.

The `modes/session_sync` suite passes, including both new #399 fd guards. The work matches the hub rescope recorded in the issue's Revisions (the issue became "detect and capture"). I found nothing new above Minor.

1. **Strengths**
   - `lua/parley/fd_watchdog.lua:19-22`: the capture never reads child arguments in the first place, rather than trying to strip secrets afterwards. That removes the whole class of leak, not just the curl case.
   - The logic is cleanly split. The four decisions (`crossed`, `children`, `report`, `stale`) are pure and unit-tested without any IO. The timer, the two commands and the file writes are a thin layer on top, and `lsof`, `ps` and `notify` can be swapped in for tests.
   - Leftover files are bounded: at most one capture per process, and only the newest five are kept (`KEEP`).
   - The integration spec's stand-in `ps` returns a secret-bearing line whenever it is asked for anything but `comm=`. So the test checks the security property itself, not just the current code.
   - Each test now collects warnings in its own table (`tests/integration/fd_watchdog_spec.lua:17-20`), so a late callback from one test can't land in another's results.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The issue's `## Spec` paragraph (issue:32) still says "fix it at the root". Only the Revisions entry records the rescope, so the paragraph reads stale. This is a plan-text note only.
   - In `M.setup`, the `state.fired` check is redundant for behaviour: `crossed(…, state.fired)` already blocks a second capture. With that check removed, the tests still pass. All it saves is an idle timer, which is fine.
   - Each of the two session-sync guards defines its own `settle` helper. This is acceptable inside a spec file.

5. **Test coverage**
   - The unit tests pin the threshold and once-only rule, the parsing of `ps` rows, the handling of a failed command in the report, and the trimming of old captures.
   - The integration test covers: firing past the threshold, a single warning, the file path, the program name without arguments, keeping five, no re-arming after setup runs again, and staying quiet below the threshold and at 0.
   - The BR-1 fix fails its test when removed. For BR-4, the test fails if `stop()` resets the once-only flag again (that flag is what the test relies on); it does not cover the redundant setup check above.

6. **Architecture**
   - ARCH-DRY: pass; the fd count has one source, `M.count`.
   - ARCH-PURE: pass.
   - ARCH-PURPOSE: pass under the documented hub rescope. Filing the root cause as its own issue waits on the first real capture.
   - ARCH-MOCK: pass. `lsof` and `ps` are injected, and they are one-shot queries, so stand-ins without state are enough. There is no live check that real `ps`/`lsof` output still matches the parser; that is acceptable for a diagnostic.
   - ARCH-CONSTRAINTS: pass. The work is one directory listing a minute, the capture runs in the background, and each command has a 10 s deadline.
   - ARCH-SECURE: pass after BR-1. The `lsof` output contains only file paths.
   - ARCH-ORDER: pass. The state is just `{timer, fired}`, and the shutdown path is explicit.
   - ARCH-FUNERAL: pass. Captures are capped at five on every write, and the timer stops after it fires.
   - ARCH-EVOLVE: pass. The capture file is write-only and the config key is a pure addition.

7. **Plan revisions:** optionally, make the issue's `## Spec` match the 2026-10-19 rescope.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      ps now asked for comm= (fd_watchdog.lua:85); reverting to command= turns the integration spec red with the SECRET-TOKEN row.
  - id: BR-2
    disposition: addressed
    note: |
      README.md:90-95 documents fd_watchdog_threshold, default 200, 0 disables, warn once, state_dir/fd-captures, keep five, no child arguments.
  - id: BR-3
    disposition: addressed
    note: |
      Each test has its own collector, and the re-arm that let a slow real-lsof capture land late is gone (BR-4); 8 of 8 runs green.
  - id: BR-4
    disposition: addressed
    note: |
      stop() no longer resets fired, the timer stops after firing, setup returns early when fired; the re-setup assertion covers it.
  - id: BR-5
    disposition: addressed
    note: |
      M.count is public; session_sync_spec and fd_watchdog_spec use it, no copied /dev/fd loops remain.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: stale-spec-after-rescope
    title: |
      The issue's Spec paragraph still describes the root-cause fix the Revisions entry dropped
    detail: |
      Issue line 32 says to fix every child's stdio at the root; the 2026-10-19 hub rescope made it detect-and-capture. Rewrite the Spec to match.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ec9158f9-18ca-4e2d-ac06-1811435606e7","repository":"github.com/xianxu/parley.nvim","issue_id":"000399","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/371a869578589110","reviewed_head":"637d080c05278db659d095dceb7b58ce5f8d174d","slot":"parley.nvim:3","requested_at":"2026-10-19T15:07:24.015601Z"},"phase":"finished","pid":56590,"started_at":"2026-10-19T15:07:24.240501Z","finished_at":"2026-10-19T15:14:23.763048Z","session_id":"de19bc9c-25e5-4f82-a305-24c942a78042","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T08:35:39-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 399 — fd leak: embedded session-file nvim leaks a unix socket per session-sync reload/lease, hits the 256 limit overnight |
| repo | parley.nvim |
| issue file | workshop/issues/000399-fd-leak-embedded-session-file-nvim-leaks-a-unix-socket-per-session-sync-reload-lease-hits-the-256-limit-overnight.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1d9ab0fda916eb0999224af77259b49060ac2bd5..b1185fee8f6a52188254a6920db9a36871fe4ffe |
| command | sdlc close --issue 399 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T08:35:39-07:00 |
| verdict | SHIP |

## Review

Checking how the specs are run so I can run the changed watchdog spec and the arrival-budget arch check.

Running the watchdog spec through `make test-spec`.

```verdict
verdict: SHIP
confidence: high
```

This fix window has two changes. The first rewrites the issue's `## Spec` so it describes the 2026-10-19 rescope instead of the original root-cause fix. The second makes the watchdog integration spec wait up to the suite's shared arrival budget (`tests/helpers/arrival.lua`, 15 s) instead of a hard-coded 5000 ms. The new Spec only records what `## Revisions` and the revised `## Done when` already say: watchdog plus capture, executable names only, warn once, two fake-backed guards, and the root cause moved to a new issue. So it is not a scope change, and it closes BR-6. `## Done when` and `## Revisions` are unchanged in the window. The test change is a one-line hardening that adds no behavior. Both `infra/fd_watchdog` spec files pass on the pinned head (integration 2/2, unit 4/4), and `tests/arch/arrival_budget_spec.lua` passes. Nothing here blocks shipping.

1. **Strengths**
   - Issue line 33: the Spec now matches the `## Revisions` entry (line 50) and the `## Done when` bullets (lines 37–39). It also says where the original root-cause spec now lives (the follow-up issue), so nothing is silently dropped.
   - `tests/integration/fd_watchdog_spec.lua:45`: the positive wait now uses the shared arrival budget. A passing run costs nothing extra, and machine load can no longer turn into a flake. The 200 ms wait that checks no second warning arrives stays short, which is correct.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none raised against this window. See note 6.

5. **Test coverage notes**
   - I ran `make test-spec SPEC=infra/fd_watchdog` on head b1185fee. Integration: 2 passed, 0 failed. Unit: 4 passed, 0 failed.
   - I ran `tests/arch/arrival_budget_spec.lua` with the make test environment: PASS.
   - The orphan check was skipped because `ps` isn't available in this environment.

6. **Architectural notes**
   - ARCH-DRY: pass. The wait reuses the single arrival-budget helper instead of a literal.
   - ARCH-PURE: pass. The change is test-only and moves no logic.
   - ARCH-PURPOSE: pass. BR-6's class (a Spec left stale after a rescope) has one site in this issue, and the rewrite covers the whole paragraph, not just a phrase.
   - ARCH-EVOLVE: not applicable. No persisted format changes.
   - One observation outside this window, for later: the arrival-budget arch scanner never sees line 45. Its pattern `vim%.wait%(%s*([^,%)]+)%s*,` stops at the `)` in `require("tests.helpers.arrival").MS`, so any wait written with an inline `require(...)` is invisible to the guard. That is the very form the guard's own failure message recommends. The line itself is correct; it is just unchecked. A future change could make the scanner tolerate one level of parentheses, or the suite could prefer a local `arrival` binding.

7. **Plan revision recommendations:** none. The Spec, Revisions, Done when and Plan now agree with each other and with the code.

```findings
dispose:
  - id: BR-6
    disposition: addressed
    note: |
      Issue line 33 now states the detect-and-capture rescope (watchdog past 200, executable names only, warn once, two fake guards, root cause to a new issue), consistent with Revisions line 50 and Done when lines 37-39; Done when and Revisions unchanged, so this records the fix rather than changing scope.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"818844b1-8184-42a3-a4e5-1297b8878893","repository":"github.com/xianxu/parley.nvim","issue_id":"000399","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/331a21d8d28f37cf","reviewed_head":"b1185fee8f6a52188254a6920db9a36871fe4ffe","slot":"parley.nvim:3","requested_at":"2026-10-19T15:33:57.639948Z"},"phase":"finished","pid":41872,"started_at":"2026-10-19T15:33:57.848637Z","finished_at":"2026-10-19T15:35:34.384888Z","session_id":"d127eea4-74c1-477f-9d01-1db8e6958af9","outcome":"returned"}] -->
