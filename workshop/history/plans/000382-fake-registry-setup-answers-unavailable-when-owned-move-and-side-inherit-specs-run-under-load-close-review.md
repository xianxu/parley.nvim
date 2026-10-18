# Boundary Review — parley.nvim#382 (whole-issue close)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6e571cf4a8f0c46687f0329c0c3721f586748742..09ca797618c2e5807a1621f51ebceab46fe5f733 |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T23:13:46-07:00 |
| verdict | SHIP |

## Review

I'm checking the regression test in the review checkout. Next I run it once against the fix and once with the old 2.5 s default put back.

Still verifying the regression test. I'm adding a temporary make target outside the repo so the spec gets the suite's test environment.

Passes at head: 8/8. Now I'm putting the 2.5 s default back to confirm the test fails without the fix.

The regression goes red without the fix, and the checkout is restored. Last, I'm running the two flaky specs at head.

```verdict
verdict: SHIP
confidence: high
```

The fix is at the cause, and both halves of `## Done when` hold up when checked against the code. The registry's hidden 2.5 s fallback (`document_registry.lua:84` at base) is gone. A request that names no deadline now gets `agentic_submit_timeout_ms` through `registry.config_ms`. The two flaky specs now report `code`/`error` when setup is refused.

I tested the regression evidence directly. At head, `document_registry_spec` passes 8/8. With the `2500` literal put back, it fails on exactly the new case ("gives a request that names no deadline the configured submit deadline"); after that run I restored the checkout. `owned_move_spec` (43/43) and `side_inherit_spec` (9/9) both pass at head.

I did not re-run the loaded 6-round reproduction or the full suite; those results come from the issue Log. Two Minor notes remain about which deadline each rename path gets and what the atlas claims; neither blocks shipping.

1. **Strengths**
   - **Fixed at the cause.** The cause was a missed default deadline, not shared state. The Log rules out the shared-state theories one by one, and the change removes the literal (`lua/parley/document_registry.lua:84`) instead of raising a timeout in the tests.
   - **ARCH-DRY: one copy of `config_ms`.** It moved into `document_registry.lua:14` and `agentic_document.lua:159` reuses it. Two explicit `timeout_ms = config_ms("agentic_submit_timeout_ms")` arguments that restated the new default were dropped (`agentic_document.lua:350`, `:696`).
   - **Real regression test.** `tests/integration/document_registry_spec.lua:52` checks both sides of the deadline: no deadline against a 3 s fake answers, and a configured 1 s deadline fails with "deadline exceeded". It restores config and env inside a `pcall`, and it goes red without the fix (verified).
   - **Better diagnostics.** The setup assertions in both specs now print `code`/`error`, as the Spec asked.
   - **Atlas updated** in the same range (`atlas/modes/session_sync.md:283`).

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - **The two rename paths get different deadlines; the atlas claim goes too far.** `document_move.lua:994` and `:1283` pass `registry_options`, which nothing sets, so their journaled renames now get 1× the submit deadline (15 s). The native rename at `agentic_document.lua:380` still gets 3× (45 s), and the comment there and `tests/helpers/arrival.lua` say "a rename gets three of them". The atlas line "owns the agentic deadlines" is also broader than the code: the 3× rename rule (`agentic_document.lua:380`) and the `ms + 1000` saveas margin (`:618`) still live in `agentic_document`. The comment at `config.lua:500` ("a move's rename uses the same deadline") is now right for `document_move` but wrong for the 3× native rename. Fix sketch: either give `document_registry` a `rename_deadline_ms()` used by both rename paths, or reword the atlas to say it owns the *default* deadline.

5. **Test coverage notes**
   - The new case covers both the default and the configured-override modes of the clause.
   - Each `lookup` in the new case takes up to 3 s, inside `arrival.MS` of 15 s.
   - No test checks that `document_move`'s journaled rename actually inherits the default. It does so only through the unset `registry_options`, so it is covered indirectly by the `request` default.

6. **Architecture notes**
   - **ARCH-DRY: pass.** `config_ms` is consolidated, and I found no duplicated block in the window.
   - **ARCH-PURE: pass.** The change is a deadline lookup in the existing IO shell. `config_ms` reads module config, which fits this thin seam.
   - **ARCH-PURPOSE: pass.** I enumerated every `registry.request` caller (`agentic_document.lua:341`, `:378`, `:618`, `:682`; `document_move.lua:994`, `:1283`). Each one now either names its own deadline or gets the default from the single source. No `2500` fallback remains in the registry path. The 2500 in `document_lease.lua:24` is a local sha256 subprocess, not a registry deadline, so it is out of scope. The only leftover, the different rename deadlines, is noted as Minor above.

7. **Plan revision recommendations:** none required. Optionally, add a Revisions note if the rename-deadline choice (1× for journaled renames vs 3× for native ones) is intentional.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: deadline-single-owner
    title: |
      Journaled document_move renames get 1x submit deadline while the native rename gets 3x; atlas says registry owns all agentic deadlines
    detail: |
      Family instances in this window: document_move.lua:994 and :1283 (no registry_options, so 15 s default) vs agentic_document.lua:380 (3x config_ms, 45 s, rule kept locally) and agentic_document.lua:618 (ms + 1000 margin kept locally). atlas/modes/session_sync.md:283 says document_registry owns the agentic deadlines; config.lua:500 and tests/helpers/arrival.lua describe a rename as getting three deadlines. Either derive both rename paths from one registry rename deadline helper, or narrow the atlas to say it owns the default deadline.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d387f071-c04f-4f43-a8ed-5bcccd9a5cd5","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/329bdd0a4d33e763","reviewed_head":"09ca797618c2e5807a1621f51ebceab46fe5f733","slot":"parley.nvim:4","requested_at":"2026-10-18T06:11:06.171933Z"},"phase":"finished","pid":55361,"started_at":"2026-10-18T06:11:06.27156Z","finished_at":"2026-10-18T06:13:45.624522Z","session_id":"ee85d8e9-5e16-4db9-b5f1-f0d7eba939ec","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T23:17:00-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | ed9ee0df88ad3b2b8488369e67ad99fca2e42a5b..036cae07964a017a0491d22147a6c9fc8a1696bc |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T23:17:00-07:00 |
| verdict | SHIP |

## Review

Checking how this repo runs its test suite, so I can run the registry spec at head.

Spec passes 9/9. Now checking whether the new test would catch the timer wiring being reverted.

```verdict
verdict: SHIP
confidence: high
```

BR-1 is fixed for the whole class, not just the sites it named. `document_registry.default_deadline_ms(operation)` (`lua/parley/document_registry.lua:26`) is now the one place the rename rule lives: three submit deadlines for a rename, one for anything else. `request()` uses it whenever the caller names no deadline (`:95`). The native rename at `agentic_document.lua:378` stopped passing its own `3 * config_ms(...)`. The two journaled renames in `document_move.lua` (lines 994 and 1284) pass `registry_options`, which nothing sets, so they now get the same 3× deadline. The atlas and the `config.lua` comment now describe what the code does, and they name the inline `:saveas!` check (`agentic_document.lua:618`, `ms + 1000`) as the one call that sets its own deadline. I ran `document_registry_spec` at head and it passes 9/9. I then put the timer back to `config_ms("agentic_submit_timeout_ms")` and it still passed 9/9 (I restored the checkout afterwards). So the new test checks the helper's arithmetic but not that `request()` uses it. That gap is Minor and doesn't block. The window doesn't change `## Spec`, `## Revisions` or `## Done when`, and it has no conflict resolutions.

1. **Strengths**
   - **Fixed for the class.** Every `registry.request` caller now either names its own deadline (only `agentic_document.lua:618`, the inline saveas) or gets it from `default_deadline_ms`: `agentic_document.lua:341`, `:378`, `:682` and `document_move.lua:994`, `:1284`. No caller keeps its own 3× rule.
   - **The atlas claim is now accurate.** `atlas/modes/session_sync.md:283-287` says the registry owns the *default* deadline and names the one exception.
   - **The helper is pure.** `default_deadline_ms` is a small deterministic function, and the new test checks it for all four operations without starting a process.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - **The new test doesn't check that `request()` uses the helper.** At `tests/integration/document_registry_spec.lua:73`, reverting `document_registry.lua:95` to the flat submit deadline stays green (verified). If that happened, every rename would quietly drop back to 1×. Fix sketch: assert the timer value through `request()` itself. For example, set a short submit deadline, run a `rename` against a fake that's slower than 1× but faster than 3×, and assert it isn't `unavailable`.
   - **Config restore isn't protected.** The new test (`:76-79`) resets `config.agentic_submit_timeout_ms` without a `pcall`, unlike the test just above it. If the helper throws, the 2000 ms value leaks into later tests.

5. **Test coverage notes:** At head, `document_registry_spec` passes 9/9. The helper's arithmetic is covered. Nothing checks that `request()` actually calls the helper, and no test checks the rename deadline from a `document_move` journaled rename end to end.

6. **Architecture (interdiff only)**
   - **ARCH-DRY: pass.** The 3× rule now exists once, in `document_registry.lua:28`, and the copy in `agentic_document` is gone.
   - **ARCH-PURE: pass.** The helper is pure apart from reading config through `config_ms`, which fits this thin seam.
   - **ARCH-PURPOSE: pass.** I swept all six callers (listed above). Each one gets its deadline from the registry or is the documented saveas exception.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      document_registry.default_deadline_ms (3x for rename) now covers the native rename (agentic_document.lua:378) and both journaled renames (document_move.lua:994, :1284); the atlas and config.lua describe it accurately; spec 9/9 at head.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: regression-test-pins-wiring
    title: |
      The default_deadline_ms test stays green when request() stops using the helper
    detail: |
      I reverted document_registry.lua:95 to config_ms("agentic_submit_timeout_ms") and document_registry_spec still passed 9/9, because the new test only checks the helper's arithmetic. Add a request()-level check, such as a rename against a fake slower than 1x but faster than 3x of a short submit deadline, and restore config inside a pcall.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3cd6c706-b875-41c1-9b5d-ac8454cc5e58","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"fix-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4412e6b24f2344d9","reviewed_head":"036cae07964a017a0491d22147a6c9fc8a1696bc","slot":"parley.nvim:4","requested_at":"2026-10-18T06:15:48.398081Z"},"phase":"finished","pid":46814,"started_at":"2026-10-18T06:15:48.493189Z","finished_at":"2026-10-18T06:16:59.847216Z","session_id":"2a56fec3-2cc5-49dc-aea3-c4d8a004159e","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T23:20:01-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | de57aa2d8452c4c7b6f0592b70fc6b5ba5356266..50cb93e46dc57bc449d2667e192049344968b039 |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T23:20:01-07:00 |
| verdict | SHIP |

## Review

Looking for where the fake registry handles its delay variable, then I'll run the spec and a revert check.

Still finding how the repo runs a single spec; once found I'll run it at head and with the wiring reverted.

No output from the grep; rerunning to see the raw output.

```verdict
verdict: SHIP
confidence: high
```

BR-2 is fixed. Everything this window adds to the test file is in `tests/integration/document_registry_spec.lua:73-95`. The test now sends a real `request("rename", …)` with the submit deadline set to 1000 ms. The fake holds only `rename` replies, for 2 s. That is past one deadline (1 s) and inside three (3 s). The test asserts the rename still comes back `registered`. The config change, the arithmetic assert and the request all run inside a `pcall`. Config and the three fake-delay variables are restored before the result is asserted. I ran the spec at head and all 9 tests pass. I then changed `lua/parley/document_registry.lua:95` back to `config_ms("agentic_submit_timeout_ms")`. The spec went red (8 passed, 1 failed), and the failure was this test. I restored the checkout afterwards. The fake does support `FAKE_COUCH_REGISTRY_DELAY_OPS` (`tests/fixtures/fake_couch_registry.py:84-88`). The other two files in the window are generated gate and review ledgers. They don't change `## Spec`, `## Revisions` or `## Done when`, and the window resolves no conflicts.

1. **Strengths**
   - **The test now checks that `request()` uses the helper, not only the helper's arithmetic.** Removing the wiring turns it red (verified above).
   - **Setup and cleanup are safe.** The file is registered before config changes, so setup uses the normal deadline. The `pcall` plus restore stops a failure from leaking the 1000 ms deadline or the delay variables into later tests. This also fixes the cleanup gap the earlier round mentioned.
   - **The timing margins are reasonable.** 2 s sits 1 s away from both edges, so the test isn't fragile under load.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none.

5. **Test coverage notes:** `document_registry_spec` passes 9/9 at head. Reverting the timer wiring fails exactly the new test, so the regression the finding described is now caught.

6. **Architecture (interdiff only)**
   - **ARCH-DRY: pass.** The new code is test-only. It uses the same save/`pcall`/restore pattern as the test just above it.
   - **ARCH-PURE: pass.** The production code doesn't change.
   - **ARCH-PURPOSE: pass.** The finding asked for a test that checks `request()` uses the helper, and the test now does. The family `regression-test-pins-wiring` gets no new instance.

7. **Plan revision recommendations:** none.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      The spec now sends a rename through request() with a 1000 ms submit deadline against a fake that holds renames 2 s, all inside a pcall that restores config and env. 9/9 at head; reverting document_registry.lua:95 to config_ms(...) fails that test (8/1), verified and restored.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"431461a9-4dc4-4b2c-a610-485c749b09a7","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/45242f9a35f2e5b1","reviewed_head":"50cb93e46dc57bc449d2667e192049344968b039","slot":"parley.nvim:4","requested_at":"2026-10-18T06:18:03.983788Z"},"phase":"finished","pid":62956,"started_at":"2026-10-18T06:18:04.079916Z","finished_at":"2026-10-18T06:19:49.015207Z","session_id":"8f9f7110-b412-4a19-9b16-88838558b5e1","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T00:13:30-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | e506c9b0b68b999a0dbece38acb8134b3966624e..ea4c01a60534f03ad762dc464494ac5b011f2490 |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T00:13:30-07:00 |
| verdict | REWORK |

## Review

Reviewing the post-close interdiff now. The new commits add deadline-from-spawn and a `start_deadline` sweep, which no prior finding asked for. Next I'll run the two new specs to check them.

The test wrapper needs an env root, so I'm setting a temporary one and rerunning the specs.

I'm setting up the isolated HOME/XDG directories the harness expects, then running the three specs.

```verdict
verdict: REWORK
confidence: high
```

**Summary.** This window contains only the post-close commits `daf09f7b`, `d5bc1f90` and `ea4c01a6`, applied on `e506c9b0`. Both prior findings (BR-1, BR-2) were already disposed, and their fixes are still in place at head. The problem is what the window adds: new behavior that no prior finding asked for, which is exactly what rule 4 rules out of a fix review.
- **Registry deadline starts at spawn.** It used to start when the request was queued.
- **New fields on every registry result:** `queued_ms` and `ran_ms`. Refusals also carry `exit` and `stderr`.
- **A new shared helper,** `helper.start_deadline`. It is now used in `oauth.lua`, `tasker.lua` and `agentic_document.lua`, so the change reaches subsystems well beyond what the issue's Spec and Plan cover.

The issue file only gained `## Log` entries; its Plan checklist and Done-when don't describe any of this. The change itself looks sound: I ran the touched specs in an isolated test env and they pass (start_deadline 2/2, document_registry 11/11, arch arrival_budget 2/2). But it needs a full `sdlc close` review, not this narrow one.

1. **Strengths**
   - `lua/parley/document_registry.lua:76-106`: the deadline now matches the module header's promise that the queue and the child's lifetime are bounded separately. A request still waiting in the queue no longer reports "mutation outcome may be unknown" when nothing ran.
   - `lua/parley/helper.lua:10-23`: the stale-loop-clock problem is fixed in one place. The helper takes an injected `runtime`, so tasker's fake runtimes keep working, and `tests/unit/start_deadline_spec.lua` covers that path with and without `update_time`.
   - `tests/helpers/fake_couch.lua:66-75`: one shared `explain()` replaces the two `vim.inspect` messages that each spec built by hand.
   - The "says why a request was refused" test pins real refusal data: `exit` 2, the fake's stderr text, and the deadline length in the error message.

2. **Critical:** none.

3. **Important**
   - **Scope changed after close; run a full `sdlc close`.** No prior finding asked for the deadline-from-spawn change, the result-diagnostics fields, or the `start_deadline` sweep across `oauth.lua:1136`, `tasker.lua:249/595` and `agentic_document.lua:319`. Per rule 4, this review doesn't cover it. Also update the issue's `## Plan` / `## Revisions` to record the added scope (see section 7).

4. **Minor**
   - **The sweep doesn't reach every deadline it claims to (ARCH-PURPOSE).** The Log says every deadline whose expiry declares a failure now uses `start_deadline`. But `lua/parley/cliproxy.lua:2393-2395` still sets its update-restart deadline with `vim.defer_fn`, which declares `{timeout = true}` and skips the clock refresh. Either route it through the helper or list it under the exclusions.
   - **A queued request now has no deadline.** It is held back only by the four running children's own deadlines and by `MAX_QUEUE`. That's acceptable today, because `bounded_request` cancels when its wait expires, but the atlas sentence should say so.

5. **Test coverage**
   - The Log says each new behavior has a mutation check: counting queue time fails the queued test, and removing `update_time` fails `start_deadline_spec`. I didn't re-run those mutations; the full close review should.
   - The changes to oauth and tasker have no new test of their own. Each is just a call-site swap to the helper, and the existing suites passed according to the Log; I didn't re-run those suites here.

6. **Architecture**
   - **ARCH-DRY: pass.** There is one helper and one `explain()`.
   - **ARCH-PURE: pass.** The helper is a thin IO shim with an injected runtime, and the duration arithmetic is trivial.
   - **ARCH-PURPOSE: flag (Minor).** The claimed sweep misses the cliproxy deadline above.

7. **Plan revisions**
   - Add a `## Revisions` entry that records the scope added after close: deadline-from-spawn, result diagnostics, and the `helper.start_deadline` sweep with its stated exclusions.
   - Add matching Plan checklist items, so the full close reviews them against the Spec.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Unchanged at head: document_registry.default_deadline_ms (3x submit for rename) still feeds request() via deadline_ms at document_registry.lua:80.
  - id: BR-2
    disposition: addressed
    note: |
      Unchanged at head; document_registry_spec passes 11/11 in an isolated run, including the request()-wiring rename case.
findings:
  - id: new
    severity: Important
    kind: defect
    family: scope-change-after-close
    title: |
      Scope changed after close — run a full sdlc close
    detail: |
      The post-close commits daf09f7b, d5bc1f90 and ea4c01a6 add behavior that no prior finding (BR-1, BR-2) asked for. The registry deadline now starts at spawn instead of enqueue; results carry new queued_ms/ran_ms/exit/stderr fields; and a new helper.start_deadline is applied in oauth.lua, tasker.lua (reconcile and attempt deadlines) and agentic_document.lua. The issue's Plan and Done-when don't record this; only Log entries were added. The narrow fix review cannot cover new cross-subsystem behavior, so it needs a full close review and a Revisions entry.
  - id: new
    severity: Minor
    kind: defect
    family: deadline-clock-refresh-sweep
    title: |
      cliproxy update-restart deadline is not routed through start_deadline despite the "every deadline" claim
    detail: |
      cliproxy.lua:2393-2395 uses vim.defer_fn for a deadline whose expiry declares failure (answer with timeout=true), so it still measures from the loop's cached time. The Log says every such deadline now uses helper.start_deadline and does not list this site as an exclusion. Either route it through the helper or add it to the exclusions.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"467ab042-6dd8-48f8-a14e-ff10ace53127","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"fix-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/6791dba6702d273d","reviewed_head":"ea4c01a60534f03ad762dc464494ac5b011f2490","slot":"parley.nvim:4","requested_at":"2026-10-18T07:11:28.300484Z"},"phase":"finished","pid":35607,"started_at":"2026-10-18T07:11:28.423951Z","finished_at":"2026-10-18T07:13:29.723168Z","session_id":"dfb82984-8e54-4754-9f53-51c9fbc02056","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T00:57:33-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 6e571cf4a8f0c46687f0329c0c3721f586748742..af3d2f438ae2de062bcbb6fdb34b13c918450009 |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T00:57:33-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

The test-env script has to be run through make, so I'm switching to the Makefile's test target.

The test runner works now. Next I'm running the remaining targeted specs and a quick revert check on `defer_deadline`.

Eight files failed in the full integration run. Most look environmental, but `document_registry_spec` is in this diff, so I'm checking its failure output first.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both open findings are fixed. BR-3's post-close scope now has a `## Revisions` entry covering both changes, and this review covered the whole window. BR-4's cliproxy update-restart deadline now goes through `helper.defer_deadline`. The core fix is sound: requests that name no deadline default to the configured submit deadline (renames get three), a deadline runs from spawn rather than from enqueue, every result carries `queued_ms`/`ran_ms`, and each deadline refreshes the loop clock before it starts. The targeted specs pass, and I confirmed `defer_deadline`'s clock refresh by reverting it: the spec went red, firing after 0 ms. One thing blocks a clean SHIP. The new "says why a request was refused" case asserts `late.ran_ms >= 300` against a 300 ms libuv deadline, and libuv timers only have millisecond precision. Running the spec 30 times under parallel load, it failed once with `ran_ms = 299`. `document_registry_spec` also failed in the first of my two full integration runs. An issue meant to remove a flake under load now ships a new flake under load.

Done-when: current — both post-close changes serve "fix at the cause", and each has a mutation-checked test. But "the full suite passes" is undermined by the flaky boundary assertion below.

**1. Strengths**
- `lua/parley/document_registry.lua:14-29`: one owner for agentic deadlines (`config_ms`, `default_deadline_ms`). `agentic_document` reuses it instead of restating it, which is ARCH-DRY done right.
- `lua/parley/document_registry.lua:207-234`: the deadline timer starts after spawn, and there is an `item.done` guard for a spawn that fails synchronously. `item.cancel` and `finish` still clean up queued items that have no timer.
- `lua/parley/helper.lua:265-284`: `start_deadline` takes an injected runtime (tasker passes `record.runtime`), and `defer_deadline` is a faithful drop-in for `vim.defer_fn`.
- `tests/unit/start_deadline_spec.lua`: the pass threshold is ≥290 ms, not ≥300, so it allows for timer granularity. That is the model the registry spec should follow.
- `agentic_document.bounded_request` (`:615-626`) still bounds wall-clock time and cancels the request on `vim.wait` timeout, so moving the deadline to spawn-time doesn't loosen the inline `:saveas!` check.

**2. Critical findings:** none.

**3. Important findings**
- `tests/integration/document_registry_spec.lua:487` (the line the review spec checks out at runs to 137): `assert.is_true(late.ran_ms >= 300)` sits exactly at the limit.
  - **Why it fails:** libuv decides a timer is due against its millisecond loop clock (`uv_update_time` truncates hrtime). `ran_ms` is a floored hrtime difference taken from *before* the spawn. So a correct 300 ms deadline can show `ran_ms = 299`.
  - **Observed:** 1 of 30 runs at 10× parallel failed with `ran_ms = 299, queued_ms = 0`.
  - **Fix sketch:** state the rule and apply it: an elapsed-time assertion against a libuv deadline allows the timer's millisecond granularity. Use `late.ran_ms >= 290`, matching `start_deadline_spec`.
  - **Other instances of the class in this window:** `start_deadline_spec.lua:20,43` (≥290, already compliant) and `document_registry_spec.lua:466` (`queued_ms >= 300` against 600 ms of queueing, with plenty of margin). Only line 487 sits at the boundary.

**4. Minor findings**
- No test checks that call sites use `defer_deadline` rather than `vim.defer_fn`: cliproxy:2393, dispatcher:855 and agentic_document:214. The helper itself is tested, so I'm not raising this as a finding; it's covered in the next section.

**5. Test coverage notes**
- I ran the targeted specs; all pass:

  | Spec | Passed |
  |---|---|
  | `start_deadline` | 3 |
  | `document_registry` | 11 |
  | `arrival_budget` | 2 |
  | `single_source_sweeps` | 28 |
  | `side_inherit` | 9 |
  | `owned_move` | 43 |
  | `arch_helper` | 9 |

- `make test-unit` is green.
- `make test-integration` has six failures that are environmental and appear in both runs: `scratch_placement`, `file_history`, `open_reference`, `starter_project`, `starter_config` and `zero_config`. The review sandbox puts TMPDIR, HOME and XDG under the checkout, and `scratch_placement` rejects that. `attention_finder` and `document_registry` failed only in the first run. I traced `document_registry`'s failure to the boundary flake above. I did not dig into `attention_finder` beyond seeing it pass on the rerun.
- Mutation check: replacing `defer_deadline`'s `start_deadline` call with a bare `timer:start` makes it fire after 0 ms, so the spec fails. The test pins the behaviour.

**6. Architectural notes**
- **ARCH-DRY: pass.** `config_ms` is consolidated, the 3× rename rule lives in a single function, and `defer_deadline` doesn't duplicate anything already in the tree.
- **ARCH-PURE: pass.** `default_deadline_ms` is a thin read of config, and the timer and clock work sits behind `start_deadline` with an injectable runtime.
- **ARCH-PURPOSE: pass.**
  - I swept every `vim.defer_fn` and `timer:start` in `lua/`. The remaining sites are repeating timers, debounces or highlight clears, or are listed in the exclusions.
  - `attention_store.lua:124` is a lease-retry backoff. Exhausting it declares "store busy", but each retry is re-armed from a fresh loop iteration, so it falls under the stated "only delay work" exclusion.
  - If a future issue wants the sweep enforced rather than enumerated, a call-site arch check would need a way to mark which timers declare failure.

**7. Plan revision recommendations:** none. The Revisions entry matches the code, including the cliproxy site.

```findings
dispose:
  - id: BR-3
    disposition: addressed
    note: |
      A Revisions entry (2026-10-18) records both post-close changes and their exclusions. This round reviewed the full window, base to head, including those changes.
  - id: BR-4
    disposition: addressed
    note: |
      cliproxy.lua:2393 now calls helper.defer_deadline. Reverting defer_deadline's clock refresh fails start_deadline_spec (fired after 0 ms), so the helper the site now uses is pinned.
findings:
  - id: new
    severity: Important
    kind: defect
    family: elapsed-vs-deadline-tolerance
    title: |
      document_registry_spec asserts ran_ms >= 300 for a 300 ms libuv deadline and flakes under load
    detail: |
      The "says why a request was refused" case at document_registry_spec.lua:487 requires late.ran_ms >= 300. libuv checks timer expiry against a millisecond-truncated loop clock, and ran_ms is a floored hrtime difference, so a correct deadline can report 299. Observed in 1 of 30 runs at 10x parallel load (ran_ms = 299, queued_ms = 0), and document_registry_spec also failed in one of two full integration runs. Rule: an elapsed-time assertion against a libuv deadline must allow the timer's millisecond granularity, as start_deadline_spec does with >= 290. Instances in this window: this line (the only one at the boundary); start_deadline_spec.lua:20 and :43 already comply; document_registry_spec.lua:466 has ample margin.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"66f2e43c-b9e4-4a46-a382-8a60aa152044","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"small-diff-review","round":5,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/31c394f525b7619a","reviewed_head":"af3d2f438ae2de062bcbb6fdb34b13c918450009","slot":"parley.nvim:4","requested_at":"2026-10-18T07:44:35.807963Z"},"phase":"finished","pid":1059,"started_at":"2026-10-18T07:44:36.04863Z","finished_at":"2026-10-18T07:57:33.48185Z","session_id":"e669ef9f-af32-4f72-adcf-2cd205d8358a","outcome":"returned"}] -->

---

## Re-review — 2026-10-18T01:00:07-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 382 — Fake-registry setup answers unavailable when owned_move and side_inherit specs run under load |
| repo | parley.nvim |
| issue file | workshop/issues/000382-fake-registry-setup-answers-unavailable-when-owned-move-and-side-inherit-specs-run-under-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 5a419287eb96df8b9f8b9515c4c449793c44ba90..22100e5415f47db4e8f39b8734e254fd4053d3f0 |
| command | sdlc close --issue 382 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-18T01:00:07-07:00 |
| verdict | SHIP |

## Review

Running the changed spec once to confirm it passes at head.

Locating the harness feature key for the spec, then running it.

Reading the harness recipe so I can run just the one changed spec file.

```verdict
verdict: SHIP
confidence: high
```

This window contains one change, the fix for BR-5. The "says why a request was refused" case at `tests/integration/document_registry_spec.lua:137-139` now accepts `ran_ms >= 290` instead of `>= 300`, and a comment explains why: libuv compares timer expiry against a millisecond-truncated clock, and `ran_ms` is floored. That matches the `>= 290` tolerance in `tests/unit/start_deadline_spec.lua:22` and `:45`. The `## Revisions` addition only records the fix and the sweep that went with it. It doesn't touch `## Spec` or `## Done when` and adds no new behavior, so the scope hasn't changed. I ran the spec 3 times in the harness's isolated environment, and all 11 cases passed each time.

Done-when: current — the window changes one test assertion's tolerance and adds a Revisions line recording it. It builds nothing new for `## Done when` to cover.

**Strengths**
- The fix covers the whole class of problem, not just the line the finding named. I checked every elapsed-time assertion this issue added. The two in `start_deadline_spec` already allow 10 ms of slack. The `queued_ms >= 300` check at `document_registry_spec.lua:116` waits behind a 600 ms hold, so it has plenty of margin. The other `>=` elapsed checks in the tree (`image_shrink_spec:300`, `fixture_ready_publish_spec:70`) predate this issue and already have loose bounds.
- The comment next to the assertion gives the reason for the tolerance, so nobody tightens it back to 300 later.
- The tolerance is the same 10 ms that `start_deadline_spec` uses. There is one rule, not two different numbers.

**Critical findings:** none.

**Important findings:** none.

**Minor findings:** none.

**Test coverage notes:** This change makes an assertion less strict, so there is no failing-without-it test to demand. The evidence is the timing argument plus the fact that a correct 299 ms run now passes. A 290 ms floor still catches the real regression, a deadline firing early from a stale loop clock: the Revisions measured that firing at about 6 ms, which is far below 290. Three passing runs here.

**Architecture:**
- ARCH-DRY: pass. One assertion changed, and its tolerance matches the existing 290 used in `start_deadline_spec`.
- ARCH-PURE: pass. The window only touches a test.
- ARCH-PURPOSE: pass. BR-5's class (elapsed-time assertions against libuv deadlines) was checked across every assertion this issue added, not just the one named.

**Plan revision recommendations:** none. The added Revisions entry already describes the fix accurately.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      document_registry_spec.lua:139 now asserts ran_ms >= 290 with the reason stated, matching start_deadline_spec. The sweep checked: line 116 has about 600 ms of margin. Spec passed 11/11 on 3 runs.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d768cbb0-eaa6-4ed8-a81c-57c56da95ab2","repository":"github.com/xianxu/parley.nvim","issue_id":"000382","recipe":"fix-review","round":6,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/afdc4f759a3779b2","reviewed_head":"22100e5415f47db4e8f39b8734e254fd4053d3f0","slot":"parley.nvim:4","requested_at":"2026-10-18T07:58:31.729744Z"},"phase":"finished","pid":4770,"started_at":"2026-10-18T07:58:31.822589Z","finished_at":"2026-10-18T08:00:06.991802Z","session_id":"3d424228-e283-4f7e-90eb-55861b241fd8","outcome":"returned"}] -->
