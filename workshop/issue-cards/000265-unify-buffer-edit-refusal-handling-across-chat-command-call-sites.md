---
id: 000265
status: working
created: 2026-09-16
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T04:02:56-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Unify buffer_edit refusal handling across chat command call sites

## Problem

`buffer_edit.replace_user_lines` **raises** on refusal — `error("User edit
unavailable: …")` when the capture fails and `error("User edit refused: …")`
when the apply does (`lua/parley/buffer_edit.lua:92`, `:94`). Thirteen call
sites invoke it. Twelve let that error surface to the user as a bare Lua
traceback; one — `M.cmd.NewQuestion`, added in #263 — wraps it in `pcall` and
logs a readable warning instead.

Surfaced by #263's boundary review, which judged the new behavior the better
one and the divergence a defect: *"The new one is the better UX; the siblings
now diverge from it."* #263 deliberately did not unify the other twelve, because
changing error semantics across features that issue does not otherwise touch,
at its close boundary, is a separable extension rather than the point.

A second, related gap from the same review: there is **no test that a live
generation produces the refusal**. #263's spec proves only that a command
catches and reports one, using a double at the `buffer_edit` seam. Two realer
approaches were measured and rejected there — a second overlapping user capture
is *allowed* (produces no refusal at all), and a detached document silently
re-attaches, because `capture_user` does `document.get(buf) or
document.attach(buf)`. Driving a real generation needs `chat_pending_spec`'s
`fake_runtime` / `fixture` / `start` helpers, which are file-local and not
exported.
