# Boundary Review — parley.nvim#334 (whole-issue close)

| field | value |
|-------|-------|
| issue | 334 — Leaving a buffer while holding the operator lock flashes the red winbar three times (submit reminder) |
| repo | parley.nvim |
| issue file | workshop/issues/000334-leaving-a-buffer-while-holding-the-operator-lock-flashes-the-red-winbar-three-times-submit-reminder.md |
| boundary | whole-issue close |
| milestone | — |
| window | 800e0d3e0ce074eb79f69c3de246822cfd893cd0..ee73224ecf92563c10999557107616e8795edb09 |
| command | sdlc close --issue 334 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-16T15:39:30-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation satisfies the issue’s reminder behavior and exclusions. The shared renderer preserves current underlying views, and the regression suite exercises cancellation and split isolation. No blocking findings.

Done-when: current — the revisions clarify window targeting and acceptance; the existing criteria still cover the delivered behavior.

```findings
{}
```

1. **Strengths**
   - `session_sync.lua:107` keeps the unsubmitted predicate pure and independent of auto-save state.
   - `session_sync.lua:602` connects both leave events through the shared attachment for registered and legacy documents.
   - `document_band.lua:154` centralizes pulse ownership, cancellation, and restoration.
   - README, atlas, and test traceability updates accompany the behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage:** All 16 mapped session-sync test files passed, including 14 new reminder regressions. Additional native `vnew` and split re-entry probes passed. Process census clean. Repository lint passed with zero warnings/errors across 757 files; diff whitespace check passed. Full suite not rerun during this review.

6. **Architecture**
   - **ARCH-DRY: pass** — reuses baseline tracking, lock reading, and the shared renderer.
   - **ARCH-PURE: pass** — deterministic eligibility predicate tested directly; UI and timer work stays in the integration boundary.
   - **ARCH-PURPOSE: pass** — covers held, free, undone, and auto-saved turns without blocking navigation.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f09b1d07-ceb2-4412-9d59-482e2ec98152","repository":"github.com/xianxu/parley.nvim","issue_id":"000334","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5cad1dba5acbd4c0","reviewed_head":"ee73224ecf92563c10999557107616e8795edb09","slot":"parley.nvim:1","requested_at":"2026-10-16T22:36:47.012969Z"},"phase":"finished","pid":9356,"started_at":"2026-10-16T22:36:47.594212Z","finished_at":"2026-10-16T22:39:28.971371Z","session_id":"01a146dc-5a89-7ca2-86b4-a8da7689e541","outcome":"returned"}] -->
