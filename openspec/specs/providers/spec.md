# Spec: Providers

## Overview

A provider is an LLM backend that parley.nvim can send chat requests to. Providers are configured with an endpoint URL and an API secret. Each agent is associated with exactly one provider. The dispatcher module handles all communication between the plugin and providers.

---

## Supported Providers

The following providers are built in with default configuration:

| Provider name | Description | Default state |
|---|---|---|
| `openai` | OpenAI chat completions API | Enabled |
| `anthropic` | Anthropic Claude messages API | Enabled |
| `googleai` | Google Gemini generative language API | Enabled |
| `ollama` | Local Ollama instance (OpenAI-compatible) | Disabled by default |
| `copilot` | GitHub Copilot (OpenAI-compatible with token exchange) | Not listed as default; present in code |

Any endpoint compatible with the OpenAI chat completions API MAY be configured as a custom provider (e.g., Azure, LM Studio).

> **NOTE:** The `copilot` provider is referenced in code and config defaults but is not described in the README as a supported provider. Its support status is undocumented.

---

## Provider Configuration

Each provider MUST be configured with at minimum:

- `endpoint`: the full URL of the API endpoint (string, required)

Each provider MAY include:

- `disable`: set to `true` to exclude the provider at setup time

A provider is removed from the active set if any of the following are true:
- It is not a table.
- Its `disable` field is `true`.
- It has no `endpoint`.
- Its provider table is set to an empty table `{}` in user config.

### Endpoint Template Variables

Some provider endpoints support template substitution at request time:

| Variable | Used by | Substituted with |
|---|---|---|
| `{{model}}` | `googleai`, `azure` | The model name from the agent config |
| `{{secret}}` | `googleai` | The resolved API secret |

For `googleai`, the model and secret are embedded into the URL and MUST NOT be sent as headers or body fields.

---

## API Secret Handling

Secrets are managed by the vault module, separate from provider configuration.

Secrets are provided via the `api_keys` table in user config, keyed by provider name. A secret value MAY be:

- A string (used directly)
- A Lua table interpreted as a shell command (first element is the executable, remaining elements are arguments)

When a secret is a table (shell command), the vault MUST resolve it asynchronously before making any request. The resolved value is trimmed of leading and trailing whitespace.

Once resolved, secrets are stored privately in the vault and MUST NOT be retained in the plugin's exposed config table after `setup()` completes.

### Copilot Token Exchange

The `copilot` provider requires an additional token exchange step before each request:

**Given** the copilot secret is a GitHub personal access token (string),
**When** a request is about to be sent,
**Then** the vault MUST exchange it for a short-lived bearer token by calling `https://api.github.com/copilot_internal/v2/token`.

The bearer token is cached with its expiry time. If the cached token is still valid at request time, the exchange MUST be skipped. The token MUST be refreshed when expired.

---

## Request Transport

All provider requests are made via `curl` as a subprocess. No HTTP library is used.

The request MUST be sent with:

- `--no-buffer` and `-s` flags (unbuffered, silent)
- `Content-Type: application/json` header
- The JSON payload written to a temporary file in the query cache directory, passed via `-d @<file>`

Optional proxy or additional curl parameters MAY be appended via the `curl_params` config field.

The temporary query file MUST be cleaned up automatically. The query cache directory MUST be pruned to at most 100 files when it exceeds 200 files.

---

## Payload Construction

The payload sent to each provider is constructed differently based on the provider name.

### OpenAI (and OpenAI-compatible providers)

Payload fields:

| Field | Value |
|---|---|
| `model` | Model name string |
| `stream` | `true` |
| `messages` | Array of `{role, content}` objects |
| `temperature` | Clamped to `[0, 2]` |
| `top_p` | Clamped to `[0, 1]` |
| `max_tokens` | From model config, default `4096` |
| `stream_options.include_usage` | `true` |

**Reasoning models** (model name starts with `o`, or is `gpt-4o-search-preview`, or starts with `gpt-5`): `temperature`, `top_p`, and `max_tokens` MUST be omitted. System messages MUST be removed. For `o3` or `gpt-5` models, `reasoning_effort` MUST be included (default `"minimal"`).

**GPT-5 models**: MUST use `max_completion_tokens` instead of `max_tokens`.

### Anthropic

Payload fields:

| Field | Value |
|---|---|
| `model` | Model name string |
| `stream` | `true` |
| `messages` | Array of non-system `{role, content}` objects |
| `system` | Array of `{type, text}` blocks extracted from system messages |
| `max_tokens` | From model config, default `4096` |
| `temperature` | Clamped to `[0, 2]` |
| `top_p` | Clamped to `[0, 1]` |

System messages are extracted from the messages array and placed in a top-level `system` array of content blocks.

**Web search and web fetch tools**: When `claude_web_search` is enabled in session state, two tools MUST be appended to the payload:

- `web_search` (`type: web_search_20250305`, `max_uses: 5`)
- `web_fetch` (`type: web_fetch_20250910`, `max_uses: 5`)

### Google AI (Gemini)

Payload fields:

| Field | Value |
|---|---|
| `contents` | Array of messages with `role` and `parts[].text` |
| `generationConfig` | `{temperature, maxOutputTokens, topP, topK}` |
| `safetySettings` | All four harm categories set to `BLOCK_NONE` |
| `model` | Included in the endpoint URL, not the body |

Role mapping: `system` → `user`, `assistant` → `model`. Consecutive messages with the same role MUST be merged into a single message by concatenating their `parts`.

The model name MUST be substituted into the endpoint URL and removed from the payload body before sending.

---

## Request Headers

Headers sent per provider:

| Provider | Headers |
|---|---|
| `openai` | `Authorization: Bearer <secret>`, `api-key: <secret>` |
| `anthropic` | `x-api-key: <secret>`, `anthropic-version: 2023-06-01`, `anthropic-beta: <tag>` |
| `googleai` | None (secret is embedded in endpoint URL) |
| `copilot` | `Authorization: Bearer <bearer>`, `editor-version: vscode/1.85.1` |
| `azure` | `api-key: <secret>` |
| All others | `Authorization: Bearer <secret>` |

For Anthropic, the `anthropic-beta` header value is `messages-2023-12-15` by default. When the `web_fetch` tool is included in the payload, it MUST be `web-fetch-2025-09-10` instead.

---

## Streaming Response Handling

All providers use streaming responses. The plugin reads `curl` stdout line by line and extracts text content incrementally.

Content is extracted per provider as follows:

| Provider | Source field |
|---|---|
| `openai` / `copilot` | `choices[0].delta.content` in each SSE `data:` line |
| `anthropic` | `delta.text` from `content_block_delta` events; `content_block.text` from `content_block_start` events |
| `googleai` | `text` field parsed from individual response lines |

Each extracted chunk is passed to the buffer handler immediately, producing visible streaming output.

If the response is empty after the stream ends, the plugin MUST log an error.

---

## Token Usage Metrics

After each response completes, the plugin attempts to extract token usage from the raw stream for internal tracking.

| Provider | Metric fields tracked |
|---|---|
| `openai` / `copilot` | `prompt_tokens`, `prompt_tokens_details.cached_tokens` |
| `anthropic` | `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens` |
| `googleai` | `usageMetadata.promptTokenCount`, `candidatesTokenCount`, `totalTokenCount` |

> **NOTE:** Extracted metrics are stored internally via `tasker.set_cache_metrics`. How they are surfaced to the user (if at all) is not documented in the README.

---

## Raw Mode

When `raw_mode.show_raw_response` is enabled (globally or per-chat header), the plugin MUST:
- Bypass content extraction from the stream.
- Accumulate the entire raw API response.
- Wrap it in a fenced ` ```json ` code block and insert it into the buffer as the assistant's response.

When `raw_mode.parse_raw_request` is enabled, the plugin MUST:
- Check the current question for a fenced ` ```json ` code block.
- If found, parse its content as a JSON object and use it directly as the API payload, bypassing normal payload construction.

---

## Notes and Ambiguities

- **Ollama**: The README states Ollama is supported and uses a dummy secret. Ollama's endpoint (`http://localhost:11434/v1/chat/completions`) is OpenAI-compatible, so it uses the default OpenAI-style headers and payload. The user is expected to have Ollama running locally with models configured. This is not verified by the plugin at startup.
- **Azure**: The `azure` provider is handled in the header construction code but has no entry in the default `providers` config and is not described in the README. Configuration details are undocumented.
- **Copilot**: Referenced in code and `api_keys` defaults but absent from the README's provider list.
- **`reasoning_effort` per-agent**: The config shows `reasoning_effort` as an agent-level field (e.g., `reasoning_effort = low`). The README does not describe this field. Its interaction with the payload is partially documented in code for `o3`/`gpt-5` models only.
- **Safety settings for Google AI**: All four harm categories are hardcoded to `BLOCK_NONE`. This is not configurable and not mentioned in the README.
