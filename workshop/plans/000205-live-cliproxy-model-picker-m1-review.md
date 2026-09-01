# Boundary Review — parley.nvim#205 (milestone M1)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..48cca57d0d58c2255285746ecfaefe20317f7321 |
| command | sdlc milestone-close --issue 205 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-31T20:22:26-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 delivers exactly the entities the plan's Core-concepts table promises — `series`, `parse`, `rank_key`, `parse_provider_spec`, `curate`, `build_agent` — as a genuinely pure module with 27 fixture-driven assertions and no mocks, and all three of the four documented `curate` renders that are asserted do match the live-captured fixture (I re-ran all four; they render exactly as the Spec claims). What blocks a clean SHIP is that the milestone's own headline claim is false in the shipped code: `build_agent` sets `web_search_strategy = "none"` for gemini picks, but `get_cliproxy_strategy` (providers.lua:103) whitelists only the three *positive* strategies at the model level, so `"none"` falls through to the provider default `openai_tools_route` and the payload for a gemini live pick carries `{type="web_search"}` — the precise configuration the Spec measured as producing `finish_reason: "malformed_function_call"` and no content. I verified this at runtime, not by reading. Task 1.6 Step 5 of the plan ("verify 'none' actually suppresses the tool") is the step that would have caught it, and it is the one step in M1 with no artifact in the diff — `cliproxy_default_web_search_strategy` ships with zero direct tests.

## 1. Strengths

- **`lua/parley/providers.lua:213`** — the three-way strategy genuinely reuses `is_cliproxy_anthropic_route_model` rather than re-writing the family test, which is the exact drift `cliproxy_route`'s extraction note (providers.lua:170-179) exists to prevent. ARCH-DRY: pass on this axis.
- **Fixtures are real and keep the awkward rows.** 43 rows, 13 with no `created`, ids that don't resemble their display names (`gemini-pro-agent` → "Gemini 3.1 Pro (High)"). The tests meet production's actual shapes, not an imagined happy path.
- **`curate` copies before tagging** (`cliproxy_catalog.lua:170-175`) and pins it with a `does not mutate the rows it was given` test — the module's purity claim is enforced, not asserted in a comment. ARCH-PURE: pass.
- **`rank_key`'s disjoint-band design** (`-1e9` rather than `-1000`, with the reasoning in the comment and the load-bearing third test case) is correct engineering on a subtle unit-mixing hazard.
- **`series` handles the all-numeral collapse** with an explicit fallback rather than emitting a colliding empty key.

## 2. Critical findings

**`lua/parley/providers.lua:103` (with `lua/parley/cliproxy_catalog.lua:196`) — a `"none"` strategy from `build_agent` is silently discarded; gemini live picks ship the broken payload the Spec exists to prevent.**

`get_cliproxy_strategy` accepts a model-level strategy only when it is `openai_search_model | openai_tools_route | anthropic_tools_route`. `"none"` — the fourth value of the enum documented at `config.lua:100`, and a value `has_feature` (providers.lua:1255) already treats as first-class — is not in that list, so it falls through to `parley.dispatcher.providers.cliproxyapi.web_search_strategy`, which ships as `openai_tools_route` (config.lua:101). Verified at runtime against HEAD:

```
model-level strategy: none
effective strategy:   openai_tools_route
payload.tools    = { { type = "web_search" } }
payload.tool_choice = auto
```

`config.web_search` defaults to `true`, so this fires on the default configuration. The commit body's claim — "a live pick there ships with server-side search off rather than broken" — does not hold.

Fix sketch: add `"none"` to the model-level accepted values in `get_cliproxy_strategy` so an explicit model-level `none` short-circuits the config fallback (safe: nothing in `config.lua` sets a model-level `"none"` today, and `pure_functions_spec` only exercises the provider-level value). Pin it with the test Task 1.6 Step 5 specifies: build a gemini agent via `cat.build_agent`, set the shipped provider default, format the payload, assert no `{type="web_search"}` entry. That test goes red without the fix — I confirmed the assertion fails today.

## 3. Important findings

**`lua/parley/providers.lua:213` — `cliproxy_default_web_search_strategy` ships with no test at all.** Plan Task 1.6 specifies five cases in `tests/unit/provider_params_spec.lua`; that file is untouched in the window and the function appears nowhere in `tests/`. It is covered only transitively through three `build_agent` assertions, which is why the `"none"` value was never followed to its consumer. The plan's `code_execution_claude` and `mystery-1` fallback cases are unexercised. This is the direct enabler of the Critical above.

**`lua/parley/cliproxy_catalog.lua:97` — `rank_key` takes the first number in `displayName` as a "version", so a parameter count outranks every real version.** `"GPT-OSS 120B (Medium)"` yields `120`; every Gemini row yields `3.x`. Consequence, run against the fixture:

```
antigravity  ->  GPT-OSS 120B (Medium) | Claude Opus 4.6 (Thinking) | Claude Sonnet 4.6 (Thinking)
```

The Spec's own default config example is `providers = { "claude:opus,sonnet", "codex:gpt-5.6", "antigravity" }` — so the bare `antigravity` entry the Spec ships surfaces three non-Gemini rows and hides every Gemini model the provider exists to offer. Fix sketch: reject a numeral immediately followed by a letter (`120B`), or anchor the version match to the alphabetic stem the series was derived from.

**`tests/unit/cliproxy_catalog_spec.lua:150` — the one `curate` render that exercises both display-name matching and created-less ranking is the only one not pinned as an equality.** The issue states "These rows are the unit-test cases for `curate`", and three of the four are asserted with `assert.same`. The fourth (`antigravity:pro,flash` → Gemini 3.1 Pro (Low), Gemini 3.1 Pro (High), Gemini 3.7 Flash) is reduced to `tbl_contains` on a single-term variant. The documented row does render correctly today — but the weaker assertion is why the `rank_key` ordering defect above was never visible to the suite. Assert the documented row as an equality, and add a bare-`antigravity` case.

## 4. Minor findings

- `lua/parley/cliproxy_catalog.lua:137` — a typo'd provider (`"claud:opus"`) resolves `owned_by` to `nil`, and the pool filter `m.owner == owner` then matches any row whose `owned_by` is absent. Silent empty group, no signal to the operator.
- `lua/parley/cliproxy_catalog.lua:37` — `series("")` still returns `""`, under a test titled "never returns an empty key, whatever the id". The plan's test listed `""`; the shipped loop drops it rather than handling it.
- `lua/parley/cliproxy_catalog.lua:194` — `m.id .. "*"` raises on a row with a nil `id`; every other function in the module type-guards its input.
- The plan repeats `make test-spec SPEC=unit/cliproxy_catalog` seven times across M1; that is not a valid SPEC key (it is an atlas spec key — `providers/cliproxy-managed`). Anyone executing the plan literally hits "No tests mapped for spec".
- The Spec's family table reads "gemini / antigravity → neither", but the implementation keys on `^gemini`, so antigravity-served `gpt-oss-120b-medium` gets `openai_tools_route` — unmeasured, and the owner-vs-family reading is ambiguous in the Spec.
- M1 shipped as one squashed commit rather than the plan's per-task commits, so the prescribed red/green TDD sequence is not evidenced in history.
- Atlas prose is unchanged (only `traceability.yaml`); the plan defers atlas to M4, and M1 introduces no user-facing surface, so README is correctly untouched. Noting only so M4 does not lose the new module's terminology (`series`, `curate`, the `provider:term,term` spec syntax).

## 5. Test coverage notes

- 27 assertions, all fixture-driven, no mocks, no IO — the ARCH-PURE claim holds and is enforced by the mutation test. `make test-spec SPEC=providers/cliproxy-managed` is fully green (all 15 mapped files), `make lint` is 0/0 across 342 files.
- The gap is entirely at the seam: every M1 entity is tested in isolation, and nothing tests what happens when `build_agent`'s output meets the code that consumes it. That is exactly where the shipped bug lives. One payload-level test closes it.
- Fixtures currently have no conformance guard — if cliproxy stops prefixing `models/`, every join misses, every row falls back to its raw id, and the whole suite stays green. Plan Task 2.1 Step 3 schedules this for M2; flagging only so it does not slip.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** — pass. The family test is reused, not copied; `matches`, the comparator and the row shape each have one home.
- **ARCH-PURE** — pass. `curate`'s `owned_by` is injectable and defaults lazily; `defaults.chat_system_prompt` is a static string, so `build_agent` does no IO.
- **ARCH-PURPOSE** — **flag.** M1's stated purpose for Task 1.6 was to *single-source* the strategy decision. The source now exists and produces the right value, but the only consumer path discards one third of its range, so the single-sourcing is documentation rather than enforcement — the "compiled to consumers" test the principle names. The Critical is that gap; fixing the resolver is what makes M1 actually deliver Task 1.6. Separately, `config.lua`'s hand-written `web_search_strategy = "anthropic_tools_route"` entries (lines 239/247/259/377/384 at HEAD) remain hand-maintained restatements — legitimately M4's scope, but M4 must sweep all of them, not just the alias block.
- **ARCH-MOCK** — pass for M1 (no external calls). M2 must land the `/v1beta/models` conformance case before the fixtures become the only witness to the wire shape.
- **ARCH-CONSTRAINTS** — pass. O(50) rows, one sort per provider spec, nothing on a UI path yet. The envelope claims land in M2/M3; note that `curate` re-sorts the pool once per provider entry, which is free at this scale but is the thing to watch if `<C-a>` re-curates on every keystroke in M3.
- Unrelated to the window: `lua/parley/config.lua` carries ~192 uncommitted deletions in the working tree. Outside this boundary, but it means M4 work is in flight while M1 closes — worth keeping the two separable.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000205-live-cliproxy-model-picker-plan.md` covering:

1. **Core concepts table omits `cliproxy_default_web_search_strategy`.** Task 1.6 delivers a new PURE entity in `lua/parley/providers.lua`, and the table's Pure-entities rows do not list it. Listing it (name / `lua/parley/providers.lua` / new) is what would have made its missing test row visible. Add it.
2. **Task 1.6 Step 5 must become a real test step, not a prose check.** As written ("confirm with a test that the payload for a gemini model carries no `tools` entry of that type") it produced no artifact and the defect shipped. Restate it as an explicit failing-test-first step naming the file, and record that `get_cliproxy_strategy`'s model-level whitelist must accept `"none"` for `build_agent`'s contract to hold.
3. **`rank_key`'s contract needs to say what a "version" is.** The current wording ("the version parsed from `displayName`") is satisfied by the first numeral, which `"GPT-OSS 120B (Medium)"` violates. State the rule and add the bare-`antigravity` render as a curate case.
4. **Correct the M1 test command.** Replace `make test-spec SPEC=unit/cliproxy_catalog` with `SPEC=providers/cliproxy-managed` throughout Chunk 1.

```findings
findings:
  - id: new
    severity: Critical
    family: single-source-not-enforced
    title: |
      build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
    detail: |
      get_cliproxy_strategy (lua/parley/providers.lua:103) whitelists only the three
      positive strategies at the model level, so build_agent's "none" falls through to
      the provider default openai_tools_route (config.lua:101). Verified at runtime on
      HEAD: cliproxy_strategy returns "openai_tools_route" and format_payload emits
      tools = { { type = "web_search" } } with tool_choice = "auto" for
      build_agent({id="gemini-3-flash"}) — the exact configuration the Spec measured as
      producing finish_reason "malformed_function_call" and no content. config.web_search
      defaults to true, so this fires on the default configuration, and the commit body's
      claim that gemini "ships with server-side search off rather than broken" is false.
      Fix: accept "none" in the model-level whitelist; pin with the payload-level test
      Task 1.6 Step 5 specifies.
  - id: new
    severity: Important
    family: missing-test-for-shipped-behavior
    title: |
      cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
    detail: |
      The function appears nowhere under tests/. Plan Task 1.6 specified five cases in
      tests/unit/provider_params_spec.lua, which is untouched in the window. It is covered
      only transitively by three build_agent assertions, which is why the "none" value was
      never followed to its consumer. The plan's code_execution_claude and mystery-1
      fallback cases are unexercised. This is the direct enabler of the Critical above.
  - id: new
    severity: Important
    family: rank-key-version-extraction
    title: |
      rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
    detail: |
      lua/parley/cliproxy_catalog.lua:97 matches "(%d+%.?%d*)" anywhere in the display
      name. For created-less antigravity rows that yields 120 for "GPT-OSS 120B (Medium)"
      against 3.x for every Gemini row. Run against the fixture, the Spec's own default
      config entry (bare "antigravity") renders GPT-OSS 120B, Claude Opus 4.6 and Claude
      Sonnet 4.6 — hiding every Gemini model the provider exists to offer. Reject a
      numeral immediately followed by a letter, or anchor the match to the series stem.
  - id: new
    severity: Important
    family: documented-render-not-pinned
    title: |
      The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
    detail: |
      The issue states the four Spec-table rows are the unit-test cases for curate. Three
      are pinned with assert.same; the antigravity row is reduced to a tbl_contains check
      on a single-term variant (tests/unit/cliproxy_catalog_spec.lua:150). The documented
      row does render correctly today, but the weakened assertion is why the rank_key
      ordering defect stayed invisible. Assert the documented row as an equality and add a
      bare-"antigravity" case.
  - id: new
    severity: Minor
    family: unknown-input-silently-ignored
    title: |
      A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
    detail: |
      lua/parley/cliproxy_catalog.lua:137-143 — provider_owned_by("claud") returns nil and
      the pool filter m.owner == owner then matches rows whose owned_by is absent. Silent
      empty (or wrong) group with no operator signal.
  - id: new
    severity: Minor
    family: test-title-overstates-guard
    title: |
      series("") returns "" under a test titled "never returns an empty key, whatever the id"
    detail: |
      The plan's version of the loop listed "" with an explicit escape; the shipped loop
      drops the case rather than handling it. lua/parley/cliproxy_catalog.lua:37 falls back
      to the id, which is also "" for an empty id.
  - id: new
    severity: Minor
    family: missing-input-guard
    title: |
      build_agent raises on a row with a nil id while every sibling function type-guards
    detail: |
      lua/parley/cliproxy_catalog.lua:194 concatenates m.id directly.
  - id: new
    severity: Minor
    family: plan-command-does-not-run
    title: |
      Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
    detail: |
      SPEC takes an atlas spec key; the correct value is providers/cliproxy-managed.
      Executing the plan literally produces "No tests mapped for spec" at seven steps.
  - id: new
    severity: Minor
    family: plan-table-missing-entity
    title: |
      Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
    detail: |
      Listing it (lua/parley/providers.lua, new) is what would have made its missing test
      row visible during the cross-check. Warrants a `## Revisions` entry.
  - id: new
    severity: Minor
    family: unmeasured-family-branch
    title: |
      The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
    detail: |
      gpt-oss-120b-medium is antigravity-owned but gpt-family by id, so it gets
      openai_tools_route — unmeasured against the live proxy, and the Spec's table does not
      disambiguate owner from family for that row.
```
