---
id: 000379
status: open
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T17:27:55-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Check operator Neovim compatibility

## Problem

The operator's PATH Neovim is 0.11.7, but scripts/test-nvim.sh selects 0.12.5 for its newer LuaJIT mcode fix. Our full suite can therefore pass while the installed operator editor is broken.

During #373's real-profile live check, all full-suite tests passed on 0.12.5, then a registered move failed immediately on PATH Neovim 0.11.7 with E976: Using a Blob as a String. document_move's journal-budget namespace contains a NUL; vim.fn.sha256 accepts its binary representation on 0.12 but refuses it on 0.11. The lease-boundary defect is fixed under #373; this issue owns preventing the wider version-coverage gap.
