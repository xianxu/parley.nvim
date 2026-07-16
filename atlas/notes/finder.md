# Note Finder

`:ParleyNoteFinder` (`<C-n>f`) — floating picker for notes across all configured note roots (excludes `templates/`).

The picker opens immediately with an animated `scanning…` status while the
shared asynchronous file source recursively enumerates `*.md` metadata. It
never reads note bodies. Matching opens join an exact retained prewarm; recency
is deliberately excluded from that discovery fingerprint and is applied only
when settled raw records are materialized. Esc cancels picker-owned discovery
but only unsubscribes from a retained prewarm.

Unchanged files reuse cached classification/date metadata. Cache updates happen
after pure record adaptation, and a successful root prunes only its own missing
entries; failed roots retain cache entries for retry. Partial scans keep usable
rows and warn, while total failure leaves a nonselectable bounded error status.

## Multi-root Display
Notes from the primary root show without prefix. Notes from extra roots are tagged with `{label}` prefix in the display, matching the chat finder pattern.

## Special Folders
First-level non-date/non-template folders are "special" — always visible regardless of recency, shown with `{folder}` prefix. Braced filters (`{K}`) match folder labels; bare `{}` matches dated tree only. Braced filters persist between picker invocations.

## Recency
Same month-based cycle as Chat Finder. Directory-derived dates drive sort order over mtime.
