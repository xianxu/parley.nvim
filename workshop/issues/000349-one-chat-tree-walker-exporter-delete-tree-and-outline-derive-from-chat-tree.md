---
id: 000349
status: open
deps: [parley.nvim#233]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '6eed07c7550d0f36449ad76efcda55223438184d' # card fields mirrored from issue-cards; edit via sdlc
---

# One chat tree walker: exporter, delete-tree and outline derive from chat_tree

## Problem

The chat tree is walked by five copies of the same logic. There are three root-finders that follow `parent_link` upward: `exporter.find_tree_root`, `init.find_tree_root_file` and outline's copy. There are two downward walkers: `exporter.collect_tree` and `init.collect_tree_files`. #233 adds `lua/parley/chat_tree.lua` as the walker for request context; split out of #233 (M2) per the TL.

## Spec

## Done when

- The root-finders and downward walkers derive from `chat_tree`: a `root(abs)` built from its link-following, and `files(root)` (its DFS file order).
- Export, delete-tree and the outline keep their tests green.
- A single-source sweep fails when any other module follows `parent_link` or walks `branches` itself.

## Plan

- [ ]

## Log

### 2026-10-16
