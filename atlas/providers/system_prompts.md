# Editable System Prompts

## Sources (highest precedence first)
- **Custom/Modified**: stored in `{state_dir}/custom_system_prompts.json`
- **Built-in**: from config defaults + `setup()` opts; deleting modified restores built-in

## Picker (`:ParleySystemPrompt`)
Supports edit (`<C-e>`), new (`<C-n>`), delete/restore (`<C-d>`), rename (`<C-r>`). Source tags: `[custom]`, `[modified]`, or none.

## Module
`lua/parley/custom_prompts.lua`: load/save/get/set/remove/rename
