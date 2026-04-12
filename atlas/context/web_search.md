# Web Search

## Config
- `web_search`: boolean toggle (default off)
- `:ParleyToggleWebSearch` / `<C-g>w`: session toggle

## Provider Support
Anthropic (tool-based), Google AI (`google_search` tool), OpenAI (search-model swapping). CLIProxyAPI routes to appropriate strategy per model family.

## UI
- Lualine: `[w]` when active, `[w?]` if unsupported by agent
- In-buffer animated spinner and progress line during search/reasoning, cleared on completion
- All providers normalize progress events to a shared shape (`kind`, `phase`, `message`)
