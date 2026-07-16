---
id: 000118
status: done
deps: []
created: 2026-05-04
updated: 2026-05-04
---

# synthetic system prompt via leading user turn

For compatibility with providers / models that handle a real `system` field poorly (older completion-style endpoints, certain local proxies, some fine-tuned open models), let the agent opt into delivering the system prompt as a **synthetic leading user turn followed by a synthetic assistant ack**, instead of via the provider's `system` field.

The classic pattern:

```
user:       <system prompt content>
assistant:  Got it. I will follow this.
user:       <real first user turn>
...
```

The synthetic assistant ack ("Got it…") is more than ceremony — it puts the model in a state where it has *committed* to the rules, which empirically strengthens adherence on models trained without strong system-role priors.

## Scope

- Per-agent flag, opt-in only. No default change.
- **Wire-format boundary only.** The chat buffer on disk and parley's exchange model never see synthetic turns. The swap happens immediately before provider serialization.
- **Cache control preserved.** The synthetic user message must carry `cache_control: ephemeral` (or whatever the agent's existing system-prompt cache policy was), or we burn a cache miss on every turn just to switch wire formats.
- Customizable ack text, but defaults to a single sensible string.

## Done when

- An agent with `synthetic_system_prompt = true` produces requests where:
  - The provider `system` field is absent / empty.
  - `messages[0]` is a user turn carrying the system-prompt content with `cache_control: ephemeral`.
  - `messages[1]` is an assistant turn with the ack text.
  - `messages[2..N]` are the original conversation, unmodified.
- The chat file on disk never shows the synthetic pair.
- An agent without the flag behaves identically to today (no regression).
- Golden payload coverage: at least one fixture exercising `synthetic_system_prompt = true`.

## Plan

### Spec

**Agent config additions** (`lua/parley/config.lua`, default agent schema):

```lua
{
    provider = "...",
    name = "...",
    system_prompt = "...",
    synthetic_system_prompt = true,                      -- opt-in flag
    synthetic_system_prompt_ack = "Got it. I will follow this.",  -- optional override
    ...
}
```

`synthetic_system_prompt_ack` defaults to `"Got it. I will follow this."` when the flag is on.

**Where the swap happens.** Tracing the call chain:

```
chat_respond.respond
  → build_messages_from_model      (buffer → message list, agent-agnostic)
  → dispatcher.prepare_payload     (joins messages + model + provider + tools)
    → provider-specific serializer (anthropic.lua / openai.lua / googleai.lua)
```

The cleanest seam is **inside `prepare_payload`** (or the smallest helper it calls), right before the provider serializer runs:

```lua
if agent_info.synthetic_system_prompt and system_text and system_text ~= "" then
    -- Prepend synthetic pair, clear system_text
    local synthetic_user = {
        role = "user",
        content = {{ type = "text", text = system_text, cache_control = { type = "ephemeral" } }},
    }
    local synthetic_assistant = {
        role = "assistant",
        content = agent_info.synthetic_system_prompt_ack or "Got it. I will follow this.",
    }
    messages = vim.list_extend({ synthetic_user, synthetic_assistant }, messages)
    system_text = nil
end
```

(The exact field shape — string vs content-block list — depends on what the existing serializer expects. Investigate `lua/parley/dispatcher.lua` and the provider modules during implementation.)

**Per-provider notes:**
- Anthropic: `system` is a top-level field; clear it. `cache_control` on user content blocks is well-supported.
- OpenAI: system is a `role: "system"` message; under this flag we just don't emit it. OpenAI doesn't need explicit cache_control (server-side caching handles long prefixes automatically).
- Google AI: has its own `systemInstruction` field; clear under the flag.
- The transformation happens in shared code; provider serializers receive an already-correct message list with no system.

**Cache-control parity.** Today the system prompt is cached via Anthropic's `cache_control: ephemeral` on the system block (verify exact location in `lua/parley/providers.lua` or wherever the Anthropic payload is built). Under the synthetic mode, the same `cache_control` marker rides on the synthetic user message's content block. Goal: cache hit rate is unchanged when toggling the flag.

### Tasks

- [x] Located the system-prompt injection sites: `chat_respond.lua` legacy path (`_build_messages`) and `build_messages_from_model` (used by tool loop).
- [x] Added `synthetic_system_prompt` and `synthetic_system_prompt_ack` to the agent_info table in `lua/parley/agent_info.lua`. No schema validation file; agent configs are plain Lua tables, so adding new fields just works.
- [x] Implemented the wire-format swap as a small pure helper: `lua/parley/system_prompt_msgs.lua` (`build(agent_info, has_cache_control)`).
- [x] Wired the helper into both injection sites in `chat_respond.lua`. Whitespace trim + trailing-newline-on-append normalization moved upstream so it works for either output shape.
- [x] Unit tests: 11 specs in `tests/unit/system_prompt_msgs_spec.lua` covering empty/whitespace prompts, default mode (with/without cache_control), synthetic mode (with/without cache_control, custom ack, blank-ack fallback, falsy flag).
- [x] End-to-end tests: 4 specs in `tests/unit/build_messages_spec.lua` covering the synthetic shape under Anthropic + OpenAI, custom ack, and the regression guard for `flag = false`.
- [x] Atlas: extended `atlas/providers/system_prompts.md` with a "Synthetic delivery" section; added `providers/system_prompts` mapping in `atlas/traceability.yaml`.

### Decisions left out of scope (deferred)

- Skill-runner / memory-prefs paths build their own system prompts inline and would also benefit from the helper, but they don't currently consult agent flags. Out of scope until a use case appears.
- Did not add a dedicated golden-payload fixture for synthetic mode — the unit tests cover the message-shape invariant, and the `parley_harness` infrastructure currently keys on agent name, not arbitrary agent overrides. A synthetic-mode fixture would require either a new sample agent (bloats defaults for an opt-in feature) or harness plumbing for ad-hoc agent overrides. Deferred.

### Out of scope

- No global default change — every existing agent stays on the real `system` field.
- No provider-specific shortcut for "this provider doesn't support system at all, force synthetic" — keep the flag explicit. (Can be revisited if a provider literally cannot accept a system field.)
- No support for inserting the synthetic pair anywhere other than the start of `messages`.
- Buffer / parser / exchange-model changes — none. The on-disk format is unaffected.

### Open questions

- Should `synthetic_system_prompt_ack` accept a function (so it can vary per call), or always a static string? **Default: static string only** — keeps the swap pure and golden-testable. If a use case for a callback emerges, add later.
- For OpenAI specifically, do we also want to drop the `role:"system"` first message and let the synthetic pair speak for itself, OR keep the system message and *also* prepend the synthetic pair? **Default: drop system** — the whole point of the flag is to opt out of the system mechanism. If a model wants both, it doesn't need this flag.

## Log

### 2026-05-04

- Issue authored after a design conversation about system prompt vs leading user message. User asked "what's the difference?" — discussion landed on training-induced steering, wire format, cache economics, and reader convention. User then proposed this compatibility play and explicitly called out (a) preserving cache control on the moved content, and (b) restricting the swap to the wire-format boundary so the chat file is unaffected.
- Implemented as a small pure helper (`system_prompt_msgs.build`) called from both `_build_messages` and `build_messages_from_model`. Pre-existing whitespace-trim and trailing-newline-on-append behaviors were moved one step upstream (onto `agent_info.system_prompt` itself) so they are independent of which output shape the helper produces.
- `make test` green except pre-existing keybindings_spec failure. `make lint` clean.
- **Bug found in manual verification**: enabling the flag on an agent had no observable effect. Root cause: `M.get_agent` in `lua/parley/init.lua:3570` returns a *sanitized snapshot* of the agent record — explicitly forwarding `tools` / `max_tool_iterations` / `tool_result_max_bytes` and dropping anything else. New fields silently fell off here before `agent_info.resolve` could see them. Same vector as the M1 tools-forwarding bug already documented in the comment above that block. Fix: added the two synthetic fields to the snapshot allow-list. Regression test added in `tests/unit/config_tools_spec.lua` (`describe "get_agent forwards synthetic_system_prompt config"`) so the next field added to agent_info is forced to walk this path or be caught.
