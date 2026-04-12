# Chat Parsing

## Buffer Sections
- **Header**: front matter (`---`/`---`) or legacy format
- **Transcript**: everything after header

## Turn Detection
`💬:` starts user turn, `🤖:` starts assistant turn. Within assistant answers: `🧠:` (thinking), `📝:` (summary), `🔧:` (tool call), `📎:` (tool result). All are tracked as blocks in the [exchange model](exchange_model.md).

## Parser → Model Pipeline
`chat_parser.parse_chat` produces structured exchanges with `line_start`/`line_end` spans. `exchange_model.from_parsed_chat` converts these to size-based blocks. The parser trims leading/trailing blank lines from all components so the model's margins are the single source of truth.

## Excluded from LLM Context
`🔒:` local sections, `🌿:` branch links (full-line).

## Branch Link Parsing
First `🌿:` before first `💬:` = parent link. Subsequent = child branches with `after_exchange` count for context assembly.

## Validation
Path must be inside a configured chat root; filename must match `YYYY-MM-DD` pattern; header must contain `topic` and `file`.
