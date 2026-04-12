# Chat Format

## Header
Front matter (`---`/`---`) with `topic`, `file` (required) and optional overrides (`model`, `provider`, `system_prompt`, `tags`, etc.). `role`/`role+` are aliases for `system_prompt`/`system_prompt+`. `key+` appends; `key` replaces.

## Prefixes
- `💬:` user turn
- `🤖:` assistant turn (may include `[AgentName]`)
- `🔒:` local section — excluded from LLM context
- `🌿:` branch link — excluded from LLM context
- `🧠:` thinking, `📝:` summary (within assistant answer)
- `🔧:` tool_use, `📎:` tool_result (within assistant answer, client-side tool-use loop — #81). Body is a dynamic-length fenced block (≥3 backticks, longer than any run in the content). Single source of truth for the schema: `lua/parley/tools/serialize.lua`.

## Branch Links
- First `🌿:` after header = parent back-link; later ones = child forward-links
- `<C-g>i` inserts link; `<C-g>o` navigates
- Inline variant: `[🌿:text](file.md)` — see `inline_branch_links.md`
