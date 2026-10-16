# #233 plan: chat context is a depth-first walk of the tree, cut at the cursor

## Goal

A submission's context is the chat tree in depth-first pre-order, cut at the
exchange being submitted: the ancestor path plus every subtree to its left,
rendered by ONE message builder. Asides that `<M-i>` creates become visible to
every later question.

## Core concepts

| Concept | Status | Meaning |
|---|---|---|
| `path_up` | new | the path from the topmost ancestor that links back down to the current file |
| `linearize` | new | the tree in depth-first pre-order along the path, cut at the submitted exchange; asides off the current file carry their anchor |
| `io_deps` | new | the editor's IO for the walk: buffer-first reads and the previous-answer substitution |
| `tree_sequence` | new | a request's exchanges: the linearized tree, with the current file's own input copies and its tail after the cut |
| `_tree_sequence` | new | test seam for `tree_sequence` |
| `other_files` | new | test helper (`tests/helpers/tree_context.lua`): the text a request takes from the tree's other files |
| `_conversation_after_lead` | modified | the topic request's input; it now keeps only the current file's messages |
| `resolve_remote_references` | modified | walks the request's sequence, reading each file's own cache |
| `build_ancestor_messages` | deleted | the second renderer, replaced by build_messages over the sequence |
| `collect_ancestor_chain` | deleted | the upward-only walk, replaced by path_up and linearize |
| `collect_ancestor_messages` | deleted | its wrapper |

## The walk (the simplest one that is correct)

Two steps, and only the second is new.

1. **Path up.** Starting at the current file, follow `parent_link` upward.
   Each parent must list the child among its `branches` (the reciprocal link that
   today's `collect_ancestor_chain` already looks for), which gives the
   branch's position: `after_exchange` and its index among the parent's
   branches. The path stops at a parent that does not link back. That parent and
   everything above it contribute nothing, which matches today's `branch_after =
   0` and keeps an orphaned or renamed child from pulling in an unrelated tree.
   It also stops at the depth cap (20) or a cycle (a visited set).

2. **Emit, root first.** For each file on the path, with `stop` = the position
   of the next file's branch (or, in the current file, the cut):

   ```
   emit(file, stop):
     for each slot k = 0 .. #exchanges:
       if k >= 1: emit exchange k            -- the cut exchange: question only
       for each branch b with after_exchange == k, in line order:
         if (k, b) is the path branch: return    -- descend to the next file
         if (k, b) is at or after the cut:  return
         emit_subtree(b)                      -- the whole child file, DFS
   ```

   `emit_subtree` is the same loop with no stop: the child's exchanges and its
   own branches, recursively. It shares the visited set, so a file reached
   twice, or a cycle, is emitted once. A child that cannot be read is skipped
   with a debug log, the way unreadable parents are today.

   In the current file, the cut is `(exchange_idx, question only)`. Branches with
   `after_exchange >= exchange_idx` are after it, which is rule 1: the children of
   an exchange being regenerated never leak in.

Pure core: `chat_tree.linearize(path, load)` takes the path (step 1's output:
each element a parsed file and its stop) and an injected `load(ref, dir)` for
subtrees. It returns an ordered list of `{ exchange, file, current }`. All
tests drive it with hand-built parsed tables and a table-backed loader.

IO shell: `chat_tree.load(abs)`, buffer-first (`helpers.chat_lines`), parsed,
with `previous_answer.substitute` applied for a buffer being regenerated (what
the ancestor walk does today, now applied to every file). The current file is
never re-read: its parsed input (`input_parsed`) is the path's last element.

## One renderer

`build_messages` takes the linearized sequence instead of a single
`parsed_chat.exchanges`:

- `exchange_idx` and the memory window (`window_size`, `preserve_exchange`)
  index the sequence. `max_full_exchanges` then spans the whole linearized
  chat, so old asides and ancestors compress into summaries like any old
  exchange.
- The visual-range line filters (`start_index`, `end_index`) apply only to
  exchanges whose `current` is true. They are line numbers in the current file.
- Image attachments resolve against the exchange's own file
  (`attach_question_images` gets a per-slot `chat_path`).
- Headers, the agent and the system prompt come from the current file, as
  today.

`build_ancestor_messages`, `collect_ancestor_chain`, `collect_ancestor_messages`
and their test seams are deleted (ARCH-DRY). Their tests move to the
linearizer, or to `build_messages` over a sequence.

**Behaviour changes beyond the issue's headline (approval asked):**

- Ancestors and asides are now rendered like any exchange. Within the memory
  window they are sent in FULL (today ancestors are always summary-first),
  with footnote stripping and tool blocks. An exchange with `@@` file
  references is pinned in full, and its files are inlined, as in its own
  file's requests. Today an ancestor's file references are dropped.
- A branch meant as an alternative leaks into later siblings. The issue
  accepts this for v1, with no toggle.

## Milestones

One boundary (M2 split out as #349 per the TL, so no Mx tags):

- [x] `lua/parley/chat_tree.lua`: `path_up`, `linearize`, `io_deps`.
- [x] `build_messages` over the sequence: the memory window spans it, the
  visual range applies to the current file only, images resolve per file, and
  it returns the current file's messages for the topic request.
- [x] `chat_respond` wires `tree_sequence` and drops the ancestor renderer.
- [x] Unit tests: `chat_tree_spec` (linearize, path_up) and
  `build_messages_spec` (tree sequence).
- [x] Integration test `chat_tree_context_spec` over real files, with nested
  and inline branches and an unsaved child buffer. The ported specs are
  `ancestor_chain_rename_spec` and `chat_respond_spec`.
- [x] Atlas: chat/lifecycle (Context Assembly), chat/memory, chat/attachments,
  traceability.

## Not doing

- No timestamps or chronological reordering.
- No mode toggle and no opt-out marker (the issue's v1).
- No change to how a file's own exchanges render.

## Revisions

- 2026-10-16, TL approval. M1 is approved; M2 (one tree walker for the exporter,
  delete-tree and the outline) is split out as #349, and #233 closes at M1.
  Behaviour (a), (b) and (c) are accepted. The operator decides on (a), full
  ancestors inside the memory window, with the measured request sizes, before
  merge. Delta: M2 removed from this plan, and the one remaining boundary takes
  plain checkboxes.
- 2026-10-16, found while building: automatic topic requests used to exclude
  ancestor context by message count, because the ancestors were contiguous after
  the lead. The tree's other files are now interleaved, so `build_messages`
  returns the messages its current-file exchanges produced, and the topic input
  keeps only those.

