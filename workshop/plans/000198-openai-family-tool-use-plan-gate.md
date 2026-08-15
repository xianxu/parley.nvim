---
gate: plan-quality
issue: 198
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-15T10:14:53-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: translate_messages lands only in openai.format_payload, which the cliproxy OpenAI route and ollama never call
          detail: |-
            cliproxyapi.format_payload returns cliproxy_openai_payload (providers.lua:999-1029, called at :1057), a
            separate builder that does not delegate to openai.format_payload; ollama.format_payload (:1165-1177) is also
            independent. Only copilot (:963) and azure (:1140) delegate. As planned, ToolSol* — the issue's trigger —
            still sends Anthropic content-block arrays to the codex channel, and every unit test and golden still passes.
          round: 1
        - id: PQ-2
          severity: Important
          title: skill_invoke and dispatcher decode sites get no cliproxy route, and the registry silently defaults to the openai wire
          detail: |-
            wire.for_provider("cliproxyapi", nil) returns the OpenAI wire, so a missing route yields zero decoded calls
            instead of an error. Task 2.3 says only "swap skill_invoke.lua:252 the same way" with no route plumbing and no
            test; the review/voice_apply path would log "model returned no tool call" for a cliproxy anthropic-route agent.
            dispatcher.lua:326 has the same exposure (a tool-only ToolOpus* turn reporting empty_response) and no named test.
          round: 1
        - id: PQ-3
          severity: Important
          title: tool_choice is never wire-translated while the tool-capable predicate widens to OpenAI-family agents
          detail: |-
            Task 2.3 widens skill_assembly.lua:93 so openai/copilot/ollama agents resolve for skills, but skill_assembly.lua:37
            still emits Anthropic's {type="tool", name=…} and skill_invoke.lua:210 writes it verbatim. Both force_tool skills
            (skills/review/init.lua:500, skills/voice_apply/init.lua:31) would then send a shape OpenAI rejects. tool_choice
            encoding belongs on the wire modules next to encode_tools.
          round: 1
        - id: PQ-4
          severity: Minor
          title: Task 2.7 misstates the ToolSol* config comment, which is also uncommitted working-tree state
          detail: |-
            config.lua's ToolSol* block already says openai_tools_route "is the right route for an OpenAI-family model" and
            that the model "calls tools with parseable arguments" — not the opposite. That block is currently an uncommitted
            addition on the 000197 branch; the plan should declare that dependency.
          round: 1
        - id: PQ-5
          severity: Minor
          title: cliproxy_route extraction is not behavior-preserving for code_execution models, contrary to the plan's claim
          detail: |-
            providers.lua:1373 tests ^claude%- only, so cliproxyapi_encode_tools raises today for code_execution_* models
            while cliproxy_route will return "anthropic". A welcome fix, but "extraction changes nothing" is inaccurate.
          round: 1
        - id: PQ-6
          severity: Minor
          title: safe_json_decode / strip_data_prefix get a third copy; two encoder stubs and cliproxy_strategy are unlisted
          detail: |-
            Task 1.1 copies both helpers into wire_anthropic and wire_openai needs them too, leaving three copies in a plan
            citing ARCH-DRY. M.ollama_encode_tools / M.googleai_encode_tools become unreachable once dispatcher.lua:124-126
            goes, and providers.cliproxy_strategy (added in Task 2.1) is missing from the entity table.
          round: 1
        - id: PQ-7
          severity: Minor
          title: Test sections enumerate roughly nineteen cases, several as full Lua bodies
          detail: |-
            Tasks 1.3/1.4/1.5 restate the diff the implementer is about to write. Compress to the function names plus one
            strategy line per risky function; the adversarial classes worth keeping (malformed arguments, truncated stream,
            exact string-content identity) are already stated in one line each.
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-15T10:20:03-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: translate_messages moved to dispatcher.prepare_payload, the sole caller of adapter.format_payload; regression test pins the cliproxy path specifically.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Registry is model-keyed with no route parameter to forget; skill_invoke and dispatcher empty_response both get named tests.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: tool_choice moves to wire_*.encode_tool_choice, skill_assembly emits a plain force_tool name, coupled into the same task as the predicate widening.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Task 2.7 extends rather than contradicts the comment; the uncommitted 000197 config dependency is declared up front.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: cliproxy_route is documented as an intentional code_execution_* fix, not a pure extraction, and the spec pins it.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Shared helpers hoist to lua/parley/sse.lua; cliproxy_strategy and the two stub deletions are in the entity table.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: Test sections are now strategy lines per risky behavior; no full Lua test bodies remain.
          round: 2
      blocked: false
content_hash: 220e6019c0100b5709b48d136d3d46529520a540323759a8967dfa66643168bd
---

# Gate ledger — parley.nvim#198 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-15T10:14:53-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] translate_messages lands only in openai.format_payload, which the cliproxy OpenAI route and ollama never call
  cliproxyapi.format_payload returns cliproxy_openai_payload (providers.lua:999-1029, called at :1057), a
  separate builder that does not delegate to openai.format_payload; ollama.format_payload (:1165-1177) is also
  independent. Only copilot (:963) and azure (:1140) delegate. As planned, ToolSol* — the issue's trigger —
  still sends Anthropic content-block arrays to the codex channel, and every unit test and golden still passes.
- **PQ-2** [Important] skill_invoke and dispatcher decode sites get no cliproxy route, and the registry silently defaults to the openai wire
  wire.for_provider("cliproxyapi", nil) returns the OpenAI wire, so a missing route yields zero decoded calls
  instead of an error. Task 2.3 says only "swap skill_invoke.lua:252 the same way" with no route plumbing and no
  test; the review/voice_apply path would log "model returned no tool call" for a cliproxy anthropic-route agent.
  dispatcher.lua:326 has the same exposure (a tool-only ToolOpus* turn reporting empty_response) and no named test.
- **PQ-3** [Important] tool_choice is never wire-translated while the tool-capable predicate widens to OpenAI-family agents
  Task 2.3 widens skill_assembly.lua:93 so openai/copilot/ollama agents resolve for skills, but skill_assembly.lua:37
  still emits Anthropic's {type="tool", name=…} and skill_invoke.lua:210 writes it verbatim. Both force_tool skills
  (skills/review/init.lua:500, skills/voice_apply/init.lua:31) would then send a shape OpenAI rejects. tool_choice
  encoding belongs on the wire modules next to encode_tools.
- **PQ-4** [Minor] Task 2.7 misstates the ToolSol* config comment, which is also uncommitted working-tree state
  config.lua's ToolSol* block already says openai_tools_route "is the right route for an OpenAI-family model" and
  that the model "calls tools with parseable arguments" — not the opposite. That block is currently an uncommitted
  addition on the 000197 branch; the plan should declare that dependency.
- **PQ-5** [Minor] cliproxy_route extraction is not behavior-preserving for code_execution models, contrary to the plan's claim
  providers.lua:1373 tests ^claude%- only, so cliproxyapi_encode_tools raises today for code_execution_* models
  while cliproxy_route will return "anthropic". A welcome fix, but "extraction changes nothing" is inaccurate.
- **PQ-6** [Minor] safe_json_decode / strip_data_prefix get a third copy; two encoder stubs and cliproxy_strategy are unlisted
  Task 1.1 copies both helpers into wire_anthropic and wire_openai needs them too, leaving three copies in a plan
  citing ARCH-DRY. M.ollama_encode_tools / M.googleai_encode_tools become unreachable once dispatcher.lua:124-126
  goes, and providers.cliproxy_strategy (added in Task 2.1) is missing from the entity table.
- **PQ-7** [Minor] Test sections enumerate roughly nineteen cases, several as full Lua bodies
  Tasks 1.3/1.4/1.5 restate the diff the implementer is about to write. Compress to the function names plus one
  strategy line per risky function; the adversarial classes worth keeping (malformed arguments, truncated stream,
  exact string-content identity) are already stated in one line each.

## Round 2 — 2026-08-15T10:20:03-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — translate_messages moved to dispatcher.prepare_payload, the sole caller of adapter.format_payload; regression test pins the cliproxy path specifically.
- PQ-2 — addressed — Registry is model-keyed with no route parameter to forget; skill_invoke and dispatcher empty_response both get named tests.
- PQ-3 — addressed — tool_choice moves to wire_*.encode_tool_choice, skill_assembly emits a plain force_tool name, coupled into the same task as the predicate widening.
- PQ-4 — addressed — Task 2.7 extends rather than contradicts the comment; the uncommitted 000197 config dependency is declared up front.
- PQ-5 — addressed — cliproxy_route is documented as an intentional code_execution_* fix, not a pure extraction, and the spec pins it.
- PQ-6 — addressed — Shared helpers hoist to lua/parley/sse.lua; cliproxy_strategy and the two stub deletions are in the entity table.
- PQ-7 — addressed — Test sections are now strategy lines per risky behavior; no full Lua test bodies remain.

## Open findings

(none — every finding has been disposed)
