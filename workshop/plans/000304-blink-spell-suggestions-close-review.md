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

---

## Re-review — 2026-09-29T16:28:17-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 304 — Unify automatic spell suggestions in Blink |
| repo | parley.nvim |
| issue file | workshop/issues/000304-blink-spell-suggestions.md |
| boundary | whole-issue close |
| milestone | — |
| window | 63390569836794b56c5e97442dceb9e3db4fd454..ef336da699c25819524c82b34fda17da45eb74dd |
| command | sdlc close --issue 304 |
| reviewer | codex |
| timestamp | 2026-09-29T16:28:17-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range delivers the shared Blink spelling integration and documents its setup and limits. BR-1 is addressed: window transitions invalidate acceptance synchronously, and its regression fails when that fix is removed in memory. No new blocking findings. Repository files remain unchanged.

1. **Strengths**
   - Pure targeting, dismissal, and acceptance logic lives in `lua/parley/spell_state.lua`.
   - Whole-word edits preserve surrounding text and undo behavior in both modes.
   - Mapping leases restore previous mappings while preserving intervening user remaps.
   - README and atlas cover the new configuration, controls, and compatibility boundary.

2. **Critical findings:** None remaining.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Required pinned stat/name-status inspections completed.
   - `make test-spec SPEC=chat/spell_typeahead`: **77 tests passed**.
   - Pinned Blink compatibility: **plugin, app, and existing completion/pairing checks passed**.
   - Mutation removing the window-event handler failed at `tests/packaging/spell_compatibility.lua:175`: stale correction accepted after returning to the original window.
   - English spelling p95 measured approximately **28 ms**.
   - Pinned diff whitespace check passed.
   - Harness process census was unavailable because `ps` was unavailable.

6. **Architectural notes**
   - **ARCH-DRY — pass:** shared plugin/app implementation and dictionary admission.
   - **ARCH-PURE — pass:** data-only reducer tests; declared integration entities match their locations.
   - **ARCH-PURPOSE — pass:** automatic Normal/Insert corrections delivered in both distributions.
   - **ARCH-MOCK — pass:** stateful fake plus real pinned dependency checks.
   - **ARCH-CONSTRAINTS — pass:** bounded inputs, suggestion counts, and cancellable debounce.
   - **ARCH-SECURE — pass:** option/edit APIs avoid command interpolation; compatibility tests isolate storage.
   - **ARCH-ORDER — pass:** window transitions now revoke tickets through the reducer; delayed-resolution regression verified.
   - **ARCH-FUNERAL — pass:** timers, mappings, adapters, and controller resources have teardown paths.

7. **Plan revision recommendations:** None; the BR-1 revision records the corrected lifecycle and regression scenarios.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      lua/parley/spell_blink.lua:256 invalidates synchronously on window transitions and schedules entry observation. Controller regressions verify cleanup and re-observation; real Blink regressions cover delayed resolution across departure and return. Both profiles pass, and removing this handler in memory makes the return-to-origin regression fail at tests/packaging/spell_compatibility.lua:175.
```
