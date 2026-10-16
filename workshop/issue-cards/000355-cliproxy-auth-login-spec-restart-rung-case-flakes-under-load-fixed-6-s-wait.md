---
id: 000355
status: codecomplete
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
started: 2026-10-16T11:05:40-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.21
tracker:
    version: 1
    completion:
        token: close-a929b6978109
        repository: github.com/xianxu/parley.nvim
        reviewed_head: fb0694d52d805cdb99e84e395484a64d4e797fb1
        evidence_commit: 5e76e74014ad45b81d87f40062c5801aca6b570f
---

# cliproxy_auth_login_spec restart-rung case flakes under load (fixed 6 s wait)

## Problem

`tests/integration/cliproxy_auth_login_spec.lua`, the case "cliproxy.recover takes the restart rung when the proxy's watcher missed a write", is flaky under machine load. It failed in the full suite on parley.nvim f8503293 (the #242 branch, which touches no cliproxy code). It failed at line 422, `out.settled` nil where `'retry'` was expected. That run took 39 s while three other suites held the machine. Run alone, the same case passed 3/3.

Cause, as read: the spec's `run()` waits a fixed `vim.wait(6000, …)` for the recovery to settle. The restart rung stops and starts the fake proxy and reads listeners, and under load that can outlast 6 s. The production restart path has its own derived budget (#345), but the test's wait is a hand-picked constant, not derived from it.
