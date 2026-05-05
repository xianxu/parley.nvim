# Editable System Prompts

## Sources (highest precedence first)
- **Custom/Modified**: stored in `{state_dir}/custom_system_prompts.json`
- **Built-in**: from config defaults + `setup()` opts; deleting modified restores built-in

## Picker (`:ParleySystemPrompt`)
Supports edit (`<C-e>`), new (`<C-n>`), delete/restore (`<C-d>`), rename (`<C-r>`). Source tags: `[custom]`, `[modified]`, or none.

## Module
`lua/parley/custom_prompts.lua`: load/save/get/set/remove/rename

## Synthetic delivery (`synthetic_system_prompt`)
Per-agent opt-in flag. When `synthetic_system_prompt = true` on an agent
config, the system prompt is delivered as a leading user message + a
synthetic assistant ack ("Got it. I will follow this." by default,
overridable via `synthetic_system_prompt_ack`), instead of via the
provider's real system field. Compatibility shim for providers / models
that handle a real system role poorly.

For Anthropic, `cache_control: ephemeral` rides on the synthetic user
message's content block so cache-hit economics match the default mode.
For providers without `cache_control` feature, the user content stays a
plain string.

Wire-format only — the chat file on disk and the buffer model never see
the synthetic pair. Built by `lua/parley/system_prompt_msgs.lua` and
applied in `lua/parley/chat_respond.lua` (both the legacy
`_build_messages` path and the model-driven `build_messages_from_model`
path used by the tool loop).
