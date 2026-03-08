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
- `chat_dir`, `notes_dir`: Storage directories.
- `api_keys`: Table of API secrets.
- `providers`: List of LLM backends.
- `agents`, `system_prompts`: Active sets for chats.
- `hooks`: Custom user-defined commands.

## Selective Merging
- Tables like `hooks`, `agents`, and `system_prompts` MUST be merged by key to allow partial overrides of default sets.
- `setup()` options MUST take priority over global config values.

## Directory Preparation
- Directories specified in configuration MUST be prepared (created if they don't exist) during `setup()`.
