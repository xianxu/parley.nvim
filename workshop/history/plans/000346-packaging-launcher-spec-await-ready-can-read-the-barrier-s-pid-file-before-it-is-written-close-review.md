# Boundary Review — parley.nvim#346 (whole-issue close)

| field | value |
|-------|-------|
| issue | 346 — packaging_launcher_spec: await_ready can read the barrier's pid file before it is written |
| repo | parley.nvim |
| issue file | workshop/issues/000346-packaging-launcher-spec-await-ready-can-read-the-barrier-s-pid-file-before-it-is-written.md |
| boundary | whole-issue close |
| milestone | — |
| window | 96d8a99f336f3a79c74df98cdd98f9ff927a67b7..c22db1af4f86c379beb39948aa8eeb2f1e46c3e0 |
| command | sdlc close --issue 346 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T02:00:03-07:00 |
| verdict | SHIP |

## Review

Running the spec at head now (the `timeout` command isn't available, so trying again without it).

Running the launcher spec through the test harness to confirm the new test passes at head and fails without the fix.

Green at head. Now reverting `await_ready` to the old version to confirm the new test fails without the fix.

```verdict
verdict: SHIP
confidence: high
```

I recommend shipping. The change is one file, test-only: `tests/integration/packaging_launcher_spec.lua`, with 18 lines added and 3 removed. It fixes the race where the test read the barrier's `ready` file before its bytes were written. `await_ready` now polls until it reads a pid it can parse, not just until the file exists. That is the first option the Done-when allows, and the Plan says it chose it. The new regression test passes at head, and I confirmed it fails without the fix. Under the harness (`make test-spec SPEC=infra/packaging`), the launcher spec ran 11 passed, 0 failed, 0 errored. I then put back the old `await_ready` in the disposable checkout and reran: the new case failed at `:78` with "Expected objects to be equal" (got nil), 10 passed and 1 failed. I restored the file afterwards. Nothing blocks shipping. One Minor note follows.

1. **Strengths**
   - The fix is at the reader, the one place that needs it (`packaging_launcher_spec.lua:59-67`). It waits for the actual record, a parsed pid, so all 4 callers of `await_ready` benefit. The barrier itself is unchanged.
   - `tonumber(readfile(ready)[1] or '')` handles an empty read: `tonumber('')` gives nil, so the wait keeps polling.
   - The regression test (`:76-83`) reproduces the race exactly: it creates an empty `ready` file, writes the pid 100 ms later, and checks that 4242 comes back. It exercises the real `await_ready`, not a mock.
   - The comments state the reason for the fix accurately and cite #346.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The check only proves the pid parses, not that the line is complete. If a reader caught a partially written line such as `12` of `12345`, it would parse and give the wrong pid. In practice that's very unlikely, because a single small `write()` on a local filesystem is effectively atomic. Two fixes would close it fully: have the barrier write the file atomically (temp file, then rename), or check that the pid is stable across two polls. This is the only instance in the window. I found no other "exists, then read" copy in `tests/`.

5. **Test coverage**
   - Both Done-when clauses are met and verified as described above.
   - The one-shot CI flake itself can't be reproduced on demand. The deterministic empty-file test covers its cause.

6. **Architecture**
   - **ARCH-DRY: pass.** It's a single helper, now used by 4 call sites plus the new test, with no duplicate in the tree.
   - **ARCH-PURE: pass.** This is test glue; there is no business logic to separate out.
   - **ARCH-PURPOSE: pass.** The fix covers every `await_ready` caller, not only the one case that uses the pid.
   - No atlas or README update is needed, since the change adds no user-facing surface.

7. **Plan revisions:** none. The plan matches the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: barrier-record-read-before-complete
    title: |
      await_ready accepts any parseable prefix of the pid line, not a confirmed-complete record
    detail: |
      At tests/integration/packaging_launcher_spec.lua:63, a torn read like "12" of "12345" would parse and return the wrong pid. That is unlikely because a single small write() is effectively atomic on local filesystems. Fix: have the barrier write a temp file and rename it, or require the pid to be the same on two polls. This is the only instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3117e5c5-cdf3-495e-816e-54a6923560cb","repository":"github.com/xianxu/parley.nvim","issue_id":"000346","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ee0779d02f604bdf","reviewed_head":"c22db1af4f86c379beb39948aa8eeb2f1e46c3e0","slot":"parley.nvim:3","requested_at":"2026-10-16T08:49:27.952314Z"},"phase":"finished","pid":58425,"started_at":"2026-10-16T08:49:28.108235Z","finished_at":"2026-10-16T08:53:28.811008Z","session_id":"a5d0fadc-042f-4a98-81a2-14312b5b7ff5","outcome":"returned"},{"version":1,"intent":{"disposable_root":true,"id":"0421706e-dbd4-4e98-909b-8ca3c463cea3","repository":"github.com/xianxu/parley.nvim","issue_id":"000346","recipe":"small-diff-review","round":1,"attempt":2,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/ee0779d02f604bdf","reviewed_head":"c22db1af4f86c379beb39948aa8eeb2f1e46c3e0","slot":"parley.nvim:3","requested_at":"2026-10-16T08:53:43.152556Z"},"phase":"finished","pid":6577,"started_at":"2026-10-16T08:53:43.409728Z","finished_at":"2026-10-16T09:00:00.154047Z","session_id":"0c454ac8-bf37-4a67-847a-c9dde4afb8ee","outcome":"returned"}] -->

## Review preparation and protocol diagnostics

Quoted values are diagnostic data, not review verdicts.
Protocol attempt 1
reason: "missing valid findings block"
output: "Diff reviewed; now trying to run the spec file to confirm the fix and the red-on-revert claim.\n\nStill working on running the spec through the project's isolated test harness.\n\n```verdict\nverdict: SHIP\nconfidence: high\n```\n\nThis is a small, test-only change in `tests/integration/packaging_launcher_spec.lua`, and it fixes the race the issue describes. `await_ready` now keeps polling until the ready file holds a pid it can parse, instead of stopping as soon as the file exists. I checked the \"fails on the old code\" claim myself in this disposable checkout. With the fix, `make test-spec SPEC=infra/packaging` passed every packaging spec, including 11/11 in `packaging_launcher_spec.lua`. Then I put back the old `await_ready` from base `96d8a99f` and kept the new test. The new test failed with expected `(number) 4242` and the other 10 passed. I restored the checkout afterwards: `git status` is clean at `c22db1af`. Both `## Done when` items are met, and nothing blocks shipping.\n\n1. **Strengths**\n   - `tests/integration/packaging_launcher_spec.lua:59-67`: the poll condition is now the value the caller needs (a parsed pid), not a stand-in for it (the file existing). It is safe on an empty file: `readfile` returns `{}`, so `[1] or ''` makes `tonumber('')` return nil and the loop keeps waiting. It also returns the pid it already read rather than reading the file a second time, which would reopen the same race.\n   - `:76-83`: the regression test recreates the bad state without timing luck. It writes an empty file, then writes the pid 100 ms later through `defer_fn`, so the outcome doesn't depend on scheduling. It is red on the old code and green on the new.\n   - The fix is made once, at the reader, so all 4 callers get it (`:134, :150, :163, :174`). That matches the issue's count of \"4 cases, only one uses the pid\".\n\n2. **Critical findings**: none.\n\n3. **Important findings**: none.\n\n4. **Minor findings**: none worth raising. In theory a reader could see a partial write (for example `42` out of `4242`), but `writefile` writes a single short line in one `write()`, so I don't count it as a defect.\n\n5. **Test coverage notes**\n   - The \"empty file, then pid\" case is covered, and the run before it covers \"pid already there\".\n   - The timeout path (no pid within 3 s) is not exercised. It behaves the same as before this change, so that's acceptable.\n\n6. **Architectural notes**\n   - **ARCH-DRY: pass.** There is one `await_ready`, and every caller uses it. No logic is duplicated.\n   - **ARCH-PURE: pass.** This is test scaffolding that does filesystem polling by nature; no business logic was added.\n   - **ARCH-PURPOSE: pass.** The fix covers every `await_ready` caller, not only the one that failed. The barrier writer is left alone on purpose: the Plan says \"the fix is one, at the reader\", and the Done-when allows that choice.\n   - **Docs gate: pass.** The change is test-only and adds nothing user-facing, so no atlas or README update is needed.\n   - **Comment claims: pass.** \"writefile creates the file before its bytes land\" is accurate, since it opens with create and truncate, then writes.\n\n7. **Plan revision recommendations**: none. The plan matches the code.\n\n```findings\n```"

truncated: false
retained-bytes: 0000003477
