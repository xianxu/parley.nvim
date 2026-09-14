# Agents

An agent combines a provider, model, and system prompt. `:ParleyAgent` opens the
picker; `:ParleyAgent NAME` selects a named agent. `<C-g>a` or
`:ParleyNextAgent` cycles the configured selection. The selection is stored in
`state_dir/state.json`; a configured `default_agent` can override it at setup.

A chat's `provider:` and `model:` headers override the selected agent for that
chat's requests. Changing the picker selection does not remove those headers;
remove or edit them when you want that chat to follow the new selection.

The picker selects a provider/model, not a particular saved vendor account.
Parley does not offer a selector between two already-connected accounts of the
same provider or a proxy-account logout command. The running proxy owns account
routing; its credential diagnosis is not a guarantee of which account a later
successful request will use. See [account management limits](cliproxy-managed.md#account-management-limits).

## Configured and live agents

`config.lua`'s `agents` list defines the shipped roster. Agent fields include
`name`, `provider`, `model` (name or parameter table), `system_prompt`, `disable`,
and `tools`. An absent/empty tool list gives no client-side tools; `@all` and
`@readonly` expand through the [tool registry](tool_use.md). The tool protocol
supports Anthropic and OpenAI families, including the corresponding CLIProxyAPI
routes. Direct Google AI has no client tool wire.

The picker also displays a live CLIProxyAPI catalog. Choosing a model registers
an agent named `<id>*`, with `@all` tools and a family-appropriate search
strategy, and persists its catalog data as `state.json.live_agent`. The chosen
model moves into the registered roster so it is not shown twice. `<C-a>` toggles
the full catalog beyond configured filters and per-provider curation. A logged-out
provider row starts login. See [managed proxy](cliproxy-managed.md) for catalog
refresh, provider filters, and login behavior.

The agent header, picker, and lualine share the same badges: `🔧` for enabled
tools, `🌎` for supported enabled search, `🌎?` for enabled but unsupported
search. Tool-loop defaults are `max_tool_iterations = 42` and
`tool_result_max_bytes = 102400`; individual agents can override them.

## Implementation and verification

- `lua/parley/config.lua`, `agent_picker.lua`, `agent_info.lua` — roster, selection UI, chat overrides.
- `lua/parley/init.lua` (`refresh_state`, `register_live_agent`), `cliproxy_catalog.lua` — persistence and live selection.
- `lua/parley/highlighter.lua` — `agent_tool_badge`, `agent_web_search_badge`.
- `tests/unit/live_agent_state_spec.lua`, `tests/unit/tool_wire_registry_spec.lua`, `tests/unit/keybindings_spec.lua`.
