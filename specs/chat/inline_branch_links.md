# Inline Branch Links

## Syntax
- `[🌿:display text](file.md)` — inline within any line (vs full-line `🌿:` on its own line)

## Creation (`<C-g>i`)
- **Visual mode** (chat + markdown): wraps selection as `[🌿:selected text](new-file.md)`, creates child chat with topic `what is "selected text"`
- **Normal mode** (chat + markdown): inserts full-line `🌿: <path>: ` and enters insert mode for topic
- **Insert mode** (markdown): exits insert, then behaves as normal mode
- Child gets `🌿:` parent back-link; no auto topic inference (topic is not `?`)

## Parser
- Detected by `parse_chat`, added to `parsed.branches` with `{ path, topic, line, after_exchange }`
- Context unpacking: `[🌿:text](file)` => `text` in LLM context
- Containing line is NOT excluded (unlike full-line `🌿:`)
- Multiple inline links per line supported

## Navigation
- `<C-g>o` on inline link opens referenced file

## Export
- HTML: `<a href="child.html" class="branch-inline">display text</a>`
- Jekyll: `<a href="{% post_url slug %}" class="branch-inline">display text</a>`

## Edge Cases
- Missing file: rendered as plain text in export; `<C-g>o` warns
- Preserved across answer regeneration
- Included in tree traversal and collision detection
