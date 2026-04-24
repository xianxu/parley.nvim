# Notes Structure

## Layout
- Dated notes: `notes_dir/YYYY/MM/weekNN/DD-subject.md`
- Special folder notes: `notes_dir/<folder>/slug.md`

## Multi-root Architecture
Notes support multiple roots via `note_roots` config (same pattern as chat roots). The primary root receives new notes; extra roots are searchable in the finder. In repo mode, `workshop/notes/` becomes primary and the global `notes_dir` becomes extra.

Shared infrastructure lives in `root_dirs.lua` (generic multi-root manager) with `note_dirs.lua` as a thin wrapper. See [Repo Mode](../infra/repo_mode.md) for details.

## Note Creation (`:ParleyNoteNew`, `<C-n>c`)
Prompts for subject, auto-creates directory structure under the primary note root. Plain subjects go to dated tree. Braced prefix `{K} title` targets named folder instead.

## Navigation
- `:ParleyNoteFinder` (`<C-n>f`): note picker (scans all roots)
- `:ParleyNoteDirs` (`<C-n>h`): manage note roots (add/rename/remove)
- `:ParleyYearRoot` (`<C-n>r`): cd to current year's notes folder
