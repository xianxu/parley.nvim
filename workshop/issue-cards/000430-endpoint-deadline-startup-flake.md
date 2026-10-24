---
id: 000430
status: wontfix
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: 
started: 2026-10-23T18:08:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
tracker:
    version: 1
    abandoned:
        ref: refs/ariadne/abandoned/000430
        branch: 000430-endpoint-deadline-startup-flake
        head: 51a4876710cf21e114ec53d57137123cdc15563b
---

# Endpoint deadline test races Python startup and registry publication

## Problem

The #405 endpoint absolute-deadline native test assumes the fake Python process has started and published within 200 ms. An admitted request may legitimately time out before main() writes its PID or before it publishes; the reply gate only holds acknowledgment after publication. This produces false test failures while testing retained possibly-published state.
