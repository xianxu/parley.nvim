# Google AI Provider

Configure `api_keys.googleai` (defaults to `GOOGLEAI_API_KEY`) and select a
`googleai` agent. The default endpoint is Google's `streamGenerateContent`
route; `providers.googleai.endpoint` contains `{{model}}` and `{{secret}}`
placeholders, expanded into the URL.

The adapter maps system messages to user messages and assistant messages to the
`model` role, then merges adjacent messages of the same role. Generation
parameters come from `provider_params.lua`. When web search is enabled it adds
Google's `google_search` grounding tool.

Direct Google AI has no client-side function-tool wire in Parley. Agents that
need file tools or editing skills must use a supported wire; Google search
support alone does not supply that capability.

Image parts use `{inlineData={mimeType, data}}`; merging messages preserves the
whole parts list. Shared image validation and the 20 MiB (20,971,520-byte) final request budget
are enforced by `assets.lua`.

## Implementation and verification

`lua/parley/providers.lua` (`googleai.format_payload`), `provider_params.lua`,
`tools/wire.lua`, and `assets.lua` define this behavior. See
`tests/unit/wire_images_spec.lua`, `tests/unit/provider_params_spec.lua`, and
`tests/unit/tool_wire_registry_spec.lua`.
