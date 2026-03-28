# Web Search

## Config
- `web_search`: boolean toggle (default off)
- `:ParleyToggleWebSearch` / `<C-g>w`: session toggle

## Provider Details

**Anthropic**: `web_search_20260209` + `web_fetch_20260209` tools. Haiku models need `allowed_callers: ["direct"]`.

**Google AI (Gemini)**: `google_search` tool in request body.

**OpenAI**: Uses search-model swapping (Chat Completions path). Agent model config MUST have `search_model` attribute. Progress parsing supports Chat Completions streaming deltas (`tool_calls`, `reasoning_content`) and Responses-style item events (`web_search_call`).

## Progress Normalization
- All providers normalize to shared shape: `kind` (reasoning/tool_start/tool_update/tool_result), `phase`, `message`, optional `text`

## UI
- Lualine: `[w]` when active, `[w?]` if unsupported by agent
- In-buffer animated spinner (`🔎 <spinner> Submitting...`) before first tokens
- Spinner animates locally (timer-driven), independent of SSE events
- Progress line updates from SSE tool/reasoning signals (e.g. `Searching web...`, `Reasoning...`, live text deltas)
- Anthropic streams: `content_block_start` types (`tool_use`, `server_tool_use`, `web_search_tool_result`, `web_fetch_tool_result`) are progress signals; unknown tool types get generic message
- OpenAI: unknown tools map to `Running <tool>...`
- cliproxy OpenAI-route reuses OpenAI progress parsing
- Progress line stays visible while streaming, updates even after answer text starts, clears on completion
