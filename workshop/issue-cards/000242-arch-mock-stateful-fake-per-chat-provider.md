---
id: 000242
status: open
created: 2026-09-12
updated: 2026-09-12
estimate_hours:
github_issue:
---

# Retrofit ARCH-MOCK to the chat providers: one stateful fake per provider at the curl seam, integration tests through it, and a live conformance check that re-records the fixtures

## Problem

parley's provider layer predates ARCH-MOCK ("every external binary or service
dependency … has a stateful fake behind the same seam … integration and
end-to-end tests run against the fake; scheduled/live conformance checks
compare the fake's modeled behavior with the real service so drift is
detected"). The retrofit is partly done, unevenly:

**Done — cliproxy.** `tests/fixtures/fake_cliproxy` is a real ARCH-MOCK
double: a process-level HTTP server behind the same seam, streaming
`POST /v1/chat/completions` as SSE (`data: …`, `[DONE]`, `tool_calls`
deltas, `finish_reason: tool_calls`), error modes using the real 7.1.71
bodies, `/v1/models` and `/v0/management/*` for the lifecycle tests, and a
live conformance spec (`tests/integration/cliproxy_conformance_spec.lua`,
gated) that boots the real binary and asserts the fields the code reads
still exist.

**Not done — the six direct providers** (`anthropic`, `openai`, `googleai`,
`copilot`, `azure`, `ollama`, per `dispatcher.lua`). What exists for them is
byte-level: recorded SSE fixtures (`tests/fixtures/anthropic_stream.txt`,
`anthropic_error.txt`, `anthropic_inband_error.txt`,
`anthropic_thinking_only_max_tokens.txt`, `anthropic_truncated_max_tokens.txt`,
`anthropic_tool_use_stream_real.jsonl`) read by unit specs
(`anthropic_tool_wire_spec`, `anthropic_tool_decode_spec`) that feed the bytes
straight into the decoders. Nothing exercises the path the bytes actually
travel: `tasker.run(buf, "curl", curl_params, terminal, out_reader(), …)`
(`dispatcher.lua:794`), the HTTP-status trailer (`:689`), the chunk
boundaries curl produces, and the `vim.schedule_wrap`'d reader. That is
exactly where the recent bugs were — #228 (the salvage regex) and #229
(stream chunks discarded when the pending session invalidates) are
interaction bugs a byte replay cannot reach.

The stateful part is also untested end to end: the Anthropic **tool loop**
is two calls (`tool_use` → parley runs the tool → a second request carrying
`tool_result` → final text), and there is no fixture for the second call at
all — `capture_anthropic_tool_use_stream.sh` records the first only.
Retries on 429/overloaded, an in-band `error` event mid-stream, and
`max_tokens` truncation are likewise unit-only.

**Conformance today is a manual re-record.** `make fixtures`
(`scripts/record_fixtures.lua`) re-captures real SSE; `scripts/model_check.sh`
refreshes model ids. No cadence, no assertion — drift is detected by whoever
next notices a broken chat.

The seam is already right for a fake: each provider's `endpoint` is
configuration (`D.providers[provider].endpoint`, `dispatcher.lua:637`), so a
test points any provider at `http://127.0.0.1:<port>` without touching the
transport.
