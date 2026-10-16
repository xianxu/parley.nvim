---
id: 000349
status: open
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
github_issue:
severity: low
---

# One chat tree walker: exporter, delete-tree and outline derive from chat_tree

## Problem

The chat tree is walked by five copies of the same logic. There are three root-finders that follow `parent_link` upward: `exporter.find_tree_root`, `init.find_tree_root_file` and outline's copy. There are two downward walkers: `exporter.collect_tree` and `init.collect_tree_files`. #233 adds `lua/parley/chat_tree.lua` as the walker for request context; split out of #233 (M2) per the TL.
