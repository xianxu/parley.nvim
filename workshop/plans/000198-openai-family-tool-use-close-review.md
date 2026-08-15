# Boundary Review — parley.nvim#198 (whole-issue close)

| field | value |
|-------|-------|
| issue | 198 — Native OpenAI-family tool-use support |
| repo | parley.nvim |
| issue file | workshop/issues/000198-openai-family-tool-use.md |
| boundary | whole-issue close |
| milestone | — |
| window | 375b6359a48a3f98acdec41532bc406f8c1a113a..HEAD |
| command | sdlc close --issue 198 |
| reviewer | claude |
| timestamp | 2026-08-15T12:01:50-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The core engineering here is strong and I verified it rather than trusting the Log: the Anthropic tool specs are byte-unchanged since the plan commit and still pass (the behavior-preserving-move proof holds), the OpenAI decoder is pinned against real captured bytes with genuine adversarial cases, `cliproxy_route` collapses two divergent route tests into one helper with an agreement matrix, and the registry's model-keyed API makes the forget-the-route failure unrepresentable. I re-ran everything independently: **201 examples across the ten new/changed unit specs, 0 failed, 0 errors**, plus `openai_tool_loop_spec` PASS in the full run and the conformance spec skipping loudly; `make lint` **0 warnings / 0 errors in 325 files**. The two integration failures in `make test` (`git_markdown_source_spec`, `markdown_finder_async_spec`) both pass in isolation and touch nothing in this diff — parallel-runner interference, not this work. Nothing rises to Critical. What keeps it off SHIP is four cheap Important items, one of them a confirmed functional gap on a path this issue newly opened: `skill_invoke`'s large-document headroom bump writes `max_tokens`, which the gpt-5 family's own param schema deliberately renames to `max_completion_tokens` — so on exactly the models #198 enables, the bump is a no-op and the cap stays 4096.

## 1. Strengths

- **The "verbatim move" claim is verifiable and verified.** `git diff 95e4b52^..HEAD -- tests/unit/anthropic_tool_{encode,decode}_spec.lua` is empty and both still pass — the right proof for a refactor milestone, and it caught nothing precisely because the move was clean.
- **The route unification is an invariant, not an assertion.** `providers.cliproxy_route` (`lua/parley/providers.lua:181-189`) is consumed by `cliproxyapi.format_payload:989` and `cliproxyapi_encode_tools:1298`, and `tests/unit/openai_payload_tools_spec.lua:93-121` pins agreement across four (model, strategy) pairs by reading the payload's own `_parley_route` stamp. The latent bug the issue names cannot recur silently.
- **`sse.str` fixes the `vim.NIL` class rather than the site.** `lua/parley/sse.lua:52-58` plus its use at every optional-field read in *both* decoders (`wire_openai.lua:138-146`, `wire_anthropic.lua:105-112`) is the correct generalization of the M1 Critical, and `anthropic_tool_wire_spec.lua` pins it on the wire that never exhibited it.
- **The decoder's resilience contract is genuinely tested.** Malformed `arguments`, absent `arguments`, a truncated stream with no `finish_reason`, a non-list `tool_calls`, a missing `index`, and — the subtle one — a nameless continuation entry dropped rather than surfaced as an unexecutable ToolCall (`wire_openai.lua:156-165`), each with a case in `openai_tool_decode_spec.lua`.
- **ARCH-MOCK is real, not a shape.** `tests/fixtures/fake_cliproxy`'s tool mode decides which round it is in by inspecting the **request** (`any(m.get("role") == "tool" …)`) rather than a counter, so it is correct under retries; `openai_tool_loop_spec.lua` then drives real curl → real SSE → real decoder → real tool dispatcher → real 🔧:/📎: writes with nothing stubbed on parley's side. `cliproxy_tool_conformance_spec.lua` reuses a running proxy read-only, gated behind `PARLEY_LIVE_CONFORMANCE=1`, with the #197 rotation-race hazard called out — I confirmed it skips loudly and cleanly.
- **The e2e evidence in `## Log` is captured output, not a claim** — a sentinel token the model could not have guessed, two sequential tool rounds plus a `utm_source=openai` citation in one turn, and an instrumented `wire=openai` line for the `force_tool` skill path.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `skill_invoke`'s large-document headroom bump is a no-op for gpt-5-family models, i.e. exactly the models this issue enables for skills.** `lua/parley/skill_invoke.lua:219`

```lua
payload.max_tokens = math.max(payload.max_tokens or 0, 100000)
```

`provider_params.lua:131-140` overrides `^gpt%-5` with `max_tokens = { api_name = "max_completion_tokens", default = 4096 }`, so after `format_payload` the payload has **no `max_tokens` key at all**. Verified by driving the real `prepare_payload`:

```
cliproxyapi  gpt-5.6-sol   payload.max_tokens=nil   max_completion_tokens=4096
   AFTER skill bump: max_tokens=100000  max_completion_tokens=4096
openai       gpt-5.4       payload.max_tokens=nil   max_completion_tokens=4096
   AFTER skill bump: max_tokens=100000  max_completion_tokens=4096
anthropic    claude-sonnet-5  payload.max_tokens=4096   → bump works (100000)
```

Two consequences. (a) The effective cap stays 4096 — which is precisely the truncation the line's own comment says it exists to prevent ("truncating the tool JSON → empty decode"). A multi-edit `propose_edits` batch on a large artifact will silently truncate and decode to zero calls on an OpenAI-family agent, reported as "model returned no tool call". (b) A stray `max_tokens` now rides along on a family whose schema deliberately renames it; OpenAI's API rejects `max_tokens` on gpt-5/o-series ("Unsupported parameter… Use `max_completion_tokens`"). cliproxy evidently tolerates it (the Log's e2e succeeded), but the plain `openai` provider is a plausible 400.

This path is newly reachable: before this diff, `skill_assembly.resolve_agent` tier 4 accepted only anthropic/cliproxyapi and `openai_encode_tools` raised. Task 2.3 widened the predicate.

Fix sketch — bump the key the wire actually uses:
```lua
local CAP = 100000
if payload.max_completion_tokens then
    payload.max_completion_tokens = math.max(payload.max_completion_tokens, CAP)
else
    payload.max_tokens = math.max(payload.max_tokens or 0, CAP)
end
```
Test: assert the effective cap for `{provider="cliproxyapi", model={model="gpt-5.6-sol"}}` is ≥100000 and that no key the schema renamed away is added.

**I2 — none of the twelve new #198 files are registered in `atlas/traceability.yaml`.** `atlas/traceability.yaml:434-464`

`providers/tool_use` still lists only the pre-#198 surface. I checked each new file; every one returns 0 occurrences:

```
lua/parley/sse.lua, tools/wire.lua, tools/wire_anthropic.lua, tools/wire_openai.lua
tests/unit/{openai_tool_encode,openai_tool_decode,openai_message_translate,
            tool_wire_registry,anthropic_tool_wire,openai_payload_tools}_spec.lua
tests/integration/{openai_tool_loop,cliproxy_tool_conformance}_spec.lua
```

`make test-spec SPEC=providers/tool_use` (documented in TOOLING.md:7, backed by `scripts/spec_test_map.sh`) therefore runs **none** of the new suite, and the atlas code↔test map claims the tool_use surface has no wire layer. `make test` globs everything so CI is unaffected — this is the spec-selection map and the Docs update gate. #197 in this same window registered all six of its new files (the diff shows the additions under `providers/cliproxy-managed`); #198 registered zero. The plan flagged it too, in Task 1.1 Step 2: "*Register the new files in `atlas/traceability.yaml` first, or the runner will not see the spec at all.*"

**I3 — the production entry point for the whole feature has no automated coverage; delete two lines and the suite stays green while every OpenAI-family tool agent goes silent.** `lua/parley/chat_respond.lua:1851-1852`

`provider = agent_info.provider` / `model = agent_info.model` is the single point where the wire selector reaches `tool_loop` in production. Nothing tests it: `tool_loop_spec.lua` constructs `agent_info` inline; `openai_tool_loop_spec.lua` does too and says so explicitly (`:100` — "is exactly what chat_respond's on_exit does"); and every tool case in `chat_respond_spec.lua` uses `ToolSonnet` (anthropic), which resolves correctly with or without the threading because `tool_loop` defaults to `"anthropic"`. So removing those two lines restores the exact M1→M2 regression this milestone exists to close — a valid request, zero decoded calls, an empty answer — with the full suite green. The plan's Task 2.4 Step 2 specified "drive a chat buffer through `chat_respond`"; the shipped spec composes `dispatcher.query` + `tool_loop.process_response` by hand instead. This is the same deletability class the M1 review used on `recover_query`'s registration.

**I4 — the plan is 0 of 84 checkboxes ticked, and the M2 design deviation is unrecorded.** `workshop/plans/000198-openai-family-tool-use-plan.md`

The commit titled `workshop: #198 tick M2 in the plan` (4ca5c90) touched only the *issue* file. The plan has a `## Revisions` section for M1 deviations and nothing for M2 — yet M2 replaced Task 2.1 Step 4's specified mechanism. The plan said: "*call `wire.has_tool_calls(provider, model, qt.raw_response)`… Do NOT recompute a route here — `has_tool_calls` takes the model and resolves internally.*" What shipped is a **payload stamp**: `_parley_tool_wire` (`dispatcher.lua:149`), consumed onto the query table (`:201-211`), plus three new registry functions (`by_name`, `name_for`, `has_tool_calls_by_name`) and a field two places must strip (`query` and `scripts/parley_harness.lua:98`). The reason is sound and documented in code — `qt` has no model table — but it is a materially different design, and it is the last boundary before archival. This repeats the #197 close review's own recommendation ("*Tick what shipped… at 1/56 the next reviewer's traceability pass is meaningless*") at 0/84.

## 4. Minor findings

- `lua/parley/tools/wire.lua:92` — `decode_by_name` has no callers anywhere (only `has_tool_calls_by_name` uses `by_name`). Dead on arrival.
- `lua/parley/tool_loop.lua:7` — module header still documents `providers.decode_anthropic_tool_calls_from_stream (Task 2.4)` as the decode step.
- `lua/parley/skill_assembly.lua:1-8` — header claims "No IO, no `require("parley")` here", but `resolve_agent:96` now reaches `wire.resolve` → `providers.cliproxy_strategy` → `pcall(require, "parley")` for ambient config. Outcome-neutral today (cliproxyapi resolves to *some* wire either way), but the claim is false (ARCH-PURE).
- `lua/parley/providers.lua:149-152` — `cliproxy_strategy`'s docstring says "PURE" while reading module-global `parley.dispatcher.providers`. Carried unfixed from the M1 review.
- `lua/parley/providers.lua:1038` — `cliproxyapi.parse_sse_progress_event` still selects its parser from `get_cliproxy_strategy(nil)` rather than the resolved wire, so a config-level `anthropic_tools_route` sends every openai-route response through the anthropic progress parser. Cosmetic (the transient status line), but `qt.tool_wire` is now in scope at the call site (`dispatcher.lua:286` already reads `qt.provider`).
- `lua/parley/tools/wire.lua:107` reads a bare-string model as a model *name* while `cliproxyapi.format_payload:985` discards it (`type(model) == "table" and model.model or nil`) — they disagree for string models. Unreachable via `prepare_payload` (which short-circuits strings at `:100`); reachable only through the public `cliproxyapi_encode_tools`, which `openai_payload_tools_spec.lua:88` exercises with a string.
- `workshop/lessons.md` — all four #198 rules (`sse.str`/`vim.NIL`, the self-branching test, milestone-splitting, "OpenAI-compatible ≠ shares the builder") are filed under the `## 2026-08-01 (#197)` heading. Every other entry in the file is `## <date> (#N)`; there is no `## 2026-08-15 (#198)`, so a reader grepping `#198` finds nothing.
- `atlas/providers/tool_use.md` — "the read paths resolve via `wire.by_name`" overstates: only the `empty_response` probe does; `tool_loop` and `skill_invoke` resolve by `(provider, model)`.
- The issue `## Log` attributes the two integration failures to a restricted sandbox blocking `git init` hook-template copying. I reproduced them **unsandboxed** under the parallel runner, and both pass in isolation (11/0/0 and 3/0/0) — the cause is runner interference, not sandboxing. Worth correcting since this is the close's verification evidence.
- `wire_openai.translate_messages:271-297` — the non-assistant branch silently drops any block that is neither `tool_result` nor `text`, dropping the whole message when nothing matches. Unreachable today (parley builds no multimodal content blocks; the only table-content user messages come from `_emit_content_blocks_as_messages` and from `system_prompt_msgs` on the anthropic-only `cache_control` path), but it would fail silently rather than loudly.
- **Window note:** the computed window `375b635..HEAD` is 54 commits and includes all 33 of #197's, because `merge-base main HEAD == 375b635` — #197 never merged to main. #197 already has its own close review on disk, so I scoped this review to #198's 21 commits (`95e4b52^..HEAD`) plus the shared surfaces they touch.

## 5. Test coverage notes

Measured first-hand, not read from the Log: `openai_tool_decode` 20, `tool_wire_registry` 26, `anthropic_tool_wire` 15, `openai_message_translate` 13, `openai_payload_tools` 12, `skill_assembly` 12, `openai_tool_encode` 10, `parley_harness_golden` 11, `tool_loop` 18, `dispatcher` 64 — **201 examples, 0 failed, 0 errors**. `cliproxy_tool_conformance` skips cleanly (2/0/0). `openai_tool_loop_spec` PASS in the full integration run. `make lint` 0/0 in 325 files.

The tests pin real logic rather than restating it: the goldens compare decoded tables with a comment explaining why a byte compare would flake and catch nothing; the route-agreement matrix reads the payload's own stamp; the fake is stateful over the request rather than a counter. The Log's mutation-testing note (index-order 17→16, `empty_dict` removal 10→8) is the right instinct for specs written after the implementation.

Gaps, in the order I'd close them:

1. **The `chat_respond` → `tool_loop` threading** (I3) — the one line the feature hangs on, with zero coverage. One integration case driving `chat_respond` against the fake with a `cliproxyapi`/`gpt-5.6-sol` agent closes it and would have failed the day the lines were deleted.
2. **`skill_invoke`'s token headroom on a non-anthropic wire** (I1) — nothing asserts the effective cap for an OpenAI-family skill agent.
3. **`skill_invoke`'s per-wire `tool_choice` and decode** are covered only by the live e2e in the Log; `skill_invoke_spec` / `skill_invoke_review_spec` reference no OpenAI-family agent. `skill_assembly_spec` covers the widened predicate, but not what the driver does with it.
4. **`wire.decode_by_name`** is untested because unused (see Minor).
5. Latent determinism: every golden — the pre-existing anthropic ones included — depends on `parley._state.web_search` being truthy (it defaults from `config.web_search = true`, but is persisted state). Pre-existing, inherited rather than introduced; worth pinning explicitly in the harness now that there are eleven goldens riding on it.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass.** Three independently hardcoded decode sites (`tool_loop`, `skill_invoke`, `empty_response`) and the dispatcher's five-branch provider chain collapse into one registry; two divergent cliproxy route tests collapse into `cliproxy_route` with an agreement matrix; `safe_json_decode`/`strip_data_prefix` hoist to `sse.lua` instead of becoming a third and fourth copy; `tool_choice` moves from a `skill_assembly` literal to the wire beside `encode_tools`. Residue is one dead function and `parse_sse_progress_event` — the last route decision not derived from the single source (both Minor).
- **ARCH-PURE — pass with a flag.** `sse`, `wire_anthropic`, `wire_openai`, and `wire` are genuinely pure: their 84 assertions run with no mocks and no IO beyond reading checked-in fixtures. Keeping `translate_messages` in the wire rather than forking `_emit_content_blocks_as_messages` is the right call — it leaves `#155`/`#156` single-sourced and lets the translator consume already-validated output. The flag is the ambient read: `cliproxy_strategy` is documented PURE but reaches module-global config, and in M2 that dependency propagated into `skill_assembly.resolve_agent`, whose own header disclaims it. It is outcome-neutral today; the risk is the next person adding a strategy-dependent branch to a function two callers believe is injected. Passing the strategy in (or injecting a resolver) would close it.
- **ARCH-PURPOSE — pass.** Shadow sweep on "who decides the tool wire": `prepare_payload` ✓ (translate + encode), `empty_response` ✓ (stamp), `tool_loop` ✓, `skill_invoke` ✓ (decode + `tool_choice`), `skill_assembly` predicate ✓, `cliproxyapi_encode_tools` ✓, `cliproxyapi.format_payload` ✓ — no provider hardcoded at a call site, and I grepped: the raising `googleai`/`ollama` stubs are gone with their last caller, and `googleai` is honestly absent from `BY_PROVIDER` with an error that names the provider instead of claiming an anthropic-family requirement. Every Done-when is delivered and live-verified. The one under-delivery is on the newly-widened skill path (I1), which is a gap in a path the issue opened rather than a deferred purpose.
- **ARCH-MOCK — pass.** The fake is a stateful process-level double behind the same HTTP seam production uses, reached through the existing spawn path, and the integration spec runs the real stack against it. The live conformance spec asserts the four delta fields the decoder depends on plus `finish_reason == "tool_calls"`, is gated behind an env var, reuses a running proxy read-only, and skips loudly — the right shape, and it carries the #197 safety reasoning forward explicitly.
- **Plan-gate carry-forward:** `workshop/plans/000198-openai-family-tool-use-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)". I re-checked each disposition against the code rather than the ledger — PQ-1 (translation at `prepare_payload`, with `dispatcher_spec.lua`'s "translates for cliproxyapi's openai route (the issue's own target)" as the regression test) ✓, PQ-2 (model-keyed registry with no route parameter; `skill_invoke` and `empty_response` both covered) ✓, PQ-3 (`force_tool` name + per-wire shaping) ✓, PQ-4 (config comment extended, not contradicted) ✓, PQ-5 (`code_execution_*` documented as an intentional change and pinned at `tool_wire_registry_spec.lua:163`) ✓, PQ-6 (`sse.lua` hoist; stubs deleted; `cliproxy_strategy` in the table) ✓, PQ-7 ✓. Nothing to carry.
- **Core-concepts cross-check: no contradictions.** All fifteen pure rows and both integration rows verify at their stated paths — `sse`/`wire_anthropic`/`wire_openai`/`wire` exist; `cliproxy_route` and `cliproxy_strategy` are in `providers.lua`; `anthropic.decode_tool_calls_from_stream` (the adapter method) and both raising stubs are gone while the two published top-level names are retained as the plan directed; `skill_assembly.build_invocation` returns `force_tool`; the Revisions' `sse.str` exists. PURE rows test without mocks; the INTEGRATION rows are process-level doubles, not called from pure logic. The table is *incomplete* rather than wrong — the M2 stamp entities have no rows (see §7).
- **For whoever adds `wire_googleai`:** the seam is ready — one module plus one `BY_PROVIDER` line — but note that `name_for`/`by_name` require a matching `BY_NAME` entry or the response side silently degrades to "no tool calls". Those two tables are hand-maintained on the same axis, which is the drift class #197's own lessons file just recorded; deriving `BY_NAME` from `BY_PROVIDER`, or asserting the correspondence in a spec, would prevent it.

## 7. Plan revision recommendations

Append a `## Revisions` entry to `workshop/plans/000198-openai-family-tool-use-plan.md`:

1. **Record the M2 stamp design.** Task 2.1 Step 4 specifies `wire.has_tool_calls(provider, model, qt.raw_response)`; what shipped is `_parley_tool_wire` stamped by `prepare_payload`, consumed onto the query table by `query` before serialization, and resolved through `wire.by_name` — because `qt` carries no model params table. Record the reason, the field, the two strip sites (`dispatcher.query`, `scripts/parley_harness.lua`), and add Core-concepts rows for `by_name` / `name_for` / `has_tool_calls_by_name` (and either a row for `decode_by_name` or its deletion).
2. **Record that Task 2.4's integration spec does not drive `chat_respond`.** The step says "drive a chat buffer through `chat_respond`"; the spec composes `dispatcher.query` + `tool_loop.process_response`. Either the step or the coverage should change (see I3) — as written the plan claims coverage that does not exist.
3. **Record the golden superset.** Task 2.5 names three OpenAI goldens; four shipped (`openai-mixed-text-and-tools` added). Harmless, but the plan is the greppable record.
4. **Tick what shipped.** 0 of 84 checkboxes are ticked while M1 and M2 are both `[x]` in the issue. This was the #197 close review's recommendation #6 verbatim; at 0/84 the next reviewer's traceability pass is meaningless.
