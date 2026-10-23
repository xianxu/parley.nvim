---
id: 000423
status: open
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
---

# Long TMPDIR makes nvim tempname() fall back outside the test scratch

## Problem

When $TMPDIR is long, Neovim's tempname() does not use it. It silently falls back to /tmp/nvim.<user>/…, which is outside the harness's TEST_ENV_ROOT. Observed 2026-10-23 during #422. A disposable clone under a long Claude scratchpad path set TMPDIR=<clone>/.sdlc-review/tmp/parley-test-env/<key>/tmp. The zero-config probe child's tempname() resolved to /private/tmp/nvim.xianxu/tUFOR9/0/… (instrumented PROBE line). Its scratch therefore escaped TEST_ENV_ROOT, and also escaped the marker check, so the run passed for the wrong reason. A short clone path (/Volumes/TestScratch/tmp/r422) used TMPDIR as expected.
