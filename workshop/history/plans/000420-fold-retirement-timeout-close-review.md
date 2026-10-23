# Boundary Review — parley.nvim#420 (whole-issue close)

| field | value |
|-------|-------|
| issue | 420 — Investigate embedded fold-retirement timeout under native suite load |
| repo | parley.nvim |
| issue file | workshop/issues/000420-fold-retirement-timeout.md |
| boundary | whole-issue close |
| milestone | — |
| window | 274c08d54b10ddc7a932168710641abf0bcfa014..38ebb2a8e6629fa6a50c42c9c3a9fdeccba70a31 |
| command | sdlc close --issue 420 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T09:58:40-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The change satisfies the revised diagnostics scope. Both fixtures preserve their single RPC, retirement operations, deadlines, and original assertions. Independent tests passed on both supported runtimes. No blocking defects found; the historical timeout remains unresolved under #424.

```findings
{}
```

1. **Strengths**

   - Shared reporter reuses the existing embedded-child and JIT-profile helpers (`tests/helpers/fold_retirement_trace.lua:34`, `:56`).
   - Atomic snapshot replacement preserves completed evidence when the child is killed (`tests/helpers/fold_retirement_trace.lua:64`).
   - Both retirement fixtures retain their original fold preference, idle-state, and viewport assertions.
   - Atlas documentation accurately describes the diagnostics and avoids claiming a root-cause fix.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   Independently ran all three affected spec files through the harness on Neovim 0.12.5 and installed 0.11.7: **7 passed per runtime**, zero failures/errors, clean process censuses. Tests exercise actual child termination, evidence survival and cleanup, unusable snapshots, work counters, and logarithmic writes. Both original retirement cases passed. `git diff --check` passed. No full-suite replay was performed during review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** both fixtures consume one reporter and existing lifecycle/profile owners.
   - **ARCH-PURE — pass:** diagnostic IO stays in the test helper; production business logic is unchanged.
   - **ARCH-PURPOSE — pass:** delivers the explicitly revised evidence-capture scope; #424 retains the unresolved investigation.
   - **ARCH-EVOLVE — pass:** no persisted production format changes; snapshots are temporary diagnostic artifacts.

   Atlas is updated. No new user-facing commands or configuration require a README change.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"9dd36ad8-e0df-4b6a-b23f-a9891c31434c","repository":"github.com/xianxu/parley.nvim","issue_id":"000420","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/18be9b04c698272e","reviewed_head":"38ebb2a8e6629fa6a50c42c9c3a9fdeccba70a31","slot":"parley.nvim:2","requested_at":"2026-10-23T16:56:39.751867Z"},"phase":"finished","pid":46210,"started_at":"2026-10-23T16:56:39.901176Z","finished_at":"2026-10-23T16:58:39.843922Z","session_id":"01a169b1-7654-7d41-8828-517b9b99a9b2","outcome":"returned"}] -->
