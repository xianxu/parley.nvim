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
- **`code_block_memo(lines, patterns, tildes)`** is the shared buffer scan; it
  tracks open/closed only, not fence WIDTH (that lives in the row state the
  render path builds), and accepts `~~~` only when `tildes` is passed.
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
| **prose (render)** | `highlight_structure` | any leading whitespace (`^%s*`), looser than CommonMark's 3-space limit; closer must be **at least** as long as its opener |

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

## The structure cache while typing (#227)

Decorations are computed on redraw from a buffer-owned structure
(`highlight_structure`), and that structure must line up with the buffer
row-for-row: the footer start, draft ranges and `state_before` are all
row-indexed.

- **Every edit is spliced.** `highlight_structure.replace` splices the edit's
  rows in and re-derives tokens, footer and drafts, so the cache never renders a
  misaligned structure. Fingerprint-identical edits share the old arrays;
  anything else costs one shallow O(n) copy (0.10 ms at 5,000 lines, `make perf`
  `structure_splice`).
- **Exact vs approximate.** A splice is exact when every touched row is inert —
  text, blank, fence, draft delimiter — and the first row below the edit is
  entered in the same state as before. That covers ordinary typing, Enter and
  joins. Turn markers, `📝`/`🔧`/`📎`, `🧠:`, `🧠:[END]` and footnotes can move
  state a splice cannot see; those leave the cache *approximate*.
- **Fail open.** The provider renders approximate structures. Its visible rows
  are walked from the actual lines, so what can lag is limited to `🧠:`
  lookahead (which can reach rows above the edit) and windows whose top is
  below the edit. Only a missing cache draws nothing.
- **One repair per burst.** An approximate cache arms a 250 ms deferral
  (`STRUCTURE_REPAIR_MS`); every further edit restarts it, and any successful
  rebuild — including the `buffer_lifecycle` convergence events — stops it. It
  repaints with `nvim__redraw({ buf, valid = false })`; `valid = true` re-runs
  `on_win` but redraws no lines of an unedited buffer (a guarded call: it is
  experimental API). Under the test harness (`$PARLEY_TEST_MODE`) no repair
  fires on its own; specs fire one by hand or opt into the real clock through
  `highlighter._set_repair_deferral` — see [infra/test_harness](../infra/test_harness.md).
- **Accounted.** Each splice reports its real work — rows classified/walked and
  `structure_entries_copied` — to the LineReader observer, and `make perf`
  gates it: a prose edit copies nothing, an Enter copies exactly two arrays.
- **Resync.** A splice that throws or no longer matches the buffer's line count
  (Nvim reports emptying a buffer as zero lines though one remains), and a
  `:checktime` reload (`on_reload` — without it Nvim detaches the attachment),
  rebuild synchronously; a cache that cannot be realigned is dropped rather
  than drawn.

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
