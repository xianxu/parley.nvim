# Spec: Configuration System

## Overview
Parley's configuration system allows for global, per-plugin, and per-chat settings.

## Merging Logic
Configuration is merged in the following order (lowest to highest priority):
1. **Defaults**: Hardcoded in `lua/parley/defaults.lua`.
2. **Global Config**: Set in `lua/parley/config.lua`.
3. **Setup Options**: Passed to `require('parley').setup(opts)`.
4. **Per-Chat Headers**: Header metadata in individual `.md` chat files.

At `setup()` time, merge behavior is intentionally mixed:
- **Key-merged tables**: `hooks`, `agents`, and `system_prompts` MUST merge by key/name so callers can override subsets.
- **Replace-on-set keys**: Other top-level keys from `opts` MUST overwrite defaults as full values.

Notable replace-on-set behavior:
- `api_keys`: if provided in `opts`, only provided keys are loaded into vault for this setup call.
- `providers`: if provided in `opts`, that table is used for dispatcher setup; omitted providers are not automatically backfilled from defaults.
- Nested config tables like `raw_mode`, `highlight`, and `chat_memory` are replaced as full tables when provided in `opts`.

## Configuration Areas
- `chat_dir`: Primary writable chat directory used for new chats and default state markers.
- `chat_roots`: Optional structured chat-root metadata, where each root can declare a `dir` and user-facing `label`.
- `chat_dirs`: Optional additional chat roots scanned by chat-aware features alongside `chat_dir`.
- `notes_dir`: Notes storage directory.
- `api_keys`: Table of API secrets.
- `providers`: List of LLM backends.
- `agents`, `system_prompts`: Active sets for chats.
- `hooks`: Custom user-defined commands.
- `chat_free_cursor`: Default cursor-follow behavior (runtime state toggle can override).

### Chat Finder Recency
- `chat_finder_recency.months`: Default filtered month window when Chat Finder opens in recent mode.
- `chat_finder_recency.presets`: Additional month cutoffs that Chat Finder cycles through before `All`.
- `chat_finder_mappings.move`: Picker-local shortcut (default `<C-r>`) for moving the selected chat to another registered chat root.
- `chat_finder_mappings.next_recency` and `chat_finder_mappings.previous_recency`: Picker-local shortcuts for moving left toward smaller cutoffs or right toward larger cutoffs and `All`.

### Note Finder Recency
- `global_shortcut_note_finder`: Global shortcut for `:ParleyNoteFinder` (default `<C-n>f` in normal and insert modes).
- `note_finder_recency.months`: Default filtered month window when Note Finder opens in recent mode.
- `note_finder_recency.presets`: Additional month cutoffs that Note Finder cycles through before `All`.
- `note_finder_mappings.delete`: Picker-local shortcut (default `<C-d>`) for deleting the selected note.
- `note_finder_mappings.next_recency` and `note_finder_mappings.previous_recency`: Picker-local shortcuts for moving left toward smaller cutoffs or right toward larger cutoffs and `All`.

### Provider-Specific Keys
- `providers.cliproxyapi.web_search_strategy`:
  - `none` (default), `openai_search_model`, `openai_tools_route`, or `anthropic_tools_route`.
  - Controls whether web-search is unavailable, uses search-model swapping, uses OpenAI-style tool injection, or uses Anthropic-style tool routing for Claude/code_execution models.
- `agent.model.web_search_strategy`:
  - Optional per-agent/per-model override for CLIProxyAPI strategy.
  - If set, it takes precedence over `providers.cliproxyapi.web_search_strategy`.

## Selective Merging
- Tables like `hooks`, `agents`, and `system_prompts` MUST be merged by key to allow partial overrides of default sets.
- `setup()` options MUST take priority over global config values.

## Directory Preparation
- Directories specified in configuration MUST be prepared (created if they don't exist) during `setup()`.
- `chat_dir` MUST remain the first entry in the normalized chat root list.
- `chat_dirs` MUST be normalized into a de-duplicated list of prepared directories that includes `chat_dir`.
- `chat_roots` MUST normalize into a de-duplicated metadata list where the first root is the primary root and every root has a resolved directory path plus a user-facing label.
- Tilde-prefixed root paths MUST be expanded before directory creation or persistence.

## Runtime Overrides
- Runtime chat-root changes made through Parley commands or UI MUST persist in `state_dir/state.json`.
- Persisted `chat_roots` metadata MUST override the setup-time chat-root list on later startups when present.
- Persisted `chat_dirs` MUST override the setup-time chat-root list on later startups.
- The primary `chat_dir` MUST NOT be removable through runtime management commands or UI.
