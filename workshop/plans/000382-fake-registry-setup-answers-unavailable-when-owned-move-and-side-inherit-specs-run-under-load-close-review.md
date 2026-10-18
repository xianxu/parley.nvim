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
