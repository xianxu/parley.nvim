---
id: 000013
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# a short cut to copy with context

<leader>ck to copy the following information

file:line_num:column_num

tell me more about `selected text`

the copy -2 line to +2 line of current line

## Done when

- `<leader>ck` in normal mode copies `file:line:col` + 2 lines of context above/below
- `<leader>ck` in visual mode copies `file:line:col`, `tell me more about \`selection\``, and context lines around selection

## Plan

- [x] Add `chat_shortcut_copy_context` config entry
- [x] Implement `M.cmd.CopyContext` — handles both normal and visual mode
- [x] Register keymap in chat and markdown buffer setup
- [x] Add to which-key help
- [x] Verify tests pass

## Log

### 2026-03-28

- Implemented `CopyContext` command: normal mode outputs `file:line:col` + surrounding context with line numbers; visual mode adds `tell me more about \`selection\`` between location and context
- Context window is +/-2 lines, clamped to buffer bounds
- Registered in both chat and markdown buffers
