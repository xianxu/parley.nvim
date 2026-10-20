---
id: 000401
status: open
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
started: 2026-10-19T17:57:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# document_fold_retirement_spec: silent 43 s case stalls under suite load

## Problem

`tests/integration/document_fold_retirement_spec.lua` stalled in #394's recorded suite on 59b6cd14 (attempt 2e99c5ad6d069ce4b1cac89edd5bf005). It hung in the compat pass (installed nvim 0.11.7) with 0 cases completed, and the suite killed it after 180 s idle. The same file passed in that run's preferred pass in 19 s. The unchanged rerun on the same head passed every file, but sdlc judged the first failure unattributable and won't record the pass over it.

The one case builds a 50,010-line document in an embedded child nvim (`jobstart --embed`) and prints nothing until it finishes. Run alone, it takes 43 s on the preferred runtime, the slowest file in `chat/document`. Under the suite's parallel load it can plausibly pass the 180 s idle deadline. Its `vim.rpcrequest` calls to the child have no timeout, so a wedged child would also hang until the harness kills it, with no diagnosis.
