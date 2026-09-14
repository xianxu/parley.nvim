# Chat Format

## Header
Chats are editable Markdown files. The header uses `---` delimiters and
single-line `key: value` fields; the legacy `# topic:`/`- file:` header is also
readable. `topic` and `file` are required for chat recognition. Optional fields
include `model`, `provider`, `system_prompt`, and `tags`. `role`/`role+` alias
`system_prompt`/`system_prompt+`; `key+` appends and `key` replaces.

```markdown
---
topic: Learning Parley
file: welcome.md
tags: tutorial, getting-started
---

💬: What can I do here?
```

Tags are separated by commas or whitespace **on the same line**. YAML block
lists (`tags:` followed by `- tutorial`) and bracketed YAML lists are not
supported by this parser. Use simple tags without spaces. Chat Finder shows
`[tutorial]` beside the topic and offers a tag filter bar; `[]` means untagged.
Save changes before reopening the finder. Keep metadata and the closing header
separator within the first ten lines: finder discovery reads only that prefix.

Chat recognition requires a configured chat root and a dated Markdown filename,
or one of the stable tutorial names `welcome.md`, `basics.md`, `advanced.md`.
See [parsing](parsing.md) for the validation boundary.

## Prefixes
- `💬:` user turn
- `🤖:` assistant turn (may include `[AgentName]`)
- `🔒:` local note — a SINGLE line, withheld from the LLM context (#214)
- `🌿:` branch link — excluded from LLM context
- `🧠:` thinking, `📝:` summary (within assistant answer). `🧠:` blocks appear only when the system prompt requests them (custom or back-compat prompts — the shipped default dropped the `🧠:` protocol in #143, keeping `📝:`); the parser still handles `🧠:` whenever present. The thinking block opens on a `🧠:` line and may span multiple lines. Termination is per-block: if a `🧠:[END]` line appears before the next structural marker, blank lines inside the block are content and only `🧠:[END]` (or a structural marker — `📝:`, `🔧:`, `📎:`, `💬:`, `🤖:`, `🌿:`, `🔒:`) terminates. Otherwise the first blank line terminates (legacy single-line convention back-compat). Stored as `exchange.reasoning.content`; the `🧠:[END]` marker is preserved verbatim in the buffer but excluded from `reasoning.content`. Multiple `🧠:` blocks within one answer (e.g. plan → tool round → reflect → answer) accumulate into a single `reasoning.content` string separated by blank lines; `reasoning.line` stays anchored to the first opener.
- `🔧:` tool_use, `📎:` tool_result (within assistant answer, client-side tool-use loop — #81). Body is a dynamic-length fenced block (≥3 backticks, longer than any run in the content). Single source of truth for the *schema*: `lua/parley/tools/serialize.lua`; for the *fence grammar* (open/close/selection; markers inside a body are content when PREFIXED, which is how the content-echoing tools emit them; a column-0 marker bounds the body instead, #203 — note `🧠:` is not in that set, so a column-0 reasoning marker is still content): `lua/parley/fence.lua`, from which serialize and the other consumers derive (#200 M2, see `providers/tool_use.md`).

## Branch Links
- First `🌿:` before the first user question = parent back-link; other branch references are child forward-links
- `<M-i>` (legacy `<C-g>i`) creates and opens a sub-chat in a chat buffer; `<M-o>` / `<C-g>o` navigates a reference
- Inline variant: `[🌿:text](file.md)` — see `inline_branch_links.md`

## Attachments (#231)
- A line that is exactly `![…](assets/<chat-timestamp>/<file>.<png|jpg|jpeg|gif|webp>)`
  inside a question is an attachment (sent to the model); anywhere else, or
  in any other form, it is prose. See [Chat Attachments](attachments.md).

## Implementation and checks

`lua/parley/chat_parser.lua` owns header/tag parsing and filename recognition;
`lua/parley/init.lua` (`not_chat`) validates chat buffers. See
`tests/unit/parse_chat_spec.lua` and `tests/unit/chat_finder_records_spec.lua`.
