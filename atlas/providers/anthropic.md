# Anthropic Provider

Configure `api_keys.anthropic` (defaults to `ANTHROPIC_API_KEY`) and select an
Anthropic agent. The default streaming endpoint is
`https://api.anthropic.com/v1/messages`, configurable under
`providers.anthropic.endpoint`.

System messages become a top-level system block list, preserving cache-control
annotations. Client-side file tools use the Anthropic tool wire. With web search
enabled, Parley adds server-side `web_search` and `web_fetch` tools; model-specific
tool parameters are resolved by `provider_params.lua`.

Claude model names default to `max_tokens = 64000` in Parley's parameter schema.
This is an output budget, including thinking tokens, and can be overridden in
the agent model configuration. See [response endings](architecture.md) when a
reply stops because that budget was exhausted.

Images become base64 image content blocks before the question text. Parley's
shared limits are 10 MiB per image, 20 image occurrences per request, and a
20 MiB final request budget (10,485,760 and 20,971,520 bytes respectively).
MiB means 1,048,576 bytes. These are plugin limits; repeated links count as
separate occurrences. Unsupported or omitted images produce transcript-context
notes rather than invalid image blocks.

## Implementation and verification

- `lua/parley/providers.lua` (`anthropic.format_payload`), `provider_params.lua` — payload and tool parameters.
- `lua/parley/assets.lua` — attachment validation and shared budgets.
- `tests/unit/anthropic_tool_wire_spec.lua`, `tests/unit/provider_params_spec.lua`, `tests/unit/wire_images_spec.lua`, `tests/unit/assets_spec.lua`.
