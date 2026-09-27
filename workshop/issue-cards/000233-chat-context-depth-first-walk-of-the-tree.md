---
id: 000233
status: open
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
github_issue:
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
