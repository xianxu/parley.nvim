---
id: 000008
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# deletion of a tree of chat

Previously, chat deletion only deletes a single file, leaving dangled reference. this is by design. here we add a new functionality <C-D>, to delete the whole tree.

## Done when

- whole chat tree can be deleted in one go
- <C-d> still work to delete a single file and leave reference dangled

## Plan

- [x] Add `M.delete_chat_tree(buf)` in `init.lua` after `collect_tree_files`
- [x] Add `<C-g>D` keymap in `prep_chat()` calling `M.delete_chat_tree`
- [x] Add "Delete chat tree" to keybinding help lines
- [x] Lint passes (no new warnings)
- [x] Tests pass

## Log

### 2026-03-28

Implemented `<C-g>D` to delete entire chat tree. Reuses existing `find_tree_root_file` and `collect_tree_files`. Shows confirmation with list of all files before deleting.
