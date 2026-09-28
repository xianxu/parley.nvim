---
id: 000292
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-27
estimate_hours:
card_mirror: '034361583d96b408d54a1b21aef35d777890c506' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-27T17:48:02-07:00
flow: {kind: quick, provenance: inferred, spec: "1d496094", done: "322345ea"}
---

# Alt+h as an alias of <C-g>? (keybinding help)

## Problem

Operator request (2026-09-27): `<M-h>` (Alt+h) should do the same as `<C-g>?`, the
keybinding help (`global_shortcut_keybindings`, `lua/parley/config.lua:448`, modes
`n`/`i`). It follows the shipped pattern of frequent actions on Alt/Option, with the
`<C-g>` form kept for terminals that need it (`atlas/ui/keybindings.md`).

## Spec

- Make the shortcut a list, `{ "<C-g>?", "<M-h>" }`, using the existing alias
  mechanism (as `chat_drill_in = { "<C-g>q", "<M-q>" }`), so both keys reach one action
  and the shipped-defaults superset test covers it.
- `<M-h>` collides with no other Parley `<M-…>` default or scope, and it goes quiet
  with the #214 master switch like every registry-derived binding.
- The help listing shows both keys.

## Done when

- `<M-h>` and `<C-g>?` open the same help in Normal and Insert mode, tested through
  the mapping, not the handler.
- `atlas/ui/keybindings.md` lists the alias.

## Plan

- [ ] Alias in `global_shortcut_keybindings`; mapping test; collision check
- [ ] Atlas

## Log

### 2026-09-27
