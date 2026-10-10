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

**The turn.** The agent holds the file by default. The operator's first edit
writes the sidecar `<file>.lock` (`holder:` and `time:`); while it exists the
agent never writes the file. After a submit, parley polls the lock once a
second. The owner replies by rewriting the file and deleting the lock; parley
then reloads the buffer and makes it editable. A failed send leaves the buffer
editable and shows couch's error.

**Reminder.** While the operator holds the lock without submitting, an idle
buffer (`session_sync_stale_minutes`, default 5) shows the virtual text
"unsent edits: Alt+Return to submit".

**The agent's side** is not parley's: the owner diffs the file against its own
copy, resolves the markers, writes, and deletes the lock.

Code: `lua/parley/session_sync.lua`; dispatch and keys in
`setup_markdown_keymaps` (`lua/parley/init.lua`).
