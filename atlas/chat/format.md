# Chat Format

## Header
Front matter (`---`/`---`) with `topic`, `file` (required) and optional overrides (`model`, `provider`, `system_prompt`, `tags`, etc.). `role`/`role+` are aliases for `system_prompt`/`system_prompt+`. `key+` appends; `key` replaces.

## Prefixes
- `💬:` user turn
- `🤖:` assistant turn (may include `[AgentName]`)
- `🔒:` local section — excluded from LLM context
- `🌿:` branch link — excluded from LLM context
- `🧠:` thinking, `📝:` summary (within assistant answer). The thinking block opens on a `🧠:` line and may span multiple lines. Termination is per-block: if a `🧠:[END]` line appears before the next structural marker, blank lines inside the block are content and only `🧠:[END]` (or a structural marker — `📝:`, `🔧:`, `📎:`, `💬:`, `🤖:`, `🌿:`, `🔒:`) terminates. Otherwise the first blank line terminates (legacy single-line convention back-compat). Stored as `exchange.reasoning.content`; the `🧠:[END]` marker is preserved verbatim in the buffer but excluded from `reasoning.content`. Multiple `🧠:` blocks within one answer (e.g. plan → tool round → reflect → answer) accumulate into a single `reasoning.content` string separated by blank lines; `reasoning.line` stays anchored to the first opener.
- `🔧:` tool_use, `📎:` tool_result (within assistant answer, client-side tool-use loop — #81). Body is a dynamic-length fenced block (≥3 backticks, longer than any run in the content). Single source of truth for the schema: `lua/parley/tools/serialize.lua`.

## Branch Links
- First `🌿:` after header = parent back-link; later ones = child forward-links
- `<C-g>i` inserts link; `<C-g>o` navigates
- Inline variant: `[🌿:text](file.md)` — see `inline_branch_links.md`
