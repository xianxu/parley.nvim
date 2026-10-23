---
id: 000423
status: done
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
started: 2026-10-23T04:29:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.56
tracker:
    version: 1
    completion:
        token: close-71d7c78874dd
        repository: github.com/xianxu/parley.nvim
        reviewed_head: f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08
        evidence_commit: 6b728457b31ce4e7113ea47910c3fbd96fe4ad1b
        landed_commit: 729013a7ca6af3ff3e0aa9b821b55df54f5a23ee
---

# Long TMPDIR makes nvim tempname() fall back outside the test scratch

## Problem

When $TMPDIR is long, Neovim's tempname() does not use it. It silently falls back to /tmp/nvim.<user>/…, which is outside the harness's TEST_ENV_ROOT. Observed 2026-10-23 during #422. A disposable clone under a long Claude scratchpad path set TMPDIR=<clone>/.sdlc-review/tmp/parley-test-env/<key>/tmp. The zero-config probe child's tempname() resolved to /private/tmp/nvim.xianxu/tUFOR9/0/… (instrumented PROBE line). Its scratch therefore escaped TEST_ENV_ROOT, and also escaped the marker check, so the run passed for the wrong reason. A short clone path (/Volumes/TestScratch/tmp/r422) used TMPDIR as expected.
