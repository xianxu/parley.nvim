# OpenAI Provider

- Endpoint: `https://api.openai.com/v1/chat/completions` (customizable for Azure/local)
- Headers: `Authorization: Bearer <secret>`, `api-key: <secret>` (Azure)
- Payload: `model`, `stream: true`, `messages`, `temperature` [0,2], `top_p` [0,1], `max_tokens` (default 4096)
- Reasoning models (o1, o3, gpt-5): use `max_completion_tokens` instead, omit system messages for some, include `reasoning_effort`
- Content extraction: `choices[0].delta.content` from SSE `data:` lines
- Usage: `prompt_tokens`, `completion_tokens`
