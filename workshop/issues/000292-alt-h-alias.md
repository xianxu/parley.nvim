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

- [x] Alias in `global_shortcut_keybindings`; mapping test; collision check
- [x] Atlas

## Log

### 2026-09-27
- 2026-09-27: closed — keybindings_spec, starter_config_spec, keybinding_agreement_spec (new #292 maparg test: <C-g>? and <M-h> in n/i both invoke cmd.KeyBindings; default_keymaps=false leaves <M-h> unmapped) pass. Full suite: rotating load-flaky specs each pass alone; single_source_sweeps fails only because local main ref is stale (diff vs origin/main adds no exports). Atlas keybindings.md updated.; review verdict: FIX-THEN-SHIP

- `<M-h>` was unbound anywhere in lua/, tests, atlas; the starter app's family
  filter passes `<M-*>` keys through, so it ships there too (starter test updated).
- Registry `default_key` and `config.lua` both became `{ "<C-g>?", "<M-h>" }`;
  `<C-g>?` leads (it is what docs and finder footers teach), so `help` joins the
  `<C-g>`-leading group in the lead-split test and the atlas.
- Mapping test: `keybinding_agreement_spec` fires each key's installed `maparg`
  callback in n and i and asserts `cmd.KeyBindings` runs; also checks
  `default_keymaps = false` leaves `<M-h>` unmapped.
- Env: `single_source_sweeps_spec` fails because local `main` is stale
  (c87a3775 vs origin d25dfcfc), so its merge-base spans other issues; this diff
  adds no exports. Parallel `make test` shows a rotating flaky spec under load
  (document_dependencies / document_semantic / branch_child / perf_ownership),
  each passing alone.

