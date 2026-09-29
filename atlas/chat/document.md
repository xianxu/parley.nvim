# Incremental Document Structure

The structural core under `lua/parley/document/` indexes metadata over externally
owned text. The buffer coordinator owns the live index used by highlighting, folds, outline,
and diagnostic candidate queries. Explicit materialization still uses the
[parser and exchange model](parsing.md). Response sessions capture source and
acquire document grants before asynchronous preparation. Provider text, tool
blocks, completion prompts, and automatic topics use those scoped operations;
the materialized exchange model supplies request input only.

## Ownership and data flow

| Module | Responsibility |
| --- | --- |
| `sequence` | Balanced row/byte index, stable row handles, local revision evidence, bounded summary searches. |
| `lexical` / `grammar` | Shared lexical rules and pure document/answer-scoped state transitions. |
| `lexer` | Bounded read requests and conversion of unread aggregate spans into lexical metadata. |
| `facts` | Indexed positive and negative lookahead with resumable search evidence. |
| `dependencies` | Earliest affected lookahead origin without enumerating a deleted suffix. |
| `semantic` | Scheduled semantic transitions, scoped answer sections, confirmed-region tracking. |
| `structure` | Document lifetime, publication, edit invalidation, and repair orchestration. |
| `projection` | Derived index summaries for exchange boundaries, folds, outline, and diagnostics. |
| `state` | Pure generation/grant transitions, dependency staleness, write-plan revisions, and the write turn. |
| `write_turn` | Pure holder decision for the write turn: an eligible incumbent keeps it, else the lowest admitted id. |
| `editor` | One native buffer attachment, normalized edit events, exact mutation receipts, and undo ownership. |
| `replacement` | Finite replacement cursors, bounded native writes, and private successor evidence across deletion/insertion receipts. |
| `init` | Per-buffer coordinator, immediate authority invalidation, bounded repair, and subscriptions. |

The index retains no transcript payload. Beside it, the coordinator holds one
piece of text per regenerating exchange: its previous answer, for request
context only, for as long as that generation holds its grant (see
[Chat Lifecycle, "Previous answer while regenerating"](lifecycle.md)). An unread
region occupies one aggregate span. Readers supply bounded byte slices; long lines retain bounded lexer state.
Reload replaces the document epoch, invalidating outstanding publication jobs.

A row handle identifies membership in the current sequence. Local publication
requires unchanged source evidence; a detached handle cannot recover its former
position. Derived metadata updates preserve lexical evidence when their token
and summary remain unchanged. Public queries return copies.

Text and syntax evidence have separate revisions. A classified same-row edit
with an unchanged complete lexical descriptor can preserve syntax evidence and
confirmed rendering, while always retiring old text evidence. Syntax evidence
requires an explicit validation mode and cannot authorize a payload write.
Changes whose classification is still unknown follow bounded conservative repair.

Lookahead facts use a third, explicit evidence kind: fixed predicate channels
count matching tokens and retain their greatest syntax revision. Inserting an
ordinary body row therefore leaves “no footer” evidence valid. Adjacency uses a
row channel; preface/tool relationships cannot survive an inserted intervening
row. Compound footer facts separate the document-wide footnote search from the
local previous-nonblank lookup.

Classified Enter/join fragments transfer complete global and answer-section
checkpoints over only the changed rows. Matching output checkpoints and relevant
facts permit reuse of the untouched suffix. Changed reasoning termination,
adjacency, markers, or uncertain inputs take the conservative repair path. When a
fragment's own assumptions hold and only its end checkpoint moves (a blank-count
change under a summary or thinking block), repair restarts at the edit's answer
header, not row 0 (#264). That's sound because admission already proved that no
earlier row depends on the edited rows; the dependency index is pruned before the
splice (`prune_from`, while every handle still ranks) and installed only on that
fallback, guarded by identity on the index roots.

Sequence traversal workers are module-level functions with explicit state.
This prevents LuaJIT traces from retaining operation-local closures over detached
trees; an isolated-process regression verifies reclamation with JIT enabled.

## Grammar scopes

Rendering, document fence scanning, preface containment, and answer sections have
historically distinct fence rules. The core preserves them explicitly. In
particular, a fence that closes after the next question can suppress a global
tool marker while the answer-scoped reducer recognizes a tool section. The two
semantic passes share lexical facts and use different certified lookahead bounds.

An unfinished lookahead returns a continuation or an unread-region request. It
never means “no closer.” Negative results retain dependency evidence through the
searched boundary. Broad structural changes may require a long repair, performed
in bounded slices. Query results identify uncertain semantic regions during it.

Node summaries are folded by the grammar's `merge_summary` and the projection's
`combine`, which are pure: they never mutate operands and return a fresh table.
The sequence relies on that and passes stored summaries through without copying
(#293) — defensive copies there cost ~480k values to repair one 300-row block.
Values still enter through `copy()` when an entry is summarized and leave through
it at query snapshots; `document_sequence_spec` pins the combines' purity and
bounded plain-value shape, and `repair_work_budget_spec` budgets the copies.

## Verification

`make test-spec SPEC=chat/document` maps the pure index, grammar, lexical worker,
fact resolver, dependency index, and repair integration tests. Seeded flat-model
comparisons defend sequence positions and byte totals; independent legacy and
golden fixtures defend malformed transcript behavior. Work counters cover tree
navigation and copied metadata as well as scanned bytes.

## Human edits and write authority

`on_bytes` records what Neovim actually changed, including intermediate logical
coordinates during grouped undo. A bounded changed fragment can transfer its
semantic checkpoint immediately; unknown or broad edits become opaque spans and
repair in scheduled slices. Deleting marker bytes retires their identity even
when the replacement text is identical. Surviving markers move with the index.

A generation receives grants over confirmed byte ranges; a tool round appends its
blocks through the answer's own grant, with none of its own (#266 M2). Each tool
block is one append (#290): streamed prose is written in 4096-byte, 255-row slices,
but a block goes whole (`block` intent, at most `BLOCK_LIMIT` = 1 MiB, the runner's
staging ceiling), so its closing fence never lands in a later turn. A grant is
one closed range, disjoint from every other live grant and never carved out of
one (#266 M4), so an insertion at its boundary is inside it. A continuation first
narrows its answer's grant to the tail (`reclaim_tail`). Editing
granted output revokes overlapping writers;
a human edit to an input dependency marks the captured input stale, while
another generation's writes move it without staling it (#261, see
[Chat Lifecycle](lifecycle.md)). Disjoint edits can
move a grant without cancelling its writer, but retire plans with old revisions.
Reload replaces the epoch and invalidates every old grant and callback.

A write plan names its epoch, generation, entity, grant, and revision. The editor
checks exact expected text and authority before each patch, then compares the
observed native event with the intended patch. Unexpected nested edits stop the
remaining patches; completed patches remain explicit receipts. Undo joins require
an exact preceding receipt from the same writer and unchanged native undo state.

One answer is one undo entry (#282): every generated write `undojoin`s the answer's
block while the receipt holds. The receipt is recorded as soon as the writer's own
patch lands — before the post-write authority check, since writing a whole tool
block suspends the grant until repair confirms it. It survives a plan whose
every patch landed even if authority is suspended afterwards; a partial or
refused plan still clears it. A save (`BufWritePost`) bumps changedtick without text, so the editor
adopts the new tick while the native undo sequence is unchanged. Any other native
text event (a user edit, undo, redo, format-on-save) clears the receipt, so those
stay separate entries. Regenerating is two steps by design: clearing the old
answer is its own entry, then the new answer is one, so the first undo shows
the question unanswered and the second restores the old answer. `answer_undo_spec` covers regeneration, concurrent chats,
mid-stream reload, saves, tool rounds, cancel,
provider failure, reload, separate answers and mid-stream user edits.

## Live consumers

Highlighters query at most 256 rows and 64 KiB per viewport page. Tall windows
advance through pages; horizontal and smooth-scroll windows read byte slices of
long rows. Local edits discard intersecting presentation pages. Uncertain regions
use neutral/local lexical styling; stale semantic roles and fence/footer/draft
context cannot authorize presentation.

Fold queries return at most eight ranges per page. Parley owns every native fold,
and Neovim carries manual folds with their text, so uncertainty removes no fold
(#264): old folds stay stable in position until a complete, confirmed, still-valid
projection is ready. Reconciliation (`fold_native.lua` reads, `fold_diff.lua`
decides) inventories a window's folds without changing them, then removes and
creates only the folds that differ, never splitting a connected region across timer
turns. A fold the
projection already has is never touched, so a closed fold never blinks open during
repair; `document_fold_continuity_spec` checks this after every step. Ordinary
body edits with surviving context let Neovim move folds without rebuilding them.
Structural changes preserve each window's view, open state, and fold enablement
while reconciling affected groups.
The stream writer is a fast path in front of this (#290): each `written` receipt
names where its first byte landed (`first_row`, `first_col`) and its tip, and
`tool_folds.fold_written` folds, in the write's own turn, an appended tool block
(marker to last non-blank row, skipping the prose row a round's first call only
continues) and each streamed `summary` row, classified from the tokens the append
lexed into the index (`written_ranges` is the pure part). It folds exactly what the
projection will, so the reconcile finds a match and leaves it; any disagreement is the
reconcile's to correct. Writing into a row deletes a manual fold over it, so a summary
row still streaming is re-folded each write.
Native application costs scale with changed fold groups and are counted separately.
Reconciliation applies at most 64 groups per timer turn (a single larger connected
region is applied whole). Above 50,000 affected rows, uncertainty still clears the
unconfirmed suffix natively; that cleanup caps each native fold-jump batch at 64
groups and temporarily disables fold display in affected windows. Completion, cancellation, reload, and detach
restore operator fold preferences. Each yield revalidates the projection; edits
that invalidate it abort and rederive the remaining plan. A deferred ordinary join
can avoid native fold work when unchanged topology is confirmed before
invalidation runs.

Outline candidates and diagnostic candidates come from index summaries. Picker
labels use bounded text slices. Navigation requires the current confirmed outline
projection, not merely a surviving handle, and rechecks after focus callbacks.
Diagnostic jobs retire on candidate-text or semantic-context changes, including
between derivation and publication. Previously published diagnostic decorations
remain the last computed snapshot during typing; they grant no navigation or write
authority. The index never stores a second transcript or a full row-position array.

Repair and consumer pagination use a shared cancellable timer owner
(`deferred_work`). Each continuation yields to a new event-loop turn. A bounded
Lua slice alone is insufficient: recursively queued immediate callbacks can still
starve input. Reload cancels pending work; detach closes its owner.

### Callback frames and retirement

The editor's single native attachment uses `on_bytes` for edit arithmetic and
`on_lines` only as an ordering barrier. Grouped undo/redo can expose final buffer
text while sending intermediate byte events; matching lengths do not establish
read provenance. Unsupported callback frames remain opaque until scheduled repair
reads the settled source. The barrier does not apply a second edit stream.

Detach severs the editor's document callback and releases work/effect references.
Fold teardown removes its buffer-owned autocmd group. Externally retained document
handles remain queryable as detached facades; the registry cannot retain retired
documents through its own callbacks. Native LuaJIT collection tests exercise all
production consumers together.

### Reentrant consumer effects

Native presentation can synchronously call operator code. Diagnostic set/reset
fires DiagnosticChanged; fold options/restoration can fire OptionSet. Consumers
retain a captured publication job and revalidate it after these boundaries. A
superseded publisher stops before its next effect and cannot clear newer dirty
work. Diagnostic clear similarly yields ownership to any replacement refresh
started by its callbacks. Recursive diagnostic step reports busy; injected reader
and converter callbacks obey the same current-job rule. Native regressions live
in `tests/integration/diagnostic_reentrancy_spec.lua`.

Fold slices also carry a monotonic presentation generation, mirrored as a scalar
buffer variable for the native fold walk. The native walk stops if a callback
replaces its job without changing text. Detach removes that scalar. The native
redraw test confirms that view-only window calls emit no entry callbacks and
buffer edits are rejected by redraw textlock.

### Superseded native fold work

Fold publication checks captured document/job ownership after callback-capable
operations. Temporary editor state has a separate cleanup obligation: stale
slices restore the captured window's view and fold preference even after losing
publication authority. A configure pass publishes its window list only when
complete; interruption discards that expected job and leaves repair dirty.
Discarding a job releases every captured window without erasing a newer job.
