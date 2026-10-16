---
id: 000242
status: working
deps: []
github_issue:
created: 2026-09-12
updated: 2026-10-16
estimate_hours: 8.37
card_mirror: '5b62ff3db97fe8ee4628c2772b00d30d62030af3' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T07:13:14-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
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

## Spec

**The fake is structurally faithful, not intelligent.** Its replies need not
make sense; they must have the exact wire shape the decoders read and behave
*consistently across the calls of one interaction*. That is all "stateful"
means here.

1. **One fake server, per-provider dialects.** Extend `fake_cliproxy`'s
   skeleton (it already does SSE, `[DONE]`, tool_calls, error modes,
   exit-with-parent) into `tests/fixtures/fake_provider` with a `--dialect`:
   - `anthropic` — the messages SSE event sequence (`message_start`,
     `content_block_start/delta/stop`, `message_delta`, `message_stop`),
     `tool_use` blocks, thinking blocks, the in-band `error` event, and
     `stop_reason: max_tokens`.
   - `openai` — chat.completions SSE; `copilot`, `azure`, `ollama` are this
     dialect with the header/endpoint differences `format_headers` applies
     (`dispatcher.lua:648`). cliproxy's existing chat surface is this dialect
     too — one implementation, not four.
   - `googleai` — `generateContent` SSE.
   Bodies come from the recorded fixtures wherever one exists (real bytes,
   faithful by construction); scripted otherwise.
2. **The behavior model is keyed on the request.** Last message carries a
   `tool_result` → reply with final text; tools offered and no result yet →
   reply with a `tool_use`; otherwise text. Plus counters for the modes a
   recording cannot show: first call 429 then 200; `overloaded`; disconnect
   after N bytes; **split every SSE frame at every byte boundary** (the
   chunking parley sees from curl is not the chunking the API sent).
3. **Integration tests through the real path**, per dialect: plain stream,
   the two-call tool loop, in-band error, HTTP error with retry, `max_tokens`
   truncation, split frames. #228 and #229 become named regressions here.
   The tests spawn the fake, set the provider's `endpoint`, and drive the
   dispatcher as a chat would — `chat_progress_process_spec.lua` and the
   cliproxy lifecycle specs are the existing shape to copy.
4. **Live conformance, gated like cliproxy's.** A spec under
   `PARLEY_LIVE_PROVIDERS=1` sends one minimal request per provider and
   asserts the event vocabulary the decoders read is present in the fresh
   stream — the same assertion the fake is built from. `make fixtures` stays
   the re-record. Cadence: nothing scheduled exists in this repo; the
   documented rule is "run before a release and after any decoder change",
   and the release checklist (parley#206's docs rebuild is the nearest home)
   lists it.
5. **No leaks.** Satisfied by construction since #220: a fake that binds a port
   inherits parent-death exit from `LoopbackHTTPServer`, so there is no flag for
   a new fake to set or forget, and `tests/arch/fixture_lifecycle_spec.lua`
   fails any fixture that reaches the watchdog by neither route. This issue
   still does not ship until #220's survivor count is enforced, or it
   multiplies the leak.

Out of scope: the record-side oracle (`scripts/parley_harness.lua` builds
payloads offline and is separately tested); Google Drive (`google_drive.lua`
is not a chat provider); making the fake answer sensibly.

## Done when

- `fake_provider --dialect {anthropic,openai,googleai}` serves the modes in
  Spec 2; a table-driven unit test asserts each mode's wire shape against the
  recorded fixture where one exists.
- Integration specs per dialect run the real dispatcher → curl → fake path
  for the six scenarios in Spec 3; #228 and #229 fail on their pre-fix code
  and pass now.
- A second-call tool-loop fixture exists for Anthropic (recorded by an
  extended `capture_anthropic_tool_use_stream.sh`).
- `PARLEY_LIVE_PROVIDERS=1 make test` runs the conformance spec against the
  real APIs and passes; without the variable it is skipped, not failed.
- A full run leaves no `fake_provider` process behind (#220's check).

## Estimate

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec              design=0.60 impl=0.04
item: api-integration         design=0.40 impl=0.60
item: api-integration         design=0.40 impl=0.60
item: api-integration         design=0.40 impl=0.60
item: cross-cutting-refactor  design=0.10 impl=0.20
item: lua-neovim              design=0.30 impl=0.60
item: lua-neovim              design=0.30 impl=0.60
item: lua-neovim              design=0.30 impl=0.60
item: real-api-discovery      design=0.00 impl=0.24
item: atlas-docs              design=0.04 impl=0.08
item: milestone-review        design=0.10 impl=0.20
item: milestone-review        design=0.10 impl=0.20
item: milestone-review        design=0.10 impl=0.20
design-buffer: 0.15
total: 8.37
```

The items:
- **api-integration ×3:** one per wire dialect (anthropic; the openai family; googleai): the shared dialect module, fake_provider's request-keyed behaviour and failure modes, and their fixture-backed tests.
- **cross-cutting-refactor:** moves fake_cliproxy's chat surface onto the shared module across its 12 specs.
- **lua-neovim ×3:** the scenario-table integration specs with the copilot token-URL seam; the standalone #228/#229 proofs on their pre-fix parents; and the gated live conformance spec with the second-call capture script.
- **real-api-discovery ×1, not 3:** the dialect shapes come from recorded fixtures, and the live runs are operator steps.
- **milestone-review ×3:** one per M1–M3 boundary.

The approved, thorough plan earns v2's ×0.2 design discount on the implementation primitives (design 0.4 from 1–3 ×0.2 for api-integration). Each `impl=` is 40% of the v2 table's high value (1.5 → 0.6), per v3.1. The design buffer is +15% (thorough plan doc). Library check: no existing library provides SSE fakes for these wires; the repo's own fake_cliproxy is reused, which is what the cross-cutting-refactor item prices.

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. `sdlc estimate-source` reported the calibration source stale on 2026-10-16, so the per-primitive values are provisional.*

## Plan

Durable plan: `workshop/plans/000242-arch-mock-stateful-fake-per-chat-provider-plan.md`. It opens with the 2026-10-16 inventory and five decisions for the TL, which revise this issue's Spec:
1. No retry exists, so HTTP errors are tested as surfaced failures and retry is filed separately.
2. #228's regression targets the ending classification that landed.
3. A copilot token-URL test seam.
4. A shared `sse_dialects.py` that both fakes import, instead of folding fake_cliproxy.
5. The live run and the second-call recording are operator steps.

- [ ] M1 — Anthropic dialect: shared dialect module + fake_provider (request-keyed behaviour, failure counters, frame splitter) + S1–S7 through the real dispatcher→curl path + #228/#229 regression proofs on their pre-fix parents
- [ ] M2 — OpenAI family (openai, azure, ollama, copilot via a token-URL seam) and googleai; fake_cliproxy's chat surface on the shared module (its anthropic route answers in the anthropic dialect)
- [ ] M3 — gated live conformance spec (`PARLEY_LIVE_PROVIDERS=1`), the second-call fixture capture, atlas + TOOLING release-checklist line

## Log

### 2026-09-12

- Filed from the brain advisor session. The operator's framing — "the mock
  doesn't need to be intelligent, its replay doesn't need to make sense, just
  structurally correct" — is right and is Spec 1–2; "stateful" is
  consistency across one interaction's calls (the tool loop) plus counters
  for retry/failure modes, nothing more.
- Inventory by reading: `fake_cliproxy` already streams SSE with tool_calls
  and error modes (lines 342-369, 475), so the OpenAI dialect is mostly a
  rename; the direct providers have fixtures but no seam-level double; the
  per-provider `endpoint` makes the seam testable without transport changes.

### 2026-10-16 (parley.nvim:4)

- Plan approved by the TL, all five decisions as proposed:
  1. HTTP errors are tested as surfaced failures carrying the API message; "retry transient provider errors" is filed as #351 (unclaimed).
  2. #228's regression targets what landed, proven on `dc548920^`.
  3. One test seam for the copilot token URL, no user config.
  4. A shared `sse_dialects` module that both fakes import.
  5. The live halves are built with offline proofs; the operator runs the live runs, which the TL schedules.
- TL guidance: keep it lean (the scenario table is the product; keep the fake shell thin). M1 first, and report at its milestone close before M2.

## Revisions

- 2026-10-16, the TL-approved decisions revise the Spec (recorded at the plan-quality gate's request, PQ-3):
  - Spec 3's "HTTP error with retry" is now "HTTP error surfaced as a failure carrying the API message, no retry"; retry is #351.
  - #228's regression targets the ending classification that landed (in-band error, cap, missing stop reason), proven on `dc548920^`.
  - The disconnect scenario splits into S7a (disconnect: failure surfaced, partial kept) and S7b (#229: a throwing output handler stops the attempt), proven on `634e33a9^`.
  - googleai has no tool wire, so its tool-loop scenario does not apply.
  - The copilot token URL gets a test seam.
  - Both fakes share `tests/fixtures/sse_dialects.py`.
  - The live runs are operator steps.
  - Done-when reads accordingly: "the scenarios in the plan's table" replaces "the six scenarios"; "#228 and #229 fail on their pre-fix code" means the standalone proofs on the pre-fix parents.

