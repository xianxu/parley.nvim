# Incremental Document Structure

The structural core under `lua/parley/document/` indexes metadata over externally
owned text. The buffer coordinator owns the live index used by highlighting, folds, outline,
and diagnostic candidate queries. Explicit materialization still uses the
[parser and exchange model](parsing.md). Generation write migration is the next
#254 milestone; its existing response model is not rendering authority.

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
| `state` | Pure generation/grant transitions, dependency staleness, and write-plan revisions. |
| `editor` | One native buffer attachment, normalized edit events, exact mutation receipts, and undo ownership. |
| `init` | Per-buffer coordinator, immediate authority invalidation, bounded repair, and subscriptions. |

The index retains no transcript payload. An unread region occupies one aggregate
span. Readers supply bounded byte slices; long lines retain bounded lexer state.
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
adjacency, markers, or uncertain inputs take the conservative repair path.

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

A generation receives grants over confirmed byte ranges. Child tool slots exclude
the parent from their ranges. Editing granted output revokes overlapping writers;
editing an input dependency marks the captured input stale. Disjoint edits can
move a grant without cancelling its writer, but retire plans with old revisions.
Reload replaces the epoch and invalidates every old grant and callback.

A write plan names its epoch, generation, entity, grant, and revision. The editor
checks exact expected text and authority before each patch, then compares the
observed native event with the intended patch. Unexpected nested edits stop the
remaining patches; completed patches remain explicit receipts. Undo joins require
an exact preceding receipt from the same writer and unchanged native undo state.

## Live consumers

Highlighters query at most 256 rows and 64 KiB per viewport page. Tall windows
advance through pages; horizontal and smooth-scroll windows read byte slices of
long rows. Local edits discard intersecting presentation pages. Uncertain regions
use neutral/local lexical styling; stale semantic roles and fence/footer/draft
context cannot authorize presentation.

Fold queries return at most eight ranges per page. Uncertainty invalidation
clears semantic folds in the unconfirmed suffix independently of recreation.
Only a complete, confirmed, still-valid projection can recreate them. Ordinary
body edits with surviving context let Neovim move folds without rebuilding them.
Structural changes preserve each window's view, open state, and fold enablement
while reconciling affected groups.
Native application costs scale with affected fold groups and are counted separately.
Creation applies at most 64 groups per timer turn. Above 50,000 affected rows,
cleanup also caps each native fold-jump batch at 64 groups and temporarily disables
fold display in affected windows. Completion, cancellation, reload, and detach
restore operator fold preferences. Each yield revalidates the projection; edits
that invalidate it abort and rederive the remaining plan. A deferred ordinary join
can avoid native fold work when unchanged topology is confirmed before
invalidation runs.

Outline candidates and diagnostic candidates come from index summaries. Picker
labels use bounded text slices and selection resolves the current stable handle.
The index never stores a second transcript or a full row-position array.

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
