# Editable System Prompts

## Sources (highest precedence first)
- **Custom/Modified**: stored in `{state_dir}/custom_system_prompts.json` (JSON map: `name -> {system_prompt: "..."}`)
- **Built-in**: from `config.lua` defaults + user `setup()` opts; cannot be deleted (deleting modified restores built-in)

## Data Model (init.lua)
- `M._builtin_system_prompts` — read-only snapshot after config merge
- `M.system_prompts` — active = builtins merged with custom overrides
- `M._system_prompts` — sorted name list

## Module
- `lua/parley/custom_prompts.lua`: load/save/get/set/remove/rename

## Picker Actions
- `<C-e>`: Edit in scratch buffer (`parley://system_prompt/{name}`, buftype=acwrite, ft=markdown)
- `<C-n>`: New custom prompt
- `<C-d>`: Delete custom / restore modified to default / no-op for pure builtins
- `<C-r>`: Rename custom/modified / no-op for pure builtins
- Source tags in picker: `[custom]`, `[modified]`, or none (pure built-in)
