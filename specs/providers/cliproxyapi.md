# Spec: CLIProxyAPI Provider

## Overview
CLIProxyAPI is an OpenAI-compatible proxy provider that can route requests to multiple upstream model vendors through a single local endpoint and credential.

## Endpoint
- Default: `http://127.0.0.1:8317/v1/chat/completions`.
- Uses standard OpenAI Chat Completions request/response streaming format.
- For Claude and `code_execution_*` models, Parley can optionally route through CLIProxyAPI's Anthropic-compatible endpoint by rewriting to `/api/provider/anthropic/v1/messages`.

## Payload Structure
- Same schema as OpenAI-compatible providers.
- `model`: upstream target model name.
- `stream`: `true`.
- `messages`: list of `{role, content}` objects.
- `temperature`: clamped to `[0, 2]`.
- `top_p`: clamped to `[0, 1]`.
- `max_tokens` defaults to `4096` unless model overrides apply.

### Model Overrides
- Existing model overrides are reused:
  - `o*` reasoning models remove unsupported sampling params.
  - `gpt-5*` maps `max_tokens` to `max_completion_tokens`.
  - search model variants can be selected when web search mode is enabled.

## Web Search Strategy
- `providers.cliproxyapi.web_search_strategy` controls how web search is handled:
  - `none` (default): web search is treated as unsupported for this provider.
  - `openai_search_model`: OpenAI-style model swap to `search_model` when web search is ON.
  - `openai_tools_route`: keep base model and send OpenAI-compatible `tools` (`web_search`) in Chat Completions payload.
  - `anthropic_tools_route`: for `claude-*` and `code_execution_*` models, Parley emits Anthropic `tools` (`web_search`, `web_fetch`) and routes via Anthropic-compatible endpoint.
    - For CLIProxy compatibility, Parley sets `allowed_callers = ["direct"]` on web tools when chat web search is ON.
    - For `code_execution_*` models, Parley additionally sets `tool_choice` to force `web_search`.
- Per-model override: set `agent.model.web_search_strategy` to override provider default for that specific agent/model.
- Status indicators:
  - `[w]` when web search is enabled and supported for the selected strategy/model.
  - `[w?]` when chat-level web search is ON but unavailable for the selected strategy/model.

## Headers
- `Authorization: Bearer <secret>`.

## Secrets
- Secret name is `cliproxyapi`.
- Default key source: `api_keys.cliproxyapi` (typically `CLIPROXYAPI_API_KEY`).

## Default Agent Coverage
- Default config includes proxy-backed agent variants for every built-in default model so users can switch to CLIProxyAPI without manual agent duplication.
