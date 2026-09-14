# Web Search

Web search lets a supported model retrieve current information while answering.
It is enabled by default (`web_search = true`); a saved toggle in `state.json`
takes precedence on later starts. `:ParleyToggleWebSearch` or `<C-g>w` changes
that saved state. The toggle does not guarantee that the model will search on
every response.

## Provider behavior

| Provider | How search is requested | Limitation |
|---|---|---|
| Anthropic | Server-side `web_search` and `web_fetch` tools | Model-specific overrides come from `provider_params.lua` |
| Google AI | `google_search` grounding tool | Separate from client-side file tools, which have no Google AI wire |
| OpenAI | Swap to the agent model's `search_model` | Enabling search requires that configured model variant |
| CLIProxyAPI | Resolve the configured strategy for the model family | Claude uses the Anthropic route; Gemini defaults to no server search; explicit model overrides take precedence |

Enabling search on an unsupported agent reports an error. When search is already
enabled and the agent changes, the badge indicates whether the new agent supports
it: `🌎` for supported, `🌎?` for unsupported, no badge when disabled. Badges appear
with the agent name in the picker, chat header, and lualine.

Chat responses use the shared [response progress](../chat/response_progress.md)
extmark: initial silence gets a delayed activity line, followed by meaningful
search/reasoning status when available. This display does not alter the transcript.
Non-chat callers retain their own progress display.

## Implementation and verification

- `lua/parley/config.lua`, `init.lua` (`ToggleWebSearch`, `refresh_state`) — defaults, validation, persistence.
- `lua/parley/providers.lua`, `provider_params.lua` — provider payloads and model-specific strategy.
- `lua/parley/highlighter.lua` (`agent_web_search_badge`), `lualine.lua` — shared indicators.
- `tests/unit/provider_params_spec.lua`, `tests/unit/keybindings_spec.lua`, `tests/unit/build_messages_spec.lua` — configuration and request behavior.
- [CLIProxyAPI](../providers/cliproxyapi.md) — proxy strategy configuration.
