# Chat Format

## Header
- Front matter (`---` / `---`), legacy format also supported
- Required: `topic`, `file`
- Optional overrides: `model`, `provider`, `system_prompt`, `system_prompt+`, `tags`, `max_full_exchanges`, `raw_mode.show_raw_response`, `raw_mode.parse_raw_request`
- `role`/`role+` are aliases for `system_prompt`/`system_prompt+`
- `key+` = append to base key; `key` = replace; both present => replace then append

## Prefixes
- `💬:` user turn
- `🤖:` assistant turn (may include `[AgentName]`)
- `🔒:` local section — excluded from LLM context, ends at next `💬:`/`🤖:`
- `🌿:` branch link — excluded from LLM context, format: `🌿: file.md: topic`
- `🧠:` thinking line (within assistant answer)
- `📝:` summary line (within assistant answer, used by memory)

## Branch Links
- First `🌿:` after header = parent back-link
- Later `🌿:` lines = child branch forward-links
- `<C-g>i` (normal) inserts `🌿:` line; `<C-g>o` opens referenced chat

## Inline Branch Links
- Syntax: `[🌿:display text](file.md)` — appears inline within text
- LLM context: replaced with just `display text`
- Line containing inline link is NOT excluded (unlike full-line `🌿:`)
- `<C-g>i` (visual) wraps selection; `<C-g>o` navigates
- See `inline_branch_links.md` for details
