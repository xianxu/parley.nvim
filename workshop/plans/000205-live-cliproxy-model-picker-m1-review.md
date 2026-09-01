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

---

## Re-review — 2026-08-31T20:41:43-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..2678b407c0a1c2889fd934f173419579b2cfb1b3 |
| command | sdlc milestone-close --issue 205 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-31T20:41:43-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The round-2 fixes are real, not paper: I reverted each one in place and confirmed the pinning test goes red — removing `none = true` from `CLIPROXY_STRATEGIES` (providers.lua:104) makes the BR-2 regression test fail with `openai_tools_route` vs `none`, and restoring the old single-`match` version extraction makes the BR-4 test fail on the 120B parameter count. `cliproxy_default_web_search_strategy` now has six direct tests including the two cases BR-3 named. What keeps this off SHIP is one new Important and one prior Important that was answered next to the target rather than on it: the BR-11 fix made `owner` decide the strategy, and `cliproxy_route` (providers.lua:194) derives the *wire* from the strategy — so `claude-sonnet-4-6`, the exact model the module's own docstring cites as flipping `owned_by` between proxy starts, now speaks the Anthropic wire on one start and the OpenAI wire on the next, directly contradicting the contract written six lines above it (cliproxy_catalog.lua:192); and BR-5's "assert the documented row as an equality" produced an equality on `antigravity:pro`, a single-term variant that is not one of the four documented rows, while the documented `antigravity:pro,flash` render and the Spec's own default-config bare `antigravity` entry remain unpinned. Suite state: `make test-spec SPEC=providers/cliproxy-managed` green (15 files, 35 assertions in the catalog spec), `make lint` 0/0 across 342 files; `tests/unit/parley_harness_spec.lua` fails 2 assertions but I confirmed it fails identically with `providers.lua` reverted to base, so it is pre-existing and outside this window.

## 1. Strengths

- **The BR-2 regression test refuses to pass for the wrong reason** (`tests/unit/cliproxy_catalog_spec.lua:276-300`). It sets `parley.dispatcher.providers.cliproxyapi.web_search_strategy` to an *active* strategy first, and says in a comment why — without that the fallback also returns `"none"` and the test is green against the buggy resolver. That is the failure mode the claimed-fixes rule exists to catch, and it was pre-empted in the test itself.
- **`CLIPROXY_STRATEGIES` (providers.lua:104)** collapses two hand-spelled triples into one table rather than adding `"none"` to both — the fix and an ARCH-DRY consolidation in the same edit.
- **`rank_key`'s `v < 100` band with the reasoning inline** (cliproxy_catalog.lua:97-102) names *why* a numeral ≥ 100 is a parameter count, so the next reader can extend the rule instead of re-deriving it.
- **Fixtures are genuinely real**: 43 rows in both routes, 13 without `created`, `models/` prefixes, and vendor naming that is inconsistent on purpose (`"Claude 4.6 Opus"` next to `"Claude Opus 4.7"`). I verified the join is total — zero v1 rows lack a beta partner.
- **The purity claim is enforced, not asserted**: `curate` copies before tagging and a `does not mutate the rows it was given` test pins it (ARCH-PURE).

## 2. Critical findings

None. BR-2 is fixed and revert-verified.

## 3. Important findings

**`lua/parley/cliproxy_catalog.lua:192` / `lua/parley/providers.lua:194` — the BR-11 fix makes `owner` decide the transport, contradicting the contract stated six lines above it.**

`build_agent`'s docstring says: *"The wire follows the MODEL FAMILY, never `owner`: owner is a display grouping that is not even stable (claude-sonnet-4-6 was reported under `anthropic` on one proxy start and `antigravity` on the next), while a claude model speaks the Anthropic wire whichever channel serves it."* But `cliproxy_default_web_search_strategy` now returns `"none"` whenever `owner == "antigravity"`, and `cliproxy_route` returns `"openai"` for any strategy that is not `anthropic_tools_route`. Measured at HEAD:

```
claude-sonnet-4-6         owner=antigravity  strategy=none                   route=openai
claude-opus-4-6-thinking  owner=antigravity  strategy=none                   route=openai
claude-opus-5             owner=anthropic    strategy=anthropic_tools_route  route=anthropic
```

Both antigravity-owned claude rows are in the shipped fixture and both surface in the bare `antigravity` render, which is the Spec's own default-config entry. The root cause is that `web_search_strategy` decides two orthogonal things — which search mechanism to send, and which wire to send it on — so a value chosen for search reasons silently retargets the transport. Nothing in the suite asserts the route for a `build_agent` output; the two BR-11 tests stop at the strategy string. Fix sketch: either give `build_agent` an explicit wire decision that keys on family independent of the strategy, or amend the docstring and the Spec's Component 4 to state that an antigravity-served claude deliberately uses the OpenAI wire — and pin whichever you choose with a `cliproxy_route(build_agent(row).model.model, cliproxy_strategy(build_agent(row).model))` assertion for both owners of the same id.

**`tests/unit/cliproxy_catalog_spec.lua:155-170` — BR-5's remaining half.** Disposed `not-addressed` below rather than re-raised; see the disposition note for the measured enumeration.

## 4. Minor findings

- BR-6, BR-7, BR-8, BR-9 are unchanged in the tree and are disposed `not-addressed` below; all four are individually one-line fixes and none blocks the gate.
- Task 1.6's tests landed in `tests/unit/cliproxy_catalog_spec.lua`, not `tests/unit/provider_params_spec.lua` as the plan's Task 1.6 Files section still says. The relocation is fine (they belong beside `build_agent`); the plan just doesn't record it.
- **Operational, not a code finding:** the working tree gained M2/M3 edits (`agent_picker.lua`, `cliproxy.lua`, `fake_cliproxy`, `ready_port.lua`, a new `tests/integration/cliproxy_catalog_spec.lua`) at 20:36–20:39 while this review ran. My revert experiments touched only `providers.lua`, `cliproxy_catalog.lua` and `config.lua`, and all three are byte-restored (`git diff HEAD` on them is empty; `config.lua` restored to sha `5687fe6d`, its state at review start). If anything wrote `config.lua` between 20:31 and 20:38:55, my restore would have reverted it — worth a glance before committing.

## 5. Test coverage notes

- 35 assertions in the catalog spec, fixture-driven, no mocks, no production IO. Both new-this-round pins (BR-2, BR-4) verified red-on-revert.
- The uncovered seam is now the **route**, not the strategy. BR-2 closed strategy→resolver; nothing closes strategy→wire, which is where the new Important lives.
- Measured renders against the fixture, for whoever writes the equality cases: `antigravity:pro,flash` → `{gemini-3.1-pro-low, gemini-pro-agent, gemini-3.7-flash-high}`; bare `antigravity` → `{claude-opus-4-6-thinking, claude-sonnet-4-6, gemini-3.7-flash-high}`.
- `scripts/spec_test_map.sh list-tests unit/cliproxy_catalog` returns nothing (exit 0) — confirming BR-9's claim that the plan's repeated SPEC key does not run.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass.** `CLIPROXY_STRATEGIES` removed the duplicated triple; `cliproxy_default_web_search_strategy` reuses `is_cliproxy_anthropic_route_model` rather than writing a fourth family test.
- **ARCH-PURE — pass.** Module is deterministic, `owned_by` is injectable, the mutation test enforces the no-side-effects claim. Fixture reads are test-harness IO, not production IO.
- **ARCH-PURPOSE — flag, narrowed.** The prior flag (single-source produced a value one consumer discarded) is genuinely closed at the resolver. The shadow sweep now finds a *second* consumer that still doesn't derive: `cliproxy_route` re-infers the wire from the strategy string instead of asking the single source — that is the new Important. Separately, `config.lua`'s hand-written `web_search_strategy = "anthropic_tools_route"` entries remain hand-maintained restatements of the family rule; legitimately M4, but M4 must sweep **all** of them, not only the alias block.
- **ARCH-MOCK — pass for M1** (no external calls). The working tree already carries `fake_cliproxy` + a conformance spec for M2, which is the right shape; the `/v1beta/models` conformance case must land before the fixtures become the only witness to the wire shape.
- **ARCH-CONSTRAINTS — pass.** 43 rows, one sort per provider spec, nothing on a UI path yet. One residual to watch: in the created-less band `rank_key` compares version numerals across unrelated vendors, so bare `antigravity` puts Claude 4.6 above Gemini 3.7. Defensible (it is the only signal available) but it is why the bare render is 2 Claude + 1 Gemini; if M3 makes that look wrong to the operator, the fix is per-series ranking, not a bigger numeral rule.

## 7. Plan revision recommendations

1. **Record the wire/strategy coupling.** The Spec's Component 4 and `build_agent`'s docstring both assert the wire follows family, never owner. State explicitly that `cliproxy_route` derives the wire from `web_search_strategy`, and decide + document which wire an antigravity-served claude model gets.
2. **State the render-pinning rule, not one more case.** "Every row of the Spec's render table is a `curate` equality case, asserted on the documented spec string verbatim" — and enumerate the five (`claude:opus,sonnet`, `claude`, `codex:gpt-5.6`, `antigravity:pro,flash`, plus the default-config bare `antigravity`).
3. **Run the referent grep the plan's own Notes prescribe** (BR-1, now the 3rd in its family and one milestone from the code that needs it): reconcile `provider_states` (Integration points, line 56) with `M._logged_out_providers` (line 1073), give one of them a creating step, and resolve the synchronous `credential_health_for_login` call in `view_for` against the plan's "zero network work on the main thread" envelope.
4. **Correct the SPEC key** at all 10 `SPEC=unit/cliproxy_catalog` sites to `SPEC=providers/cliproxy-managed`.
5. **Record the Task 1.6 test relocation** to `tests/unit/cliproxy_catalog_spec.lua`.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Plan unchanged on this point; `_logged_out_providers` still appears only at plan:1073 attributed to Task 3.1, which creates neither it nor `provider_states` (plan:56). 3rd in family; M3 is next.
  - id: BR-2
    disposition: addressed
    note: |
      Verified by revert — removing `none = true` from CLIPROXY_STRATEGIES makes the new test fail with openai_tools_route vs none.
  - id: BR-3
    disposition: addressed
    note: |
      Six direct tests incl. code_execution_claude and mystery-1; they live in cliproxy_catalog_spec.lua, not provider_params_spec.lua as the plan states.
  - id: BR-4
    disposition: addressed
    note: |
      Verified by revert — restoring the single-match extraction makes "does not let a parameter count outrank a version" fail.
  - id: BR-5
    disposition: not-addressed
    note: |
      Equality landed on `antigravity:pro`, a single-term variant that is not one of the four documented rows; the documented `antigravity:pro,flash` render and the bare-`antigravity` case (added as a tbl_contains negative, the exact weak form the finding named) are still unpinned — 2 of 5 Spec renders unasserted. State the rule (every Spec render row is a curate equality on the documented spec string) and sweep all five.
  - id: BR-6
    disposition: not-addressed
    note: |
      curate is unchanged; owner may still be nil and `m.owner == owner` still pools rows lacking owned_by. Measured: `claud:opus` renders silently empty.
  - id: BR-7
    disposition: not-addressed
    note: |
      Measured at HEAD — cat.series("") still returns ""; the test loop still omits the "" case.
  - id: BR-8
    disposition: not-addressed
    note: |
      Measured at HEAD — build_agent({owner="anthropic"}) raises "attempt to concatenate field 'id' (a nil value)" at cliproxy_catalog.lua:204.
  - id: BR-9
    disposition: not-addressed
    note: |
      `SPEC=unit/cliproxy_catalog` still at 10 plan sites; spec_test_map.sh list-tests returns nothing for that key.
  - id: BR-10
    disposition: addressed
    note: |
      Both rows added to the Core concepts table plus a `## Revisions` entry.
  - id: BR-11
    disposition: addressed
    note: |
      owner == "antigravity" now yields none regardless of family, with two tests; but see the new finding — that change also moves the wire.
findings:
  - id: new
    severity: Important
    family: one-value-two-decisions
    title: |
      web_search_strategy also selects the wire, so the BR-11 owner rule makes owned_by decide the transport — contradicting build_agent's own docstring
    detail: |
      cliproxy_route (lua/parley/providers.lua:194) returns "openai" for any strategy
      that is not anthropic_tools_route, so the BR-11 fix (owner == "antigravity" =>
      "none") retargets the wire as a side effect. Measured at HEAD: build_agent for
      claude-sonnet-4-6 with owner=antigravity yields strategy=none route=openai, while
      the same id with owner=anthropic yields anthropic_tools_route route=anthropic.
      cliproxy_catalog.lua:192 states the opposite as a contract — "The wire follows the
      MODEL FAMILY, never owner ... a claude model speaks the Anthropic wire whichever
      channel serves it" — and cites claude-sonnet-4-6 flipping owned_by between proxy
      starts as the reason. Both antigravity-owned claude rows are in the fixture and
      both surface in the bare "antigravity" render, which is the Spec's default config
      entry. No test asserts the route for a built agent; the BR-11 tests stop at the
      strategy string. Either decide the wire independently of the strategy, or amend
      the docstring and Spec Component 4 — and pin the choice for both owners of one id.
```

---

## Re-review — 2026-08-31T20:53:57-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 205 — live cliproxy model picker; retire hardcoded model lists |
| repo | parley.nvim |
| issue file | workshop/issues/000205-live-cliproxy-model-picker.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 42d72b9d2f12bad462d847d8e5b24876a1a6a63b..2ecb11c22bf4b73c30da15850c084fbec6165ccf |
| command | sdlc milestone-close --issue 205 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-31T20:53:57-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 1's Critical is genuinely fixed and genuinely pinned — I verified by reverting each claimed fix in a scratch checkout of `2ecb11c` and watching the named test go red (`none = true` removed from `CLIPROXY_STRATEGIES` → the resolver test fails; first-numeral `rank_key` restored → the parameter-count test fails; `owner == "antigravity"` hoisted above the family test → two wire tests fail). The M1 entities in the plan's Core-concepts table all exist at the stated paths, `make lint` is 0/0 across 344 files, and the catalog spec plus the eight related unit specs are green at HEAD. What stops a clean SHIP is that two of the seven carried findings were answered at the instance and not at the class: BR-4's fix ("first number below 100 is the version") still reads a parameter count as a version for every size under 100 — I measured `gpt-oss-20b-medium` taking the **top** slot of the `antigravity` group and pushing every Gemini row out of a 3-cap render — and BR-5's equality assertion pins `antigravity:pro`, a variant, rather than the Spec's documented `antigravity:pro,flash` row, which I confirmed renders exactly as the Spec claims and would cost one line to pin. Five carried Minors (BR-1, BR-6, BR-7, BR-8, BR-9) went untouched for a third round.

## 1. Strengths

- **`lua/parley/providers.lua:225-247` — the BR-12 resolution is by measurement, not by preference.** Putting `is_cliproxy_anthropic_route_model` first and consulting `owner` only in the region where `cliproxy_route` returns `"openai"` either way makes "owner cannot reach the wire" a *structural* property, not a convention. The comment states exactly why, and the test `never lets owner reach the wire decision` asserts the two owners of `claude-sonnet-4-6` resolve identically — the shared-id instability the Spec measured.
- **The BR-2 regression test is honestly constructed** (`tests/unit/cliproxy_catalog_spec.lua:257-263`). It forces `parley.dispatcher.providers.cliproxyapi.web_search_strategy` to an *active* strategy first, and the comment records that the naive version passed against the buggy resolver. That is the difference between a test written from the fix's mental model and one that actually constrains it — confirmed by revert.
- **The BR-2 fix restores agreement with existing documented behavior rather than inventing new.** `atlas/providers/cliproxyapi.md:6-7` already listed `none` among the four values with "per-model override via `agent.model.web_search_strategy`", and `has_feature` (`providers.lua:1283-1287`) already treated `none` as first-class. The code was the outlier; no atlas change was needed.
- **`CLIPROXY_STRATEGIES` (`providers.lua:104-109`) collapses a set that was spelled out twice**, and `get_web_search_strategy` (`:1302`) delegates to the same `get_cliproxy_strategy`, so the badge, the payload builder and the feature gate cannot drift. ARCH-DRY: pass.
- **Purity is enforced, not asserted.** `curate` copies before tagging (`cliproxy_catalog.lua:170-175`) and `does not mutate the rows it was given` compares a deepcopy of the whole input array, so a reordering or a stray field would fail. ARCH-PURE: pass.

## 2. Critical findings

None.

## 3. Important findings

**`lua/parley/cliproxy_catalog.lua:96-105` — `rank_key`'s `< 100` threshold fixes the 120B instance, not the class it belongs to.**

**This is the 2nd finding in family `rank-key-version-extraction`.** Round 1 fixed the instance (`"GPT-OSS 120B (Medium)"`). Do not fix this instance either — state the rule and fix the rule.

The rule the code needs: *a numeral scraped from a free-text display name is a version only when it is delimited — not when a letter follows it.* `120B`, `20B`, `70B`, `8B`, `32K` are magnitudes with unit suffixes; `3.7`, `4.6`, `5` are versions. The round-1 review sketched this rule verbatim ("reject a numeral immediately followed by a letter (`120B`), or anchor the version match to the alphabetic stem the series was derived from"); the shipped fix substituted a magnitude threshold, which happens to exclude the one row in the fixture and nothing else.

Measured against the shipped code at HEAD, adding one row (`gpt-oss-20b-medium` / `"GPT-OSS 20B (Medium)"` / no `created`, the sibling size of the row already in the fixture):

```
antigravity (before) -> claude-opus-4-6-thinking, claude-sonnet-4-6, gemini-3.7-flash-high
antigravity (after)  -> gpt-oss-20b-medium, claude-opus-4-6-thinking, claude-sonnet-4-6
rank_key(20B row)    = -999999980
rank_key(Gemini 3.7) = -999999996.3
```

That is BR-4's exact failure mode — the Spec's shipped default entry `antigravity` hiding every Gemini row — reproduced with a size the threshold does not catch. Fix sketch: match `(%d+%.?%d*)` only when not followed by `%a`, and add a case per magnitude *shape* (`20B`, `120B`, `8B`) rather than per value, so the next suffix cannot slip through the same gap.

Secondary evidence for the same rule: within the created-less band the number is compared across product lines, so `"Claude Opus 4.6 (Thinking)"` outranks `"Gemini 3.7 Flash"` on 4.6 > 3.7 — a comparison between two vendors' version scales that has no meaning. The bare-`antigravity` render pinned at `cliproxy_catalog_spec.lua:157-163` encodes that outcome as correct. Worth deciding deliberately at M3 when the render is on screen, rather than by pattern accident.

## 4. Minor findings

- `tests/unit/cliproxy_catalog_spec.lua:38-44` — dropping `""` from the malformed-id list makes the suite green without making the title (`never returns an empty key, whatever the id`) true. See BR-7 disposition.
- `lua/parley/cliproxy_catalog.lua:206` — `m.id .. "*"` still raises; every sibling type-guards. See BR-8.
- `lua/parley/cliproxy_catalog.lua:145-150` — `owner == nil` from an unknown provider still pools `owned_by`-less rows. See BR-6.
- The plan's Core-concepts table row `resolve_channel | lua/parley/cliproxy_config.lua` is correct at the stated path (`:163`) but the issue's second Revision renamed the entity `resolve_channels`; rename the row when M4 lands so the table does not go stale mid-milestone.

## 5. Test coverage notes

- 36 assertions, all green, all fixture-driven; fixtures carry the awkward shapes (43 rows, 13 without `created`, 43/43 joined on the `models/` prefix, four distinct owners).
- **The three claimed fixes are all pinned by tests that fail without them** — verified by revert, not by reading. BR-2 → 1 red, BR-4 → 1 red, BR-12 → 2 red.
- The BR-2 seam test asserts at `cliproxy_strategy`, one step short of the payload assertion plan Task 1.6 Step 5 specifies. Acceptable: `format_payload` (`providers.lua:1046`) resolves through the same `get_cliproxy_strategy` and gates on a literal `== "openai_tools_route"` twelve lines away, so the composition is direct. Noting only so the step is marked done deliberately rather than by omission.
- Uncovered: `curate` with an unknown/empty provider; `series("")`; `build_agent` on a row missing `id`; the documented `antigravity:pro,flash` render; any parameter count below 100. Four of the five are the carried Minors.
- The spec header declares "no IO, no mocks", but the BR-2 case `require("parley")`s the plugin and stubs `parley.dispatcher`. That is defensible (it tests an explicitly-impure resolver, and 32 other unit specs require `parley`), but it makes the file's own header inaccurate and gives the pure spec a transitive dependency on `construct/generated/vocabulary/issue.json` — I hit that failure in a clean `git archive` checkout before copying the generated tree in. Consider a one-line header amendment noting the last `describe` block is a seam test.

## 6. Architectural notes for upcoming work

- **ARCH-DRY: pass.** No duplicated logic introduced; the strategy value set and the anthropic family test are each single-sourced and reused.
- **ARCH-PURE: pass.** `cliproxy_catalog.lua` is IO-free, the mutation test enforces it, and the one impure entity (`get_cliproxy_strategy`) documents its ambient read at `providers.lua:161-166`.
- **ARCH-PURPOSE: pass at this boundary, with one thing to carry.** M1's scope is the pure core, and it delivers all of it. The issue's actual purpose — no model named in `config.lua` — is M4, a genuinely separable milestone, not a deferred point. But the shadow sweep already has one live consumer that does not derive: `config.lua:222` still hand-writes `web_search_strategy = "anthropic_tools_route"` for `claude-opus-4-8` while `cliproxy_default_web_search_strategy` is now the single source that would compute it. M4 must make that row derive, not merely delete the alias block. Separately, the *answering* half of this principle is what the Important above is about: two of three carried findings this round were answered at the instance.
- **ARCH-MOCK: pass with a scheduled gap.** M1 is pure and fixture-driven, so no seam is required. The `/v1beta/models` live conformance check (plan Task 2.1 Step 3) is the only witness that `name` keeps its `models/` prefix — without it, unit tests run on a fixture consistent with itself and integration tests on a fake restating the same assumption, and a bare id would make all 43 joins miss silently while both suites stay green. Do not let it slip past M2.
- **ARCH-CONSTRAINTS: pass, N/A at this boundary.** M1 adds no runtime path; the declared envelope (zero network on the main thread at picker open, ~5 KB cache read, 10-min staleness) is an M2/M3 obligation and the plan states it with basis.
- **For M3:** `owner` now decides the search tool, and `owner` is unstable. A live agent is built once at pick time and persisted across restart (Spec Component 5), so a persisted `gpt-oss-*` agent can carry a strategy derived from an owner value the proxy has since changed. Both directions are inert on today's measurements (`none` loses search; `openai_tools_route` searches without effect) and the fatal gemini case is caught by the family rule regardless of owner — so this is safe as designed, not a defect. Worth a sentence in M3's persistence note so the next reader does not re-derive it.

## 7. Plan revision recommendations

- **`## Revisions` — "M1 boundary review round 3".** Record the `rank_key` rule change (delimited numeral, not a magnitude threshold) and state explicitly that round 2's `< 100` answered the instance rather than the class, so the next round can see the pattern.
- **`## Revisions` — the referent sweep BR-1 prescribed was never run.** Run the whole-plan grep the plan's own "Notes for the implementer" already mandates, then either add a step that creates the logged-out-provider producer or delete the call site. Right now `M._logged_out_providers` (plan `:1073`, attributed to Task 3.1) and `provider_states` (plan `:56`, `:65`) name one capability twice with no defining step, and the plan's Integration-points table says it reuses `credential_health_for_login` — which is callback-async, so the synchronous `view_for` call on picker-open contradicts the plan's own "zero network work on the main thread" envelope. Resolve the async shape in the plan before M3 implements it.
- **Chunk 1–3 step commands:** replace every `make test-spec SPEC=unit/cliproxy_catalog` / `SPEC=unit/picker_items` / `SPEC=integration/cliproxy_catalog` / `SPEC=unit/live_agent_state` with `SPEC=providers/cliproxy-managed` (or the matching atlas key). Confirmed: `scripts/spec_test_map.sh list-tests unit/cliproxy_catalog` returns nothing, and the make target exits 1 with "No tests mapped for spec".
- **Core-concepts table:** rename `resolve_channel` → `resolve_channels` to match the issue's second Revision.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Plan Revisions cover BR-2..BR-5, BR-10..BR-12 only; `M._logged_out_providers` (plan:1073) is still attributed to a Task 3.1 that defines no such function, `provider_states` (plan:56,65) still names the same capability, and the prescribed whole-plan referent grep was not run.
  - id: BR-5
    disposition: not-addressed
    note: |
      The tbl_contains is gone and a bare-`antigravity` case was added, but the equality pins `antigravity:pro` — a single-term variant — not the Spec's documented `antigravity:pro,flash` row, which I measured rendering exactly as documented (gemini-3.1-pro-low, gemini-pro-agent, gemini-3.7-flash-high).
  - id: BR-6
    disposition: not-addressed
    note: |
      Verified at HEAD: curate with provider "claud" returns [], and the `m.owner == owner` filter with owner==nil still pools every row whose owned_by is absent. No guard added.
  - id: BR-7
    disposition: not-addressed
    note: |
      The shipped test now drops "" from the input list entirely rather than handling it; `series("")` still returns "" under a title reading "never returns an empty key, whatever the id".
  - id: BR-8
    disposition: not-addressed
    note: |
      Verified: build_agent({owner="anthropic"}) raises "attempt to concatenate field 'id' (a nil value)" at cliproxy_catalog.lua:206.
  - id: BR-9
    disposition: not-addressed
    note: |
      `scripts/spec_test_map.sh list-tests unit/cliproxy_catalog` returns nothing; the plan still repeats invalid SPEC keys at twelve steps across Chunks 1-3.
  - id: BR-12
    disposition: addressed
    note: |
      Verified by revert in a scratch checkout: hoisting the `owner == "antigravity"` check above the family test turns two tests red; docstring and Spec reading now agree.
findings:
  - id: new
    severity: Important
    family: rank-key-version-extraction
    title: |
      rank_key's `< 100` threshold answers the 120B instance, not the class: any parameter count below 100 still reads as a version
    detail: |
      2nd in family — do NOT patch the site. The rule the code needs: a numeral
      scraped from a free-text display name is a version only when it is
      DELIMITED (not followed by a letter). `120B`, `20B`, `70B`, `8B`, `32K` are
      magnitudes with unit suffixes; the round-1 review sketched exactly this rule
      and the shipped fix substituted a magnitude threshold that happens to
      exclude the single fixture row and nothing else. Measured at HEAD by adding
      `gpt-oss-20b-medium` / "GPT-OSS 20B (Medium)" (no created, sibling size of
      the row already in the fixture): the antigravity group renders
      gpt-oss-20b-medium, claude-opus-4-6-thinking, claude-sonnet-4-6 —
      rank_key = -999999980 vs -999999996.3 for "Gemini 3.7 Flash" — so every
      Gemini row is pushed out of the Spec's shipped 3-cap `antigravity` entry.
      That is BR-4's exact failure mode with a size the threshold misses. Fix the
      rule (reject `%d+%.?%d*` followed by `%a`, or anchor the version to the
      alphabetic stem `series` already derives) and cover it by magnitude SHAPE
      (20B / 120B / 8B), not by value. Related: within the created-less band the
      scraped number is compared across product lines, so "Claude Opus 4.6"
      outranks "Gemini 3.7" on 4.6 > 3.7 — a cross-vendor version comparison the
      bare-`antigravity` test currently pins as correct; decide that deliberately
      at M3 rather than by pattern accident.
```
