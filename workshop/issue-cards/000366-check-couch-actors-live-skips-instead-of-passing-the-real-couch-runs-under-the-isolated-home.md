---
id: 000366
status: codecomplete
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-16T23:59:12-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.29
tracker:
    version: 1
    completion:
        token: close-0c1cb74ecd27
        repository: github.com/xianxu/parley.nvim
        reviewed_head: e6b4a8de051080a9f129ad213dab016e38ac8e6a
        evidence_commit: d7e7f91aebf9d99fd1861d1634b97d335a02ca0d
---

# check-couch-actors-live skips instead of passing: the real couch runs under the isolated HOME

## Problem

`make check-couch-actors-live` (#365) never really ran the live `--actors` conformance check. Run unsandboxed from ops:0 on 2026-10-16, `couch_spec`'s live case printed `Pending … couch unreachable here` followed by `Success`. Plenary prints that pair for any case that calls `pending()`, so the check was skipped, not passed.

The case reaches the real binary (past the sentinel), but its `couch --actors --json` exits non-zero or prints non-JSON. The likely cause is that the target runs under the harness's isolated HOME, XDG and TMPDIR, so the real CLI can't find the operator's Couch store or supervisor socket. The thread names alone are not enough.
