# Agentic Documents and Session-Sync Files

In a Couch pane, the first Alt+Return in a named Markdown document saves it,
registers it with Couch, attaches the existing session-sync turn engine and sends
`submitted: <absolute path>` (#332). Registration supplies a stable document ID;
no `type`, owner or instruction frontmatter is added or changed. Opening a
registered file restores that identity through a bounded registry lookup. A
positive null lookup proves a file plain; lookup failure leaves membership
unknown. Plain files take no session-sync lock or watcher before admission.
Insert admission below begins once that registration identity is known (from
cache or a completed lookup). While an uncached lookup is still pending, S1
keeps editing available and records outstanding edits for reconciliation on
attachment. It does not block every Markdown insert on discovery. Sharing the
500 ms budget with an already-pending lookup is tracked separately in #410.

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
file). Registered insert entry confirms acquisition under Couch's registry
transaction before queued input can apply (#408). It then runs an unconditional
freshness check: a clean pre-ack write reloads silently before the first edit,
with the acquisition baseline taken from that fresh snapshot. Nested InsertEnter
dispatch permits this narrowly scoped native reread without a deferred warning;
dirty conflicts still reconcile outside input autocmds. Normal-mode first edits
and observed unknown-period edits share the acquisition owner.

The acquire/release commands have a named 500 ms bound. Namespace/store
unavailability or timeout leaves editing enabled with `not locked: Couch
unreachable; edits may conflict`; the warning survives saves and outranks older
submit receipts. A concurrent write after an unconfirmed edit uses the existing
clobber-copy effect even if auto-save cleared modified. Held/identity/path
refusals, uncertain sidecar publication and invalid/mismatched acknowledgments
block changes and say that keys were not applied. After leaving insert, press
`i` to retry; refused-only buffer-local `i/a/o/I/A/O` mappings run admission,
then the original native entry action only when admitted. `:ParleySessionRetry`
runs the same admission without inserting or submitting. Successful or degraded
admission removes those maps, restoring displaced local mappings and uncovering
global ones. Refusal never creates a writable gap.
No automatic retry or guessed unlock. The commands run locally without the
Couch supervisor; its absence alone is not a degraded condition.

The pure `operator_admission.lua` owner retains the original baseline, token and
proof through unavailable/refused retries, saved edits and status refreshes.
Its phases are idle, acquiring, freshening, held, unconfirmed and refused; only
a confirmed release retires normal turn history. The session engine runs its
IO effects and returns matching operation witnesses. Validated move restoration
and exact-preimage rebase use the same owner, including legacy journal proofs.

The producer contract is `operator-acquire FILE --id ID --turn TOKEN --json`
and matching `operator-release` (pair#777). One 32-hex token identifies the turn;
lost-reply retries retain it and preserve exact lock text/time. `OperatorLock`
acknowledges ID, canonical File, Holder, Turn, LockPath, LockText and State.
The lock bytes carry strict single `document` and `turn` fields. Owned release
uses the producer transaction and verifies its acknowledgment; a move copies
those bytes and releases at the new canonical path with the same ID/token.
Existing journals retain their exact legacy ownership witnesses without a
format migration. Unrelated registered legacy/foreign protection is refused.
Producer availability is required before shipping this consumer contract.

Unchanged insert exit releases the owned turn. `<M-CR>` saves and releases it;
the next insert entry or edit takes it again.
Undoing back to the acquisition content silently releases the turn outside
insert mode, without submitting or notifying the owner; redo away takes it again.
Restoring the baseline while inserting retains protection until insert exit.
InsertLeave and ModeChanged share one departure handler: Ctrl-C skips
InsertLeave, but still ends unchanged intent. Completion/replace submodes keep
intent; non-insert departures defer reconciliation until input/autosave settles.
Automatic move finalization shares the same eligibility rule and retains live
intent even when its acquisition baseline is unchanged. Persisted release
permission is rechecked at recovery admission and immediately before cleanup,
including protection/retire replay. If fresh insert intent conflicts, the move
stays interrupted: leave insert mode and reopen the destination to finish it.
No lock or journal is overwritten to force recovery.
Attachment completed during insert mode takes the same lock. No idle-release
timer or new watcher is added; failed release retains the existing band/recovery. This acquisition baseline is an in-memory content hash: explicit saves
and immediate auto-save never advance it. A save of changed text keeps the turn.
A pre-existing registered lock after a restart has no proven local ownership; it is not adopted or removed by guessing. Its owner must release it before a new turn can acquire. Legacy unregistered session files retain their previous submit behavior. A legacy `holder: agent` lock reads as no lock and is
overwritten by insert entry or an edit. A failed send leaves the file free; `<M-CR>`
resends. The lock is read from disk, so a reopened buffer shows it too. While
the buffer is loaded, parley watches the file once a second: during a free
turn an agent write reloads the unmodified buffer silently (and so does a
buffer-local `FileChangedShell` on focus or `:checktime`). Either reload keeps
every window on the text it showed (#356): `view_map` maps each cursor and top
line through a line diff, and a line the agent rewrote is followed by its own
text. `window_views` (capture before, restore after) owns that wrap, and
parley's own whole-buffer rewrites use it too (#358): `file_refresh` after the
chat write, edit and propose tools, and the review round's reload. The operator's turn
never starts on an old copy unnoticed: a registered clean insert reloads a
write completed before acquisition acknowledgment. A dirty first edit or a genuine
write after acquisition goes through the violation path below with the
operator's text kept. Outside the operator's turn, submit refuses to
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
| free | `free: insert mode or an edit takes your turn` (no lock, nothing owed) | `ParleySessionSyncFree` (StatusLine) |
| owed | `<owner> owes a response, N min` (N since the oldest owed event; no operator lock) | `ParleySessionSyncOwed` (DiffChange) |
| operator | `your turn, Alt+Return to submit` | `ParleySessionSyncOperator` (dark red `#870000`, white bold) |
| violated | `<owner> wrote under your lock: yours kept, theirs in .clobbered` (`changed as you started typing: …` for the race) | `ParleySessionSyncOperator` |
| stale | `unsent edits, Alt+Return to submit` | `ParleySessionSyncStale` (orange, black bold) |

Leaving a held, unsubmitted turn triggers three 150ms bright-red pulses through
`document_band`, plus a one-line reminder naming the source file. A WinLeave
pulses the departing physical window; a same-window buffer switch pulses its
destination bar and names the source. Navigation is never blocked. The existing
acquisition baseline suppresses an undone turn, even before deferred release;
auto-save does not suppress an outstanding turn. One cancellable pulse owns each
window, duplicate leave events coalesce, and underlying view updates remain live.
Window/buffer replacement, source turn release/detach and user option overrides
retire the pulse. New splits do not retain a copied red frame. The bright group
is `ParleySessionSyncLeave` (red `#ff0000`, white bold).

A completed Couch-pane submission overlays the band with `submitted to OWNER ·
HH:MM` (DiagnosticOk), retained through saves and status probes until the next
operator edit or observed agent write. Explicit submit failures show a bounded
literal error (DiagnosticError), including before registry attachment; this
feedback changes neither turn ownership nor the acquisition baseline.

The submit never blocks the editor (#357). It shows `submitting…` until its
outcome, under one deadline (`agentic_submit_timeout_ms`, 15 s) that covers the
registry stage and the send together. Past the deadline, or on a registry
failure, the band reads `not confirmed: submit again · <reason>`. That is one
state, and Alt+Return is its one action:
- A registry stage that timed out still holds the operator's lock, since the
  send never started. The next press confirms the registration, then submits
  the current bytes.
- A send already issued is never killed, because a kill can't tell delivered
  from not. A press while it is out joins it (`submitting… still waiting for
  Couch`), and its late success records the receipt below, so an identical
  resubmit sends nothing.

**Moves never wait on Couch (#359)**, except an overwrite of an existing file.
`document_move_plan.move_preflight` decides from what parley already holds: the
loaded model, the namespace cache, or an earlier background answer.
- A registered document moves at once. Couch's own rename is the authority on
  NEW, refusing an occupied destination (`destination_registered =
  "authority"`), and the journal carries the metadata rename forward.
- A positively plain document renames plainly.
- An unknown identity or a legacy `type: session-sync` file refuses at once
  with nothing moved (`move not confirmed: … Run the move again`), and asks
  Couch in the background, so the rerun proceeds. A background "absent"
  answer holds for `ANSWER_TTL_MS` (60 s). A rerun after that asks again, so a
  registration made since is never moved past.
- Neovim gives the rename hooks no `!`, so any rename onto an existing path
  (`:saveas!`, or `:file` there) takes the bounded check below.
- Only `:saveas!` onto an existing file asks inline, within
  `agentic_move_timeout_ms`. Neovim writes it before Couch could refuse, and
  past the deadline the recovery is `rename back to OLD, then run it again`.

`move_outcome` maps new v2 moves to three operator states:
- moving: `moving: confirming with Couch`; wait for confirmation;
- done: the move band clears; no action;
- interrupted: `move interrupted: reopen to finish; REASON`; reopen is the
  recovery action. Internal journal phases are never shown as choices.

Reopening rechecks filesystem and editor witnesses and resumes the same intent.
A refusal before any effect aborts cleanly. After an effect, changed or unknown
bytes keep the move interrupted with its concrete reason; nothing is rolled
back or overwritten to force progress. Older v1 journals remain readable and
retain their earlier feedback while being recovered.

After the parent rewrite is acknowledged, `document_move.record_write` makes
each later save the journal's witness for NEW, including saves while metadata
confirmation is delayed. A save cannot restore the old parent references.

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
`renamed.md`. If NEW was absent when admitted, an occupied target side folder is
an orphan: it moves without replacement to the first free `renamed_N.side/`
(up to 4096 candidates checked before effects). The notification names that
retained folder; it adds no recovery choice. An overwrite of an existing NEW
never authorizes orphan displacement.

The moving parent's Markdown links into its side tree and block `discussions:`
entries are rewritten. Pending Pair insertion proposals containing an escaped
`→ [proposal](…)` or `→ [discussion](…)` side-doc link use the same destination
rewrite while preserving the marker's bracket escaping. Escaped prose outside
that complete one-line proposal and fenced/inline code remain literal. Existing side-doc `parent:` fields and backlinks to the
old parent are rewritten relative to each moved child. Nested side docs retain
their own parent relationship, and incoming links from other documents stay
unchanged. Quoting, comments, fragments and unrelated bytes are preserved;
missing backlinks are not invented. Escaping symlinks, malformed/ambiguous
relevant data and changed preimages refuse before overwrite. Side scans stop
at 4096 entries / 512 Markdown files.

**Side docs inherit the parent's owner (#378).** Alt+o from a registered parent
onto a file directly in its `.side/` folder (the mover's rule; no frontmatter
needed) registers an absent child to the parent's effective owner, never to the
pane's actor, and sends nothing. The model confirms both halves with Couch
first: the child is absent, and the parent still holds the registration the
parent buffer showed. A registered child keeps its owner; if another actor
registers the child first, the child adopts that registration. Anything
unconfirmed registers nothing: a parent Couch no longer confirms (stale, gone,
unavailable) shows `not inherited · reopen from parent to retry, or Alt+Return
here`, and a child lookup Couch cannot answer shows the usual `Couch
unavailable` band. A parent with no registration offers nothing to inherit.
Other Markdown links never inherit. An Alt+Return pressed while inheritance is
under way is authorized only by it: a registration means one submit to that
owner, anything else drops the press, so it is never re-aimed at the pane's
actor. Pressing again on the plain doc is the deliberate fallback. The pure
model owns the held press: `queue_submit` asks it to hold one, and every
dispatch settles it, so whichever event ends the holding operation (reply,
refusal, `changed`, pending, detach) emits exactly one `flush_queued` or
`drop_queued`. The shell submits only on `flush_queued`.

Journals live in configured `state_dir`, partitioned by Couch namespace and
stable ID, at most 32 pending journals / 256 KiB each. They record the exact tuple,
path/content witnesses and completed effects, not document snapshots. The
single existing journal now writes v2 records; v1 records remain readable.
`document_move_state.lua` is the pure transition authority, and one dispatcher
in `document_move.lua` owns v2 checkpoint replacement for fresh moves and
recovery. Recovery rechecks witnesses under the same lease and resumes the
same tuple; an unprovable partial effect stays interrupted for reopening.
Metadata-only Couch rename must confirm the same ID and destination, returning
the current effective owner; an idempotent replay succeeds. Only then is the
matching OLD lock removed. Finalization stays inside the same journal with
internal handoff, protection and retirement progress. Before releasing a
synthetic NEW lock it records the exact intended after-state; a held unsent
operator turn remains held. Fresh moves and recovery use this same path.
Reopening recognizes captured-before or authorized-after lock states with
matching document/editor witnesses; foreign lock bytes and changed contents
remain interrupted. Every disk/protection effect finishes before journal
unlink, and the session engine resumes only afterward. A failed unlink or
process death between steps therefore retains replayable authority.
Unresolved journals are never aged out. Lease files are bounded to 4096 IDs per
namespace and remain allocated; deleting a live lease pathname would split
execution ownership. Lease digests preserve raw identity bytes across Neovim
versions; when an older SHA API rejects NUL, the boundary hashes raw stdin with
sha256sum/shasum and refuses before allocation if neither is available. There is
no automatic lease-file garbage collection.

Code: `agentic_document.lua` owns admission, cached knowledge and native move
hooks and the public Parley movers. Owned file moves journal intent before an
atomic no-replace rename; native saveas waits for its successful write witness.
`document_session.lua` owns the pure lifecycle; `document_registry.lua`
uses the shared `couch.run` transport (with `timeout = false`: its own timer is the one deadline) and owns the default registry deadline
(`default_deadline_ms`, read through `config_ms`). A request that names none
gets `agentic_submit_timeout_ms`, and a rename, native or journaled, gets three
of them; there is no hidden literal (#382). Only the inline `:saveas!` check
names its own, shorter deadline. A deadline bounds the child from its spawn, not
from when it queued behind the four running ones. The queue is bounded by count
(64), not time; a caller that needs a wall-clock bound sets its own, as the
inline `:saveas!` check does. Every result carries `queued_ms`/`ran_ms`, and a
refusal the child's `exit` and `stderr`. Each such deadline refreshes the loop
clock before it starts (`helper.start_deadline`), since libuv measures a timer
from cached time. `document_move_plan.lua` projects pure
side/backlink effects and the [S3 projection contract](#s3-move-projection-and-execution-373).
`document_move.lua` dispatches and recovers the journal through the pure
`document_move_state.lua` reducer; `document_lease.lua` owns kernel leases, and
`helper.write_file_atomic` is the shared checked byte writer. `session_sync.lua`
remains the single edit-turn, watch, baseline/undo, ping and rendering engine.
Dispatch and keys live in `setup_markdown_keymaps` (`lua/parley/init.lua`). The maintainer real/fake registry
probe is documented in [TOOLING](../../TOOLING.md).

### The agent's round and `presentation:` (#383)

Couch keeps the change an agent's last write made, as its round (pair#661).
Spans hold 0-based `[line, byte column]` positions in the written file, the
old and new text, and an optional `explain`. A document's `presentation:`
frontmatter key (`direct` | `highlight` | `propose`; missing or unknown means
`highlight`, as Couch reads it) says how parley shows the round. The pure
`presentation.lua` reads the key and places the spans. It places a span where
Couch says only when the buffer's hash is the round's `result_hash` and the
text is there. Otherwise it re-finds the span by its new text, nearest its old
position. Each placed span carries a kind from `presentation.kind`: `add` when
its old text is empty, `change` otherwise. A deletion (empty new text) leaves
no trace, so it yields nothing (#387). A span that can't be placed is dropped, never clamped. At most
`MAX_SPANS` (200) spans are placed.

`edit_round.lua` is the shell around it. `refresh(buf)` asks Couch (`round PATH
--json`, through `document_registry`'s bounded client and its own reply
classifier) and draws under `highlight`. Under `direct` nothing is drawn, and
under `propose` the proposal markers are already in the text. A larger rewrite
arrives as a `→ [proposal](…)` side-doc link, followed and inherited like any
side doc. A generation per buffer drops a reply that a later refresh or clear
overtook. A round with more than 200 spans says so once, as a WARN notice
(`showing 200 of N agent changes`). `session_sync` refreshes after `reload()`,
at `FileChangedShellPost` and on attach. It clears in `release_and_send`'s
confirmed branch, before the state guard (sent is sent). A reopen draws nothing
once Couch reports the round `Cleared`, which means a submit came after it,
compared as instants. BufUnload forgets the buffer.

Drawing is `skill_render`'s round kind: `ParleyEditAdd` or `ParleyEditChange`
highlights by span kind (#387: faint tints of `Normal`'s background) in the `parley_round_hl` namespace, plus INFO diagnostics with
source `parley-round` in the shared review namespace. Every writer of that
namespace replaces only the kind it owns, through one `replace_kind` helper.
The round is owned by the round functions alone, so a review-skill run, an
undo/redo snapshot or a dismiss leaves it in place. Footnote and review-skill
diagnostics likewise survive a round's publish and clear. Marks move with the text and
diagnostics do not, so a buffer-local `on_lines` re-derives them from the
marks. Keystrokes coalesce into one scheduled re-derive per buffer, O(spans),
which a counted 8/16-keystroke spec holds. The fake keeps a seeded round and
stamps submits to the microsecond. The opt-in registry conformance probe
checks the real binary's `round` too.

### S3 move projection and execution (#373)

`document_move_plan.project(OLD, NEW, observations)` describes effects from
complete supplied observations; it performs no IO. Alongside the existing ID,
file/write/registration and side-tree observations, optional `parent_bytes`
enables the moving document's own reference rewrite. An occupied target side
folder needs `new_absent_at_admission = true` and dense `orphan_candidates`:
occupied suffixes followed by the first free suffix, at most 4096 observations.
An existing NEW document, unknown suffix, exhausted search, escaping/duplicate
entry or ambiguous relevant syntax cannot authorize orphan displacement.
The shared pure geometry check also rejects interfering side/orphan roots:
distinct roots cannot contain one another or either document, including an
absent source-side root. A shared identical side root remains one resource.
Frontend and direct mover admission use read-only suffix preflight before save
or protection; unsafe moves explain the conflict and ask for another name first.

Before a successful NEW write, the result is `wait_new_write`; supplied parent
syntax is validated before that result. Afterwards effects are ordered:
`move_orphan` when needed, `move_side`, changed child `rewrite_parent` effects,
moving-parent `rewrite_document`, then `rename_metadata`. The result's optional
`orphan_destination` names `<newstem>_N.side/`; the active parent keeps its
canonical `<newstem>.side/`. A same-side extension change needs no folder rename.

`rewrite_side_references` updates the parent's links resolving inside its old
side tree and supported block `discussions:` doc scalars, even when the source
folder is absent. Scalar quotes/comments, fragments and unrelated bytes remain
exact; ambiguous scalars or relevant unsupported destinations refuse without a
partial result. Both rewrite APIs share scalar/link helpers and the reference
scanner's `markdown_blocks` containment rules, preserving inline/fenced code.
Other documents' incoming links are outside the supplied tree and are not
rewritten. Shared exported before/after fixtures exercise this pure contract.

The v2 dispatcher executes this projection under the existing lease. Parent
disk references are rewritten before metadata confirmation; the coordinator
acknowledges that content through a guarded native reread, then calls
`session_sync.synchronize_move(buf, token, expected_before_content_hash)`.
That API checks the move token, loaded/unmodified buffer, destination and lock;
it refreshes the observed content/mtime and translates only a baseline equal to
the pre-rewrite editor content. An outstanding operator baseline stays intact.
A changed buffer or protection witness interrupts the move instead of replacing
an operator edit. Editor acknowledgement and its protection witness are
checkpointed before the registry rename can proceed.

`tests/integration/document_move_shared_spec.lua` discovers every exported move
fixture from the manifest and checks both the pure projection and real disk
execution through the persistent fake Couch registry against the complete
exported after tree. `document_move_state_spec.lua` covers reducer transitions;
`document_move_owner_spec.lua` guards the dispatcher's sole checkpoint ownership.
`session_sync_native_spec.lua` checks synchronization tokens, lock witnesses and
baseline translation. `agentic_document_owned_move_spec.lua` covers public
moves, native saveas, editor-read races, recovery and later saves during delayed
confirmation.

Native and public move preflight also checks the loaded coordinator before
plain fallback: unresolved owner selection, pending admission and an active
submit cannot be renamed past. The plain bypass needs positive absence that
parley already holds (#359). While Couch is unavailable, a held identity still
moves, and its journal recovers the rename on reopen; editing stays available.

A true buffer unload retires its async incarnation and execution lease; reopen
confirms registration and resumes any durable forward-only move journal.
Controlled session-sync rereads and owned rename acknowledgements mark their
native read epoch explicitly, retaining attachment and the successful receipt.
Raw completions during that epoch wait until read observers have reconciled;
they cannot authorize an old captured submit against newly loaded content.

Window rendering is shared by legacy session files and registered ordinary
Markdown in `document_band.lua`. It installs both winbar and StatusLine mapping,
including unknown/pending admission and pre-attachment feedback. The state
owners still choose their views. Temporary views restore a live underlying
view on release; buffer handoff retires old window ownership. Final detach
restores original options only when they still contain our installed values.

Neovim can cache a rendered window-local value before BufWinLeave. The renderer
retains the original/installed option proof for that window/buffer pair until
re-entry, consuming it before a new renderer captures its baseline. Re-entry,
buffer wipe and window close remove these in-memory proofs; no file or timer
is created, and repeated visits do not append history.


The shared renderer also composes [per-window breadcrumb trails](../ui/breadcrumb.md). State selection supplies the underlying lock and a separate feedback value; a submission receipt does not replace that lock cell. Window width and cached trail are composition inputs, with no filesystem or subprocess work on repaint. The acquisition-baseline hash supplies the unsubmitted dot even after auto-save.
