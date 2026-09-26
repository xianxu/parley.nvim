# Packaged Parley Theme Picker Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `:ParleyTheme`, a compact floating picker that previews and persists four packaged full Neovim colorschemes while preserving a safe startup fallback.

**Architecture:** A pure theme registry owns ids, labels, colorscheme names, contrast/style metadata, and the startup sentinel. A small adapter applies a registry entry, reapplies Parley highlights, and reads/writes one validated preference under Parley’s existing `state_dir`. The existing `float_picker` gets a generic `on_selection_change` callback; the theme picker uses that callback for non-persistent previews and its existing select/cancel hooks for commit/rollback.

**Tech Stack:** Lua, Neovim highlight/colorscheme APIs, lazy.nvim starter dependencies, Plenary/Busted integration tests.

## Core concepts

| Name | Lives in | Status |
|------|----------|--------|
| `DEFAULT` | `lua/parley/theme.lua` | new |
| `items` | `lua/parley/theme.lua` | new |
| `valid_id` | `lua/parley/theme.lua` | new |
| `apply` | `lua/parley/theme.lua` | new |
| `open` | `lua/parley/theme_picker.lua` | new |
| `set_selection` | `lua/parley/float_picker.lua` | modified |

- `ThemeSpec` is an immutable registry row: id, display label, colorscheme command, dark/light mode, colorful/subdued style, and whether it is the startup default.
- `ThemeRegistry` is the only enumeration of choices. It includes Moonfly as the startup/default scheme, the four packaged choices, and a sentinel restore row; callers derive picker items and validation from it (ARCH-DRY, ARCH-PURPOSE).
- `ThemePreference` is the validated persisted id. Missing, unknown, malformed, or unreadable state becomes the default sentinel without raising during startup (ARCH-SECURE).
- `ThemeApplier` applies a colorscheme in the current Neovim process, calls Parley’s existing highlight setup, and returns the observed `vim.g.colors_name`. It never writes preference state; persistence is a separate operation.
- `ThemePicker` owns the open snapshot, preview candidate, commit, and rollback sequence. It delegates layout, cursor movement, mouse selection, and dismissal to `float_picker`.

## Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `save` | `lua/parley/theme.lua` | new | Parley `state_dir` filesystem |
| `lazy` | `packaging/starter-config/init.lua` | modified | lazy.nvim and pinned theme plugins |
| `Theme` | `lua/parley/init.lua` | modified | Neovim user command and current UI |
| `set_selection` | `lua/parley/float_picker.lua` | modified | cursor/mouse selection events |

- `ThemeStateStore` uses the existing atomic file helper or a dedicated one-line state file inside `config.state_dir`; it validates the read value before applying it. Tests use the existing isolated test state root, never the operator’s real profile.
- `ThemeColorschemeLoader` adds pinned Catppuccin, Tokyo Night, and Solarized plugin specs to the packaged starter. Catppuccin supplies both Mocha and Latte; Tokyo Night supplies Storm; Solarized supplies Light. Moonfly remains the default. The adapter tolerates a missing optional scheme by notifying and retaining the prior scheme.
- `ParleyThemeCommand` is registered through the existing command table and calls `ThemePicker.open(_parley)`. Startup invokes the same registry/applier after the starter has loaded the persisted scheme, so normal plugin use and the packaged app share behavior.
- `FloatPickerSelectionChange` is a generic callback invoked after every effective `set_selection`, including keyboard and mouse movement, but not when filtering produces no selected item. It must not alter existing picker behavior when omitted.

## Tasks

### Task 1: Define registry, preference validation, and apply/persistence seams

**Files:**
- Create: `lua/parley/theme.lua`
- Test: `tests/unit/theme_spec.lua`

- [ ] Write pure tests for the five selectable ids, default/sentinel behavior, labels, and dark/light/colorful/subdued metadata.
- [ ] Run the focused unit spec and verify it fails because the registry module is absent.
- [ ] Write tests for malformed, unknown, empty, and valid persisted values using an injected reader/writer; assert invalid values resolve to the startup sentinel without IO errors escaping.
- [ ] Run the focused unit spec and verify the preference tests fail for the missing seam.
- [ ] Implement the registry and pure preference resolver, then add the thin apply/store adapter around `vim.cmd.colorscheme`, `vim.g.colors_name`, Parley highlight setup, and atomic state writes.
- [ ] Run `make test-spec SPEC=theme` or the direct focused unit command and verify green.

### Task 2: Add a generic live-selection hook to the existing picker

**Files:**
- Modify: `lua/parley/float_picker.lua` around `set_selection` and the public option documentation
- Test: `tests/unit/float_picker_spec.lua`

- [ ] Add a failing unit/integration assertion that a selection-change callback receives keyboard and mouse selection changes while `on_select` remains close-time only.
- [ ] Run the focused picker spec and verify the callback assertion fails before implementation.
- [ ] Add optional `on_selection_change(item)` invocation after an effective selection, guard closed/empty states, and preserve recall/filter/resize behavior.
- [ ] Run picker tests, including existing float-picker tests, and verify green.

### Task 3: Build the theme picker and command with preview/commit/rollback

**Files:**
- Create: `lua/parley/theme_picker.lua`
- Modify: `lua/parley/init.lua`
- Test: `tests/integration/theme_picker_spec.lua`

- [ ] Write production-path tests that invoke `:ParleyTheme`, move among rows, observe a changed `vim.g.colors_name` and refreshed Parley groups, then cancel and assert the opening scheme and saved id return.
- [ ] Run the focused integration spec and verify it fails because the command and picker are absent.
- [ ] Implement picker items from the registry, an explicit startup-restore row, snapshot/preview/commit/cancel transitions, and a notification when a packaged scheme cannot load.
- [ ] Register `M.cmd.Theme` so `:ParleyTheme` uses the normal command registration and refresh-state path.
- [ ] Run the focused integration spec and verify green for keyboard movement, `<CR>`, `<Esc>`, and the production mouse mappings or their shared selection callback.

### Task 4: Integrate packaged startup restoration and theme dependencies

**Files:**
- Modify: `packaging/starter-config/init.lua`
- Modify: `packaging/starter-config/README.md`
- Modify: `packaging/README.md`
- Test: `tests/integration/packaging_theme_spec.lua` or the existing packaging integration suite

- [ ] Add a failing packaged-startup test for default Moonfly, a valid persisted selection, and malformed state fallback.
- [ ] Run the packaging-focused spec and verify it fails before starter integration.
- [ ] Add pinned Catppuccin, Tokyo Night, and Solarized specs; load the validated persisted id after lazy setup and before `require("parley.starter").start()`.
- [ ] Document the four choices, `:ParleyTheme`, preview/cancel behavior, and the Moonfly fallback.
- [ ] Run the packaging-focused spec and verify all four schemes load and Parley’s semantic groups remain defined.

### Task 5: Compatibility sweep and verification

**Files:**
- Modify: `tests/integration/theme_picker_spec.lua`
- Modify: `tests/integration/packaging_theme_spec.lua`
- Modify: `atlas/index.md` and the relevant atlas UI/theme map if the repository map has a theme surface
- Modify: `workshop/issues/000275-packaged-theme-picker.md`

- [ ] For every packaged scheme, assert `vim.g.colors_name`, `Normal`, `Comment`, `String`, `Identifier`, `Title`, `NormalFloat`, `FloatBorder`, Parley semantic groups, and the configured statusline groups are available after switching.
- [ ] Exercise repeated preview/cancel cycles and a missing plugin/unknown state path; assert no background handles or temporary files remain.
- [ ] Run focused unit/integration/packaging specs, lint, and the appropriate fresh-clone/package verification.
- [ ] Record actual evidence in the issue Log and reconcile every plan row before the SDLC close boundary.

## Design constraints

- Preview is synchronous and local to the Neovim process; no network or provider request occurs on cursor movement (ARCH-CONSTRAINTS).
- The picker adds no persistent file beyond one validated theme id and removes no existing user configuration (ARCH-FUNERAL/ARCH-SECURE).
- Theme metadata, picker items, startup validation, and compatibility enumeration derive from one registry (ARCH-DRY/ARCH-PURPOSE).
- Existing users can continue to set any external colorscheme in their own config; `:ParleyTheme` only offers schemes that the packaged registry can load and provides startup restore as an explicit escape hatch.
