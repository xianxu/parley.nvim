# Anthropic Provider

- Endpoint: `https://api.anthropic.com/v1/messages`
- Headers: `x-api-key: <secret>`, `anthropic-version: 2023-06-01`, `anthropic-beta: messages-2023-12-15` or `web-fetch-2025-09-10`
- Payload: `model`, `stream: true`, `messages`, `system` (array of content blocks, extracted separately), `max_tokens` (default 4096), `temperature` [0,1], `top_p` [0,1]
- Web search tools (when active): `web_search` (type `web_search_20260209`), `web_fetch` (type `web_fetch_20260209`)
  - `claude-haiku-4-5*` MUST set `allowed_callers: ["direct"]` on both
- Content extraction: `delta.text` and `content_block.text` from SSE
- Usage: `input_tokens`, `output_tokens`, `cache_read_input_tokens`
