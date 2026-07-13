# Web Search

## Config
- `web_search`: boolean toggle (default off)
- `:ParleyToggleWebSearch` / `<C-g>w`: session toggle

## Provider Support
Anthropic (tool-based), Google AI (`google_search` tool), OpenAI (search-model swapping). CLIProxyAPI routes to appropriate strategy per model family.

## UI
- Lualine: `[w]` when active, `[w?]` if unsupported by agent
- Chat-producing LLM legs use the shared [response-progress](../chat/response_progress.md) extmark: a delayed playful line covers initial silence, then meaningful search/reasoning status replaces it without changing transcript text
- Web search does not own a buffer-backed initial spinner; non-chat web-enabled calls keep the progress surface of their caller (for example Definition's selection spinner or Document Review's detached luabar)
- All providers normalize semantic progress events to a shared shape (`kind`, `phase`, `message`); raw transport activity is a separate callback used only for playful verb timing
