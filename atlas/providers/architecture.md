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
specs cover startup/abort behavior.
