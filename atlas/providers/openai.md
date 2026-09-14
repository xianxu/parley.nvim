# OpenAI Provider

Configure `api_keys.openai` (defaults to `OPENAI_API_KEY`) and select an agent
whose `provider` is `openai`. Requests stream through the Chat Completions
endpoint, `https://api.openai.com/v1/chat/completions`, configurable at
`providers.openai.endpoint`. An empty provider table disables that provider.

Client-side tools use the OpenAI tool wire. Web search uses the agent model's
`search_model` variant when the shared web-search toggle is on; ordinary models
are not automatically replaced with an inferred search model.

## Request behavior

- Messages, including system messages, pass into the request. For a compatibility
  alternative, see [synthetic system prompts](system_prompts.md).
- `provider_params.lua` applies model-specific parameters. The o1/o3/o4 families
  default to `max_completion_tokens = 4096` and `reasoning_effort = "low"`, without
  temperature/top_p. GPT-5 names map `max_tokens` to `max_completion_tokens` and
  also omit temperature/top_p. Explicit supported model parameters can override defaults.
- Images become Chat Completions `image_url` parts with base64 data URLs and
  `detail = "auto"`; text-only messages remain strings. Shared plugin image
  budgets are enforced before sending, rather than inferred from the endpoint.

## Implementation and verification

`lua/parley/providers.lua` (`openai.format_payload`), `provider_params.lua`,
`tools/wire_openai.lua`, and `assets.lua` own these behaviors.
`tests/unit/provider_params_spec.lua`, `tests/unit/wire_images_spec.lua`, and
`tests/unit/tool_wire_registry_spec.lua` cover parameters and wire shapes.
