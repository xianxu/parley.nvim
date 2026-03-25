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
- Opens Parley's floating picker for available templates.
- Selects from available `.md` files in the templates folder.
- Template-based note creation MUST honor the same creation rules as `:ParleyNoteNew`: plain subjects stay in the dated tree, and only braced forms such as `{K} some document title` create in a top-level note folder.
- Template-based note creation MUST also reject bare `{}` input for the same reason.
- Template-based note creation MUST also reject repeated leading braced segments such as `{K} {another} love`.
- Template-based note filenames MUST use a lowercased slug built from the subject plus a simplified template-name suffix.
- The template suffix MUST strip the `.md` extension, split all template filenames into slug segments, count segment frequency across the template directory, and remove any segment whose count is greater than `3`.
- Example: subject `xian xu` with template `hiring-HMS-Hiring-Manager-Phone-Screen.md` MUST create a filename ending in `xian-xu-hms-manager-phone-screen.md`.

## Substitution
- The plugin MUST replace specific placeholders in the template with current values (e.g., date, subject).
