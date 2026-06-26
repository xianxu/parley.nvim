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

Structural markers (`📝/🔧/📎/💬/🤖/🌿/🔒`) always terminate either mode.

## Parser → Model Pipeline
`chat_parser.parse_chat` produces structured exchanges with `line_start`/`line_end` spans. `exchange_model.from_parsed_chat` converts these to size-based blocks. The parser trims leading/trailing blank lines from all components so the model's margins are the single source of truth.

## Excluded from LLM Context
`🔒:` local sections, `🌿:` branch links (full-line).

## Branch Link Parsing
First `🌿:` before first `💬:` = parent link. Subsequent = child branches with `after_exchange` count for context assembly.

## Validation
Path must be inside a configured chat root; filename must match `YYYY-MM-DD` pattern; header must contain `topic` and `file`.
