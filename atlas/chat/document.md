# Incremental Document Structure

The structural core under `lua/parley/document/` indexes metadata over externally
owned text. It is being integrated under #254; the live buffer adapters still use
the [existing parser and exchange model](parsing.md) during the M2 boundary.

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
