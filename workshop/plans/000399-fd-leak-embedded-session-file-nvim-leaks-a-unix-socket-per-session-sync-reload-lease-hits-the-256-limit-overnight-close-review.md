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
