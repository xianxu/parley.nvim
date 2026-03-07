# Spec: Notes Structure

## Overview
Parley organizes notes within `notes_dir` by date (Year/Month/Week).

## Directory Layout
- `notes_dir/YYYY/MM/weekNN/DD-subject.md`.
- Example: `notes/2026/03/week10/07-design-plans.md`.

## Note Creation
### Command: `:ParleyNoteNew` (`<C-n>c`)
- Prompts for a subject.
- Automatically creates the sub-directory structure.
- Opens the new note in a Neovim buffer.

### Subject-Based Organization
- If the first word of the subject matches a sub-directory in `notes_dir`, the note is created there (without the date prefix).
- Example: `notes/project-name/task-description.md`.

## Navigation
- `:ParleyYearRoot` (`<C-n>r`): Changes the Neovim working directory to the current year's notes folder.
