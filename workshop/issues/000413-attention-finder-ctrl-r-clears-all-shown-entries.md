---
id: 000413
status: open
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '0d23fd6748519de3a4962e6a2db2f02e178829b8' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-22
