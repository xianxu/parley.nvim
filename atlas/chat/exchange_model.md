# Exchange Model

The exchange model (`lua/parley/exchange_model.lua`) is the single source of truth for buffer layout. All position queries — where to insert, where to fold, where to read content — go through the model.

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
- **Spinner**: tracked as a block; set to size 0 when cleared.
- **Prompt append**: uses `exchange_total_size` to compute insertion point.
- **Folding**: `thinking`, `summary`, `tool_use`, and `tool_result` ranges come
  only from their stated model block spans and stay inside the selected
  exchange. Gaps are never projected as folds.

Because the model is live state, `chat_respond` protects every pending async write with a chat lease anchored on an `invalidate=true` extmark on the response's agent-header line (#138). The anchor distinguishes Parley-owned writes from structural edits: streaming and ordinary edits move the anchor (valid), while deleting the header — undo/redo or other structural drift — invalidates the pending response instead of reconciling the model against a changed serialized transcript. (Pre-#138 the lease keyed on `changedtick` and committed each Parley write's new tick; the extmark anchor makes that commit unnecessary.)

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

Any feature needing buffer positions MUST use the model. Never scan lines, use `foldlevel()`, `last_content_line()`, or backward lookups. The model already knows.
