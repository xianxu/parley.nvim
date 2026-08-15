---
id: 000198
status: working
deps: []
github_issue:
created: 2026-08-15
updated: 2026-08-15
estimate_hours: 5.6
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
codex channel), but the same wall blocks the `openai` provider itself plus
copilot, azure, and ollama.

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
parley's `web_search_20260209` / `web_fetch_20260209` to a codex model produced
no `server_tool_use` blocks at all — the model just answered from memory.
(Same tools on the `claude` channel
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
- `lua/parley/tools/wire.lua` — registry resolving (provider, **model**) → wire
  module. The single seam `dispatcher`, `tool_loop`, and `skill_invoke`
  consume, replacing three independent provider conditionals (ARCH-DRY). Keyed
  on the model, not a route: a route parameter is one a caller can forget, and
  forgetting it fails silently as zero decoded tool calls.

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
  provider, copilot and azure (which delegate to `openai.format_payload`), and
  ollama (which has its own builder) can all run tool-enabled agents.
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
| M1 atlas update (Task 1.9 Step 3 — required at the milestone) | atlas-docs | 0.02 | 0.06 |
| M1 milestone review | milestone-review | 0.02 | 0.14 |
| M2 dispatcher seam (translate + encode + empty_response) | smaller-go-module | 0.06 | 0.20 |
| M2 `tool_loop` + `chat_respond` threading | smaller-go-module | 0.03 | 0.14 |
| M2 `skill_invoke` + `skill_assembly` + `tool_choice` | lua-neovim | 0.30 | 0.40 |
| M2 `fake_cliproxy` tool mode + integration spec | api-integration | 0.20 | 0.40 |
| M2 golden payloads | smaller-go-module | 0.02 | 0.12 |
| M2 live conformance spec | real-api-discovery | 0.00 | 0.18 |
| M2 manual e2e against the real codex API | real-api-discovery | 0.00 | 0.40 |
| M2 atlas update | atlas-docs | 0.02 | 0.06 |
| M2 `lessons.md` update (Task 2.8 Step 4) | atlas-docs | 0.00 | 0.03 |
| M2 close review | milestone-review | 0.02 | 0.14 |

**Two deliberate deviations**, both from the estimate-quality review:

- *`fake_cliproxy` design at the ×0.2 floor (0.20, not mid-range 0.40).* The
  plan pre-resolves this tightly — the mode selector follows the existing
  `--error-mode` precedent and the statefulness rule is spelled out — so by this
  block's own "design cost survives only where the plan didn't resolve it"
  standard it belongs at the low end.
- *Manual e2e impl at 0.40, which is ABOVE `real-api-discovery`'s ×0.4 band
  (0.12–0.24).* Intentional. v3.1's ×0.4 scale is calibrated on **AI-paired**
  implementation, which compresses; Task 2.7 is six operator-driven round-trips
  in a live editor against a real API, which does not. The unscaled 0.3–0.6
  range is the honest one here, so this line is written unscaled.

**Calibration note (advisory, for #127's ledger — NOT applied to the total):**
recent window-trusted parley rows near this size have run consistently over —
#187 0.58, #190 0.57, #195 0.53, #168 0.60, #186 0.96, #197 0.82 (est/actual);
median ≈0.6. Against that, 5.6 projects an actual nearer 7–9h. This issue's
shape (8 new files, 2 milestones, a live-API dependency, a mostly *sequential*
task chain that gets little within-session parallelism) sits with the low-ratio
rows. Recorded as v3.1 drift to measure at close, not hand-inflated here.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: cross-cutting-refactor   design=0.14 impl=0.22
item: lua-neovim               design=1.00 impl=1.28
item: smaller-go-module        design=0.17 impl=0.74
item: api-integration          design=0.20 impl=0.40
item: real-api-discovery       design=0.00 impl=0.70
item: atlas-docs               design=0.04 impl=0.15
item: milestone-review         design=0.04 impl=0.28
design-buffer: 0.15
total: 5.60
```

## Plan

See `workshop/plans/000198-openai-family-tool-use-plan.md`.

- [x] M1 — pure wire layer: `wire_anthropic` extraction, `wire_openai`
      (encode / decode / translate), `wire` registry, unit specs + captured
      fixtures. No consumer wiring.
- [ ] M2 — wire it up: dispatcher / tool_loop / skill_invoke / chat_respond /
      skill_assembly, fake tool mode, OpenAI-route goldens, live conformance,
      end-to-end `ToolSol*` verification.

## Log

### 2026-08-15
- 2026-08-15: closed M1 — Pure wire layer landed: sse.lua + wire_anthropic + wire_openai + wire registry + cliproxy_route/cliproxy_strategy. Full suite exit 0 (unit+integration, unsandboxed). Anthropic tool specs UNCHANGED and still 19+6 pass = behaviour-preserving move; golden payloads byte-identical. 72 new assertions across 5 new specs incl. both real captured SSE fixtures. Beyond units: fed encode_tools+translate_messages real output to live cliproxy and got a correct answer back (parallel tool_calls + separate role:tool messages accepted end-to-end). Decoder specs mutation-verified (index sort 17->16, empty_dict removal 10->8).; review verdict: FIX-THEN-SHIP

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

**M1 — the pure wire layer.** Landed as `lua/parley/sse.lua`,
`tools/wire_anthropic.lua`, `tools/wire_openai.lua`, `tools/wire.lua`, plus
`providers.cliproxy_route` / `cliproxy_strategy`. 72 new/changed unit
assertions; full suite green.

Evidence beyond the unit tests: fed `translate_messages`' and `encode_tools`'
**real output** to the live proxy and got a correct answer back —
`Paris: 18°C, light rain; Tokyo: 26°C, clear.` — so parallel `tool_calls` plus
separate `role:"tool"` messages are accepted end to end, not merely
shaped right. Also mutation-tested the decoder specs (sorting the index order
drops 17 passes to 16; removing the `empty_dict` coercion drops 10 to 8), since
those tests were written after the implementation rather than before.

Three findings from doing the work:

1. **`dispatcher_spec` was pinning the latent bug.** Its cliproxy case used
   `claude-sonnet-4-6` with no `web_search_strategy` — so `format_payload`
   built an *openai* payload while the old encoder stamped anthropic-shaped
   tools onto it, and the test asserted `t.name == "read_file"`, i.e. demanded
   the mismatch. Rewritten to assert tools follow the route.
2. **The `googleai`/`ollama` stubs stay until M2.** The plan had them deleted
   here, but their only caller is the dispatcher chain M2 replaces; removing
   them first would leave the tree calling a nil. Deleted in M2 instead, in the
   commit that removes the last reference.
3. **`strip_data_prefix` was leaking `gsub`'s count** as a second return value.
   Parenthesized in the hoist; verified all seven call sites either
   single-assign or pass to a one-parameter function, so it is inert.

**Codex credential expired mid-session** — `auth_unavailable: no auth
available (providers=codex, model=gpt-5.6-sol)`, the #197 failure mode. The
round-trip above was therefore validated through the `claude` channel (cliproxy
translating openai→anthropic), which exercises the same payload shape; the
codex-side validation earlier in this Log used the identical shape before the
credential died. **M2's Task 2.7 e2e needs `:ParleyProxy login codex` first.**

**⚠ M1 MUST NOT MERGE WITHOUT M2 — intermediate-state regression.** M1
unblocked the *encoders* while the *decoders* still assume Anthropic. At this
commit a `ToolSol*` turn builds a valid OpenAI request, gets `delta.tool_calls`
back, decodes **zero** calls (`tool_loop.lua:193` still calls
`decode_anthropic_tool_calls_from_stream`), and renders an empty answer with a
"response is empty" notice — where before M1 it raised a clear *"tools not
supported for this provider yet"* at request-build time. A clear raise became a
silent wrong answer. M2 Tasks 2.1/2.2 close it and should be sequenced first
within the milestone. (M1 review I4.)

**M1 review verdict: FIX-THEN-SHIP** — one Critical, five Important. All fixed
before the close commit, per the #174 protocol:

- **C1 (real bug I introduced):** `vim.json.decode` maps an explicit JSON
  `null` to `vim.NIL`, which is **truthy in Lua** — so `if tc.id then` accepted
  it and a continuation chunk carrying `"id":null` overwrote the correctly
  captured id with userdata. Probed and confirmed: the resulting ToolCall
  raised `attempt to concatenate field 'name' (a userdata value)` in the
  registry lookup two frames downstream, breaking the decoder's own
  never-raise contract. Fixed by a shared `sse.str()` used at every optional
  field read in **both** decoders — making the class unrepresentable rather
  than patched per-site — plus dropping nameless entries, which have no
  anthropic analogue and cannot be executed.
- **I1:** the `cliproxy_strategy` config-fallback test was self-skipping —
  `parley` is not set up in the unit process, so it degraded to
  `assert.equals("none", "none")` and never exercised the one behaviour the
  wrapper exists to own. Now stubs the provider config explicitly.
- **I2:** `has_tool_calls` and `encode_tool_choice` — the two functions Task
  1.2 flagged as "NOT moves", and the exact call sites M2 rewires — had no
  direct coverage. Pinned by value now, including the exact wire spelling the
  substring probe depends on, in a new `anthropic_tool_wire_spec.lua`.
- **I3:** the atlas described M2 wiring in the present tense. Scoped to a
  state note, to be dropped at M2's atlas pass.
- **I5:** plan `## Revisions` appended (the stub-deletion deviation, the
  consolidated spec file, the I4 handoff, and `sse.str` as a new entity).

**M2 — wiring, and the end-to-end proof.** The regression above is closed:
`prepare_payload` translates and encodes at the one seam upstream of every
payload builder, `tool_loop` / `skill_invoke` / `empty_response` all decode
through the wire registry, and the `googleai`/`ollama` stubs died with the
chain that was their last caller.

The codex credential recovered on its own mid-session (cliproxy refreshed it),
so no `:ParleyProxy login codex` was needed after all.

E2E against the LIVE codex channel, driving real chat buffers through
`cmd_respond` — buffer output captured, not paraphrased:

1. **Single tool round.** `ToolSol*` emitted `🔧: read_file
   id=call_pVTFO06rF6hU0xm8olOh709G`, the tool ran, `📎:` carried
   `1  PARLEY_E2E_SENTINEL_7731`, the loop recursed, and the answer was *"The
   sentinel token is `PARLEY_E2E_SENTINEL_7731`"* — a token it could not have
   guessed.
2. **Multi-round + web search in ONE turn.** Two *sequential* `read_file`
   rounds (`call_bUZLTi2…` then `call_FIz1Gv1…`), each with its own 🔧:/📎:
   pair, then a cited web result:
   `github.com/neovim/neovim/releases?…utm_source=openai` — the `utm_source`
   marker showing it went through server-side search. This is the exact
   combination the anthropic route cannot give a codex model, and the reason
   option A was rejected.
3. **Anthropic route unregressed.** `ToolOpus*` ran the same prompt, emitted a
   `toolu_*`-id tool call (anthropic wire), and answered correctly.
4. **`force_tool` skill on an OpenAI-family agent.** The `review` skill (which
   compels `propose_edits`) ran on `gpt-5.6-sol`. Instrumented
   `prepare_payload` to make the wire evidence rather than inference:
   `provider=cliproxyapi model=gpt-5.6-sol wire=openai tools[1].type=web_search`,
   terminal `ok=true`, and the artifact really edited — *"This **sentence** has
   a **spelling** error."* That is the path that would have 400'd had
   `tool_choice` stayed Anthropic-shaped.

Live wire conformance (`PARLEY_LIVE_CONFORMANCE=1`) also passes against
7.2.110: all four delta fields present, `finish_reason=tool_calls`, decoder
yields a usable ToolCall.

**Two test-suite hazards worth knowing** (neither caused by this work):
`tests/unit/tools_builtin_find_spec.lua` shells `find` over the live repo tree,
so it races other specs creating/deleting temp files and fails intermittently
under the parallel runner (passes 3/3 in isolation). And
`chat_progress_process_spec` flaked once on fake-SSE-server port allocation.
Both re-run clean. Separately, `git`-dependent integration specs fail under a
restricted sandbox (`git init` cannot copy hook templates); they pass in a
normal shell — full suite exit 0.
