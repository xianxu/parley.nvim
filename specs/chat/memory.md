# Chat Memory

## Config
- `chat_memory.enable`: toggle summarization
- `chat_memory.max_full_exchanges`: number of recent full exchanges to keep
- `chat_memory.omit_user_text`: replacement text for summarized user messages

## Mechanism
- Exchanges beyond `max_full_exchanges` threshold: user message replaced with `omit_user_text`, assistant message replaced with `📝:` summary line content

## Preservation Rules (never summarized)
- Current question being sent
- Within most recent `max_full_exchanges`
- Questions containing `@@` file/directory references

## Per-Chat Override
- Header `max_full_exchanges: <number>` overrides global config
