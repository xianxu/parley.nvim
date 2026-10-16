# Boundary Review — parley.nvim#348 (whole-issue close)

| field | value |
|-------|-------|
| issue | 348 — starter welcome lock: a second starter can see the lock dir before its owner file and demand repair |
| repo | parley.nvim |
| issue file | workshop/issues/000348-starter-welcome-lock-a-second-starter-can-see-the-lock-dir-before-its-owner-file-and-demand-repair.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0a616029f43d1a239f5a46bb3fc0b42a129dcd9a..030ca6380c1a92b867f409496792a6169d73032b |
| command | sdlc close --issue 348 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T03:13:35-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking the test runner so I can run the starter spec.

Running the starter spec at head, then reverting starter.lua to confirm the new cases go red.

Using the harness to run just the starter spec file.

Most starter cases fail here — checking whether that's environmental (e.g. sandbox) rather than the diff.

The review sandbox puts TMPDIR inside this checkout, which has a `.parley` marker, so the starter runs in project mode. Rerunning with TMPDIR outside the repo.

starter_config passes 21/21; the one error (starter_bootstrap) comes from a sandbox `git init` restriction and is unrelated. Now reverting starter.lua to base to confirm the new cases go red.

Red confirmed: all three cases fail on base, including the original flake. Next, checking whether any test covers the waiter's identity re-check.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix works. Taking the lock now means writing the owner record into a staging directory and renaming it into place. Retiring the lock means renaming it away and then deleting it. So a waiter can no longer see a bare lock directory in either of the two windows. I checked this at the pinned head: `tests/integration/starter_config_spec.lua` passes 21/21. I then put back the base version of `lua/parley/starter.lua`, and three cases went red, all with "requires repair" at `starter.lua:102`: both new gate cases, and the case from the original flake, "waits for another welcome creator…". So the issue's flake is reproduced and fixed.

One thing needs fixing before the boundary. The waiter's lock-identity re-check, added during self-review, has no test that fails without it. That is a behavior change with no regression evidence, which is cheap to fix. The rest are minor wording and edge-case notes.

**Environment notes.** The review sandbox's TMPDIR sits inside this checkout, which has a `.parley` marker. That puts the starter in project mode and every run fails with "chat_dir escaped profile". I reran with TMPDIR under /tmp. `starter_bootstrap_spec` also errors because the sandbox refuses `git init` outside the reviewer's directories (sdlc #339). This diff doesn't touch that file, so both problems are environmental.

1. **Strengths**
   - `lua/parley/starter.lua:101-117`: `take_lock` and `retire_lock` close both windows with atomic renames instead of trying to shrink them. A loser's rename fails on a lock that isn't empty, so nothing needs to retry or sleep.
   - The new gate hooks (`tests/packaging/starter_launch.lua:27-56`) are deterministic. Both new cases fail on the old code and pass on the new code; I confirmed this by reverting.
   - The repair paths still raise and are still tested: dead owner (`starter_config_spec.lua:208`) and an owner record that is missing or malformed (`:225`). That covers both halves of Done-when clause 2.
   - The atlas recovery note says what a crash can leave behind (`.new-*`, `.retired-*`) and that these are safe to remove.

2. **Critical:** none.

3. **Important**
   - `lua/parley/starter.lua:127-131`: the inode/device "same lock" re-check has no test. I changed `same and (…)` to `stat and (…)`, which keeps the retry when the lock is absent but drops the identity check. All 21 cases still passed. The case it protects is an owner retiring the lock, or a new owner replacing it, between the waiter's `fs_lstat(lock)` and its read of `owner`. No test reaches that case: under the new code the RETIRE gate fires only after the lock has already been renamed away.
     - **Fix sketch:** add a waiter-side gate, for example a hook on the waiter's `io.open` of `welcome-initializer/owner` that pauses after the first `lstat`. Release the owner during that pause, then assert the waiter exits 0.
     - **Same class in this window:** this is the only behavior with no test that fails without it. The absent-lock retry is covered by the existing waits test, which goes red if the `not stat` → repair condition is restored.

4. **Minor**
   - **Test names describe the old failure mode** (`starter_config_spec.lua:200` and `:204`). Under the new code the OWNER gate pauses before the staging rename, so the second starter takes the lock itself and doesn't wait. The RETIRE gate fires after the lock has been renamed away. The names should say what is now checked: "a second starter never sees a lock without its owner record", during take and during retire.
   - **Docs don't match the code on empty locks.** `atlas/infra/starter.md:168` says "A lock with no valid owner is therefore garbage". But an empty lock directory gets silently replaced by rename, as the code comment at `starter.lua:99-100` says. Neither the atlas nor the comment notes the side effect: an older starter caught between its `mkdir` and its owner write could have its lock replaced, and both would proceed. It's an unlikely mixed-version case, but neither place mentions it and no test covers the takeover.
   - **A failed owner write leaves staging behind.** If `writefile` fails in `take_lock` (`starter.lua:103`), the `.new-*` directory stays. That fits the atlas note on leftovers, but it isn't only a crash case.

5. **Test coverage notes:** the reverts above confirm red for the three lock-race cases. The identity re-check is the one gap. The other starter specs passed in this environment except the sandbox-blocked bootstrap spec. I didn't re-run the "loaded full suite" clause; the implementer's log reports 6 concurrent runs at 21/21.

6. **Architectural notes**
   - **ARCH-DRY: pass.** Staging plus rename matches the existing publication idiom (`migrate_auth`, tutorial staging) without copying it.
   - **ARCH-PURE: pass.** Lock code is IO by nature. The garbage check is a small inline expression that was already there and stays readable.
   - **ARCH-PURPOSE: pass.** Both windows are closed, not just the one that failed. All Done-when clauses are delivered, and the repair paths still raise.

7. **Plan revision recommendations:** none. The Core concepts table matches the code (`take_lock` and `retire_lock` exist as described).

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: behavior-change-without-red-test
    title: |
      Waiter lock-identity re-check (ino/dev) has no test that fails without it
    detail: |
      With the check changed from `same and (...)` to `stat and (...)` at lua/parley/starter.lua:131, all 21 starter_config cases still pass. The case it protects (an owner retires or replaces the lock between the waiter's lstat and its owner read) is never reached: under the new code the RETIRE gate fires only after the lock is renamed away. Add a waiter-side gate, e.g. a hook on the waiter's io.open of welcome-initializer/owner that pauses after the first lstat, release the owner meanwhile, and assert the waiter exits 0. This is the only behavior in the window without red-test evidence.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-drift
    title: |
      Gate test names and the atlas garbage-lock claim describe the old model
    detail: |
      starter_config_spec.lua:200 and :204 say the waiter waits for an owner mid-take or mid-retire, but under the new code neither gate leaves a lock visible: the second starter takes the lock itself, or the lock is already gone. atlas/infra/starter.md:168 says a lock with no valid owner is garbage, but an empty lock is silently replaced by rename (starter.lua:99-100). Neither place notes that an older starter caught between mkdir and its owner write could be replaced, after which both proceed.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e1083162-f294-401e-8801-4f59d7f79821","repository":"github.com/xianxu/parley.nvim","issue_id":"000348","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/805e2331b8f9fa23","reviewed_head":"030ca6380c1a92b867f409496792a6169d73032b","slot":"parley.nvim:3","requested_at":"2026-10-16T10:07:00.431694Z"},"phase":"finished","pid":47367,"started_at":"2026-10-16T10:07:00.661537Z","finished_at":"2026-10-16T10:13:34.027571Z","session_id":"1d73f8dd-7324-47c5-8ead-a8cece219e8e","outcome":"returned"}] -->
