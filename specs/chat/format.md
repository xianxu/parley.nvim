# Spec: Chat Format

## Overview
The chat transcript is a Markdown-compatible file with specific conventions for marking turns, metadata, and special content.

## File Header Section
Every chat file MUST contain a header section before the first `---` separator.

### Required Fields
- `# topic: <topic>`: The first line of the file. 
- `- file: <filename>`: Within the first 10 lines.

### Optional Configuration Overrides
The header MAY contain YAML-like keys to override global configurations for the specific chat:
- `- model: <string|json>`: Model parameters.
- `- provider: <provider_name>`: LLM provider.
- `- role: <system_prompt>`: System prompt (newlines escaped as `\n`).
- `- tags: <space_separated_tags>`: Tags for organization.
- `- max_full_exchanges: <number>`: Memory threshold override.
- `- raw_mode.show_raw_response: <boolean>`: Display raw JSON response.
- `- raw_mode.parse_raw_request: <boolean>`: Parse user JSON as request.

## Conversation Prefixes
The plugin uses specific markers to distinguish between roles and special content.

| Prefix | Default | Role/Purpose |
|---|---|---|
| `chat_user_prefix` | `💬:` | User's question |
| `chat_assistant_prefix`| `🤖:` | Assistant's answer |
| `chat_local_prefix` | `🔒:` | Local section (ignored by LLM) |
| `thinking_prefix` | `🧠:` | Assistant's internal reasoning |
| `summary_prefix` | `📝:` | Summary of the exchange (for memory) |

### Assistant Prefix with Agent
The assistant prefix line may include an agent identifier: `🤖: [AgentName]`.

## Local Sections
- Lines starting with `🔒:` begin a local section.
- Content in these sections is excluded from the context sent to the LLM.
- A local section ends when the next user or assistant prefix is encountered. This algorithm is greedy.
