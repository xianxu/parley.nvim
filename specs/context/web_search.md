# Spec: Web Search

## Overview
Parley supports server-side web search for providers that offer it.

## Configuration
- `web_search`: Boolean to enable/disable by default.
- `:ParleyToggleWebSearch` (`<C-g>w`): Toggles web search in the current session.

## Provider Support
### Anthropic (Claude)
- Includes `web_search_20260209` and `web_fetch_20260209` tools.
- `x-api-key` and `anthropic-beta` headers MUST be updated.
- For `claude-haiku-4-5*`, web tools MUST include `allowed_callers: ["direct"]`.

### Google AI (Gemini)
- Includes the `google_search` tool in the request body.

### OpenAI
- OpenAI's current native tool type is `web_search` (Responses API).
- Parley's OpenAI adapter currently uses search-model swapping (Chat Completions path).
- The agent's model config MUST include a `search_model` attribute for OpenAI web search in Parley.

## UI Indicators
- Lualine displays `[w]` when active.
- If web search is enabled but unsupported by the agent, lualine MUST display `[w?]`.
