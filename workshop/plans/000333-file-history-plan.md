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
| `is_restoring` | INTEGRATION | `lua/parley/file_history.lua` | new | Read-only restore scope consumed by buffer preparation. |
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

- [x] Write tests for A→B→C, repeated same-file cursor moves, per-visit positions,
  Back→Back→root, Back→new D tail truncation, same-path visits while back,
  nonadjacent repeat visits, input immutability and cap eviction.
- [x] Run the focused tests before implementation and confirm missing transition
  behavior fails. Add both tests to ui/keybindings in atlas/traceability.yaml.
- [x] Implement only transition; run tests again, then commit the model and tests.

## Task 2 — native window adapter and key

Files: create `lua/parley/file_history.lua` and
`tests/integration/file_history_spec.lua`; modify `lua/parley/init.lua`,
`lua/parley/keybinding_registry.lua`, `lua/parley/config.lua`, and
`tests/unit/keybindings_spec.lua`.

- [x] Write failing real-editor tests. Seed a session Markdown file with an answer
  link and an answer with a side-doc link, follow both with remappable Alt+o,
  move inside each file, then press Alt+Shift+O twice and assert file and cursor.
- [x] Cover gf, edit, nvim_win_set_buf as picker entry, independent splits, focus
  changes, same-file jumps, scratch and floating windows, branch-after-Back,
  deleted targets, unsaved-buffer refusal/retry, clamped cursors, and repeated setup.
- [x] Implement setup with departure snapshots (BufLeave/WinLeave), visits
  (BufEnter/WinEnter), WinClosed cleanup, and seed existing editing windows.
- [x] Implement back using the pure model and guarded native switching in the
  current window. Use the actual target after the switch as the success oracle.
- [x] Add global file_back registry/config entry (<M-O>, n/i), FileBack command,
  callback and help. Verify custom prefix/key and disabled/default mapping policy.
- [x] Run `make test-spec SPEC=ui/keybindings`; confirm the original absence and
  removal of history recording or back suppression makes the relevant cases fail.

## Task 3 — documentation, full verification and landing

Files: README.md, atlas/ui/keybindings.md, atlas/index.md (if adding a new atlas
page), atlas/traceability.yaml, generated help through its established generator,
workshop/lessons.md for findings.

- [x] Document the key, command, scope, bounds, root/no-op and error behavior.
  Regenerate help with the existing script; do not hand-edit generated output.
- [x] Run targeted suite and lint; stage explicit paths and commit.
- [x] Run `make test` in the background; record exit/count/no-survivor evidence.
  Run vocabulary freshness and range whitespace checks required by the repo.
After verification, tick issue/plan rows, checkpoint evidence and run `sdlc close --issue 333`
  with measured actuals and concrete verification. Address findings until SHIP.
Then run `sdlc pr`, check the exact head's CI, `sdlc merge --yes`; confirm landing,
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

## Revisions

### 2026-10-15 — TL approval and split inheritance

Approved by ops:0 delivery 499f2cb2-4d7a-42df-80e9-06b6c25d9175,
including the 200-visit limit. Supersedes fresh split histories: a new split
inherits a copy of its parent window's history, then evolves independently,
so Back can still reach the session file. Capture the source on WinLeave and
copy its immutable model state when WinNew creates the child; cover a split
showing the same file and a split opening a new file. A tab opened from a
window follows the same inheritance when Neovim creates its window.

Insert-mode Back bypasses the global registry's stopinsert wrapper using an
entry-specific preserve_insert flag; other entries keep the current behavior.
Native probes confirm buffer switching itself preserves Insert mode. The help
surface is generated at runtime from the registry; no static help file or
help-generator script exists, so assert the generated help lines directly.

### 2026-10-15 — buffer preparation participates in restoration

Real-key tracing found prep_md resets mode and drains typeahead on BufEnter,
even after the registry preserves Insert mode. Reuse the adapter's synchronous
restore scope through read-only is_restoring(win), and have prep_md honor it.
This is required to preserve queued typing and repeated Back keys; all ordinary
Markdown setup remains unchanged. Model cursor records use named row/col fields.

### 2026-10-15 — inactive splits and test results

Track the focused source on WinEnter (and seed it at setup); WinNew can execute
in an inactive child without WinLeave in its source. Snapshot the source when
copying the immutable history. A real API-created inactive-split test failed
before this correction and passed afterward. The full ui/keybindings mapping
passed before adding that case. Disabling only the Insert-preservation entry
makes two typed-key regressions fail; restored before the final full suite.
The final close/merge/stage steps are post-implementation procedures whose
completion is recorded by their SDLC evidence, rather than pre-ticked tasks.

### 2026-10-15 — final verification checkpoint

The initial full run caught a forbidden pattern-based named-buffer lookup.
Reused helper.buffer_for(path, true) for eligibility and selection (ARCH-DRY).
The final full make test run exited 0: 430 passing files, 728 Lua files with
zero lint warnings/errors, and no surviving test processes. Complete keybinding
mapping, focused 16-case adapter plus exact-name architecture guard, vocabulary
freshness and committed-range whitespace checks pass. Close/merge/staging follow
as authorized by the TL approval; no further scope change.

### 2026-10-15 — BR-1 replanning checkpoint

The boundary review correctly rejects focused-source inheritance for an explicit
unfocused API parent. All eight new direction/active-inactive regressions fail.
Native WinNew observations are ambiguous under equalalways (different parents
can yield identical layout, geometry and cloned buffer/cursor). A geometry-only
fix would repeat the assumption rather than establish parent identity (ARCH-ORDER).
Hub decision requested: capture Lua nvim_open_win arguments explicitly with a
native-command focus fallback and documented RPC limitation, or narrow the split
contract. Do not implement a parent heuristic while that decision is pending.

### 2026-10-15 — TL-approved narrowed inheritance contract

Delivery 0071ffce-140a-4b7b-a704-4752bce09148 approves narrowing and prohibits
wrapping nvim_open_win. Inherit only a focused native source's immediate WinLeave
before WinNew; consume that departure once and clear it at WinEnter. Native user
split/tab commands and Parley's command-based openers retain strict inheritance.
API-created windows emit WinNew first, so start with no inherited entries,
including focused-parent API calls; RPC-created windows receive the same rule.
Their initially displayed file becomes the root when observed. This replaces the
last-focused-source assumption, without guessing parentage from buffers/layouts.
Update README/atlas, revise all eight unfocused API cases to assert root no-op
and independent subsequent visits, retain strict native split/tab tests, and
cover API focused-source empty history. Re-run targeted/full checks and the SDLC
review; BR-1 must be disposed before landing.

API creation also emits WinEnter before replacing the temporary cloned buffer.
For these fresh windows only, suppress creation-time observations and seed the
final displayed file in one scheduled callback after creation returns. A per-window
token cancels stale callbacks on close; Back consumes the token and observes the
actual target synchronously if invoked before that callback. This supersedes the
original no-async-callback statement for API initialization only. Cover different
initial targets, identical-buffer parent ambiguity, and close-before-callback.

### 2026-10-15 — BR-2 synchronous initialization revision

Round 2 disposes BR-1 but rejects suppression until a scheduled seed: legitimate
immediate file entries are lost. Remove deferred initialization entirely. A
window with no inherited history ignores WinEnter's creation clone; BufEnter
starts its own history synchronously and all subsequent entries are recorded.
Back can also establish its currently displayed file as the root. For an API
creation that does not enter a different buffer, history remains empty until a
file-entry event or Back; no promise is made to retain creation-time clones.
This follows the TL's EMPTY-history rule and supersedes the stronger final-buffer
seeding promise introduced by the implementation, without suppressing later visits.
Cover immediate API→edit→edit→Back, immediate Back, native splitting and close;
keep the eight narrowed API cases and strict focused native inheritance tests.
