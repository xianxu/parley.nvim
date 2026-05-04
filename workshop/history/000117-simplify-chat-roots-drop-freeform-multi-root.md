---
id: 000117
status: done
deps: []
created: 2026-05-04
updated: 2026-05-04
---

# simplify chat roots: drop freeform multi-root, keep repo + super-repo

## Spec

The `chat_roots` list grew out of a desire to point parley at additional
directories (e.g. drop a folder of files into a repo as a starting
point for deliberation). That intent has since been fully absorbed by
two structured features:

- **repo mode** (`apply_repo_local` in `lua/parley/init.lua:400-410`):
  when nvim is started inside a `.parley/` repo, that repo's chat dir
  is injected as the primary write root with the global as read
  fallback.
- **super-repo mode** (`lua/parley/super_repo.lua`): a runtime toggle
  that appends sibling `.parley` repos' `workshop/parley` dirs as
  read-only roots.

The freeform "add an arbitrary folder as a chat root" path is now
redundant *and* the only thing that requires `chat_roots` to be
persisted state. Removing it lets us model roots as a derived list:

```
chat_roots = [config.chat_dir] + repo_local_dir + super_repo_pushed_dirs
```

…recomputed on every `get_chat_roots()` call. No persistence, no
transient-vs-permanent gate, no `label` sentinel arithmetic.

### Goals

- A single configured global root (`config.chat_dir`).
- Repo mode and super-repo mode unchanged from the user's perspective.
- No UI / command / keybinding to add or remove arbitrary chat roots.
- `state.json` no longer carries `chat_dirs` / `chat_roots`.
- Read consumers (`chat_finder`, `memory_prefs`, validation) unchanged.

### Non-goals

- No change to chat-file-naming or in-buffer format.
- No change to repo detection logic (`.parley/` marker still bootstraps
  repo mode).
- No change to super-repo discovery / sibling-walk.
- Memory subsystem unchanged.

## Plan

### M1 — disable, don't delete (one-flip rollback)

- [x] Remove the `<C-g>h` keybinding registration for `chat_dirs`
      (`lua/parley/keybinding_registry.lua` — entry deleted).
- [x] Unregister `:ParleyChatDirs`, `:ParleyChatDirAdd`,
      `:ParleyChatDirRemove` user commands (removed from `M.cmd` table
      in `init.lua`; the auto-registration loop at `init.lua:906` no
      longer creates them).
- [x] Leave the underlying `add_chat_dir` / `remove_chat_dir` /
      `rename_chat_dir` functions in place for one release as a safety
      net. Marked with a deprecation comment in `chat_dirs.lua`. The
      handler functions `cmd_chat_dirs` / `cmd_chat_dir_add` /
      `cmd_chat_dir_remove` similarly kept as dormant code.
- [x] Continue reading `chat_dirs` from `state.json` during
      `refresh_state` for back-compat, but stop writing it. Implemented
      by nil-ing `persist_state.chat_roots` and `persist_state.chat_dirs`
      after `strip_transient` in `init.lua` (read path at lines 1001-1009
      untouched; old state files still de-serialize cleanly).
- [x] Test contract inverted: `chat_dirs_spec.lua` now asserts
      `read_state().chat_dirs == nil` and that re-`setup()` does not
      restore previously-added dirs.
- [x] `make test` clean, `make lint` clean.

Verification (manual) — completed 2026-05-04:
- [x] Plain global mode: `get_chat_roots()` returns one entry; new
      chats save under `config.chat_dir`; disabled commands raise
      `Not an editor command`; `state.json.chat_dirs/chat_roots = null`.
- [x] Repo mode: finder shows repo chats with no `{...}` prefix and
      global as `{global}` (after the apply_repo_local label fix);
      `state.json` stays clean.
- [x] Super-repo mode: sibling repos appear labeled
      `{<sibling-repo-name>}`; toggle off removes them; state
      untouched.

### M2 — delete (revised scope, executed)

The original draft had two items that turned out to be wrong on
inspection — `root_dirs.lua` mutators and `root_dir_picker.lua`
hotkeys are shared with the *note* system, which still has UI commands
and persists. Notes were left untouched. The "pure derivation" item
was also dropped — the existing cached `M._state.chat_roots` shape
works fine once freeform mutation is gone, and the refactor would
touch hot read paths for marginal gain. Final M2 scope:

- [x] Delete `M.add_chat_dir` / `M.remove_chat_dir` / `M.rename_chat_dir`
      from `lua/parley/chat_dirs.lua` and the matching forwarders in
      `lua/parley/init.lua` (root_dirs.lua mutators kept for notes).
- [x] Delete `M.cmd_chat_dirs`, `M.cmd_chat_dir_add`,
      `M.cmd_chat_dir_remove` from `chat_dirs.lua`.
- [x] Delete `lua/parley/chat_dir_picker.lua` and its require in
      `init.lua`.
- [x] Stop reading `chat_dirs` / `chat_roots` from `state.json` on
      load — `init.lua` `refresh_state` chat branch removed.
- [x] Delete the chat-side defensive re-injection at
      `init.lua:1020-1043` (note-side block kept).
- [x] Drop chat half of `strip_transient` and inline the note-side
      logic; chat is unconditionally nil-ed before persist.
- [x] Delete `global_shortcut_chat_dirs` from `config.lua`.
- [x] Replace `tests/unit/chat_dirs_spec.lua` with the new contract:
      single-root derivation, no chat keys in state.json, stale chat
      keys ignored on load, stale chat keys removed from state.json
      on next persist.
- [x] Update `atlas/infra/repo_mode.md` and `atlas/modes/super_repo.md`
      to reflect the new chat/note asymmetry.
- [x] All tests pass; lint clean (151 files, was 152 — chat_dir_picker
      deleted).

### Verification

- `make test` clean after M1 and M2.
- `make lint` clean.
- Manual smoke test in three states:
  1. Plain global mode (no `.parley` in cwd) — chats save to
     `config.chat_dir`; finder shows that dir.
  2. Repo mode (`cd` into a repo with `.parley/`) — chats save into
     the repo's chat dir; finder shows repo as primary, global as
     secondary.
  3. Super-repo mode toggled on — sibling repos appear in finder;
     toggle off — they disappear; state.json untouched throughout.

## Log

### 2026-05-04

Drafted. Triggered by user observation that the multi-root setup was
overgrown — the original "drop a folder in" intent is now fully covered
by repo + super-repo modes. Explore agent mapped the current
machinery; storage lives in `M._state.chat_roots` with a
persistence gate (`label = "repo"` / `super_repo.get_pushed_chat_dirs`)
that exists *only* to keep transient roots from leaking into
`state.json`. With freeform roots gone, the gate has nothing to gate
and the whole list can become a derived value.

M1 implemented same day. Surface area touched:

- `lua/parley/keybinding_registry.lua` — removed `chat_dirs` entry.
- `lua/parley/init.lua` — removed `chat_dirs` keybinding handler;
  removed `M.cmd.ChatDirs` / `ChatDirAdd` / `ChatDirRemove`; removed
  `ChatDirAdd` / `ChatDirRemove` from `completions`; removed unused
  `dir_completion` helper; nil out `chat_roots` / `chat_dirs` in
  persist_state.
- `lua/parley/chat_dirs.lua` — deprecation comments on `add_chat_dir`
  / `remove_chat_dir` / `rename_chat_dir` and on the dormant cmd
  handlers.
- `lua/parley/init.lua` (apply_repo_local) — switched from flat
  `chat_dirs` list to structured `chat_roots` with explicit labels:
  repo dir → `"repo"`, demoted `config.chat_dir` → `"global"` (was
  showing as `{<basename>}` because the normalizer derived labels
  from directory basenames).
- `lua/parley/config.lua` — deprecation comment on
  `global_shortcut_chat_dirs` (now a no-op).
- `tests/unit/chat_dirs_spec.lua` — inverted two persistence tests to
  guard the new contract (`chat_dirs` not written to state.json,
  added dirs do not survive `setup()`).

Decision log:

- Considered actively dropping `state.chat_dirs` on read (so old
  freeform additions disappear immediately) vs read-but-don't-write
  (so they hang around for one session). Chose read-then-don't-rewrite
  for M1 — minimum surprise — but a user with a state.json carrying
  freeform dirs will see those entries one final time before they
  evaporate on next persist. M2 will drop the read path entirely.
