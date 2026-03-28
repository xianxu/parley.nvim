# Notes Structure

## Layout
- Dated notes: `notes_dir/YYYY/MM/weekNN/DD-subject.md`
- Special folder notes: `notes_dir/<folder>/slug.md`

## Note Creation (`:ParleyNoteNew`, `<C-n>c`)
- Prompts for subject, auto-creates directory structure, opens buffer
- Plain subjects always go to dated tree (even if first word matches a folder name)
  - `K task-description` -> `notes/YYYY/MM/WNN/DD-K-task-description.md`
- Braced prefix `{K} title` -> `notes_dir/K/some-title.md` (bypasses dated tree)
- Bare `{}` rejected (reserved for finder filter)
- Multiple braced segments rejected (e.g. `{K} {another} love`)
- Template-based creation: same rules; filename slug appends template suffix with common segments (count > 3) stripped

## Navigation
- `:ParleyNoteFinder` (`<C-n>f`): note picker
- `:ParleyYearRoot` (`<C-n>r`): cd to current year's notes folder
