---
id: 000324
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '8e33dd6f23166bcee4d8f964f61f5f992e38a177' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T16:45:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "1dff2098", done: "cb6b284b"}
---

# session-sync: a normal-mode edit (dd) doesn't take the operator's lock; only insert-mode edits seem to

## Problem

2026-10-14, the operator on ops' TL status file: deleting a line with `dd` in normal mode didn't take the operator's turn (no `<file>.lock`), so the agent could still write; edits after entering insert mode do take it. The code intends both: `lua/parley/session_sync.lua` ~488–516 takes the lock on `BufModifiedSet` / `TextChanged` / `TextChangedI` when `s.turn == "free"`, the buffer is modified, the disk turn reads free, and the buffer is a session-sync file. So one of those conditions fails for a normal-mode first edit, e.g. `s.turn` stale after an agent write reloaded the buffer, `TextChanged` not firing until the cursor moves, or `BufModifiedSet` already spent because the buffer was modified earlier.

## Spec

Find which condition fails on a first normal-mode change (`dd`, `x`, `p`, `u`) and fix it so any first edit, in any mode, takes the operator's lock before an agent write can land. Add a headless test per edit kind, including right after an agent write reloaded the buffer.

## Done when

- `dd` (and `x`, `p`, `u`, `.`) as the first edit creates the lock with holder operator; an agent `couch --session-sync write` then refuses (exit 3).

## Core concepts

| Concept | Owner / invariant |
|---|---|
| Attached session file | Recognized at attach; temporarily editing its YAML does not revoke protection. |
| Operator turn | On-disk sidecar; first dirty edit acquires, undo to unmodified releases silently, submit saves/releases/notifies. |
| Saved buffer | Explicit save/auto-save preserves the existing submit/violation protocol; it is not an undo. |

## Plan

- [x] Reproduce with real child-Neovim UI input; cover dd/x/p/u/dot and insert initially and after an agent reload, including edits damaging frontmatter. Record events and guard values; clarify the operator's original edit location with the hub.
- [ ] Repair attached-buffer turn reconciliation in the existing callback; add failing regression tests for clean undo, multi-step undo, redo, silent release, and saved-buffer/violation compatibility. Keep race handling and timer cleanup intact (ARCH-DRY, ARCH-STATE, ARCH-FUNERAL).
- [ ] Run targeted session-sync tests and the declared full suite, update atlas, obtain the required real-editor check through the hub, then close/review/land on SHIP.

## Log

### 2026-10-14

- Claimed and started on a fresh main-based branch. Start-plan refreshed the private Ariadne substrate and required a rerun with its rebuilt binary; no product source changed.
- Root-cause probes use a child Neovim with attached headless UI and real nvim_input, not synthetic autocmd dispatch. Body dd acquires, including after agent write/checktime reload. Header ggdd fires TextChanged and BufModifiedSet with modified=true, but M.is_session_sync=false because the edit removed the opening delimiter, so acquisition is skipped. dd then u fires both events with modified=false while the lock remains: callback has acquisition only, no clean-edit release.
- Sent the measured findings and proposed brief plan to the hub; original reported edit location remains unconfirmed. Preserve the distinction rather than claiming the body-only symptom reproduced. Temporary probe scripts: /tmp/parley324-probe.lua, /tmp/parley324-header-probe.lua, /tmp/parley324-reload-probe.lua.

## Revisions

- 2026-10-14 — add (operator): **undo back to the lock releases it.** If the operator undoes back to the point where their edit took the lock, the buffer equals the file on disk again (not modified), so release the operator lock without a submit and without telling the owner. Criterion: on TextChanged/BufModifiedSet, `&modified` is false (content matches disk), not an undo-sequence comparison, so redo, retyping the same text, or an undo through several changes all behave. Same autocmd as the first-edit fix, so it belongs in this issue. Test: dd → u releases; dd → x → u → u releases; dd → u → Ctrl-r takes it again.

- 2026-10-14 — root-cause refinement: normal body edits fail with the operator's pre-existing TextChanged auto-save registered before session attachment. Real input ordering is on_lines (modified=true), TextChanged (auto-save first, then lock handler sees modified=false), BufModifiedSet (modified=false). Insert TextChangedI can run before that auto-save. Existing tests manually fire BufModifiedSet before TextChanged and hide the defect. /tmp/parley324-autosave-probe.lua and /tmp/parley324-lines-probe.lua record it.
- 2026-10-14 — proposed delta pending hub approval: acquire in the buffer edit notification before auto-save, keep attached identity through header edits, and reconcile a clean edit only when no save intervened. An unconditional modified=false release after a save would negate the Normal-mode fix and violate #317's existing saved-turn tests; asked the hub to confirm this interpretation.

- Confirmed the live operator configuration read-only at ~/.config/nvim/lua/core/options.lua:48–56: global InsertLeave/TextChanged for *.md immediately writes when modified. Parley's own prep_md is debounced; the regression fixture must reproduce the operator's immediate global callback installed before session attachment. This closes the body-only reproduction gap.

- 2026-10-14 — TL confirmed the original edit was in the body. The operator's exact immediate auto-save configuration reproduces that failure. Live hub peek shows approval of the edit-before-save design and retaining save semantics; implementation is within the dispatch's explicit build/land authorization.
- 2026-10-14 — revised design: attach on_lines to acquire synchronously before TextChanged/auto-save; defer clean-edit reconciliation until modified settles, guarded by the edit's disk-mtime snapshot so saves do not release. Ignore reload notifications as operator edits; retain/reinstall the attachment across reloads and wipeout with the existing lifecycle. Real UI tests install the operator-style global InsertLeave/TextChanged auto-save before attachment. First edit still schedules the existing foreign-write race check.
