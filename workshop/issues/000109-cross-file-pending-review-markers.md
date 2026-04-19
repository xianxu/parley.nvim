---
id: "000109"
title: "Cross-file pending review marker finder"
status: open
---

## Summary

When a folder contains `.md` files with pending review markers (🤖 or ㊷), there is no way to discover them without opening each file individually. We need a way to scan all markdown files under the cwd and surface files/markers needing human attention.

## Spec

A keybinding (`<C-g>vf`) that scans all `.md` files under `cwd` for pending markers and populates the quickfix list.

**Pending marker definition** (turn-aware):
- `㊷` markers with even section count — agent asked a question, awaiting human reply
- `🤖` markers with odd section count — agent made a finding, awaiting human reply
- Both types can have multi-turn conversations, e.g. `🤖[]{}[]` (3 sections = odd = pending)

**Behavior:**
- Scan all `.md` files under cwd (recursive, using `vim.fn.glob`)
- For each file, run `parse_markers` and collect pending (non-ready) markers
- Populate quickfix with one entry per pending marker, with `filename`, `lnum`, `col`, and the marker text
- Open quickfix if any found; show info message if none
- Reuses existing `parse_markers` and `populate_quickfix` infrastructure

**Config:** add `review_shortcut_finder` (default `<C-g>vf`) alongside other review shortcuts.

## Plan

- [ ] Add `M.scan_folder(dir)` to `skills/review/init.lua` — returns list of `{filename, marker}` pairs
- [ ] Add `M.populate_quickfix_multi(items)` or extend existing `populate_quickfix` to accept cross-file items (it already supports `filename` field)
- [ ] Wire keybinding in `setup_keymaps` and add `review_shortcut_finder` to `config.lua`
- [ ] Register global shortcut (available in any buffer, not just markdown)

## Log
