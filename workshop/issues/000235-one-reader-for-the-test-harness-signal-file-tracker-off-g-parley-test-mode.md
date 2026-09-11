---
id: 000235
status: open
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
---

# One reader for the test-harness signal: file_tracker off g:parley_test_mode

## Problem

`PlenaryBustedFile` runs each spec in a child nvim started *without*
`tests/minimal_init.vim`, so `let g:parley_test_mode = v:true` in that init
never reaches a spec. The child inherits only the environment. #227 found this
when its test-mode default printed nil inside a spec. The fix was
`$PARLEY_TEST_MODE`, which the init now exports and the highlight structure's
repair reads.

The only other production reader, `lua/parley/file_tracker.lua`
`is_test_mode()` (lines 10–12), still reads `vim.g.parley_test_mode`. Its
guards in `load_data`, `save_data` and `init` are therefore off in every spec
except `chat_move_spec`, which sets the flag itself as a workaround. The #227
close review observed the effect: after a `make test` run, the harness's
`…/xdg/data/nvim/parley/file_access.json` held `topic_gen_spec`'s chat paths.
That is persisted state shared by parallel specs that none of them set up.
(#227 close round 2, Minor, family `class-not-instance`.)

## Spec

The harness signal has exactly one production reader: a small helper keyed on
`$PARLEY_TEST_MODE`. `file_tracker` and the highlighter's
`new_default_deferral` both call it, and an arch guard in
`tests/arch/single_source_sweeps_spec.lua` fails if any other module in `lua/`
reads `parley_test_mode` or `PARLEY_TEST_MODE`. Then remove the workarounds:
`tests/minimal_init.vim`'s `g:` line and `chat_move_spec.lua:5`. Turning
`file_tracker`'s guards on suite-wide may expose specs that silently relied on
the leaked `file_access.json`; run the full suite and fix those specs, don't
re-open the leak.

## Done when

- One helper reads the harness signal; `file_tracker` and the highlighter use it.
- An arch guard fails on any other `lua/` reader of the signal, and it has been
  seen red.
- `g:parley_test_mode` is gone from `tests/minimal_init.vim` and
  `chat_move_spec.lua`.
- A spec asserts that `file_tracker` writes no `file_access.json` under the
  harness.
- `make test` is green.

## Plan

- [ ] Extract the harness-signal helper; route `file_tracker` and `new_default_deferral` through it.
- [ ] Arch guard: no other reader of the signal in `lua/`; watch it go red.
- [ ] Remove the `g:` flag and the `chat_move_spec` workaround; fix any spec that depended on the leak.
- [ ] Spec: no `file_access.json` written under the harness; full `make test`.

## Log

### 2026-09-10

Filed from the #227 close review (round 2, Minor). Split out rather than landed
after that review: it turns `file_tracker`'s test-mode guards on across the
whole suite, which deserves its own reviewed change.
