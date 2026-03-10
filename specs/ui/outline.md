# Spec: Outline Navigation

## Overview
Parley provides an outline navigator to easily navigate through chat turns and Markdown headings.

## Command
- `:ParleyOutline` (`<C-g>t`): Opens a floating picker with headings and conversation turns.

## Logic
- Identifies user questions (`💬:`) and assistant answers (`🤖:`).
- Identifies Markdown headings (`#`, `##`, etc.) used for organization.
- Items are listed most-recent-first.

## Picker Interaction
- Selecting an item jumps the cursor to that line in the buffer with a brief highlight flash.
- Single click selects an item; double-click or Enter confirms and navigates.
- Use native `/` to search within the outline list.
