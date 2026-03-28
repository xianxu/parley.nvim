# Note Finder

- **Command**: `:ParleyNoteFinder` (`<C-n>f`) -- floating picker for notes
- Searches `notes_dir` recursively for `.md` files; excludes `notes_dir/templates/`
- Paths shown relative to `notes_dir`, sorted newest-first
- Date inferred from directory path (`YYYY/MM/weekNN/DD-subject.md`) drives sort order over mtime

## Special Folders
- First-level folders under `notes_dir` that aren't `templates` or dated paths = special named folders
- Special folder notes show braced prefix: `{K} evergreen-note.md`
- Special folder notes always visible regardless of recency window
- Search includes braced label; `{K}` filters to that folder, bare `{}` filters to dated tree only
- Braced filters match only folder labels, not arbitrary row text
- Braced filters persist between picker invocations (seeded with trailing space on reopen)

## Recency
- Same month-based cycle model as Chat Finder: `note_finder_recency.months` default, `note_finder_recency.presets`, then `All`
- Directory-based date ranges decide folder overlap with recency cutoff (may include slightly older files)

## Picker Actions
- `<C-d>`: delete note (with confirmation)
- `<C-a>`/`<C-s>`: cycle recency window left/right
- Select: opens note in source window
