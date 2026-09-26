---
gate: boundary-review
issue: 275
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-25T20:54:35-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Filtering changes the selected theme without updating its preview
          detail: set_selection compares only row indices, so a different item at the same index receives no selection-change callback.
          family: selection-identity-effects
          round: 1
        - id: BR-2
          severity: Critical
          title: Packaged dependency metadata is maintained outside the theme registry
          detail: The starter has a separate hand-maintained plugin list despite the Spec's single-source requirement.
          family: registry-consumer-derivation
          round: 1
        - id: BR-3
          severity: Critical
          title: Restore startup theme always selects Moonfly
          detail: The command is available to ordinary plugin users whose startup colorscheme may be different.
          family: startup-snapshot-semantics
          round: 1
        - id: BR-4
          severity: Important
          title: Theme acceptance behavior lacks production-path tests
          detail: The committed integration test opens the command but does not verify preview, commit, cancel, mouse input, packaged restoration, or colorscheme compatibility groups.
          family: production-path-coverage
          round: 1
        - id: BR-5
          severity: Important
          title: Preference read errors can escape startup
          detail: readfile is outside the protected decode path, so an unreadable or changing preference file can raise instead of falling back.
          family: untrusted-state-read-failure
          round: 1
        - id: BR-6
          severity: Important
          title: Top-level README omits the new theme command and startup theme
          detail: README.md is unchanged in the pinned range despite the new user-facing command.
          family: user-surface-readme
          round: 1
      recipe: milestone-review
      blocked: true
    - "n": 2
      timestamp: "2026-09-25T20:58:55-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Filtering replaces filtered before set_selection reads previous_item (float_picker.lua:1198, 1224, 1028), so a different theme at the same index still produces no callback. No filtering regression test was added.
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: theme.packaged_plugins() exists (theme.lua:69) but has no consumer; the starter still duplicates every plugin and commit (packaging/starter-config/init.lua:97-105). This is the registry-consumer-derivation rule, not a missing metadata field.
          round: 2
        - id: BR-3
          disposition: not-addressed
          note: The picker passes its opening scheme as the startup scheme (theme_picker.lua:28, 60, 63). After a packaged launch restores a saved theme, selecting Restore startup reapplies that saved theme while persisting the startup sentinel. Ordinary plugin startup also applies Moonfly when that sentinel is loaded (init.lua:1343-1345). No regression test covers either path.
          round: 2
        - id: BR-4
          disposition: not-addressed
          note: The sole production command test asserts only that the picker opens (theme_picker_spec.lua:24-35). It never exercises preview, filtering, commit, cancel, mouse input, packaged restart, or compatibility groups.
          round: 2
        - id: BR-5
          disposition: not-addressed
          note: readfile is now protected (theme.lua:106), but there is no regression test that makes the read fail. The required behavior-changing correction lacks evidence that fails without it.
          round: 2
        - id: BR-6
          disposition: addressed
          note: README.md:47-49 now names :ParleyTheme and Moonfly; the command is registered in init.lua:5107-5108, and Moonfly is the packaged default in theme.lua:7-14.
          round: 2
      recipe: milestone-review
      blocked: true
    - "n": 3
      timestamp: "2026-09-25T21:05:26-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Filtering replaces the list before set_selection reads the previous item; no filtering regression test exists.
          round: 3
        - id: BR-2
          disposition: not-addressed
          note: Registry derivation is wired, but no regression test fails when the starter dependency derivation is removed.
          round: 3
        - id: BR-3
          disposition: not-addressed
          note: The startup row applies opening_scheme, which can be a previously saved nondefault theme; no regression test covers it.
          round: 3
        - id: BR-4
          disposition: not-addressed
          note: The production-command integration test asserts opening only, leaving the specified acceptance transitions and compatibility groups untested.
          round: 3
        - id: BR-5
          disposition: addressed
          note: theme.lua protects readfile with pcall, and theme_spec.lua tests an unreadable file; removing that protection makes the test fail.
          round: 3
        - id: BR-6
          disposition: addressed
          note: The README diff names :ParleyTheme and Moonfly, matching the command registration and registry default.
          round: 3
      findings:
        - id: BR-7
          severity: Critical
          title: Solarized Light loads the dark variant when background is dark
          detail: The registry names a light option but applies colorscheme solarized without setting background=light; the pinned scheme selects its variant from &background. Set and restore the required mode and test the resulting background through the production command.
          family: colorscheme-variant-selection
          round: 3
      recipe: milestone-review
      blocked: true
    - "n": 4
      timestamp: "2026-09-25T21:07:55-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: Item-identity comparison was added at float_picker.lua:1175-1268, but no regression test filters to a different item at the same row; the executable fix lacks required evidence.
          round: 4
        - id: BR-2
          disposition: not-addressed
          note: The starter now calls theme.packaged_plugins at packaging/starter-config/init.lua:100, but no regression test proves its dependency list derives from the registry.
          round: 4
        - id: BR-3
          disposition: not-addressed
          note: The picker captures the opening scheme, but saving startup then restarting an ordinary plugin user still applies Moonfly at lua/parley/init.lua:1343-1345; no production regression test covers the snapshot.
          round: 4
        - id: BR-4
          disposition: not-addressed
          note: The integration test only opens the command; the stated preview, commit, cancel, mouse, packaged restoration, and compatibility assertions are absent.
          round: 4
        - id: BR-7
          disposition: not-addressed
          note: theme.apply now sets background=light before Solarized, but no production-path test asserts the resulting background and colorscheme; the executable fix lacks required regression evidence.
          round: 4
      findings:
        - id: BR-8
          severity: Critical
          title: Failed colorscheme loads leave the previous theme altered
          detail: theme.apply changes vim.o.background at lua/parley/theme.lua:136-137 before the protected colorscheme call. When an optional scheme is unavailable, failure returns without restoring the prior mode or scheme, violating the plan's retain-prior-scheme contract. Restore the snapshot on failure and test this through the production command. ARCH-ORDER.
          family: failed-theme-application-rollback
          round: 4
      recipe: milestone-review
      blocked: true
    - "n": 5
      timestamp: "2026-09-25T22:06:18-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Selection notifications compare identities. Replacing identity comparison with row comparison makes the same-index filtering regression fail.
          round: 5
        - id: BR-2
          disposition: addressed
          note: The starter consumes theme.packaged_plugins(); the bootstrap fixture asserts every registry dependency reaches Lazy with its pin and eager-loading setting.
          round: 5
        - id: BR-3
          disposition: addressed
          note: Startup is captured separately before preference restoration. Hardcoding Moonfly again makes the custom-startup regression fail.
          round: 5
        - id: BR-4
          disposition: not-addressed
          note: Preview, commit, cancel and mouse coverage now exist, but packaged restart restoration remains untested through production startup. The real-plugin compatibility script also never asserts colors_name or OneDark style; disabling variant selection still passes all 19 entries. Complete the acceptance matrix through production entry points and verify each oracle detects removal of its behavior. ARCH-PURPOSE, ARCH-MOCK.
          round: 5
        - id: BR-5
          disposition: addressed
          note: Protected preference reads and the unreadable-file regression remain present; the focused test passes.
          round: 5
        - id: BR-6
          disposition: addressed
          note: README.md documents ParleyTheme, Moonfly startup, persistence and cancellation, matching command registration and picker callbacks.
          round: 5
        - id: BR-7
          disposition: addressed
          note: Application sets the registry background mode. Removing that assignment for Solarized makes the production-command light-mode regression fail.
          round: 5
        - id: BR-8
          disposition: addressed
          note: Failed application restores the previous snapshot. Removing rollback makes the partial-highlight-failure regression fail.
          round: 5
      recipe: milestone-review
      blocked: false
    - "n": 6
      timestamp: "2026-09-25T22:12:18-07:00"
      agent: codex
      dispose:
        - id: BR-4
          disposition: addressed
          note: Production-command tests cover preview, commit, cancellation, mouse mappings, and failed loads. Fresh starter tests cover persisted choices and fallback. Independently removing startup restoration in a scratch copy fails both saved-choice tests. The real compatibility matrix passes all 19 entries against verified plugin pins.
          round: 6
        - id: BR-1
          disposition: addressed
          note: Selection notifications compare item identity; the production filter-change regression passes.
          round: 6
        - id: BR-2
          disposition: addressed
          note: Starter dependencies derive from packaged_plugins(), with registry-derived dependency assertions in the bootstrap fixture.
          round: 6
        - id: BR-3
          disposition: addressed
          note: Startup is captured before preference restoration; fresh-process saved-theme and startup-sentinel assertions pass.
          round: 6
        - id: BR-5
          disposition: addressed
          note: Preference reads protect readfile with pcall; the unreadable-state regression passes.
          round: 6
        - id: BR-6
          disposition: addressed
          note: README.md now documents :ParleyTheme, Moonfly startup, Enter persistence, and Escape restoration, matching the implemented command.
          round: 6
        - id: BR-7
          disposition: addressed
          note: Solarized declares light mode; both production-command and real-plugin checks pass.
          round: 6
        - id: BR-8
          disposition: addressed
          note: Failed application restores the previous snapshot; production-command tests verify appearance and unchanged preference after partial failure and missing packages.
          round: 6
      findings:
        - id: BR-9
          severity: Critical
          title: Confirming no matches closes the picker without resolving its preview
          detail: 'lua/parley/float_picker.lua:1111-1121 closes unconditionally but invokes on_select only when an item exists; it never invokes on_cancel for empty results. Reproduced through :ParleyTheme: preview dayfox, filter to no matches, press Enter. Both floats close and no preference is saved, but dayfox remains instead of the opening Moonfly. Enforce the rule that every preview-session exit commits a valid selection or restores the opening snapshot; alternatively keep empty confirmation open. Enumerate terminal paths and add a production-command regression (ARCH-ORDER, ARCH-PURPOSE).'
          family: preview-terminal-outcomes
          round: 6
      recipe: milestone-review
      blocked: true
    - "n": 7
      timestamp: "2026-09-25T22:17:32-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Selection notifications compare item identity; the production filter-change regression passes.
          round: 7
        - id: BR-2
          disposition: addressed
          note: Starter dependencies derive from theme.packaged_plugins(); bootstrap tests check registry-derived pins.
          round: 7
        - id: BR-3
          disposition: addressed
          note: Startup capture precedes preference restoration; startup and opening-snapshot tests pass.
          round: 7
        - id: BR-4
          disposition: addressed
          note: Production command and fresh starter subprocess tests exercise selection, persistence, and restoration.
          round: 7
        - id: BR-5
          disposition: addressed
          note: Preference reads catch readfile failures; the unreadable-state regression passes.
          round: 7
        - id: BR-6
          disposition: addressed
          note: README.md now documents ParleyTheme, Moonfly, confirmation, and cancellation, matching the implementation.
          round: 7
        - id: BR-7
          disposition: addressed
          note: Solarized specifies light mode, applied before colorscheme loading; its production-command regression passes.
          round: 7
        - id: BR-8
          disposition: addressed
          note: Failed application restores the previous snapshot; the partial-highlight-failure regression passes.
          round: 7
        - id: BR-9
          disposition: addressed
          note: Empty confirmation dismisses through on_cancel; failed load/save confirmation also restores the opening snapshot. Reverting the two production files to their parent versions in a scratch copy makes all three regressions fail with dayfox instead of moonfly.
          round: 7
      findings:
        - id: BR-10
          severity: Critical
          title: Standalone starter requires Parley before installing or loading it
          detail: packaging/starter-config/init.lua:9 unconditionally requires parley.theme before Lazy bootstrap. The documented standalone launch without PARLEY_RUNTIME fails immediately with module 'parley.theme' not found. Establish the Parley runtime before consuming its registry, retaining one metadata source, and add fresh/cached standalone startup regressions without PARLEY_RUNTIME (ARCH-PURPOSE).
          family: dependency-bootstrap-order
          round: 7
      recipe: milestone-review
      blocked: true
    - "n": 8
      timestamp: "2026-09-25T22:25:58-07:00"
      agent: codex
      dispose:
        - id: BR-10
          disposition: addressed
          note: packaging/starter-config/init.lua:80-104 establishes the standalone runtime before requiring the registry. Fresh/cached startup and failure-cleanup tests pass; replacing the starter with its parent revision in a scratch copy makes all three new regressions fail.
          round: 8
      recipe: milestone-review
      blocked: false
---

# Gate ledger — parley.nvim#275 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-25T20:54:35-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `selection-identity-effects` Filtering changes the selected theme without updating its preview
  set_selection compares only row indices, so a different item at the same index receives no selection-change callback.
- **BR-2** [Critical] `registry-consumer-derivation` Packaged dependency metadata is maintained outside the theme registry
  The starter has a separate hand-maintained plugin list despite the Spec's single-source requirement.
- **BR-3** [Critical] `startup-snapshot-semantics` Restore startup theme always selects Moonfly
  The command is available to ordinary plugin users whose startup colorscheme may be different.
- **BR-4** [Important] `production-path-coverage` Theme acceptance behavior lacks production-path tests
  The committed integration test opens the command but does not verify preview, commit, cancel, mouse input, packaged restoration, or colorscheme compatibility groups.
- **BR-5** [Important] `untrusted-state-read-failure` Preference read errors can escape startup
  readfile is outside the protected decode path, so an unreadable or changing preference file can raise instead of falling back.
- **BR-6** [Important] `user-surface-readme` Top-level README omits the new theme command and startup theme
  README.md is unchanged in the pinned range despite the new user-facing command.

## Round 2 — 2026-09-25T20:58:55-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — Filtering replaces filtered before set_selection reads previous_item (float_picker.lua:1198, 1224, 1028), so a different theme at the same index still produces no callback. No filtering regression test was added.
- BR-2 — not-addressed — theme.packaged_plugins() exists (theme.lua:69) but has no consumer; the starter still duplicates every plugin and commit (packaging/starter-config/init.lua:97-105). This is the registry-consumer-derivation rule, not a missing metadata field.
- BR-3 — not-addressed — The picker passes its opening scheme as the startup scheme (theme_picker.lua:28, 60, 63). After a packaged launch restores a saved theme, selecting Restore startup reapplies that saved theme while persisting the startup sentinel. Ordinary plugin startup also applies Moonfly when that sentinel is loaded (init.lua:1343-1345). No regression test covers either path.
- BR-4 — not-addressed — The sole production command test asserts only that the picker opens (theme_picker_spec.lua:24-35). It never exercises preview, filtering, commit, cancel, mouse input, packaged restart, or compatibility groups.
- BR-5 — not-addressed — readfile is now protected (theme.lua:106), but there is no regression test that makes the read fail. The required behavior-changing correction lacks evidence that fails without it.
- BR-6 — addressed — README.md:47-49 now names :ParleyTheme and Moonfly; the command is registered in init.lua:5107-5108, and Moonfly is the packaged default in theme.lua:7-14.

## Round 3 — 2026-09-25T21:05:26-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — Filtering replaces the list before set_selection reads the previous item; no filtering regression test exists.
- BR-2 — not-addressed — Registry derivation is wired, but no regression test fails when the starter dependency derivation is removed.
- BR-3 — not-addressed — The startup row applies opening_scheme, which can be a previously saved nondefault theme; no regression test covers it.
- BR-4 — not-addressed — The production-command integration test asserts opening only, leaving the specified acceptance transitions and compatibility groups untested.
- BR-5 — addressed — theme.lua protects readfile with pcall, and theme_spec.lua tests an unreadable file; removing that protection makes the test fail.
- BR-6 — addressed — The README diff names :ParleyTheme and Moonfly, matching the command registration and registry default.

### Raised

- **BR-7** [Critical] `colorscheme-variant-selection` Solarized Light loads the dark variant when background is dark
  The registry names a light option but applies colorscheme solarized without setting background=light; the pinned scheme selects its variant from &background. Set and restore the required mode and test the resulting background through the production command.

## Round 4 — 2026-09-25T21:07:55-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — Item-identity comparison was added at float_picker.lua:1175-1268, but no regression test filters to a different item at the same row; the executable fix lacks required evidence.
- BR-2 — not-addressed — The starter now calls theme.packaged_plugins at packaging/starter-config/init.lua:100, but no regression test proves its dependency list derives from the registry.
- BR-3 — not-addressed — The picker captures the opening scheme, but saving startup then restarting an ordinary plugin user still applies Moonfly at lua/parley/init.lua:1343-1345; no production regression test covers the snapshot.
- BR-4 — not-addressed — The integration test only opens the command; the stated preview, commit, cancel, mouse, packaged restoration, and compatibility assertions are absent.
- BR-7 — not-addressed — theme.apply now sets background=light before Solarized, but no production-path test asserts the resulting background and colorscheme; the executable fix lacks required regression evidence.

### Raised

- **BR-8** [Critical] `failed-theme-application-rollback` Failed colorscheme loads leave the previous theme altered
  theme.apply changes vim.o.background at lua/parley/theme.lua:136-137 before the protected colorscheme call. When an optional scheme is unavailable, failure returns without restoring the prior mode or scheme, violating the plan's retain-prior-scheme contract. Restore the snapshot on failure and test this through the production command. ARCH-ORDER.

## Round 5 — 2026-09-25T22:06:18-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Selection notifications compare identities. Replacing identity comparison with row comparison makes the same-index filtering regression fail.
- BR-2 — addressed — The starter consumes theme.packaged_plugins(); the bootstrap fixture asserts every registry dependency reaches Lazy with its pin and eager-loading setting.
- BR-3 — addressed — Startup is captured separately before preference restoration. Hardcoding Moonfly again makes the custom-startup regression fail.
- BR-4 — not-addressed — Preview, commit, cancel and mouse coverage now exist, but packaged restart restoration remains untested through production startup. The real-plugin compatibility script also never asserts colors_name or OneDark style; disabling variant selection still passes all 19 entries. Complete the acceptance matrix through production entry points and verify each oracle detects removal of its behavior. ARCH-PURPOSE, ARCH-MOCK.
- BR-5 — addressed — Protected preference reads and the unreadable-file regression remain present; the focused test passes.
- BR-6 — addressed — README.md documents ParleyTheme, Moonfly startup, persistence and cancellation, matching command registration and picker callbacks.
- BR-7 — addressed — Application sets the registry background mode. Removing that assignment for Solarized makes the production-command light-mode regression fail.
- BR-8 — addressed — Failed application restores the previous snapshot. Removing rollback makes the partial-highlight-failure regression fail.

## Round 6 — 2026-09-25T22:12:18-07:00 (codex) — BLOCKED

### Disposed

- BR-4 — addressed — Production-command tests cover preview, commit, cancellation, mouse mappings, and failed loads. Fresh starter tests cover persisted choices and fallback. Independently removing startup restoration in a scratch copy fails both saved-choice tests. The real compatibility matrix passes all 19 entries against verified plugin pins.
- BR-1 — addressed — Selection notifications compare item identity; the production filter-change regression passes.
- BR-2 — addressed — Starter dependencies derive from packaged_plugins(), with registry-derived dependency assertions in the bootstrap fixture.
- BR-3 — addressed — Startup is captured before preference restoration; fresh-process saved-theme and startup-sentinel assertions pass.
- BR-5 — addressed — Preference reads protect readfile with pcall; the unreadable-state regression passes.
- BR-6 — addressed — README.md now documents :ParleyTheme, Moonfly startup, Enter persistence, and Escape restoration, matching the implemented command.
- BR-7 — addressed — Solarized declares light mode; both production-command and real-plugin checks pass.
- BR-8 — addressed — Failed application restores the previous snapshot; production-command tests verify appearance and unchanged preference after partial failure and missing packages.

### Raised

- **BR-9** [Critical] `preview-terminal-outcomes` Confirming no matches closes the picker without resolving its preview
  lua/parley/float_picker.lua:1111-1121 closes unconditionally but invokes on_select only when an item exists; it never invokes on_cancel for empty results. Reproduced through :ParleyTheme: preview dayfox, filter to no matches, press Enter. Both floats close and no preference is saved, but dayfox remains instead of the opening Moonfly. Enforce the rule that every preview-session exit commits a valid selection or restores the opening snapshot; alternatively keep empty confirmation open. Enumerate terminal paths and add a production-command regression (ARCH-ORDER, ARCH-PURPOSE).

## Round 7 — 2026-09-25T22:17:32-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Selection notifications compare item identity; the production filter-change regression passes.
- BR-2 — addressed — Starter dependencies derive from theme.packaged_plugins(); bootstrap tests check registry-derived pins.
- BR-3 — addressed — Startup capture precedes preference restoration; startup and opening-snapshot tests pass.
- BR-4 — addressed — Production command and fresh starter subprocess tests exercise selection, persistence, and restoration.
- BR-5 — addressed — Preference reads catch readfile failures; the unreadable-state regression passes.
- BR-6 — addressed — README.md now documents ParleyTheme, Moonfly, confirmation, and cancellation, matching the implementation.
- BR-7 — addressed — Solarized specifies light mode, applied before colorscheme loading; its production-command regression passes.
- BR-8 — addressed — Failed application restores the previous snapshot; the partial-highlight-failure regression passes.
- BR-9 — addressed — Empty confirmation dismisses through on_cancel; failed load/save confirmation also restores the opening snapshot. Reverting the two production files to their parent versions in a scratch copy makes all three regressions fail with dayfox instead of moonfly.

### Raised

- **BR-10** [Critical] `dependency-bootstrap-order` Standalone starter requires Parley before installing or loading it
  packaging/starter-config/init.lua:9 unconditionally requires parley.theme before Lazy bootstrap. The documented standalone launch without PARLEY_RUNTIME fails immediately with module 'parley.theme' not found. Establish the Parley runtime before consuming its registry, retaining one metadata source, and add fresh/cached standalone startup regressions without PARLEY_RUNTIME (ARCH-PURPOSE).

## Round 8 — 2026-09-25T22:25:58-07:00 (codex) — passed

### Disposed

- BR-10 — addressed — packaging/starter-config/init.lua:80-104 establishes the standalone runtime before requiring the registry. Fresh/cached startup and failure-cleanup tests pass; replacing the starter with its parent revision in a scratch copy makes all three new regressions fail.

## Open findings

(none — every finding has been disposed)
