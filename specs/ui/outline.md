# Spec: Outline Navigation

## Overview
Parley provides an outline navigator to quickly jump between chat turns and Markdown headings. For chat files in a tree (linked via `🌿:`), the outline shows the full tree structure.

## Command
- `:ParleyOutline` (`<C-g>t`): Opens a floating picker with headings and conversation turns.

## Logic
- Identifies user questions (`💬:`), Markdown headings (`#` → 🧭, `##` → `•`), and branch references (`🌿:`).
- Items are listed in **document order** (top to bottom, ascending line number).

## Tree-Aware Outline (Chat Files)
- For chat files, the outline walks the parent chain to find the tree root, then builds a unified outline across all linked files.
- The root file's topic is shown as `📋 topic` at the top.
- All branches are **expanded by default**, showing child questions indented under the `🌿` item.
- Each depth level adds 2 spaces of indentation.
- Selecting a `🌿` item jumps to that `🌿:` line in its parent file.
- Selecting a question/header from a child file opens that file (in the same window) and jumps to the line.

## Picker Interaction
- Uses the standard `float_picker` two-window layout (results + prompt).
- Typing in the prompt fuzzy-filters and highlights matching characters.
- Single click selects an item; double-click or `<CR>` confirms and navigates.
- Selecting an item jumps the cursor to that line in the buffer with a brief highlight flash.
- Cross-file navigation uses `edit` (same window), not `split`.
