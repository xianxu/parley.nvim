---
id: 000394
status: working
created: 2026-10-18
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-19T14:14:24-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Registry queue deadline flake

## Problem

The existing document_registry_spec queue/deadline case is intermittent under parallel suite load. In #393 recorded suite cb7588a68bab3b4b10fa36c1e134718c on d6e05403, request 1 returned unavailable: Couch registry deadline exceeded after 1000 ms; queued_ms=0, ran_ms=1000, instead of absent. All other preferred-runtime spec files passed; make stopped before the compatibility pass. The same unchanged spec passed all 11 cases alone immediately afterwards (/tmp/parley-393-registry-alone.log).

The test starts eight Python-backed fake lookups with a 0.6-second sleep and a one-second per-child deadline, leaving only 0.4 seconds for interpreter/startup/scheduling under load. Neither registry code nor its spec differs between #393 and origin/main; #393 changes only the spelling default.
