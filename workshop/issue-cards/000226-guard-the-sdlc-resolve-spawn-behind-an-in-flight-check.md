---
id: 000226
status: codecomplete
created: 2026-09-08
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T00:18:48-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.25
tracker:
    version: 1
    completion:
        token: close-ccc469aa9258
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2f49f51bddfecf8a72586f4550fa40d0ceda761b
        evidence_commit: f0a2bf8a083a4ad8c4ebf25e6d0cdc4bfe9120cd
---

# Guard the sdlc resolve spawn behind an in-flight check

## Problem

`artifact_ref.goto_ref_at_cursor` shells to `sdlc resolve --json` with no
in-flight guard and no cancellation. Two presses before the first returns start
two subprocesses; both complete, both `vim.schedule` a dispatch, and you get two
`open_buf` calls or two family pickers.

This has always been true of `gf` (`resolve_ref_gf`), where it was tolerable
because `gf` on a ref is occasional. #225 put the same path behind **`<M-o>`**,
the key the operator presses most while navigating a forked transcript, which is
exactly the usage that produces a double-press. Raised as a Minor in #225's
close review and deliberately not folded in: cancellation semantics are a design
question, not a keybinding fix.

There is a second, related extent (#225 review, ARCH-ORDER): nothing cancels the
`run_resolve` → `vim.schedule` → `open_buf` chain if the user leaves the buffer
mid-flight, so a slow resolve can yank the window out from under whatever they
moved to.
