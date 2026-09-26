# Boundary Review — parley.nvim#275 (whole-issue close)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..11c16dac5b70c162705616bcd0e7d00d7d40fb37 |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T20:54:35-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The picker and theme registry are wired into the production command, but the pinned range does not meet the live-preview and single-source contracts. The missing behavior tests also leave most of the issue’s acceptance criteria unverified.

### Strengths

- `:ParleyTheme` enters the existing floating picker through the normal command registration path ([init.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:5105)).
- Preview application and preference writing are separate operations ([theme_picker.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:58)).
- The new theme surface is mapped in `atlas/`.

### Critical findings

1. **ARCH-PURPOSE — Filtering can leave the displayed candidate and preview out of sync.** [float_picker.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/float_picker.lua:1029) fires `on_selection_change` only when the numeric index changes. A query can replace or reorder the item at the same index, so the highlighted theme changes without applying its colorscheme. Compare selected item identity across filter updates and add a regression test for that sequence.

2. **ARCH-DRY / ARCH-PURPOSE — The registry is not the promised source for packaged dependencies.** [theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:16) defines theme choices, while [starter-config/init.lua](/Users/xianxu/workspace/parley.nvim/packaging/starter-config/init.lua:97) separately maintains the plugin list and pins. The Spec explicitly puts dependency metadata in the registry. Derive the starter’s plugin specs from that metadata, then test the projection.

3. **ARCH-PURPOSE — “Restore startup theme” does not restore the startup snapshot.** The fifth row always resolves to Moonfly ([theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:7)), although the picker is also available in ordinary plugin use, where the startup scheme may differ. Capture the startup scheme for that action and test a non-Moonfly startup.

### Important findings

- **Acceptance coverage is incomplete.** [theme_picker_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/theme_picker_spec.lua:24) only proves that the command opens. No test drives production keyboard or mouse entry through preview, commit, cancellation, persistence, or repeated cycles. No committed test loads all four packaged schemes and checks the specified syntax, Parley, float, and statusline groups. Add those tests before closing; this is also the ARCH-MOCK conformance gap for the external colorscheme plugins.
- **ARCH-SECURE — A failed preference read can escape startup.** [theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:90) protects JSON decoding but not `readfile`. A file that becomes unreadable between the readability check and read can raise, contrary to the documented fallback. Handle the read failure visibly and test it through an injected reader.
- **README gate:** `README.md` has no change in the pinned range despite the new user-facing `:ParleyTheme` command and Moonfly startup default. [packaging/README.md](/Users/xianxu/workspace/parley.nvim/packaging/README.md:20) covers the packaged app, but the required top-level README update is still missing.

### Minor findings

- None.

### Test coverage notes

The unit tests cover registry values, a keyboard index move, and an injected apply call. They do not exercise the filter identity bug or the issue’s full production and packaged-launch paths. I inspected the committed tests and diff; I did not run test targets because this review was restricted to read-only tools.

### Architectural notes for upcoming work

ARCH-DRY and ARCH-PURPOSE: **flag**, as above. ARCH-PURE: **pass** for registry lookup and picker callback separation; revise the plan’s concept table to label IO-bearing `apply` and `save` as INTEGRATION. ARCH-MOCK: **flag** for missing executable package compatibility coverage. ARCH-CONSTRAINTS: **pass**; previews are synchronous with no new fan-out. ARCH-SECURE: **flag** for the read failure path. ARCH-ORDER: **flag** for the filter transition that changes selection identity without a preview effect. ARCH-FUNERAL: **pass**; this range adds one overwritten preference file and no growing artifact family.

### Plan revision recommendations

Append a `## Revisions` entry recording the dependency-metadata projection, startup-snapshot semantics, and filter identity transition. Add PURE/INTEGRATION kinds to the Core concepts table and reconcile the unchecked task rows with the tests actually delivered.

```findings
findings:
  - id: new
    severity: Critical
    family: selection-identity-effects
    title: |
      Filtering changes the selected theme without updating its preview
    detail: |
      set_selection compares only row indices, so a different item at the same index receives no selection-change callback.
  - id: new
    severity: Critical
    family: registry-consumer-derivation
    title: |
      Packaged dependency metadata is maintained outside the theme registry
    detail: |
      The starter has a separate hand-maintained plugin list despite the Spec's single-source requirement.
  - id: new
    severity: Critical
    family: startup-snapshot-semantics
    title: |
      Restore startup theme always selects Moonfly
    detail: |
      The command is available to ordinary plugin users whose startup colorscheme may be different.
  - id: new
    severity: Important
    family: production-path-coverage
    title: |
      Theme acceptance behavior lacks production-path tests
    detail: |
      The committed integration test opens the command but does not verify preview, commit, cancel, mouse input, packaged restoration, or colorscheme compatibility groups.
  - id: new
    severity: Important
    family: untrusted-state-read-failure
    title: |
      Preference read errors can escape startup
    detail: |
      readfile is outside the protected decode path, so an unreadable or changing preference file can raise instead of falling back.
  - id: new
    severity: Important
    family: user-surface-readme
    title: |
      Top-level README omits the new theme command and startup theme
    detail: |
      README.md is unchanged in the pinned range despite the new user-facing command.
```

---

## Re-review — 2026-09-25T20:58:55-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..4cde6e91601bfe10b309bde1fefa2ee423e04cee |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T20:58:55-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The focused theme tests pass, and the README now documents the command. The boundary still fails the Spec: filtering can leave the preview on the wrong theme, packaged dependencies remain hand-maintained outside the registry, and “Restore startup theme” can restore the wrong scheme. The production test does not exercise those paths.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Filtering replaces filtered before set_selection reads previous_item (float_picker.lua:1198, 1224, 1028), so a different theme at the same index still produces no callback. No filtering regression test was added.
  - id: BR-2
    disposition: not-addressed
    note: |
      theme.packaged_plugins() exists (theme.lua:69) but has no consumer; the starter still duplicates every plugin and commit (packaging/starter-config/init.lua:97-105). This is the registry-consumer-derivation rule, not a missing metadata field.
  - id: BR-3
    disposition: not-addressed
    note: |
      The picker passes its opening scheme as the startup scheme (theme_picker.lua:28, 60, 63). After a packaged launch restores a saved theme, selecting Restore startup reapplies that saved theme while persisting the startup sentinel. Ordinary plugin startup also applies Moonfly when that sentinel is loaded (init.lua:1343-1345). No regression test covers either path.
  - id: BR-4
    disposition: not-addressed
    note: |
      The sole production command test asserts only that the picker opens (theme_picker_spec.lua:24-35). It never exercises preview, filtering, commit, cancel, mouse input, packaged restart, or compatibility groups.
  - id: BR-5
    disposition: not-addressed
    note: |
      readfile is now protected (theme.lua:106), but there is no regression test that makes the read fail. The required behavior-changing correction lacks evidence that fails without it.
  - id: BR-6
    disposition: addressed
    note: |
      README.md:47-49 now names :ParleyTheme and Moonfly; the command is registered in init.lua:5107-5108, and Moonfly is the packaged default in theme.lua:7-14.
```

### Strengths

- The registry supplies picker rows and validates persisted IDs in [theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:62).
- Preview and preference writes use separate callbacks in [theme_picker.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:59).
- The new atlas page and README entry map the user-facing surface.

### Critical findings

- **BR-1 — ARCH-ORDER:** Capture the selected identity *before* replacing the filtered list, then emit one selection-change event if the resulting identity differs. Add a production-path filtering test that goes red without the fix.
- **BR-2 — ARCH-DRY, ARCH-PURPOSE:** Make the starter consume registry-derived plugin specs. Test that every packaged registry dependency reaches the starter; the unused helper does not establish a single source.
- **BR-3 — ARCH-ORDER:** Keep the scheme at picker open for cancellation, and the actual startup scheme for the restore action. Test packaged restoration followed by “Restore startup,” plus an ordinary plugin with a custom startup scheme.

### Important findings

- **BR-4 — ARCH-PURPOSE:** Add production-command tests for keyboard and mouse preview, commit, cancel, persistence across startup, invalid state, and every specified highlight group. Assert observed colorscheme and state changes.
- **BR-5 — ARCH-SECURE:** Add a read-failure regression test that makes `readfile` raise and proves startup falls back without raising.

### Minor findings

None.

### Test coverage notes

`make test-spec SPEC=ui/themes PLENARY=/tmp/plenary.nvim JOBS=1` passed: 4 sidecar, 1 command integration, 81 float-picker, and 5 theme unit tests. The green command test proves opening only. No packaged-startup or colorscheme compatibility acceptance test appears in the pinned range.

### Architectural notes for upcoming work

- **ARCH-DRY:** Flag — starter dependency metadata duplicates the registry.
- **ARCH-PURE:** Pass for `valid_id` and registry lookup; the plan should classify `apply` and `set_selection` as integration code.
- **ARCH-PURPOSE:** Flag — the promised single source and acceptance behavior remain incomplete.
- **ARCH-MOCK:** No new external service seam is introduced; packaged plugin behavior still needs a real packaged-path test.
- **ARCH-CONSTRAINTS:** Pass — theme changes are synchronous, with no new fan-out or background work.
- **ARCH-SECURE:** Flag — failed preference reads have no regression evidence.
- **ARCH-ORDER:** Flag — filtering loses prior selection identity, and startup, opening, and saved schemes are conflated.
- **ARCH-FUNERAL:** Pass — the feature adds one rewritten preference file and no growing artifact family.

### Plan revision recommendations

Append a `## Revisions` entry to [the plan](/Users/xianxu/workspace/parley.nvim/workshop/plans/000275-packaged-theme-picker-plan.md:11) that distinguishes startup scheme from picker-opening scheme, makes starter dependency derivation explicit, and records the remaining production-path tests. Add the missing PURE/INTEGRATION kind column to the Core concepts table. Its task checkboxes remain unchecked despite the issue claiming completion; reconcile them against delivered evidence.

---

## Re-review — 2026-09-25T21:05:26-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..69aed1365c6aeb15fdd672c716798c1f56168055 |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T21:05:26-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The registry now supplies the starter’s theme plugins, the unreadable-preference fallback has a regression test, and the README documents the command. The boundary still cannot close: filtering can leave the preview on the wrong theme, “Restore startup theme” can restore the currently saved theme, and Solarized Light can load in dark mode. The focused suite passed, but it does not exercise those behaviors.

### Strengths

- [theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:69) derives packaged plugin specs from registry entries.
- [theme_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/unit/theme_spec.lua:45) exercises a read failure that would escape without the protected `readfile` call.
- The [README](/Users/xianxu/workspace/parley.nvim/README.md:47) and [atlas theme map](/Users/xianxu/workspace/parley.nvim/atlas/ui/themes.md:1) cover the new surface.

### Critical findings

- **BR-1 — filtering still misses a preview change.** [apply_filter](/Users/xianxu/workspace/parley.nvim/lua/parley/float_picker.lua:1174) replaces `filtered` before `set_selection` captures `previous_item`. When a query puts a different theme at the same index, the callback does not run. Capture the selected identity before replacing the list and add a filtering regression test.
- **BR-3 — startup restore still uses the opening scheme.** [theme_picker.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:59) passes `opening_scheme` to the startup row. After a saved Catppuccin launch, choosing “Restore startup theme” applies Catppuccin again while saving `startup`; the visible choice changes only on the next launch. Keep the opening snapshot for cancellation and the actual startup scheme for this action.
- **New — Solarized Light does not select light mode.** [theme.lua](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:43) calls `colorscheme solarized` without setting `background=light`. The pinned Solarized script branches on `&background`; an isolated Neovim run with `background=dark` remained `dark solarized`. Apply and restore the variant explicitly, with a test that checks `vim.o.background`.

### Important findings

- **BR-2 remains open under the review’s regression rule.** The starter now consumes `packaged_plugins()`, but no test asserts that its dependency set derives from registry entries or goes red if a plugin is removed from that function.
- **BR-4 remains open.** [theme_picker_spec.lua](/Users/xianxu/workspace/parley.nvim/tests/integration/theme_picker_spec.lua:24) verifies command opening only. Add production-command tests for preview, filtering, commit, cancel, mouse selection, saved startup restoration, and the specified highlight and syntax groups.

### Minor findings

None.

### Test coverage notes

`make test-spec SPEC=ui/themes PLENARY=/tmp/plenary.nvim` passed: 4 sidecar, 1 integration, 81 picker, and 6 theme tests. Those results establish the tested paths, not the missing acceptance behavior above.

### Architecture

ARCH-DRY **pass**: starter dependencies derive from the registry. ARCH-PURE **pass**: registry decisions and UI application remain separated. ARCH-PURPOSE **flag**: the startup action and Solarized Light do not deliver their named choices. ARCH-MOCK **pass**: no new external service call is introduced. ARCH-CONSTRAINTS **pass**: switching is synchronous and local. ARCH-SECURE **pass** for the tested unreadable preference path. ARCH-ORDER **flag**: filtering changes selected identity without consistently producing its preview effect. ARCH-FUNERAL **pass**: the change adds one rewritten preference value, with no growing artifact.

### Plan revision recommendations

Append a dated `## Revisions` entry correcting the plan’s claim that filtering notifications and startup restore are fixed. Add explicit PURE/INTEGRATION kinds to the Core concepts table, and name Solarized’s required background transition and its restoration test.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Filtering replaces the list before set_selection reads the previous item; no filtering regression test exists.
  - id: BR-2
    disposition: not-addressed
    note: |
      Registry derivation is wired, but no regression test fails when the starter dependency derivation is removed.
  - id: BR-3
    disposition: not-addressed
    note: |
      The startup row applies opening_scheme, which can be a previously saved nondefault theme; no regression test covers it.
  - id: BR-4
    disposition: not-addressed
    note: |
      The production-command integration test asserts opening only, leaving the specified acceptance transitions and compatibility groups untested.
  - id: BR-5
    disposition: addressed
    note: |
      theme.lua protects readfile with pcall, and theme_spec.lua tests an unreadable file; removing that protection makes the test fail.
  - id: BR-6
    disposition: addressed
    note: |
      The README diff names :ParleyTheme and Moonfly, matching the command registration and registry default.
findings:
  - id: new
    severity: Critical
    family: colorscheme-variant-selection
    title: |
      Solarized Light loads the dark variant when background is dark
    detail: |
      The registry names a light option but applies colorscheme solarized without setting background=light; the pinned scheme selects its variant from &background. Set and restore the required mode and test the resulting background through the production command.
```

---

## Re-review — 2026-09-25T21:07:54-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..fd6384839b7b90003f8eee46a6ff9c77fac71612 |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T21:07:54-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The pinned diff adds the theme registry, derives the starter plugin list from it, and wires `:ParleyTheme` into the shared picker. The boundary is not ready: the open behavior fixes lack the required regression tests, startup restoration still mishandles ordinary plugin users, and a failed theme load can leave the current theme altered.

### Strengths

- The starter obtains its theme plugins from [the registry](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:69), removing the separate dependency list.
- [Preview and persistence](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:61) are separate operations.
- README and atlas changes describe the new command and theme surface.

### Critical findings

- **BR-3 remains open — startup snapshot semantics.** [Selecting “Restore startup theme”](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:65) persists `startup`, but [ordinary plugin setup](/Users/xianxu/workspace/parley.nvim/lua/parley/init.lua:1343) later resolves that value to Moonfly, regardless of the user’s startup colorscheme. The picker also applies the registry’s dark mode before loading a captured light startup scheme. Define and test restoration across a fresh plugin launch, including a light startup theme. **ARCH-PURPOSE, ARCH-ORDER.**
- **New — failed-theme-application-rollback.** [theme.apply](/Users/xianxu/workspace/parley.nvim/lua/parley/theme.lua:136) changes `background` before attempting the colorscheme. If that scheme is unavailable, it returns failure while leaving the prior theme’s mode changed, contrary to the plan’s “retain the prior scheme” contract. Snapshot and restore the prior mode and scheme on failure; test through `:ParleyTheme`. **ARCH-ORDER.**
- **BR-1, BR-2, and BR-7 lack regression evidence.** The diff contains plausible corrections, but no test that fails without the filtering identity fix, registry-derived starter dependencies, or Solarized Light’s mode setting. The review contract requires such a test for each executable fix.

### Important findings

- **BR-4 remains open — production-path coverage.** [The integration spec](/Users/xianxu/workspace/parley.nvim/tests/integration/theme_picker_spec.lua:24) checks only that the command opens. It does not assert preview, Enter, Escape, mouse selection, packaged restart, or compatibility groups. Sweep the acceptance cases in the issue through the production command. **ARCH-PURPOSE.**

### Minor findings

None.

### Test coverage notes

No tests were run in this read-only review. Inspection found unit tests for metadata and isolated application, but no regression test for the open behavior findings. The issue’s claimed compatibility and packaged-startup checks are not present as committed assertions.

### Architectural notes

- **ARCH-DRY:** Pass; starter dependencies derive from the registry.
- **ARCH-PURE:** Pass with a thin application boundary; registry lookup and validation are separable.
- **ARCH-PURPOSE:** Flag; the documented acceptance behavior remains unproved and ordinary-user startup restoration fails.
- **ARCH-MOCK:** Pass for this local Neovim operation; no new external service seam.
- **ARCH-CONSTRAINTS:** Pass; application is synchronous and bounded.
- **ARCH-SECURE:** Pass for malformed preference values; the read path validates IDs.
- **ARCH-ORDER:** Flag; failed application does not preserve the opening state, and picker transitions lack sequence tests.
- **ARCH-FUNERAL:** Pass; the new preference is one rewritten state file.

### Plan revision recommendations

Append a dated `## Revisions` entry defining how the `startup` sentinel resolves on a later ordinary-plugin launch, how failed theme application restores the previous state, and the production-path test matrix. Add PURE/INTEGRATION kinds to the Core concepts table; `apply` belongs to the integration boundary.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Item-identity comparison was added at float_picker.lua:1175-1268, but no regression test filters to a different item at the same row; the executable fix lacks required evidence.
  - id: BR-2
    disposition: not-addressed
    note: |
      The starter now calls theme.packaged_plugins at packaging/starter-config/init.lua:100, but no regression test proves its dependency list derives from the registry.
  - id: BR-3
    disposition: not-addressed
    note: |
      The picker captures the opening scheme, but saving startup then restarting an ordinary plugin user still applies Moonfly at lua/parley/init.lua:1343-1345; no production regression test covers the snapshot.
  - id: BR-4
    disposition: not-addressed
    note: |
      The integration test only opens the command; the stated preview, commit, cancel, mouse, packaged restoration, and compatibility assertions are absent.
  - id: BR-7
    disposition: not-addressed
    note: |
      theme.apply now sets background=light before Solarized, but no production-path test asserts the resulting background and colorscheme; the executable fix lacks required regression evidence.
findings:
  - id: new
    severity: Critical
    family: failed-theme-application-rollback
    title: |
      Failed colorscheme loads leave the previous theme altered
    detail: |
      theme.apply changes vim.o.background at lua/parley/theme.lua:136-137 before the protected colorscheme call. When an optional scheme is unavailable, failure returns without restoring the prior mode or scheme, violating the plan's retain-prior-scheme contract. Restore the snapshot on failure and test this through the production command. ARCH-ORDER.
```

---

## Re-review — 2026-09-25T22:06:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..47debd2f6fbc8c699303019060742655df68a490 |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T22:06:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation substantially resolves the reported bugs, and the focused tests pass. BR-4 remains open: packaged startup restoration is not tested through its production path, and the compatibility script passes even when OneDark variant selection is disabled. No new critical defect was established.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Selection notifications compare identities. Replacing identity comparison with row comparison makes the same-index filtering regression fail.
  - id: BR-2
    disposition: addressed
    note: |
      The starter consumes theme.packaged_plugins(); the bootstrap fixture asserts every registry dependency reaches Lazy with its pin and eager-loading setting.
  - id: BR-3
    disposition: addressed
    note: |
      Startup is captured separately before preference restoration. Hardcoding Moonfly again makes the custom-startup regression fail.
  - id: BR-4
    disposition: not-addressed
    note: |
      Preview, commit, cancel and mouse coverage now exist, but packaged restart restoration remains untested through production startup. The real-plugin compatibility script also never asserts colors_name or OneDark style; disabling variant selection still passes all 19 entries. Complete the acceptance matrix through production entry points and verify each oracle detects removal of its behavior. ARCH-PURPOSE, ARCH-MOCK.
  - id: BR-5
    disposition: addressed
    note: |
      Protected preference reads and the unreadable-file regression remain present; the focused test passes.
  - id: BR-6
    disposition: addressed
    note: |
      README.md documents ParleyTheme, Moonfly startup, persistence and cancellation, matching command registration and picker callbacks.
  - id: BR-7
    disposition: addressed
    note: |
      Application sets the registry background mode. Removing that assignment for Solarized makes the production-command light-mode regression fail.
  - id: BR-8
    disposition: addressed
    note: |
      Failed application restores the previous snapshot. Removing rollback makes the partial-highlight-failure regression fail.
```

1. **Strengths**

   - Dependency installation and picker choices derive from the registry.
   - Filtering now follows selected identity through the shared picker boundary.
   - Startup and opening snapshots have separate responsibilities.
   - README, packaging guidance and atlas document the new surface.

2. **Critical findings**

   None remaining.

3. **Important findings**

   **BR-4 — incomplete acceptance coverage.** At `tests/integration/theme_picker_spec.lua:130`, the restart test manually invokes a fresh theme module; it does not exercise packaged startup or `parley.setup()` preference restoration. The bootstrap fixture replaces `parley.starter.start()` and records window/runtime metadata without asserting theme state.

   At `tests/packaging/theme_compatibility.lua:21–30`, assertions cover background and highlight presence, but omit `vim.g.colors_name` and `vim.g.onedark_config.style`. An in-memory mutation removing variant selection still passed every entry.

   Finish this existing finding by testing saved, absent and malformed preferences through fresh production startup, then asserting scheme identity and variant for every registry choice. Include command-path failed-preview rollback. These checks should fail when the corresponding behavior is removed.

4. **Minor findings**

   None newly raised.

5. **Test coverage notes**

   - Passed all **109 mapped tests**.
   - Passed compatibility checks against installed plugins matching all registry pins.
   - Independently checked **361 preview/restore pairs** for scheme, background, representative appearance and applicable OneDark style.
   - Mutation checks detected removal of identity tracking, custom startup restoration, Solarized mode selection and failure rollback.
   - Process-survivor verification was unavailable because the sandbox blocks `ps`.
   - Repository files were unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** registry-derived dependency and picker consumers.
   - **ARCH-PURE — pass:** deterministic registry operations are distinguishable from application/storage boundaries; revised classifications match.
   - **ARCH-PURPOSE — flag:** BR-4 leaves required acceptance behavior insufficiently verified.
   - **ARCH-MOCK — flag:** startup fixtures do not model persisted theme restoration; real-plugin checks lack identity oracles.
   - **ARCH-CONSTRAINTS — pass:** fixed-size, synchronous local selection; no added network work.
   - **ARCH-SECURE — pass:** persisted ids are validated and read/decode failures handled.
   - **ARCH-ORDER — pass:** separate snapshots and synchronous rollback; existing picker owns dismissal and confirmation.
   - **ARCH-FUNERAL — pass:** one rewritten preference file; picker resources use existing teardown.

7. **Plan revision recommendations**

   Append a `## Revisions` entry distinguishing helper-level restart coverage from production startup coverage. Reconcile the acceptance claims after adding scheme/variant assertions and fresh-start persistence tests, recording the mutations each detects.

---

## Re-review — 2026-09-25T22:12:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 275 — Add a packaged Parley theme picker with live preview |
| repo | parley.nvim |
| issue file | workshop/issues/000275-packaged-theme-picker.md |
| boundary | whole-issue close |
| milestone | — |
| window | d8da2fe2132dc4946ae02955b7431746139fb285..7bc2cccb9004c1ae4f74b75df4cd54ea91f44d13 |
| command | sdlc close --issue 275 |
| reviewer | codex |
| timestamp | 2026-09-25T22:12:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-4 is addressed: production-path coverage now exercises the requested behaviors, and all 113 mapped tests plus all 19 pinned-plugin compatibility cases pass. One newly reproduced correctness bug blocks shipping: confirming an empty search closes the picker while leaving an uncommitted preview active.

```findings
dispose:
  - id: BR-4
    disposition: addressed
    note: |
      Production-command tests cover preview, commit, cancellation, mouse mappings, and failed loads. Fresh starter tests cover persisted choices and fallback. Independently removing startup restoration in a scratch copy fails both saved-choice tests. The real compatibility matrix passes all 19 entries against verified plugin pins.
  - id: BR-1
    disposition: addressed
    note: |
      Selection notifications compare item identity; the production filter-change regression passes.
  - id: BR-2
    disposition: addressed
    note: |
      Starter dependencies derive from packaged_plugins(), with registry-derived dependency assertions in the bootstrap fixture.
  - id: BR-3
    disposition: addressed
    note: |
      Startup is captured before preference restoration; fresh-process saved-theme and startup-sentinel assertions pass.
  - id: BR-5
    disposition: addressed
    note: |
      Preference reads protect readfile with pcall; the unreadable-state regression passes.
  - id: BR-6
    disposition: addressed
    note: |
      README.md now documents :ParleyTheme, Moonfly startup, Enter persistence, and Escape restoration, matching the implemented command.
  - id: BR-7
    disposition: addressed
    note: |
      Solarized declares light mode; both production-command and real-plugin checks pass.
  - id: BR-8
    disposition: addressed
    note: |
      Failed application restores the previous snapshot; production-command tests verify appearance and unchanged preference after partial failure and missing packages.
findings:
  - id: new
    severity: Critical
    family: preview-terminal-outcomes
    title: |
      Confirming no matches closes the picker without resolving its preview
    detail: |
      lua/parley/float_picker.lua:1111-1121 closes unconditionally but invokes on_select only when an item exists; it never invokes on_cancel for empty results. Reproduced through :ParleyTheme: preview dayfox, filter to no matches, press Enter. Both floats close and no preference is saved, but dayfox remains instead of the opening Moonfly. Enforce the rule that every preview-session exit commits a valid selection or restores the opening snapshot; alternatively keep empty confirmation open. Enumerate terminal paths and add a production-command regression (ARCH-ORDER, ARCH-PURPOSE).
```

1. **Strengths**
   - Registry-derived packaging, picker choices, and validation share one authority.
   - Startup and picker-opening snapshots correctly serve different purposes.
   - Real-plugin compatibility verifies scheme identity, OneDark variant, background, and highlight groups.
   - README and atlas updates cover the new user and architectural surfaces.

2. **Critical findings**
   - Empty confirmation strands the preview. The closing branch is at [float_picker.lua:1111](/Users/xianxu/workspace/parley.nvim/lua/parley/float_picker.lua:1111); restoration depends on `on_cancel` at [theme_picker.lua:70](/Users/xianxu/workspace/parley.nvim/lua/parley/theme_picker.lua:70). Route this outcome through cancellation or retain the open picker.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Mapped suite: **113 passed**.
   - Real compatibility matrix: **19 passed**; installed commit hashes match registry pins.
   - Startup mutation: **two expected failures**, proving the saved-choice tests detect missing restoration.
   - Added scratch reproduction: **11 existing cases passed, one new case failed**, observing `dayfox` instead of `moonfly` after empty confirmation.
   - `git diff --check` passed. Process-leak census was unavailable because the harness could not use `ps`. Repository files were unchanged.

6. **Architectural notes**
   - **ARCH-DRY — pass:** consumers derive from the registry.
   - **ARCH-PURE — pass:** registry queries remain deterministic; editor/filesystem operations are classified as integration.
   - **ARCH-PURPOSE — flag:** the preview lifecycle remains incomplete for empty confirmation.
   - **ARCH-MOCK — pass:** executable color fixtures exercise production loading; pinned real plugins provide compatibility evidence.
   - **ARCH-CONSTRAINTS — pass:** fixed choice set and synchronous local application; no new background fan-out.
   - **ARCH-SECURE — pass:** preference validation and isolated test state cover malformed/unreadable inputs.
   - **ARCH-ORDER — flag:** a terminal path invokes neither commit nor cancellation.
   - **ARCH-FUNERAL — pass:** one overwritten preference file; existing picker cleanup owns windows and callbacks.

7. **Plan revision recommendation**
   - Append a `## Revisions` entry defining empty-confirmation behavior and the invariant that every closed preview session resolves through commit or restoration. Include its production-path regression evidence.
