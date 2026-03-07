# Spec: OpenAI Provider

## Overview
OpenAI's provider is the default for most agents.

## Endpoint
- Default: `https://api.openai.com/v1/chat/completions`.
- Customizable for Azure, LM Studio, or local endpoints.

## Payload Structure
- `model`: Model name string.
- `stream`: `true`.
- `messages`: List of `{role, content}` objects.
- `temperature`: Clamped to `[0, 2]`.
- `top_p`: Clamped to `[0, 1]`.
- `max_tokens`: Configurable; defaults to `4096`.

### Reasoning Models (o1, o3, gpt-5)
- MUST use `max_completion_tokens`.
- System messages MUST be omitted for some models (e.g., `o1`).
- `reasoning_effort` MUST be included (e.g., `"low"`, `"medium"`, `"high"`).

## Headers
- `Authorization: Bearer <secret>`.
- `api-key: <secret>` (for Azure compatibility).

## Content Extraction
- Extracts from `choices[0].delta.content` in each SSE `data:` line.
- Usage metrics: `prompt_tokens`, `completion_tokens`.
