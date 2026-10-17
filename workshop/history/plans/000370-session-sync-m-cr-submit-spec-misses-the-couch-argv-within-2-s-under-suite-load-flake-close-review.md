# Boundary Review — parley.nvim#370 (whole-issue close)

| field | value |
|-------|-------|
| issue | 370 — session_sync M-CR submit spec misses the couch argv within 2 s under suite load (flake) |
| repo | parley.nvim |
| issue file | workshop/issues/000370-session-sync-m-cr-submit-spec-misses-the-couch-argv-within-2-s-under-suite-load-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | d104447797a74f52477481a8d2b5ddd6d7a6091d..d0d574ff658a3cf5a0f513957cd91564857f72dd |
| command | sdlc close --issue 370 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T02:57:50-07:00 |
| verdict | SHIP |

## Review

Checking the test runner so I can run the focused spec and confirm the regression goes red without the fix.

No `timeout` on this host, so I'm running the focused spec without it.

The focused spec passes at head. Now I'm setting the bound back to 2000 to check that the regression goes red.

```verdict
verdict: SHIP
confidence: high
```

This change fixes the flake where it starts: the spec guessed a timing bound. A new local `arrival_ms()` in `tests/integration/session_sync_spec.lua:16-18` reads the submit deadline from config (`agentic_submit_timeout_ms`, 15000 by default) and now bounds every positive wait in the spec. A new test, "<M-CR> waits out a slow couch send", gives the fake couch send a 2.5 s delay. I checked the main claims in this checkout. The focused spec passes at head (`PASS: tests/integration/session_sync_spec.lua (24s)`). With `arrival_ms()` forced back to `return 2000`, only the new test fails (`Success: 63, Failed: 1`, "<M-CR> waits out a slow couch send"). I put the file back afterwards and the checkout is clean. The plan's count is correct: 34 `arrival_ms()` sites, which are 33 former 2 s waits plus the 3 s registry lookup. Every absence check still uses its short fixed wait (`vim.wait(200|300|50|100)`). Nothing blocks shipping. The findings below are Minor.

**1. Strengths**
- The regression test fails without the fix, and I confirmed that by reverting it. It reproduces the real failure: `FAKE_COUCH_SLEEP` delays the send before the argv and log are written (`tests/helpers/fake_couch.lua`, the `sleep` line). `before_each` already saves and clears that variable (`session_sync_spec.lua:96,105`), so the delay can't leak into later tests.
- Positive waits and absence checks are handled differently, and correctly. A long bound costs nothing when a wait passes. The absence checks keep short bounds because their bound is what the test costs.
- The diagnosis rests on a trace, not on guessing. The issue's Plan rules out queue ordering with timestamped argv logs. The new entry in `workshop/lessons.md` records the general rule.
- `arrival_ms()` falls back to the shipped default when setup sets nothing, the same order the product's `config_ms` uses (`lua/parley/agentic_document.lua:105-109`).

**2. Critical findings:** none.

**3. Important findings:** none.

**4. Minor findings**
- **ARCH-DRY:** `arrival_ms()` (`session_sync_spec.lua:16-18`) copies the fallback in `agentic_document.lua:105-109`, but loosely. The product rejects a value that is not a number or is ≤ 0; the spec's `or` chain does not. If a test set the key to 0 or a string, the spec would wait 0 ms while the product used 15000. There is only this one copy in the window. Fix: copy the `type(value) == "number" and value > 0` guard, or expose `config_ms` and call it.
- **Comment wording:** the comment at `session_sync_spec.lua:12-15` calls the bound "the submit's own deadline for a Couch round-trip". About 20 of the 34 sites involve no Couch round-trip. They wait on file-watch reloads, `.clobbered` files appearing, the winbar band, and the ping loop (for example lines 303, 337, 355, 384, 448, 477, 487, 539, 573, 610, 622, 636, 645, 689, 700, 755–899). The Plan chose to use one bound everywhere, which is fine. The comment should say it is a generous bound borrowed from the submit deadline, not that it is the deadline for those paths.
- **Done when not evidenced:** the clause "the focused spec and the full suite pass" covers two runs. The issue only records the focused run (64/64). Record a full-suite result before closing. I did not run the full suite here.

**5. Test coverage notes**
- The fixed path is covered and goes red without the fix (verified).
- The new test sits beside the existing #315 test at line 213 and shares its fixture. It asserts the lock is released straight away even while the send is slow (`assert.is_false(exists(file .. ".lock"))` right after the key). That pins the asynchronous submit as well as the wait.

**6. Architectural notes for upcoming work**
- **ARCH-PURE:** pass. The change only touches tests; no product logic changed.
- **ARCH-DRY:** flagged as Minor above.
- **ARCH-PURPOSE:** pass. The issue's purpose is this one flake in this spec, and every positive wait in the file now uses the bound. The issue log names 19 other spec files with `assert.is_true(vim.wait(2000, ...))` for a separate issue. That is a genuinely separable task (other files, possibly not waiting on a process), not a deferral of this issue's point. Whoever files it should reuse a shared helper, for example a `tests/helpers/` function that wraps `config_ms`, rather than copying `arrival_ms()` 19 times.
- **Docs gate:** not applicable. The change touches only tests and `lessons.md`, with no new user-facing or architectural surface, so no atlas or README update is needed.

**7. Plan revision recommendations:** none. The plan's checklist matches the code: one bound, 33+1 sites, absence checks unchanged, a regression test that goes red on 2000.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: restated-config-fallback
    title: |
      arrival_ms() copies agentic_document config_ms fallback without its number/positive guard
    detail: |
      tests/integration/session_sync_spec.lua:16-18 copies lua/parley/agentic_document.lua:105-109 but drops the type(value)=="number" and value>0 check. A 0 or non-number config value would make the spec wait 0 ms while the product falls back to 15000. This is the only instance in the window (ARCH-DRY). Fix: copy the guard, or expose config_ms and call it.
  - id: new
    severity: Minor
    kind: defect
    family: comment-claim-overreach
    title: |
      arrival_ms comment calls the bound the Couch round-trip deadline for waits that make no Couch call
    detail: |
      The comment at session_sync_spec.lua:12-15 says the bound is the submit's deadline for a Couch round-trip. About 20 of the 34 sites wait on watcher reloads, .clobbered files, winbar bands or ping ticks (e.g. 303, 337, 355, 384, 448, 477, 487, 539, 573, 610, 622, 636, 645, 689, 700). Reword it as a generous bound borrowed from that deadline.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-clause-unevidenced
    title: |
      Done-when requires the full suite to pass, but the issue records only the focused run
    detail: |
      Done when says "the focused spec and the full suite pass". The Plan checklist and Log record only the focused 64/64 run. Record a full-suite result before closing. This review ran only the focused spec, which passed, and the revert check.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"1fda3208-c291-4e15-a620-48b03e1ffedd","repository":"github.com/xianxu/parley.nvim","issue_id":"000370","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/f19d23343146ee3c","reviewed_head":"d0d574ff658a3cf5a0f513957cd91564857f72dd","slot":"parley.nvim:3","requested_at":"2026-10-17T09:55:15.47786Z"},"phase":"finished","pid":36846,"started_at":"2026-10-17T09:55:15.673573Z","finished_at":"2026-10-17T09:57:49.346573Z","session_id":"ca2e957f-12f7-4f62-a851-d23dbb1d9ff3","outcome":"returned"}] -->
