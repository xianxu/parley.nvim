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

**One classification, computed once, rendered afterwards.** The first version
asked three separate questions in a fixed `if/elseif` order — empty? in-band
error? abnormal stop reason? — so *order* decided the answer, and an empty
response that ALSO carried an error could never be reported as an error. That
is a bug a single classification cannot have.

| function | question |
|---|---|
| `_extract_stop_reason(raw)` | what did the wire call the ending? `stop_reason` (anthropic), `finish_reason` (openai), `finishReason` (googleai — camelCase, and unmatched until #228) |
| `_is_output_cap(r)` | was it the output cap? |
| `_is_normal_finish(r)` | did it end normally? A **whitelist** |
| `_inband_error(raw)` | did the body carry an error the status could not see? |
| `_classify_ending(qt)` | → `done` / `cap` / `filtered` / `error` / `unknown` |
| `_ending_notice(qt)` | → the line to log, and at what level, or nil |

Each has tests in `tests/unit/empty_response_reason_spec.lua`; the classification
is table-driven over the endings, and the wire spellings have a case each.

`_is_normal_finish` is a whitelist on purpose. Asking the opposite question —
*was it the cap?* — stays silent for refusals, content filters and anything not
yet enumerated. **A spurious warning is cheap; a silently truncated transcript
is not**, so an unrecognised ending surfaces rather than passing as normal. Read
the code for the accepted spellings rather than trusting a list here — an
earlier revision of this paragraph named four when the code had six.

**An in-band error outranks every other class**, because it explains the whole
turn including its emptiness. It is also the one ending no stop reason can
describe: a mid-stream error event carries none, so the body is the only
evidence it happened.

**`unknown` (no reason at all) surfaces only when text arrived.** An empty
response with no reason is the empty-diagnosis path's business. Text that
arrives with no terminal reason is anomalous — every recorded stream fixture
across all three wires carries exactly one.

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
