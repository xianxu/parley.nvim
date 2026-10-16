# Agentic Documents and Session-Sync Files

In a Couch pane, the first Alt+Return in a named Markdown document saves it,
registers it with Couch, attaches the existing session-sync turn engine and sends
`submitted: <absolute path>` (#332). Registration supplies a stable document ID;
no `type`, owner or instruction frontmatter is added or changed. Opening a
registered file restores that identity through a bounded registry lookup. A
positive null lookup proves a file plain; lookup failure leaves membership
unknown. Plain files take no session-sync lock or watcher before admission.

The default owner is the agent in this editor's own Couch pane, resolved from
`COUCH_THREAD_SCOPE` / `COUCH_THREAD_TAG`. An explicit `couch-owner:` is an owner
override honored by Couch. An ordinary business `owner:` field is ignored.
Legacy `type: session-sync` files remain recognized: only that typed legacy
form may use `owner:` as the fallback for missing `couch-owner:`. Registration
adopts its existing state before a move. Once attached, the confirmed identity
supplies every owner use: submit, band, liveness ping and violation notification;
editing the header cannot detach the file or silently redirect those operations.

```yaml
# Optional explicit Couch owner; no frontmatter is needed for first submit.
couch-owner: ops:0
```

| Key | Action |
|---|---|
| `<M-CR>` in a Couch pane | Save and register on first submit; confirm identity, release the operator lock and send `submitted: <absolute path>` on later submits. An unresolved pane agent or uncertain mutation keeps submission pending. |
| `<M-CR>` outside a Couch pane | Existing [review behavior](review.md#altreturn-process-instruction-and-the-slot-send-316), including the typed legacy session-sync path. |

**Offline membership.** Unknown/unavailable Couch membership stays editable,
with the exact band `Couch unavailable: agentic state unknown`. Parley never
makes an unknown file read-only because Couch is unreachable. A known attached
identity, or a validated namespace-scoped cache hit, retains full operator-turn
protection while offline. The cache holds at most 256 registrations / 1 MiB;
eviction, corruption or an unavailable cache loses knowledge, never proves a
file plain. Confirmed absence removes its binding. A bounded retry reconciles
loaded unknown files when Couch returns. If edits occurred while unknown,
attachment acquires against the observed pre-edit baseline, even after auto-save.

**The lock (#315: pessimistic for the human, optimistic for the agent).**
The operator's lock is the only lock. The sidecar `<file>.lock` is absent
(free: the agent may write) or `holder: operator` (the agent never writes the
file). The operator's first edit writes it; `<M-CR>` deletes it; the next
edit takes it again. Undoing back to the content before that first edit silently
releases the turn without submitting or notifying the owner; redo away takes it
again. This acquisition baseline is an in-memory content hash: explicit saves
and immediate auto-save never advance it. A save of changed text keeps the turn.
A pre-existing lock after a restart has no known baseline and stays held until submit. A legacy `holder: agent` lock reads as no lock and is
overwritten by the first edit. A failed send leaves the file free; `<M-CR>`
resends. The lock is read from disk, so a reopened buffer shows it too. While
the buffer is loaded, parley watches the file once a second: during a free
turn an agent write reloads the unmodified buffer silently (and so does a
buffer-local `FileChangedShell` on focus or `:checktime`). The operator's turn
never starts on an old copy unnoticed: an agent write that landed just before
the first edit lost the race, and goes through the violation path below with
the operator's text kept. Outside the operator's turn, submit refuses to
overwrite a file rewritten under a modified buffer.

**Edit ordering (#324).** Buffer edit notifications acquire the lock before
`TextChanged` / `InsertLeave` auto-save can clear `modified`, for Normal and
Insert edits alike. Recognition at attachment survives temporary edits to the
frontmatter. Baseline-equality release is deferred until the edit settles and
ensures baseline text is saved before deleting the lock. A failed save retains
the turn. Pending foreign writes/deletions are
reconciled through the violation handler before release; an undecided disk check
keeps the lock until the change can be classified. The watcher’s `:edit!` detaches native
buffer callbacks, so `BufReadPost` reinstalls them before the next keystroke.

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
failing or unknown verb reads as nothing owed. They drive the band. With owed
events and no operator lock, the ping waits `session_sync_ping_minutes`
(default 15) since `LastWrite`, the owner's last session-sync write. When that
field is absent/null, the oldest owed event supplies the age; an invalid write
timestamp never proves staleness. A write postpones the ping even when it folds
no deliveries. The owner's slot in `couch --actors --json` must be live and
quiet (`LastActivity` at least 30 s old, couch's QuietInterval; `Resting` names
the resting branch, not the turn). Parley sends
`session-sync ping: <path> owes a response since <time>` once per write value
in the buffer lifetime (once while no write has been recorded). New deliveries
or folding old ones cannot rearm it. A write or operator lock acquired while
either query is running postpones sending until a later probe.
Every message leaves from the operator's editor, so pair#433's
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

A completed Couch-pane submission overlays the band with `submitted to OWNER ·
HH:MM` (DiagnosticOk), retained through saves and status probes until the next
operator edit or observed agent write. Explicit submit failures show a bounded
literal error (DiagnosticError), including before registry attachment; this
feedback changes neither turn ownership nor the acquisition baseline.

The last confirmed successful submission also records its captured post-save
content hash, stable document ID, namespace, effective owner and local time in
memory. A later Alt+Return still saves/reconciles and confirms the owner first;
unchanged content shows `nothing to submit: no changes since HH:MM` without
sending. A second explicit idle press within two seconds sends anyway and shows
`resent to OWNER · HH:MM`. Busy presses cannot queue a duplicate or authorize a
resend. Changed content or ownership sends normally, and failed or uncertain
sends never advance the receipt. An edit during an issued send keeps its newer
turn and suppresses stale success feedback; confirmed delivery remembers only
the issued content. Confirmed same-ID moves preserve the receipt. Detaching the
buffer or restarting the editor forgets it; the known-path cache contains no
submit history.

An operator turn left idle for `session_sync_stale_minutes` (default 5) is stale.

**The agent's side** is not parley's: the owner diffs the file against its own
copy, resolves the markers and writes while no lock is held (Couch refuses a write
under the operator's lock, pair#439). It never writes or deletes the lock.

**Moves and recovery (#332).** The move contract is forward-only. A
namespace/stable-ID kernel lease covers the exact OLD→NEW tuple, filesystem
effects and Couch metadata confirmation. A second editor cannot execute or
recover that journal while the lease is held. Native `:saveas` keeps its old
file; metadata is never renamed merely because `BufFilePost` changed the buffer
name. NEW must have a successful write first. The existing turn engine suspends
and resumes the same turn and acquisition baseline across the move. After an
owned filesystem rename, a guarded non-bang native read acknowledges the proven
new file to Neovim so later ordinary writes and auto-save remain valid. It keeps
undo and view, refuses a modified handoff, and reinstalls edit callbacks before
releasing migration protection.

An existing `project.side/` beside `project.md` moves to `renamed.side/` beside
`renamed.md`; an occupied destination refuses instead of merging or overwriting.
Only existing `parent:` frontmatter and body Markdown links resolving to the old
parent are rewritten, relative to each moved child. Quoting, fragments and
unrelated bytes are preserved; missing backlinks are not invented. Escaping
symlinks, malformed/ambiguous relevant data and changed backlink preimages
refuse before overwrite. Side scans stop at 4096 entries / 512 Markdown files.

Journals live in configured `state_dir`, partitioned by Couch namespace and
stable ID, at most 32 pending journals / 256 KiB each. They record the exact tuple,
path/content witnesses and completed effects, not document snapshots. Recovery
rechecks those witnesses under the same lease and resumes the same tuple; an
unprovable partial effect stays pending for concrete recovery instead of
rolling files back or overwriting new data. Metadata-only Couch rename must
confirm the same ID and destination, returning the current effective owner; an idempotent replay succeeds. Only
then is the matching OLD lock removed and the completed journal deleted.
Unresolved journals are never aged out. Lease files are bounded to 4096 IDs per
namespace and remain allocated; deleting a live lease pathname would split
execution ownership. There is no automatic lease-file garbage collection.

Code: `agentic_document.lua` owns admission, cached knowledge and native move
hooks and the public Parley movers. Owned file moves journal intent before an
atomic no-replace rename; native saveas waits for its successful write witness.
`document_session.lua` owns the pure lifecycle; `document_registry.lua`
uses the shared `couch.run` transport. `document_move_plan.lua` projects pure
side/backlink effects, `document_move.lua` executes and recovers journals,
`document_lease.lua` owns kernel leases, and `helper.write_file_atomic` is the
shared checked byte writer. `session_sync.lua` remains the single edit-turn,
watch, baseline/undo, ping and rendering engine. Dispatch and keys live in
`setup_markdown_keymaps` (`lua/parley/init.lua`). The maintainer real/fake registry
probe is documented in [TOOLING](../../TOOLING.md).

Native and public move preflight also checks the loaded coordinator before
plain fallback: unresolved owner selection, pending admission and an active
submit cannot be renamed past. Fresh bounded OLD membership confirms the
plain bypass; unavailable membership blocks migration while editing stays
available.

A true buffer unload retires its async incarnation and execution lease; reopen
confirms registration and resumes any durable forward-only move journal.
Controlled session-sync rereads and owned rename acknowledgements mark their
native read epoch explicitly, retaining attachment and the successful receipt.
Raw completions during that epoch wait until read observers have reconciled;
they cannot authorize an old captured submit against newly loaded content.
