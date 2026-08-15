---
id: 000198
status: working
deps: []
github_issue:
created: 2026-08-15
updated: 2026-08-15
estimate_hours: 5.5
started: 2026-08-15T10:03:41-07:00
---

# Native OpenAI-family tool-use support

## Problem

Client-side tool use only works against Anthropic-shaped wires. Selecting a
tool-enabled agent on any OpenAI-family model raises at
`lua/parley/providers.lua:1374`:

```
tools not supported for this provider yet — cliproxyapi requires an
anthropic-family model (see #81 follow-up)
```

The stubs it belongs to — `openai_encode_tools`, `googleai_encode_tools`,
`ollama_encode_tools` (`providers.lua:1348-1362`) — are the #81 M1 deferral.
The concrete trigger is a `ToolSol*` agent (`gpt-5.6-sol` on cliproxyapi's
codex channel), but the same wall blocks the `openai` provider itself and
everything sharing `openai.format_payload` (copilot, azure, ollama).

Three things are missing, not one:

1. **Encode** — no OpenAI `{type:"function", function:{…}}` tool encoder.
2. **Decode** — no reader for OpenAI's streamed `delta.tool_calls[]`.
3. **Message translation** — `chat_respond._emit_content_blocks_as_messages`
   (`chat_respond.lua:576-700`) emits Anthropic content-block messages
   (`assistant[text,tool_use]` / `user[tool_result]`). OpenAI needs
   `assistant.tool_calls[]` plus a separate `{role:"tool", tool_call_id}`
   message per result. Nothing translates between them.

Plus three hardcoded decode sites that assume the Anthropic wire:
`tool_loop.lua:193`, `skill_invoke.lua:252`, and the `empty_response`
predicate at `dispatcher.lua:326` (`'"type":"tool_use"'`).

### Why not route everything over cliproxy's Anthropic translation endpoint

cliproxyapi *does* translate an Anthropic-format tool request to a codex
backend — verified live against 7.2.110: `tool_use` out, `tool_result`
round-trip closes. That would have been a ~100-line fix.

It was rejected because **server-side `web_search` / `web_fetch` are silently
inert on that cross-family path**. An Anthropic-shaped request carrying
`web_search_20250305` to a codex model produced no `server_tool_use` blocks at
all — the model just answered from memory. (Same tools on the `claude` channel
work fine, because that channel passes through to a real Anthropic endpoint;
the loss is specific to cross-family translation.) Routing `ToolSol*` that way
would have traded away search to gain tools.

The OpenAI route has no such trade: `{type:"web_search"}` and function tools
coexist in one `tools` array and both fire. Verified — see Log.

## Spec

Teach parley the OpenAI function-calling protocol as a first-class wire,
peer to the existing Anthropic one, so any OpenAI-family model can run the
client-side tool loop with web search intact.

**Shape of the solution.** Extract the per-wire tool protocol into pure
modules behind one registry seam:

- `lua/parley/tools/wire_anthropic.lua` — the existing encoder/decoder, moved
  verbatim out of `providers.lua`. Re-exported so existing call sites and
  specs are untouched (behavior-preserving move, proven by the unchanged
  specs passing).
- `lua/parley/tools/wire_openai.lua` — new. Encode, decode, and the
  content-block → OpenAI message translation.
- `lua/parley/tools/wire.lua` — registry mapping (provider, route) → wire
  module. The single seam `dispatcher`, `tool_loop`, and `skill_invoke`
  consume, replacing three independent provider conditionals (ARCH-DRY).

**Route selection does not change.** cliproxyapi keeps today's rule —
anthropic wire iff anthropic-family model *and*
`web_search_strategy == "anthropic_tools_route"`. Both wires now support
tools, so `ToolSol*` works on the OpenAI route its config already selects, and
`ToolSonnet*` / `ToolOpus*` / `ToolFable*` keep the Anthropic route unchanged.
The one fix is that `cliproxyapi_encode_tools` must consult the *same* route
decision `format_payload` uses instead of its own `^claude%-` string test —
extracted to one pure `cliproxy_route()` helper (ARCH-DRY).

This also closes a latent bug: a claude-family cliproxy agent with tools but
*without* the strategy override currently takes the OpenAI payload path and
then has Anthropic-shaped tools appended onto it. Nothing enforces the pairing
today; the shared route helper does.

**Translation lives at the dispatcher seam, not the emitter and not an
adapter.** `_emit_content_blocks_as_messages` stays Anthropic-shaped and stays
the single place the `#155` (no dangling `tool_use`) and `#156` (no orphan
`tool_result`) invariants are enforced; `dispatcher.prepare_payload`
translates its already-validated output into OpenAI shape. Parameterizing the
emitter by provider instead would fork those invariants across two code paths
(ARCH-DRY) and push wire knowledge into `chat_respond`, which has none today.

Putting it in `openai.format_payload` — the obvious-looking spot — would
**miss the issue's own target**: cliproxy's OpenAI route builds its payload in
`cliproxy_openai_payload` (`providers.lua:999-1029`) and `ollama` in its own
`format_payload` (`:1165-1177`); only copilot and azure delegate to openai's.
`prepare_payload` is the one point upstream of every builder, and it is
already where tools are encoded and appended — so both halves of the wire
decision sit together.

Translation is unconditional, not gated on "this request declares tools" — a
prior turn's tool blocks live in history and must translate on every
subsequent request.

## Done when

- A `ToolSol*` (`gpt-5.6-sol`) chat runs a full multi-round tool loop —
  🔧:/📎: blocks render, the loop recurses, the final answer lands — with
  `web_search` enabled and working in the same request.
- `providers.openai_encode_tools` no longer raises; the plain `openai`
  provider (and copilot/azure/ollama, which share `openai.format_payload`)
  can run tool-enabled agents.
- `tool_loop`, `skill_invoke`, and `dispatcher`'s `empty_response` predicate
  all decode through the wire registry — no provider hardcoded at a call site.
- Parallel tool calls in one turn decode correctly (distinct `index` values).
- Existing Anthropic golden payloads are byte-identical; new OpenAI-route
  goldens cover one-round, two-round, and tool-error transcripts.
- `tests/fixtures/fake_cliproxy` gains a tool-call response mode, and an
  integration spec drives the tool loop against it (ARCH-MOCK).
- A live conformance spec asserts the real binary still emits the delta shape
  the decoder reads, mirroring `cliproxy_conformance_spec.lua`.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against
`baseline-v3.1.md`. Method A only.*

**Step 2.5 (library availability):** no Lua/Neovim library implements the OpenAI
function-calling wire — this is protocol code against a captured byte format.
But the codebase's own `wire_anthropic` is a direct structural mirror, so the
"established codebase patterns count" clause of the Step 3 discount applies on
top of the plan doc.

**Step 3 (spec quality):** ×0.2 design across every primitive. The plan doc
resolves the decisions concretely — file:line seams, the per-function contracts,
the route matrix, the pinned test behaviors — and it cleared plan-quality. The
one place design cost is *not* pre-resolved is the decoder and translator
semantics, which is why those carry the largest design lines even after ×0.2.

**Step 5 (familiarity):** 1.0. Own codebase and a mirrored pattern argue for a
discount, but this is the first non-Anthropic wire and the round-trip semantics
are new; neutral is the honest call.

**Step 6 (buffer):** +15% — thorough plan doc (v2.1 calibration).

Per-part derivation, before slug consolidation (design shown post-×0.2, impl
post-×0.4 per v3.1):

| Part | Slug | design | impl |
|---|---|---|---|
| M1 `sse.lua` hoist | cross-cutting-refactor | 0.06 | 0.10 |
| M1 `wire_anthropic` extraction | cross-cutting-refactor | 0.08 | 0.12 |
| M1 `wire_openai` encode + decode | lua-neovim | 0.40 | 0.48 |
| M1 `translate_messages` | lua-neovim | 0.30 | 0.40 |
| M1 registry + `cliproxy_route`/`_strategy` | smaller-go-module | 0.04 | 0.16 |
| M1 encoder delegation + branch test | smaller-go-module | 0.02 | 0.12 |
| M1 fixture capture (already taken) | real-api-discovery | 0.00 | 0.12 |
| M1 milestone review | milestone-review | 0.02 | 0.14 |
| M2 dispatcher seam (translate + encode + empty_response) | smaller-go-module | 0.06 | 0.20 |
| M2 `tool_loop` + `chat_respond` threading | smaller-go-module | 0.03 | 0.14 |
| M2 `skill_invoke` + `skill_assembly` + `tool_choice` | lua-neovim | 0.30 | 0.40 |
| M2 `fake_cliproxy` tool mode + integration spec | api-integration | 0.40 | 0.40 |
| M2 golden payloads | smaller-go-module | 0.02 | 0.12 |
| M2 live conformance spec | real-api-discovery | 0.00 | 0.18 |
| M2 manual e2e against the real codex API | real-api-discovery | 0.00 | 0.20 |
| M2 atlas update | atlas-docs | 0.02 | 0.06 |
| M2 close review | milestone-review | 0.02 | 0.14 |

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: cross-cutting-refactor   design=0.14 impl=0.22
item: lua-neovim               design=1.00 impl=1.28
item: smaller-go-module        design=0.17 impl=0.74
item: api-integration          design=0.40 impl=0.40
item: real-api-discovery       design=0.00 impl=0.50
item: atlas-docs               design=0.02 impl=0.06
item: milestone-review         design=0.04 impl=0.28
design-buffer: 0.15
total: 5.52
```

## Plan

See `workshop/plans/000198-openai-family-tool-use-plan.md`.

- [ ] M1 — pure wire layer: `wire_anthropic` extraction, `wire_openai`
      (encode / decode / translate), `wire` registry, unit specs + captured
      fixtures. No consumer wiring.
- [ ] M2 — wire it up: dispatcher / tool_loop / skill_invoke / chat_respond /
      skill_assembly, fake tool mode, OpenAI-route goldens, live conformance,
      end-to-end `ToolSol*` verification.

## Log

### 2026-08-15

Wire behavior established empirically against the operator's running
cliproxyapi 7.2.110 (`127.0.0.1:8317`, codex channel authed) before planning,
so the design rests on observed bytes rather than API docs.

**Cross-family Anthropic translation works** — `/api/provider/anthropic/v1/messages`
with `model: gpt-5.6-sol` and an `input_schema` tool returned a proper
Anthropic `tool_use` stream, and the `tool_result` round-trip closed:

```
content_block_start {"type":"tool_use","id":"call_Gqyl…","name":"get_weather","input":{}}
input_json_delta    {"city":"Paris"}
message_delta       stop_reason: "tool_use"
```

**…but server-side web tools are inert on it.** The same route carrying
`web_search` + `web_fetch` emitted no `server_tool_use` /
`web_search_tool_result` blocks — only `thinking` + `text`. Re-tested with
`web_search_20260209` / `web_fetch_20260209`, the revisions
`providers.lua:20-21` actually sends (the first pass used older strings, which
would have made "the proxy ignored them" an artifact of a stale type): same
result, no error, no server tool blocks. Sending a bare
`{type:"web_search"}` instead came back as a *client-side* `tool_use` with
empty input (i.e. the proxy handed it back for parley to execute). This is
what ruled out the cheap route-everything-over-Anthropic fix. Operator
confirmed `server_tool_use` does work for opus — consistent: that is the
`claude` channel passing through to real Anthropic, not cross-family
translation.

**OpenAI route: search and function tools coexist.** One request carrying
both `{type:"web_search"}` and a `{type:"function"}` tool succeeded, the model
called the function, and a search-requiring prompt on the same route returned
a live citation (`github.com/neovim/neovim/releases/latest`). This is the
capability the Anthropic route cannot give a codex model.

**Captured delta shape** (drives the decoder). `id` + `name` arrive only in
the first chunk; `arguments` accumulates as string fragments at the same array
`index`; nothing closes a call — finalize on `finish_reason == "tool_calls"`:

```json
"tool_calls":[{"index":0,"id":"call_WZB1…","type":"function","function":{"name":"get_weather","arguments":""}}]
"tool_calls":[{"index":0,"function":{"arguments":"{\"city\":\"Paris\"}"}}]
"tool_calls":[{"index":1,"id":"call_DnyS…","type":"function","function":{"name":"get_weather","arguments":""}}]
"tool_calls":[{"index":1,"function":{"arguments":"{\"city\":\"Tokyo\"}"}}]
```

Structurally harder than the Anthropic decoder, which gets explicit
`content_block_start`/`_stop` framing around a top-level `.index`.

**Round-trip validated before planning** — the riskiest assumption. An
assistant turn with `content: null` + two parallel `tool_calls`, followed by
two separate `{role:"tool", tool_call_id}` messages, was accepted by the codex
channel and produced a correct summary of both results. No error.

Raw captures preserved for use as test fixtures in M1.
