---
gate: boundary-review
issue: 205
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-08-31T20:22:26-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
          detail: |-
            Task 3.2 calls M._logged_out_providers(plugin) attributed to Task 3.1, but
            Task 3.1 only extends _build_items and injects logged_out rows in its test;
            the Integration-points table calls the same capability provider_states. No
            step creates either. It also reads credential_health_for_login
            (lua/parley/cliproxy.lua:474), which is callback-async, so a synchronous
            call in view_for on picker-open contradicts the plan's own "zero network
            work on the main thread" envelope. 4th in family (PQ-4, PQ-12, this;
            3 of 3 in the sibling invented-test-api family). Do not patch this site —
            the covering rule already exists in Notes for the implementer; run the
            grep it prescribes once over the whole plan and dispose of its output.
            (carried from plan-quality PQ-14, deferred to the boundary review)
          family: stated-design-not-implemented
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-08-31T20:22:26-07:00"
      agent: claude
      findings:
        - id: BR-2
          severity: Critical
          title: build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
          detail: |-
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
          family: single-source-not-enforced
          round: 2
        - id: BR-3
          severity: Important
          title: cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
          detail: |-
            The function appears nowhere under tests/. Plan Task 1.6 specified five cases in
            tests/unit/provider_params_spec.lua, which is untouched in the window. It is covered
            only transitively by three build_agent assertions, which is why the "none" value was
            never followed to its consumer. The plan's code_execution_claude and mystery-1
            fallback cases are unexercised. This is the direct enabler of the Critical above.
          family: missing-test-for-shipped-behavior
          round: 2
        - id: BR-4
          severity: Important
          title: rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
          detail: |-
            lua/parley/cliproxy_catalog.lua:97 matches "(%d+%.?%d*)" anywhere in the display
            name. For created-less antigravity rows that yields 120 for "GPT-OSS 120B (Medium)"
            against 3.x for every Gemini row. Run against the fixture, the Spec's own default
            config entry (bare "antigravity") renders GPT-OSS 120B, Claude Opus 4.6 and Claude
            Sonnet 4.6 — hiding every Gemini model the provider exists to offer. Reject a
            numeral immediately followed by a letter, or anchor the match to the series stem.
          family: rank-key-version-extraction
          round: 2
        - id: BR-5
          severity: Important
          title: The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
          detail: |-
            The issue states the four Spec-table rows are the unit-test cases for curate. Three
            are pinned with assert.same; the antigravity row is reduced to a tbl_contains check
            on a single-term variant (tests/unit/cliproxy_catalog_spec.lua:150). The documented
            row does render correctly today, but the weakened assertion is why the rank_key
            ordering defect stayed invisible. Assert the documented row as an equality and add a
            bare-"antigravity" case.
          family: documented-render-not-pinned
          round: 2
        - id: BR-6
          severity: Minor
          title: A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
          detail: |-
            lua/parley/cliproxy_catalog.lua:137-143 — provider_owned_by("claud") returns nil and
            the pool filter m.owner == owner then matches rows whose owned_by is absent. Silent
            empty (or wrong) group with no operator signal.
          family: unknown-input-silently-ignored
          round: 2
        - id: BR-7
          severity: Minor
          title: series("") returns "" under a test titled "never returns an empty key, whatever the id"
          detail: |-
            The plan's version of the loop listed "" with an explicit escape; the shipped loop
            drops the case rather than handling it. lua/parley/cliproxy_catalog.lua:37 falls back
            to the id, which is also "" for an empty id.
          family: test-title-overstates-guard
          round: 2
        - id: BR-8
          severity: Minor
          title: build_agent raises on a row with a nil id while every sibling function type-guards
          detail: lua/parley/cliproxy_catalog.lua:194 concatenates m.id directly.
          family: missing-input-guard
          round: 2
        - id: BR-9
          severity: Minor
          title: Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
          detail: |-
            SPEC takes an atlas spec key; the correct value is providers/cliproxy-managed.
            Executing the plan literally produces "No tests mapped for spec" at seven steps.
          family: plan-command-does-not-run
          round: 2
        - id: BR-10
          severity: Minor
          title: Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
          detail: |-
            Listing it (lua/parley/providers.lua, new) is what would have made its missing test
            row visible during the cross-check. Warrants a `## Revisions` entry.
          family: plan-table-missing-entity
          round: 2
        - id: BR-11
          severity: Minor
          title: The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
          detail: |-
            gpt-oss-120b-medium is antigravity-owned but gpt-family by id, so it gets
            openai_tools_route — unmeasured against the live proxy, and the Spec's table does not
            disambiguate owner from family for that row.
          family: unmeasured-family-branch
          round: 2
      boundary: M1
      blocked: true
---

# Gate ledger — parley.nvim#205 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-31T20:22:26-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
  Task 3.2 calls M._logged_out_providers(plugin) attributed to Task 3.1, but
  Task 3.1 only extends _build_items and injects logged_out rows in its test;
  the Integration-points table calls the same capability provider_states. No
  step creates either. It also reads credential_health_for_login
  (lua/parley/cliproxy.lua:474), which is callback-async, so a synchronous
  call in view_for on picker-open contradicts the plan's own "zero network
  work on the main thread" envelope. 4th in family (PQ-4, PQ-12, this;
  3 of 3 in the sibling invented-test-api family). Do not patch this site —
  the covering rule already exists in Notes for the implementer; run the
  grep it prescribes once over the whole plan and dispose of its output.
  (carried from plan-quality PQ-14, deferred to the boundary review)

## Round 2 — 2026-08-31T20:22:26-07:00 (claude) — BLOCKED

### Raised

- **BR-2** [Critical] `single-source-not-enforced` build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
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
- **BR-3** [Important] `missing-test-for-shipped-behavior` cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
  The function appears nowhere under tests/. Plan Task 1.6 specified five cases in
  tests/unit/provider_params_spec.lua, which is untouched in the window. It is covered
  only transitively by three build_agent assertions, which is why the "none" value was
  never followed to its consumer. The plan's code_execution_claude and mystery-1
  fallback cases are unexercised. This is the direct enabler of the Critical above.
- **BR-4** [Important] `rank-key-version-extraction` rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
  lua/parley/cliproxy_catalog.lua:97 matches "(%d+%.?%d*)" anywhere in the display
  name. For created-less antigravity rows that yields 120 for "GPT-OSS 120B (Medium)"
  against 3.x for every Gemini row. Run against the fixture, the Spec's own default
  config entry (bare "antigravity") renders GPT-OSS 120B, Claude Opus 4.6 and Claude
  Sonnet 4.6 — hiding every Gemini model the provider exists to offer. Reject a
  numeral immediately followed by a letter, or anchor the match to the series stem.
- **BR-5** [Important] `documented-render-not-pinned` The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
  The issue states the four Spec-table rows are the unit-test cases for curate. Three
  are pinned with assert.same; the antigravity row is reduced to a tbl_contains check
  on a single-term variant (tests/unit/cliproxy_catalog_spec.lua:150). The documented
  row does render correctly today, but the weakened assertion is why the rank_key
  ordering defect stayed invisible. Assert the documented row as an equality and add a
  bare-"antigravity" case.
- **BR-6** [Minor] `unknown-input-silently-ignored` A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
  lua/parley/cliproxy_catalog.lua:137-143 — provider_owned_by("claud") returns nil and
  the pool filter m.owner == owner then matches rows whose owned_by is absent. Silent
  empty (or wrong) group with no operator signal.
- **BR-7** [Minor] `test-title-overstates-guard` series("") returns "" under a test titled "never returns an empty key, whatever the id"
  The plan's version of the loop listed "" with an explicit escape; the shipped loop
  drops the case rather than handling it. lua/parley/cliproxy_catalog.lua:37 falls back
  to the id, which is also "" for an empty id.
- **BR-8** [Minor] `missing-input-guard` build_agent raises on a row with a nil id while every sibling function type-guards
  lua/parley/cliproxy_catalog.lua:194 concatenates m.id directly.
- **BR-9** [Minor] `plan-command-does-not-run` Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
  SPEC takes an atlas spec key; the correct value is providers/cliproxy-managed.
  Executing the plan literally produces "No tests mapped for spec" at seven steps.
- **BR-10** [Minor] `plan-table-missing-entity` Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
  Listing it (lua/parley/providers.lua, new) is what would have made its missing test
  row visible during the cross-check. Warrants a `## Revisions` entry.
- **BR-11** [Minor] `unmeasured-family-branch` The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
  gpt-oss-120b-medium is antigravity-owned but gpt-family by id, so it gets
  openai_tools_route — unmeasured against the live proxy, and the Spec's table does not
  disambiguate owner from family for that row.

## Open findings

- **BR-1** [Minor] `stated-design-not-implemented` The producer of the logged-out rows is named twice and defined nowhere; the plan's own referent sweep was stated but not run
- **BR-2** [Critical] `single-source-not-enforced` build_agent's "none" web-search strategy is discarded by the resolver; a gemini live pick ships the broken web_search payload
- **BR-3** [Important] `missing-test-for-shipped-behavior` cliproxy_default_web_search_strategy ships with no direct test; Task 1.6 Steps 1-5 produced no artifact
- **BR-4** [Important] `rank-key-version-extraction` rank_key reads the first numeral in displayName as a version, so "GPT-OSS 120B" outranks every Gemini row
- **BR-5** [Important] `documented-render-not-pinned` The one curate render exercising both displayName matching and created-less ranking is asserted with tbl_contains, not equality
- **BR-6** [Minor] `unknown-input-silently-ignored` A typo'd provider spec resolves owned_by to nil and then pools every row missing owned_by
- **BR-7** [Minor] `test-title-overstates-guard` series("") returns "" under a test titled "never returns an empty key, whatever the id"
- **BR-8** [Minor] `missing-input-guard` build_agent raises on a row with a nil id while every sibling function type-guards
- **BR-9** [Minor] `plan-command-does-not-run` Plan Chunk 1 repeats `make test-spec SPEC=unit/cliproxy_catalog`, which is not a valid SPEC key
- **BR-10** [Minor] `plan-table-missing-entity` Core concepts table omits cliproxy_default_web_search_strategy, the new PURE entity Task 1.6 delivers
- **BR-11** [Minor] `unmeasured-family-branch` The Spec's "gemini / antigravity -> neither" row is implemented as `^gemini`, leaving antigravity's gpt-oss row on openai_tools_route
