---
id: 000349
status: working
deps: [parley.nvim#233]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '8a238ecdf49a9a6fdbbeeedb36eff261b872ea04' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T03:39:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "9e1762db"}
---

# One chat tree walker: exporter, delete-tree and outline derive from chat_tree

## Problem

The chat tree is walked by five copies of the same logic. There are three root-finders that follow `parent_link` upward: `exporter.find_tree_root`, `init.find_tree_root_file` and outline's copy. There are two downward walkers: `exporter.collect_tree` and `init.collect_tree_files`. #233 adds `lua/parley/chat_tree.lua` as the walker for request context; split out of #233 (M2) per the TL.

## Spec

### Core concepts

| Concept | Status | Meaning |
|---|---|---|
| `root` | new | `chat_tree.root(file, deps)`: the first file of `path_up`; an unloadable or orphaned file is its own root |
| `files` | new | `chat_tree.files(root, deps)`: the tree's files in depth-first pre-order, each once, depth-capped |
| `disk_deps` | new | `chat_tree.disk_deps()`: the walker's IO over saved files, for commands that act on files |
| `chat_tree_files` | new | init's one call into `root` and `files` for delete-tree, move and `get_chat_tree_files` |
| `find_tree_root` | modified | exporter and outline: thin wrappers over `chat_tree.root` |
| `collect_tree` | modified | exporter: the info objects for `chat_tree.files`, each file read once |
| find_tree_root_file, collect_tree_files | deleted | init's copies of the root-finder and the downward walk |

## Done when

- The root-finders and downward walkers derive from `chat_tree`: a `root(abs)` built from its link-following, and `files(root)` (its DFS file order).
- Export, delete-tree and the outline keep their tests green.
- A single-source sweep fails when any other module follows `parent_link` or walks `branches` itself.

## Plan

Design (quick flow: about 30 code lines added, about 90 removed):

- **`chat_tree.root(file, deps)`:** the first file of `path_up`. Load the file, walk `path_up` and return `path[1].file`. A file that cannot be loaded is its own root. One link-following rule (ARCH-DRY).
- **`chat_tree.files(root, deps)`:** the tree's files in DFS pre-order (root, then each branch in order, recursively). Each visited file is visited once, under the same depth cap as `linearize`. Returns `{ file, parsed }[]`; an unloadable file is skipped. Pure over `deps`, like `path_up` (ARCH-PURE): unit-tested with hand-built parses.
- **Consumers derive:**
  - **init** (delete-tree, chat move, `get_chat_tree_files`): `find_tree_root_file` and `collect_tree_files` are deleted; they call `root` and `files` with `io_deps()`.
  - **exporter:** `find_tree_root` and `collect_tree` are deleted. Its `deps.load` is `read_chat_file`, keeping the info object per file, so each file is still read once (the comment at the call site). Its test seams `_find_tree_root` and `_collect_tree` become thin wrappers, or `exporter_tree_spec` moves to the new seams.
  - **outline:** `find_tree_root` is deleted; `<M-t>` calls `root` with `io_deps()`. The outline's downward render walk (`_build_tree_outline_items`) stays: it recurses through rendered branch rows under the expand/collapse state, so it is not a file walk. It takes its root from `chat_tree`.
- **Behaviour change (one, deliberate):** the three old root-finders followed `parent_link` as long as the parent was readable, even when the parent no longer listed the child. Starting from such an orphaned child, delete-tree, export, move and `<M-t>` then acted on the parent's tree, which does not contain the current file. Delete removed a tree the operator wasn't in and left their file. `path_up` stops at a parent that doesn't link back, so these now act on the child's own subtree, the same as the request context. A test pins this for delete-tree's file list.
- **Loading:** `io_deps` reads a loaded buffer ahead of the disk. Root and files only read `parent_link` and `branches`, so an unsaved edit to either is now honoured.
- **Sweep (tests/arch/single_source_sweeps_spec.lua):**
  - `parent_link.path` is followed only in `chat_tree.lua`.
  - `resolve_chat_path(branch.path` appears only in `chat_tree.lua` and `outline.lua`. The outline's branch rows resolve their own child path for display; the sweep names this reason.
  - Each pattern must select a non-empty corpus.
- ARCH-CONSTRAINTS: interactive commands over a tree of a few files; the same reads as before. ARCH-MOCK, SECURE, ORDER, FUNERAL: N/A. There is no external IO beyond the chat files already read, no new input boundary, no state held between events (each command walks afresh), and nothing durable is created.

Steps:

- [ ] `chat_tree.root` and `chat_tree.files`, with unit cases (order, a cycle, the depth cap, an unloadable file, an orphaned child as its own root)
- [ ] init: delete-tree, move and `get_chat_tree_files` on chat_tree; delete the old walkers
- [ ] exporter on chat_tree with its own loader; update the seams or the spec
- [ ] outline `<M-t>` root from chat_tree; delete `find_tree_root`; port `outline._find_tree_root`'s test seam
- [ ] sweep guard, with the outline exception explained
- [ ] atlas (chat/lifecycle, export, outline) and traceability

## Revisions

- 2026-10-16, TL: keep the new root rule. The old rule was a bug, and one walker means one notion of the tree; note the change in the close and the atlas.
- 2026-10-16, build: delete-tree, move, export and the outline load through `chat_tree.disk_deps()`, not `io_deps()`. They act on the saved files, and the outline renders from disk. Two chat_move cases found this: they append the 🌿 line on disk while the root's buffer is loaded. The request context keeps `io_deps` (buffer first). A readable file without a header (a legacy `# topic:` chat) loads as a leaf with no links, as the old init walker listed it. chat_finder_logic_spec's move cases found this.

## Log

### 2026-10-16
