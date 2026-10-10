# Session-sync submit Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A markdown file with `type: session-sync` frontmatter becomes a turn-based shared file: the operator's first edit takes a sidecar lock, `<M-CR>` submits to the owning agent via `couch`, and the agent's reply (file rewritten, lock deleted) unlocks the buffer.

**Architecture:** One new module `lua/parley/session_sync.lua` — a pure header parser plus a per-buffer controller (`attach`, `submit`, `unlock`). `setup_markdown_keymaps` attaches it and wraps the existing `review_next` (`<M-CR>`) callback so the dispatch is decided at call time from the buffer's current frontmatter. Unlock-on-reply is a 1s lock-file poll that exists only while a submit is outstanding.

**Tech Stack:** Lua, Neovim API (`vim.uv` timers, `vim.system`, extmarks), plenary/busted specs.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_header` | `lua/parley/session_sync.lua` | new |
| `lock_body` | `lua/parley/session_sync.lua` | new |
| `turn` | `lua/parley/session_sync.lua` | new |
| `view` | `lua/parley/session_sync.lua` | new |

- **parse_header(lines)** — top-level `key: value` pairs between the opening `---` and the closing `---`; returns `nil` unless `type == "session-sync"`, else `{ owner, operator }` (owner may be nil → submit refuses with a message). Unit-tested without IO.
  - **DRY rationale:** parley has three special-purpose frontmatter readers (`issues.parse_frontmatter`, `issue_cards.frontmatter`, chat headers), each shaped for its own record. None returns a generic key→value map; this one is ~12 lines and scoped to the module. If a fourth caller appears, promote it to a shared `frontmatter.lua`.
- **lock_body(holder, epoch)** — the sidecar's text: `holder: <h>\ntime: <ISO-8601 UTC>\n`. Pure so the format is asserted in one place.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `attach` | `lua/parley/session_sync.lua` | new | autocmds, uv timers |
| `submit` | `lua/parley/session_sync.lua` | new | `couch` binary, lock sidecar |
| `unlock` | `lua/parley/session_sync.lua` | new | lock sidecar |
| `dispatch` | `lua/parley/session_sync.lua` | new | the `<M-CR>` callback |
| `is_session_sync` | `lua/parley/session_sync.lua` | new | buffer lines |
| `lock_path` | `lua/parley/session_sync.lua` | new | file system |
| `setup_markdown_keymaps` | `lua/parley/init.lua` | modified | keybinding registry |
| `session_sync_unlock` registry entry | `lua/parley/keybinding_registry.lua`, `lua/parley/config.lua` | new | keymap |

- **attach(buf)** — idempotent (`vim.b[buf].parley_session_sync`), per-buffer augroup. No-op unless the header parses. Sets buffer-local `autoread`. Autocmds: `BufModifiedSet` → take the lock if the buffer is modified, modifiable, and `<file>.lock` is absent; `TextChanged`/`TextChangedI`/`BufModifiedSet` → clear the reminder and restart the idle timer while the lock is held and no submit is outstanding; `BufWipeout` → close timers.
- **submit(buf)** — refuse (notify) without an owner or while a submit is outstanding; `stopinsert`, `silent write`, ensure the lock exists, `modifiable=false`, clear reminder, `vim.system({"couch","--send-to",owner,"--message","submitted: "..abs})`. On exit (scheduled): code 0 → notify `submitted to <owner>` and start the poll; non-zero → `modifiable=true`, notify the stderr. Fake: a `couch` shell script on `PATH` that appends its argv to a file and exits with `$FAKE_COUCH_EXIT`.
- **poll** — `vim.uv` timer, `M.POLL_MS` (1000, tests lower it). When the lock file is gone: stop, `silent edit!` in the buffer, `modifiable=true`, notify `owner replied`.
- **unlock(buf)** — manual escape when the owner never replies: stop the poll, `modifiable=true`. The lock file stays: the operator holds the turn again and resubmits with `<M-CR>`.
- **reminder** — one-shot timer of `config.session_sync_stale_minutes` (default 5); on fire, if the lock exists and no submit is outstanding, set an extmark with eol virtual text `unsent edits: Alt+Return to submit` on row 0 in namespace `parley_session_sync`.

**Lifecycles (ARCH-FUNERAL):**
- `<file>.lock` — created by parley on the first edit (or at submit); deleted by the owner agent on reply (spec §6); if the operator never submits, the reminder nags until they do. One file per session-sync document, never more.
- Poll timer — created at a successful send; closed on lock-gone, manual unlock, or `BufWipeout`.
- Reminder timer — at most one per buffer, replaced on each edit, closed on fire or `BufWipeout`.
- Extmark — cleared on next edit and on submit.

## Tasks

### Task 1: pure header + lock body
**Files:** Create `lua/parley/session_sync.lua`; Test `tests/unit/session_sync_spec.lua`
- [ ] Write failing specs: header with `type: session-sync`, `owner: ops:0`, `operator: xian-xu` → `{owner="ops:0", operator="xian-xu"}` (trailing `# comment` stripped); other `type:` → nil; no frontmatter → nil; unterminated → nil. `lock_body("x", 0)` == `"holder: x\ntime: 1970-01-01T00:00:00Z\n"`.
- [ ] Implement; run `nvim --headless … PlenaryBustedFile tests/unit/session_sync_spec.lua` (via `make test-spec` mapping once added) → PASS. Commit.

### Task 2: controller (attach / lock / submit / poll / unlock / reminder)
**Files:** Modify `lua/parley/session_sync.lua`, `lua/parley/init.lua` (`setup_markdown_keymaps`), `lua/parley/keybinding_registry.lua`, `lua/parley/config.lua`; Create `tests/integration/session_sync_spec.lua`
- [ ] Failing integration specs (temp dir file with session-sync header, fake `couch` on `PATH`, `M.POLL_MS = 20`):
  1. a modification (`nvim_buf_set_lines`) creates `<file>.lock` whose body starts `holder: xian-xu`;
  2. `<M-CR>` (call the bound callback) saves, sets `modifiable=false`, fake argv file holds exactly `--send-to\nops:0\n--message\nsubmitted: <abs path>`;
  3. fake exit 1 → buffer modifiable again, lock remains;
  4. after submit, rewrite the file on disk and delete the lock → buffer shows new content and is modifiable;
  5. a plain markdown buffer's `<M-CR>` still calls the review callback (stub `review_cbs.review_next` via the wrapper seam: `session_sync.dispatch(buf, fallback)`);
  6. `session_sync_stale_minutes = 0.001` → after a modification, the extmark text appears;
  7. manual unlock after submit → modifiable, lock still present.
- [ ] Implement `attach`, `submit`, `unlock`, `dispatch(buf, fallback)` (returns a function: session-sync header → `submit(buf)`, else `fallback()`).
- [ ] Wire: in `setup_markdown_keymaps`, `review_next = review_cbs.review_next and session_sync.dispatch(buf, review_cbs.review_next)`, `session_sync_unlock = session_sync.is_session_sync(buf) and function() session_sync.unlock(buf) end or nil`, then `session_sync.attach(buf)` after `comment.attach`.
- [ ] Registry entry `session_sync_unlock` (config `session_sync_shortcut_unlock`, `<C-g>u`, n, scope markdown, buffer_local); config defaults `session_sync_shortcut_unlock` + `session_sync_stale_minutes = 5`.
- [ ] Run both specs + `tests/integration/review_menu_spec.lua` + keybinding/help specs → PASS. Commit.

### Task 3: atlas + traceability
- [ ] `atlas/modes/session_sync.md` (type, keys `owner`/`operator`, lock protocol, `<M-CR>`, `<C-g>u`, reminder, agent's side); link from `atlas/index.md`; add `<C-g>u` and the `<M-CR>` dispatch note to `atlas/ui/keybindings.md`; `modes/session_sync` entry in `atlas/traceability.yaml` mapping both specs.
- [ ] Full `make test` before close; live check with the ops TL on `tl-status-xian-xu.md`.

## Revisions

### 2026-10-10 — turn holder in the lock + rendering (ops scope fold)
- The lock body is `holder: operator|agent` (see the issue's Revisions). New pure `turn(lock_text)` → free/operator/agent and `view(turn, stale, owner)` → {state, label, hl}; all state is re-read from disk by one `refresh(buf)` that sets `modifiable`, runs the poll only during the agent's turn, and renders the winbar + window-local `winhighlight` (`StatusLine:ParleySessionSync{Free,Operator,Stale,Agent}`, default-linked to StatusLine/DiffAdd/DiffDelete/DiffChange). `status(buf)` feeds `lualine.create_session_sync_component()`, added next to the parley component in `lualine.section`.
- The stale reminder became the `stale` state's winbar label and colour; the eol extmark is gone.
- Core-concepts tables list one row per entity (the arch sweep checks rows by name).

### 2026-10-10 — live-check rendering changes (ops TL, from the operator)
- Winbar label is a full-width band (`%=` fills in the state's colour).
- Lualine component removed, with `status(buf)` that only fed it.
- `ParleySessionSyncOperator` is an explicit bright red band (bg `#d70000`, white bold), `ParleySessionSyncStale` an orange one (bg `#ff8700`); both `default = true`, so a colourscheme can still override them.
- Re-check: operator red darkened to `#870000` (cterm 88).

### 2026-10-10 — close review round 1 (BR-1, BR-2 + minors)
- Supersedes the Core-concepts prose where it differs: `attach` idempotency comes from the module `state` table (not `vim.b`); the reminder is the `stale` state (no extmark); `unlock` rewrites the holder to `operator`; the 1s timer is a *watch* that runs whenever the turn is not the operator's.
- BR-1: each submit carries a generation; its couch completion acts only while `state[buf]`, the generation and `holder: agent` all still match, so a late failure cannot hand back a turn that moved on (unlock, resubmit, reply).
- BR-2: the watch also runs in the free turn and reloads an unmodified buffer when the file changes on disk; the buffer records the mtime it last read/wrote, the first edit warns if it is editing an old copy, and submit refuses to overwrite a file rewritten under it (without that guard Neovim's own write prompt blocks).
- Minors: the idle timer is reused per buffer and reads the cached turn; attach starts the idle timer, so a reopened operator turn still turns stale.
