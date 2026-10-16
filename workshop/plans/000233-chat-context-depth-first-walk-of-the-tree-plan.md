# #233 plan: chat context is a depth-first walk of the tree, cut at the cursor

## Goal

A submission's context is the chat tree in depth-first pre-order, cut at the
exchange being submitted: the ancestor path plus every subtree to its left,
rendered by ONE message builder. Asides that `<M-i>` creates become visible to
every later question.

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

- [ ] M1: context.
  - `lua/parley/chat_tree.lua`: `path_up`, `linearize`, `load`.
  - `build_messages` over the sequence.
  - `chat_respond` wires it and drops the ancestor renderer.
  - Unit tests on `linearize`: R1 → A → R2 sends R1, A1, R2; sibling A to
    the left of B; nothing to the right; regenerate excludes the exchange's
    children; a visited/cycle guard; a non-reciprocal parent; the depth cap.
  - `build_messages`: the memory window spans the sequence; the visual range
    is current-file only; per-file image paths.
  - Integration test over real files with nested and inline branches,
    including an unsaved child buffer.
  - Atlas: chat branching/context.
- [ ] M2: one tree walker. The three root-finders (`exporter.find_tree_root`,
  `init.find_tree_root_file`, `outline`'s copy) and the two downward walkers
  (`exporter.collect_tree`, `init.collect_tree_files`) derive from
  `chat_tree`. They need a `root(abs)` built from `path_up`'s link-following,
  and `files(root)`, the DFS file order (`linearize` with no cut, files only).
  Export, delete-tree and the outline keep their tests green, plus a
  single-source sweep that no other module follows `parent_link`.

M2 is separable: it changes no request. If you prefer, it can be filed as its
own issue, and #233 closes at M1.

## Not doing

- No timestamps or chronological reordering.
- No mode toggle and no opt-out marker (the issue's v1).
- No change to how a file's own exchanges render.
