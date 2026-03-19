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
- OpenAI progress parsing MUST support both:
  - Chat Completions streaming tool deltas (`choices[].delta.tool_calls`)
  - Chat Completions reasoning deltas (`choices[].delta.reasoning_content`)
  - Responses-style item events (`response.output_item.*` with `web_search_call`)
- Provider progress parsing MUST normalize to a shared shape consumed by UI:
  - `kind` (`reasoning`, `tool_start`, `tool_update`, `tool_result`)
  - `phase` (`reasoning`, `tooling`)
  - `message` (human-readable in-buffer cue)
- `text` (optional raw streamed progress text, e.g. reasoning/thinking deltas)

## UI Indicators
- Lualine displays `[w]` when active.
- If web search is enabled but unsupported by the agent, lualine MUST display `[w?]`.
- During `:ParleyChatRespond`, when web search is enabled, the pending assistant area MUST show an in-buffer animated placeholder spinner line (`🔎 <spinner> Submitting...`) before first response tokens.
- The spinner MUST animate locally (timer-driven) even when no new SSE events arrive.
- If provider SSE includes tool progress signals, the in-buffer progress line MUST update accordingly, including switching from the placeholder cue to tool-specific text such as `Searching web...`.
- If provider SSE includes reasoning signals, the in-buffer progress line SHOULD show a reasoning cue (e.g. `Reasoning...`) until tool or answer phases replace it.
- When reasoning `text` deltas are available, the in-buffer cue SHOULD surface that live text (not only generic event type labels).
- When tool progress `text` deltas are available (e.g. tool arguments/query/url), the in-buffer cue SHOULD also surface that live text.
- Anthropic/Anthropic-route streams MUST treat `content_block_start` tool-related types as progress signals, including known types such as:
  - `tool_use`
  - `server_tool_use`
  - `web_search_tool_result`
  - `web_fetch_tool_result`
- For unknown tool-like `content_block.type` values, the UI SHOULD still show a generic progress message using that type string.
- OpenAI tool progress parsing SHOULD map unknown tool names to a generic `Running <tool>...` message.
- For cliproxy OpenAI-route streams, progress parsing SHOULD reuse OpenAI progress parsing so reasoning/tooling cues are not dropped.
- The in-buffer progress line MUST remain visible while the response is still streaming, even if answer text has already started.
- If later tool-progress SSE arrives after answer text, the in-buffer progress line MUST continue updating until the response completes.
- The in-buffer progress line MUST clear automatically when the query completes or exits.
