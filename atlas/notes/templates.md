# Note Templates

- Stored in `notes_dir/templates/`; built-ins created on first use only if the templates directory is absent
- Built-ins: `basic.md`, `daily-note.md`, `meeting-notes.md`, `interview.md` (has `:00min`)

## Command: `:ParleyNoteNewFromTemplate` (`<C-n>t`)
Floating picker for template selection. Same creation rules as `:ParleyNoteNew` (plain = dated tree, `{K}` = named folder). Filename slug incorporates simplified template name.

Edit or add Markdown files in that directory to customize templates. An existing
empty directory produces “No template files found”; missing individual built-ins
are not regenerated automatically. Template placeholders include `{{title}}`,
`{{date}}`, and `{{week}}`.

The app starter omits the plugin-default Ctrl+n t shortcut; the command remains
available. `lua/parley/notes.lua` (`create_default_templates`,
`cmd_note_new_from_template`, `new_note_from_template`) owns this flow.
