---
id: '000249'
status: done
started: 2026-09-14T09:15:17-07:00
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.51
actual_hours: 1.79
---

# Fix chat finder delete key collision

## Problem

Ctrl+d in Chat Finder does not invoke single-chat deletion. The shipped delete_tree key `<C-D>` is identical to `<C-d>` after Neovim termcode normalization; the later extra mapping overwrites single deletion.
