---
id: 000235
status: working
deps: []
github_issue:
created: 2026-09-10
updated: 2026-10-16
estimate_hours:
card_mirror: 'e131e9dbe8aec016f75acfff232a9cb3547c4ab2' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T05:22:52-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d86ae097", done: "4b4abcd2"}
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

## Core concepts

| Entity | Status | Where | What |
|---|---|---|---|
| `active` | added | lua/parley/test_isolation.lua | `test_isolation.active()`: the one reader of the harness signal, `$PARLEY_TEST_MODE == "1"`. `file_tracker`, `cliproxy` (×2) and `issue_tracker` ask it; an arch guard refuses any other `lua/` reader. |
| `fetch_enabled` | changed | lua/parley/issue_tracker.lua | Now `not test_isolation.active()`, the one reader, instead of reading the variable itself. |

## Plan

Re-checked 2026-10-16:
- **Since #261 M5 every spec child loads `tests/minimal_init.vim`**, so `g:parley_test_mode` now reaches specs. The leak this issue describes is likely already closed. It is verified below by the Done-when spec rather than assumed.
- The highlighter's `new_default_deferral` no longer exists.
- The signal has FOUR production readers: `file_tracker` (`g:`), `cliproxy.lua` ×2 and `issue_tracker.lua` (`$PARLEY_TEST_MODE`). The goal stands: one reader.

- [x] `lua/parley/harness.lua`: `active()` returns `vim.env.PARLEY_TEST_MODE == "1"`, the one reader. `file_tracker`, `cliproxy` (×2) and `issue_tracker` call it.
- [x] Arch guard in `tests/arch/single_source_sweeps_spec.lua`: no other `lua/` module reads `parley_test_mode` or `PARLEY_TEST_MODE`; seen red with a planted reader.
- [x] `g:parley_test_mode` removed from `tests/minimal_init.vim`, `chat_move_spec.lua` and `tests/packaging/spell_compatibility.lua`. `file_tracker_spec` and `tests/helpers/sidecars.lua` toggle `$PARLEY_TEST_MODE` instead.
- [x] Spec: under the harness `file_tracker` writes no `file_access.json`; full suite.

## Log

### 2026-09-10

Filed from the #227 close review (round 2, Minor). Split out rather than landed
after that review: it turns `file_tracker`'s test-mode guards on across the
whole suite, which deserves its own reviewed change.

### 2026-10-16 (parley.nvim:4)

- Built with one change to the plan: the reader is `test_isolation.active()` in the existing harness-rules module (`lua/parley/test_isolation.lua`, already home to `inside`/`check`) rather than a new `harness.lua` (ARCH-DRY).
- Seen red: a planted `vim.env.PARLEY_TEST_MODE` reader in issue_tracker.lua fails the new arch guard. With file_tracker reverted to its old `g:` reader (no longer set anywhere), the new "never writes file_access.json under the harness" spec fails.
- The atlas `test_harness.md` paragraph is rewritten: one variable, one reader, its callers. It no longer says the highlighter's scheduled repair keys on the signal; that deferral no longer exists.

