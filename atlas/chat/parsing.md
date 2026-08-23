# Chat Parsing

## Buffer Sections
- **Header**: front matter (`---`/`---`) or legacy format
- **Transcript**: everything after header

## Turn Detection
`💬:` starts user turn, `🤖:` starts assistant turn. Within assistant answers: `🧠:` (thinking — multi-line, opens on `🧠:`), `📝:` (summary, single line), `🔧:` (tool call), `📎:` (tool result). All are tracked as blocks in the [exchange model](exchange_model.md).

### Thinking-block termination

The parser decides termination mode per-block at open time by looking ahead from the `🧠:` line:

- **Explicit-end mode** — if a `🧠:[END]` line appears before the next structural marker, blank lines inside the block are part of the reasoning content and only `🧠:[END]` (or a structural marker) terminates. This is the mode for chats whose system prompt requests `🧠:[END]` — custom prompts, or back-compat (the shipped default dropped the `🧠:` thinking-block protocol in #143, so default-prompt chats no longer emit `🧠:` at all). Where a prompt does request it, an explicit closer is more reliable than a blank-line terminator, since Claude is reluctant to suppress blank lines in reasoning.
- **Legacy mode** — otherwise, the first blank line terminates the block (back-compat with chats authored under the previous single-line `🧠:` convention).

Structural markers (`📝/🔧/📎/💬/🤖/🌿/🔒`) terminate either mode, with one
exception that `lua/parley/fence.lua` owns — see its docstrings for the grammar
itself; this page states only which markers the rule covers.

**A tool body may not span a column-0 structural marker** (#203) —
`📝/🔧/📎/💬/🤖/🌿/🔒`, the set named in `highlight_structure.STRUCTURAL_KINDS`.
See `atlas/providers/tool_use.md` for the rule and the producer-side invariant
it depends on.

**Tool markers only.** A `🔧:`/`📎:` is structural only at fence depth 0:

- inside a **tool body** (the fenced block opening on the line right after such
  a marker) it is content, because tool output routinely quotes transcripts;
- inside **any other fenced block** it is also not a tool marker, which is what
  stops that block's closer being read as a body opener.

**Everything else stays fence-naive.** A `💬:` or `🤖:` inside a plain
```` ```text ```` block still starts a turn. That is a deliberate non-goal
recorded in the #200 plan, not an oversight: suppressing there would need a
general markdown block model rather than a fence pair.

`fence.scan` makes the one depth-aware pass; `chat_parser`, `answer_structure`
and `fold_projection` all consume it.

## Parser → Model Pipeline
`answer_structure.reduce` is the one semantic answer grammar. It produces
`text`, `thinking`, `summary`, `tool_use`, and `tool_result` spans for both
`chat_parser.parse_chat` and bounded streaming reconciliation.

`chat_parser.parse_chat` still owns full transcript/exchange parsing and the
backward-compatible `content_blocks`; it also attaches semantic spans that
`exchange_model.from_parsed_chat` converts to size-based blocks. Initial load
parses the transcript once. Streaming normally reduces only the insertion block;
when a later `🧠:[END]` resolves a provisional legacy blank, it reduces exactly
that opener-through-terminator span and no earlier line.

## Excluded from LLM Context
`🔒:` local sections, `🌿:` branch links (full-line).

## Branch Link Parsing
First `🌿:` before first `💬:` = parent link. Subsequent = child branches with `after_exchange` count for context assembly.

## Validation
Path must be inside a configured chat root; filename must match `YYYY-MM-DD` pattern; header must contain `topic` and `file`.
