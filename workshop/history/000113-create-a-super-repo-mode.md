---
id: 000113
status: done
deps: []
created: 2026-04-27
updated: 2026-04-27
---

# create a super-repo mode

right now, parley has a repo mode, in which chats/notes are localized into a local repo, instead of using global write location. 

I work across multiple repositories, all cloned under ~/workspace, e.g. parley.nvim, ariadne, charon, nous, brain. all of them have the parley infrastructure. sometimes I would want to check of notes/chats/issues or <C-g>m to find all recent markdown file changes, across the board. Let's make this work, and call it super-repo mode.

it should work like this:

1. all writes are going to brain by default. as a matter of fact, if the current folder has a brain folder and have marker brain/.parley, this is the signature enabling the super-repo mode.

2. all reads in all modes should poll in from all parley enabled repos. so for example, if we have charon/.parley, ariadne/.parley, but not diary/.parley, then for example, for notes search, we should search charon/workshop/notes, ariadne/workshop/notes, along with the global location. 

First inspect parley features, and design this out. 

## Done when

- A new keybinding `<C-g>S` toggles **super-repo mode** on and off. Activation is **explicit only** — there is no auto-activation from a marker file. Single-repo workflows stay untouched.
- Toggle-on requires cwd to be inside a `.parley` repo (i.e., plain repo mode is already active). The current repo's parent dir is the **workspace root**; sibling members are discovered there. If cwd is not in a `.parley` repo, the toggle fails with a notice (`"super-repo: cwd is not inside a .parley repo"`) and state is unchanged.
- Super-repo is **a pure read-aggregation overlay** on top of plain repo mode. Writes are unchanged: they continue to go to the current repo (whichever repo cwd is in), exactly as plain repo mode does today. No write redirection to brain.
- When super-repo is active: all read-side finders (chat `<C-g>f`, note `<C-n>f`, issue `<C-y>f`, markdown `<C-g>m`, vision `<C-j>f`) aggregate across every sibling `.parley` repo (including the current repo and brain when present), plus the global locations as extras.
- Finder result rows are prefixed with the member-repo name so I can tell which repo a hit came from. Most of this is free (chat/note/markdown finders); issue & vision finders need an explicit prefix added during their refactor.
- Toggle-off cleanly removes super-repo's added roots and any state it added; plain repo mode is back exactly as before the toggle.
- Super-repo state is **transient** — never persisted to `state.json`. Re-toggle each session as desired.
- Globals stay as extras in finders (so iCloud chats/notes still surface), same as plain repo mode today. Persisted global write locations are not disturbed by super-repo.
- A new lualine indicator replaces the `markdown` filetype string with a single unicode glyph denoting parley's mode: `○` global, `⊚` repo, `⦿` super-repo. Auto-replacement of an existing filetype component, with an opt-out flag.

## Spec

### Activation

Super-repo mode is **explicitly toggled** via `<C-g>S`. There is no marker-file auto-activation.

- The toggle keybinding registers in `keybinding_registry.lua` as `super_repo_toggle`, default key `<C-g>S`, modes `{ "n", "i" }`, scope `global`.
- **Pre-condition for toggle-on:** cwd must be inside a `.parley` repo. Concretely, `M.config.repo_root` must be set (which `apply_repo_local` does at startup when cwd has `.parley`). If not, fail with a notice and leave state unchanged.
- **Workspace root:** parent of `repo_root`. E.g. `repo_root = ~/workspace/parley.nvim` → workspace root is `~/workspace`. Stored as `M.config.super_repo_root` while active.
- **Members:** computed via `vim.fn.glob(super_repo_root .. "/*/.parley")` → list of parent dirs. Stored as `M.config.super_repo_members = { { path, name }, ... }`. The current repo is one of them; brain is one if present.
- On toggle-off: clear `super_repo_root` / `super_repo_members`, remove super-repo-pushed entries from `chat_roots` / `note_roots`. Plain repo mode is fully restored.
- Super-repo is a runtime-only switch — never persisted to `state.json`.

### Writes — unchanged from plain repo mode

Super-repo does **not** touch write targets. `chat_dir`, `notes_dir`, `issues_dir`, `history_dir`, `vision_dir`, `repo_root` are whatever plain repo mode set them to (current repo's `workshop/...` paths). New chats/notes/issues land in the current repo. This was the user's clarification: super-repo is read-only aggregation; writes follow the current repo.

Brain has no special status. It is just one of the sibling members for read purposes (and only if it's actually present in the workspace).

### Reads — multi-root aggregation

Each finder grows a multi-root path triggered when `super_repo_members` is non-empty:

| Finder        | Per-member path           | Existing multi-root? | Change                                                                       |
|---------------|---------------------------|----------------------|------------------------------------------------------------------------------|
| Chat finder   | `<member>/workshop/parley`| yes (`get_chat_roots`)| Push every member's chat dir into chat roots with `label = <repo_name>`. Current repo's chat dir stays primary; siblings appended as extras (with `label = "repo"` so persistence filter excludes them). Repo-name `{label}` prefix renders for free in non-primary entries. |
| Note finder   | `<member>/workshop/notes` | yes (`get_note_roots`)| Same pattern as chat. |
| Issue finder  | `<member>/workshop/issues`| no — single dir       | Refactor `issue_finder.open` + `issues.scan_issues` to accept a list of roots. Add member-name prefix to display row + `repo` tag for filtering. |
| Vision finder | `<member>/workshop/vision`| no — single dir       | Same refactor pattern as issue finder. |
| Markdown      | scans single repo_root    | no                    | When super-repo active, loop the existing scanner over each member at `markdown_finder_max_depth`. Display path becomes `<repo>/<relative-within-repo>`. Per-repo depth bound preserves the "same depth as single-repo, just one extra level for the repo name itself" semantics the user asked for. |

Globals stay as extras (parity with today's plain repo mode). Persisted global write paths are not touched.

Tag-bar filtering: each entry gets a `repo` tag (member name); when N≥2 members are visible, the tag bar shows one chip per repo to toggle. Reuses the existing pattern from `markdown_finder.lua` and the existing root-label `{}` filter on chat/note finders.

### Lualine mode indicator

Today the user's lualine shows the `markdown` filetype string for chat/note buffers, which is wide and uninformative. Parley provides a new lualine component that returns a single-unicode parley-mode glyph, intended to replace the user's existing filetype component:

| Mode        | Glyph | Meaning                                |
|-------------|-------|----------------------------------------|
| global      | `○`   | No parley repo context (global writes) |
| repo        | `⊚`   | cwd is inside a `.parley` repo         |
| super-repo  | `⦿`   | super-repo toggle is on                |

Implementation:

- New `M.format_mode()` and `M.create_mode_component()` exported from `lua/parley/lualine.lua`. Mirror the existing `format_directory` / `create_component` patterns.
- Mode resolution: `super_repo_active` → `◎`; else `repo_root` set → `◉`; else `○`.
- The existing parley lualine setup already monkey-patches user lualine config (lines 297-320 detect a directory component by string-dumping it). Extend the same mechanism: detect a filetype component by string-dumping the function and matching `bo.filetype` / `bo%[.-%]%.filetype`. Replace with a `M.format_mode()`-backed component when found.
- Toggle the mode component refreshes lualine on activation/deactivation (fire a `User ParleySuperRepoChanged` autocmd; bind a refresh callback the same way as `ParleyAgentChanged`).
- Provide a config flag `lualine.replace_filetype` (default `true`) to opt out of the auto-replacement. Users who want manual wiring can set it to false and add `M.create_mode_component()` themselves.

### Issue numbering

Unchanged from plain repo mode. New issues number against the current repo's `workshop/issues`. The finder shows issues from siblings too; cross-repo ID collisions are disambiguated by the `<repo> ·` prefix.

### Memory

Plain repo mode already governs `chat_memory` / `memory_prefs` based on `repo_root`. Super-repo doesn't change this — writes still go to the current repo, so memory behaves identically to plain repo mode.

### Persistence

Sibling members pushed into chat_roots/note_roots get `label = "repo"` so the existing persistence gate (init.lua:1061-1072) filters them out of `state.json`. The current repo's chat/note dirs are already filtered the same way today. No new persistence code.

### Tests

- `super_repo.compute_members(repo_root)` returns sibling `.parley` repos under `repo_root`'s parent (fixture: `W/{a,b,c}/.parley`, `W/d/` no marker, `repo_root = W/a` → members `[W/a, W/b, W/c]`).
- Toggle on from inside a `.parley` repo (e.g. cwd in `W/a`): super-repo activates, `super_repo_root = W`, members include all siblings, sibling chat/note dirs appended to chat_roots/note_roots with `label = "repo"`.
- Toggle on from outside any `.parley` repo (`repo_root` empty): fails with notice; state unchanged.
- Toggle off: super-repo-added roots removed from chat_roots/note_roots; `super_repo_root` and `super_repo_members` cleared.
- Write paths (`chat_dir`, `notes_dir`, `issues_dir`, `history_dir`, `vision_dir`, `repo_root`) are unchanged across toggle on/off — only read-side state moves.
- Multi-root issue / vision / markdown finder: union of entries across members with `repo` tags.
- Persistence: super-repo-added roots not written to `state.json`; global writes paths in `state.json` not modified.
- Lualine `format_mode()` returns `○` / `⊚` / `⦿` for global / repo / super-repo.

### Resolved questions

1. **Persist the toggle?** No — transient.
2. **Globals as extras + write semantics?** Yes, globals stay as extras. Writes go to current repo (super-repo is read-only aggregation). Persisted global write paths are untouched.
3. **Markdown depth?** Each member scanned at `markdown_finder_max_depth` (= 4). Same as single-repo mode; the extra level for the repo name itself sits outside the bound.
4. **`src_root` side-effect?** Dropped. The existing `resolve_src_link` (init.lua:3033-3045) already auto-detects via `git rev-parse --show-toplevel` from the current buffer, which yields the same workspace root super-repo computes. Setting `src_root` from the toggle would be redundant.
5. **Lualine auto-replace?** Yes — auto-detect the user's filetype component and swap; opt-out via `lualine.replace_filetype = false`.

## Plan

- [x] **M1 — `super_repo.lua` module.** New `lua/parley/super_repo.lua` with `M.compute_members(repo_root)`, `M.is_active()`, `M.toggle()`. Toggle pushes/pops sibling `<member>/workshop/parley` and `<member>/workshop/notes` into chat_roots/note_roots with `label = "repo"`. Sets/clears `M.config.super_repo_root` and `M.config.super_repo_members`. Fires `User ParleySuperRepoChanged`. Unit-tests with a fixture tree.
- [x] **M2 — Keybinding wiring.** Register `super_repo_toggle` in `keybinding_registry.lua` (default `<C-g>S`, modes `{ "n", "i" }`, scope `global`). Wire to `super_repo.toggle()` in `init.lua`.
- [x] **M3 — Multi-root issue finder.** Refactored `issues.scan_issues` to accept `repo_name` + `history_dir_override` opts; refactored `issue_finder.open` to compute roots list (one per member when super-repo active, else single repo). Display rows prefixed with `{repo}` when multi-root.
- [x] **M4 — Multi-root vision finder.** Mirrored M3 — `vision_finder.open` aggregates initiatives across member vision dirs; rows prefixed with `{repo}`.
- [x] **M5 — Multi-root markdown finder.** When super-repo active, scan each member at `markdown_finder_max_depth`; display `<repo>/<relative>` and tag entries by repo name (so the tag bar filters by repo). Single-repo path unchanged.
- [x] **M6 — Lualine mode indicator.** Added `M.format_mode()` and `M.create_mode_component()` in `lualine.lua`. Setup-time monkey-patcher now also detects filetype components — both string form (`"filetype"`), table form (`{"filetype", ...}`), and function form (string-dump matches `filetype` / `bo.`) — and swaps in the mode glyph. Config flag `lualine.replace_filetype` (default `true`) for opt-out. Refresh hooked on `ParleySuperRepoChanged`.
- [x] **M7 — Tests + atlas.** Added `atlas/modes/super_repo.md`, indexed it, mapped `modes/super_repo` in `atlas/traceability.yaml` (so `make test-spec SPEC=modes/super_repo` works). Added 5 more unit tests (markdown _scan_members, scan_issues multi-root, expand_roots, persistence gate, lualine glyph). 18 super_repo cases pass; full unit suite green.
- [x] **Code review** dispatched after M6. Findings actioned: (a) tightened lualine filetype heuristic to explicit `bo.filetype` access patterns (was matching any function with `filetype`/`bo%.` substring — false-positive risk); (b) replaced display-string regex parsing in `_scan_members` with direct path stripping from `e.value` (cleaner, no fragile regex on a previously-formatted string); (c) added `super_repo.expand_roots(subdir)` helper and refactored issue/vision finders to use it (DRY); (d) added warning notice when toggle-on finds no siblings. Reviewer flagged the markdown-finder scope-broadening from earlier in this session as a regression — that change was a separate user-requested edit before issue #113 work began, not an oversight here, so left in place.

## Log

### 2026-04-27

- Synced status to working, pushed.
- Inspected repo-mode infrastructure. Key findings:
  - Chat & note finders already multi-root via `root_dirs.lua`; issue/vision/markdown finders are single-root.
  - `apply_repo_local` (init.lua:388-455) is the central activation hook.
  - Repo roots already filtered from persistence — super-repo can reuse the same gate.
  - `src_root` exists for `src:` URLs and points to parent of sibling repos — natural alignment with workspace root.
- Drafted Spec v1: walk-up auto-activation via `brain/.parley`. User reverted.
- Drafted Spec v2: cwd-must-equal-workspace-root activation. User pivoted to:
  - Activation should be **explicit toggle** (`<C-g>S`), not marker-based, so single-repo mode stays usable inside any `.parley` repo.
  - Lualine should drop the wide `markdown` filetype string and show a single-unicode mode glyph instead.
- Drafted Spec v3: explicit toggle, brain as canonical write target, walk-up via `brain/.parley`.
- User clarified: writes go to **current repo** (super-repo is read-only aggregation), no special status for brain. Walk-up doesn't need brain — just go to cwd's repo's parent.
- Drafted Spec v4 (current): super-repo is a read-overlay on top of plain repo mode; pre-condition is cwd-in-`.parley`-repo; workspace root = parent of `repo_root`; members = all `*/.parley` siblings; writes unchanged. All 5 open questions resolved per user.
- `src_root` side-effect dropped — `resolve_src_link` already auto-detects via git, redundant with super-repo.
- Plan reduced to 7 milestones. Ready to start M1 (the `super_repo.lua` module + tests) on user go-ahead.
- **M1 done.** Implemented `lua/parley/super_repo.lua` with `compute_members`, `is_active`, `toggle`. Wired into `init.lua` exposing `parley.toggle_super_repo()` / `parley.is_super_repo_active()`. Extended `init.lua` persistence filter to also strip `note_roots` with `label = "repo"` (was chat-only; mirrors existing chat-side behaviour and prevents super-repo's pushed note dirs from leaking into `state.json`). Added `tests/unit/super_repo_spec.lua` — 12 cases covering compute_members + toggle activate/deactivate / state-shape / write-paths-untouched / autocmd. Full unit suite passes (143 cases).
- **Discovery during M1:** plain repo mode's `note_roots` were also being persisted (the existing filter handled chat_roots only). Extending the filter is a small bonus fix that benefits non-super-repo users too.

