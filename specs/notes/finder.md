# Note Finder

`:ParleyNoteFinder` (`<C-n>f`) — floating picker for notes under `notes_dir` (excludes `templates/`).

## Special Folders
First-level non-date/non-template folders are "special" — always visible regardless of recency, shown with `{folder}` prefix. Braced filters (`{K}`) match folder labels; bare `{}` matches dated tree only. Braced filters persist between picker invocations.

## Recency
Same month-based cycle as Chat Finder. Directory-derived dates drive sort order over mtime.
