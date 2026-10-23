# Boundary Review — parley.nvim#412 (whole-issue close)

| field | value |
|-------|-------|
| issue | 412 — Investigate native o-retry refusal flake on Neovim 0.11 |
| repo | parley.nvim |
| issue file | workshop/issues/000412-native-retry-refusal-flake.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0ac550a7735b18463d5b1edde7d41ce608d04420..823e00427984579672757290ff6eefdf153be628 |
| command | sdlc close --issue 412 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T13:09:27-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies the issue’s purpose without changing production behavior. The fixture now checks completed admission, preserves refusal protection, and separates producer arrival time from the production timeout. No blocking findings.

```findings
{}
```

1. **Strengths**
   - The completion observer follows the production `InsertEnter` handler; assertions inspect the actual admission result (`tests/integration/session_sync_native_spec.lua:372`).
   - Both refusal and unavailable outcomes exercise the real classifier and admission path (`tests/integration/session_sync_native_spec.lua:413`).
   - All six native retry keys remain covered. Atlas guidance accurately describes the changed fixture contract.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Neovim **0.11.7** and **0.12.5** each passed **144 native tests and 19 Couch tests**.
   - Preferred runtime: four architecture tests passed. Operator runtime: four documentation tests passed.
   - An in-memory mutation removing refusal protection caused both the controlled refusal test and native `o` retry test to fail, with explicit refusal diagnostics.
   - Diff checks passed; the checkout remains unchanged.

6. **Architecture**
   - **ARCH-DRY: Pass** — shared observation helper reuses the existing arrival budget.
   - **ARCH-PURE: Pass** — injected transport results exercise existing production logic; no business logic was added to the IO shell.
   - **ARCH-PURPOSE: Pass** — protection, timeout fallback, and native recovery remain covered. The pinned registry confirms Lua registration is still unsupported.
   - **ARCH-EVOLVE: Pass** — no persisted format changes.
   - Docs gate passes: atlas updated; no new user-facing command or configuration requires README changes.

7. **Plan revisions:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"edb4def4-f215-4858-b26f-2f67e6832c82","repository":"github.com/xianxu/parley.nvim","issue_id":"000412","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/cecb045acc12486d","reviewed_head":"823e00427984579672757290ff6eefdf153be628","slot":"parley.nvim:2","requested_at":"2026-10-22T20:05:48.944039Z"},"phase":"finished","pid":98834,"started_at":"2026-10-22T20:05:49.144933Z","finished_at":"2026-10-22T20:09:27.260571Z","session_id":"01a16538-4875-7c90-91a6-025beb355a27","outcome":"returned"}] -->
