# Persistent Repo/Super-Repo Mode Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist each repository's explicit repo/peer mode choice, restore it synchronously at startup, remove brain-only behavior, and migrate the peer/branch keybindings without a tool-fold collision.

**Architecture:** A new pure `repo_mode` module owns validation, selection, and immutable updates of the canonical-root-keyed preference map. `init.lua` owns orchestration: it serializes transient-safe state through one atomic write-only boundary, restores mode once after all setup refreshes, and persists only successful explicit toggles. The existing keybinding registry gains optional-default resolution so one configurable action may intentionally remain unbound.

**Tech Stack:** Lua, Neovim APIs, plenary/busted tests, Markdown atlas/docs.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `repo_mode.resolve` | `lua/parley/repo_mode.lua` | new |
| `repo_mode.updated` | `lua/parley/repo_mode.lua` | new |
| `keybinding_registry.resolve_keys` | `lua/parley/keybinding_registry.lua` | modified |

- **`repo_mode.resolve`** — selects only exact `repo`/`super_repo` values for one already-canonical repository root.
  - **Relationships:** N:1 preferences-to-repository map lookup; the caller owns the map and canonical root.
  - **DRY rationale:** Startup restoration and toggle persistence must share one validity rule.
  - **Future extensions:** Additional explicitly modeled repo modes widen the allowed-value set here.
- **`repo_mode.updated`** — returns a fresh sanitized preference map with one repository choice replaced.
  - **Relationships:** one input map produces one independent output map; valid entries for other roots are preserved.
  - **DRY rationale:** Both toggle directions need identical immutable filtering and replacement.
  - **Future extensions:** Migration/version policy can be added without coupling it to Neovim IO.
- **`keybinding_registry.resolve_keys`** — resolves configured shortcuts while allowing an entry to have no default key.
  - **Relationships:** one registry entry plus one config table resolves to zero-or-more keys and modes.
  - **DRY rationale:** Registration and help already consume this single resolver; teaching it the unbound state prevents parallel special cases.
  - **Future extensions:** Other opt-in actions can use the same optional-default contract.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `helper.table_to_file_atomic` | `lua/parley/helper.lua` | new | JSON encoding, temporary-file IO, atomic rename |
| `parley.persist_state` | `lua/parley/init.lua` | new | live state sanitization and `state.json` persistence |
| `parley.setup` mode restoration | `lua/parley/init.lua` | modified | setup ordering, canonical filesystem roots, saved preference |
| `parley.toggle_super_repo` | `lua/parley/init.lua` | modified | runtime overlay transition, durable preference, bounded warning |
| `super_repo.set_active` | `lua/parley/super_repo.lua` | new | non-persisting runtime overlay activation/deactivation |

- **`helper.table_to_file_atomic`** — writes encoded JSON beside the destination, renames only after a complete close, reports `(true)` or `(false, err)`, and leaves the prior file intact on failure.
  - **Injected into:** `parley.persist_state` through `M.helpers`, allowing failure tests to substitute a deterministic fake.
  - **Future extensions:** Other durable JSON stores can opt into atomic replacement without changing legacy `table_to_file` consumers.
- **`parley.persist_state`** — builds the single transient-safe state snapshot and sends it to the atomic writer without reloading disk state or live roots.
  - **Injected into:** `refresh_state` and explicit peer-mode toggle persistence.
  - **Future extensions:** Additional transient fields are filtered at this one policy boundary.
- **`parley.setup` mode restoration** — after the base and optional default-agent refreshes, resolves the canonical current repo preference and calls the non-persisting runtime transition exactly once.
  - **Injected into:** normal plugin setup; production-path tests use real temporary repositories and `state.json`.
  - **Future extensions:** Setup migrations remain ordered before this final mode application.
- **`parley.toggle_super_repo`** — persists the resulting preference only after a successful explicit runtime transition; persistence failure keeps runtime state and warns once.
  - **Injected into:** public Lua API and the existing global keybinding callback.
  - **Future extensions:** Commands or status UI continue calling the same public transition.
- **`super_repo.set_active`** — exposes idempotent activation/deactivation without owning preference IO.
  - **Injected into:** setup restoration and explicit toggle orchestration.
  - **Future extensions:** Additional restoration callers avoid impersonating a user toggle.

## Chunk 1: Pure preference and durable state boundaries

### Task 1: Add the pure repository-mode policy

**Files:**
- Create: `lua/parley/repo_mode.lua`
- Create: `tests/unit/repo_mode_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Write failing pure-policy tests**

Cover `resolve(repo_modes, canonical_root)` returning `nil` for non-table maps, empty/non-string roots, missing entries, and unknown values; returning exact valid values; and keeping repo A isolated from repo B. Cover `updated(repo_modes, root, mode)` returning a fresh map, preserving only valid entries with non-empty string roots, discarding malformed entries, replacing the current root, starting empty for non-table input, and never mutating its input.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

Expected: FAIL because `parley.repo_mode` does not exist.

- [ ] **Step 3: Implement the minimal pure module**

Create `repo_mode.resolve` and `repo_mode.updated` around one private exact-value predicate. Do not call `vim`, touch files, or mutate arguments. Add the module and unit spec to the existing `modes/super_repo` traceability entry.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/repo_mode_spec.lua" -c "qa!"`

Expected: PASS with zero failures.

- [ ] **Step 5: Commit the pure policy**

Commit: `super-repo: #190 add pure persisted-mode policy`

### Task 2: Add atomic JSON replacement and one write-only state boundary

**Files:**
- Modify: `lua/parley/helper.lua`
- Modify: `tests/unit/helper_io_spec.lua`
- Modify: `lua/parley/init.lua`
- Modify: `tests/unit/super_repo_spec.lua`

- [ ] **Step 1: Write failing atomic-writer tests**

Add tests proving `table_to_file_atomic` returns true and round-trips nested JSON. Through an optional IO adapter, force write, close, and rename failures independently; each must return false plus a bounded error, remove its unique sibling temporary file, and preserve pre-existing destination bytes byte-for-byte. Encoding happens before any destination-adjacent file is opened, so an encode exception is inherently destination-safe and must also return a bounded failure.

- [ ] **Step 2: Run helper IO tests and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

Expected: FAIL because `table_to_file_atomic` is undefined.

- [ ] **Step 3: Implement atomic replacement**

Encode before opening, write to a unique sibling temporary path, check write/close outcomes, rename to the destination, remove the temporary file on every failure, and return a result. Keep legacy `table_to_file` behavior unchanged for unrelated consumers.

- [ ] **Step 4: Run helper IO tests and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/helper_io_spec.lua" -c "qa!"`

Expected: PASS with zero failures.

- [ ] **Step 5: Write failing state-boundary regressions**

Add production-facing tests that call the wished-for `parley.persist_state()`: it must omit `chat_roots`/`chat_dirs`, repo-labeled and super-repo-pushed note roots; preserve durable scalar state and `repo_modes`; and leave the active overlay roots byte-for-byte unchanged. Add an injected writer-failure test asserting `(false, err)`, no root reload/mutation, and that the writer received the correctly sanitized snapshot before failing.

- [ ] **Step 6: Run mapped state tests and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because `parley.persist_state` is undefined.

- [ ] **Step 7: Extract and reuse the persistence boundary**

Move the snapshot/filter/write tail of `refresh_state` into `M.persist_state()`, returning the atomic writer result. Make `refresh_state` call it once after its load/update/root-restoration work. Keep display refresh in `refresh_state`, not the write-only function.

- [ ] **Step 8: Run mapped state tests and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures and unchanged live roots.

- [ ] **Step 9: Commit the persistence boundary**

Commit: `state: #190 add atomic write-only persistence`

## Chunk 2: Startup restoration and explicit toggle persistence

### Task 3: Restore and persist mode through production orchestration

**Files:**
- Modify: `lua/parley/super_repo.lua`
- Modify: `lua/parley/init.lua`
- Modify: `tests/unit/super_repo_spec.lua`
- Modify: `atlas/traceability.yaml`

- [ ] **Step 1: Write failing runtime-transition tests**

Add tests for `super_repo.set_active(true|false)` being idempotent and non-persisting. Through `parley.toggle_super_repo`, assert successful on/off transitions update the current canonical root in `repo_modes`, preserve valid peer entries, and atomically persist; activation failure changes neither runtime state nor saved preference. Add a successful-runtime/failed-save regression starting from an existing state file: runtime and in-memory preference change, durable bytes remain identical, exactly one bounded warning contains “preference not saved,” and no success notification is emitted.

- [ ] **Step 2: Run the super-repo spec and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because `set_active` and toggle persistence are absent.

- [ ] **Step 3: Implement explicit transition orchestration**

Export idempotent `super_repo.set_active(active)` as the non-persisting overlay API. Make `M.toggle_super_repo()` call the runtime toggle, update `M._state.repo_modes` through `repo_mode.updated` only on success, then call `M.persist_state`. On write failure, retain runtime mode and in-memory choice while emitting one bounded warning containing “preference not saved”; preserve the existing boolean runtime-transition return contract so callers do not misread persistence failure as transition failure.

- [ ] **Step 4: Run the super-repo spec and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures.

- [ ] **Step 5: Write failing production-path startup tests**

Create temporary current/sibling repositories with `.parley`, pre-seed `state.json` under the configured state directory, supply a valid `default_agent`, and call real `parley.setup()`. Assert that setup returns with super-repo active, complete sibling chat/note roots, and member config; no later `VimEnter` is required. Spy on the atomic writer, account for the expected initial/default-agent refresh writes, assert every refresh payload preserves the saved preference, and prove restoration adds no writer call after `super_repo.set_active`. Add cases for unsaved default repo mode, explicit saved repo mode, per-repo isolation, canonical/symlink root lookup, invalid values, and an unsaved `.brain` repository remaining ordinary after setup plus synthetic `VimEnter`. For failed saved-super restoration, assert ordinary mode remains usable, the final saved preference remains `"super_repo"`, no post-transition write occurs, and exactly one bounded warning is emitted.

- [ ] **Step 6: Run the startup tests and verify RED**

Run: `make test-spec SPEC=modes/super_repo`

Expected: FAIL because setup does not restore saved preferences and still installs brain-specific `VimEnter` behavior.

- [ ] **Step 7: Restore once after setup refreshes and remove brain treatment**

Delete the `.brain` autocmd block. After the initial `refresh_state()` and optional default-agent `refresh_state(...)`, canonicalize `M.config.repo_root`, resolve its saved mode, and call `super_repo.set_active(mode == "super_repo")` exactly once for repo mode. Do nothing in global mode. A failed saved-super activation keeps the preference and uses the existing bounded warning path. Map the policy, state persistence, runtime transition, setup restoration, and toggle orchestration surfaces to `tests/unit/repo_mode_spec.lua`, `tests/unit/helper_io_spec.lua`, and `tests/unit/super_repo_spec.lua` in traceability.

- [ ] **Step 8: Run the startup tests and verify GREEN**

Run: `make test-spec SPEC=modes/super_repo`

Expected: PASS with zero failures; the default-agent case includes all sibling roots immediately on return.

- [ ] **Step 9: Commit startup and toggle persistence**

Commit: `super-repo: #190 persist and restore peer mode`

## Chunk 3: Optional keybindings, documentation, and verification

### Task 4: Migrate peer/branch defaults and make tool folds opt-in

**Files:**
- Modify: `lua/parley/config.lua`
- Modify: `lua/parley/keybinding_registry.lua`
- Modify: `tests/unit/keybindings_spec.lua`
- Modify: `tests/unit/config_tools_spec.lua`

- [ ] **Step 1: Write failing registry and mapping tests**

Assert defaults resolve peer toggle to `<C-g>p` in normal/insert, chat prune to `<C-g>b` in normal, and tool-fold to no keys. Assert an entry with no default is valid; absent or empty-string tool-fold configuration produces neither mapping nor help row; and a user config `{ modes = { "n" }, shortcut = "<leader>tf" }` restores both registration and help through the shared resolver.

- [ ] **Step 2: Run keybinding tests and verify RED**

Run: `make test-spec SPEC=ui/keybindings`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/config_tools_spec.lua" -c "qa!"`

Expected: both fail on the old defaults, mandatory `default_key` invariant, and configured tool-fold default.

- [ ] **Step 3: Implement optional-default resolution and new defaults**

Set the peer and prune defaults in both config and registry. Remove the tool-fold default config value and registry `default_key`, retain its `config_key`, modes, callback, and descriptions. Treat nil/empty shortcuts as unbound. Make help skip entries resolving to no key, while registration naturally skips them; relax the registry invariant only for configurable entries.

- [ ] **Step 4: Run keybinding and config tests and verify GREEN**

Run: `make test-spec SPEC=ui/keybindings`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/config_tools_spec.lua" -c "qa!"`

Expected: both PASS with zero failures.

- [ ] **Step 5: Commit the keybinding migration**

Commit: `keybindings: #190 use peer and branch mnemonics`

### Task 5: Reconcile documentation and close-ready evidence

**Files:**
- Modify: `README.md`
- Modify: `atlas/index.md`
- Modify: `atlas/modes/super_repo.md`
- Modify: `atlas/infra/repo_mode.md`
- Modify: `atlas/chat/lifecycle.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000190-persist-repo-super-repo-state-across-nvim-sessions.md`
- Modify: `workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md`

- [ ] **Step 1: Update every user-facing description**

Document `<C-g>p` as peer-mode toggle, `<C-g>b` as branch/prune, tool-fold as configurable with no default, per-canonical-repo persistence in `state.json`, ordinary unsaved default, synchronous startup restore, and brain parity. Add README discoverability for the peer toggle and configuration override.

- [ ] **Step 2: Search for stale behavior and resolve every relevant hit**

Run: `rg -n '<C-g>S|Pruning \(`<C-g>p`\)|chat_shortcut_toggle_tool_folds.*<C-g>b|Brain repos auto|Toggle is transient|never persisted' README.md atlas lua tests`

Expected: no stale assertions; fixture strings that intentionally test migration must be labeled as such or updated.

- [ ] **Step 3: Run mapped tests and static checks**

Before running mapped tests, confirm `atlas/traceability.yaml` maps optional-default registry/help behavior to `keybindings_spec.lua`, default-config migration to `config_tools_spec.lua`, repository-mode policy to `repo_mode_spec.lua`, atomic JSON writes to `helper_io_spec.lua`, and persistence/startup/toggle orchestration to `super_repo_spec.lua`. Extend the existing `modes/super_repo`, `ui/keybindings`, and `chat/lifecycle` entries and add an `infra/repo_mode` entry so every changed atlas file is mapped. Run these concrete selection checks and verify every intended test is selected:

Run: `scripts/spec_test_map.sh list-tests modes/super_repo`

Run: `scripts/spec_test_map.sh list-tests ui/keybindings`

Run: `scripts/spec_test_map.sh list-tests infra/repo_mode`

Run: `scripts/spec_test_map.sh list-tests chat/lifecycle`

Run: `make test-changed`

Run: `make lint`

Run: `git diff --check`

Expected: all commands exit 0 with no failures or whitespace errors.

- [ ] **Step 4: Run the full suite**

Run: `make test`

Expected: exit 0 with zero failing tests.

- [ ] **Step 5: Reconcile artifacts and commit**

Check every completed issue and durable-plan box, append implementation discoveries and exact verification evidence to `## Log`, and ensure atlas index/traceability stay consistent.

Commit: `docs: #190 document persistent peer mode`

- [ ] **Step 6: Prepare and invoke the close boundary**

Run `sdlc actual --issue 190`, then `sdlc close --issue 190 --verified '<fresh mapped/full test, lint, diff-check, and smoke-test evidence>'`, using only the precise `--no-atlas`/other gate flag if the command identifies a genuinely inapplicable guard. Let `sdlc close` dispatch the mandatory fresh-context boundary review; fix all Critical/Important findings before shipping.

## Revisions

### 2026-07-15 — fresh-context plan review

- Reason: review found missing failure-path oracles and incomplete traceability/test command coverage.
- Delta: added write/close/rename atomic preservation tests, exact successful-runtime/failed-save warning assertions, zero-write startup restoration checks, explicit traceability mappings, both RED keybinding/config runs, and empty-shortcut behavior; removed an unused `chat_dirs_spec.lua` modification.

### 2026-07-15 — plan re-review sequencing correction

- Reason: re-review found that setup refresh writes make original-file byte equality an invalid oracle for restoration and that one traceability command remained symbolic.
- Delta: count expected refresh writes and forbid only post-restoration writes while preserving `repo_modes`; name concrete traceability keys and selection commands for every changed atlas surface.
