---
id: 000342
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '2635ba69559234591ae0675fe33aa1975e398037' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T20:29:30-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "a27b20a1", done: "58f88fed"}
---

# A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache

## Problem

A test or review run outside the `make` harness wrote real user state. This is the same class as #338: tests reaching state the operator owns.

Evidence (2026-10-15):
- The operator's real cache `~/.local/share/nvim/parley/cliproxy/catalog.json` (mode 0600) has mtime 19:26:08. Its content is exactly `fake_cliproxy`'s 7-model list: claude-opus-5, claude-opus-4-8, claude-sonnet-4-6, gpt-5-codex, gpt-5.6-sol, gemini-pro-agent and gpt-oss-120b-medium (`tests/fixtures/fake_cliproxy:238-244`). On 2026-09-10 the same file held the real 41-model catalog that #230 measured, so that measurement can no longer be reproduced from it.
- The parley.nvim:3 full suite (`make -k test`, harness HOME and XDG isolated) finished at 19:24:30. 19:26 falls inside the #341 close review's window. That review runs specs in its own checkout, so a spec invoked outside the harness, with the real HOME, is the likely writer. The exact writer is not pinned.
- Every spec that fetches the catalog either redirects the cliproxy data dir (`_set_data_dir`) or uses in-memory data. Under the harness none can reach the real path, so the hole is "run without isolation", not one spec.

Impact today is low: the file is a cache refetched when stale. The class is not low: the same route reaches credentials, chats and state under the real XDG roots.

## Spec

Make the write impossible rather than finding this one writer:
- Specs fail fast when they run outside an isolated HOME and XDG roots. One shared guard, loaded by every spec entry point (the harness's minimal init and any direct `PlenaryBustedFile` / `-l` run), refuses to run when HOME or XDG_DATA_HOME resolves to the operator's real roots. The message says how to run the spec through `make`.
- Defense in depth at the writer: the cliproxy catalog and config writers refuse to write under the real XDG data dir whenever the endpoint is a fake (a loopback `fake_cliproxy` port, or a test marker the harness sets). Decide which signal is reliable, and prefer one that cannot be spoofed by production config.
- Reviewers and agents running a single spec use the harness entry point (`make test-spec`), and the close-review instructions say so.

## Done when

- A spec run directly with the real HOME (no harness) fails before executing any test, naming the reason. The regression launches a child nvim on a spec file with a non-isolated env and asserts the refusal and that no file appears under that env's data dir.
- With the harness, every spec still runs; the full suite passes.
- A catalog fetch against a fake endpoint with a non-isolated data dir refuses to write (unit or integration test), if the writer-side guard is adopted.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `check` | PURE | new | `lua/parley/test_isolation.lua` | The reasons an environment is not isolated; empty when it is. |
| `inside` | PURE | new | `lua/parley/test_isolation.lua` | Whether a path lies inside a root, links resolved. |
| `test_isolation` | PURE | new | `lua/parley/test_isolation.lua` | The one rule: under the harness, a path must resolve inside `PARLEY_TEST_ENV_ROOT`; `check(env)` names what is not isolated. |
| tests/minimal_init.vim | INTEGRATION | modified | `tests/minimal_init.vim` | Refuses to run any spec, before plenary loads one, when the env is not isolated. |
| `single_source_sweeps_spec` | INTEGRATION | modified | `tests/arch/single_source_sweeps_spec.lua` | Diffs from the branch point against origin/main, not a lagging local main. |
| `cliproxy` | INTEGRATION | modified | `lua/parley/cliproxy.lua` | `data_root()` refuses a root outside the isolated env in test mode, so no cache, config or binary write can reach real state. |
| Makefile.parley | INTEGRATION | modified | `Makefile.parley` | Exports `PARLEY_TEST_ENV_ROOT` with the isolated env; a goldens target replaces the documented direct run. |

## Plan

Measurement (2026-10-15, :3): every `make` target that loads `tests/minimal_init.vim` (test, test-spec, perf, fixtures) exports `TEST_ENV` (an isolated HOME and XDG roots under `TEST_ENV_ROOT`). The init itself checks nothing, so a direct `nvim -u tests/minimal_init.vim -c PlenaryBustedFile …` runs every spec against the operator's real roots. That is the route behind the 19:26 write. `scripts/refresh_goldens.lua` is documented as exactly such a direct run. No spec spawns a `minimal_init` child with a cleared env (the children inherit the marker).

- [x] `parley.test_isolation` (pure): `inside(root, path)` with symlinks resolved, and `check(env)` listing HOME, XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME (and XDG_CONFIG_HOME when set) that fall outside `PARLEY_TEST_ENV_ROOT`, or the marker itself missing. Unit-tested.
- [x] Harness: `TEST_ENV` exports `PARLEY_TEST_ENV_ROOT`. `minimal_init.vim` runs the check first and `cquit`s with the reasons and "run it through make test-spec" when it fails, before any spec loads.
- [x] Writer side: in test mode (`PARLEY_TEST_MODE=1`, which only the harness init sets), cliproxy's `data_root()` errors when the root (override or stdpath) is outside the isolated env. A spec forgetting `_set_data_dir` then fails loudly instead of writing elsewhere. Production (no test mode) is unchanged.
- [x] `make goldens` runs `refresh_goldens.lua` under `TEST_ENV`; its usage comment points there. TOOLING.md documents that specs only run through make.
- [x] Regression (red first): a child nvim on `minimal_init.vim` with a non-isolated env (a scratch HOME, no marker) and a spec that would write a sentinel under its data dir. Assert a nonzero exit, the refusal message, and no sentinel file. Also the writer guard: in test mode, `data_root()` with an outside root errors.
- [x] Atlas test_harness: the isolation guard. Verify: the full suite.


## Log

### 2026-10-15
- 2026-10-15: closed — Prior evidence stands (red-first child-nvim refusal; cliproxy writer guard). Round 1 fixes: TEST_ENV pins every test_isolation.ROOTS entry incl. XDG_CONFIG_HOME, asserted by a unit case; remaining direct minimal_init runs routed through make (fixtures, new perf-finder, init usage); guard fails closed on its own load error (red without pcall 3/1, green 4/0). Ariadne review-instruction Minor left per TL: the guard fails loudly with the make command, a stronger enforcement. Full make -k test exit 0 on f62f0404, lint clean.; review verdict: SHIP

### 2026-10-15 (:3)

- Red first: `tests/integration/test_isolation_spec` launches a child nvim on `minimal_init.vim` that writes a sentinel under its data dir. Before the guard, the unmarked child and the one with XDG_DATA_HOME outside the root both ran and wrote it (2 fail, 1 pass). After: 3/0 (refusal before any `-c`, reasons plus the `make test-spec` hint, no sentinel; an isolated child runs normally).
- Writer guard: `tests/unit/test_isolation_spec` 8/0, including cliproxy refusing an outside root; red with the guard disabled (7/1).
- `check-spell-compatibility.sh` runs in test mode with its own mktemp roots, so it now declares them as `PARLEY_TEST_ENV_ROOT`; one definition of isolation everywhere. `check-fresh-clone.sh` needs nothing (its probe is not in test mode; its inner `make test` sets the marker). `test_local_app.py` inherits the harness env.
- Out of reach here: the close-review dispatcher lives in ariadne. With the guard, a reviewer's direct run fails loudly with the make command to use instead.
- Full suite on def08221: one failing file, single_source_sweeps. Two causes. (1) My table backticked `minimal_init` and `goldens`, which are not Lua symbols, and lacked `check` and `inside`; fixed. (2) A real guard flaw: it took the branch point from `git merge-base HEAD main`. In the slot layout the local `main` is the :0 checkout's branch (here at 7762f5ed, far behind origin/main; untouched, since :0 is staged), so #230's `_operator_specs`, `_select` and `diagnose` were charged to this branch. A single `branch_point()` now prefers origin/main and falls back to main; both call sites use it. single_source_sweeps 25/0, lint clean.
- Full suite on 541ccefd (final code commit): exit 0, lint clean (740 files).
- Close review round 1, two Important, both taken as classes.
  - BR-1: TEST_ENV did not pin XDG_CONFIG_HOME while the check refused an outside value, so an operator exporting it would have every harness run refused. Class: every root the check inspects must be pinned. `test_isolation.ROOTS` is now the single list (config required like the rest), TEST_ENV pins and PREP_TEST_ENV creates `$(TEST_XDG)/config`, and a unit case asserts that TEST_ENV assigns every ROOTS entry.
  - BR-2: documented direct runs remained in `record_fixtures.lua` and `perf_chat_finder.lua`. Class sweep over `-u tests/minimal_init.vim` instructions: those two, plus minimal_init's own usage line, now point at make targets. A new `make perf-finder` covers the finder benchmark, which had none. The two June `workshop/continuation` handoff notes are archival and left as written.
- Minor, same round: the init guard now fails closed. A require error becomes a refusal ("the isolation check could not run"). Red with the pcall removed (the unguarded child ran: 3/1), green 4/0. Minor (review-instruction follow-up in ariadne) is with the TL.
- unit test_isolation 9/0, integration 4/0, lint clean.
- Minor (close-review instructions in ariadne should say make test-spec): left by TL decision. The guard is the stronger enforcement: a direct run now fails before any spec with the make command to use, which no sentence in review instructions can match.
- Full suite on f62f0404 (final code commit): exit 0, lint clean (740 files).
