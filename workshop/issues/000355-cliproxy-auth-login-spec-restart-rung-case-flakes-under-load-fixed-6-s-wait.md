---
id: 000355
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '9025f459037a5494399fd355ccf3948f7ebeb70b' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T11:05:40-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "f0ee053f", done: "bcece1c0"}
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

- [x] One bound for every wait on a claimed recovery: `SETTLE_MS = dispatcher.recovery_timeout_ms`, the backstop `cliproxy_budget_spec` proves the whole repair budget fits under. It replaces the 6000, 9000 and 6000 literals in `run()`, the EXHAUSTIVE case and the seed read.
- [x] ~~Before and after under CPU load~~: CPU load alone never reproduced it (0/18 runs on the old literals, 13–17 s each, against 39 s in the failing suite). Replaced by a deterministic slow proxy, see Revisions.
- [x] Regression case: "settles the restart rung within the backstop when every probe is slow (#355)", with `PARLEY_FAKE_GET_DELAY_MS=1500`. It fails with `SETTLE_MS = 6000` and passes with the backstop, 5/5 runs.

## Log

### 2026-10-16
- 2026-10-16: closed — Test-only fix. All three claimed-recovery waits in cliproxy_auth_login_spec (run(), the EXHAUSTIVE case, the seed read) now use SETTLE_MS = dispatcher.recovery_timeout_ms. That is the backstop cliproxy_budget_spec proves the repair budget fits under, and the restart rung alone budgets up to 15 s, so the 6 s literal was below the code worst case. Reproduced the suite failure deterministically: with PARLEY_FAKE_GET_DELAY_MS=1500 the old spec fails "takes the restart rung..." (settled nil). New regression case, the slow-proxy restart rung: it fails with SETTLE_MS=6000 and passes with the backstop, spec 5/5 runs green. CPU-burner load did not reproduce it (0/18), hence the deterministic knob. No production code changed.; review verdict: SHIP
- Why the backstop rather than a summed restart budget: the restart rung's worst case is `stop_identity_probe + port_release + ensure_probe + poll_healthy` = 2 + 4 + 2 + 7 = 15 s, and the seed read (credential_health) can itself run the whole repair. So 6 s was below the code's own worst case, not just tight. The production contract is "settles before the dispatcher's backstop", so the test waits exactly that. A passing run still settles in well under a second.
- Scope: other cliproxy specs (lifecycle, login, dispatch, catalog) use literal waits too, on different paths, and none has flaked. Not swept here; same remedy if one does.
- Before/after, deterministic: with every GET delayed by 1500 ms, the old spec fails the exact suite case ("takes the restart rung…", `settled` nil), and the fixed spec passes.

## Revisions

- 2026-10-16 Done when's "20 runs alongside a full suite" is replaced by a deterministic regression. CPU burners didn't reproduce the suite's slowdown, which comes from process and IO contention as well. The fake's existing `PARLEY_FAKE_GET_DELAY_MS` knob slows every probe instead: it lengthens the rung past 6 s but keeps it inside its budget, every run.
