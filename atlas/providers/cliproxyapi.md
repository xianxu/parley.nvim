# CLIProxyAPI Provider

CLIProxyAPI lets Parley use models from several vendors through a local proxy.
The default endpoint is `http://127.0.0.1:8317/v1/chat/completions`; configure it
under `providers.cliproxyapi.endpoint`. The client token is
`api_keys.cliproxyapi` (`CLIPROXYAPI_API_KEY`, or `parley-local` by default).
Vendor account login is separate from this client token.

Use `:ParleyAgent` to select configured agents or models from the proxy's live
catalog. A model need not be listed in Parley's default agent roster. See
[managed proxy](cliproxy-managed.md) for installation, login, and process commands.

## Search strategy and tool routing

`providers.cliproxyapi.web_search_strategy` defaults to `openai_tools_route`.
Accepted values are `none`, `openai_search_model`, `openai_tools_route`, and
`anthropic_tools_route`. Set `agent.model.web_search_strategy` for an explicit
per-model override. A provider-level `none` disables the default search strategy.

Without a model override, Parley corrects the configured strategy for the model
family: Claude uses the Anthropic `/v1/messages` route; Gemini gets `none` for
server-side search. Other models normally use the OpenAI-compatible route.
The live catalog can also disable search for non-Claude models served through
Antigravity. `openai_search_model` requires an agent `search_model`.

Client-side file tools are a separate capability: the proxy's Anthropic and
OpenAI routes both have tool wires. Server-search support does not determine
whether a model can use those tools.

## Implementation and verification

- `lua/parley/providers.lua` — `cliproxy_strategy`, `cliproxy_route`, payloads, and family defaults.
- `lua/parley/tools/wire.lua` — matching client tool protocol.
- `lua/parley/cliproxy_catalog.lua` — catalog-derived agents.
- `tests/unit/tool_wire_registry_spec.lua`, `tests/unit/cliproxy_catalog_spec.lua`, `tests/integration/cliproxy_dispatch_spec.lua`.
