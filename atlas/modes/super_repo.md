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
component with a compact mode indicator:

| Glyph          | Mode       | Meaning                                     |
|----------------|------------|---------------------------------------------|
| `○`            | global     | No parley repo context                      |
| `⊚-<repo>`     | repo       | cwd is inside a `.parley` repo              |
| `⦿-<repo>`     | super-repo | super-repo toggle is on                     |

`<repo>` is the basename of `config.repo_root`, so a brain repo cwd displays
`⊚-brain` in plain repo mode and `⦿-brain` when super-repo is active.

Refresh fires on `User ParleySuperRepoChanged`.

## Reads — multi-root aggregation

| Finder           | Per-member path           | Display prefix  |
|------------------|---------------------------|-----------------|
| Chat (`<C-g>f`)  | `<member>/workshop/parley`| `{<repo_name>} `|
| Note (`<C-n>f`)  | `<member>/workshop/notes` | `{<repo_name>} `|
| Issue (`<C-y>f`) | `<member>/workshop/issues`| `{<repo_name>} `|
| Vision (`<C-j>f`)| `<member>/workshop/vision`| `{<repo_name>} `|
| Markdown (`<C-g>m`) | `<member>` at `markdown_finder_max_depth` | `{<repo_name>} <relative>` |

Chat & note finders inherit multi-root behaviour from `root_dirs.lua` —
super-repo simply pushes each member's chat/note dir into `chat_roots` /
`note_roots` with `label = <repo_name>`. Issue / vision / markdown finders
were extended explicitly during M3-M5.

Markdown Finder obtains the active member roots from `super_repo.get_state()`
when each picker invocation opens; it does not treat the cached config member
list as the authority. In super-repo mode its tag bar is repo-only:
`[ALL] [NONE] [repo…]`. Repository choices are derived from the member roots,
sorted alphabetically, and include members that currently yield no Markdown
rows. An eligible expansion with zero total rows therefore retains the bar, so
a persisted NONE state is recoverable through ALL. Incomplete labels or fewer
than two distinct labels suppress the bar. Duplicate complete labels are
deduplicated and suppress it only when they collapse the universe below two;
repo facets are also suppressed when a successfully scanned row has no label
or has a label outside the eligible root set. Eligible roots with no rows remain
valid facets. Suppression leaves the aggregate unfiltered with no bar rather
than applying a partial facet policy.

## Finder query persistence

Chat, note, and vision finders preserve `{repo}` filter fragments
across reopens via `lua/parley/finder_sticky.lua`. Both completed (`{charon}`)
and in-progress (`{char`) prompt fragments are extracted on every keystroke,
normalised to the completed form, and re-seeded as `initial_query` next time.
Chat finder additionally preserves `[tag]` fragments. Issue Finder is the
first intentional exception; Markdown Finder now follows the same complete,
opaque policy. Each stores the prompt verbatim in its own in-memory finder state
on every change, including whitespace and clearing to the empty string, so the
query survives facet repaint and later invocations without going through
`finder_sticky` (#177, #187).

Matching is also forgiving of in-progress brackets: `{char` matches the same
items as `{charon}` would (prefix match against the haystack `{repo}` token),
fixing the case where typing was abandoned before the closing brace.

## Writes — unchanged

`chat_dir`, `notes_dir`, `issues_dir`, `history_dir`, `vision_dir`,
`repo_root` are exactly what plain repo mode set them to. Super-repo
does not redirect writes to a "brain" repo — that idea was dropped during
design (see `workshop/issues/000113-create-a-super-repo-mode.md`).

## Persistence safety

For **chat** roots: trivially safe. Issue #117 stopped persisting
`chat_roots` / `chat_dirs` to `state.json` entirely — the chat root list
is derived on every read from `config.chat_dir + repo + super-repo`.
Super-repo's `get_pushed_chat_dirs()` is still called by the (now
chat-less) persistence gate sibling note path indirectly, but on the
chat side there is nothing to filter.

For **note** roots: the persistence gate still runs. Super-repo-pushed
sibling note dirs are excluded from `state.json` via
`super_repo.get_pushed_note_dirs()`, in addition to the `label = "repo"`
filter for plain repo mode's primary note root.

## Code

- `lua/parley/super_repo.lua` — module: `compute_members`, `is_active`,
  `toggle`, `get_pushed_chat_dirs` / `get_pushed_note_dirs`.
- `lua/parley/init.lua` — wires `parley.toggle_super_repo()` /
  `parley.is_super_repo_active()`; persistence gate consults pushed-dirs.
- `lua/parley/issues.lua` — `scan_issues` accepts `repo_name` +
  `history_dir_override` opts.
- `lua/parley/issue_finder.lua`, `vision_finder.lua` — multi-root aggregation
  through `super_repo.expand_roots`.
- `lua/parley/markdown_finder.lua` — per-invocation aggregation and contextual
  facets from the active `super_repo.get_state()` member roots.
- `lua/parley/finder_sticky.lua` — shared `{root}` / `[tag]` extraction and
  initial-query formatter used by chat, note, and vision finders; Issue Finder
  and Markdown Finder own separate full-query persistence state.
- `lua/parley/lualine.lua` — `format_mode`, `create_mode_component`, and
  the filetype-component auto-replace at setup time.
- `lua/parley/keybinding_registry.lua` — `super_repo_toggle` entry.
