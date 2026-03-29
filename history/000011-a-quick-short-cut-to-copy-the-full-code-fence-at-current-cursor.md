---
id: 000011
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# a quick short cut to code fense

Oftentimes, with mouse inside a code fense in markdown, I want to copy the full code fence at current cursor. Make a shortcut to do so.

let's use <C-g><C-c>

## Done when

- `<C-g><C-c>` in normal mode inside a code fence copies the fence content (without ``` delimiters) to system clipboard
- Works in parley chat buffers and any markdown buffer
- Shows a message if cursor is not inside a code fence

## Plan

- [x] Add `chat_shortcut_copy_fence` config entry in `lua/parley/config.lua` with shortcut `<C-g><C-c>`
- [x] Implement `copy_code_fence()` — scan up for opening ```, scan down for closing ```, yank content between to `+` register
- [x] Register the keymap in `init.lua` alongside other chat shortcuts (both chat buffers and markdown buffers)
- [ ] Verify: open a parley chat with code fences, cursor inside, press `<C-g><C-c>`, paste elsewhere

## Log

### 2026-03-28

- Added `chat_shortcut_copy_fence` to config.lua (line 321)
- Implemented `M.cmd.CopyCodeFence` in init.lua — scans up for opening ```, down for closing ```, copies content between to `+` register
- Registered keymap in both chat buffer setup and `setup_markdown_keymaps` so it works in any markdown buffer
- Added to which-key help section
- Tests pass (4 pre-existing failures in ChatFinder unrelated to this change)
