# Boundary Review — parley.nvim#360 (whole-issue close)

| field | value |
|-------|-------|
| issue | 360 — Cliproxy catalog joins-routes case intermittently returns empty under suite load |
| repo | parley.nvim |
| issue file | workshop/issues/000360-cliproxy-catalog-suite-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | f7808490a40dfed64017cb6b183e042c80fa8bf0..139ef2b9570dc37907fe167492022c627091c527 |
| command | sdlc close --issue 360 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T01:01:44-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I'm checking whether the new lsof query in the test helper duplicates an existing one in `cliproxy.lua`.

Next I'm running the `ready_port` unit spec directly, then reverting the fix to check that the regression test fails without it.

Unrelated environmental failures (the review checkout sits under the cache path). Now the mutation check:

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

**Summary.** The fix is sound. A TCP simultaneous open can make a probe's connect succeed with nothing listening. The change keeps the connect and then requires `lsof` to show a LISTEN socket on the port, all inside the shared helper. It also removes all four hand-copied connect loops, and a grep confirms no others remain in `tests/`. I reverted the confirm step (`is_listening` returning true after any connect), and "rejects a connect that completed with nothing listening" then failed. With the fix restored, `ready_port_spec` passed in the `infra/test_harness` run. The only failures in that run were 8 in `scratch_placement_spec`, which come from where the review checkout lives, not from this diff. The one thing I'd fix before closing is the time budget. The new `lsof` check is cut off at 2 s inside a 5 s readiness wait, but this repo's own #345 notes measured real `lsof` taking longer than 2 s under the 8-way suite. If that happens again, the readiness wait gives up too early on a fake that is actually up, which is a new flake.

1. **Strengths**
   - `tests/helpers/ready_port.lua:134-143`: `lsof` runs only after a connect succeeds, so polling a port that still refuses costs nothing extra, and the third unit case checks this.
   - `_has_listener` treats a timeout (code 124) and other `lsof` failures as "can't say" (nil), never as "listening". The product's `pids_on_port_async` handles code 124 the same way.
   - The `_connect` seam stages the false positive deterministically instead of trying to win a kernel race. The mutation test confirmed this regression catches the bug.
   - ARCH-DRY sweep: all four copies (`cliproxy_caller_teardown`, `cliproxy_dispatch`, `openai_tool_loop`, `stream_integrity`) now call `wait_listening`. Two of them used to ignore the result of their wait; they now assert it, which is stricter.
   - The atlas (`atlas/infra/test_harness.md:160-167`) documents the rule and points to the regression.

2. **Critical:** none.

3. **Important**
   - **The `lsof` cutoff is shorter than this repo's own measurements** (`tests/helpers/ready_port.lua:100`, `LSOF_TIMEOUT_MS = 2000`, against `wait_listening`'s 5 s default):
     - `cliproxy.lua:35` uses a 10 s `LSOF_GUARD_MS` because #345 found real `lsof` taking longer than 2 s under the 8-way suite (see the comments at `cliproxy_lifecycle_spec.lua:442` and `:595`).
     - Here a timeout means "not listening", so a slow `lsof` uses up most of the readiness budget. Two or three slow answers fail the readiness wait even though the fake is up. The issue log already shows a max wait of 2.08 s under the 12×20 stress run.
     - The same cost hits `cliproxy_catalog_spec.lua:96`. That wait has only 300 ms, and every poll while the port is still up now runs an `lsof`.
     - Fix sketch: give `wait_listening` a budget sized to the `lsof` cutoff (for example a 10 s default, or at least several cutoffs). Alternatively, when `lsof` times out after a connect has already succeeded, retry once before the wait counts it against the budget.

4. **Minor**
   - The "`lsof` absent" path (the connect alone decides) has no test. The "rejects…" case would actually fail on a host without `lsof`, because `is_listening` returns true there. `_has_listener`'s handling of exit codes 124, 1 and other failures is also untested. A stubbed `_has_listener` returning nil, with `lsof` present and absent, would cover the whole family.
   - ARCH-DRY: the `lsof` command line and its output check repeat `cliproxy.lua:954-962` (`lsof_argv` and `parse_listener_pids`). I'd accept this, since a fixture's readiness check shouldn't depend on the code it is testing, but a comment pointing at the twin would help.
   - `tests/unit/ready_port_spec.lua:99-105`: `_has_listener` is put back only when the test passes. `after_each` restores only `_connect`, so a failure would leave the counter wrapper installed for later cases.

5. **Test coverage notes.** The regression is deterministic and fails without the fix (verified). A real-listener case checks the positive path. What's missing is the fallback mode and the exit-code handling (see Minor). The behaviour under suite load relies on the implementor's stress logs, which I did not re-run.

6. **Architecture**
   - ARCH-DRY: pass. The four copies are consolidated; the `lsof` duplication with product code is noted under Minor.
   - ARCH-PURE: pass. The IO sits behind two small replaceable functions (`_connect`, `_has_listener`), and `is_listening` just combines them.
   - ARCH-PURPOSE: pass. The root cause is fixed in the shared helper, every readiness wait gets the fix, and leaving `callback_port_blocked` unchanged is justified in the log.

7. **Plan revisions:** none needed. If the budget is changed, add a `## Revisions` note recording the new `wait_listening` and `lsof` timing.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: probe-cost-exceeds-wait-budget
    title: |
      The 2 s lsof cutoff inside the 5 s wait_listening budget can fail readiness on a fake that is up
    detail: |
      tests/helpers/ready_port.lua:100 cuts lsof off at 2 s and counts a timeout as not listening, but #345 measured real lsof past 2 s under the 8-way suite (cliproxy.lua:35 uses a 10 s guard; see cliproxy_lifecycle_spec.lua:442 and :595). Two or three slow answers use up wait_listening's 5 s default, which is a new false-negative flake. Every site in the family: wait_listening's default at ready_port.lua:150, the 4 rewritten start_fake helpers, and cliproxy_catalog_spec.lua:96 (a 300 ms wait where every poll now runs an lsof while the port is still up). Fix: size the wait budget to the lsof cutoff, or retry an lsof timeout after a successful connect before counting it against the budget.
  - id: new
    severity: Minor
    kind: defect
    family: documented-mode-untested
    title: |
      The lsof-absent fallback and _has_listener's exit-code handling are untested
    detail: |
      The is_listening doc says the connect alone decides when lsof is absent, but no test covers that path, and the rejects case would fail on a host without lsof. Codes 124, 1 and other failures in _has_listener are also unpinned. Stub _has_listener to return nil, with lsof present and absent.
  - id: new
    severity: Minor
    kind: defect
    family: test-seam-restore
    title: |
      The never-runs-lsof case restores _has_listener only when it passes
    detail: |
      tests/unit/ready_port_spec.lua:99-105 restores _has_listener inline, and after_each restores only _connect, so a failure leaves the wrapper installed. Restore both seams in after_each.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"315fc00c-3bd6-4d17-9cdf-0019733e54cc","repository":"github.com/xianxu/parley.nvim","issue_id":"000360","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/bbce154f729b785d","reviewed_head":"139ef2b9570dc37907fe167492022c627091c527","slot":"parley.nvim:4","requested_at":"2026-10-17T07:58:08.194916Z"},"phase":"finished","pid":97771,"started_at":"2026-10-17T07:58:08.30167Z","finished_at":"2026-10-17T08:01:44.194036Z","session_id":"98c87d59-c137-4c32-afa6-b3e450fe4734","outcome":"returned"}] -->
