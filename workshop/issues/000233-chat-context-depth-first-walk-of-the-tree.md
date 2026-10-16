---
id: 000233
status: working
deps: []
github_issue:
created: 2026-09-10
updated: 2026-10-16
estimate_hours:
card_mirror: '6b065a73a258e6ecfa8eb1748a7f714428910d1b' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T03:36:06-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

## Spec

**The context for a submission is the chat tree in depth-first pre-order, cut off at the
exchange being submitted.**

Walk the tree from the root. For each file, emit its exchanges in order. After exchange *k*,
descend into every branch whose `after_exchange == k`, in line order, and emit the whole
subtree before continuing with *k+1*. Stop at `(current file, current exchange)`.

Put another way, **DFS truncated at the cursor = today's ancestor path + every subtree to the
left of it.** Nothing to the right is included. That covers later siblings, later exchanges
of any ancestor, and anything below the cursor.

Why DFS order is the right one: under the `<M-i>` habit of finishing an aside before moving on,
DFS pre-order is the order in which the operator read things. It can be derived from the files
alone, so it needs no timestamps. It departs from chronology only when an old aside gets
revisited later. Its new exchanges then land at the old spot, which is still deterministic and
acceptable.

Rules:

1. **Cut point.** For the exchange being submitted, emit only its question, as today.
   Its answer and any branches hanging off it are after the cut. When an exchange that already
   has children gets **regenerated**, those children are about the answer being replaced, so they
   must not leak in.
2. **One renderer.** Today an exchange becomes messages through **two** code paths.
   `build_ancestor_messages` (`:149`) is a stripped-down copy that always uses the summary and
   skips footnote stripping, tool blocks and the `chat_memory` policy. The current-file loop
   (`~:850–920`) is the full one. DFS turns the tree into a **virtual single chat**: linearize
   first, then run the existing single-file pipeline over the sequence. That applies the
   memory policy (`max_full_exchanges` plus summaries) across the whole linearized sequence,
   so old asides compress automatically, and it retires the second renderer (ARCH-DRY).
3. **One tree walker.** The repo already has three copies of the root-finder
   (`exporter.lua:131`, `init.lua:3461`, `outline.lua:206`) and two downward walkers
   (`exporter.lua:157 collect_tree`, `init.lua:3478 collect_tree_files`). The DFS walker must
   be **the** walker, not copy #4, and those consumers must derive from it. "All files in the
   tree" is just the DFS order of its files.
4. **Buffer-first reads.** Every file in the walk is read from its loaded buffer when there is
   one, and from disk otherwise. Today the ancestors come from `readfile` (disk). A child just
   answered in another buffer must not be missed because it hasn't been saved.
5. **Guards.** Keep a visited set (a file referenced twice, or a cycle) and the existing
   depth cap.

**Known loss, accepted for v1:** a branch meant as a real *alternative* ("try a different
framing") will now leak into siblings to its right. The operator's actual usage is asides, so
DFS is the default and there is **no mode toggle**. Add an opt-out marker only when a
real case shows up.

## Done when

- A root with R1 → `<M-i>` child A (A1) → R2: submitting R2 sends `R1, A1, R2` (today it sends `R1, R2`).
- Submitting inside child B, where sibling A branched from an earlier exchange of the same
  parent, includes A's whole subtree before B's branch point.
- Nothing to the right of the cursor is sent: later siblings, later ancestor exchanges,
  children of the current exchange when regenerating.
- `chat_memory` summarization applies across the linearized sequence, with no separate
  ancestor renderer.
- One root-finder and one downward walker; exporter/delete/tree-files derive from them. (Split out as #349.)
- An unsaved child buffer's latest exchange is included.
- Unit tests on the pure linearizer (hand-built parsed trees) plus an integration test over
  real files with nested and inline branches.

## Plan

Durable plan: `workshop/plans/000233-chat-context-depth-first-walk-of-the-tree-plan.md`.
M2 (one tree walker) is split out as #349.

- [x] Pure `chat_tree.linearize` and `path_up`, with tests for the cases above
- [x] Feed the linearized sequence through `build_messages`, and delete `build_ancestor_messages` / `collect_ancestor_chain`
- [x] Integration test over real chat files with nested and inline branches and an unsaved child buffer
- [ ] The operator's decision on full ancestors inside the memory window (below), before merge

## Log

### 2026-09-10

- Filed from the operator's brainstorm in the brain advisor session. Verified by reading, not by
  running: children are never read (`chat_respond.lua:1471` gate is `parent_link` only). A branch
  inside exchange *k*'s answer records `after_exchange = k`, because the exchange is pushed when
  its question starts (`chat_parser.lua:648`), so "descend after *k*" places an aside
  directly after the answer it is about.
- Related: #224 (ancestor walk uses the shared resolver), #232 (outline tree builder has its
  own item rule, the same drift from duplicated tree code).

### 2026-10-16

- Taken by parley.nvim:3. The plan was approved for M1, with M2 split out as #349.
- Red: with `linearize`'s subtree descent removed (the old behaviour: no
  asides), 3 of 4 `chat_tree_context_spec` cases and 4 of 11 `chat_tree_spec`
  cases fail. Green: chat_tree 11, chat_tree_context 4, build_messages 104,
  chat_respond 53, ancestor_chain_rename 6, topic_gen 11, all 20 arch specs.
  luacheck clean.
- Found while building: topic requests excluded ancestors by message count.
  `build_messages` now returns the current file's messages, and the topic
  input keeps only those (`build_messages_spec`).
- Request size, before (origin/main) vs after (this branch). Bytes are the JSON
  of the messages array; tokens are estimated as bytes / 4. The tree is built
  from real repo chats: root = the graphviz chat (27.7 KB, 7 questions); an aside
  after root exchange 2 = the 2026-04-03.22-21 chat (26.3 KB, 4 questions); a
  nested aside after the aside's exchange 1 = the refractive-index chat
  (4.4 KB, 2 questions). The answers carry `📝:` summaries, as real ones do.

  | submission | memory off (default) | memory on, 4 full exchanges |
  |---|---|---|
  | root, question right after the aside (R3) | 3.6k to 11.4k tokens | 1.6k to 5.8k |
  | root, last question (R7) | 8.3k to 16.1k | 5.2k to 5.8k |
  | aside, last question | 8.2k to 11.3k | 8.2k to 5.7k |
  | nested aside, last question | 3.3k to 7.3k | 3.3k to 6.2k |
  | real repo pair basics.md to refractive-index (aside after the cut / the child) | unchanged (1.3k / 2.4k) | n/a |

  There are two effects. (1) The asides are now visible, which is the point: R3
  and R7 gain the aside's 7.8k tokens. (2) Ancestors were always sent as their
  `📝:` summaries; now they render like any exchange, so with memory off they
  are sent in full, `🧠:` lines included as in the current file. That is the
  nested case's growth with the same 9 messages. With `chat_memory` enabled,
  the window spans the whole linearized tree, so the long cases come out
  smaller than before.

