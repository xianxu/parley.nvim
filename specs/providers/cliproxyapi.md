# CLIProxyAPI Provider

- Endpoint: `http://127.0.0.1:8317/v1/chat/completions` (OpenAI-compatible)
- For Claude/`code_execution_*` models: can rewrite to `/api/provider/anthropic/v1/messages`
- Headers: `Authorization: Bearer <secret>` (secret name: `cliproxyapi`)
- Payload: same as OpenAI-compatible; reuses model overrides (o* reasoning, gpt-5* max_completion_tokens)

## Web Search Strategy (`providers.cliproxyapi.web_search_strategy`)
- `none` (default): unsupported
- `openai_search_model`: swap to `search_model` variant
- `openai_tools_route`: keep model, add `tools` (`web_search`) to payload
- `anthropic_tools_route`: for `claude-*`/`code_execution_*`, emit Anthropic tools (`web_search`, `web_fetch`) via Anthropic endpoint
  - Sets `allowed_callers = ["direct"]` on web tools
  - `code_execution_*` models force `tool_choice` to `web_search`
- Per-model override: `agent.model.web_search_strategy`
- Status: `[w]` = enabled+supported, `[w?]` = enabled but unavailable

## Default Agents
- Includes proxy-backed variants for all built-in models so users can switch without manual duplication
