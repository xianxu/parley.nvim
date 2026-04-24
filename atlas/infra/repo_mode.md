# Repo Mode

## Overview
When a `.parley` marker file exists at the git root of the current working directory, parley enters "repo mode". This makes parley a brainstorming and design tool scoped to that repository.

## Detection
During `setup()`, after config merging:
1. Check `config.repo_marker` is set (default: `".parley"`)
2. Find the git root from `vim.fn.getcwd()` (works from any subdirectory)
3. If `<git_root>/<repo_marker>` is readable, activate repo mode

## Behavior when active
- `config.repo_root` is set to the git root path
- Repo-local directories are auto-created: `workshop/parley/`, `workshop/notes/`, `workshop/issues/`, `workshop/vision/`, `workshop/history/`
- `workshop/parley/` (configurable via `repo_chat_dir`) becomes the primary chat directory
- `workshop/notes/` (configurable via `repo_note_dir`) becomes the primary note directory
- The user's global `chat_dir` and `notes_dir` are demoted to extra search directories (still findable, not written to)
- `chat_memory` and `memory_prefs` are disabled (not useful for repo-scoped brainstorming)
- Persisted state (`state.json`) is overridden: repo chat/note dirs are always forced as primary root on startup

## Multi-root architecture
Both chats and notes use a shared `root_dirs.lua` generic multi-root manager. Domain modules (`chat_dirs.lua`, `note_dirs.lua`) are thin wrappers. Similarly, `root_dir_picker.lua` provides the shared picker UI, with `chat_dir_picker.lua` and `note_dir_picker.lua` as thin wrappers.

Each domain supports:
- A primary root (writes go here)
- Extra roots (searchable in finder, read-only)
- Add/remove/rename roots via picker or commands
- State persistence in `state.json`

## Configuration
| Key | Default | Description |
|-----|---------|-------------|
| `repo_marker` | `".parley"` | Marker file name; set to `nil`/`false` to disable |
| `repo_chat_dir` | `"workshop/parley"` | Chat dir name within repo (primary in repo mode) |
| `repo_note_dir` | `"workshop/notes"` | Note dir name within repo (primary in repo mode) |
| `issues_dir` | `"workshop/issues"` | Issue tracker dir |
| `history_dir` | `"workshop/history"` | Archived issues dir |
| `vision_dir` | `"workshop/vision"` | Vision tracker dir |
| `note_roots` | `{}` | Structured note roots metadata |
| `note_dirs` | `{}` | Additional note dirs (extras) |

All directory names are relative to git root unless they start with `/`.

## Commands and keybindings
- `:ParleyNoteDirs` / `<C-n>h` — manage note roots (add/rename/remove)
- `:ParleyNoteDirAdd` / `:ParleyNoteDirRemove` — CLI equivalents
- `:ParleyChatDirs` / `<C-g>h` — manage chat roots (existing)

## Implementation notes
- `repo_chat_dir` and `repo_note_dir` are excluded from the generic `_dir$` prepare loop in setup
- `refresh_state()` re-asserts repo dirs as primary after restoring persisted state
- `detect_buffer_context` checks all note roots (not just primary) for scope detection
- Note finder scans all roots, tagging non-primary entries with `{label}` prefix
