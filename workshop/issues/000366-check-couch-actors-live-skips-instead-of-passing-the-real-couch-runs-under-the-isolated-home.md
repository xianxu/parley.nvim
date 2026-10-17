---
id: 000366
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '036a663491a35e13470c7fcaa63d7ef9791bca37' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-16
