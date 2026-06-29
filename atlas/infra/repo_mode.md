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
- `workshop/parley/` (configurable via `repo_chat_dir`) becomes the primary chat directory, labeled `"repo"`
- `workshop/notes/` (configurable via `repo_note_dir`) becomes the primary note directory
- The user's global `chat_dir` is demoted to an extra search directory and explicitly labeled `"global"` (still findable, not written to). The global `notes_dir` is similarly demoted.
- `chat_memory` and `memory_prefs` are disabled (not useful for repo-scoped brainstorming)

## Multi-root architecture

### Chat roots (issue #117)
Chat roots are a *derived* list — never freeform-added or persisted. The shape on every read is:

```
chat_roots = [config.chat_dir]
           + (repo_root/repo_chat_dir if repo mode is active)
           + (sibling repos' chat dirs if super-repo mode is active)
```

`apply_repo_local()` materializes this list at setup; super-repo toggling pushes/pops sibling entries at runtime. There are no `:ParleyChatDirs` / `:ParleyChatDirAdd` / `:ParleyChatDirRemove` commands and no `<C-g>h` keybinding — they were removed in issue #117 because the original use case (drop a folder in for deliberation) is fully covered by repo + super-repo modes. State.json no longer carries `chat_dirs` / `chat_roots`; old state files with these fields are silently ignored on load.

### Reference neighborhood (#147)
Relative tool paths and chat-buffer file completion use a per-artifact
neighborhood root, not the editor process cwd. `lua/parley/neighborhood.lua`
derives the root from the artifact path: repo-backed Parley artifacts under the
repo-local chat/note/issue/vision/history dirs resolve to `config.repo_root`;
global chats and ordinary content files resolve to their own folder. `prep_chat`
attaches a buffer-local `completefunc` for chat buffers, so root-relative file
candidates come from the same neighborhood that tool calls use.

### Note roots
Notes still use the multi-root manager with freeform add/remove/rename via `:ParleyNoteDirs` / `<C-n>h` and persist `note_roots` / `note_dirs` to state.json. The shared `root_dirs.lua` generic manager and `root_dir_picker.lua` UI exist primarily to serve the note system now; the chat side only uses the read paths (get/find/normalize/apply) and `super_repo.set_chat_roots`.

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
- (No chat-root management commands — see "Chat roots" above.)

## Implementation notes
- `repo_chat_dir` and `repo_note_dir` are excluded from the generic `_dir$` prepare loop in setup
- `apply_repo_local()` builds `config.chat_roots = [{dir=repo_chat, label="repo"}, {dir=config.chat_dir, label="global"}, ...]` directly, bypassing the basename-derived label heuristic in `default_root_label`
- `refresh_state()` re-asserts the repo *note* dir as primary after restoring persisted state (chat side does not need this — chat state is never persisted), and strips note_roots entries marked transient (plain repo's `label = "repo"` and super-repo's pushed sibling dirs) from `state.json`
- `detect_buffer_context` checks all note roots (not just primary) for scope detection
- `neighborhood.derive_for_path()` canonicalizes `/var`/`/private/var` style path aliases before testing repo-local artifact directories
- Finders scan all roots, tagging non-primary entries with `{label}` prefix

## Related
- [Super-Repo Mode](../modes/super_repo.md) — read-aggregation overlay across sibling `.parley` repos.
