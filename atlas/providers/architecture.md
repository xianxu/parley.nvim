# Provider Architecture

Choose a provider through the selected agent; configure its endpoint under
`providers` and credentials under `api_keys`. Parley streams responses through
`curl` subprocesses. Authentication or startup failures abort the caller's
request and release its pending UI state; HTTP success alone does not mean a
usable answer arrived.

## Request and response flow

`dispatcher.prepare_payload` is the shared request boundary. Provider adapters
format messages, parameters, headers, and streaming response events. Client-side
tool encoding and decoding go through the [tool wire registry](tool_use.md).
CLIProxyAPI chooses an Anthropic or OpenAI-compatible route from the model and
search strategy.

OpenAI-compatible adapters do not all delegate to `openai.format_payload`:
CLIProxyAPI and Ollama build their own payloads, while Copilot and Azure delegate.
Cross-provider behavior therefore belongs at the dispatcher boundary rather than
inside just the OpenAI adapter. `lua/parley/sse.lua` supplies shared SSE/JSON
primitives.

### Chat response ownership

`chat_respond` captures submission intent and delegates to `response_session`.
The Session composes guarded preparation, `response_provider`, `response_tools`,
and pending presentation. Provider callbacks deliver bytes and round outcomes to
`response_runner`; they hold no saved buffer ranges. The runner applies output
through current Document grants, so disjoint human edits proceed in the same
buffer; sibling generations run concurrently but write one at a time under the
document's write turn (see [write ownership](../chat/ownership.md)).

`response_provider` freezes decoded tool declarations from a successful response.
`response_tools` runs a round's tools as soon as it is declared, renders the
call and result blocks the generation machine writes one at a time in declared
order (`tools/sequence.lua`), then builds the next request from captured messages
and settled results. It does not
reparse the live buffer or recursively submit a new chat. See the
[tool loop model](tool_use.md#loop-model) for limits and producer outcomes.

Cancellation stops admission before cleanup completes. Each provider operation
has its own Tasker owner, and stopping one owner does not stop sibling responses.
Process exit alone is not completion: process and pipe cleanup, or an explicit
startup abort, provide the evidence that releases the operation. A zero-match
stop can still mean asynchronous readiness is pending. Tool producers likewise
must report positive cleanup before their round continues. An unknown effect is
written as an error result and the round goes on, while its resources stay
quarantined until reconciled (see [tool execution](tool_execution.md)).

Automatic topic generation uses a separate header grant and captured parent
marker guards. It collects output without buffer writes, then replaces the
bounded `?` suffix only after successful completion and cleanup. Answer success
can leave that independent topic operation active; invalidation cancels it.

Query diagnostics live in the dispatcher's cache `query_dir`. Setup prunes an
oversized store; explicit per-chat logs are described in [raw mode](../modes/raw_mode.md).

## When an answer is empty or stops early

The dispatcher classifies endings as `done`, `cap`, `filtered`, `error`, or
`unknown`, then produces the corresponding notice. An in-band error takes
precedence over stop-reason classification. Recognized normal endings remain
quiet; unrecognized endings after visible text produce a warning. An empty
response without a reason follows the separate empty-response diagnosis.

| Function in `dispatcher.lua` | Responsibility |
|---|---|
| `_extract_stop_reason` | Read Anthropic `stop_reason`, OpenAI `finish_reason`, or Google `finishReason` |
| `_inband_error` | Detect stream errors even after HTTP 200 |
| `_classify_ending` | Choose one ending category |
| `_is_output_cap`, `_is_normal_finish` | Classify known reason values |
| `_ending_notice` | Format the notice and severity |

Model parameters are resolved by `provider_params.lua`. Claude names default to
`max_tokens = 64000`, whether reached directly or through CLIProxyAPI. Thinking
can consume that budget before visible answer text appears. This model-specific
default does not raise the limit for every model behind the same provider.

## Verification

`tests/unit/empty_response_reason_spec.lua` covers classifications and provider
reason spellings; `tests/unit/provider_params_output_cap_spec.lua` covers output
budgets; `tests/unit/providers_pre_query_spec.lua` and the CLIProxyAPI integration
specs cover startup/abort behavior. Native `response_provider_spec.lua`,
`response_session_spec.lua`, and `response_topic_spec.lua` integration tests
exercise scoped ownership and positive cleanup with fake processes.
