---
id: 000233
status: codecomplete
created: 2026-09-10
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T03:36:06-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 1.21
tracker:
    version: 1
    completion:
        token: close-672962e81120
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 4012c9d579f1db161cd916f6d67e7845f822b6b3
        evidence_commit: f8c4490016fea744576a1c9b8e064fc35b495eac
---

# A question asked after an <M-i> branch cannot see that branch; build chat context by depth-first walk of the tree

## Problem

The operator's main use of branching is `<M-i>`: read an answer, fire off an immediate
question about it in a child chat, get the answer, come back, and keep going. Each of those
branches is an **aside**. When the operator asks the next question, they have already read it.

Context building treats a branch as a **fork** instead, the way git does: a sibling branch is an
alternative that never happened. A submission sees only its own file (up to the cursor)
plus the **ancestor path** up to the root, with each ancestor cut at the point where it branched:

- `chat_respond.lua:1471`: ancestor injection runs only `if parsed_chat.parent_link`, and
  `collect_ancestor_chain` (`:178`) walks **upward** only.
- Nothing ever reads a child file. An inline `[🌿:text](file)` link is unpacked to its
  display text (`chat_parser.lua:855`), and the child's exchanges are dropped.

The failure the operator hits most happens **in the parent, not in a child**. Ask R1, `<M-i>`
a question about R1's answer into child A, read A's answer, come back and ask R2. R2's context
is R1 only. The model never saw the aside that shaped R2, so the model and the operator now
disagree about what has already been said. The same goes for any earlier sibling of an
ancestor: from inside child B, a sibling A that branched earlier is invisible.
