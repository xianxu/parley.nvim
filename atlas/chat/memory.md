# Chat Memory

## Config
- `chat_memory.enable`: toggle summarization (default `false`; the current chat's exchange window is retained in full when off)
- `chat_memory.max_full_exchanges`: number of recent full exchanges to keep when enabled (default `242`)
- `chat_memory.omit_user_text`: replacement text for summarized user messages
- `chat_memory.side_chats`: `"summary"` (default) or `"full"`; how side chats off the path to the root are sent, whether or not `enable` is on (#352)

Tree-of-chat context is not assembled separately (#233). The request's
exchanges are the chat tree linearized in depth-first order, ancestors and
asides included. The window spans the path to the root: the current file and
its ancestors. Under `side_chats = "summary"`, a side chat (an aside, or a chat
nested under one) is off the path: each of its exchanges is sent as its `📝:`
summary in the summarized form, or, without one, as its question alone,
truncated to 300 characters and marked. It is outside the window and never
pinned in full, and its `@@` references are neither fetched nor inlined. Under
`"full"`, side chats are counted and rendered like any exchange. With memory
disabled, every exchange on the path is sent in full; see [chat lifecycle](lifecycle.md).

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
