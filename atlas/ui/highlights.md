# Spec: Syntax Highlighting

## Highlight Groups
Custom groups (`ParleyQuestion`, `ParleyFileReference`, `ParleyChatReference`, `ParleyThinking`, `ParleyAnnotation`, `ParleyReference`, `ParleyFootnote`, `ParleyPickerApproximateMatch`, `InterviewTimestamp`, `InterviewThought`) linked to standard Neovim groups. `ParleyReference` (default underline) marks drill-in `[referenced span]` brackets — see [chat/drill_in](../chat/drill_in.md). `ParleyFootnote` (default `DiagnosticHint`) marks managed definition-footnote footer lines.

## Exchange partitions contain fence state (#218)

`💬:` / `🤖:` / `🔒:` / `🌿:` at **column zero** are hard partitions: any open
code fence ends there. Without this, one unmatched ``` from a model renders
every later exchange as code — the boundary was already tracked for
`in_question` and `in_reasoning`, and `in_code` was simply left out of it.

- **One transition function.** `highlight_structure.advance(state, token, len)`
  applies a row's token; `reset_partition(state, token)` clears what a boundary
  terminates. The builder and `highlighter`'s per-window walk both call them —
  `highlighter` previously kept a byte-identical private copy that drifted.
- **Phase is deliberate.** `reset_partition` runs BEFORE the row's snapshot (a
  `💬:` line is not itself inside code, so `state_before[that row]` must already
  be clean); `advance` runs after, matching the convention that
  `state_before[row]` is the state *entering* the row. Collapsing the two
  inverts the fence delimiter's own render.
- **`is_partition(line, patterns)`** is exported for consumers that keep their
  own lightweight fence walks — `outline` (two of them) and the review skill —
  so "what is a partition" has one definition, not four.
- **The fence fingerprint carries its width** (`c3`, `c4`). `M.replace`'s
  per-keystroke fast path keys on fingerprint equality and reuses `state_before`
  verbatim, so a single `fence` token for every width let an in-place width edit
  serve stale state for the rest of the buffer.

### Two fence grammars, deliberately separate

| | grammar | rule |
|---|---|---|
| **tool bodies** | `lua/parley/fence.lua` | no leading whitespace; closes only on an **exactly equal** run, so a body may contain shorter fences |
| **prose (render)** | `highlight_structure` | CommonMark: up to 3 spaces of indent; closer must be **at least** as long as its opener |

`fence.lua` is not the canonical prose grammar and adopting it would silently
stop recognising indented fences.

### The two-space indentation convention

A turn marker written flush-left inside a fence now reads as a turn — that is
the cost of positional containment. The default chat system prompt
(`lua/parley/defaults.lua`) therefore asks the model to indent every fenced
block by **exactly two spaces** (never four: four makes it an indented code
block and the ``` markers become literal). Because the partition patterns are
anchored at column zero, indented content never matches, so a correctly
formatted quoted transcript still nests. Both shapes are pinned by tests, so the
convention degrades safely when a model ignores it.

## Key Behaviors
- Applied via decoration providers with ephemeral extmarks per window viewport
- Multi-window safe: independent redraw cache per window
- Managed definition-footnote footers (from the first `[^id]: ...` line) use
  `ParleyFootnote` in chat and markdown buffers instead of inheriting the active
  chat exchange color.
- `🌿:` lines auto-rendered with debounced topic lookup from referenced files
- `chat_conceal_model_params`: optional header param concealment
- UTC timestamps shaped like `YYYY-MM-DDTHH:MM:SSZ` get local-time INFO
  diagnostics in Parley chat and markdown buffers. The pure parser/formatter
  lives in `lua/parley/timezone_diagnostics.lua`; `highlighter.setup_buf_handler`
  refreshes its separate diagnostic namespace on buffer enter/window enter and
  text changes. Its namespace renders review-style virtual lines for the current
  line and uses the concise message `local time: <converted local time>`. The
  buffer text is never rewritten.
