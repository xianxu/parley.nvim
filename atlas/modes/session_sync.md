# Session-Sync Files

A markdown file whose frontmatter says `type: session-sync` is a turn-based
shared file between the operator and one agent (#313). The ops TL's status file
(`tl-status-<operator>.md`) is the first user: the operator comments with
`🤖[…]` markers and hands the turn back with one key.

```yaml
type: session-sync
owner: ops:0        # couch address of the agent that keeps the file
operator: xian-xu   # recorded as the lock holder
```

| Key | Action |
|---|---|
| `<M-CR>` | Submit: save, make the buffer read-only, run `couch --send-to <owner> --message "submitted: <absolute path>"`. In any other markdown file it stays the review action. |
| `<C-g>u` | Unlock a submit the owner never answered: the buffer is editable again and the lock stays, so `<M-CR>` resubmits. |

**The turn.** The sidecar `<file>.lock` names whose turn it is: absent =
free (the agent may write); `holder: operator` = the operator's turn (the agent
never writes the file); `holder: agent` = the agent's turn (the buffer is
read-only). The operator's first edit writes `holder: operator`; `<M-CR>`
rewrites it to `holder: agent`; the agent deletes the lock when done and never
writes it. A failed send and `<C-g>u` both rewrite it to `holder: operator`.
The turn is read from disk, so a buffer reopened during the agent's turn is
read-only too. During the agent's turn parley polls the lock once a second; when
it is gone, parley reloads the buffer and makes it editable.

**Rendering.** Each window showing the file gets a full-width winbar band
and a window-local `winhighlight` for its StatusLine, both in the state's
colour. The groups are defined with `default = true`, so a colourscheme can
override them.

| State | Winbar | Highlight (default link) |
|---|---|---|
| free | `free: editing takes your turn` | `ParleySessionSyncFree` (StatusLine) |
| operator | `your turn, Alt+Return to submit` | `ParleySessionSyncOperator` (bright red, white bold) |
| stale | `unsent edits, Alt+Return to submit` | `ParleySessionSyncStale` (orange, black bold) |
| agent | `<owner> working, read-only` | `ParleySessionSyncAgent` (DiffChange) |

An operator turn left idle for `session_sync_stale_minutes` (default 5) is stale.

**The agent's side** is not parley's: the owner diffs the file against its own
copy, resolves the markers, writes, and deletes the lock.

Code: `lua/parley/session_sync.lua`; dispatch and keys in
`setup_markdown_keymaps` (`lua/parley/init.lua`).
