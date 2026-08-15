# Boundary Review — parley.nvim#198 (milestone M1)

| field | value |
|-------|-------|
| issue | 198 — Native OpenAI-family tool-use support |
| repo | parley.nvim |
| issue file | workshop/issues/000198-openai-family-tool-use.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 95e4b52b647f33e2229af8f8ae6b86f26e74de76^..HEAD |
| command | sdlc milestone-close --issue 198 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-15T11:13:06-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 delivers what it set out to: the Anthropic tool protocol is a byte-faithful move out of `providers.lua` (I diffed both bodies against `95e4b52^` — identical modulo the `M.` name and the `sse.` prefix), a new OpenAI wire is pinned against real captured bytes, and the two divergent cliproxy route tests genuinely collapse into one helper with a matrix test that asserts payload shape and tool shape can no longer disagree. Full unit suite passes (the two integration failures are `git init` returning 128 in this environment, in `markdown_finder_async` / `git_markdown_source` — unrelated to this diff and already noted in the issue Log); luacheck clean. One Critical blocks a clean close: the OpenAI decoder's `id`/`name` guards are truthiness checks, so an explicit JSON `null` (which this very wire emits for `finish_reason`) resolves to `vim.NIL` and overwrites a correctly-captured id/name — I verified the resulting ToolCall raises `attempt to concatenate a userdata value` two frames downstream, which is exactly the "never raises, degrade instead" contract the decoder advertises. Everything else is coverage and doc-accuracy.

## 1. Strengths

- **The route unification is real, not asserted.** `providers.cliproxy_route` (`lua/parley/providers.lua:181-189`) is consumed by both `cliproxyapi.format_payload:989` and `cliproxyapi_encode_tools:1298`, and `tests/unit/openai_payload_tools_spec.lua:93-121` pins the invariant across four (model, strategy) combinations by reading the payload's own `_parley_route` stamp. That's an invariant test, not a restatement of the implementation.
- **The "verbatim move" claim holds up under diff.** `encode_tools` and `decode_tool_calls_from_stream` in `lua/parley/tools/wire_anthropic.lua` are byte-identical to the originals; `tests/unit/anthropic_tool_{encode,decode}_spec.lua` are untouched and pass. That is the right proof for a refactor milestone.
- **Fixtures are real bytes with provenance recorded where it can live.** `tests/fixtures/openai_*.sse` keep the usage chunk, `native_finish_reason`, and `[DONE]` interleaving, and `tests/unit/openai_tool_decode_spec.lua:16-17` records the capture source. The decoder is pinned against the wire, not against an idealization of it.
- **The dispatcher_spec rewrite is honest.** `tests/unit/dispatcher_spec.lua:333-339` states plainly that the old assertion was *demanding* the latent bug, rather than quietly deleting it.
- **`translate_messages`' identity test** (`tests/unit/openai_message_translate_spec.lua:22-30`) guards the highest-blast-radius path in the file — every tool-less OpenAI chat flows through it once M2 wires it up.
- **The decoder resilience suite is genuinely adversarial** — malformed JSON, absent arguments, truncated stream with no `finish_reason`, non-list `tool_calls`, missing `index`.

## 2. Critical findings

**C1 — `lua/parley/tools/wire_openai.lua:134-146`: truthiness guards let `vim.NIL` and nameless entries poison a ToolCall, which raises downstream.**

```lua
if tc.id then state.id = tc.id end            -- vim.NIL is truthy
...
if fn.name then state.name = fn.name end      -- vim.NIL is truthy
if type(fn.arguments) == "string" then ...    -- correctly type-guarded
```

The asymmetry with the `arguments` guard on the next line is the tell. Two reachable outcomes, both verified by direct probe against the module:

1. A continuation chunk carrying `"id":null` / `"function":{"name":null,...}` — explicit nulls are on this wire; cliproxyapi's own captures emit `"finish_reason":null,"native_finish_reason":null` — **overwrites the correct id/name captured in the first chunk** with `vim.NIL`. Probe result: `id type=userdata is_vim_NIL=true`, `name type=userdata is_vim_NIL=true`, with `input` correctly assembled.
2. An array entry that never carries a first chunk (`{"index":0,"function":{"arguments":"{}"}}`) yields `{id=nil, name=nil, input={}}`. Probe result: `orphan n=1 id=nil name=nil`. `wire_anthropic` cannot produce this — a call only exists there if `content_block_start` carried a `tool_use` block.

Failure scenario: either ToolCall reaches `tool_loop.process_response` → `tools/dispatcher.execute_call`, where `lua/parley/tools/dispatcher.lua:230-237` does `tools_registry.get(call.name)` → nil → `"Tool '" .. call.name .. "' is not available..."` → `attempt to concatenate field 'name' (a userdata value)` (verified), thrown *before* the handler pcall. The chat buffer is left with an unmatched 🔧: — precisely the outcome the decoder's docstring (`wire_openai.lua:97-98`) and the plan's Task 1.5 resilience list promise to prevent. In case 1 the milder path is a `tool_call_id` that JSON-encodes as `null` on the round trip, which the API rejects.

Fix sketch:
```lua
if type(tc.id) == "string" then state.id = tc.id end
...
if type(fn.name) == "string" then state.name = fn.name end
```
and in the assembly loop, skip (or explicitly synthesize an error result for) any `state` with no `name`. Add two spec cases to `tests/unit/openai_tool_decode_spec.lua`: explicit-null continuation chunk must not clobber, and a nameless entry must not surface as a ToolCall.

## 3. Important findings

**I1 — `tests/unit/tool_wire_registry_spec.lua:158-171`: the one behavior `cliproxy_strategy` exists to own is not actually tested.** The test branches on whether `parley` is set up. In the unit-test process it is not — I probed under `tests/minimal_init.vim` and got `configured=nil`, `strategy=none`, so the assertion degrades to `equals("none","none")` and the config-level fallback is never exercised. That fallback is the entire justification for exposing the wrapper (`providers.lua:149-158`: consumers "MUST NOT re-implement the config-level fallback"). Fix: stub `parley.dispatcher = { providers = { cliproxyapi = { web_search_strategy = "anthropic_tools_route" } } }` in `before_each` / restore in `after_each`, then assert both that the config value is picked up and that a model-level value still wins.

**I2 — no coverage for the two functions Task 1.2 explicitly flags as "NOT moves."** `wire_anthropic.has_tool_calls` (`wire_anthropic.lua:165-168`) has no direct test at all — not even via the registry. `wire_anthropic.encode_tool_choice` (`:60-62`) is covered only by an inequality assertion (`tests/unit/openai_tool_encode_spec.lua:110-116`) that would pass with a wrong Anthropic shape. `wire.encode_tool_choice` (`wire.lua:85-91`) is untested entirely, raise path included. These are the exact call sites M2 swaps the dispatcher's `empty_response` predicate and `skill_assembly`'s forced-tool literal onto; a drift in the `'"type":"tool_use"'` probe would silently break the primary provider. Fix: pin `{type="tool", name=…}` by value, pin `has_tool_calls` true/false against the existing anthropic fixture, and add a registry-level `encode_tool_choice` case including the googleai raise.

**I3 — `atlas/providers/tool_use.md` describes M2 state in the present tense.** Line 36: "`lua/parley/tools/wire.lua` is the registry every consumer goes through." Line 75: `translate_messages` "converts that already-validated output at the dispatcher seam." At HEAD neither is true — `lua/parley/dispatcher.lua:117-130` still runs the five-branch chain, `lua/parley/tool_loop.lua:193` and `lua/parley/skill_invoke.lua:252` still call `providers.decode_anthropic_tool_calls_from_stream`, `dispatcher.lua:326` still hardcodes the Anthropic literal, and nothing calls `translate_messages`. AGENTS.md §8 makes atlas the current-state map; an agent reading it would believe the wiring is done. Fix: scope the consumer claims to "M2 rewires the consumers; at M1 they still call the Anthropic wire directly," and drop the note at M2's atlas pass (Task 2.8 Step 3).

**I4 — the encoders were unblocked before the decoders were, leaving a user-reachable silent failure.** `openai_encode_tools` and the cliproxy openai route now build valid payloads, but `tool_loop` decodes with the Anthropic decoder and `empty_response` probes for `'"type":"tool_use"'`. Concretely: `ToolSol*` (`provider="cliproxyapi"`, `model={model="gpt-5.6-sol"}`, `tools={"@all"}` — in the working tree, carried into this branch per Task 2.7) previously raised a clear *"tools not supported for this provider yet"* at request-build time; it now sends tools, gets `delta.tool_calls` back, decodes zero, and renders an empty answer with a "response is empty" notice. That's the checklist's "silent error swallowing where the source raised." It is not fixable *at* M1 — M2 Tasks 2.1/2.2 own it — so the remediation is a `## Log` entry naming the intermediate-state hazard and an explicit note that M1 must not merge without M2. Flagging it so the boundary records the exposure rather than inheriting it silently.

**I5 — plan Core-concepts table contradicts the code.** `workshop/plans/000198-openai-family-tool-use-plan.md:28-29` mark `M.ollama_encode_tools` and `M.googleai_encode_tools` "deleted", and Task 1.8 (`:251`) is explicit about deleting them in M1. Both are still present (`lua/parley/providers.lua:1310, :1315`). The deviation is *correct* — deleting them before M2 removes `dispatcher.lua:124-126` would leave the tree calling a nil — and it is recorded as Log finding #2. What's missing is the plan-side half: no `## Revisions` section, so the plan still claims something the code does not deliver. See §7.

## 4. Minor findings

- `lua/parley/dispatcher.lua:122` — comment `-- raises` is now false for `openai_encode_tools`; `:112` says "Non-Anthropic providers raise here" which is also stale.
- `lua/parley/tools/wire.lua:50` reads the model name from a bare string (`model.model or model`) while `cliproxyapi.format_payload:985` discards it (`model.model or nil`) — the shared-decision property holds only for table models. The string form is a supported, tested signature (`openai_payload_tools_spec.lua:87-90`). Currently unreachable via `prepare_payload` (string models short-circuit at `dispatcher.lua:100`), but the divergence is the same class the issue set out to remove.
- `providers.lua:149-158` — `cliproxy_strategy`'s docstring says "PURE", but it reads module-global `parley.dispatcher.providers` (ARCH-PURE). That global read is exactly why I1's test punts.
- `wire_openai.has_tool_calls` (`:177-180`) plain-finds `"tool_calls"`. An OpenAI-compatible backend that emits `"tool_calls":null` in every delta makes it permanently true. Benign direction (suppresses the empty-response notice), worth a comment.
- `lua/parley/sse.lua` has no direct spec. The `strip_data_prefix` parenthesization is a genuine latent-bug fix (Log finding #3) and nothing pins the single-return contract.
- `providers.lua:1038` — `cliproxyapi.parse_sse_progress_event` still picks anthropic-vs-openai parsing from `get_cliproxy_strategy(nil)` alone, not `cliproxy_route`. Pre-existing and commented, and benign at the `openai_tools_route` config default (`config.lua:101`), but it is the last route decision not derived from the shared helper.

## 5. Test coverage notes

Unit suite green including all six new/changed specs and `parley_harness_golden_spec` (the Anthropic goldens are the refactor's real backstop). Tests are pure — no mocks anywhere in the new specs; the only IO is `io.open` on a checked-in fixture, which is test-side, not the entity under test. The Log's mutation-testing note (reordering the index list drops 17→16, removing the `empty_dict` coercion drops 10→8) is the right instinct for specs written after the implementation.

Gaps, in priority order: the two `wire_anthropic` non-move functions and registry `encode_tool_choice` (I2); the `cliproxy_strategy` config fallback, which currently self-skips (I1); the decoder's explicit-null and nameless-entry cases (C1); `sse.lua`'s single-return contract. One weak-by-construction case: the route-agreement rows with no strategy (`openai_payload_tools_spec.lua:106,107`) resolve through `"none"` in the unit env, so both sides trivially agree — the claude rows carry the real signal.

## 6. Architectural notes

- **ARCH-DRY — pass.** `sse.lua` prevents the third and fourth copies the plan gate (PQ-6) called out. `cliproxy_route` collapses the two divergent route tests into one function with three consumers, pinned by the agreement matrix. Residual duplication (`dispatcher.lua:117-130`'s chain re-implementing the registry's dispatch) is M2's by design. The `parse_sse_progress_event` divergence (Minor) is the one route decision left outside the source.
- **ARCH-PURE — pass with one note.** `sse`, `wire_anthropic`, `wire_openai`, and `wire` are pure modules whose specs run with no IO, no fs, no exec, no mocks. The exception is `cliproxy_strategy`'s module-global config read (Minor), which surfaces as the self-skipping test in I1 — the classic tell that a "pure" entity has an ambient input.
- **ARCH-PURPOSE — pass for the milestone, with I4 recorded.** The issue's purpose is end-to-end OpenAI tool use; M1 is a legitimate layer split, not a deferred point, and M2 is planned in the same branch. The single-source shadow-sweep on `cliproxy_route` finds two of three consumers deriving correctly; the third (`parse_sse_progress_event`) is pre-existing. I4 is the ordering cost of splitting encode from decode across the boundary.
- **ARCH-MOCK — pass at this boundary; the obligations are M2's and must land.** M1 introduces no external calls, and the wire is pinned by *captured* bytes rather than hand-written idealizations — the right substitute at this layer. The stateful `fake_cliproxy` tool mode and the live conformance check (`PARLEY_LIVE_CONFORMANCE=1`, reusing a running proxy read-only to avoid #197's rotation race) are named in the plan and in Done-when; they are what makes the wire defensible against upstream drift, so the M2 close should verify both actually landed rather than inheriting the M1 pass.
- **For upcoming work:** C1 generalizes — parley now decodes two wires, and `vim.json.decode`'s `vim.NIL` is a hazard at every optional-field read. A one-line `local function str(v) return type(v) == "string" and v or nil end` in `sse.lua`, used by both decoders, would make the class unrepresentable rather than fixed per-site.

## 7. Plan revision recommendations

Add a `## Revisions` section to `workshop/plans/000198-openai-family-tool-use-plan.md` (per AGENTS.md — append, don't overwrite) with:

1. **Timestamped entry, M1:** rows `M.ollama_encode_tools` and `M.googleai_encode_tools` (`:28-29`) change status `deleted` → `deleted in M2`. Reason: their only caller is `dispatcher.lua:124-126`, which M2 Task 2.1 removes; deleting at M1 would leave the tree calling a nil. Task 1.8 (`:251`) and its Files list update to match.
2. **Timestamped entry, M1:** Task 1.7's stated test files (`tool_wire_registry_spec.lua`, `cliproxy_route_spec.lua`) consolidated into `tool_wire_registry_spec.lua` alone. Cosmetic, but the plan currently names a file that does not exist.
3. **Timestamped entry, M1 → M2 handoff:** record the I4 intermediate state — encoders unblocked at M1 while decode and `empty_response` still assume Anthropic — so M2 Task 2.1/2.2 is understood as closing a live regression, not just adding capability. Mirror it in the issue's `## Log`.
