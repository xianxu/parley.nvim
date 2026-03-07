# Spec: Note Templates

## Overview
Parley's template system allows creating notes with pre-defined structures.

## Location
- Templates are stored in `notes_dir/templates/`.
- Built-in templates are created on first use.

## Built-in Templates
- `basic.md`: Simple note with title and date.
- `daily-note.md`: Tasks, notes, and reflection.
- `meeting-notes.md`: Attendees, agenda, and action items.
- `interview.md`: Pre-configured for interview mode (includes `:00min`).

## Selection
### Command: `:ParleyNoteNewFromTemplate` (`<C-n>t`)
- Opens a Telescope picker (or `vim.ui.select` fallback).
- Selects from available `.md` files in the templates folder.

## Substitution
- The plugin MUST replace specific placeholders in the template with current values (e.g., date, subject).
