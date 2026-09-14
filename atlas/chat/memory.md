# Chat Memory

## Config
- `chat_memory.enable`: toggle summarization (default `false`; the current chat's exchange window is retained in full when off)
- `chat_memory.max_full_exchanges`: number of recent full exchanges to keep when enabled (default `242`)
- `chat_memory.omit_user_text`: replacement text for summarized user messages

Ancestor context is assembled separately: available ancestor answer summaries
are used even when `chat_memory.enable` is false. Ancestors contribute exchanges
through each branch position, oldest ancestor first; see [chat lifecycle](lifecycle.md).

## Mechanism
- Exchanges beyond `max_full_exchanges` threshold: user message replaced with `omit_user_text`, assistant message replaced with `📝:` summary line content

## Preservation Rules (never summarized)
- Current question being sent
- Within most recent `max_full_exchanges`
- Questions containing `@@` file/directory references
- NOT image attachments (#231): they drop with their exchange on both
  builders, and the placeholder says an image was there

## Per-Chat Override
- Header `max_full_exchanges: <number>` overrides the global window while memory is enabled; setting the header alone does not enable summarization

## Cross-Chat Recall
- The `chat_history_search` tool searches configured chat roots allowed by the current request's root policy. A project request normally searches that project; `tool_read_roots` can grant additional roots. Finder discovery of global or sibling chats does not itself grant tool access. Use this when the user asks "do you remember when we talked about X?". Output paths are prefixed with `{<repo>}/...` so the agent can identify which repo each hit belongs to. See [Tool Use](../providers/tool_use.md).

## Implementation and checks

`lua/parley/chat_respond.lua` (`window_size`, `preserve_exchange`,
`build_messages`) owns retention; `lua/parley/config.lua` owns defaults.
`tests/unit/build_messages_spec.lua` covers message construction. Preference
profiles are a separate opt-in feature: [Memory Preferences](memory_prefs.md).

History-search scope is implemented by `lua/parley/tools/builtin/chat_history_search.lua`,
which filters configured roots through `tools/dispatcher.lua`
`resolve_read_path` using dispatcher-supplied context.
`tests/unit/tools_builtin_chat_history_search_spec.lua` covers project isolation,
explicit extra roots, escaping symlinks, and attempted model-supplied policy.
