# Spec: Note Finder

## Overview
Parley provides a note finder for browsing and opening notes stored under `notes_dir`.

## Command
- `:ParleyNoteFinder` (`<C-n>f`): Opens a floating picker for notes.

## Discovery
- Note Finder MUST search recursively through `notes_dir` for Markdown files.
- Files under `notes_dir/templates/` MUST be excluded from results.
- Results MUST display note paths relative to `notes_dir`.

## Recency Filtering
- Note Finder MUST support the same month-based recency cycle model as Chat Finder.
- By default, the active window is `note_finder_recency.months`, with extra presets from `note_finder_recency.presets`, followed by `All`.
- For notes stored in dated directories (`YYYY/MM/...`), Note Finder MUST use directory-derived date ranges to decide whether the containing folder can overlap the recency cutoff.
- This directory-based filter MAY include slightly older filenames when they live in a directory that still overlaps the active recency window.

## Picker Actions
- `<C-d>` deletes the selected note after confirmation.
- `<C-a>` and `<C-s>` cycle the recency window left/right.
- Selecting a result opens the note in the source window that launched the picker.

## Ordering
- Results MUST be sorted newest first.
- When a note path encodes a dated directory and optional day prefix (`DD-subject.md`), that inferred date SHOULD drive ordering ahead of filesystem mtime.
