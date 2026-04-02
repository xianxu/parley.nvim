# Chat Parsing

## Buffer Sections
- **Header**: front matter (`---`/`---`) or legacy format
- **Transcript**: everything after header

## Turn Detection
`💬:` starts user turn, `🤖:` starts assistant turn. Special lines within assistant: `🧠:` (thinking), `📝:` (summary).

## Excluded from LLM Context
`🔒:` local sections, `🌿:` branch links (full-line).

## Branch Link Parsing
First `🌿:` before first `💬:` = parent link. Subsequent = child branches with `after_exchange` count for context assembly.

## Validation
Path must be inside a configured chat root; filename must match `YYYY-MM-DD` pattern; header must contain `topic` and `file`.
