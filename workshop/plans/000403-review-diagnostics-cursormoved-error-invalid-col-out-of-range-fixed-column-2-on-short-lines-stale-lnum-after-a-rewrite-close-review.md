# Boundary Review — parley.nvim#403 (whole-issue close)

| field | value |
|-------|-------|
| issue | 403 — review diagnostics: CursorMoved error 'Invalid col: out of range' (fixed column 2 on short lines; stale lnum after a rewrite) |
| repo | parley.nvim |
| issue file | workshop/issues/000403-review-diagnostics-cursormoved-error-invalid-col-out-of-range-fixed-column-2-on-short-lines-stale-lnum-after-a-rewrite.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0e4a8f60951d56a9541d7d74761aa998d2d91d25..1326aebbad6b609a856dbd2d127229365024c549 |
| command | sdlc close --issue 403 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-19T22:42:05-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change fixes short-line anchors and stale diagnostic rows, with shared cleanup and retry handling. Regression tests exercise real extmarks and fail against the base renderer. No findings block this review; the recorded full suite and operator acceptance remain separate landing gates.

Done-when: current — the revisions change verification timing; the existing criteria still cover the implemented correction.

```findings
{}
```

1. **Strengths**
   - Column-zero anchors and one buffer-size lookup handle short lines and stale rows without reading every line (`diag_display.lua:233–263`).
   - One shared failure boundary clears partial output, warns once, and allows recovery (`diag_display.lua:272–281`).
   - Atlas behavior documentation and traceability were updated consistently.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Pinned head: **20 passed**, zero failures, on Neovim 0.12.5.
   - Same tests with the base renderer: **five failures**, confirming regression sensitivity.
   - Coverage includes empty, one-byte and multibyte lines; stale rows; CursorMoved; partial cleanup; warning suppression; recovery; and bounded size lookups.
   - `git diff --check` passed; checkout remained unchanged. Full-suite and live acceptance were not independently verified.

6. **Architectural notes**
   - **ARCH-DRY: pass** — all render callers share the correction.
   - **ARCH-PURE: pass** — changes remain in the UI boundary; existing pure text wrapping is reused.
   - **ARCH-PURPOSE: pass** — both invalid-anchor causes and render-error containment are delivered.
   - **ARCH-EVOLVE: pass** — no persisted format changes.
   - No new user-facing command or configuration requires a README update.

7. **Plan revision recommendations:** None. No Core concepts table is claimed; the implementation matches the short plan.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"282dcd5c-fe5b-4cd9-88fd-6acff9bf1433","repository":"github.com/xianxu/parley.nvim","issue_id":"000403","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/b40afea4371176d2","reviewed_head":"1326aebbad6b609a856dbd2d127229365024c549","slot":"parley.nvim:1","requested_at":"2026-10-20T05:40:35.71851Z"},"phase":"finished","pid":62893,"started_at":"2026-10-20T05:40:35.891041Z","finished_at":"2026-10-20T05:42:05.325441Z","session_id":"01a157d3-6d73-7303-bc5c-30c5af7768d4","outcome":"returned"}] -->
