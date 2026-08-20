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
  exchange. Gaps are never projected as folds. See *Fold reconciliation* below
  for how that projection is applied.

Because the model is live state, `chat_respond` protects every pending async write with a chat lease anchored on an `invalidate=true` extmark on the response's agent-header line (#138). The anchor distinguishes Parley-owned writes from structural edits: streaming and ordinary edits move the anchor (valid), while deleting the header — undo/redo or other structural drift — invalidates the pending response instead of reconciling the model against a changed serialized transcript. (Pre-#138 the lease keyed on `changedtick` and committed each Parley write's new tick; the extmark anchor makes that commit unnecessary.)

## Fold reconciliation

`tool_folds` is the only module that creates or deletes folds. Since #200 it
treats `fold_projection`'s output as a **desired state**, not an append list —
three properties follow:

- **Parley owns every fold within an exchange span.** Reconciling clears the
  whole span before recreating the projected folds, so a fold the projection no
  longer wants cannot survive. This includes a manual `zf` the operator made
  inside an exchange: it is deleted on the next reconcile. Folds outside every
  exchange span are untouched. (Operator-decided contract change, 2026-08-20;
  previously only folds at projected start rows were removed, which meant a
  drifted fold survived for the rest of the session.)
- **What gets created is verified; what gets cleared is identified.** The two
  halves are guarded differently because they fail differently.
  - *Creation*: each fold range must anchor on its own marker line and cover no
    question, checked against the buffer (`fold_projection.verify_anchors`).
  - *Destruction*: the rows an exchange owns come from `exchange_anchors` —
    one `invalidate = true` extmark per exchange start, in the manner
    `chat_lease` anchors the streaming insertion point (#138). Marks travel
    with edits, so the span is right even when the model's remembered rows are
    not. A row-span is not an identity: positional rules ("starts on a
    question, contains no other") are satisfied equally by a *different*
    exchange's rows, which is how a drifted reconcile could delete a
    neighbour's folds.
  - Identity declines rather than guesses when the anchor count disagrees with
    the model's exchange count (a structural edit re-indexed the exchanges), or
    when either bounding mark's line was deleted. The positional check
    (`verify_span`) remains only as the fallback floor for those cases, and its
    question-anchor requirement is waived for exchange 1, because `chat_parser`
    fabricates a question block for an assistant-first transcript and that path
    can produce no other index.
- **Drift heals once, then refuses.** If verification fails, the model is
  re-derived from the buffer and rechecked. If it still does not verify, no
  fold is created rather than a wrong one, and the refusal is logged at debug
  with which half drifted — a silently unfolded exchange is otherwise
  indistinguishable from one with nothing to fold.

Clearing walks fold-to-fold (`zj`/`zD` in a single VimL crossing) rather than
probing every row, because `chat_respond` wraps every streamed chunk in
`with_exchange_update`: the clear is on the per-chunk path and must scale with
the number of folds present, not with exchange length.

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
