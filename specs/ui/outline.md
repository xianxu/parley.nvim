# Spec: Outline Navigation

## Overview
Parley provides an outline navigator to easily navigate through chat turns and Markdown headings.

## Command
- `:ParleyOutline` (`<C-g>t`): Opens a Telescope picker with headings and conversation turns.

## Logic
- Identifies user questions (`💬:`) and assistant answers (`🤖:`).
- Identifies Markdown headings (`#`, `##`, etc.) used for organization.
- Items are listed in the order they appear in the buffer.

## Telescope Integration
- Selecting an item in the picker jumps the cursor to that line in the buffer.
- Preview MUST show the content around the selected heading or turn.
