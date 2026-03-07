# Spec: Chat Memory

## Overview
Parley manages large chat histories by replacing older conversation turns with their summaries, reducing token usage while maintaining context.

## Configuration
- `chat_memory.enable`: Boolean to enable/disable summarization.
- `chat_memory.max_full_exchanges`: Number of recent full exchanges to preserve.
- `chat_memory.omit_user_text`: Text used to represent summarized user messages.

## Summarization Mechanism
- Exchanges beyond `max_full_exchanges` are substituted in the LLM payload.
- The user's message is replaced by `omit_user_text`.
- The assistant's message is replaced by the content of the summary line (`📝:`) from the transcript.

## Preservation Rules
An exchange MUST be preserved in full (NOT summarized) if:
1. It is the current question being sent.
2. It is within the most recent `max_full_exchanges`.
3. The question contains `@@` file or directory references.

## Per-Chat Override
The `max_full_exchanges` threshold can be overridden per chat file via the header:
`- max_full_exchanges: <number>`
This header value MUST take precedence over the global configuration.
