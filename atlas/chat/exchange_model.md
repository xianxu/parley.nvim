# Exchange Model

The exchange model (`lua/parley/exchange_model.lua`) materializes parsed chats for
preparation, serialization, and existing response planning. Live rendering and
identity queries use the [document coordinator](document.md). The remaining
generation model is scheduled for retirement with #254 M4 scoped writes.

## Core Principle: Everything Is a Block

An exchange is a flat list of blocks. Each block has a `kind`, `size` (line
count), and an intra-exchange `gap_before`; the exchange owns the leading gap
before its question. Positions are computed on demand from accumulated sizes
and gaps. Absolute line numbers are not retained after parser spans have been
compiled into this relative layout.

```
Exchange = {
    blocks = {
        { kind = "question",      size = 1, gap_before = 0 }, -- 💬:
        { kind = "agent_header",  size = 1, gap_before = 1 }, -- 🤖:
        { kind = "thinking",      size = 2 },   -- 🧠: semantic block
        { kind = "text",          size = 5 },   -- ordinary response text
        { kind = "tool_use",      size = 4 },   -- 🔧: + json fence
        { kind = "tool_result",   size = 10 },  -- 📎: + content fence
        { kind = "text",          size = 3 },   -- more response text
        { kind = "summary",       size = 1 },   -- 📝: semantic block
    }
}
```

## Layout Rules

1. Existing chats preserve the zero-, one-, or multi-line gaps implied by
   parser item spans; new live blocks default to one blank margin.
2. The exchange exclusively owns its leading gap. The question block owns no
   duplicate gap; later blocks own only intra-exchange gaps.
3. Empty blocks contribute neither size nor gap and remain invisible.
4. `exchange_total_size` excludes the exchange leading gap;
   `exchange_start` adds each leading gap exactly once.

## Lifecycle

The model is built once per `M.respond` call and lives through the entire response lifecycle:

- **Streaming**: ordinary writes reduce and replace only the current insertion
  block. A late `🧠:[END]` is the sole wider case: it reconciles only the
  recorded provisional thinking opener through the insertion block. Neither
  path reparses the chat.
- **Tool loop**: `add_block` appends 🔧:/📎: blocks. The model is passed to recursive `M.respond` calls — no rebuilding.
- **Pending presentation**: the current spinner/status is an extmark outside the model; see [Response Progress](response_progress.md). Legacy spinner block kinds remain tolerated by consumers.
- **Prompt append**: uses `exchange_total_size` to compute insertion point.
- **Folding**: live folds use the document index, independent of this model.

Because the model is live state, `chat_respond` protects every pending async write with a chat lease anchored on an `invalidate=true` extmark on the response's agent-header line (#138). The anchor distinguishes Parley-owned writes from structural edits: streaming and ordinary edits move the anchor (valid), while deleting the header — undo/redo or other structural drift — invalidates the pending response instead of reconciling the model against a changed serialized transcript. (Pre-#138 the lease keyed on `changedtick` and committed each Parley write's new tick; the extmark anchor makes that commit unnecessary.)

## Fold reconciliation

`tool_folds` consumes certified document projections. It no longer validates an
array of exchange extmarks or reparses the chat to recover layout. Ordinary body
edits preserve native folds; structural edits queue bounded projection queries.
Invalidation clears semantic folds whose context is uncertain. Only a complete,
confirmed plan can recreate affected native groups.
Manual folds before the first exchange remain outside Parley's owned region.
Window view, fold enablement, and open state survive application. Creation is
batched at 64 groups; beyond 50,000 affected rows cleanup is also batched with
fold display suspended until completion or cancellation.

See [document consumers](document.md#live-consumers) for paging and cost bounds.
`fold_projection` remains a materialized-model oracle for compatibility tests.

## Loading from Parser

`from_parsed_chat(parsed_chat)` builds a model from parser output. The shared
`answer_structure` reducer supplies semantic answer spans; the parser trims
leading/trailing blank lines from item content, while adjacent absolute spans
compile into relative gaps. Historical chats do not need canonical spacing.
Streaming performs the same compilation from its bounded active-segment
sections when replacing the insertion span.

## API

| Method | Purpose |
|--------|---------|
| `add_exchange(q_size, gap?)` | Add exchange with question block |
| `add_block(k, kind, size, gap?)` | Append block to exchange k |
| `grow_block(k, b, delta)` | Streaming grew the block |
| `set_block_size(k, b, size)` | Set exact size (e.g., spinner → 0) |
| `remove_block(k, b)` | Remove a block |
| `grow_question(k, delta)` | Question grew (e.g., raw_request_fence) |
| `block_start(k, b)` | 0-indexed line where block content starts |
| `block_end(k, b)` | 0-indexed last line of block |
| `last_nonempty_block_end(k)` | Last visible block line, or `nil` when none is visible |
| `append_pos(k)` | Where the next block would go |
| `exchange_start(k)` | Where exchange k begins |
| `exchange_total_size(k)` | Total lines in exchange k |

## Key Invariant

Materialized model positions describe their captured transcript. They cannot
authorize asynchronous writes or identify live exchanges after human edits; use
document identities and current grant resolution for that purpose.


## Folding verification corpus

`tests/integration/fold_invariants_spec.lua` exercises real Neovim fold state
over five dedicated `tests/fixtures/fold_*.md` transcripts: tool blocks,
assistant-first input, adversarial fences, markers inside prose fences, and
ordinary multi-exchange/model conversations. Both parsed-model and independent
raw-text oracles remain active. Workshop chats are not test fixtures; removing
or editing personal conversations does not change the test corpus.

## Question prefaces

A parsed exchange may own `preface = {line_start, line_end, content}` before its
question. Currently this is an immediately adjacent whole-line `@@…@@` tag.
The parser excludes it from the preceding component (including an unanswered
question), and rendering places it before the `💬:` line. Question starts remain
on their real markers. The live model stores only `preface = {size}` and derives
its span with `preface_start/end`, immediately before block1. Those rows are
already counted in `gap_before`; they are never counted twice in exchange size.

Context builders prepend the raw preface through `question_tags.compose_question`.
The initial request, tool continuation, ancestor context and branch topic request
use the same composition. Anonymous tags affect only outline visibility. Existing
file-reference syntax in a preface belongs to the following question, including
its retention/reference-loading policy. Regenerating the preceding answer leaves
the following preface outside the deleted span.

Exchange editing and scoped context use `question_tags.semantic_start(exchange)`
to include a preface. Cut, selection, paste and pruning share that ownership
boundary; question block positions remain anchored on the question marker.
