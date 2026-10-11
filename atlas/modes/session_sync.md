# Session-Sync Files

A markdown file whose frontmatter says `type: session-sync` is a turn-based
shared file between the operator and one agent (#313). The ops TL's status file
(`tl-status-<operator>.md`) is the first user: the operator comments with
`🤖[…]` markers and hands the turn back with one key.

```yaml
type: session-sync
owner: ops:0        # couch address of the agent that keeps the file
operator: xian-xu   # who the operator is
```

| Key | Action |
|---|---|
| `<M-CR>` | Submit: save, delete the lock, run `couch --send-to <owner> --message "submitted: <absolute path>"`. The buffer stays editable. In any other markdown file it stays the review action. |

**The lock (#315: pessimistic for the human, optimistic for the agent).**
The operator's lock is the only lock. The sidecar `<file>.lock` is absent
(free: the agent may write) or `holder: operator` (the agent never writes the
file). The operator's first edit writes it; `<M-CR>` deletes it; the next
edit takes it again. A legacy `holder: agent` lock reads as no lock and is
overwritten by the first edit. A failed send leaves the file free; `<M-CR>`
resends. The lock is read from disk, so a reopened buffer shows it too. While
the buffer is loaded, parley watches the file once a second: during a free
turn an agent write reloads the unmodified buffer silently (and so does a
buffer-local `FileChangedShell` on focus or `:checktime`). The operator's turn
never starts on an old copy unnoticed: an agent write that landed just before
the first edit lost the race, and goes through the violation path below with
the operator's text kept. Outside the operator's turn, submit refuses to
overwrite a file rewritten under a modified buffer.

**Whose write it was (#317).** parley keeps the mtime it last read or wrote
as a cache, but a write from a non-nested autocmd (an auto-save on
`TextChanged`) fires no `BufWritePost`. So when the mtime moves, parley asks
Neovim with `:checktime <buf>`: Neovim records every write the buffer makes and
raises `FileChangedShell` only for someone else's. The buffer's `autoread` is
off, so an unmodified buffer never reloads on `:checktime` without that event.

**A write under the operator's lock (#314)** is a violation, never a prompt.
The watch, a buffer-local `FileChangedShell` (focus, `:checktime`) and submit
all reach one handler: it copies the agent's file to `<file>.clobbered`
(one per file, overwritten by the next violation), writes the operator's
buffer back with `:write!` (so no save prompts later), flags the band, and
sends the owner one `couch --send-to` message per operator turn
(`session-sync violation: …`). Outside the operator's turn `FileChangedShell`
does what autoread would.

**Owed work and the liveness ping (#314, #315).** At most once a minute (and
right after a submit or a reload) the watch asks
`couch --session-sync status --json FILE` (pair#437) whether the owner owes a
response: since the oldest owed event it reports. Owed events alone decide; a
failing or unknown verb reads as nothing owed. They drive the band. When owed for `session_sync_ping_minutes` (default 5) and the owner's slot in
`couch --actors --json` is live and quiet (`LastActivity` at least 30 s old,
couch's QuietInterval; `Resting` names the resting branch, not the turn),
parley sends `session-sync ping: <path> owes a response since <time>` once per
owed episode. Every message leaves from the operator's editor, so pair#433's
breaker counts it as the operator's, not a peer's.

**Rendering.** Each window showing the file gets a full-width winbar band
and a window-local `winhighlight` for its StatusLine, both in the state's
colour. The groups are defined with `default = true`, so a colourscheme can
override them.

| State | Winbar | Highlight (default link) |
|---|---|---|
| free | `free: editing takes your turn` (no lock, nothing owed) | `ParleySessionSyncFree` (StatusLine) |
| owed | `<owner> owes a response, N min` (N since the oldest owed event; no operator lock) | `ParleySessionSyncOwed` (DiffChange) |
| operator | `your turn, Alt+Return to submit` | `ParleySessionSyncOperator` (dark red `#870000`, white bold) |
| violated | `<owner> wrote under your lock: yours kept, theirs in .clobbered` (`changed as you started typing: …` for the race) | `ParleySessionSyncOperator` |
| stale | `unsent edits, Alt+Return to submit` | `ParleySessionSyncStale` (orange, black bold) |

An operator turn left idle for `session_sync_stale_minutes` (default 5) is stale.

**The agent's side** is not parley's: the owner diffs the file against its own
copy, resolves the markers and writes while no lock is held (Couch refuses a write
under the operator's lock, pair#439). It never writes or deletes the lock.

Code: `lua/parley/session_sync.lua`; dispatch and keys in
`setup_markdown_keymaps` (`lua/parley/init.lua`).
