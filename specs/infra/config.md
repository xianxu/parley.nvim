# Configuration

## Merge Order (low to high priority)
1. Defaults (`lua/parley/defaults.lua`)
2. Global config (`lua/parley/config.lua`)
3. `setup(opts)`
4. Per-chat header metadata

## Merge Behavior at `setup()`
- **Key-merged**: `hooks`, `agents`, `system_prompts` (partial overrides OK)
- **Replace-on-set**: everything else (full table replacement)
  - `api_keys`, `providers`, `raw_mode`, `highlight`, `chat_memory` -- replaced wholesale if provided

## Key Config Fields
- `chat_dir`: primary writable chat dir (always first in root list, not removable)
- `chat_roots`: structured root metadata (`dir` + `label`); de-duped, tilde-expanded
- `chat_dirs`: additional chat roots (legacy); normalized with `chat_dir`
- `notes_dir`: notes storage
- `chat_free_cursor`: default cursor-follow behavior (toggleable at runtime)

## Chat Finder Recency
- `chat_finder_recency.months` / `.presets`: default window + cycle presets before `All`
- `chat_finder_mappings`: `move` (`<C-x>`), `next_recency`, `previous_recency`

## Note Finder Recency
- `note_finder_recency.months` / `.presets`: same pattern
- `note_finder_mappings`: `delete` (`<C-d>`), `next_recency`, `previous_recency`
- `global_shortcut_note_finder`: default `<C-n>f`

## Web Search Strategy
- `providers.cliproxyapi.web_search_strategy`: `none` | `openai_search_model` | `openai_tools_route` | `anthropic_tools_route`
- `agent.model.web_search_strategy`: per-agent override, takes precedence

## Directory Prep & Runtime State
- Dirs created at `setup()` if missing; tilde expanded
- Runtime chat-root changes persist in `state_dir/state.json` and override setup-time list on restart
