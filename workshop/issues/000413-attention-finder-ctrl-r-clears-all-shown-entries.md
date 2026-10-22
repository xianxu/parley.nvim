---
id: 000413
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '2500cd50d69b642371f096011c6f86205279142a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T12:56:14-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "aae3164f", done: "cc84ef65"}
---

# Attention finder: Ctrl+R clears all shown entries

## Problem

## Spec

Operator request (10-22): the attention finder (Alt+Space) fills up during trials because answered and waiting entries
never expire (only seen ones leave, after `attention.seen_grace_minutes`), and the operator often forgets to open each
one, so the list grows past what they can go through by hand. Add a one-key **clear all** in the open finder.

- **Ctrl+R** (the operator's suggestion; "reset") in the open finder clears every row it currently shows, respecting
  the current scope (this slot / all slots, Ctrl+A) and the typed filter. Verify Ctrl+R doesn't collide with the
  float picker's prompt mappings (Insert-mode Ctrl+R pastes a register); if it does, keep Ctrl+R in the finder and say
  how the collision is resolved.
- Cleared entries leave the list at once (not the seen grace). A later submit of the same file brings it back as
  waiting, as today.
- One line of feedback: "Cleared N entries." No confirmation prompt; the finder's title or footer names the key.
- Shared store semantics unchanged: one leased store, cleared state persists across restarts like seen does.

## Done when

- With entries in all three states, Ctrl+R in the finder empties exactly the shown rows (scope and filter respected)
  and leaves hidden ones (test).
- A cleared file resubmitted reappears as waiting (test).
- README and `atlas/ui/attention_finder.md` and keybindings document the key.

## Plan

- [ ] Add red model/store cases for exact clear, all states, side retirement and resubmit; add native picker scope/filter/empty/late-refresh controls.
- [ ] Extend the existing picker action context with its shown-row snapshot; register finder-local Ctrl+R, clear once through the leased model, repaint and notify the removed count.
- [ ] Document the key and native register-paste override; run focused checks on both nvim versions, recorded suite and close review, then land.

Actions: clear shown rows; submit again. The existing store lease serializes clear with other writes (ARCH-ORDER); a failed write leaves rows intact and surfaces the existing warning. Successful clear removes only listed paths, preserving side retirement through the existing remove rule (ARCH-DRY/PURE); later submits restore waiting. No new durable format, watcher or retry. The picker snapshot includes filtered ancestor context, excludes hidden scope rows, and is empty while a status replaces rows. Snapshot/clear walks N rows once, N <=256; 8/16-entry tests count one batch with exactly N paths. Ctrl+R overrides native register paste only in this finder and is configurable under attention_finder_mappings.clear_shown. Other pickers keep native behavior.

## Log

### 2026-10-22
