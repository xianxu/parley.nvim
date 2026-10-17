---
id: 000365
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: high
card_mirror: '18df816a847a78a77c8f710b82a61ed12d3a4817' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T17:17:24-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Tests inherit the slot's live Couch environment and query the real registry (chat_move_spec failed when Couch flapped)

## Problem

The test suite inherits the running slot's live Couch environment: `COUCH_THREAD_SCOPE`, `COUCH_THREAD_TAG`, `COUCH_STORE_DIR` and `COUCH_ISOLATED_ROOT`. `couch.thread()` then returns a real thread, `agentic_document`'s `namespace()` is non-nil, and every spec that moves or opens a markdown file without its own fake asks the REAL `couch --session-sync` registry. Only `tests/helpers/sidecars.lua` scrubs these variables, and only around its own cases.

Seen on 2026-10-16: `sdlc local-check run --name suite` on #358's 7ff97e39 failed three `chat_move_spec` cases at `:206`, with `move_chat_tree` returning "Invalid registry response". The non-timestamped child goes through `move_membership`'s registry lookup, and the live `couch` was flapping then (the CLI was briefly "command not found"). The spec passes alone, and on main the failure depends only on Couch's health. Log: `~/workspace/parley.nvim/.git/sdlc/test-stats/failed/c4be4a46c8f79f0408c42b10abcd1ed2.log`.

This is worse than a flake. A spec that moves a document the live registry knows can mutate it, by rename or register, and results depend on the operator's real registry state.

## Spec

- The test harness clears the Couch thread and store variables before any spec runs, for example in `tests/minimal_init.lua` or the runner's environment. A spec that wants Couch sets up the fake explicitly, as the agentic and session-sync specs already do.
- An arch-style guard proves no spec reaches the real `couch` binary. For example, PATH is pinned so that a bare `couch` resolves to a refusing stub unless a fake is installed.

## Done when

- With the slot's real `COUCH_THREAD_*` exported and the real `couch` unavailable, the full suite is green. `chat_move_spec` no longer depends on Couch.
- A test fails if a spec's process inherits `COUCH_THREAD_SCOPE` or `COUCH_THREAD_TAG`.

## Plan

Quick flow. The shape follows pair#617, as the TL asked: an allowlist environment, not a denylist.

| Name | Lives in | Status |
|------|----------|--------|
| `test-env.sh` (the allowlist launcher) | `scripts/test-env.sh` | new |
| sentinel `couch` and `pair` | `tests/fixtures/sentinel-bin/` | new |
| `ambient` (denied ambient names) | `lua/parley/test_isolation.lua` | new |

- [x] `scripts/test-env.sh CMD…` execs `env -i` with only the allowlisted names copied from its own environment: PATH, HOME, the XDG roots, TMPDIR, `PARLEY_TEST_ENV_ROOT`, `NVIM_TEST_PLENARY`, `PARLEY_TEST_JITSTAT*`, `PERF_OUTPUT`, locale, and `PARLEY_LIVE_*` opt-ins. It also sets `SHELL=/bin/sh` and prepends the sentinel bin to PATH. It is the one owner of the list. Every nvim launch in `Makefile.parley` goes through it: RUN_SPEC, test-spec, test-changed, perf, perf-finder, goldens, fixtures.
- [x] The sentinel `couch` and `pair` record each call (cwd and argv) to `$PARLEY_TEST_ENV_ROOT/sentinel.log`, then refuse with exit 97. A spec's fake wins because the spec prepends its own bin. `PREP_TEST_ENV` empties the log, and every target fails afterwards if it isn't empty: proof that no spec reached the real CLI, and so the real registry socket.
- [x] `test_isolation.ambient(env)` lists every visible `COUCH_*`, `PAIR_*` and terminal-owner name (TMUX, NVIM, KITTY_*, WEZTERM_*, ITERM_SESSION_ID, TERM_SESSION_ID, ZELLIJ, …). Pure, with unit tests.
- [x] Guard, `tests/integration/test_isolation_spec.lua`: the spec process's own environment has no ambient names, in particular no `COUCH_THREAD_SCOPE` or `COUCH_THREAD_TAG`; a bare `couch` resolves to the sentinel; calling it refuses and logs (to a log of the case's own). A launcher case runs `test-env.sh` with a polluted environment and checks the child's environment is exactly the allowlist.
- [x] The suite is green with the slot's live `COUCH_THREAD_*` exported. `chat_move_spec` now runs plain, because no thread is visible.
- [x] The atlas `infra/test_harness.md` gets the allowlist, the sentinel, and why.

## Log

### 2026-10-16
- Built on 2026-10-16. `NVIM` is left out of the denied names: Neovim sets it in every job it starts, so a spec sees the harness's own parent (plenary runs each file in a child). The launcher strips the operator's anyway.
- `couch_spec`'s "couch conformance (live)" case now runs pending under the harness, since no thread is visible. That is by design: a live check must not ride on the operator's ambient thread.
- Mutation check: letting the launcher pass `COUCH_THREAD_SCOPE` fails both the in-process guard and the exact-allowlist case.
- An extra guard: no `nvim` launch in `Makefile.parley` bypasses the launcher. There are 7 launches: RUN_SPEC, test-spec, test-changed, perf, perf-finder, goldens, fixtures.
- Full suite green on e7a42fb4 (`sdlc-local/suite`), run from this slot with the live `COUCH_THREAD_SCOPE`/`TAG` exported. The sentinel log stayed empty. The run before it failed only `fixture_lifecycle_spec`, which wanted the new sentinels declared as fixtures that cannot block; fixed in e7a42fb4.
