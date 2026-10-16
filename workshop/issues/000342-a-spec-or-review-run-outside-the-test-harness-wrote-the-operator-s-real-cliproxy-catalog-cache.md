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
| `test_isolation` | PURE | new | `lua/parley/test_isolation.lua` | The one rule: under the harness, a path must resolve inside `PARLEY_TEST_ENV_ROOT`; `check(env)` names what is not isolated. |
| `minimal_init` | INTEGRATION | modified | `tests/minimal_init.vim` | Refuses to run any spec, before plenary loads one, when the env is not isolated. |
| `cliproxy` | INTEGRATION | modified | `lua/parley/cliproxy.lua` | `data_root()` refuses a root outside the isolated env in test mode, so no cache, config or binary write can reach real state. |
| `Makefile.parley` | INTEGRATION | modified | `Makefile.parley` | Exports `PARLEY_TEST_ENV_ROOT` with the isolated env; a `goldens` target replaces the documented direct run. |

## Plan

Measurement (2026-10-15, :3): every `make` target that loads `tests/minimal_init.vim` (test, test-spec, perf, fixtures) exports `TEST_ENV` (an isolated HOME and XDG roots under `TEST_ENV_ROOT`). The init itself checks nothing, so a direct `nvim -u tests/minimal_init.vim -c PlenaryBustedFile …` runs every spec against the operator's real roots. That is the route behind the 19:26 write. `scripts/refresh_goldens.lua` is documented as exactly such a direct run. No spec spawns a `minimal_init` child with a cleared env (the children inherit the marker).

- [ ] `parley.test_isolation` (pure): `inside(root, path)` with symlinks resolved, and `check(env)` listing HOME, XDG_DATA_HOME, XDG_STATE_HOME, XDG_CACHE_HOME (and XDG_CONFIG_HOME when set) that fall outside `PARLEY_TEST_ENV_ROOT`, or the marker itself missing. Unit-tested.
- [ ] Harness: `TEST_ENV` exports `PARLEY_TEST_ENV_ROOT`. `minimal_init.vim` runs the check first and `cquit`s with the reasons and "run it through make test-spec" when it fails, before any spec loads.
- [ ] Writer side: in test mode (`PARLEY_TEST_MODE=1`, which only the harness init sets), cliproxy's `data_root()` errors when the root (override or stdpath) is outside the isolated env. A spec forgetting `_set_data_dir` then fails loudly instead of writing elsewhere. Production (no test mode) is unchanged.
- [ ] `make goldens` runs `refresh_goldens.lua` under `TEST_ENV`; its usage comment points there. TOOLING.md documents that specs only run through make.
- [ ] Regression (red first): a child nvim on `minimal_init.vim` with a non-isolated env (a scratch HOME, no marker) and a spec that would write a sentinel under its data dir. Assert a nonzero exit, the refusal message, and no sentinel file. Also the writer guard: in test mode, `data_root()` with an outside root errors.
- [ ] Atlas test_harness: the isolation guard. Verify: the full suite.


## Log

### 2026-10-15
