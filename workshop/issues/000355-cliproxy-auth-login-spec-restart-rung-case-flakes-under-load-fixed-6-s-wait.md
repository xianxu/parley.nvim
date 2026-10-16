---
id: 000355
status: open
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '5ad8de6417c71ed27c0d8c40529184bd05ce2a2e' # card fields mirrored from issue-cards; edit via sdlc
---

# cliproxy_auth_login_spec restart-rung case flakes under load (fixed 6 s wait)

## Problem

`tests/integration/cliproxy_auth_login_spec.lua`, the case "cliproxy.recover takes the restart rung when the proxy's watcher missed a write", is flaky under machine load. It failed in the full suite on parley.nvim f8503293 (the #242 branch, which touches no cliproxy code). It failed at line 422, `out.settled` nil where `'retry'` was expected. That run took 39 s while three other suites held the machine. Run alone, the same case passed 3/3.

Cause, as read: the spec's `run()` waits a fixed `vim.wait(6000, …)` for the recovery to settle. The restart rung stops and starts the fake proxy and reads listeners, and under load that can outlast 6 s. The production restart path has its own derived budget (#345), but the test's wait is a hand-picked constant, not derived from it.

## Spec

## Done when

- The wait in `run()` (and the seed wait above it) comes from cliproxy's own restart budget, plus a margin. It is not a literal 6000.
- The case passes in a loop under load: run it 20 times alongside a full suite, with zero failures.
- Failed log, for reference: `.git/sdlc/test-stats/failed/9c9aed1a5b4d70e9da08f2e2a381b940.log`.

## Plan

- [ ]

## Log

### 2026-10-16
