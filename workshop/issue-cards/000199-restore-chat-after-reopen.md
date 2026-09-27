---
id: '000199'
status: done
started: 2026-08-18T15:21:36-07:00
created: 2026-08-18
updated: 2026-08-20
estimate_hours: 1.13
actual_hours: 0.24
---

# Restore chat setup after buffer reopen

## Problem

Deleting a prepared chat buffer with `:bdelete` unloads it and removes its
buffer-local keymaps. Opening the same document again through Chat Finder
resurrects the same buffer handle, but `M._prepared_bufs[buf]` still says the
buffer is prepared. `prep_chat` therefore returns before reinstalling chat
setup, leaving visual `<M-CR>`, visual `<C-g><C-g>`, and the other buffer-local
chat behavior unavailable until Neovim restarts.
