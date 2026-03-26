# Spec: Chat Format

## Overview
The chat transcript is a Markdown-compatible file with specific conventions for marking turns, metadata, and special content.

## File Header Section
Every chat file MUST contain a header section before the transcript body.
Preferred format is Markdown front matter (`---` opening + `---` closing). Legacy header style remains supported for existing files.

### Required Fields
- `topic: <topic>`
- `file: <filename>`

### Optional Configuration Overrides
The header MAY contain YAML-like keys to override global configurations for the specific chat:
- `model: <string|json>`: Model parameters.
- `provider: <provider_name>`: LLM provider.
- `system_prompt: <system_prompt>`: System prompt (newlines escaped as `\n`).
- `system_prompt+: <system_prompt_suffix>`: Append text to the resolved system prompt (`system_prompt+` MAY be repeated; entries apply in order).
- `role` / `role+`: Backward-compatible aliases for `system_prompt` / `system_prompt+`.
- `tags: <space_or_comma_separated_tags>`: Tags for organization.
- `max_full_exchanges: <number>`: Memory threshold override.
- `raw_mode.show_raw_response: <boolean>`: Display raw JSON response.
- `raw_mode.parse_raw_request: <boolean>`: Parse user JSON as request.

### Append Syntax (`key+`)
- Header keys ending with `+` MUST be treated as append directives for the base key.
- Repeated `key+` entries MUST be preserved and applied in file order.
- `key` remains replace semantics; if both `key` and `key+` are present, Parley MUST apply replacement first, then append values.

## Conversation Prefixes
The plugin uses specific markers to distinguish between roles and special content.

| Prefix | Default | Role/Purpose |
|---|---|---|
| `chat_user_prefix` | `💬:` | User's question |
| `chat_assistant_prefix`| `🤖:` | Assistant's answer |
| `chat_local_prefix` | `🔒:` | Local section (ignored by LLM) |
| `chat_branch_prefix` | `🌿:` | Chat tree link (parent or child; ignored by LLM) |
| `thinking_prefix` | `🧠:` | Assistant's internal reasoning |
| `summary_prefix` | `📝:` | Summary of the exchange (for memory) |

### Assistant Prefix with Agent
The assistant prefix line may include an agent identifier: `🤖: [AgentName]`.

## Local Sections
- Lines starting with `🔒:` begin a local section.
- Content in these sections is excluded from the context sent to the LLM.
- A local section ends when the next user or assistant prefix is encountered. This algorithm is greedy.

## Chat Branch Links (`🌿:`)
- Lines starting with `🌿:` are chat tree links with the format: `🌿: filename.md: topic`.
- **First transcript line** (immediately after the header `---`): back-link to parent chat.
- **Anywhere in body**: forward link to a child chat branch.
- `🌿:` lines are excluded from LLM context and preserved across answer regeneration (like `🔒:`).
- `<C-g>i` in a chat buffer inserts a new `🌿:` line; `<C-g>o` on a `🌿:` line opens the referenced chat.
