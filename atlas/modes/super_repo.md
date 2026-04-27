# Super-Repo Mode

Read-aggregation overlay on top of plain repo mode. When active, parley's
finders surface chats / notes / issues / vision / markdown across **all**
sibling `.parley` repos under the workspace root, not just the current one.
Writes are unchanged: still go to the current repo.

## Activation

- **Toggle**: `<C-g>S` (`global_shortcut_super_repo_toggle`).
- **Pre-condition**: cwd must be inside a `.parley` repo (i.e. `repo_root`
  is set by `apply_repo_local`). If not, the toggle fails with a notice.
- **Workspace root**: parent of `repo_root`. Members are direct children of
  the workspace root whose own direct child is `.parley`.
- **Transient** — never persisted to `state.json`.

## Mode glyphs (lualine)

`lualine.replace_filetype = true` (default) swaps the user's filetype
component with a single-character mode indicator:

| Glyph | Mode       | Meaning                                     |
|-------|------------|---------------------------------------------|
| `○`   | global     | No parley repo context                      |
| `⊚`   | repo       | cwd is inside a `.parley` repo              |
| `⦿`   | super-repo | super-repo toggle is on                     |

Refresh fires on `User ParleySuperRepoChanged`.

## Reads — multi-root aggregation

| Finder           | Per-member path           | Display prefix  |
|------------------|---------------------------|-----------------|
| Chat (`<C-g>f`)  | `<member>/workshop/parley`| `{<repo_name>} `|
| Note (`<C-n>f`)  | `<member>/workshop/notes` | `{<repo_name>} `|
| Issue (`<C-y>f`) | `<member>/workshop/issues`| `{<repo_name>} `|
| Vision (`<C-j>f`)| `<member>/workshop/vision`| `{<repo_name>} `|
| Markdown (`<C-g>m`) | `<member>` at `markdown_finder_max_depth` | `<repo_name>/<relative>` |

Chat & note finders inherit multi-root behaviour from `root_dirs.lua` —
super-repo simply pushes each member's chat/note dir into `chat_roots` /
`note_roots` with `label = <repo_name>`. Issue / vision / markdown finders
were extended explicitly during M3-M5.

## Writes — unchanged

`chat_dir`, `notes_dir`, `issues_dir`, `history_dir`, `vision_dir`,
`repo_root` are exactly what plain repo mode set them to. Super-repo
does not redirect writes to a "brain" repo — that idea was dropped during
design (see `workshop/issues/000113-create-a-super-repo-mode.md`).

## Persistence safety

Super-repo-pushed sibling roots are excluded from `state.json` by the
persistence gate in `init.lua`. The gate consults
`super_repo.get_pushed_chat_dirs()` and `super_repo.get_pushed_note_dirs()`,
in addition to the existing `label = "repo"` filter for plain repo mode's
primary root. The gate now also covers `note_roots` (was chat-only —
side fix during M1).

## Code

- `lua/parley/super_repo.lua` — module: `compute_members`, `is_active`,
  `toggle`, `get_pushed_chat_dirs` / `get_pushed_note_dirs`.
- `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
  `parley.is_super_repo_active()`; persistence gate consults pushed-dirs.
- `lua/parley/issues.lua` — `scan_issues` accepts `repo_name` +
  `history_dir_override` opts.
- `lua/parley/issue_finder.lua`, `vision_finder.lua`, `markdown_finder.lua`
  — multi-root aggregation when `super_repo_members` is non-empty.
- `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
  the filetype-component auto-replace at setup time.
- `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
