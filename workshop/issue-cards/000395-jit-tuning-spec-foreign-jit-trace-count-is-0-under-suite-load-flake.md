---
id: 000395
status: codecomplete
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
severity: low
started: 2026-10-19T19:32:05-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.22
tracker:
    version: 1
    completion:
        token: close-523e89520144
        repository: github.com/xianxu/parley.nvim
        reviewed_head: f674d4f0ac1eae1be97f5ff3fdb72fac3ea50a66
        evidence_commit: 2a86a8c5daac6d0b30b9c95ac84aa490bc853528
---

# jit_tuning_spec foreign JIT trace count is 0 under suite load (flake)

## Problem

`tests/unit/jit_tuning_spec.lua` "module-scoped compiler protection in a real VM keeps unrelated JIT traces active while protecting the entire document pipeline" failed at line 126 (`assert.is_true(result.foreign > 0)`) in the full suite on parley.nvim#391's head 0c9ab358, a diff that touches no JIT or document-pipeline code. The child VM's foreign trace never reached `stop`: an abort or flush under suite load clears `foreign_trace`, so the count stays 0. The same file passed three isolated runs (`make test-spec SPEC=infra/test_harness`) on the same head, and the previous full suite on c3c50006 passed.

Evidence: suite log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/8f1ede4b55ff8fded222bbfdcb96c6e5.log (sha256 ee66cec1ac34), recorded as sdlc-local/suite on 0c9ab358.
