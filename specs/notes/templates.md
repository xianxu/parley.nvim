# Note Templates

- Stored in `notes_dir/templates/`; built-ins created on first use
- Built-ins: `basic.md`, `daily-note.md`, `meeting-notes.md`, `interview.md` (has `:00min`)

## Command: `:ParleyNoteNewFromTemplate` (`<C-n>t`)
- Floating picker for template selection
- Same creation rules as `:ParleyNoteNew` (plain=dated tree, `{K}`=named folder, bare `{}`=rejected, multiple braced=rejected)

## Filename Slug
- Lowercased subject + simplified template-name suffix
- Suffix: strip `.md`, split all template filenames into segments, remove segments appearing in > 3 templates
- Example: subject `xian xu` + template `hiring-HMS-Hiring-Manager-Phone-Screen.md` -> `xian-xu-hms-manager-phone-screen.md`

## Substitution
- Placeholders in template replaced with current values (date, subject, etc.)
