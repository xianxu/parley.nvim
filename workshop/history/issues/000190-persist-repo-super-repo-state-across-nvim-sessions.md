---
id: 000190
status: done
deps: []
github_issue:
created: 2026-07-15
updated: 2026-07-15
estimate_hours: 2.75
started: 2026-07-15T12:00:53-07:00
actual_hours: 4.81
---

# persist repo super-repo state across nvim sessions

## Problem

Repo mode is derived from the current `.parley` repository, but super-repo mode
is a transient overlay. A user who prefers peer aggregation for one repository
must re-enable it in every Neovim session. Brain repositories currently receive
a separate automatic super-repo rule, so startup behavior depends on repository
type rather than the user's explicit choice.

The mode toggle also uses `<C-g>S`, while the desired mnemonic is `<C-g>p` for
“peer.” That key is currently used by chat pruning, and the agreed replacement
`<C-g>b` is currently used by the optional tool-fold toggle.

## Spec

- Persist an explicit mode preference per `.parley` repository in Parley's
  existing `state.json`. The stored shape is a `repo_modes` map from canonical,
  resolved repository-root paths to exactly `"repo"` or `"super_repo"`.
- A repository with no saved entry starts in ordinary repo mode. Global mode
  outside a `.parley` repository remains unchanged and does not create a
  preference.
- Remove all `.brain`-specific startup behavior. Brain repositories follow the
  same saved-preference/default rules as every other `.parley` repository; a
  saved ordinary-repo choice therefore overrides the former automatic overlay.
- Restore a saved `"super_repo"` preference only after repo-local chat/note
  roots and persisted state have settled. Restoration activates the existing
  super-repo overlay before normal use without rewriting the preference.
- After all setup-time state refreshes have completed, including the optional
  default-agent refresh, `setup()` synchronously resolves and applies the saved
  mode exactly once before returning. Restoration must not depend on a future
  `VimEnter` event and must use a non-persisting activation path.
- A successful user toggle immediately records the resulting mode for the
  current canonical repo root. Toggling on records `"super_repo"`; toggling off
  records `"repo"`. Failed activation leaves both the runtime mode and saved
  preference unchanged.
- Unknown values, malformed maps, or entries for other repositories are ignored
  without error. If a valid saved super-repo preference cannot be activated,
  Parley remains usable in ordinary repo mode, keeps the saved preference for a
  future session, and uses the existing bounded warning path.
- Selection treats a non-table `repo_modes` value as empty and recognizes only
  exact `"repo"`/`"super_repo"` values for the current canonical root. Updating
  a malformed map starts from empty; otherwise it returns a fresh map that
  preserves entries for other non-empty string roots only when their value is
  valid, discards invalid entries, and replaces only the current root. It never
  mutates the caller's map.
- Keep runtime roots transient: `chat_roots`, `chat_dirs`, and super-repo-pushed
  note roots must remain absent from persisted state. Extract the current state
  serialization/write policy into one reusable write-only boundary so saving a
  mode preference does not run the full state reload/root-restoration path
  (`ARCH-DRY`, `ARCH-PURE`).
- The write-only state boundary reports success/failure and replaces
  `state.json` atomically, so a failed preference save leaves the previous
  durable file intact. If the runtime transition succeeds but persistence
  fails, keep the resulting runtime mode, keep the last durable preference,
  and emit one bounded warning that explicitly says the preference was not
  saved; do not report persistence success.
- Keep preference selection/updates in a small deterministic core: resolving a
  mode from `(repo_modes, canonical_root)` and returning an updated fresh map
  must not mutate callers. Neovim filesystem resolution and JSON IO stay in the
  adapter (`ARCH-PURE`).
- Change the global peer-mode toggle default from `<C-g>S` to `<C-g>p` in normal
  and insert mode. Change chat branch/prune from `<C-g>p` to `<C-g>b` in normal
  mode. Remove the default key for `chat_shortcut_toggle_tool_folds`; users may
  still assign that configurable action their own shortcut.
- Extend the shared keybinding registry to support configured actions with no
  default shortcut. An unconfigured tool-fold action registers no mapping and
  appears in no keybinding-help row; a non-empty user shortcut registers and is
  displayed through the existing registry path, with the callback unchanged
  (`ARCH-DRY`).
- Update help, README, and atlas descriptions so “peer,” persistence, default
  behavior, brain parity, and the two keybinding migrations agree with code
  (`ARCH-PURPOSE`).

## Done when

- A repo explicitly left in super-repo mode reopens in super-repo mode in a new
  Neovim setup/session, while another repo with no preference opens in repo mode.
- A production-path setup test pre-seeds `state.json`, supplies a default agent,
  calls `setup()` without a future `VimEnter` trigger, and observes both active
  super-repo mode and the complete live sibling chat/note overlay immediately
  on return. An unsaved `.brain` repo remains in repo mode both after setup and
  after a synthetic `VimEnter`.
- Toggling back to repo mode persists and prevents a later session—including in
  a brain repo—from auto-enabling super-repo mode.
- Mode persistence never restores transient sibling chat/note roots from disk
  and never disturbs the live overlay while saving a toggle.
- Invalid stored preferences and failed restoration degrade to ordinary repo
  mode without corrupting the stored map.
- Mixed valid/invalid maps preserve other valid repo choices while discarding
  invalid entries; a write-failure regression proves the runtime transition,
  unchanged durable file, and one bounded “preference not saved” warning.
- `<C-g>p` toggles peer aggregation, `<C-g>b` branches/prunes a chat, and the
  tool-fold action has no default collision.
- With no configured tool-fold shortcut, neither a mapping nor help row exists;
  assigning one restores both through the shared registry.
- Automated tests cover per-repo isolation, canonical-root lookup, immutable
  preference updates, first-run defaulting, startup restoration, toggle-on/off
  persistence, brain parity, failure preservation, transient-root filtering,
  and the keybinding defaults.

## Plan

- [x] Add the pure per-repo mode-preference policy and focused tests.
- [x] Extract reusable state serialization and integrate startup/toggle
  persistence without reloading live roots.
- [x] Migrate the peer, branch, and tool-fold keybinding defaults with collision
  regressions.
- [x] Reconcile user-facing and atlas documentation; run mapped and full tests.

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.50 impl=1.60
item: atlas-docs design=0.15 impl=0.20
item: milestone-review design=0.00 impl=0.20
design-buffer: 0.15
total: 2.75
```

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md`
against `baseline-v3.1.md`. Method A only.*

## Log

### 2026-07-15
- 2026-07-15: closed — Verified exact traceability selections for modes/super_repo, ui/keybindings, infra/repo_mode, and chat/lifecycle; make test-changed; make lint (0 warnings/errors in 275 files); git diff --check; three isolated chat_progress_process_spec.lua reruns; and full make test JOBS=1 all exited 0. The initial parallel full-suite run exposed the existing ready-file race in that unchanged integration fixture; reduced parallelism completed cleanly. Atlas documents the new repo-mode persistence surface and keybinding lifecycle.; review verdict: FIX-THEN-SHIP

- Claimed before design. The approved direction stores a canonical-root-keyed
  `repo_modes` map in existing state rather than modifying `.parley` or adding
  per-repo files. Ordinary repo mode is the unsaved default; explicit choices
  win uniformly, so the brain-only auto-enable path is removed.
- Keybinding design: `<C-g>p` becomes the peer overlay toggle, `<C-g>b` becomes
  branch/prune, and tool-fold toggling remains configurable without a default.
- Root-cause inspection found that calling the full `refresh_state()` after a
  successful activation could restore pre-overlay note roots. The design
  therefore reuses one extracted write-only persistence policy instead of
  reloading state while saving the scalar preference (`ARCH-DRY`, `ARCH-PURE`).
- The first code-change gate rejected duplicated keybinding ownership. For the
  migrated configurable actions, `config.lua` now remains the sole default
  source and registry registration/help derive through `config_key`
  (`ARCH-DRY`).
- Implemented a pure `repo_mode` policy plus one atomic, write-only state
  boundary. Explicit peer-mode toggles now persist only after successful
  runtime transitions, while a failed save keeps the live choice and preserves
  the prior durable file.
- Startup now applies the saved canonical-repo preference once, after all state
  refreshes, through an idempotent non-persisting overlay transition. Removed
  the `.brain` startup exception so unsaved brain repositories follow the same
  ordinary-repo default as every peer.
- Migrated peer toggle to `<C-g>p` and chat branch/prune to `<C-g>b`. Tool-fold
  toggling remains configurable but intentionally has no default mapping or
  help row; registry resolution and exposed config share one source of truth.
- Verification: exact traceability selections for `modes/super_repo`,
  `ui/keybindings`, `infra/repo_mode`, and `chat/lifecycle`; `make
  test-changed`; `make lint` (0 warnings/errors in 275 files); `git diff
  --check`; and `make test JOBS=1` all exited 0. The first parallel full-suite
  run exposed a pre-existing ready-file race in
  `chat_progress_process_spec.lua`; the unchanged test passed three isolated
  repetitions and the complete reduced-parallelism rerun.
- The close review found one Important `ARCH-DRY` issue: persisted repo identity
  and transient-root filtering repeated the same canonical path expression.
  Hoisted and reused `resolve_dir_key` across every trailing-slash-normalized
  path comparison in `init.lua`, and added an architecture regression that
  requires exactly one owning expression. Focused architecture and mapped
  super-repo tests passed after the consolidation.

## Revisions

### 2026-07-15 — fresh-context spec review

- Reason: review found implementation-defining ambiguity in startup timing,
  optional keybinding/help semantics, mixed-map sanitization, and persistence
  write failure.
- Delta: made restoration synchronous before `setup()` returns; defined one
  registry path for configurable unbound actions; specified immutable map
  filtering; and required atomic, result-bearing state writes with bounded
  failure behavior and production-path regressions.

### 2026-07-15 — startup sequencing correction

- Reason: follow-up review found that restoring after each setup refresh could
  let the optional default-agent refresh replace live overlay roots while the
  super-repo state still appeared active.
- Delta: require exactly one restoration after all setup refreshes and verify
  the complete live sibling chat/note overlay in the default-agent setup path.

### 2026-07-15 — implementation planning

- Reason: the approved multi-file behavior needs a durable, test-first execution
  record before crossing the code-change gate.
- Delta: added the reconciled v3.1 estimate and detailed implementation plan at
  `workshop/plans/000190-persist-repo-super-repo-state-across-nvim-sessions-plan.md`.

### 2026-07-15 — code-gate architecture refinement

- Reason: plan-quality review found that changing defaults independently in
  config and registry would preserve two authoritative definitions.
- Delta: make config the sole owner for migrated configurable defaults; registry
  registration/help derive them through `config_key`, with a drift regression.
