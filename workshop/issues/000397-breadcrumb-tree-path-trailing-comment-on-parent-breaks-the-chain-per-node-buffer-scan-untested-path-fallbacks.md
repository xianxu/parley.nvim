---
id: 000397
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
severity: low
collaboration-mode: collaboration
card_mirror: 'a6b5b8ec12063437d50ca290efe82359334a6687' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T01:00:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6e340b9c", done: "3b5e5ccc"}
---

# breadcrumb tree path: trailing comment on parent: breaks the chain; per-node buffer scan; untested path fallbacks

## Problem

Three Minor notes from #391's round-2 close review (archived close review for #391, PR #315), left as follow-ups:

1. **Bug: a trailing comment on `parent:` becomes part of the path.** `side_tree_model.parse` takes everything after `parent:` as the value, so `parent: ../A.md # note` resolves to `../A.md # note`, which does not exist, and the winbar shows the `?` missing marker instead of the real tree path. The same parse checks the opening line as exactly `---`, while `chat_parser.find_header_end` trims it, so a `--- ` opener is treated as having no frontmatter.
2. **Hot-path cost: a buffer scan per chain node.** `file_history.read_node` calls `helpers.buffer_for(path, true)` before the cache check. That walks every buffer and calls `vim.fn.resolve` on each, for every node in the chain, on every BufEnter/WinEnter, so the cost is O(buffers × (depth+1)). The #391 plan's hot-path budget counted only frontmatter reads (ARCH-CONSTRAINTS). One resolved name-to-buffer map per `observe` would make it O(buffers + depth).
3. **Untested fallbacks.** `breadcrumb_model.path_value` / `file_history.path_display` have tests only for the `.git`-relative branch. The `~` (home-relative) and `/` (absolute) fallbacks were correct when probed by hand but are untested.

## Spec

## Done when

- `parent: ../A.md # note` (and a quoted value followed by a comment) resolves to `../A.md`, and the opener check trims like `find_header_end`; unit tests in `side_tree_model_spec`.
- `read_node` no longer scans all buffers per chain node; a counted test shows the buffer lookup cost does not scale with depth × buffers.
- Unit tests in `breadcrumb_model_spec` cover the `~` and `/` branches of path display.

## Plan

- [ ]

## Log

### 2026-10-19

### 2026-10-19
- `parse` takes a quoted value as quoted, else the text before whitespace + `#` (a leading `#` included, so `parent: # none` is no parent); `a#b.md` keeps its `#`. The opener trims as `find_header_end` does.
- Buffer lookup: one `helper.loaded_buffer_index` per chain, sharing `buffer_for`'s key function (ARCH-DRY). Revert check: with the old per-node `buffer_for`, the depth test counts 10 scans for depth 8 against 3 for depth 1; with the index both are equal.
- Path form selection moved to pure `breadcrumb_model.located` (ARCH-PURE) and unit-tested for root, home, absolute and a home-prefix lookalike (`/hx`).
