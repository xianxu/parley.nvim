# Boundary Review — parley.nvim#299 (whole-issue close)

| field | value |
|-------|-------|
| issue | 299 — Ignore floating overlays during chat navigation |
| repo | parley.nvim |
| issue file | workshop/issues/000299-navigation-floating-overlays.md |
| boundary | whole-issue close |
| milestone | — |
| window | 1e1b01b5e3c4c16097716ae268212f0fdc795d97..fc16ff034cce1fbfb20d46797788b9559af5d87a |
| command | sdlc close --issue 299 |
| reviewer | codex |
| timestamp | 2026-09-28T22:25:50-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned change satisfies the issue’s Done-when contract. Floating overlays are excluded from split counting and destination lookup, with regression coverage for both link and outline navigation. No blocking findings.

1. **Strengths**
   - `lua/parley/helper.lua:11` centralizes window eligibility, including invalid and external windows.
   - `tests/integration/open_reference_spec.lua:379` exercises actual Option+O mappings across single-window, two-split, and destination-in-float cases.
   - `tests/unit/outline_spec.lua:356` covers both captured and discovered floating destinations and checks that the overlay’s cursor remains unchanged.
   - Both relevant atlas pages document the correction.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes:** Both mapped suites passed: `context/file_references` and `ui/outline`. Lint passed across 669 files; pinned-range whitespace checks passed. The harness could not check orphan processes because `ps` was unavailable. Existing tests retain coverage for ordinary splits and ChatFinder behavior.

6. **Architectural notes**
   - **ARCH-DRY — pass:** All four affected checks consume the shared predicate.
   - **ARCH-PURE — pass:** The addition is a small Neovim UI boundary helper; no business logic or new IO workflow is introduced.
   - **ARCH-PURPOSE — pass:** Both navigation paths are corrected, including buffers already displayed in overlays. No new command, keybinding, or configuration surface requires a README update.

7. **Plan revision recommendations:** None.

```findings
{}
```
