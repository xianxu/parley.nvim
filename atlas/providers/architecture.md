# Provider Architecture

- Transport: `curl` subprocess (no Lua HTTP deps). OpenAI-compatible adapters share payload format and SSE parsing; differ in headers/endpoints. Note that "OpenAI-compatible" does not mean "delegates to `openai.format_payload`": cliproxyapi's openai route (`cliproxy_openai_payload`) and `ollama` each build their own payload, and only `copilot` and `azure` delegate — so anything that must apply to every openai-shaped request belongs at `dispatcher.prepare_payload`, the single point upstream of all of them.
- SSE line primitives (`safe_json_decode`, `strip_data_prefix`) live in `lua/parley/sse.lua`, shared by the adapters and the [tool wires](tool_use.md).
- CLIProxyAPI dynamically selects OpenAI or Anthropic behavior based on strategy and model family.
- Query cache in `query_dir`; pruned at >200 files.

## When a response arrives but carries no answer (#228)

HTTP 200 does not mean the turn produced text, and three different endings look
identical in the buffer — an answer that stops mid-sentence and looks finished.
Parley knew the reason in every case and reported none of them, saying only
`"<provider> response is empty: body_bytes=18152"` — a message that pairs the
word *empty* with a byte count, and that has now misled twice for two unrelated
causes (#197 credentials, #228 a token cap).

Four predicates in `dispatcher.lua`, each pure and each with its own test:

| function | question |
|---|---|
| `_extract_stop_reason(raw)` | what did the wire call the ending? `stop_reason` (anthropic), `finish_reason` (openai), `finishReason` (googleai — camelCase, and unmatched until #228) |
| `_is_output_cap(r)` | was it the output cap? `max_tokens` / `length` / `MAX_TOKENS` |
| `_is_normal_finish(r)` | did it end normally? A **whitelist** — `end_turn`, `stop`, `tool_use`, `tool_calls` |
| `_inband_error(raw)` | did the body carry an error the status could not see? |

`_is_normal_finish` is a whitelist on purpose. Asking the opposite question —
*was it the cap?* — stays silent for refusals, content filters and anything not
yet enumerated. **A spurious warning is cheap; a silently truncated transcript
is not**, so an unrecognised ending surfaces rather than passing as normal.

A `nil` stop reason still counts as normal: every successful non-streaming shape
has none, and warning on all of them would be noise. That is precisely the gap
`_inband_error` fills — a mid-stream error event carries no stop reason, so the
body is the only evidence it happened.

### `max_tokens` is a MODEL property, not a provider one

Defaults live in `provider_params.lua`. Claude models get **64000** (Anthropic's
documented default for streaming, which is what parley sends) via a
**model-keyed** override rather than a provider default: the same
`claude-sonnet-5` arrives through both `anthropic` and `cliproxyapi`, while
`cliproxyapi` also proxies `gpt-*` and `ollama` serves small local models — a
provider-level default would push a cap those cannot honour.

The cap counts **reasoning/thinking tokens**. A system prompt that asks the
model to think before answering can spend the entire budget reasoning and emit
no text at all, which is #228's reported failure: 18 KB of body, one thinking
block, zero `text_delta`.
