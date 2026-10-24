# Boundary Review — parley.nvim#431 (whole-issue close)

| field | value |
|-------|-------|
| issue | 431 — Native release-journal test intermittently loses its setup lock |
| repo | parley.nvim |
| issue file | workshop/issues/000431-native-release-journal-setup-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | a36bab20b568f1832ed9763be3947523b3ffe043..838d439028664564b76a616cc5fcea7df4b0a55e |
| command | sdlc close --issue 431 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-24T02:59:21-07:00 |
| verdict | SHIP |

## Review

The code side checks out. Next I'm confirming whether the flaky cases were actually unregistered, then running the lint and the regression tests.

Trying a single-spec run of the arch lints and couch_spec via `test-spec`.

Specs run; fixing my output filter (colour codes) and running the rest, then a negative control.

Negative control goes red as claimed. Now checking that the lint catches a reverted call site, and running the native spec green and red.

Everything verified on 0.11.7. Last check: running the regressions on the other supported Neovim, if one is installed.

```verdict
verdict: SHIP
confidence: high
```

The window does what #431 set out to do, and I confirmed it by running the tests in this checkout. `helper.system` refreshes libuv's loop clock before calling `vim.system`. All 8 call sites that pass a timeout now go through it, and no raw `vim.system` call with a timeout is left under `lua/`. I reverted the one-line fix (the `update_time()` call) and all five regressions failed: couch_spec #431, lock_leave_reminder #437, native pre-detach #431, native journal after-new/before-restore #431, and native synthetic-move #433. With the fix restored they all pass, on both 0.11.7 and 0.12.5 (native spec 147/0, couch_spec 20/0, lock_leave_reminder 19/0). The new lint fails when `couch.run` and the `remote_process` ps call are switched back to raw `vim.system`. The spawn census stays green at 14/0. Nothing blocks SHIP. The only findings are two Minor blind spots in the new call-form scans.

1. **Strengths**
   - `lua/parley/helper.lua:117-120`: a tiny wrapper that looks up `vim.system` on every call, so specs can still replace it. The couch_spec regression depends on exactly that.
   - The whole class was fixed at once (ARCH-PURPOSE). The lint found two more members of the class, `fd_watchdog` and `image_shrink`, which the plan had not listed.
   - `tests/arch/spawn_seam_spec.lua:225,143-147`: the census was taught the new call form. Without that, the helper would have hidden every spawn from it, and the coverage loss would have been silent. The lesson was also recorded.
   - Each fold got its own causal reproduction. #432 was split back out when its reproduction showed a different outcome, instead of being closed on a shared story.
   - The real-overrun hypothesis was ruled out with measurements (max 49 ms under load against the 500 ms budget) before the existing timeout was kept.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `tests/arch/spawn_seam_spec.lua:225`: the census only matches the inline `require("parley.helper").system(` form. A future `local helper = require("parley.helper"); helper.system(...)` would be invisible to the spawn census. That is the same quiet coverage loss `workshop/lessons.md` warns about. Every current site uses the inline form, so nothing is uncounted today.
   - `tests/arch/deadline_timer_spec.lua:202-203`: the "forwarded options" check needs argv and opts on the same line as `vim.system`. A multi-line `pcall(vim.system,\n argv, opts, cb)` that forwards an options variable carrying a timeout would pass the lint. The spec comment discloses aliases and distant timeouts as blind spots, but not this one.

5. **Test coverage**
   - Every regression blocks the loop for 1200 ms just before the call, so each one reproduces the bug deterministically rather than by luck. The negative control matched what the log claims.
   - The journal variant with the stall runs only at the after-new/before-restore ordering, the one that failed. That matches Done when.
   - Unregistering the flaky cases isn't missing work. Under the substrate's semantics (`README.md:939,994`), `flake_tests` only registers while the issue is open, so closing #431 unregisters them. Closing #433 and #437 also happens at close time.

6. **Architecture**
   - **ARCH-DRY: pass.** There is one helper and no duplicated refresh logic. Spreading `require("parley.helper").system` inline across the sites is deliberate, because the census matches that form.
   - **ARCH-PURE: pass.** The change is a thin IO wrapper and nothing else.
   - **ARCH-PURPOSE: pass.** Every consumer that passes a timeout goes through the helper. I enumerated the remaining raw `vim.system` calls in `lua/` and none of them passes a timeout. The lint enforces this.
   - **ARCH-EVOLVE: pass.** No persisted format changes; only the tracker frontmatter list grows.
   - The atlas is updated in `remote_session.md`, `session_sync.md` and `traceability.yaml`. No new user-facing surface was added, so README needs nothing.

7. **Plan revisions:** none. The plan and Revisions 1–2 match the code.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: call-form-lint-misses-variant-forms
    title: |
      Spawn census and the vim.system-timeout lint each match one literal call form
    detail: |
      There are two instances in this window. First, tests/arch/spawn_seam_spec.lua:225 counts helper spawns only in the inline require("parley.helper").system( form, so a local alias such as helper.system( would hide the spawn from the census. Second, tests/arch/deadline_timer_spec.lua:202-203 detects a forwarded options variable only when argv and opts are on the same line as vim.system, so a multi-line pcall(vim.system, argv, opts, cb) carrying a timeout would pass the lint. No current call site uses either form. Fix sketch: also match a local alias bound to require("parley.helper") followed by .system(, and apply the forwarded-variable regex to the joined window rather than the single line.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d6b7649c-513d-4161-80fd-777ab12218a2","repository":"github.com/xianxu/parley.nvim","issue_id":"000431","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/a7dcd0c9c9a94aec","reviewed_head":"838d439028664564b76a616cc5fcea7df4b0a55e","slot":"parley.nvim:1","requested_at":"2026-10-24T09:53:49.14196Z"},"phase":"finished","pid":85808,"started_at":"2026-10-24T09:53:49.242955Z","finished_at":"2026-10-24T09:59:20.039313Z","session_id":"8f01ef89-8ab6-4d2e-9990-e6188baf195b","outcome":"returned"}] -->
