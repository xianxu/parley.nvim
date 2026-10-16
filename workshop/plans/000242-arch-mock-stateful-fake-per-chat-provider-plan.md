# Provider fakes at the curl seam (ARCH-MOCK retrofit) Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** give every chat provider a stateful fake HTTP server behind the real curl seam, drive integration tests through the unmodified `dispatcher → tasker.run("curl") → out_reader` path, and add a gated live conformance check that compares the fake's event vocabulary with the real APIs.

**Architecture:** the SSE wire shapes live in ONE Python module, `tests/fixtures/sse_dialects.py` (`anthropic`, `openai`, `googleai`), whose bodies are built from the recorded fixtures wherever one exists. A new process-level fake, `tests/fixtures/fake_provider`, serves those dialects with a request-keyed behaviour model and failure counters. The existing `fake_cliproxy` imports the same module for its chat surface, so there is one implementation of each wire shape. Specs point a provider's configured `endpoint` at the fake. The transport is never stubbed.

**Tech Stack:** Lua (Neovim plugin, plenary busted specs), Python 3 fixtures on `LoopbackHTTPServer` (parent-death exit, #220), curl.

---

## Inventory (2026-10-16, read from the code; supersedes the issue's line numbers)

**Providers** (`providers.lua:1325-1333`; an unknown name falls back to openai):

| Provider | Default endpoint | Secret | Stream parsers | Tool wire |
|---|---|---|---|---|
| anthropic | `api.anthropic.com/v1/messages` | `x-api-key` header | own (`content_block_*`, `thinking_delta`, `input_json_delta`, `message_delta` usage) | wire_anthropic |
| openai | `api.openai.com/v1/chat/completions` | Bearer | own (`choices[].delta`) | wire_openai |
| googleai | `…/models/{{model}}:streamGenerateContent?key={{secret}}` | **in the URL** | own (regex over `"text":`, `usageMetadata`) | **none** (`wire.lua:32`) |
| copilot | none (configured) | Bearer `copilot_bearer`, fetched by `pre_query` from a **hardcoded** `api.github.com/copilot_internal/v2/token` (`vault.lua:227`) | openai | wire_openai |
| azure | none (configured), `{{model}}` in the URL | `api-key` header | openai | wire_openai |
| ollama | `localhost:11434/v1/chat/completions` | Bearer | openai (+ own usage) | wire_openai |
| cliproxyapi | `127.0.0.1:8317` | Bearer | openai, then anthropic, per `_parley_route` | per route |

**The seam:**
- `D.query` → `vault.run_with_secret` → `query` (`dispatcher.lua:449`).
- The endpoint is read from `D.providers[p].endpoint` (`:662`).
- curl argv (`:717-736`): `--no-buffer -s --write-out "%{stderr}__PARLEY_HTTP_<qid>__%{http_code}"`.
- `tasker.run(…, out_reader(), …)` (`:869`). The reader is called directly from libuv through `call_safely` (`tasker.lua:614-620`, re-sliced to 64 KiB). It is not `schedule_wrap`'d any more.
- The terminal parses the HTTP trailer (`:746-760`); a non-2xx status is a failure.
- Ending classification: `_extract_stop_reason`, `_inband_error`, `_classify_ending`, `_is_output_cap`, `_ending_notice`, `_empty_response_reason` (`:181-417`).
- **No 429/overloaded retry exists anywhere in lua/.** Only cliproxyapi's `recover_query` restarts, and only for auth-class errors.

**Today's doubles:**
- `fake_cliproxy`: an OpenAI-shaped chat surface (completion, tool_call[_parallel] keyed on a `role:"tool"` message, paced `stream`), error modes, models and management routes. 15 files use it. It answers `/v1/messages` in the **OpenAI** shape, so cliproxy's anthropic route has never met its real wire.
- `fake_sse_server`: one OpenAI delta, single request; used by `query_cache_spec`.
- `respond_fixture` and 17 other `dispatcher.query =` stubs: above the transport.
- `dispatcher_query_spec`: feeds fixture bytes straight to `out_reader`, which bypasses curl.
- Recorded fixtures: anthropic ×6, openai ×4, googleai ×2. `openai_error` and `googleai_error` are read by **no** spec.
- No direct-provider live spec exists.

**Related issues:**
- #220: the survivor count is enforced by every make target (`ORPHANS --phase after`), so a new fixture is covered by construction.
- #228: the salvage rewrite was **withdrawn**. What landed is the ending classification (dc548920, 3d460c83, 0a569772); the pre-fix parent is `dc548920^`.
- #229: the throwing-reader stop (634e33a9 in `tasker.lua:607-621`); the pre-fix parent is `634e33a9^`.

## Decisions for the TL (they change the issue's Spec)

1. **"HTTP error with retry" becomes "HTTP error surfaces, no retry".** No 429/overloaded retry exists, so testing one means building it, which is a feature. Proposed: this issue tests that a 429/529/500 reaches the user as a failure carrying the API's message, and files "retry transient provider errors" separately.
2. **#228's regression targets what landed.** Its pre-fix failures are the in-band `error` event, the `max_tokens` cap and a missing stop reason being reported as success. Those are what the fake drives; the withdrawn salvage regex has nothing to regress.
3. **Copilot needs one seam.** Its token URL is hardcoded. Proposed: `vault._set_copilot_token_url(url)` (test seam), and the fake serves `/copilot_internal/v2/token`. No user-facing config.
4. **Shared dialect module, not a fold of fake_cliproxy.** The issue proposes renaming fake_cliproxy's chat surface into fake_provider. That churns 15 users. Proposed instead: both fakes import `sse_dialects.py`. That is one implementation (ARCH-DRY), and it also fixes cliproxy's anthropic route (`/v1/messages` gets the anthropic dialect).
5. **Operator steps:** the live conformance run (`PARLEY_LIVE_PROVIDERS=1`, real API keys) and the second-call tool-loop recording (`capture_anthropic_tool_use_stream.sh`, real key) need credentials I do not hold. I build both and run their offline halves; the operator runs the live halves.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `Dialect` (anthropic / openai / googleai) | `tests/fixtures/sse_dialects.py` | new |
| `BehaviorModel` | `tests/fixtures/sse_dialects.py` | new |
| `FrameSplitter` | `tests/fixtures/sse_dialects.py` | new |
| `ProviderScenario` | `tests/helpers/provider_scenarios.lua` | new |
| `EventVocabulary` | `tests/helpers/provider_vocabulary.lua` | new |

- **Dialect**: pure functions from an abstract reply (`text`, `tool_use{id,name,input}`, `thinking`, `inband_error`, `cap`) to the exact SSE bytes one provider sends. The anthropic events are `message_start`, `content_block_start/delta/stop`, `message_delta` (`stop_reason`, usage) and `message_stop`. OpenAI is `choices[].delta`, `finish_reason` and `[DONE]`. googleai is `candidates[].content.parts[].text` plus `usageMetadata`. Event templates are lifted from the recorded fixtures, so the shape is real bytes.
  - **Relationships:** 1 dialect : N providers (openai serves openai, azure, ollama, copilot and cliproxy's openai route).
  - **DRY rationale:** fake_cliproxy's private `_sse` / `_tool_call_chunks` / `_stream_deltas` become its imports.
  - **Future extensions:** a new wire (e.g. OpenAI Responses) is one more dialect.
- **BehaviorModel**: request → abstract reply, keyed on the REQUEST, never on a counter (as fake_cliproxy's tool mode already is):
  - the last message carries a tool result (anthropic `tool_result` block, openai `role:"tool"`) → final text;
  - tools offered and no result yet → `tool_use`;
  - otherwise → text.
  - Failure counters cover what a recording cannot show: `http_<status>[_once]`, `inband_error`, `cap` (stop_reason `max_tokens` / `length` / `MAX_TOKENS`), `disconnect_after=<n bytes>`, `no_stop_reason`.
- **FrameSplitter**: given the SSE byte string and a split mode (`every_byte`, `random(seed)`, `frames`), the write boundaries. Pure, so the fake flushes a slice at each one. That is the chunking curl actually hands parley.
- **ProviderScenario** (Lua): the table of the scenarios × the providers they apply to (googleai has no tool loop), each naming its fake mode and its expectation. The integration specs iterate it, so adding a provider is one row.
- **EventVocabulary** (Lua): per dialect, the event types and fields the decoders read (e.g. anthropic `content_block_delta.delta.text`). The fake's unit test asserts the fake emits them, and the live spec asserts the real API still does. Both sides hold the same list.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `fake_provider` | `tests/fixtures/fake_provider` | new | the provider HTTP APIs |
| `fake_cliproxy` chat surface | `tests/fixtures/fake_cliproxy` | modified | cliproxyapi's chat routes |
| copilot token URL seam | `lua/parley/vault.lua` | new (test seam) | `api.github.com` token fetch |
| `provider_live_conformance_spec` | `tests/integration/provider_live_conformance_spec.lua` | new | the real provider APIs |

- **fake_provider**: `--dialect {anthropic,openai,googleai} --port N --mode <behaviour/failure> --split <mode>`. It answers the dialect's chat route(s) and records each request body to `$PARLEY_FAKE_REQUEST_LOG`, so a spec asserts what parley SENT on the second tool-loop call. For copilot it also serves `/copilot_internal/v2/token`. It is built on `LoopbackHTTPServer` (parent-death exit, #220 by construction).
- **copilot token URL seam**: `vault._set_copilot_token_url(url|nil)`; production keeps the constant.
- **live conformance**: gated by `PARLEY_LIVE_PROVIDERS=1`; one minimal request per provider whose key is configured. It asserts `EventVocabulary` against the fresh stream, and skips loudly (not failing) without the variable or key, like `cliproxy_tool_conformance_spec`.

## Scenarios (Spec 3, as revised by Decisions 1 and 2)

| # | Scenario | anthropic | openai family (openai, azure, ollama, copilot) | googleai | cliproxy anthropic route |
|---|---|---|---|---|---|
| S1 | plain stream → the answer equals the fake's text, byte for byte | ✓ | ✓ | ✓ | ✓ |
| S2 | two-call tool loop → second request carries the tool result; final text written | ✓ | ✓ | n/a | ✓ |
| S3 | in-band `error` event mid-stream → reported as failure, not success (#228 regression) | ✓ | ✓ | ✓ | – |
| S4 | HTTP 429/529/500 → failure with the API's message; no retry (Decision 1) | ✓ | ✓ | ✓ | – |
| S5 | output cap (`max_tokens`/`length`/`MAX_TOKENS`) → cap notice (#228 regression) | ✓ | ✓ | ✓ | – |
| S6 | split frames: every SSE frame split at every byte boundary → S1's answer unchanged | ✓ | ✓ | ✓ | – |
| S7a | disconnect after N bytes → failure surfaced, the partial answer kept | ✓ | – | – | – |
| S7b | the caller's output handler throws mid-stream → the attempt stops with `io_error`, no later chunk is consumed (#229) | ✓ | – | – | – |

Regression proofs: #228 (S3, S5) must fail on `dc548920^`, and #229 (S7b) on `634e33a9^`. See "Regression proof procedure" in the Revisions.

## Chunk 1: M1, the Anthropic dialect end to end

### Task 1: the dialect module and its fixture-backed unit test

**Files:**
- Create: `tests/fixtures/sse_dialects.py`
- Create: `tests/unit/sse_dialects_spec.lua` (runs `python3 -I tests/fixtures/sse_dialects.py --emit <case>` and decodes with the real Lua parsers)
- Create: `tests/helpers/provider_vocabulary.lua`

- [ ] Write `provider_vocabulary.lua` with the anthropic event and field list the decoders read (grep `providers.lua:652-765` and `wire_anthropic.lua:90-176`).
- [ ] Write the failing spec. For anthropic text, tool_use, thinking, inband_error and cap: the emitted bytes decode through `providers.anthropic.parse_sse_content` / `parse_sse_progress_event` / `wire_anthropic.decode_tool_calls_from_stream` to the abstract reply. Every vocabulary entry is present. The text case matches `tests/fixtures/anthropic_stream.txt`'s event sequence.
- [ ] Run: `make test-spec`-equivalent single-file run → FAIL (module missing).
- [ ] Implement the anthropic dialect plus `--emit`, with templates lifted from the recorded fixtures.
- [ ] Spec passes; `make lint`.
- [ ] Commit `#242 M1: anthropic SSE dialect, fixture-backed`.

### Task 2: fake_provider with the behaviour model and splitter

**Files:**
- Create: `tests/fixtures/fake_provider` (executable; `LoopbackHTTPServer`)
- Modify: `tests/arch/fixture_lifecycle_spec.lua` (the executable-fixture corpus count, +1; the fake inherits the watchdog via `LoopbackHTTPServer`)
- Test: `tests/unit/fake_provider_spec.lua` (spawn through `fixture_process`, curl it, assert bytes)

- [ ] Failing spec. `BehaviorModel`: one table of request shapes → expected reply kind. `FrameSplitter`: the concatenation of the slices equals the input for every mode. The shell: one curl per failure mode, asserting status and body. The request log appears only when its variable is set.
- [ ] Implement it, with `BehaviorModel` and `FrameSplitter` as pure functions in `sse_dialects.py` and the server as a thin shell.
- [ ] Spec passes; the fixture arch spec passes.
- [ ] Commit.

### Task 3: the Anthropic integration specs, S1–S7, through the real path

**Files:**
- Create: `tests/helpers/provider_scenarios.lua` (the scenario table and a `drive(provider, mode)` that starts the fake, points `D.providers[p].endpoint` at it, and runs `dispatcher.query` as `stream_integrity_spec` does)
- Create: `tests/integration/provider_anthropic_spec.lua`

- [ ] One failing case per scenario row, each asserting: the written answer, or the failure/cap notice (`_ending_notice` text), and for S2 the request log's second body carrying `tool_result` with the first call's id.
- [ ] Implement `provider_scenarios.drive`, making each case pass. No production change is expected; if one is needed, STOP and report it to the TL as a finding.
- [ ] Commit.

### Task 4: regression proofs

- [ ] Scratch worktree at `dc548920^`: S3 and S5 fail (reported as success). Back on the branch: pass. Record both in the Log.
- [ ] Scratch worktree at `634e33a9^`: S7 with a throwing reader fails there and passes on the branch.
- [ ] Commit the Log.

### Task 5: M1 boundary

- [ ] Full suite via `sdlc local-check run --name suite`. `ORPHANS --phase after` shows no `fake_provider` survivor.
- [ ] `sdlc milestone-close --issue 242 --milestone M1`.

## Chunk 2: M2, the OpenAI family, googleai and cliproxy on the shared module

### Task 6: the openai and googleai dialects

- [ ] Extend `sse_dialects.py` and `sse_dialects_spec.lua`: openai (text, tool_calls split id/name/args as fake_cliproxy does today, `finish_reason` `length`, the in-band error) and googleai (text, `MAX_TOKENS`, error). Backed by `openai_stream.txt`, `openai_tool_use_stream.sse` and `googleai_stream.txt`, and the never-read `openai_error.txt` / `googleai_error.txt`.
- [ ] Vocabulary lists for both.

### Task 7: fake_cliproxy on the shared module

**Files:** Modify `tests/fixtures/fake_cliproxy` (its `_sse`, `_tool_call_chunks` and `_stream_deltas` become `sse_dialects` calls; `/v1/messages` answers in the anthropic dialect).

- [ ] Every one of its 12 specs is unchanged and green, the arch fixture specs too.
- [ ] Add S1 + S2 for cliproxy's anthropic route (new: it was never met in its real shape).

### Task 8: the copilot seam and the openai-family / googleai integration specs

**Files:**
- Modify: `lua/parley/vault.lua` (`vault._set_copilot_token_url`, a test seam with a reader in the spec)
- Create: `tests/integration/provider_openai_family_spec.lua` (openai, azure with `{{model}}` in the endpoint, ollama, copilot through the token route)
- Create: `tests/integration/provider_googleai_spec.lua` (`{{secret}}` and `{{model}}` in the URL)

- [ ] The scenario table rows for each; failing first, then passing.
- [ ] M2 boundary: full suite, orphan check, `sdlc milestone-close --milestone M2`.

## Chunk 3: M3, live conformance and the second-call fixture

### Task 9: the live conformance spec

**Files:** Create `tests/integration/provider_live_conformance_spec.lua`.

- [ ] Gated by `PARLEY_LIVE_PROVIDERS=1`. For each provider whose key is set (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLEAI_API_KEY`), one minimal streamed request through the real dispatcher, asserting `EventVocabulary` against the raw stream. Without the variable or key it gives a loud SKIP per provider, never a failure.
- [ ] Offline proof: point the spec at `fake_provider` via an override variable and watch it pass; drop one vocabulary event from the fake and watch it fail.

### Task 10: the second-call tool-loop fixture

**Files:** Modify `scripts/capture_anthropic_tool_use_stream.sh` (record the second call too, sending `tool_result` for the first call's id). Create `tests/fixtures/anthropic_tool_result_stream_real.jsonl` (operator-recorded).

- [ ] Extend the script; dry-run it against `fake_provider` (an endpoint override) to prove the second request is well-formed.
- [ ] The operator runs it with a real key; the fixture backs the anthropic dialect's final-text case.

### Task 11: docs and release checklist

- [ ] Atlas: `atlas/providers/architecture.md` (the fakes and their seam), `atlas/infra/test_harness.md` (`PARLEY_LIVE_PROVIDERS`), traceability routes for the new specs.
- [ ] TOOLING.md: "run `PARLEY_LIVE_PROVIDERS=1 make test` before a release and after any decoder change; `make fixtures` re-records".
- [ ] `sdlc close --issue 242`.

## Risks

- The fakes' SSE templates drift from the real APIs between conformance runs. That is mitigated by the shared vocabulary list and the live spec.
- curl's buffering on loopback may merge the fake's small writes. If so, S6 is asserted at the reader through `tasker._uv`'s 64 KiB re-slicing plus the fake's flushes; that is measured in Task 2 before relying on it.
- A copilot `pre_query` that reaches the real network in a spec. The seam's default stays the real URL, so the copilot spec sets it, and a test asserts that a spec run never contacts `api.github.com` (the request log).

## Revisions

### 2026-10-16, plan-quality round 1

- **PQ-1, the regression proof procedure.** The new spec cannot run on the old trees: `loopback_http.py`, `_classify_ending` and `_ending_notice` do not exist at `dc548920^`. Each proof is therefore a small standalone script, `tests/regression/proof_228.lua` / `proof_229.lua`. It is run with `nvim --headless -l` from a scratch worktree of the pre-fix parent (`git worktree add`, never stash). It requires only APIs present on BOTH trees: `dispatcher.query` with a provider endpoint and its completion and error callbacks. The FAKE is run from the branch checkout by absolute path, so nothing is copied onto the old tree. The assertion is about behaviour, not the new notice text. #228: an in-band-error stream and a `max_tokens` stream complete WITHOUT a failure on the old tree, and WITH one on the branch. #229: on the old tree a throwing handler does not stop the attempt (later chunks are still consumed). Each script prints `PROOF-REACHED <case>` immediately before its assertion, and a run without that marker counts as inconclusive, not as a pass. The old/new outcomes go in the issue Log.
- **PQ-2, S7 split.** S7a is the disconnect (curl ends early, a failure is surfaced, the partial is kept). S7b is #229's real trigger: the caller's output handler, the callback `dispatcher.query` already takes and `out_reader` calls per chunk, throws on the Nth chunk. The assertion: the attempt stops with an `io_error` failure and the fake's later bytes are never handed to the handler. That is a real seam (the consumer callback), not a transport stub.
- **PQ-3.** The issue gets a Revisions entry (the scenario set as revised by Decisions 1 and 2, and Done-when updated).
- **PQ-4, the request log.** `$PARLEY_FAKE_REQUEST_LOG` is a per-case `vim.fn.tempname()` under the harness's isolated TMPDIR. The spec that sets it deletes it in `after_each`, and the fake writes nothing when the variable is unset.
- **PQ-5, credentials.** Specs use dummy secrets only (`sk-ant-fake`, `ghu_fake`). The copilot seam is reset to `nil` (the real URL) in `after_each`, and a case asserts that no spec request reaches `api.github.com` (the fake's request log holds every request). The live spec never puts a key in an assertion message, and its failures name the provider and the missing vocabulary entry only.
- **PQ-6.** Task 2's test plan is compressed to one strategy line per risky function (done above).
- **PQ-7, operating envelope.** `--split every_byte` runs only on the small text fixture (≤ 4 KiB, so ≤ 4096 flushes). Measured in Task 2, the case must finish under 5 s on a loaded suite, or the cap is lowered to fit. The other cases use `--split random:<seed>` (8–64-byte slices).

