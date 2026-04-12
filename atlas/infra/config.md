# Configuration

## Merge Order (low to high priority)
1. Defaults (`lua/parley/defaults.lua`)
2. Global config (`lua/parley/config.lua`)
3. `setup(opts)`
4. Per-chat header metadata

`hooks`, `agents`, `system_prompts` are key-merged (partial overrides OK). Everything else is replaced wholesale.

## Key Concepts
- `chat_dir`: primary writable chat dir (always first, not removable)
- `chat_roots`: additional roots with labels; `chat_dirs` is legacy alias
- Recency presets for chat and note finders: configurable month windows + cycle
- `web_search_strategy`: per-provider and per-agent override
- Runtime chat-root changes persist in `state_dir/state.json`
