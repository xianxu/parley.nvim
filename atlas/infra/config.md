# Configuration

## Merge Order (low to high priority)
1. Plugin defaults (`lua/parley/config.lua`)
2. `setup(opts)`
3. Per-chat header metadata for supported request fields

`hooks`, `agents`, `system_prompts` are key-merged (partial overrides OK). Everything else is replaced wholesale.

## Key Concepts
- `chat_dir`: primary writable chat dir (always first, not removable)
- `chat_roots`: additional roots with labels; `chat_dirs` is legacy alias
- Recency presets for chat and note finders: configurable month windows + cycle
- `web_search_strategy`: per-provider and per-agent override
- Runtime chat-root changes persist in `state_dir/state.json`

## Application versus plugin configuration

The [release configuration map](starter.md) owns the two entry points, current
policy differences and regression checks. The app passes
`starter_config.options(roots)` to the same `setup(opts)` used by plugin users.
`defaults.lua` supplies runtime constants and fallback templates rather than a
separate complete configuration merged before `config.lua`. Provider credentials
and provider definitions have dedicated setup handling; do not assume every
option follows generic table replacement.

The app and plugin share portable product defaults: the answer-style prompt and
📝 summaries, web search and all registered tools are enabled; automatic memory
generation is disabled. The app supplies editor/bootstrap and storage differences.
Cursor-follow during streaming defaults to on; an existing saved preference
takes precedence. `Ctrl+g l` toggles it.
Personal chat/notes and blog export paths live in the user's Neovim configuration.
OAuth credentials use the same explicit `~/.cli-proxy-api` directory.
