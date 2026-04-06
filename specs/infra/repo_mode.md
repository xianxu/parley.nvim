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
- Repo-local directories are auto-created: `design/`, `issues/`, `vision/`, `history/`
- `design/` (configurable via `repo_chat_dir`) becomes the primary chat directory
- The user's global `chat_dir` is demoted to an extra search directory (still findable, not written to)
- `chat_memory` and `memory_prefs` are disabled (not useful for repo-scoped brainstorming, and would pollute the repo chat dir with preference files)
- Persisted state (`state.json`) is overridden: repo chat dir is always forced as primary root on startup, regardless of what was previously saved

## Configuration
| Key | Default | Description |
|-----|---------|-------------|
| `repo_marker` | `".parley"` | Marker file name; set to `nil`/`false` to disable |
| `repo_chat_dir` | `"design"` | Chat dir name within repo (primary in repo mode) |
| `issues_dir` | `"issues"` | Issue tracker dir (pre-existing config) |
| `history_dir` | `"history"` | Archived issues dir |
| `vision_dir` | `"vision"` | Vision tracker dir (pre-existing config) |

All directory names are relative to git root unless they start with `/`.

## Implementation notes
- `repo_chat_dir` is excluded from the generic `_dir$` prepare loop in setup (it's a relative name, not a path to auto-create at CWD)
- `refresh_state()` re-asserts the repo chat dir as primary after restoring persisted state, preventing stale `state.json` from overriding repo mode
