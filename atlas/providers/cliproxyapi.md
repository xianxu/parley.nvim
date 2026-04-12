# CLIProxyAPI Provider

Local OpenAI-compatible proxy (`127.0.0.1:8317`) for multi-vendor models. For Claude/`code_execution_*` models, can rewrite to Anthropic endpoint.

## Web Search Strategy (`providers.cliproxyapi.web_search_strategy`)
- `none` (default), `openai_search_model`, `openai_tools_route`, `anthropic_tools_route`
- Per-model override via `agent.model.web_search_strategy`
- Includes proxy-backed default agents for all built-in models
