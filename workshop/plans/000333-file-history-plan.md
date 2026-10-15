# Per-window file history implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 for execution strategy.
> The pure model is a bounded delegation; integration stays with the main agent.

**Goal:** Alt+Shift+O returns through distinct file visits in the current window,
restoring each departure cursor, until the first retained file.

**Architecture:** A pure transition model owns visit ordering, same-file
collapse, saved positions, Back selection and forward-tail truncation. One
Neovim adapter owns window state, events and safe buffer switches. The existing
registry owns configurable keys and help; normal file opens remain unchanged.

**Tech stack:** Lua, Neovim autocmds/window APIs, existing Plenary harness.

## Core concepts

| Entity | Kind | Location | Status | Responsibility |
| --- | --- | --- | --- | --- |
| `file_history_model` | PURE | `lua/parley/file_history_model.lua` | new | Immutable history transitions, maximum 200 retained visits. |
| `transition` | PURE | `lua/parley/file_history_model.lua` | new | State/event to next state and optional Back target. |
| `file_history` | INTEGRATION | `lua/parley/file_history.lua` | new | Window-scoped state and native editor effects. |
| `setup` | INTEGRATION | `lua/parley/file_history.lua` | new | Idempotent event registration and initial window seeding. |
| `back` | INTEGRATION | `lua/parley/file_history.lua` | new | Safe current-window navigation through model-selected targets. |
| `keybinding_registry` | INTEGRATION | `lua/parley/keybinding_registry.lua` | modified | Global file_back action, effective key resolution and help. |
| `init` | INTEGRATION | `lua/parley/init.lua` | modified | Setup adapter, route FileBack command and global callback. |
| `config` | INTEGRATION | `lua/parley/config.lua` | modified | global_shortcut_file_back, default n/i <M-O>. |

## Operating contract

- Track named normal file buffers in normal editing windows. Resolve file
  identity to an absolute path; use a loaded matching buffer when returning.
- A window owns one history. New splits begin with their own displayed file;
  switching focus does not merge histories. Clear a window's state on WinClosed.
- Transient/floating buffers neither become visits nor erase a file's history.
- Bound each history to 200 entries (proposed TL choice); evict oldest entries.
  No timers, background jobs, network, persistence, or global history sharing.
- Keep the newest departure cursor for each visit, not a shared per-buffer mark.
  Clamp saved row/column to the current contents when returning to edited files.
- Back never calls open_buf: it must keep the current window, rather than use
  the existing other-split preference. Respect native modified-buffer refusal.
- Back skips missing/unloaded targets; a failed native switch preserves the
  original history index and current file. Never force, save, or discard text.
- Normal and Insert default keys are configurable/disableable through the
  registry. Preserve the caller's mode across the synchronous navigation.
- Root is the first retained visit, not a filesystem directory or frontmatter
  parent. No separate forward action in this slice.

## Transition model

`transition(history, event, limit)` receives nil or `{entries, index}` and
returns a new history plus an optional target entry. An entry is
`{path, cursor={row, col}}`; the default limit is 200. Inputs remain unchanged.

| Event | Transition | Effect |
| --- | --- | --- |
| visit(path,cursor), same current path | Update current entry cursor, keep order/index and forward entries. | None. |
| visit(path,cursor), different path | Truncate after index, append visit; evict overflow from front. | None. |
| snapshot(path,cursor), matches current path | Update current entry's cursor only. | None. |
| snapshot for another path/transient buffer | No history change. | None. |
| back | Select nearest earlier entry with a different path; move index in proposed state. | Return selected entry; nil at root. |

The adapter proposes Back transitions locally while skipping missing files. It
commits the proposed history only once the target is shown successfully.
During the synchronous editor switch, suppress only this window's normal
visit/snapshot events; clear that suppression even when switching errors. The
successful post-switch state comes from the model, with clamped cursor saved.
A failed switch leaves the original state; ordinary events resume immediately.
There are no asynchronous callbacks or retries in this subsystem.

## Architecture assessment

ARCH-DRY: use the existing registry and editing-window predicate; do not alter
open_buf, gf, pickers or other file-opening consumers. Observe visits once.
ARCH-PURE/ARCH-ORDER: transition is the sole ordering authority; the adapter
stores model states and executes effects, with explicit success/refusal paths.
ARCH-PURPOSE: any-method visits and per-window cursor restoration fulfill the
project's session → answer → side-doc → session workflow without depending on
unlanded #327 work. Use direct Markdown links already supported on main.
ARCH-MOCK: no external service/binary integration is introduced; exercise real
Neovim buffers, mappings and events with temporary files. No call-count mocks.
ARCH-CONSTRAINTS: at most 200 small entries per editing window; event work is
bounded by that cap, only on window/buffer boundaries and Back, not keystrokes.
ARCH-SECURE: paths cross the editor/filesystem boundary via fnameescape/native
commands; no shell execution. Protect unsaved buffers through native refusal.
ARCH-FUNERAL: in-memory histories die on WinClosed or editor exit; setup replaces
its autocmd group, and creates no timers, sidecars or durable cache.

## Task 1 — pure transition model

Files: create `lua/parley/file_history_model.lua` and
`tests/unit/file_history_model_spec.lua`.

- [ ] Write tests for A→B→C, repeated same-file cursor moves, per-visit positions,
  Back→Back→root, Back→new D tail truncation, same-path visits while back,
  nonadjacent repeat visits, input immutability and cap eviction.
- [ ] Run the focused tests before implementation and confirm missing transition
  behavior fails. Add both tests to ui/keybindings in atlas/traceability.yaml.
- [ ] Implement only transition; run tests again, then commit the model and tests.

## Task 2 — native window adapter and key

Files: create `lua/parley/file_history.lua` and
`tests/integration/file_history_spec.lua`; modify `lua/parley/init.lua`,
`lua/parley/keybinding_registry.lua`, `lua/parley/config.lua`, and
`tests/unit/keybindings_spec.lua`.

- [ ] Write failing real-editor tests. Seed a session Markdown file with an answer
  link and an answer with a side-doc link, follow both with remappable Alt+o,
  move inside each file, then press Alt+Shift+O twice and assert file and cursor.
- [ ] Cover gf, edit, nvim_win_set_buf as picker entry, independent splits, focus
  changes, same-file jumps, scratch and floating windows, branch-after-Back,
  deleted targets, unsaved-buffer refusal/retry, clamped cursors, and repeated setup.
- [ ] Implement setup with departure snapshots (BufLeave/WinLeave), visits
  (BufEnter/WinEnter), WinClosed cleanup, and seed existing editing windows.
- [ ] Implement back using the pure model and guarded native switching in the
  current window. Use the actual target after the switch as the success oracle.
- [ ] Add global file_back registry/config entry (<M-O>, n/i), FileBack command,
  callback and help. Verify custom prefix/key and disabled/default mapping policy.
- [ ] Run `make test-spec SPEC=ui/keybindings`; confirm the original absence and
  removal of history recording or back suppression makes the relevant cases fail.

## Task 3 — documentation, full verification and landing

Files: README.md, atlas/ui/keybindings.md, atlas/index.md (if adding a new atlas
page), atlas/traceability.yaml, generated help through its established generator,
workshop/lessons.md for findings.

- [ ] Document the key, command, scope, bounds, root/no-op and error behavior.
  Regenerate help with the existing script; do not hand-edit generated output.
- [ ] Run targeted suite and lint; stage explicit paths and commit.
- [ ] Run `make test` in the background; record exit/count/no-survivor evidence.
  Run vocabulary freshness and range whitespace checks required by the repo.
- [ ] Tick issue/plan rows, checkpoint evidence and run `sdlc close --issue 333`
  with measured actuals and concrete verification. Address findings until SHIP.
- [ ] `sdlc pr`, check the exact head's CI, `sdlc merge --yes`; confirm landing,
  clean resting slot, and send the hub the PR and outcome. The close gate owns
  cross-project completion updates; do not edit the ops project concurrently.

## Verification commands

`make test-spec SPEC=ui/keybindings` — model, adapter, actual mappings and help.
`make lint` — Lua style checks, no new warnings.
`make test` — complete unit/integration/architecture coverage.
`make check-vocabulary` — generated vocabulary matches resolved dependency model.
`git diff --check origin/main...HEAD` — committed range whitespace.

## Approval

Pending TL review of this plan, especially retention limit and unavailable targets.
