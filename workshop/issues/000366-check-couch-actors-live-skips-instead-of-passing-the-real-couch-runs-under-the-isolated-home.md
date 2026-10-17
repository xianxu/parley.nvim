---
id: 000366
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
card_mirror: '118aa01a9461e7cd35dba57d812a134b950a4769' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T23:59:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "79f1365d", done: "ee4c97ec"}
actual_hours: 0.29
---

# check-couch-actors-live skips instead of passing: the real couch runs under the isolated HOME

## Problem

`make check-couch-actors-live` (#365) never really ran the live `--actors` conformance check. Run unsandboxed from ops:0 on 2026-10-16, `couch_spec`'s live case printed `Pending … couch unreachable here` followed by `Success`. Plenary prints that pair for any case that calls `pending()`, so the check was skipped, not passed.

The case reaches the real binary (past the sentinel), but its `couch --actors --json` exits non-zero or prints non-JSON. The likely cause is that the target runs under the harness's isolated HOME, XDG and TMPDIR, so the real CLI can't find the operator's Couch store or supervisor socket. The thread names alone are not enough.

## Spec

- Under `PARLEY_LIVE_COUCH` only, the live case runs the real binary with the operator's own HOME. The Makefile already has `REAL_HOME`, passed for example as `PARLEY_LIVE_COUCH_HOME`, plus whatever else the CLI proves to need, measured rather than guessed. The spec process itself stays isolated.
- When the call fails, the case still goes pending, but its message includes the CLI's exit code and stderr, so the next failure diagnoses itself.

## Done when

- From an unsandboxed operator terminal, `make check-couch-actors-live` shows the live case as Success with NO Pending line.
- The same run under the sandbox, where the socket is unreachable, shows Pending with the CLI's stderr.

## Plan

Measured (2026-10-16, unsandboxed, real binary through scripts/test-env.sh with the isolated values): HOME is not the cause. Two failures, in order:
1. `couch: configured root ".../xdg/data/pair" conflicts with selected "~/.local/share/pair"; unset the override`: the isolated XDG_DATA_HOME conflicts with the store COUCH_STORE_DIR selects.
2. With that fixed: `couch: operation requires the calling conversation identity`. pair's callerIdentity reads COUCH_THREAD_SCOPE, COUCH_THREAD_TAG, PAIR_SESSION_NAME and PAIR_LAUNCH_NONCE, and the allowlist keeps only the first two.
With both fixed and HOME still isolated, `couch --actors --json` exits 0 with Code ok.

- [x] scripts/test-env.sh: under PARLEY_LIVE_COUCH only, also keep PAIR_SESSION_NAME and PAIR_LAUNCH_NONCE.
- [x] Makefile.parley: check-couch-actors-live passes PARLEY_LIVE_COUCH_DATA_HOME (the operator's XDG_DATA_HOME, else REAL_HOME/.local/share).
- [x] tests/unit/couch_spec.lua: that one vim.system call gets XDG_DATA_HOME from it; the spec process stays isolated. The pending message carries the exit code and the first stderr line.
- [x] test_isolation specs: the live-Couch expected names gain the two identity names.
- [x] Verify: unsandboxed `make check-couch-actors-live` shows Success with no Pending; sandboxed shows Pending with the stderr.

## Revisions

- 2026-10-17: the Spec's "operator's own HOME" is replaced by the measured needs above (the real data home for the one call, and the two identity names); HOME stays isolated. Reported to the hub as plan366, proceeding unless it objects.

## Log

### 2026-10-16

### 2026-10-17
- 2026-10-17: closed — Unsandboxed make check-couch-actors-live: live case Success, no Pending (5 Success, 0 Failed). Sandboxed: Pending with "couch unreachable here (exit 1): couch: dial unix ...sock: connect: operation not permitted". Focused isolation and couch specs green; with the identity names removed from test-env.sh, the allowlist spec fails. luacheck clean.; review verdict: SHIP

- Unsandboxed `make check-couch-actors-live`: the live case is Success, with no Pending line (5 Success, 0 Failed).
- Sandboxed: Pending, "couch unreachable here (exit 1): couch: dial unix /tmp/pair-message-501/....sock: connect: operation not permitted".
- Mutation check: with test-env.sh's two identity names removed, "lets each live flag carry only its own check's names" fails.
- Lesson: `command -v couch` in an agent shell can be a shell function. Find the real binary with `whence -pa couch` before measuring it.
