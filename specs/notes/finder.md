# Spec: Note Finder

## Overview
Parley provides a note finder for browsing and opening notes stored under `notes_dir`.

## Command
- `:ParleyNoteFinder` (`<C-n>f`): Opens a floating picker for notes.

## Discovery
- Note Finder MUST search recursively through `notes_dir` for Markdown files.
- Files under `notes_dir/templates/` MUST be excluded from results.
- Results MUST display note paths relative to `notes_dir`.
- First-level folders under `notes_dir` whose names are neither `templates` nor the dated Year/Month/Week path pattern MUST be treated as special named folders.

## Recency Filtering
- Note Finder MUST support the same month-based recency cycle model as Chat Finder.
- By default, the active window is `note_finder_recency.months`, with extra presets from `note_finder_recency.presets`, followed by `All`.
- For notes stored in dated directories (`YYYY/MM/...`), Note Finder MUST use directory-derived date ranges to decide whether the containing folder can overlap the recency cutoff.
- This directory-based filter MAY include slightly older filenames when they live in a directory that still overlaps the active recency window.
- Notes stored under special first-level folders MUST remain searchable and visible regardless of the active recency window.

## Folder Labels
- Notes stored under special first-level folders MUST display with a braced folder prefix, for example `{K} evergreen-note.md`.
- Note Finder search text MUST include the braced folder label so users can filter by `{base_folder}`.
- Bare `{}` MUST filter only notes from the dated Year/Month/Week tree.
- Braced Note Finder filters MUST target only these special first-level folder labels; they MUST NOT fall back to plain word matching elsewhere in the row text.
- When the prompt contains braced folder filters such as `{K}`, Note Finder MUST preserve those fragments between invocations and internal reopen flows. Reopened prompts seed the preserved fragments with a trailing space so users can immediately continue with free-text filtering.

## Picker Actions
- `<C-d>` deletes the selected note after confirmation.
- `<C-a>` and `<C-s>` cycle the recency window left/right.
- Selecting a result opens the note in the source window that launched the picker.

## Ordering
- Results MUST be sorted newest first.
- When a note path encodes a dated directory and optional day prefix (`DD-subject.md`), that inferred date SHOULD drive ordering ahead of filesystem mtime.
