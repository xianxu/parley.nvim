# Notes Structure

## Layout
- Dated notes: `notes_dir/YYYY/MM/weekNN/DD-subject.md`
- Special folder notes: `notes_dir/<folder>/slug.md`

## Note Creation (`:ParleyNoteNew`, `<C-n>c`)
Prompts for subject, auto-creates directory structure. Plain subjects go to dated tree. Braced prefix `{K} title` targets named folder instead.

## Navigation
- `:ParleyNoteFinder` (`<C-n>f`): note picker
- `:ParleyYearRoot` (`<C-n>r`): cd to current year's notes folder
