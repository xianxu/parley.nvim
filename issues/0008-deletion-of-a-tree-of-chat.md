---
id: 0008
status: open
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# deletion of a tree of chat

Previously, chat deletion only deletes a single file, leaving dangled reference. this is by design. here we add a new functionality <C-g>D, to delete the whole tree.

## Done when

- whole chat tree can be deleted in one go
- <C-g>d still work to delete a single file and leave reference dangled

## Plan

- [ ]

## Log

### 2026-03-28

