---
id: 000112
status: done
deps: []
created: 2026-04-24
updated: 2026-04-24
---

# create a repo mode for notes

Follow the setup of repo mode for parley chat, create a repo mode for note. The triggering condition is exactly the same, e.g. in a repo, where repo root contains the .parley marker file.

Investigate the features parley chat's repo mode enables, but here are the top of mind:

1. support multiple roots where notes are loaded. one root, serving as default write location, where new notes go. notes in other roots can be still found and edited in notes finder.

2. <C-n>h to change note roots. this should pop up a float_finder to change which root serve as default. that dialog also supports adding new note roots. renaming, and removing a root.

3. in repo mode, a directory in the repo serves as the default note root for writes purpose. default to workshop/notes

This way, when nvim is started in a parley enabled repo, all notes taken are stored inside the repo itself. Overall, check the chats' repo mode and follow that design.

If there are common code between chat's repo mode and note's repo mode, do extract common code and keep things DRY.

## Done when

- [x] Notes support multiple roots (note_roots) with one primary for writes
- [x] Note finder scans all roots, tagging non-primary with {label}
- [x] <C-n>h opens a note root picker (add/rename/remove)
- [x] In repo mode (.parley marker), workshop/notes becomes primary, global notes_dir becomes extra
- [x] New notes go to the primary root
- [x] detect_buffer_context recognizes notes from any root
- [x] State persistence for note_roots in state.json

## Spec

### Architecture — DRY extraction

`chat_dirs.lua` implements root management (normalize, add, remove, rename, set, find_root, etc.)
that is ~95% generic. Extract the shared logic into `root_dirs.lua` — a generic multi-root manager
parameterized by config key names and labels.

Then both `chat_dirs.lua` and `note_dirs.lua` become thin wrappers calling the generic module.

Similarly, `chat_dir_picker.lua` → `root_dir_picker.lua` (generic) with domain-specific thin wrappers.

### Config additions

```lua
-- notes_dir already exists (single root)
note_roots = {},        -- structured roots metadata, like chat_roots
note_dirs = {},         -- additional note dirs, like chat_dirs
repo_note_dir = "workshop/notes",  -- note dir within repo, like repo_chat_dir
global_shortcut_note_dirs = { modes = { "n", "i" }, shortcut = "<C-n>h" },
```

### Repo mode changes (init.lua: apply_repo_local)

When .parley marker detected:
1. Create `workshop/notes/` alongside other repo dirs
2. Set `workshop/notes` as primary note root
3. Demote global `notes_dir` to extra root

### State persistence

Add `note_roots` and `note_dirs` to `refresh_state()` / state.json.

### Note finder changes

`note_finder.lua:scan_note_files()` changes to scan all note roots,
tagging non-primary entries with `{label}`.

### detect_buffer_context

Check all note roots, not just `notes_dir`.

## Plan

- [x] 1. Create `root_dirs.lua` — generic multi-root manager extracted from chat_dirs.lua
- [x] 2. Create `root_dir_picker.lua` — generic root picker extracted from chat_dir_picker.lua
- [x] 3. Refactor `chat_dirs.lua` to wrap `root_dirs.lua`
- [x] 4. Create `note_dirs.lua` wrapping `root_dirs.lua`
- [x] 5. Create `note_dir_picker.lua` wrapping `root_dir_picker.lua`
- [x] 6. Add config keys: `note_roots`, `note_dirs`, `repo_note_dir`, `global_shortcut_note_dirs`
- [x] 7. Update `apply_repo_local()` in init.lua for notes
- [x] 8. Update state persistence (refresh_state) for note_roots
- [x] 9. Update `note_finder.lua` to scan multiple roots
- [x] 10. Update `detect_buffer_context` to check all note roots
- [x] 11. Register keybinding `<C-n>h` and `:ParleyNoteDirs` command
- [x] 12. Update `notes.lua` to use primary note root for new notes (notes_dir already points to primary via root_dirs)
- [x] 13. Run tests and lint — all pass, 0 failures, 0 errors, 0 lint warnings

## Log

### 2026-04-24

- Read and analyzed chat_dirs.lua, chat_dir_picker.lua, note_finder.lua, notes.lua, init.lua
- chat_dirs has ~300 lines of root management, ~95% generic
- chat_dir_picker has ~200 lines, all generic except title strings and API names
- Identified DRY extraction: root_dirs.lua + root_dir_picker.lua as shared base
- Implemented all 13 plan items
- All tests pass (0 failures, 0 errors), lint clean (0 warnings / 0 errors in 148 files)
