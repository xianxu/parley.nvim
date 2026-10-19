---
id: 000397
status: done
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
severity: low
started: 2026-10-19T01:00:46-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.24
tracker:
    version: 1
    completion:
        token: close-e104cbd88303
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 555ad10936db22758652a4a29f0a2ce861a8b1de
        evidence_commit: fcc4a21d91be7041ab68a7c9d9ce4df078683185
        landed_commit: 70c00daf62a61a53bed9d9385dd734f1e94c94ed
---

# breadcrumb tree path: trailing comment on parent: breaks the chain; per-node buffer scan; untested path fallbacks

## Problem

Three Minor notes from #391's round-2 close review (archived close review for #391, PR #315), left as follow-ups:

1. **Bug: a trailing comment on `parent:` becomes part of the path.** `side_tree_model.parse` takes everything after `parent:` as the value, so `parent: ../A.md # note` resolves to `../A.md # note`, which does not exist, and the winbar shows the `?` missing marker instead of the real tree path. The same parse checks the opening line as exactly `---`, while `chat_parser.find_header_end` trims it, so a `--- ` opener is treated as having no frontmatter.
2. **Hot-path cost: a buffer scan per chain node.** `file_history.read_node` calls `helpers.buffer_for(path, true)` before the cache check. That walks every buffer and calls `vim.fn.resolve` on each, for every node in the chain, on every BufEnter/WinEnter, so the cost is O(buffers × (depth+1)). The #391 plan's hot-path budget counted only frontmatter reads (ARCH-CONSTRAINTS). One resolved name-to-buffer map per `observe` would make it O(buffers + depth).
3. **Untested fallbacks.** `breadcrumb_model.path_value` / `file_history.path_display` have tests only for the `.git`-relative branch. The `~` (home-relative) and `/` (absolute) fallbacks were correct when probed by hand but are untested.
