# Note Finder

`:ParleyNoteFinder` (`<C-n>f`) — floating picker for notes across all configured note roots (excludes `templates/`).

## Multi-root Display
Notes from the primary root show without prefix. Notes from extra roots are tagged with `{label}` prefix in the display, matching the chat finder pattern.

## Special Folders
First-level non-date/non-template folders are "special" — always visible regardless of recency, shown with `{folder}` prefix. Braced filters (`{K}`) match folder labels; bare `{}` matches dated tree only. Braced filters persist between picker invocations.

## Recency
Same month-based cycle as Chat Finder. Directory-derived dates drive sort order over mtime.
