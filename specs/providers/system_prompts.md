# Spec: Editable System Prompts

## Overview
System prompts define the LLM's persona and behavior. They come from two sources: built-in defaults (from config) and user customizations (persisted on disk). User customizations override built-in prompts with the same name.

## Sources & Precedence
1. **Built-in**: Defined in `config.lua` defaults and user `setup()` opts. Cannot be deleted.
2. **Custom**: User-created prompts stored in `{state_dir}/custom_system_prompts.json`. Can be freely created, edited, renamed, and deleted.
3. **Modified**: A built-in prompt that has been edited by the user. Stored in the custom file. Deleting restores the built-in default.

Precedence: custom/modified overrides built-in with same name.

## Storage
- File: `{state_dir}/custom_system_prompts.json`
- Format: JSON map of `name → { "system_prompt": "..." }`
- Module: `lua/parley/custom_prompts.lua` handles load/save/get/set/remove/rename

## Data Model (init.lua)
- `M._builtin_system_prompts` — snapshot of prompts after config merge (read-only reference)
- `M.system_prompts` — active prompts = builtins merged with custom overrides
- `M._system_prompts` — sorted list of active prompt names

## Picker UI
- Title shows available action keys
- Source indicator: `[custom]` or `[modified]` shown after prompt name; pure builtins have no tag
- Picker actions (control-key mappings):
  - `<C-e>`: Edit — opens prompt in a scratch buffer
  - `<C-n>`: New — prompts for name, creates custom prompt, opens editor
  - `<C-d>`: Delete/Restore — deletes custom prompts; restores modified builtins to default; no-op for pure builtins
  - `<C-r>`: Rename — renames custom/modified prompts; no-op for pure builtins

## Edit Buffer
- Opens as `parley://system_prompt/{name}` with `buftype=acwrite`
- Filetype: `markdown`
- Save (`BufWriteCmd`) writes content to `custom_system_prompts.json` and refreshes in-memory state
