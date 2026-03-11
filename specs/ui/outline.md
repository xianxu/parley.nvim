# Spec: Outline Navigation

## Overview
Parley provides an outline navigator to quickly jump between chat turns and Markdown headings.

## Command
- `:ParleyOutline` (`<C-g>t`): Opens a floating picker with headings and conversation turns.

## Logic
- Identifies user questions (`💬:`) and assistant answers (`🤖:`).
- Identifies Markdown headings (`#` → 🧭, `##` → `•`).
- Items are listed in **document order** (top to bottom, ascending line number).

## Picker Interaction
- Uses the standard `float_picker` two-window layout (results + prompt).
- Typing in the prompt fuzzy-filters and highlights matching characters.
- Single click selects an item; double-click or `<CR>` confirms and navigates.
- Selecting an item jumps the cursor to that line in the buffer with a brief highlight flash.
