# Spec: UI Pickers

## Overview
Parley uses a single custom floating-window picker (`float_picker`) for all selection UIs.
No external dependencies (Telescope or similar) are required.

## Layout
Each picker opens two stacked floating windows:
- **Results window** (top): read-only list of items, `cursorline` shows the current selection.
- **Prompt window** (bottom, 1 line): focused on open, always in insert mode. The user types a fuzzy query here.

Both windows share the same width and are centered as a unit. Actual dimensions are clamped to the screen with `MARGIN_H = 4` cols and `MARGIN_V = 3` rows on each side. The prompt window adds a fixed overhead of 5 rows (two sets of borders + 1 content row) to the total vertical height.

`VimResized` repositions both windows (cleaned up on close).

## Fuzzy Search
Typing in the prompt filters and re-ranks the results live on every keystroke:
- Query is split on whitespace into **words**.
- **All words must match** for an item to be included (AND logic).
- **Word order does not matter** — `"gpt open"` matches `"openai gpt-4"`.
- Within each word, characters must appear **in order** in the item (subsequence match, case-insensitive).
- Items are scored and sorted by match quality (consecutive runs, word-boundary hits, prefix matches score higher).
- Matched characters are highlighted in the results window using the `Search` highlight group.
- Empty query shows all items in their original order with no highlights.

## Mouse Interaction
- **Single click** in results: moves selection to clicked row; focus stays in the prompt (insert mode).
- **Double-click** in results: confirms the selection and closes the picker.
- Clicking while the prompt is in insert mode is handled by a prompt-side `<LeftMouse>` mapping that calls `getmousepos()` — this prevents Neovim's default insert-mode click behavior (exit-insert + window-switch) from stealing focus.

## Keyboard (from prompt)
| Key | Action |
|-----|--------|
| `<CR>` | Confirm selected item |
| `<Esc>` / `<C-c>` | Cancel and close |
| `<C-j>` / `<Down>` | Move selection down |
| `<C-k>` / `<Up>` | Move selection up |

## Sizing
- `desired_w` = max of title width + 4 and longest item width + 2, or `opts.width` if provided.
- `desired_h` = number of items, or `opts.height` if provided (controls results window only).
- Both are clamped to screen bounds.

## WinLeave Behaviour
The picker closes if focus moves to any window that is neither the results nor the prompt window.

## Agent Picker
- `:ParleyAgent`: Opens a picker with agent names, providers, and models.
- The current agent is marked with `✓` and sorted to the top; others are alphabetical.

## System Prompt Picker
- `:ParleySystemPrompt`: Opens a picker with named system prompts.
- The current prompt is marked with `✓` and sorted to the top; others are alphabetical.
- Descriptions are truncated to 80 characters in the display.

## Chat Finder
- `:ParleyChatFinder` (`<C-g>f`): Browse and open chat files.
- **Recency Filter**: By default shows files from the last `chat_finder_recency.months`.
- **Extra mappings** (insert mode in prompt):
    - Toggle key (`<C-g>a` by default): Toggle between recent and all files.
    - Delete key (`<C-d>` by default): Delete the selected chat file.
    - `<C-g>?`: Open Parley key-bindings help.
- Files are sorted by modification date, newest first.

## Navigation / Outline Picker
- `:ParleySearchChat` (`<C-g>n`) and `:ParleyOutline` (`<C-g>t`): Navigate headings and conversation turns.
- Items are listed in document order (top to bottom).
- Selecting an item jumps the cursor to that line with a brief highlight flash.
