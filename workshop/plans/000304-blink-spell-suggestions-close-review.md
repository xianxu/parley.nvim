# Boundary Review — parley.nvim#304 (whole-issue close)

| field | value |
|-------|-------|
| issue | 304 — Unify automatic spell suggestions in Blink |
| repo | parley.nvim |
| issue file | workshop/issues/000304-blink-spell-suggestions.md |
| boundary | whole-issue close |
| milestone | — |
| window | 63390569836794b56c5e97442dceb9e3db4fd454..91fc5d6767186a89d211756399bf65eac563e8a9 |
| command | sdlc close --issue 304 |
| reviewer | codex |
| timestamp | 2026-09-29T16:23:27-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared controller, whole-word edits, mapping restoration, and documentation are well implemented. The spelling suite and real Blink checks pass, but a reproduced window-switch race violates the stale-acceptance contract and blocks shipping.

1. **Strengths**

   - Pure target selection and admission logic are separated from Neovim effects in `lua/parley/spell_state.lua`.
   - `lua/parley/spell_source.lua:71` reconstructs the original whole-word edit and completes callbacks even when editing fails.
   - Mapping leases preserve prior mappings and intervening user remaps.
   - README and atlas document setup, controls, fallback, configuration, and compatibility limits.

2. **Critical findings**

   **Window excursions do not invalidate acceptance — ARCH-ORDER.** At [spell_blink.lua:241](/private/tmp/parley-304-worktree/lua/parley/spell_blink.lua:241), observations cover buffer/cursor/mode changes but omit window entry/leave. Switching between two windows displaying the same buffer at the same position need not trigger those events. Returning to the original window therefore leaves an old acceptance ticket valid.

   Reproduced with the pinned real Blink: during source resolution, switch to the other window and back, then complete resolution. The result was `before the after`; the stale correction should have been rejected. A controller-level probe independently returned `ACCEPTED_AFTER_WINDOW_EXCURSION true`.

   Add synchronous invalidation on window departure and observation on entry, routed through the reducer. Add regression coverage for both remaining in another window and returning before resolution completes, including menu/map cleanup.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Required pinned stat/name-status inspections completed; production, tests, plan, and documentation changes inspected.
   - `make test-spec SPEC=chat/spell_typeahead`: all 75 tests passed.
   - `scripts/check-spell-compatibility.sh`: plugin, app, and existing completion/pairing checks passed.
   - Measured English spelling p95: approximately 28 ms.
   - `git diff --check` passed.
   - Existing stale-resolution coverage exercises cursor movement, but misses same-buffer window excursions.
   - The test harness could not perform its process census because `ps` was unavailable.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared plugin/app integration and dictionary admission check.
   - **ARCH-PURE — pass:** the declared pure entity uses data-only tests; integration entities exist at their documented paths.
   - **ARCH-PURPOSE — pass:** both distributions implement the requested interface, subject to the defect above.
   - **ARCH-MOCK — pass:** stateful Blink fake and real pinned compatibility checks exercise the dependency seam.
   - **ARCH-CONSTRAINTS — pass:** bounded input/suggestions, cancellable debounce, and measured synchronous spelling cost.
   - **ARCH-SECURE — pass:** option/edit APIs avoid command interpolation; compatibility profiles isolate filesystem state.
   - **ARCH-ORDER — flag:** window transitions bypass generation invalidation.
   - **ARCH-FUNERAL — pass:** timers, mappings, adapters, and per-buffer ownership have teardown paths.

7. **Plan revision recommendations**

   Add a `## Revisions` entry explicitly including same-buffer window transitions in the lifecycle and regression matrix. Enumerate departure, entry, and departure/return before delayed resolution, preserving the existing stale-acceptance guarantee.

```findings
findings:
  - id: new
    severity: Critical
    family: acceptance-context-invalidation
    title: |
      Same-buffer window excursions leave stale acceptance tickets valid
    detail: |
      lua/parley/spell_blink.lua:241-258 omits window entry/leave invalidation. With pinned real Blink, switching between two windows showing the same buffer and returning during resolution still applied the old correction. ARCH-ORDER: invalidate synchronously on window departure, observe on entry, and add regression tests covering delayed acceptance and resource cleanup across these transitions.
```
