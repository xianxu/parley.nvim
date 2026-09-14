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
This is the same complete-result replacement and cancellation contract used by
the Chat, Markdown, Issue, and Vision disk-backed finders; Note differs only in
its metadata-only recursive acquisition and joinable retained prewarm.

## Multi-root Display
Notes from the primary root show without prefix. Notes from extra roots are tagged with `{label}` prefix in the display, matching the chat finder pattern.

## Special Folders
First-level non-date/non-template folders are "special" — always visible regardless of recency, shown with `{folder}` prefix. Braced filters (`{K}`) match folder labels; bare `{}` matches dated tree only. Braced filters persist between picker invocations.

## Recency
Same month-based cycle as Chat Finder. Directory-derived dates drive sort order over mtime.

## Controls and defaults

`note_finder_recency` defaults to filtering the last 3 months, with 3/6/12/All
views. Ctrl+a/Ctrl+s cycle the view; Ctrl+d asks before deleting a note. Basic
navigation is Ctrl+j/k or arrows, Enter to open, Esc/Ctrl+c to cancel. Action
keys are configurable through `note_finder_mappings`.

The app starter does not bind the plugin-default Ctrl+n f launcher; use
`:ParleyNoteFinder`. Local Ctrl+g ? help shows the configured picker actions.

## Implementation and checks

`lua/parley/note_finder.lua` and `lua/parley/note_finder_records.lua` own discovery,
classification, recency, and display. See `tests/unit/note_finder_logic_spec.lua`
and `tests/unit/note_finder_records_spec.lua`.
