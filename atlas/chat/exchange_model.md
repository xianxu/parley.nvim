# Exchange Model

The exchange model (`lua/parley/exchange_model.lua`) is the single source of truth for buffer layout. All position queries — where to insert, where to fold, where to read content — go through the model.

## Core Principle: Everything Is a Block

An exchange is a flat list of blocks. Each block has a `kind` and `size` (line count). Positions are computed on demand from accumulated sizes. No absolute line numbers are stored.

```
Exchange = {
    blocks = {
        { kind = "question",      size = 1 },   -- 💬:
        { kind = "agent_header",  size = 1 },   -- 🤖:
        { kind = "text",          size = 5 },   -- response text (may contain 🧠:, 📝:)
        { kind = "tool_use",      size = 4 },   -- 🔧: + json fence
        { kind = "tool_result",   size = 10 },  -- 📎: + content fence
        { kind = "text",          size = 3 },   -- more response text
    }
}
```

## Layout Rules

1. **1 blank margin** between adjacent non-empty blocks.
2. **Empty blocks (size 0) cancel one margin** — invisible in layout.
3. **1 blank margin** between exchanges.
4. **Header** occupies `header_lines` at the top, followed by 1 margin.

## Lifecycle

The model is built once per `M.respond` call and lives through the entire response lifecycle:

- **Streaming**: `on_lines_changed` callback calls `grow_block` to keep the streaming section's size current.
- **Tool loop**: `add_block` appends 🔧:/📎: blocks. The model is passed to recursive `M.respond` calls — no rebuilding.
- **Spinner**: tracked as a block; set to size 0 when cleared.
- **Prompt append**: uses `exchange_total_size` to compute insertion point.
- **Folding**: `apply_folds` reads block positions from the model.

## Loading from Parser

`from_parsed_chat(parsed_chat)` builds a model from parser output. The parser trims leading/trailing blank lines from all components (questions, answers, sections) so the model's margins are the single source of truth for gaps.

## API

| Method | Purpose |
|--------|---------|
| `add_exchange(q_size)` | Add exchange with question block |
| `add_block(k, kind, size)` | Append block to exchange k |
| `grow_block(k, b, delta)` | Streaming grew the block |
| `set_block_size(k, b, size)` | Set exact size (e.g., spinner → 0) |
| `remove_block(k, b)` | Remove a block |
| `grow_question(k, delta)` | Question grew (e.g., raw_request_fence) |
| `block_start(k, b)` | 0-indexed line where block content starts |
| `block_end(k, b)` | 0-indexed last line of block |
| `append_pos(k)` | Where the next block would go |
| `exchange_start(k)` | Where exchange k begins |
| `exchange_total_size(k)` | Total lines in exchange k |

## Key Invariant

Any feature needing buffer positions MUST use the model. Never scan lines, use `foldlevel()`, `last_content_line()`, or backward lookups. The model already knows.
