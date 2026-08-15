# Native OpenAI-Family Tool-Use Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the client-side tool loop work over the OpenAI function-calling wire, so any OpenAI-family model (cliproxy codex channel, plain `openai`, copilot, azure, ollama) can run tools with server-side web search intact.

**Architecture:** Extract the per-wire tool protocol into pure modules under `lua/parley/tools/` — `wire_anthropic` (moved verbatim from `providers.lua`), `wire_openai` (new), and a `wire` registry resolving (provider, model) → module. The registry is the single seam `dispatcher`, `tool_loop`, and `skill_invoke` consume. Anthropic content-block message shape stays canonical internally; `dispatcher.prepare_payload` translates it to OpenAI shape at one point upstream of every adapter, so `chat_respond`'s `#155`/`#156` invariants stay single-sourced.

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim runtime, plenary.nvim busted-style specs, `vim.json`, curl-driven SSE.

**Working-tree dependency:** the `ToolSol*` agent and the `codex` `oauth-model-alias` block in `lua/parley/config.lua` are currently **uncommitted** changes on the `000197-cliproxy-auth-self-healing` branch. They are the e2e target of Task 2.7 and must be carried into this issue's branch, not lost.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `sse` (shared decode helpers) | `lua/parley/sse.lua` | new |
| `wire_anthropic` | `lua/parley/tools/wire_anthropic.lua` | new |
| `wire_openai` | `lua/parley/tools/wire_openai.lua` | new |
| `wire` (registry) | `lua/parley/tools/wire.lua` | new |
| `cliproxy_route` | `lua/parley/providers.lua` | new |
| `cliproxy_strategy` | `lua/parley/providers.lua` | new |
| `anthropic.decode_tool_calls_from_stream` | `lua/parley/providers.lua` | deleted |
| `M.ollama_encode_tools` | `lua/parley/providers.lua` | deleted |
| `M.googleai_encode_tools` | `lua/parley/providers.lua` | deleted |
| `M.anthropic_encode_tools` | `lua/parley/providers.lua` | modified |
| `M.openai_encode_tools` | `lua/parley/providers.lua` | modified |
| `M.cliproxyapi_encode_tools` | `lua/parley/providers.lua` | modified |
| `cliproxyapi.format_payload` | `lua/parley/providers.lua` | modified |
| `skill_assembly.build` (`tool_choice` → `force_tool`) | `lua/parley/skill_assembly.lua` | modified |

- **sse** — `safe_json_decode` + `strip_data_prefix`, today private locals at `providers.lua:28-38`. Both wires need them; hoisting beats a third and fourth copy in a plan that cites ARCH-DRY. `providers.lua` requires it too, so there is one definition.
  - **DRY rationale:** eliminates the copies this plan would otherwise create; also the first shared home for SSE-parsing primitives, which currently exist only as adapter-file locals.

- **wire_anthropic** — the Anthropic tool protocol: `encode_tools`, `encode_tool_choice`, `decode_tool_calls_from_stream`, `has_tool_calls`. A verbatim move of the tool halves of `providers.lua:681-753` and `:1330-1345`.
  - **Relationships:** 1:1 with the `anthropic` adapter; also the wire cliproxyapi selects on its anthropic route.
  - **DRY rationale:** first half of the symmetry. The Anthropic protocol is currently interleaved with adapter concerns (headers, payload, usage) in a 1379-line file; adding a second protocol inline doubles that. Extraction makes "what must a wire implement" a readable contract rather than a convention.
  - **Future extensions:** `wire_googleai` (`functionDeclarations`) drops in beside it without touching `providers.lua`.

- **wire_openai** — the OpenAI function-calling protocol: the same four functions plus `translate_messages` (Anthropic content-block messages → OpenAI `tool_calls` / `role:"tool"` shape).
  - **Relationships:** 1:1 with the `openai` adapter; also the wire for copilot, azure, ollama, and cliproxyapi's OpenAI route.
  - **DRY rationale:** `translate_messages` exists so `_emit_content_blocks_as_messages` (`chat_respond.lua:576-700`) is NOT forked per provider. That function is the only place `#155` (no dangling `tool_use`) and `#156` (no orphan `tool_result`) are enforced; a provider-parameterized emitter would implement those invariants twice.
  - **Future extensions:** `strict` function schemas, `parallel_tool_calls: false`.

- **wire** — registry resolving (provider, model) → wire module, plus `encode` / `encode_tool_choice` / `decode` / `has_tool_calls` / `translate_messages` pass-throughs.
  - **Relationships:** N:1 — many consumers, one registry; 1:N over wire modules.
  - **DRY rationale:** collapses three hardcoded decode sites (`tool_loop.lua:193`, `skill_invoke.lua:252`, `dispatcher.lua:326`) and the dispatcher's five-branch provider chain (`dispatcher.lua:114-131`) into one lookup.
  - **Critical design constraint:** the public API takes **`model`, not `route`**. The registry derives the cliproxy route itself, so no consumer can forget to pass it. A route-taking API defaults `nil` to *some* wire, and a caller that forgets silently decodes zero tool calls — indistinguishable from a truncated response. `for_provider(provider, route)` remains as the low-level form, used only by `resolve`.
  - **Future extensions:** wires could declare capabilities (`supports_parallel_calls`) consumers query rather than special-case.

- **cliproxy_route** — pure `(model_name, strategy) → "anthropic" | "openai"`.
  - **DRY rationale:** `cliproxyapi.format_payload` and `cliproxyapi_encode_tools` currently make this decision by two *different* tests — the former checks strategy AND family (`providers.lua:1034-1037`), the latter checks `^claude%-` alone (`:1372`). They can disagree; that is the latent bug in the issue. One function, three callers.
  - **NOT purely behavior-preserving:** today `cliproxyapi_encode_tools` *raises* for a `code_execution_*` model, because its `^claude%-` test excludes it, while `format_payload` routes it to the anthropic wire. After extraction such a model encodes correctly. That is a fix, and the `cliproxy_route` spec should name it as an intentional change rather than claim pure extraction.

- **cliproxy_strategy** — pure wrapper exposing the existing `get_cliproxy_strategy` local (`providers.lua:102-121`), which falls back from the model table to the **config-level** `providers.cliproxyapi.web_search_strategy`. Consumers must not re-implement that fallback by reading `model.web_search_strategy` directly.

**Route selection is deliberately unchanged.** `cliproxy_route` returns `"anthropic"` iff the model is anthropic-family *and* the strategy is `anthropic_tools_route` — today's rule, extracted rather than rewritten. Both wires support tools afterwards, so `ToolSol*` gets tools on the OpenAI route its config already selects, and the three claude `Tool*` agents keep the Anthropic route (where `server_tool_use` web search works, confirmed by the operator). Changing routing is not needed to deliver the goal (Simplicity First).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `fake_cliproxy` tool mode | `tests/fixtures/fake_cliproxy` | modified | cliproxyapi HTTP |
| cliproxy tool-wire conformance | `tests/integration/cliproxy_tool_conformance_spec.lua` | new | real cliproxyapi binary |

- **fake_cliproxy tool mode** — a new response-mode selector making `POST /v1/chat/completions` answer with the captured OpenAI `tool_calls` delta stream. **Stateful**: the first request gets the tool stream; a request whose body contains a `role:"tool"` message gets a plain completion. That statefulness is the point — it models the two-round loop, so an integration spec drives real `tool_loop` recursion against a subprocess rather than function mocks.
  - **Injected into:** nothing pure — a process-level double behind the same HTTP seam the real binary sits behind, reached through the existing spawn path.
  - **Future extensions:** a malformed-arguments mode for decoder resilience.

- **cliproxy tool-wire conformance** — boots against the REAL binary and asserts the fields the decoder depends on still exist (`delta.tool_calls[].index`, `.id`, `.function.name`, `.function.arguments`, `finish_reason == "tool_calls"`), mirroring `cliproxy_conformance_spec.lua`'s `REQUIRED_FIELDS` pattern.
  - **SAFETY:** a live tool call needs a real credential, so this spec must **skip unless `PARLEY_LIVE_CONFORMANCE=1`** and must reuse an already-running proxy read-only. It must NOT spawn a second proxy against a live auth-dir — that is the #197 OAuth-rotation race.

---

## Chunk 1: M1 — the pure wire layer

No consumer is rewired in M1. At its end the wire modules exist, are unit-tested against captured real fixtures, and `providers.lua` delegates its encoders to them — but `tool_loop` / `skill_invoke` / `dispatcher` still call the functions they call today, and every existing spec passes untouched. That is the milestone's proof of a behavior-preserving refactor.

**Test strategy for this chunk:** each function gets a spec named for it in `tests/unit/`. Rather than enumerate cases the implementer will rewrite anyway, each task names the *risky* behaviors the spec must pin — those are the ones a plausible implementation gets wrong.

### Task 1.1: Hoist the shared SSE helpers

**Files:**
- Create: `lua/parley/sse.lua`
- Modify: `lua/parley/providers.lua:28-38`

- [x] **Step 1: Create `lua/parley/sse.lua`** with `safe_json_decode` and `strip_data_prefix`, bodies copied verbatim from `providers.lua:28-38`.
- [x] **Step 2: Replace the locals in `providers.lua`** with `local sse = require("parley.sse")` and local aliases, so the ~20 existing call sites are untouched.
- [x] **Step 3: Run the full suite** — `make test`. Expected: PASS, unchanged. A pure move.
- [x] **Step 4: Commit** — `git commit -am "providers: #198 M1: hoist shared SSE decode helpers"`

### Task 1.2: Move the Anthropic wire out of providers.lua

**Files:**
- Create: `lua/parley/tools/wire_anthropic.lua`
- Modify: `lua/parley/providers.lua:681-753` (delete `anthropic.decode_tool_calls_from_stream`), `:1330-1345` (`M.anthropic_encode_tools` → delegate)
- Test: `tests/unit/anthropic_tool_encode_spec.lua`, `tests/unit/anthropic_tool_decode_spec.lua` — **UNCHANGED**, they are the regression proof

- [x] **Step 1: Run the existing Anthropic specs for a green baseline.** Record the test count; it must be identical after the move.

Run: `nvim --headless -c "PlenaryBustedFile tests/unit/anthropic_tool_decode_spec.lua"`

- [x] **Step 2: Create the module** with `encode_tools` and `decode_tool_calls_from_stream` moved verbatim (including the documented `server_tool_use` / thinking-block exclusions), requiring `parley.sse` for the helpers.

- [x] **Step 3: Add the two functions that are NOT moves:**

```lua
--- Cheap predicate for dispatcher's empty_response check.
function M.has_tool_calls(raw_response)
    return type(raw_response) == "string"
        and raw_response:find('"type":"tool_use"', 1, true) ~= nil
end

--- Compel a specific tool this turn (skill manifests' force_tool).
function M.encode_tool_choice(tool_name)
    return { type = "tool", name = tool_name }
end
```

`has_tool_calls` promotes the `dispatcher.lua:326` literal to the wire (keep the plain-text `find(..., true)` form — the existing line depends on plain matching). `encode_tool_choice` promotes `skill_assembly.lua:37`'s literal. Neither changes behavior yet; M2 routes the call sites here.

- [x] **Step 4: Delegate from `providers.lua`.** Keep BOTH public names — `M.anthropic_encode_tools` and `M.decode_anthropic_tool_calls_from_stream` — since the untouched specs and `skill_invoke.lua:252` call them.

- [x] **Step 5: Re-run Step 1's command.** Expected: PASS, identical count. A differing count means the move was not verbatim.

- [x] **Step 6: Commit**

```bash
git commit -am "providers: #198 M1: extract the anthropic tool wire

Behavior-preserving move ahead of adding a second wire. The existing
anthropic tool specs are unchanged and still pass — that is the proof."
```

### Task 1.3: Capture real OpenAI wire fixtures

**Files:**
- Create: `tests/fixtures/openai_tool_use_stream.sse`, `tests/fixtures/openai_parallel_tool_calls.sse`

Captures from the operator's live cliproxyapi 7.2.110 are staged in the session scratchpad (`wire/openai_*.sse`); copy them in rather than re-issuing billable calls. Strip nothing — the specs must exercise the real interleaving (usage chunk, `[DONE]` sentinel, ignored `native_finish_reason` fields).

- [x] **Step 1: Copy the staged captures in.**
- [x] **Step 2: Record provenance** (`captured 2026-08-15 from cliproxyapi 7.2.110, model gpt-5.6-sol`) in the spec that loads them — SSE files cannot carry comments. This is what a re-capture must reproduce.
- [x] **Step 3: Commit.**

### Task 1.4: `wire_openai.encode_tools` + `encode_tool_choice`

**Files:**
- Create: `lua/parley/tools/wire_openai.lua`
- Test: `tests/unit/openai_tool_encode_spec.lua`

Target shape: `{type="function", ["function"]={name, description, parameters=input_schema}}`. `["function"]` bracket syntax is required — `function` is a Lua keyword. `encode_tool_choice(name)` returns `{type="function", ["function"]={name=name}}`.

- [x] **Step 1: Write the failing spec.** Pin, in order of likelihood-of-getting-wrong:
  - **an empty `input_schema` encodes as `{}`, not `[]`** — an empty Lua table JSON-encodes as an array and OpenAI rejects it where an object schema belongs. `vim.empty_dict()` is the fix; `_emit_content_blocks_as_messages` already hit this at `chat_respond.lua:669-675`.
  - internal `ToolDefinition` fields (`handler`, `kind`, `needs_backup`) never reach the payload.
  - `nil` input returns `{}`.

  Follow `tests/unit/anthropic_tool_encode_spec.lua:26-34`'s `registry.reset()` / `registry.register_builtins()` before/after pair — omitting the restore breaks later specs sharing the process.
- [x] **Step 2: Run to verify it fails** (`module 'parley.tools.wire_openai' not found`).
- [x] **Step 3: Implement.**
- [x] **Step 4: Run to verify it passes.**
- [x] **Step 5: Commit.**

### Task 1.5: `wire_openai.decode_tool_calls_from_stream`

**Files:**
- Modify: `lua/parley/tools/wire_openai.lua`
- Test: `tests/unit/openai_tool_decode_spec.lua`

The hard one. Unlike Anthropic — explicit `content_block_start`/`_stop` framing around a top-level `.index` — OpenAI streams an *array* of partial `tool_calls`: `id` and `function.name` arrive only in the first chunk for an index, `function.arguments` accumulates as string fragments, and **nothing closes a call**.

- [x] **Step 1: Write the failing spec.** Pin these behaviors:
  - a call split across chunks reassembles (`{"city":` + `"Paris"}` → `{city="Paris"}`).
  - **parallel calls stay separate and ordered** — distinct `index` values, order of *first appearance*, not numeric order. This is the case the real fixture covers.
  - **resilience, all four:** missing arguments, malformed-JSON arguments, a stream cut short with no `finish_reason`, and a plain-text response — each yields `input = {}` or `{}` overall and **never raises**. A raising decoder breaks the chat buffer mid-loop.
  - the real-fixture assertion against `tests/fixtures/openai_parallel_tool_calls.sse`: two `get_weather` calls, `{city="Paris"}` then `{city="Tokyo"}`.
- [x] **Step 2: Run to verify it fails.**
- [x] **Step 3: Implement.** Accumulate into `by_index[idx] = {id, name, parts={}}` with a separate `order` list of first appearance; at the end `table.concat(parts)` and `pcall(vim.json.decode)`, defaulting `input` to `{}`.

  **Deliberately NOT gated on `finish_reason == "tool_calls"`:** a truncated stream still yields whatever assembled, and `tool_loop` already writes synthetic 📎: results for calls it cannot resolve (`tool_loop.lua:81-97`). Gating would drop them silently and strand the buffer with an unmatched 🔧:.
- [x] **Step 4: Run to verify it passes.**
- [x] **Step 5: Add `has_tool_calls`** (plain-text find for `"tool_calls"`) with a two-case test: plain-text stream false, tool stream true.
- [x] **Step 6: Commit.**

### Task 1.6: `wire_openai.translate_messages`

**Files:**
- Modify: `lua/parley/tools/wire_openai.lua`
- Test: `tests/unit/openai_message_translate_spec.lua`

Input is whatever `_emit_content_blocks_as_messages` produced — already `#155`/`#156`-validated. Output is OpenAI shape.

- [x] **Step 1: Write the failing spec.** Pin:
  - **string-content messages are returned by exact identity.** This is the majority path — every tool-less OpenAI chat in the plugin flows through it. Get this wrong and every existing chat changes shape.
  - assistant `[text, tool_use]` → `content` + `tool_calls[]`, with `arguments` a **JSON string**, not a table.
  - a user `[tool_result, tool_result]` batch → **two separate `{role="tool", tool_call_id=…}` messages**, order preserved.
  - `is_error` folds into the content string (prefix `Error: `) — OpenAI has no wire equivalent, and without it the model cannot tell a failed call from a successful one returning error text.
  - a tool-only assistant turn leaves `content` **nil**, not `""` — the live round-trip used explicit `null` and was accepted; `""` risks reading as a real empty answer.
  - empty tool input encodes as `arguments == "{}"`.
  - a full two-round loop preserves message order end to end.
- [x] **Step 2: Run to verify it fails.**
- [x] **Step 3: Implement.** Messages whose `content` is not a table pass straight through. Assistant tables split into joined text + `tool_calls`; non-assistant tables emit one `role="tool"` message per `tool_result` (and a `role="user"` message for any stray text blocks).
- [x] **Step 4: Run to verify it passes.**
- [x] **Step 5: Commit.**

### Task 1.7: The `wire` registry

**Files:**
- Create: `lua/parley/tools/wire.lua`
- Modify: `lua/parley/providers.lua` (add `M.cliproxy_route`, `M.cliproxy_strategy`)
- Test: `tests/unit/tool_wire_registry_spec.lua`, `tests/unit/cliproxy_route_spec.lua`

- [x] **Step 1: Write the failing specs.** For the registry, pin:
  - `anthropic` → anthropic wire; `openai` / `copilot` / `azure` / `ollama` → openai wire.
  - **`cliproxyapi` resolves by MODEL, deriving the route internally** — `{model="claude-sonnet-5", web_search_strategy="anthropic_tools_route"}` → anthropic wire; `{model="gpt-5.6-sol"}` → openai wire. There is no route parameter on the public API to forget.
  - `googleai` → nil; `decode`/`has_tool_calls` degrade to `{}`/`false` for it, while `encode` raises naming the provider.

  For `cliproxy_route`, pin today's matrix — anthropic-family + `anthropic_tools_route` → `"anthropic"`; anthropic-family without the strategy → `"openai"`; non-anthropic model → `"openai"` regardless of strategy; nil model → `"openai"` — **plus** the one intentional change: `code_execution_*` + `anthropic_tools_route` → `"anthropic"`, which the current `cliproxyapi_encode_tools` would have raised on.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement the registry**, public API keyed on `(provider, model)`:

```lua
function M.resolve(provider, model)
    if provider == "cliproxyapi" then
        local providers = require("parley.providers")
        local model_name = type(model) == "table" and model.model or model
        local route = providers.cliproxy_route(model_name, providers.cliproxy_strategy(model))
        return route == "anthropic" and anthropic or openai
    end
    return BY_PROVIDER[provider]
end
```

`encode` raises when no wire resolves (an agent asked for tools the provider cannot carry — fail fast at request time). `decode` / `has_tool_calls` / `translate_messages` degrade quietly, since they run on every response including from non-tool agents.

- [x] **Step 4: Implement `cliproxy_route` and `cliproxy_strategy`** in `providers.lua`, the former extracted from `is_cliproxy_anthropic_route_model` (`:144-149`) plus the strategy test at `:1037`, the latter exposing the existing `get_cliproxy_strategy` local **including its config-level fallback**.
- [x] **Step 5: Run to verify they pass.**
- [x] **Step 6: Commit.**

### Task 1.8: Point the encoders at the registry

**Files:**
- Modify: `lua/parley/providers.lua:1348-1362` (`openai_encode_tools`; **delete** `googleai_encode_tools` and `ollama_encode_tools`), `:1364-1377` (`cliproxyapi_encode_tools`), `:1031-1058` (`cliproxyapi.format_payload` branch test)
- Test: `tests/unit/openai_payload_tools_spec.lua`

The two deleted stubs become unreachable once M2 replaces the dispatcher's provider chain (`dispatcher.lua:124-126` is their only caller). Delete them here and let M2's chain removal land in the same issue; leaving dead raising stubs behind is the kind of residue ARCH-PURPOSE flags.

- [x] **Step 1: Write the failing spec.** Pin: `openai_encode_tools` no longer raises and emits `type == "function"`; `cliproxyapi_encode_tools` emits `type == "function"` for `gpt-5.6-sol` and still emits `input_schema` for `claude-sonnet-5` + `anthropic_tools_route`.
- [x] **Step 2: Run to verify it fails** (both encoders raise today).
- [x] **Step 3: Implement** — both encoders become one-line delegations to `wire.encode(provider, model, defs)`, and `cliproxyapi.format_payload`'s branch test becomes `if M.cliproxy_route(model_name, strategy) == "anthropic" then`, replacing `strategy == "anthropic_tools_route" and use_anthropic_route`. `use_code_execution_model` stays — it gates `tool_choice`, not the route.
- [x] **Step 4: Run the FULL suite** — `make test`. `tests/unit/parley_harness_golden_spec.lua` must be green: the Anthropic goldens prove nothing disturbed the anthropic path.
- [x] **Step 5: Commit.**

### Task 1.9: Close M1

- [x] **Step 1: `make test`** — green, no new failures vs. the Task 1.2 baseline.
- [x] **Step 2: luacheck** clean (see TOOLING.md).
- [x] **Step 3: Update `atlas/`** for the new `lua/parley/sse.lua` + `lua/parley/tools/wire*.lua` surface; keep `atlas/index.md` linking every file (AGENTS.md §8 — at the milestone, not deferred).
- [x] **Step 4: `sdlc milestone-close --issue 198 --milestone M1`** — the binary dispatches the mandatory fresh-eyes review itself (AGENTS.md §3; do NOT separately run `superpowers-requesting-code-review`). Fix Critical/Important before crossing; log the verdict in `## Log`.

---

## Chunk 2: M2 — wire it up

M1 built the protocol; M2 makes the running system use it.

### Task 2.1: Translate and encode at the dispatcher seam

**Files:**
- Modify: `lua/parley/dispatcher.lua:99-143` (`prepare_payload`), `:325-327` (`empty_response`)
- Test: `tests/unit/dispatcher_spec.lua`

**This task carries the Critical fix.** `translate_messages` must NOT be installed in `openai.format_payload`: cliproxy's OpenAI route uses its own builder (`cliproxy_openai_payload`, `providers.lua:999-1029`, called at `:1057`) and `ollama.format_payload` (`:1165-1177`) is independent too — only copilot (`:963`) and azure (`:1140`) delegate. Installing it there would leave `ToolSol*`, the issue's own trigger, sending Anthropic content-block arrays to the codex channel while every unit test and golden still passed.

`prepare_payload` is the one point upstream of **all** payload builders, and it is already where tools are encoded and appended — so both halves of the wire decision live together.

- [x] **Step 1: Write the failing tests.** Pin:
  - **`cliproxyapi` + `gpt-5.6-sol` + content-block history → `payload.messages` contains a `role == "tool"` message.** This is the regression test for the Critical; it must exercise the *cliproxy* path, not `providers.get("openai")`.
  - the same for provider `openai`, and for `ollama`.
  - `anthropic` and cliproxy's anthropic route are **not** translated — content blocks survive as-is.
  - tools encode to the right shape per provider/model.
  - **the APPEND invariant:** with `web_search` on, server-side tools already in `payload.tools` survive and client tools follow them (the #81 Task 1.0 discovery — a regression here is silent).
  - the config-level strategy fallback: a cliproxy model table with no `web_search_strategy` still routes per `providers.cliproxyapi.web_search_strategy`.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement.** Resolve the wire once, translate if it can, then build and encode:

```lua
    local w = require("parley.tools.wire").resolve(provider, model)
    if w and w.translate_messages then
        messages = w.translate_messages(messages)
    end
    local payload = adapter.format_payload(messages, model, provider)

    if agent_tools and #agent_tools > 0 then
        local defs = require("parley.tools").select(agent_tools)
        local client_tools = require("parley.tools.wire").encode(provider, model, defs)
        payload.tools = payload.tools or {}
        for _, t in ipairs(client_tools) do
            table.insert(payload.tools, t)
        end
    end
```

Translation is **unconditional**, not gated on this request declaring tools — a prior turn's tool blocks live in history and must translate on every subsequent request. The `translate_messages` capability check replaces a per-provider branch: only `wire_openai` defines it. This deletes the five-branch chain at `:114-131`.

- [x] **Step 4: Fix the `empty_response` predicate.** `dispatcher.lua:326` hardcodes the Anthropic literal, so a tool-only turn from an OpenAI-family agent would report an empty response. Thread `provider` + `model` onto `qt` at query creation and call `wire.has_tool_calls(provider, model, qt.raw_response)`, inverted. Do NOT recompute a route here — `has_tool_calls` takes the model and resolves internally. Add a test pinning **both** a cliproxy anthropic-route tool turn and a cliproxy openai-route tool turn as non-empty.
- [x] **Step 5: Run to verify they pass.**
- [x] **Step 6: Commit.**

### Task 2.2: Provider-aware decode in the tool loop

**Files:**
- Modify: `lua/parley/tool_loop.lua:189-199`, `lua/parley/chat_respond.lua:1847-1852`
- Test: `tests/unit/tool_loop_spec.lua`

- [x] **Step 1: Write the failing test** — `process_response` given an OpenAI `tool_calls` stream plus `agent_info = {provider="openai", model=…}` writes 🔧:/📎: blocks and returns `"recurse"`; the same stream with no provider (Anthropic default) returns `"done"`; an Anthropic stream with a cliproxy anthropic-route model still returns `"recurse"`.
- [x] **Step 2: Run to verify it fails.**
- [x] **Step 3: Implement** — replace `providers.decode_anthropic_tool_calls_from_stream(...)` with `wire.decode(agent_info.provider, agent_info.model, raw_response or "")`. Default `provider` to `"anthropic"` when absent, so existing callers and the buffer-rebuild fallback path (`tool_loop.lua:206-222`) keep working.
- [x] **Step 4: Pass provider + model from `chat_respond`** — the `agent_info` table built inline at `:1847` gains them alongside `root_policy`.
- [x] **Step 5: Run to verify it passes.**
- [x] **Step 6: Commit.**

### Task 2.3: skill_invoke — decode, tool_choice, and the capability predicate

**Files:**
- Modify: `lua/parley/skill_invoke.lua:252` (decode), `:209-211` (tool_choice), `lua/parley/skill_assembly.lua:35-38` (emit `force_tool`, not a wire shape), `:93` (tool-capable predicate)
- Test: `tests/unit/skill_assembly_spec.lua`, `tests/unit/skill_invoke_spec.lua`

Three coupled changes; splitting them ships a broken intermediate.

- [x] **Step 1: Write the failing tests.** Pin:
  - `skill_invoke`'s decode resolves by `(agent.provider, agent.model)` — **the same pair already in scope at `:208`**. Test a cliproxy **anthropic-route** agent decodes its tool call; without the model this silently yields zero calls and the path logs "model returned no tool call", indistinguishable from a truncated response.
  - `skill_assembly.build` returns `force_tool = "propose_edits"` (a plain name) rather than a wire-shaped `tool_choice` table.
  - `skill_invoke` encodes that name per-wire at payload time: `{type="tool", name=…}` for anthropic, `{type="function", function={name=…}}` for openai.
  - `resolve_agent`'s tool-capable fallback accepts an `openai`-provider agent.
- [x] **Step 2: Run to verify they fail.**
- [x] **Step 3: Implement.** `skill_assembly.lua:37` stops constructing Anthropic's shape (moved to `wire_anthropic.encode_tool_choice` in Task 1.2); `skill_invoke.lua:209` calls `wire.encode_tool_choice(agent.provider, agent.model, inv.force_tool)`. Widen `skill_assembly.lua:93` to `wire.resolve(agent.provider, agent.model) ~= nil`.

  **Why this is in scope:** widening the predicate without translating `tool_choice` would hand the review skill to an agent it 400s against. Both shipped `force_tool` skills (`skills/review/init.lua:500` and `skills/voice_apply/init.lua:31`, both `propose_edits`) go through this path. `tool_choice` is wire knowledge and belongs beside `encode_tools` (ARCH-PURPOSE).
- [x] **Step 4: Run to verify they pass.**
- [x] **Step 5: Commit.**

### Task 2.4: Teach `fake_cliproxy` to call tools

**Files:**
- Modify: `tests/fixtures/fake_cliproxy`
- Create: `tests/integration/openai_tool_loop_spec.lua`

- [x] **Step 1: Add a stateful `tool_call` response mode**, selected like the existing error modes (`--response-mode` / `PARLEY_FAKE_RESPONSE_MODE`, following the `--error-mode` precedent in the fake's docstring). First `POST /v1/chat/completions` → the captured `tool_calls` stream; a request whose body contains a `role:"tool"` message → a plain completion.
- [x] **Step 2: Write the integration spec** — drive a chat buffer through `chat_respond` against the fake; assert 🔧: and 📎: blocks land and the loop terminates. Follow `tests/integration/cliproxy_dispatch_spec.lua` for spawn/teardown.
- [x] **Step 3: Run — expect FAIL, then PASS once the mode lands.**
- [x] **Step 4: Add a parallel-call case** — two indices, both 🔧:/📎: pairs render in order.
- [x] **Step 5: Commit.**

### Task 2.5: OpenAI-route golden payloads

**Files:**
- Modify: `tests/unit/parley_harness_golden_spec.lua:9-17`
- Create: `tests/fixtures/golden_payloads/openai-{one-round-tool-use,two-round-tool-use,tool-error}.json`

- [x] **Step 1: Extend the spec** to run the existing tool transcripts a second time under an OpenAI-route agent, reusing the `READONLY_TOOLS` pin (its comment at `:19-25` explains the machine-independence reason, which applies identically).
- [x] **Step 2: Generate the goldens and READ THEM before committing** — confirm by eye that `arguments` are JSON strings, each `tool_result` became its own `role:"tool"` message, and `parameters` is `{}` not `[]`. A golden captured from a bug is a bug with a test defending it.
- [x] **Step 3: Confirm the Anthropic goldens are byte-identical.**
- [x] **Step 4: Commit.**

### Task 2.6: Live wire conformance

**Files:**
- Create: `tests/integration/cliproxy_tool_conformance_spec.lua`

- [x] **Step 1: Write it** on the `cliproxy_conformance_spec.lua` model — a `REQUIRED_FIELDS`-style list (`index`, `id`, `function.name`, `function.arguments`, `finish_reason == "tool_calls"`) asserted against a real response, so upstream wire drift fails here rather than in a user's chat.
- [x] **Step 2: Gate behind `PARLEY_LIVE_CONFORMANCE=1`,** skip otherwise. Unlike the management-API check this needs a real credential, so it must reuse an already-running proxy read-only and never spawn a second one against a live auth-dir (#197's rotation race).
- [x] **Step 3: Run once with the flag to confirm it passes against 7.2.110; confirm it SKIPS cleanly without it.**
- [x] **Step 4: Commit.**

### Task 2.7: End-to-end verification in the real editor

**Files:**
- Modify: `lua/parley/config.lua` (the `ToolSol*` block)

- [x] **Step 1: Carry the uncommitted `ToolSol*` + `codex` alias config forward** from the `000197` working tree into this issue's branch, then **extend** its comment. The existing text is already correct that `openai_tools_route` suits an OpenAI-family model — it does not need contradicting. What it should gain: parley now speaks the OpenAI tool wire natively, and web search coexists with function tools on that route. Separately, sweep for the stale "cliproxyapi requires an anthropic-family model" framing anywhere it survives.
- [x] **Step 2: Manual e2e** — select `ToolSol*`, ask for something needing a file read AND a web lookup in one turn. Confirm 🔧:/📎: render, the loop recurses, a cited URL appears, the answer lands, no error.
- [x] **Step 3: Multi-round loop** — a task needing ≥2 sequential rounds; confirm the iteration counter advances and terminates.
- [x] **Step 4: Regression-check `ToolOpus*`** through the same prompt — unchanged, including `server_tool_use` web search (which the operator confirmed works on the claude channel).
- [x] **Step 5: Exercise a skill on an OpenAI-family agent** — the `force_tool` path from Task 2.3, end to end. Unit tests alone will not catch a wrong `tool_choice` shape; the API will.
- [x] **Step 6: Capture the actual buffer output into `## Log`** — evidence, not a claim that it worked.

### Task 2.8: Close the issue

- [x] **Step 1: `make test`** green. **Step 2: luacheck** clean.
- [x] **Step 3: Update `atlas/`** for the wire seam, the `tool_choice` relocation, and the widened tool-capable predicate.
- [x] **Step 4: Update `workshop/lessons.md`** with rules from what the reviews caught (AGENTS.md §4) — the plan-gate Critical here (a translation seam installed in a builder two of its four supposed consumers never call) is exactly the class worth a rule.
- [x] **Step 5: `sdlc close --issue 198 --verified '<evidence>'`** — omit `--actual` so the binary measures and adopts the hours (AGENTS.md §5; never hand-type them).

---

## Risks

- **`vim.json.encode` key order is not stable.** `arguments` is a JSON *string*, so goldens with multi-key tool inputs may differ run to run. Keep golden tool inputs single-key, or decode before comparing. Decide in Task 2.5 — if the goldens flake, this is why.
- **`translate_messages` runs on every OpenAI-family request, tool-less ones included.** The string-content pass-through must be exact identity or every existing OpenAI chat changes shape. Task 1.6's first pinned behavior is the guard; the full suite in Task 1.8 Step 4 is the backstop.
- **The registry must stay model-keyed.** The moment a consumer passes a route instead, the forget-the-route failure returns — and it fails *silently*, as zero decoded tool calls. If a future caller genuinely has no model, give it an explicit `wire.for_route(route)` rather than letting `nil` default.
- **`googleai` remains wireless.** `resolve` returns nil and `encode` raises naming the provider — the same failure the issue fixes, but honest about which provider and no longer claiming an anthropic-family requirement. Out of scope by ARCH-PURPOSE: the issue's purpose is the OpenAI family, and Google needs a genuinely different shape (`functionDeclarations`), not a deferred half of this one.

---

## Revisions

### 2026-08-15 — M1 execution deviations

**1. `M.ollama_encode_tools` / `M.googleai_encode_tools`: status `deleted` → `deleted in M2`.**
Core-concepts table rows and Task 1.8 both said M1 deletes them. It does not.
Their only caller is the dispatcher's provider chain (`dispatcher.lua:124-126`),
which M2 Task 2.1 removes — deleting them at M1 would leave the tree calling a
nil for any googleai/ollama agent that declared tools. They are deleted in M2,
in the same commit that removes the last reference. Task 1.8's Files list
changes accordingly.

**2. Task 1.7's test files consolidated.** The task named both
`tests/unit/tool_wire_registry_spec.lua` and `tests/unit/cliproxy_route_spec.lua`;
everything landed in the former. The latter does not exist.

**3. M1 → M2 handoff carries a live regression, not just missing capability.**
M1 unblocked the *encoders* while the *decoders* still assume Anthropic. So at
this commit a `ToolSol*` turn builds a valid OpenAI request, receives
`delta.tool_calls`, decodes zero calls through
`providers.decode_anthropic_tool_calls_from_stream`, and renders an empty
answer — where before M1 it raised a clear "tools not supported for this
provider yet" at request-build time. **M1 must not merge without M2.** M2 Tasks
2.1/2.2 are therefore closing an exposure, not merely adding capability, and
should be sequenced first within the milestone.

**4. New pure entity: `sse.str`** (`lua/parley/sse.lua`), from M1 review C1.
`vim.json.decode` maps an explicit JSON `null` to `vim.NIL`, which is **truthy**
in Lua, so `if obj.name then …` accepts it and overwrites a good value with
userdata that raises on the next concatenation. Both decoders now read every
optional field through `sse.str`, making the class unrepresentable rather than
patched per-site. Add to the Core-concepts table as `new`.

### 2026-08-15 — M2 execution deviations

**5. Task 2.1 Step 4's `empty_response` mechanism changed.** The step specified
`wire.has_tool_calls(provider, model, qt.raw_response)` with the note "*Do NOT
recompute a route here — `has_tool_calls` takes the model and resolves
internally.*" That is not implementable as written: the query table carries the
provider and the **serialized payload**, whose `model` is a bare NAME, and no
model params table. `claude-sonnet-5` resolves to a *different* wire depending
on the agent's `web_search_strategy`, so a name-only resolution silently picks
the wrong decoder.

What shipped instead is a payload stamp, mirroring the existing `_parley_route`
convention: `prepare_payload` writes `_parley_tool_wire`
(`dispatcher.lua:149`), `query` consumes it onto the query table *before* the
body is serialized (`:201-211`), and the probe resolves through
`wire.by_name`. Two places must strip it — `dispatcher.query` and
`scripts/parley_harness.lua` (so the goldens stay an accurate request model);
both are covered by tests (`dispatcher_query_spec` Group K, and the golden spec
itself).

New Core-concepts rows this adds to `lua/parley/tools/wire.lua`: `by_name`,
`name_for`, `has_tool_calls_by_name` — all `new`, all pure. (A fourth,
`decode_by_name`, was written and then deleted in the close-review pass: no
caller ever materialised, and `tool_loop`/`skill_invoke` resolve by
`(provider, model)` because the agent is in scope there.)

**6. Task 2.4's integration spec does not drive `chat_respond`.** The step said
"drive a chat buffer through `chat_respond`"; `openai_tool_loop_spec.lua`
composes `dispatcher.query` + `tool_loop.process_response` against the fake
instead. The close review flagged the resulting gap — the production threading
at `chat_respond.lua:1851-1852` was deletable with the suite green — so the
`chat_respond` coverage landed as a separate case in
`tests/integration/chat_respond_spec.lua` ("threads provider/model to the tool
loop so an openai-family agent recurses"), verified by mutation: deleting those
two lines fails it with "tool loop did not recurse".

**7. Task 2.5 shipped four OpenAI goldens, not three.**
`openai-mixed-text-and-tools` was added alongside the named one-round,
two-round and tool-error fixtures, since interleaved text and tool blocks are a
distinct shape.

**8. New entity from the close review: `provider_params.raise_output_cap`.**
`skill_invoke`'s large-document headroom bump wrote `max_tokens` directly,
which for gpt-5 models is a no-op — `provider_params` renames the cap to
`max_completion_tokens`, so the effective limit stayed at 4096 (causing the
truncation the bump exists to prevent) while a rejected `max_tokens` key rode
along. Reachable precisely because Task 2.3 widened the skill predicate to
OpenAI-family agents. The helper lives in `provider_params` because that is
where the renaming is defined, and its spec pins the invariant "raise whichever
key `resolve_params` wrote" rather than a hand-listed model table.
