# Boundary Review — parley.nvim#251 (whole-issue close)

| field | value |
|-------|-------|
| issue | 251 — Align shortcut help with finder controls and aliases |
| repo | parley.nvim |
| issue file | workshop/issues/000251-finder-help-aliases.md |
| boundary | whole-issue close |
| milestone | — |
| window | c90d2f953d6b6c3d3b91f7a6b13368ea5c61b9ed..0f20364519606a7beaece854446643dc85d5ba8a |
| command | sdlc close --issue 251 |
| reviewer | codex |
| timestamp | 2026-09-14T11:03:55-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned implementation delivers the finder alias and help corrections. All registry-backed picker installers consume complete key lists, primary labels remain unchanged, and reserved aliases are filtered individually. No blocking findings. Independent verification passed 344 focused tests and lint.

1. **Strengths**
   - Alias expansion stays centralized in `float_picker.lua:1501`, preserving existing callback and focus handling.
   - `float_picker_spec.lua:547` exercises effective mappings in prompt Insert/Normal and results Normal modes.
   - Registry tests cover disabled entries, explicit overrides, alias ordering, and finder help.
   - README and atlas changes document the changed finder controls and installer contract.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings**
   - `workshop/plans/000251-finder-help-aliases-plan.md:7` omits the requested PURE/INTEGRATION column. Entity locations and changes match the code, but classification should be explicit.

5. **Test coverage notes**
   - Eight focused spec files passed: **344 tests**, zero failures/errors.
   - `make lint`: **447 files**, zero warnings/errors.
   - Full-suite and native starter smoke results remain implementor-reported; I did not independently rerun those.
   - `git diff --check` found whitespace-only issues in workshop artifacts.

6. **Architectural notes**
   - **ARCH-DRY — pass:** one resolver and one alias installer; consumer sweep found no remaining registry-backed primary-only installers.
   - **ARCH-PURE — pass:** resolution remains deterministic; Neovim mapping effects stay in the picker.
   - **ARCH-PURPOSE — pass:** all targeted finders and help installers consume aliases.
   - **ARCH-MOCK — pass:** no new external dependency; focused tests exercise real Neovim mappings.
   - **ARCH-CONSTRAINTS — pass:** installation grows linearly with alias count; no new per-keystroke scan.
   - **ARCH-SECURE — pass:** registry normalization and existing reserved-key checks remain intact.
   - **ARCH-ORDER — pass:** aliases reuse existing callback sequencing and focus ownership.
   - **ARCH-FUNERAL — pass:** aliases create no durable runtime artifacts; mappings retain buffer-owned lifetimes.

7. **Plan revision recommendation**
   - Append a `## Revisions` entry identifying registry resolution as PURE and picker installation/callers as INTEGRATION.

```findings
findings:
  - id: new
    severity: Minor
    family: explicit-concept-classification
    title: |
      Core concepts omit PURE/INTEGRATION classifications
    detail: |
      workshop/plans/000251-finder-help-aliases-plan.md:7 lists names, locations, and status but no kind. ARCH-PURE: append a revision explicitly classifying registry resolution as PURE and Neovim mapping installation/callers as INTEGRATION.
```
