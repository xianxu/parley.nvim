---
id: "000109"
title: "Cross-file pending review marker finder"
status: done
---

## Summary

When a folder contains `.md` files with pending review markers (🤖 or ㊷), there is no way to discover them without opening each file individually. We need a way to scan all markdown files under the cwd and surface files/markers needing human attention.

## Spec

A float picker (same infrastructure as `ChatFinder`) triggered by a keybinding (`<C-g>vf`) that lists all `.md` files under cwd containing pending review markers, with preview of the marker text. Selecting an entry jumps directly to the marker line.

**Precondition:** only active when the repo is parley-enabled (`.parley` marker file present at git root). If not in a parley repo, show a warning.

**Scan root:** the current nvim cwd (`vim.fn.getcwd()`), not the repo-relative paths used by the issue tracker. This lets it work on any subdirectory the user is working in.

**Pending marker definition** (turn-aware):
- `㊷` markers with even section count — agent asked a question, awaiting human reply
- `🤖` markers with odd section count — agent made a finding, awaiting human reply
- Multi-turn is handled correctly, e.g. `🤖[]{}[]` (3 sections = odd = pending)

**Picker behavior** (follow `ChatFinder` / `float_picker` conventions):
- One entry per pending marker: `filename (relative to cwd) | line | marker text preview`
- Preview pane shows the file around the marker line
- Enter → open file, jump to marker line
- Reuses `parse_markers` for detection; `float_picker` for display

**Config:** `review_shortcut_finder` (default `<C-g>vf`), registered as a global shortcut (available in any buffer, not just markdown).

## Plan

- [x] Add `M.scan_pending(dir)` to `skills/review/init.lua` — walks `.md` files under `dir`, returns `{filepath, marker}` list
- [x] Build picker entries + preview using existing `float_picker` infrastructure
- [x] Add `review_shortcut_finder` to `config.lua` and register as global shortcut in `init.lua`
- [x] Guard: check for `.parley` at git root before scanning; warn if absent

## Log
