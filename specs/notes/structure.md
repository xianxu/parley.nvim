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
- Plain subjects are always treated as normal note titles, even if the first word matches a first-level folder name under `notes_dir`.
- Example: `K task-description` MUST create a dated note such as `notes/YYYY/MM/WNN/DD-K-task-description.md`.
- Only the explicit braced top-level folder syntax from Note Finder labels may bypass the dated Year/Month/Week layout. A subject like `{K} some document title` MUST create `notes_dir/K/some-document-title.md`.

## Navigation
- `:ParleyNoteFinder` (`<C-n>f`): Opens a recursive note picker rooted at `notes_dir`.
- `:ParleyYearRoot` (`<C-n>r`): Changes the Neovim working directory to the current year's notes folder.
