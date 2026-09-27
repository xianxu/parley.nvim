---
id: 000235
status: open
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
github_issue:
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
