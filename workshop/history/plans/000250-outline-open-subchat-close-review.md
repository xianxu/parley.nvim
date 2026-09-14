# Boundary Review — parley.nvim#250 (whole-issue close)

| field | value |
|-------|-------|
| issue | 250 — Open sub-chat when selecting an outline branch |
| repo | parley.nvim |
| issue file | workshop/issues/000250-outline-open-subchat.md |
| boundary | whole-issue close |
| milestone | — |
| window | c90d2f953d6b6c3d3b91f7a6b13368ea5c61b9ed..b67298f62df303098d730957ba879823c3cfddb8 |
| command | sdlc close --issue 250 |
| reviewer | codex |
| timestamp | 2026-09-14T10:33:06-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned changes fulfill #250’s branch-navigation contract: standalone, inline, and nested branches open their child at line 1; missing children warn without creating buffers. The included #249 finder changes also passed focused checks. No blocking findings.

1. **Strengths**

   - `lua/parley/outline.lua:443` reuses resolved child paths and the existing window-navigation helper.
   - Regression tests exercise real chat parsing and file navigation, asserting destination paths and cursor positions.
   - Missing-file coverage verifies both visible failure and absence of an empty buffer.
   - Atlas documents branch destinations; README and starter documentation cover the finder changes.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   Independently passed the `ui/outline` mapped suite, including all six outline-navigation tests and 57 finder tests. Also passed 79 float-picker tests and five starter-policy tests. Full-suite, native-launcher, and pre-fix failure claims were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Reuses path resolution, navigation helpers, and registry metadata.
   - **ARCH-PURE — pass:** Navigation effects remain in the UI boundary; starter policy remains a configuration projection.
   - **ARCH-PURPOSE — pass:** All specified branch forms share the corrected destination rule.
   - **ARCH-MOCK — pass:** No new external dependency; navigation tests use isolated files and the existing picker seam.
   - **ARCH-CONSTRAINTS — pass:** Adds one selected-file load, with no new scanning or concurrency.
   - **ARCH-SECURE — pass:** Checks readability before buffer creation and retains escaped file navigation.
   - **ARCH-ORDER — pass:** Introduces no asynchronous navigation state; existing confirmation sequencing remains intact.
   - **ARCH-FUNERAL — pass:** Uses existing editor-owned buffers and introduces no durable artifact family.

7. **Plan revision recommendations:** None.

```findings
{}
```
