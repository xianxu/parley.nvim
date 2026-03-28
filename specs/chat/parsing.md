# Chat Parsing

## Buffer Sections
- **Header**: front matter (`---`/`---`) or legacy (lines before first `---`)
- **Transcript**: everything after header closing separator

## Turn Detection
- `💬:` starts user turn, ends at next `🤖:` or EOF
- `🤖:` starts assistant turn, ends at next `💬:` or EOF

## Special Lines (within assistant answer)
- `🧠:` thinking (single line)
- `📝:` summary (single line, used by memory)

## Excluded from LLM Context
- `🔒:` local sections
- `🌿:` branch links (full-line)

## Branch Link Parsing
- First `🌿:` before first `💬:` => `parent_link = { path, topic, line }`
- Subsequent `🌿:` => `branches[] = { path, topic, line, after_exchange }`
- `after_exchange`: number of preceding exchanges (for context assembly)

## Validation
- Path must be inside a configured chat root
- Filename must match `YYYY-MM-DD` pattern
- Header must contain `topic` and `file`
