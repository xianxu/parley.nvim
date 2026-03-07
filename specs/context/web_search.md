# Spec: Web Search

## Overview
Parley supports server-side web search for providers that offer it.

## Configuration
- `web_search`: Boolean to enable/disable by default.
- `:ParleyToggleWebSearch` (`<C-g>w`): Toggles web search in the current session.

## Provider Support
### Anthropic (Claude)
- Includes `web_search_20250305` and `web_fetch_20250910` tools.
- `x-api-key` and `anthropic-beta` headers MUST be updated.

### Google AI (Gemini)
- Includes the `google_search` tool in the request body.

### OpenAI
- Supported via search model variants (e.g., `gpt-4o-search-preview`).
- The agent's model config MUST include a `search_model` attribute.

## UI Indicators
- Lualine displays `[w]` when active.
- If web search is enabled but unsupported by the agent, lualine MUST display `[w?]`.
